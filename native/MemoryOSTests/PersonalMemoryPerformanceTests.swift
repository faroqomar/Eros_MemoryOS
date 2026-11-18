import Darwin
import Foundation
import MemoryCore
import XCTest

@testable import MemoryOS

/// Select this class explicitly in Release. Fixtures never use the app's persistent history.
final class PersonalMemoryPerformanceTests: XCTestCase, @unchecked Sendable {
  func testIsolatedFileGraphLatencyAndGrowth() async throws {
    for count in [100, 1_000] {
      var cold: [Double] = []
      var warm: [Double] = []
      var edits: [Double] = []
      var fileBytes: [Int] = []
      var rssGrowth: [Int64] = []
      var thermalBefore: [Int] = []
      var thermalAfter: [Int] = []
      for repetition in 0..<3 {
        let directory = FileManager.default.temporaryDirectory.appending(
          path: "memoryos-performance-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let initialRSS = try residentBytes()
        thermalBefore.append(ProcessInfo.processInfo.thermalState.rawValue)
        let seed = try fixture(count: count)
        try await prepare(seed, in: directory)

        // A fresh actor forces JSON decode/validation. OS filesystem caches are not flushed.
        let start = ProcessInfo.processInfo.systemUptime
        var useCases = PersonalMemoryComposition.makeUseCases(directory: directory)
        let first = try await useCases.snapshot()
        cold.append(milliseconds(since: start))
        XCTAssertEqual(first.sources, seed.sources)
        XCTAssertEqual(first.events.count, 50)
        try first.validate()

        let warmStart = ProcessInfo.processInfo.systemUptime
        useCases = PersonalMemoryComposition.makeUseCases(directory: directory)
        let reopened = try await useCases.snapshot()
        warm.append(milliseconds(since: warmStart))
        XCTAssertEqual(reopened, first)

        let entryID = try XCTUnwrap(reopened.entries.first?.id)
        for edit in 0..<30 {
          let editStart = ProcessInfo.processInfo.systemUptime
          let updated = try await useCases.updateEntry(
            id: entryID, text: "Fictional edit \(repetition)-\(edit)")
          edits.append(milliseconds(since: editStart))
          XCTAssertEqual(updated.events.count, 50)
          XCTAssertEqual(updated.sources, seed.sources)
        }
        let final = try await useCases.snapshot()
        let persisted = try await PersonalMemoryComposition.makeUseCases(directory: directory)
          .snapshot()
        XCTAssertEqual(persisted, final)
        XCTAssertEqual(final.entries.first?.text, "Fictional edit \(repetition)-29")
        XCTAssertEqual(final.sources.count, count)
        XCTAssertEqual(final.events.count, 50)
        try final.validate()
        let file = directory.appending(path: "memory.json")
        let values = try file.resourceValues(forKeys: [.fileSizeKey])
        fileBytes.append(try XCTUnwrap(values.fileSize))
        rssGrowth.append(Int64(try residentBytes()) - Int64(initialRSS))
        thermalAfter.append(ProcessInfo.processInfo.thermalState.rawValue)
        XCTAssertTrue(
          try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
            == true)
        #if os(iOS) && !targetEnvironment(simulator)
          let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
          XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
          let directoryAttributes = try FileManager.default.attributesOfItem(atPath: directory.path)
          XCTAssertEqual(directoryAttributes[.protectionKey] as? FileProtectionType, .complete)
        #endif
        try FileManager.default.removeItem(at: directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
      }
      let p95 = percentile(edits, fraction: 0.95)
      let coldMedian = percentile(cold, fraction: 0.5)
      let warmMedian = percentile(warm, fraction: 0.5)
      let result: [String: Any] = [
        "benchmark": "personal_memory_file_graph_v2_with_evidence", "sources": count,
        "retained_events": 50,
        "repetitions": 3, "edit_samples": edits.count, "cold_new_actor_ms": cold,
        "warm_new_actor_ms": warm, "cold_median_ms": coldMedian,
        "warm_median_ms": warmMedian, "edit_p95_ms": p95,
        "file_bytes": fileBytes, "rss_growth_bytes": rssGrowth,
        "thermal_state_before": thermalBefore, "thermal_state_after": thermalAfter,
        "thermal_state_key": "0 nominal, 1 fair, 2 serious, 3 critical; endpoints, not energy",
        "rss_method": "whole-process TASK_BASIC_INFO resident_size endpoints; not peak",
        "cold_method": "fresh actor; filesystem cache not flushed; not process launch",
        "backup_excluded": true,
        "protection_complete_attributes": isPhysicalDevice ? true as Any : NSNull(),
        "protection_method": "Physical attributes only; Simulator is unavailable, not passed.",
        "latency_pass": p95 < 250 && coldMedian < 1_000 && warmMedian < 1_000,
        "os": ProcessInfo.processInfo.operatingSystemVersionString,
        "physical_device": isPhysicalDevice,
      ]
      let encoded = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
      print("MEMORYOS_BENCHMARK " + String(decoding: encoded, as: UTF8.self))
      XCTAssertLessThan(p95, 250, "Edit p95 target is 250 ms")
      XCTAssertLessThan(coldMedian, 1_000, "Fresh actor reopen median target is 1 s")
      XCTAssertLessThan(warmMedian, 1_000, "Warm reopen median target is 1 s")
    }
  }

  private func prepare(_ seed: PersonalMemorySnapshot, in directory: URL) async throws {
    let useCases = PersonalMemoryComposition.makeUseCases(directory: directory)
    _ = try await useCases.restoreArchive(JSONEncoder().encode(seed))
    let id = try XCTUnwrap(seed.entries.first?.id)
    for edit in 0..<50 {
      _ = try await useCases.updateEntry(id: id, text: "Fictional history \(edit)")
    }
  }

  private func fixture(count: Int) throws -> PersonalMemorySnapshot {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let conversation = UUID()
    let sources = (0..<count).map { index in
      var source = PersonalMemorySource(
        conversationID: conversation, text: "Fictional preference \(index)", createdAt: date,
        origin: "benchmark", kind: .preference)
      source.analysis = PersonalMemoryAnalysisState(status: .processed)
      return source
    }
    let sourceData = try JSONEncoder().encode(sources)
    let sourceObjects = try JSONSerialization.jsonObject(with: sourceData)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(PersonalMemorySnapshot()))
        as? [String: Any])
    object["sources"] = sourceObjects
    object["entries"] = sources.map { source -> [String: Any] in
      [
        "id": UUID().uuidString, "text": source.text, "kind": "preference",
        "sourceIDs": [source.id.uuidString],
        "profileIDs": [PersonalMemorySnapshot.ownerID.uuidString],
        "categories": ["preference"], "confirmed": false,
        "createdAt": date.timeIntervalSinceReferenceDate,
        "evidence": [["sourceID": source.id.uuidString, "quote": source.text]],
      ]
    }
    let result = try JSONDecoder().decode(
      PersonalMemorySnapshot.self,
      from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    try result.validate()
    return result
  }

  private func residentBytes() throws -> UInt64 {
    var info = mach_task_basic_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    guard status == KERN_SUCCESS else {
      throw NSError(domain: "MemoryOSBenchmark", code: Int(status))
    }
    return info.resident_size
  }

  private func milliseconds(since start: TimeInterval) -> Double {
    (ProcessInfo.processInfo.systemUptime - start) * 1_000
  }

  private func percentile(_ values: [Double], fraction: Double) -> Double {
    let sorted = values.sorted()
    return sorted[max(0, Int(ceil(Double(sorted.count) * fraction)) - 1)]
  }

  private var isPhysicalDevice: Bool {
    #if targetEnvironment(simulator)
      false
    #else
      true
    #endif
  }
}
