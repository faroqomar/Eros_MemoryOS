import ChatCore
import Foundation
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

struct ChatIntegrationTests {
  @Test(arguments: ["ماذا أيضًا؟", "ماذا ايضا؟", "مَاذَا أَيْضًا؟", "ماذا ا\u{654}يضا؟"])
  func arabicFollowUpVariantsKeepTheEarlierTopicAndOriginalQuestionBytes(query: String) {
    let prior = "متى موعد ميرا؟"
    let resolved = LocalChatMemory.resolvedQuery(
      query, previousQuestions: [prior, "شنو بعد؟"])
    #expect(Data(resolved.utf8) == Data((prior + "\n" + query).utf8))
    let explicit = query + " عن نور"
    #expect(LocalChatMemory.resolvedQuery(explicit, previousQuestions: [prior]) == explicit)
  }

  @Test func latestTopicWinsOverEarlierReferences() {
    #expect(
      LocalChatMemory.resolvedQuery("What about Noor?", previousQuestions: ["What about Zain?"])
        == "What about Noor?")
    #expect(
      LocalChatMemory.resolvedQuery("What else about him?", previousQuestions: ["What about Zain?"])
        == "What about Zain?\nWhat else about him?")
    #expect(
      LocalChatMemory.resolvedQuery("شنو بعد؟", previousQuestions: ["موعد علي؟"]).contains(
        "موعد علي"))
  }

  @Test func retrievalSnapshotUsesCorrectionsAndExcludesTrash() {
    let ali = UUID()
    let records = [
      LocalRecord(
        id: ali, kind: .capture, originalText: "Ali meeting Friday", text: "Ali meeting Monday"),
      LocalRecord(
        kind: .capture, originalText: "Ali secret", text: "Ali secret", deletedAt: Date()),
    ]
    let evidence = LocalChatMemory.records(local: records, personal: nil)
    #expect(evidence.map(\.id) == [ali.uuidString])
    #expect(evidence[0].text.contains("Monday"))
    #expect(!evidence[0].text.contains("Friday"))
  }

  @Test func changedOrDeletedRecordsAreRejectedAfterProviderSearch() async throws {
    let id = UUID()
    let original = MemorySearchRecord(id: id.uuidString, text: "Old personal value")
    let reads = RecallSnapshots([
      [original], [MemorySearchRecord(id: id.uuidString, text: "Corrected value")],
    ])
    let memory = LocalChatMemory(
      search: RecallSearchStub(hits: [.init(sourceID: id.uuidString, score: 1)]),
      readRecords: { await reads.next() })
    #expect(try await memory.retrieve(query: "personal value").isEmpty)
    let deleted = RecallSnapshots([[original], []])
    let deletionMemory = LocalChatMemory(
      search: RecallSearchStub(hits: [.init(sourceID: id.uuidString, score: 1)]),
      readRecords: { await deleted.next() })
    #expect(try await deletionMemory.retrieve(query: "personal value").isEmpty)
  }

  @Test func currentMessageCannotRetrieveItselfAndUnknownIDsAreRejected() async throws {
    let id = UUID()
    let records = [MemorySearchRecord(id: id.uuidString, text: "current query")]
    let memory = LocalChatMemory(
      search: RecallSearchStub(hits: [
        .init(sourceID: id.uuidString, score: 1), .init(sourceID: UUID().uuidString, score: 1),
      ]),
      readRecords: { records })
    #expect(
      try await memory.retrieve(query: "current query", previousQuestions: [], excluding: [id])
        .isEmpty)
  }

  @Test func partialOrganizationKeepsTheWholeOriginalSearchable() async throws {
    let useCases = PersonalMemoryUseCases(repository: RecallPersonalRepository())
    let source = PersonalMemorySource(text: "I like tea. Maybe I should move.")
    _ = try await useCases.ingest(source: source)
    let input = try #require(try await useCases.nextAnalysisInput())
    _ = try await useCases.applyAnalysis(
      PersonalMemoryAnalysis(
        memories: [.init(quote: "I like tea.", kind: .preference)],
        deferredQuotes: ["Maybe I should move."]), input: input)
    let records = LocalChatMemory.records(local: [], personal: try await useCases.snapshot())
    #expect(records.contains { $0.id == source.id.uuidString && $0.text.contains(source.text) })
  }

  @Test func correctedEntryLinksHistoricalOriginalToCurrentValue() async throws {
    let useCases = PersonalMemoryUseCases(repository: RecallPersonalRepository())
    let source = PersonalMemorySource(text: "Work starts at nine", kind: .fact)
    _ = try await useCases.ingest(source: source)
    let entry = try #require(try await useCases.snapshot().currentEntries.first)
    _ = try await useCases.updateEntry(
      id: entry.id, text: "Work starts at ten", confirmedChange: true)
    let snapshot = LocalChatMemory.makeSnapshot(local: [], personal: try await useCases.snapshot())
    #expect(snapshot.replacements[source.id.uuidString] == [entry.id.uuidString])
    #expect(
      snapshot.records.first(where: { $0.id == source.id.uuidString })?.text.contains(
        "not a current fact") == true)
  }

  @Test func indexingMetadataAndLookupQueryAreBoundedWithoutEditingOriginals() async throws {
    let original = String(repeating: "a", count: LocalMemoryLimits.textUTF8Bytes)
    let records = LocalChatMemory.records(
      local: [LocalRecord(kind: .capture, originalText: original, text: original)], personal: nil)
    #expect(records[0].text.hasSuffix(original))
    #expect(records[0].text.utf8.count <= 101000)
    let query = LocalChatMemory.boundedQuery("START\0" + original + "END")
    #expect(query.hasPrefix("START "))
    #expect(query.hasSuffix("END"))
    #expect(query.utf8.count <= 4096)
  }

  @Test func latePassageKeepsMeaningLabelAndFabricatedPassageIsRejected() async throws {
    let id = UUID()
    let passage = "A fictional captain sails to Basra."
    let source = MemorySearchRecord(
      id: id.uuidString,
      text: "[original statement; rolePlay; not a confirmed fact] "
        + String(repeating: "Earlier text. ", count: 200) + passage)
    let memory = LocalChatMemory(
      search: RecallSearchStub(hits: [
        .init(sourceID: id.uuidString, score: 1, matchedText: passage)
      ]),
      readRecords: { [source] })
    let result = try await memory.retrieve(query: "Where does the captain sail?")
    #expect(result.first?.text.contains("rolePlay") == true)
    #expect(result.first?.text.contains(passage) == true)
    let fabricated = LocalChatMemory(
      search: RecallSearchStub(hits: [
        .init(sourceID: id.uuidString, score: 1, matchedText: "Invented source")
      ]),
      readRecords: { [source] })
    #expect(try await fabricated.retrieve(query: "captain").isEmpty)
  }

  @Test func relevanceChecksEightCandidatesBeforeReturningAtMostThree() async throws {
    let records = (0..<8).map {
      MemorySearchRecord(id: UUID().uuidString, text: "Fictional record \($0)")
    }
    let selected = Set(records.suffix(4).compactMap { UUID(uuidString: $0.id) })
    let search = RecallCandidateSearch(records: records)
    let filter = RecallFilter { candidates in
      #expect(candidates.count == 8)
      return selected
    }
    let memory = LocalChatMemory(search: search, relevance: filter, readRecords: { records })
    let evidence = try await memory.retrieve(query: "Fictional topic")
    #expect(await search.limit == 8)
    #expect(
      evidence.map(\.id) == records.suffix(4).prefix(3).compactMap { UUID(uuidString: $0.id) })
  }

  @Test(arguments: [true, false])
  func changesDuringRelevanceVerificationCannotLeakStaleSources(deleted: Bool) async throws {
    let id = UUID()
    let record = MemorySearchRecord(id: id.uuidString, text: "Old value")
    let state = MutableRecallRecords([record])
    let filter = RecallFilter { _ in
      await state.replace(deleted ? [] : [.init(id: id.uuidString, text: "Corrected value")])
      return [id]
    }
    let memory = LocalChatMemory(
      search: RecallSearchStub(hits: [.init(sourceID: id.uuidString, score: 0.2)]),
      relevance: filter, readRecords: { await state.records })
    #expect(try await memory.retrieve(query: "value").isEmpty)
  }

  @Test func unrelatedAndInventedRelevanceResultsCannotBecomeEvidence() async throws {
    let id = UUID()
    let records = [MemorySearchRecord(id: id.uuidString, text: "Lina likes tea.")]
    let search = RecallSearchStub(hits: [.init(sourceID: id.uuidString, score: 0.99)])
    let rejected = LocalChatMemory(
      search: search, relevance: RecallFilter { _ in [] }, readRecords: { records })
    #expect(try await rejected.retrieve(query: "Lina bank account?").isEmpty)
    let invented = LocalChatMemory(
      search: search, relevance: RecallFilter { _ in [UUID()] }, readRecords: { records })
    await #expect(throws: (any Error).self) { try await invented.retrieve(query: "Lina?") }
  }

  @Test func renderBlocksPreserveParagraphsListsAndCode() {
    let result = ChatFormatting.blocks(
      "First **bold** paragraph.\n\n- One\n2. Two\n\n```swift\nlet name = \"علي\"\n```\n\nLast.")
    #expect(result.count == 5)
    #expect(result[0].text == "First **bold** paragraph.")
    #expect(result[1].kind == .list("•"))
    #expect(result[2].kind == .list("2."))
    #expect(result[3].kind == .code("swift"))
    #expect(result[3].text == "let name = \"علي\"")
    #expect(result[4].text == "Last.")
    #expect(
      String(ChatFormatting.inline("**bold** and *emphasis*").characters) == "bold and emphasis")
  }

  @Test func unfinishedFenceRemainsReadableWhileStreaming() {
    let result = ChatFormatting.blocks("```\nprint(\"hello\")")
    #expect(result.count == 1)
    #expect(result.first?.kind == .code(""))
    #expect(result.first?.text == "print(\"hello\")")
  }
}

