import Foundation
import MemoryCore
import MemorySQLite
import Testing

private actor Step2MemoryRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

struct Step2VerificationTests {
  private func storedFixture(at url: URL) async throws -> PersonalMemorySnapshot {
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    _ = try await cases.ingest(
      source: PersonalMemorySource(conversationID: UUID(), text: "I prefer tea", kind: .preference))
    let primary = try #require(try await cases.snapshot().entries.first { $0.kind == .preference })
    _ = try await cases.createProfile(kind: .person, name: "Mira")
    let person = try #require(try await cases.snapshot().profiles.first { $0.kind == .person })
    _ = try await cases.addLink(from: primary.id, to: person.id, label: "Fictional context")
    _ = try await cases.organize(
      entryID: primary.id, categories: ["Drinks"], profileIDs: [person.id])
    return try await cases.updateEntry(id: primary.id, text: "Fictional corrected tea preference")
  }

  @Test func editedExcerptKeepsProfilesOfItsRetainedSources() async throws {
    let cases = PersonalMemoryUseCases(repository: Step2MemoryRepository())
    _ = try await cases.createProfile(kind: .project, name: "Cedar")
    _ = try await cases.createProfile(kind: .person, name: "Mira")
    let initial = try await cases.snapshot()
    let cedar = try #require(initial.profiles.first { $0.name == "Cedar" })
    let mira = try #require(initial.profiles.first { $0.name == "Mira" })
    let conversation = UUID()
    let first = PersonalMemorySource(
      conversationID: conversation, text: "My goal is finish Cedar", kind: .goal)
    _ = try await cases.ingest(source: first)
    let before = try await cases.snapshot()
    let summary = try #require(before.entries.first { $0.kind == .summary })
    _ = try await cases.updateEntry(id: summary.id, text: "Owner correction about Cedar")
    for day in 1...6 {
      _ = try await cases.ingest(
        source: PersonalMemorySource(
          conversationID: conversation, text: "My goal is meet Mira day \(day)", kind: .goal))
    }
    let final = try await cases.snapshot()
    let edited = try #require(final.entries.first { $0.id == summary.id })
    #expect(edited.sourceIDs == [first.id])
    #expect(edited.profileIDs.contains(cedar.id))
    #expect(!edited.profileIDs.contains(mira.id))
  }

  @Test func corruptFileNeverOverwritesPreviousBytesOnRead() async throws {
    let folder = URL.temporaryDirectory.appending(path: "step2-corrupt-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appending(path: "memory.json")
    let corrupt = Data("{broken fictional archive".utf8)
    try corrupt.write(to: url)
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    await #expect(throws: PersonalMemoryError.storage) { try await cases.snapshot() }
    #expect(try Data(contentsOf: url) == corrupt)
    await #expect(throws: PersonalMemoryError.storage) {
      try await cases.ingest(source: PersonalMemorySource(text: "I prefer tea", kind: .preference))
    }
    #expect(try Data(contentsOf: url) == corrupt)
  }

  @Test func editedExcerptFollowsSupportedEntryOrganizationUnlessOwnerOverridesIt() async throws {
    let cases = PersonalMemoryUseCases(repository: Step2MemoryRepository())
    _ = try await cases.createProfile(kind: .project, name: "Cedar")
    _ = try await cases.createProfile(kind: .person, name: "Mira")
    let initial = try await cases.snapshot()
    let cedar = try #require(initial.profiles.first { $0.name == "Cedar" })
    let mira = try #require(initial.profiles.first { $0.name == "Mira" })
    let source = PersonalMemorySource(
      conversationID: UUID(), text: "My goal is finish Cedar", kind: .goal)
    _ = try await cases.ingest(source: source)
    let captured = try await cases.snapshot()
    let primary = try #require(captured.entries.first { $0.kind == .goal })
    let summary = try #require(captured.entries.first { $0.kind == .summary })
    _ = try await cases.updateEntry(id: summary.id, text: "Owner wording")
    let organized = try await cases.organize(
      entryID: primary.id, categories: ["Personal"], profileIDs: [mira.id])
    let following = try #require(organized.entries.first { $0.id == summary.id })
    #expect(following.sourceIDs == [source.id])
    #expect(following.profileIDs == [mira.id])
    _ = try await cases.organize(entryID: summary.id, categories: [], profileIDs: [cedar.id])
    let overridden = try await cases.organize(
      entryID: primary.id, categories: [], profileIDs: [mira.id])
    #expect(overridden.entries.first { $0.id == summary.id }?.profileIDs == [cedar.id])
  }

