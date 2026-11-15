import AIEvaluationCore
import Darwin
import Foundation

/// Platform adapter. Footprint is a 100 ms sampled process peak, not Instruments or phone energy.
actor LabProcessMeasurement: RunMeasuring {
  private let storageURLs: [URL]
  private var peak: UInt64?
  private var sampler: Task<Void, Never>?

  init(storageURLs: [URL]) { self.storageURLs = storageURLs }

  func start() {
    sample()
    // Sampling must not inherit the actor running model decode or the UI actor.
    sampler = Task.detached { [weak self] in
      while !Task.isCancelled {
        await self?.sample()
        do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
      }
    }
  }

  func finish() async -> RunTelemetry {
    sampler?.cancel()
    await sampler?.value
    sampler = nil
    sample()
    return RunTelemetry(
      peakMemoryBytes: peak, storageBytes: storageURLs.reduce(0) { $0 + logicalBytes($1) },
      measurementMethod:
        "Process TASK_VM_INFO phys_footprint sampled every 100 ms; includes the whole lab process. Storage is logical bytes of this candidate's model/index paths. Simulator battery and physical heat are not measured."
    )
  }

  private func sample() {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    if status == KERN_SUCCESS { peak = max(peak ?? 0, info.phys_footprint) }
  }

  private func logicalBytes(_ url: URL) -> UInt64 {
    let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
    guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
    if values.isRegularFile == true { return UInt64(values.fileSize ?? 0) }
    guard
      let enumerator = FileManager.default.enumerator(
        at: url, includingPropertiesForKeys: Array(keys))
    else { return 0 }
    var bytes: UInt64 = 0
    for case let child as URL in enumerator {
      guard let values = try? child.resourceValues(forKeys: keys), values.isRegularFile == true
      else { continue }
      bytes += UInt64(values.fileSize ?? 0)
    }
    return bytes
  }
}
