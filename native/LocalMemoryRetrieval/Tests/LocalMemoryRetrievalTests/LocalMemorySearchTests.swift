import Foundation
import LocalMemoryRetrieval
import RetrievalCore
import Testing

@testable import CactusMemoryRuntime

actor RecordingIndex: RecallIndex {
  var records: [MemorySearchRecord] = []
  var rebuilds = 0
  var invalid = false
  var failsClose = false
  var closes = 0
  func rebuild(records: [MemorySearchRecord]) {
    self.records = records
    rebuilds += 1
  }
  func search(query: String, limit: Int) -> [MemorySearchHit] {
    if invalid { return [.init(sourceID: "unknown", score: .nan)] }
    return records.filter { $0.text.contains(query) }.prefix(limit).map {
      .init(sourceID: $0.id, score: 1)
    }
  }
  func setInvalid() { invalid = true }
  func setCloseFailure() { failsClose = true }
  func close() throws {
    closes += 1
    if failsClose { throw RetrievalError.unavailable("Fixture close failure") }
    records = []
  }
}

@Suite(.serialized)
struct LocalMemorySearchTests {
  @Test func keepsCanonicallyEquivalentButByteDistinctSourceIDs() async throws {
    let search = LocalMemorySearch(indexes: [RecordingIndex()])
    let ids = ["é", "e\u{301}"]
    let result = try await search.search(
      query: "Amber", records: ids.map { .init(id: $0, text: "Amber notebook") }, limit: 3)
    #expect(Set(result.map { Data($0.sourceID.utf8) }) == Set(ids.map { Data($0.utf8) }))
  }

  @Test func closeAttemptsRemainingProvidersAfterFailure() async throws {
    let first = RecordingIndex()
    let second = RecordingIndex()
    await first.setCloseFailure()
    let search = LocalMemorySearch(indexes: [first, second])
    await #expect(throws: RetrievalError.self) { try await search.close() }
    #expect(await first.closes == 1)
    #expect(await second.closes == 1)
  }