private actor RecallSnapshots {
  var snapshots: [[MemorySearchRecord]]
  init(_ snapshots: [[MemorySearchRecord]]) { self.snapshots = snapshots }
  func next() -> [MemorySearchRecord] {
    snapshots.count > 1 ? snapshots.removeFirst() : snapshots[0]
  }
}

private struct RecallSearchStub: MemorySearching {
  let hits: [MemorySearchHit]
  func search(query: String, records: [MemorySearchRecord], limit: Int) async throws
    -> [MemorySearchHit]
  { hits }
}

private actor RecallPersonalRepository: PersonalMemoryRepository {
  var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) { value = snapshot }
}

private struct RecallFilter: MemoryEvidenceFiltering {
  let evaluate: @Sendable ([ChatEvidence]) async throws -> Set<UUID>
  func selectRelevant(query: String, candidates: [ChatEvidence]) async throws -> Set<UUID> {
    try await evaluate(candidates)
  }
}

private actor MutableRecallRecords {
  var records: [MemorySearchRecord]
  init(_ records: [MemorySearchRecord]) { self.records = records }
  func replace(_ records: [MemorySearchRecord]) { self.records = records }
}

private actor RecallCandidateSearch: MemorySearching {
  let records: [MemorySearchRecord]
  var limit: Int?
  init(records: [MemorySearchRecord]) { self.records = records }
  func search(query: String, records: [MemorySearchRecord], limit: Int) async throws
    -> [MemorySearchHit]
  {
    self.limit = limit
    return self.records.prefix(limit).map { .init(sourceID: $0.id, score: 0.1) }
  }
}