  @Test func validLargeCombiningGraphemesDoNotBlockOriginalIngestion() async throws {
    let cases = PersonalMemoryUseCases(repository: Step2MemoryRepository())
    let cluster = "a" + String(repeating: "\u{301}", count: 15_720)
    let text = "I prefer " + cluster + String(repeating: "b", count: 523)
    try #require(text.count > 512)
    try #require(text.utf8.count <= PersonalMemoryLimits.textBytes)
    let source = PersonalMemorySource(conversationID: UUID(), text: text, kind: .preference)
    _ = try await cases.ingest(source: source)
    let snapshot = try await cases.snapshot()
    #expect(snapshot.sources.first?.text.utf8.elementsEqual(text.utf8) == true)
    #expect(snapshot.entries.contains { $0.kind == .summary })
    try snapshot.validate()
  }

  @Test func rollingExcerptStaysBoundedAcrossLargeCombiningSources() async throws {
    let cases = PersonalMemoryUseCases(repository: Step2MemoryRepository())
    let conversation = UUID()
    let cluster = "a" + String(repeating: "\u{301}", count: 30)
    let text = "I prefer " + String(repeating: cluster, count: 524)
    try #require(text.utf8.count <= PersonalMemoryLimits.textBytes)
    var sourceIDs: [UUID] = []
    for _ in 1...6 {
      let source = PersonalMemorySource(conversationID: conversation, text: text, kind: .preference)
      sourceIDs.append(source.id)
      _ = try await cases.ingest(source: source)
    }
    let snapshot = try await cases.snapshot()
    #expect(snapshot.sources.count == 6)
    let excerpt = try #require(snapshot.entries.first { $0.kind == .summary })
    #expect(excerpt.text.utf8.count <= PersonalMemoryLimits.textBytes)
    #expect(Set(excerpt.sourceIDs) == Set(sourceIDs.suffix(5)))
    try snapshot.validate()
  }