  @Test func unchangedSnapshotReusesIndexButCorrectionsAndDeletionsRebuild() async throws {
    let index = RecordingIndex()
    let actual = LocalMemorySearch(indexes: [index])
    let records = [
      MemorySearchRecord(id: "a", text: "Birthday December"),
      .init(id: "b", text: "Copper lantern"),
    ]
    #expect(
      try await actual.search(query: "December", records: records, limit: 3).map(\.sourceID) == [
        "a"
      ])
    _ = try await actual.search(query: "Copper", records: records, limit: 3)
    #expect(await index.rebuilds == 1)
    #expect(
      try await actual.search(
        query: "December", records: [.init(id: "a", text: "Birthday September")], limit: 3
      ).isEmpty)
    #expect(
      try await actual.search(
        query: "Copper", records: [.init(id: "a", text: "Birthday September")], limit: 3
      ).isEmpty)
    #expect(await index.rebuilds == 2)
  }

  @Test func chunksPreserveOriginalBytesAndDeduplicateToCanonicalID() async throws {
    let index = RecordingIndex()
    let actual = LocalMemorySearch(indexes: [index])
    let text = String(repeating: "دفتر أزرق ", count: 400)
    let hits = try await actual.search(
      query: "دفتر", records: [.init(id: "عربي", text: text)], limit: 3)
    let chunks = await index.records
    #expect(hits.map(\.sourceID) == ["عربي"])
    #expect(chunks.allSatisfy { $0.text.utf8.count <= 1200 })
    #expect(Data(chunks.map(\.text).joined().utf8) == Data(text.utf8))
  }

  @Test func supportsLegalCombinedCountLongSourcesAndNullSegments() async throws {
    let index = RecordingIndex()
    let search = LocalMemorySearch(indexes: [index])
    var records = (0..<29999).map { MemorySearchRecord(id: "r\($0)", text: "Fictional note") }
    let long = String(repeating: "a", count: 100000) + "\0endmarker"
    records.append(.init(id: "long", text: long))
    let hits = try await search.search(query: "\0endmarker\0", records: records, limit: 3)
    // The stub observes cleaned lookup text; canonical segments remain unchanged.
    #expect(hits.isEmpty)
    let direct = try await search.search(query: "endmarker", records: records, limit: 3)
    #expect(direct.map(\.sourceID) == ["long"])
    #expect(direct.first?.matchedText == "endmarker")
    #expect(await index.records.allSatisfy { !$0.text.utf8.contains(0) })
  }

  @Test func rejectsUnknownIDsInvalidScoresDuplicateSourcesAndMissingSemanticAsset() async throws {
    let index = RecordingIndex()
    await index.setInvalid()
    let search = LocalMemorySearch(indexes: [index])
    await #expect(throws: RetrievalError.self) {
      _ = try await search.search(query: "book", records: [.init(id: "a", text: "book")], limit: 3)
    }
    await #expect(throws: RetrievalError.self) {
      _ = try await search.search(
        query: "book", records: [.init(id: "a", text: "book"), .init(id: "a", text: "other")],
        limit: 3)
    }
    let missing = LocalMemorySearch(directory: temporaryRoot(), cactusModelDirectory: nil)
    await #expect(throws: RetrievalError.self) {
      _ = try await missing.search(query: "book", records: [.init(id: "a", text: "book")], limit: 3)
    }
  }

  @Test func processLockProtectsLiveIndexesAndColdStartRemovesOnlyOwnedOrphans() async throws {
    let directory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: directory) }
    let wax = directory.appendingPathComponent("wax")
    try FileManager.default.createDirectory(
      at: wax.appendingPathComponent("memoryos-wax-recall-old"), withIntermediateDirectories: true)
    let preserved = wax.appendingPathComponent("original.txt")
    try Data("preserve".utf8).write(to: preserved)
    let first = LocalMemorySearch(directory: directory, cactusModelDirectory: nil, provider: .wax)
    let second = LocalMemorySearch(directory: directory, cactusModelDirectory: nil, provider: .wax)
    let records = [MemorySearchRecord(id: "a", text: "Amber notebook")]
    _ = try await first.search(query: "Amber", records: records, limit: 3)
    #expect(
      !FileManager.default.fileExists(
        atPath: wax.appendingPathComponent("memoryos-wax-recall-old").path))
    await #expect(throws: RetrievalError.busy) {
      _ = try await second.search(query: "Amber", records: records, limit: 3)
    }
    #expect(
      try await first.search(query: "Amber", records: records, limit: 3).map(\.sourceID) == ["a"])
    try await first.close()
    #expect(
      try await second.search(query: "Amber", records: records, limit: 3).map(\.sourceID) == ["a"])
    try await second.close()
    #expect(try Data(contentsOf: preserved) == Data("preserve".utf8))
  }

  @Test func cancelledSearchDoesNotBuildOrReturnResults() async throws {
    let index = RecordingIndex()
    let actual = LocalMemorySearch(indexes: [index])
    let task = Task {
      while !Task.isCancelled { await Task.yield() }
      return try await actual.search(
        query: "book", records: [.init(id: "a", text: "book")], limit: 3)
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { _ = try await task.value }
    #expect(await index.rebuilds == 0)
  }

  @Test func realWaxMatchesArabicAndDoesNotPersistQueryText() async throws {
    let directory = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: directory) }
    let search = LocalMemorySearch(directory: directory, cactusModelDirectory: nil, provider: .wax)
    let records = [
      MemorySearchRecord(id: "ar", text: "نور اشترت دفتر أزرق"),
      .init(id: "en", text: "Samir bought a copper lantern"),
      .init(id: "noura", text: "Noura celebrates her birthday on May 12."),
    ]
    #expect(
      try await search.search(query: "دفتر", records: records, limit: 3).map(\.sourceID) == ["ar"])
    #expect(
      try await search.search(query: "What is Noura's passport number?", records: records, limit: 3)
        .isEmpty)
    #expect(try await search.search(query: "Hi", records: records, limit: 3).isEmpty)
    let privateQuery = "PRIVATE_QUERY_65F146E2_C7AF_460F"
    #expect(try await search.search(query: privateQuery, records: records, limit: 3).isEmpty)
    for file in files(in: directory) {
      guard (try file.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else {
        continue
      }
      #expect(try Data(contentsOf: file).range(of: Data(privateQuery.utf8)) == nil)
    }
    #expect(try await search.search(query: "دفتر", records: [], limit: 3).isEmpty)
    try await search.close()
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
  func realCactusAndHybridRetrieveParaphraseAndRejectUnrelatedQuery() async throws {
    guard let path = ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] else { return }
    let records = [
      MemorySearchRecord(
        id: "travel", text: "Maya travels to her workplace on a bicycle every morning."),
      .init(id: "food", text: "Omar cannot eat peanuts because of his allergy."),
      .init(id: "noura", text: "Noura celebrates her birthday on May 12."),
      .init(id: "arabic", text: "سارة تذهب إلى العمل بالحافلة كل صباح."),
    ]
    for provider in [LocalRecallProvider.cactus, .hybrid] {
      let directory = temporaryRoot()
      let search = LocalMemorySearch(
        directory: directory, cactusModelDirectory: URL(fileURLWithPath: path), provider: provider)
      let hits = try await search.search(
        query: "How does Maya commute?", records: records, limit: 3)
      #expect(hits.first?.sourceID == "travel")
      #expect(
        try await search.search(query: "كيف تتنقل سارة إلى وظيفتها؟", records: records, limit: 3)
          .first?.sourceID == "arabic")
      for query in [
        "What is the melting point of tungsten?", "What is Noura's passport number?", "Hi",
      ] {
        #expect(try await search.search(query: query, records: records, limit: 3).isEmpty)
      }
      try await search.close()
      try? FileManager.default.removeItem(at: directory)
    }
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
  func realEmbeddingCacheReusesUnchangedChunksAndRemovesDeletedVectors() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"])
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let index = CactusRecallIndex(modelDirectory: URL(fileURLWithPath: path), indexDirectory: root)
    let first = MemorySearchRecord(id: "one", text: "Maya cycles to work.")
    try await index.rebuild(records: [first])
    #expect(await index.embeddedDocumentCount == 1)
    await index.unloadModel()
    try await index.rebuild(records: [first, .init(id: "two", text: "Omar prefers tea.")])
    #expect(await index.embeddedDocumentCount == 2)
    try await index.rebuild(records: [first, .init(id: "two", text: "Omar prefers coffee.")])
    #expect(await index.embeddedDocumentCount == 3)
    #expect(await index.cachedDocumentCount == 2)
    try await index.rebuild(records: [first])
    #expect(await index.embeddedDocumentCount == 3)
    #expect(await index.cachedDocumentCount == 1)
    _ = try await index.search(query: "Private inquiry about transport", limit: 3)
    #expect(await index.cachedDocumentCount == 1)
    try await index.rebuild(records: [])
    #expect(await index.cachedDocumentCount == 0)
    await index.close()
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
  func realHundredSourceAppendReusesDocumentVectors() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"])
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let index = CactusRecallIndex(modelDirectory: URL(fileURLWithPath: path), indexDirectory: root)
    var records = (0..<100).map {
      MemorySearchRecord(
        id: "note-\($0)",
        text: "Fictional project \($0) holds its weekly planning meeting on Tuesday.")
    }
    let clock = ContinuousClock()
    let initial = try await clock.measure { try await index.rebuild(records: records) }
    #expect(await index.embeddedDocumentCount == 100)
    await index.unloadModel()
    records.append(.init(id: "new", text: "Maya enjoys reading books about astronomy."))
    let appended = try await clock.measure { try await index.rebuild(records: records) }
    #expect(await index.embeddedDocumentCount == 101)
    print("RECALL_CACHE_METRIC initial100=\(initial) append1=\(appended) embedded_total=101")
    await index.close()
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["MEMORYOS_RECALL_SCORE_PROBE"] == "1"))
  func consumedRetrievalScoreDiagnostic() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"])
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let index = CactusRecallIndex(
      modelDirectory: URL(fileURLWithPath: path), indexDirectory: root, minimumSimilarity: -1)
    try await index.rebuild(records: [
      .init(id: "travel", text: "Maya travels to her workplace on a bicycle every morning."),
      .init(id: "food", text: "Omar cannot eat peanuts because of his allergy."),
      .init(id: "noura", text: "Noura celebrates her birthday on May 12."),
      .init(id: "arabic", text: "سارة تذهب إلى العمل بالحافلة كل صباح."),
    ])
    for (id, query) in [
      ("english-positive", "How does Maya commute?"),
      ("arabic-positive", "كيف تتنقل سارة إلى وظيفتها؟"),
      ("general-negative", "What is the melting point of tungsten?"),
      ("passport-negative", "What is Noura's passport number?"), ("greeting-negative", "Hi"),
    ] {
      let hits = try await index.search(query: query, limit: 4)
      print(
        "RECALL_SCORE \(id) " + hits.map { "\($0.sourceID)=\($0.score)" }.joined(separator: " "))
    }
    await index.close()
  }

  private func files(in directory: URL) -> [URL] {
    (FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])?
      .allObjects as? [URL]) ?? []
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "memoryos-retrieval-adapter-test-" + UUID().uuidString)
  }
}
