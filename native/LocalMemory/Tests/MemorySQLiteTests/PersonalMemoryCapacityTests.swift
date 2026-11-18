import Foundation
import MemoryCore
import MemorySQLite
import Testing

struct PersonalMemoryCapacityTests {
  private func fixture(count: Int = 1_000) throws -> PersonalMemorySnapshot {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let conversation = UUID()
    let sources = (0..<count).map { index in
      var source = PersonalMemorySource(
        conversationID: conversation, text: "Fictional preference \(index)", createdAt: date,
        origin: "benchmark", kind: .preference)
      source.analysis = PersonalMemoryAnalysisState(status: .processed)
      return source
    }
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(PersonalMemorySnapshot()))
        as? [String: Any])
    object["sources"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(sources))
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
      PersonalMemorySnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    try result.validate()
    return result
  }

  @Test func thousandProcessedEvidenceSourcesRetainFiftyHistoryRevisions() async throws {
    let seed = try fixture()
    let folder = URL.temporaryDirectory.appending(path: "capacity-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appending(path: "memory.json")
    try JSONEncoder().encode(seed).write(to: file)
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let entryID = try #require(seed.entries.first?.id)
    var editMilliseconds: [Double] = []
    for edit in 0..<50 {
      let start = ProcessInfo.processInfo.systemUptime
      _ = try await cases.updateEntry(id: entryID, text: "Fictional history \(edit)")
      editMilliseconds.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
    }
    let retained = try await cases.snapshot()
    #expect(retained.sources == seed.sources)
    #expect(retained.events.count == 50)
    #expect(retained.entries.first { $0.id == entryID }?.evidence == seed.entries.first?.evidence)
    let bytes = try Data(contentsOf: file)
    #expect(bytes.count <= PersonalMemoryLimits.archiveBytes)
    let stored = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect((stored["analysisStates"] as? [[String: Any]])?.count == 1_000)
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    #expect(try await reopened.snapshot() == retained)
    let undone = try await reopened.undo()
    #expect(undone.entries.first { $0.id == entryID }?.text == "Fictional history 48")
    #expect(undone.events.count == 49)
    let exported = try await reopened.exportArchive()
    #expect(exported.count <= PersonalMemoryLimits.archiveBytes)
    let decoded = try JSONDecoder().decode(PersonalMemorySnapshot.self, from: exported)
    try decoded.validate()
    #expect(decoded == undone)
    var budget = PersonalMemoryRetainedBudget(
      originalBytes: retained.sources.reduce(0) { $0 + $1.estimatedRetainedBytes })
    try budget.add(retained.graph)
    for event in retained.events { try budget.add(event.before) }
    let sortedEdits = editMilliseconds.sorted()
    let p95 = sortedEdits[Int(ceil(Double(sortedEdits.count) * 0.95)) - 1]
    print(
      "MEMORYOS_CAPACITY sources=1000 events=50 logical_bytes=\(budget.bytes) file_bytes=\(bytes.count) export_bytes=\(exported.count) host_edit_p95_ms=\(p95)"
    )
  }

  @Test func uniqueAnalysisVersionsStillConsumeTheLogicalBudget() throws {
    let seed = try fixture()
    var shared = PersonalMemoryRetainedBudget(originalBytes: 0)
    for _ in 0..<51 { try shared.add(seed.graph) }
    #expect(shared.bytes < PersonalMemoryLimits.archiveBytes / 2)
    var unique = PersonalMemoryRetainedBudget(originalBytes: 0)
    var refused = false
    for revision in 0..<51 {
      var graph = seed.graph
      for source in seed.sources {
        graph.analysisStates?[source.id]?.appliedRevision = UInt64(revision)
      }
      do { try unique.add(graph) } catch PersonalMemoryError.limitReached {
        refused = true
        break
      }
    }
    #expect(refused)
  }

  @Test(arguments: ["category-bytes", "classification", "unresolved-overlap"])
  func validationReuseNeverHidesChangedBytesOrHistoricalRules(mutation: String) async throws {
    let seed = try fixture(count: 1)
    let folder = URL.temporaryDirectory.appending(path: "validation-cache-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appending(path: "memory.json")
    try JSONEncoder().encode(seed).write(to: file)
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: file))
    let entryID = try #require(seed.entries.first?.id)
    let validCategory = String(repeating: "é", count: 60)
    let value = try await cases.organize(
      entryID: entryID, categories: [validCategory], profileIDs: [seed.selfProfileID])
    var root = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    let currentEntries = try #require(root["entries"] as? [[String: Any]])
    let current = try #require(currentEntries.first { ($0["id"] as? String) == entryID.uuidString })
    var events = try #require(root["events"] as? [[String: Any]])
    var before = try #require(events.last?["before"] as? [String: Any])
    var entries = [current]
    if mutation == "category-bytes" {
      let invalidCategory = String(repeating: "e\u{301}", count: 60)
      #expect(validCategory == invalidCategory && invalidCategory.utf8.count > 120)
      entries[0]["categories"] = [invalidCategory]
    } else if mutation == "classification" {
      var classifications = try #require(before["classifications"] as? [Any])
      for index in stride(from: 1, to: classifications.count, by: 2) {
        classifications[index] = "rolePlay"
      }
      before["classifications"] = classifications
    } else {
      var states = try #require(before["analysisStates"] as? [Any])
      var state = try #require(states[1] as? [String: Any])
      state["status"] = "needsClarification"
      state["question"] = "Is this certain?"
      state["quote"] = seed.sources[0].text
      states[1] = state
      before["analysisStates"] = states
    }
    before["entries"] = entries
    events[events.count - 1]["before"] = before
    root["events"] = events
    let corrupted = try JSONDecoder().decode(
      PersonalMemorySnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    #expect(
      throws: mutation == "category-bytes"
        ? PersonalMemoryError.limitReached : PersonalMemoryError.invalidArchive
    ) {
      try corrupted.validate()
    }
  }

}
