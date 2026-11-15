import Darwin
import Foundation

/// Local builder diagnostics contain numeric timings only, never prompts, replies or record IDs.
struct ChatMeasurement: Codable, Sendable {
  let tokens: Int?
  let firstTokenSeconds: Double?
  let preparationSeconds: Double?
  let totalSeconds: Double
  let cold: Bool?
  let residentBytes: UInt64?

  static func residentBytes() -> UInt64? {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    return result == KERN_SUCCESS ? info.resident_size : nil
  }
}

actor ChatMeasurementStore {
  static let shared = ChatMeasurementStore()
  private var samples: [ChatMeasurement] = []
  func append(_ sample: ChatMeasurement) {
    samples.append(sample)
    samples = Array(samples.suffix(40))
    let url = URL.documentsDirectory.appending(path: "chat-builder-measurements.json")
    do {
      let data = try JSONEncoder().encode(samples)
      try data.write(to: url, options: [.atomic, .completeFileProtection])
      var file = url
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try file.setResourceValues(values)
    } catch {
      // Diagnostics must not alter chat persistence or expose error paths/content in logs.
    }
  }
}
