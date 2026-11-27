import Foundation
import Testing

private actor ResidentReadProbe {
  private(set) var count = 0
  private var waiting: CheckedContinuation<Void, Never>?

  func read() -> UInt64? {
    count += 1
    if count >= 2 {
      waiting?.resume()
      waiting = nil
    }
    return count == 1 ? 100 : (count == 2 ? 500 : 200)
  }
  func waitForPoll() async {
    if count >= 2 { return }
    await withCheckedContinuation { waiting = $0 }
  }
}

@Suite struct RequestResidentSamplerTests {
  private enum ProbeError: Error { case expected }

  @Test(arguments: [false, true])
  func successfulAndThrowingOperationsJoinTheSampler(_ fails: Bool) async throws {
    let probe = ResidentReadProbe()
    let sampler = RequestResidentSampler(read: { await probe.read() })
    do {
      let measured = try await sampler.measure {
        await probe.waitForPoll()
        if fails { throw ProbeError.expected }
        return 7
      }
      #expect(!fails)
      #expect(measured.value == 7)
    } catch ProbeError.expected {
      #expect(fails)
    }
    let report = try #require(await sampler.report)
    #expect(report.startBytes == 100)
    #expect(report.endBytes == 200)
    #expect(report.peakBytes == 500)
    #expect(report.sampleCount == report.sampleAttempts)
    #expect(report.sampleCount >= 3)
    #expect(await !sampler.isRunning)
    let finishedCount = await probe.count
    // Observe two complete poll intervals: a leaked poller would keep reading after return.
    try await Task.sleep(for: .milliseconds(60))
    #expect(await probe.count == finishedCount)
  }

  @Test func cancellationJoinsSamplingAndRetainsItsFinalReading() async throws {
    let probe = ResidentReadProbe()
    let sampler = RequestResidentSampler(read: { await probe.read() })
    let request = Task {
      try await sampler.measure {
        try await Task.sleep(for: .seconds(30))
        return 1
      }
    }
    await probe.waitForPoll()
    request.cancel()
    await #expect(throws: CancellationError.self) { try await request.value }
    #expect(await !sampler.isRunning)
    let report = try #require(await sampler.report)
    #expect(report.endBytes == 200)
    #expect(report.peakBytes == 500)
    let finishedCount = await probe.count
    try await Task.sleep(for: .milliseconds(60))
    #expect(await probe.count == finishedCount)
  }
}