  @Test func legacyJSONReadWriteReopenAndPublicExportPreserveFullHistory() async throws {
    let cases = PersonalMemoryUseCases(repository: Step2MemoryRepository())
    let source = PersonalMemorySource(
      conversationID: UUID(), text: "I prefer cafe\u{301}",
      createdAt: Date(timeIntervalSince1970: 1_700_000_000.125), kind: .preference)
    _ = try await cases.ingest(source: source)
    let captured = try await cases.snapshot()
    let primary = try #require(captured.entries.first { $0.kind == .preference })
    _ = try await cases.createProfile(kind: .person, name: "Mira", aliases: ["ميرا"])
    let profiled = try await cases.snapshot()
    let mira = try #require(profiled.profiles.first { $0.kind == .person })
    _ = try await cases.addLink(from: primary.id, to: mira.id, label: "Fictional context")
    _ = try await cases.organize(
      entryID: primary.id, categories: ["Coffee"], profileIDs: [mira.id])
    _ = try await cases.setPhoto(profileID: mira.id, data: Data([1, 2, 3]), origin: .supplied)
    for edit in 0..<8 {
      _ = try await cases.updateEntry(id: primary.id, text: "Fictional correction \(edit)")
    }
    _ = try await cases.updateEntry(id: primary.id, text: "I prefer cafe\u{301}")
    _ = try await cases.updateEntry(id: primary.id, text: "I prefer café")
    let legacy = try await cases.snapshot()
    let folder = URL.temporaryDirectory.appending(path: "step2-legacy-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appending(path: "memory.json")
    let oldBytes = try JSONEncoder().encode(legacy)
    try oldBytes.write(to: url, options: .atomic)
    let reopened = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    #expect(try await reopened.snapshot() == legacy)
    #expect(try Data(contentsOf: url) == oldBytes)
    let edited = try await reopened.updateEntry(id: primary.id, text: "Fictional migrated edit")
    let migrated = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    #expect(try await migrated.snapshot() == edited)
    let publicExport = try await migrated.exportArchive()
    #expect(try JSONDecoder().decode(PersonalMemorySnapshot.self, from: publicExport) == edited)
    let undone = try await migrated.undo()
    #expect(undone.sources == legacy.sources)
    #expect(undone.entries == legacy.entries)
    #expect(undone.profiles == legacy.profiles)
    #expect(undone.links == legacy.links)
    #expect(undone.events == legacy.events)
    #expect(undone.photos == legacy.photos)
  }

  @Test(arguments: [
    "negative-entry", "entry-overflow", "profile-overflow", "link-overflow",
    "classification-overflow", "duplicate-entry", "unused-entry", "too-many-graph-entries",
    "unknown-version", "nested-history",
  ])
  func pooledArchiveRejectsTamperedReferencesWithoutChangingFile(mutation: String) async throws {
    let folder = URL.temporaryDirectory.appending(path: "step2-pools-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appending(path: "memory.json")
    let original = try await storedFixture(at: url)
    var object = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    try #require(object["storageVersion"] as? Int == 2)
    var events = try #require(object["events"] as? [[String: Any]])
    var event = try #require(events.last)
    var graph = try #require(event["before"] as? [String: Any])
    let entryReferences = try #require(graph["entries"] as? [Int])
    let entry = try #require(entryReferences.first)
    switch mutation {
    case "negative-entry": graph["entries"] = [-1]
    case "entry-overflow": graph["entries"] = [(object["entries"] as? [Any])?.count ?? 0]
    case "profile-overflow": graph["profiles"] = [(object["profiles"] as? [Any])?.count ?? 0]
    case "link-overflow": graph["links"] = [(object["links"] as? [Any])?.count ?? 0]
    case "classification-overflow":
      graph["classifications"] = (object["classifications"] as? [Any])?.count ?? 0
    case "duplicate-entry": graph["entries"] = [entry, entry]
    case "unused-entry":
      var pool = try #require(object["entries"] as? [[String: Any]])
      pool.append(try #require(pool.first))
      object["entries"] = pool
    case "too-many-graph-entries":
      graph["entries"] = Array(repeating: entry, count: PersonalMemoryLimits.entries + 1)
    case "unknown-version": object["storageVersion"] = 999
    case "nested-history":
      var snapshot = try #require(object["snapshot"] as? [String: Any])
      let plain = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
      snapshot["events"] = plain["events"]
      object["snapshot"] = snapshot
    default: Issue.record("Unknown test mutation")
    }
    event["before"] = graph
    events[events.count - 1] = event
    object["events"] = events
    let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try tampered.write(to: url, options: .atomic)
    let repository = FilePersonalMemoryRepository(url: url)
    await #expect(throws: (any Error).self) { try await repository.load() }
    #expect(try Data(contentsOf: url) == tampered)
  }

  @Test func pooledArchiveFailedSaveRollsBackStateAndCanRetry() async throws {
    let folder = URL.temporaryDirectory.appending(path: "step2-failed-save-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appending(path: "memory.json")
    let original = try await storedFixture(at: url)
    let cases = PersonalMemoryUseCases(repository: FilePersonalMemoryRepository(url: url))
    #expect(try await cases.snapshot() == original)
    let entry = try #require(original.entries.first { $0.kind == .preference })
    let retained = folder.appending(path: "retained.json")
    try FileManager.default.moveItem(at: url, to: retained)
    let before = try Data(contentsOf: retained)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    let marker = url.appending(path: "marker")
    try Data("fictional obstruction".utf8).write(to: marker)
    await #expect(throws: PersonalMemoryError.storage) {
      try await cases.updateEntry(id: entry.id, text: "Fictional failed correction")
    }
    #expect(try await cases.snapshot() == original)
    #expect(try Data(contentsOf: retained) == before)
    #expect(try String(contentsOf: marker, encoding: .utf8) == "fictional obstruction")
    try FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: retained, to: url)
    let reopened = FilePersonalMemoryRepository(url: url)
    #expect(try await reopened.load() == original)
    let retry = try await cases.updateEntry(id: entry.id, text: "Fictional retry correction")
    #expect(try await FilePersonalMemoryRepository(url: url).load() == retry)
  }

  @Test func pooledArchiveBoundsExpansionBeforeFinalGraphValidation() async throws {
    let folder = URL.temporaryDirectory.appending(path: "step2-expansion-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appending(path: "memory.json")
    _ = try await storedFixture(at: url)
    var object = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var event = try #require((object["events"] as? [[String: Any]])?.last)
    var graph = try #require(event["before"] as? [String: Any])
    let entry = try #require((graph["entries"] as? [Int])?.first)
    graph["entries"] = Array(repeating: entry, count: PersonalMemoryLimits.entries)
    event["before"] = graph
    object["events"] = (0..<PersonalMemoryLimits.retainedEvents).map { _ -> [String: Any] in
      var copy = event
      copy["id"] = UUID().uuidString
      return copy
    }
    let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try #require(tampered.count < 2 * 1024 * 1024)
    try tampered.write(to: url, options: .atomic)
    // Duplicate graph IDs would fail later semantic validation. The expansion budget must
    // stop reconstruction first, while each graph stays inside its individual count limit.
    await #expect(throws: PersonalMemoryError.limitReached) {
      try await FilePersonalMemoryRepository(url: url).load()
    }
    #expect(try Data(contentsOf: url) == tampered)
  }
}
