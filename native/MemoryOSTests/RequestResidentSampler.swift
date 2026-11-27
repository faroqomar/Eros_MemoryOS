import Foundation

/// Test-only process RSS sampling. The reported peak is sampled, not an OS high-water mark.
actor RequestResidentSampler {
  struct Report: Sendable {
    let startBytes: UInt64?
    let endBytes: UInt64?
    let peakBytes: UInt64?
    let sampleCount: Int
    let sampleAttempts: Int

    var fields: [String: Any] {
      [
        "residentStartBytes": startBytes.map { $0 as Any } ?? NSNull(),
        "residentEndBytes": endBytes.map { $0 as Any } ?? NSNull(),
        "peakResidentBytes": peakBytes.map { $0 as Any } ?? NSNull(),
        "residentSampleCount": sampleCount, "residentSampleAttempts": sampleAttempts,
        "residentPollingMilliseconds": 25, "residentMeasurement": "process-rss-sampled",
      ]
    }
  }

  private let read: @Sendable () async -> UInt64?
  private var poller: Task<Void, Never>?
  private var peak: UInt64?
  private var sampleCount = 0
  private var sampleAttempts = 0
  private(set) var report: Report?
  var isRunning: Bool { poller != nil }

  init(read: @escaping @Sendable () async -> UInt64?) { self.read = read }

  func measure<Value: Sendable>(_ operation: @Sendable () async throws -> Value) async throws
    -> (value: Value, resident: Report)
  {
    precondition(poller == nil && report == nil, "Use one sampler per request.")
    let start = await sample()
    // This task inherits the sampler actor, not the benchmark's MainActor.
    poller = Task { [self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(25)) } catch { break }
        guard !Task.isCancelled else { break }
        _ = await sample()
      }
    }
    do {
      let value = try await operation()
      return (value, await finish(start: start))
    } catch {
      _ = await finish(start: start)
      throw error
    }
  }

  private func sample() async -> UInt64? {
    sampleAttempts += 1
    let value = await read()
    if let value {
      sampleCount += 1
      peak = max(peak ?? value, value)
    }
    return value
  }

  private func finish(start: UInt64?) async -> Report {
    poller?.cancel()
    await poller?.value
    poller = nil
    let end = await sample()
    let result = Report(
      startBytes: start, endBytes: end, peakBytes: peak,
      sampleCount: sampleCount, sampleAttempts: sampleAttempts)
    report = result
    return result
  }
}
