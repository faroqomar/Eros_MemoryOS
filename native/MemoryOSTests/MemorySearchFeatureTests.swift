import Foundation
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

private actor SearchCollectionStore {
  var value: MemorySearchCollection
  init(_ value: MemorySearchCollection) { self.value = value }
  func read() -> MemorySearchCollection { value }
  func replace(_ value: MemorySearchCollection) { self.value = value }
}

private actor CancellableSearchProbe: MemorySearching {
  private var started = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  func waitUntilStarted() async {
    if started { return }
    await withCheckedContinuation { waiters.append($0) }
  }
  func search(query: String, records: [MemorySearchRecord], limit: Int) async throws
    -> [MemorySearchHit]
  {
    started = true
    for waiter in waiters { waiter.resume() }
    waiters = []
    try await Task.sleep(for: .seconds(30))
    return []
  }
}

private actor SearchProviderProbe: MemorySearching {
  var supplied: [MemorySearchHit]?
  private(set) var calls = 0
  var onSearch: (@Sendable () async -> Void)?
  init(_ supplied: [MemorySearchHit]? = nil, onSearch: (@Sendable () async -> Void)? = nil) {
    self.supplied = supplied
    self.onSearch = onSearch
  }
  func search(query: String, records: [MemorySearchRecord], limit: Int) async throws
    -> [MemorySearchHit]
  {
    calls += 1
    await onSearch?()
    if let supplied { return supplied }
    return records.filter { $0.text.localizedStandardContains(query) }.prefix(limit).map {
      MemorySearchHit(sourceID: $0.id, score: 1, matchedText: $0.text)
    }
  }
}

private func searchDocument(_ text: String, id: UUID = UUID()) -> MemorySearchDocument {
  .init(
    id: id, text: text, kind: .original, date: Date(timeIntervalSince1970: 1),
    originalText: nil, detail: "originalStatement", destination: .source(id))
}

struct MemorySearchFeatureTests {
  @MainActor @Test(arguments: [false, true])
  func cancelOrInputEditStopsTheOldSearch(changeQuery: Bool) async throws {
    let provider = CancellableSearchProbe()
    let collection = MemorySearchCollection(documents: [searchDocument("Morning")], connections: [])
    let model = MemorySearchViewModel(
      useCases: .init(
        keyword: provider, semantic: provider, readCollection: { collection }))
    model.query = "Morning"
    let running = Task { await model.search() }
    await provider.waitUntilStarted()
    if changeQuery { model.query = "Evening" } else { model.cancel() }
    await running.value
    #expect(!model.isBusy && model.results.isEmpty && !model.searched && model.failure == nil)
  }
  @Test func keywordAndSemanticCallOnlyTheirSelectedProvider() async throws {
    let document = searchDocument("Quiet mornings")
    let store = SearchCollectionStore(.init(documents: [document], connections: []))
    let keyword = SearchProviderProbe()
    let semantic = SearchProviderProbe([.init(sourceID: document.id.uuidString, score: 0.8)])
    let useCases = MemorySearchUseCases(
      keyword: keyword, semantic: semantic, readCollection: { await store.read() })
    #expect(try await useCases.search(query: "Quiet", mode: .keyword).map(\.id) == [document.id])
    #expect(await keyword.calls == 1)
    #expect(await semantic.calls == 0)
    #expect(
      try await useCases.search(query: "calm start", mode: .semantic).map(\.id) == [document.id])
    #expect(await keyword.calls == 1)
    #expect(await semantic.calls == 1)
  }

  @Test func linkedSearchFollowsRealDirectEdgesAndLabelsNeighbors() async throws {
    let seed = searchDocument("Mira")
    let neighbor = searchDocument("We agreed on Saturday")
    let unrelated = searchDocument("A separate project")
    let collection = MemorySearchCollection(
      documents: [seed, neighbor, unrelated],
      connections: [
        .init(from: seed.id, to: neighbor.id, label: "commitment")
      ])
    let useCases = MemorySearchUseCases(
      keyword: SearchProviderProbe(), semantic: SearchProviderProbe(),
      readCollection: { collection })
    let results = try await useCases.search(query: "Mira", mode: .linked)
    #expect(results.map(\.id) == [seed.id, neighbor.id])
    #expect(results.last?.connection == "commitment")
    #expect(results.last?.passage == neighbor.text)
  }

  @Test(arguments: ["changed", "deleted", "contextChanged"])
  func updatesDuringRankingRejectStaleEvidence(change: String) async throws {
    let original = searchDocument("Meet on Friday")
    let collection = MemorySearchCollection(documents: [original], connections: [])
    let store = SearchCollectionStore(collection)
    let provider = SearchProviderProbe(onSearch: {
      var updated = collection
      if change == "deleted" {
        updated.documents = []
      } else if change == "contextChanged" {
        updated.connections = [.init(from: original.id, to: original.id, label: "new correction")]
      } else {
        updated.documents = [searchDocument("Meet on Saturday", id: original.id)]
      }
      await store.replace(updated)
    })
    let useCases = MemorySearchUseCases(
      keyword: provider, semantic: provider, readCollection: { await store.read() })
    await #expect(throws: MemorySearchFailure.changed) {
      try await useCases.search(query: "Meet", mode: .keyword)
    }
  }

  @Test(arguments: ["unknownID", "inventedPassage", "invalidScore"])
  func invalidProviderEvidenceNeverReachesResults(failure: String) async throws {
    let document = searchDocument("Exact original")
    let collection = MemorySearchCollection(documents: [document], connections: [])
    let hit = MemorySearchHit(
      sourceID: (failure == "unknownID" ? UUID() : document.id).uuidString,
      score: failure == "invalidScore" ? .infinity : 1,
      matchedText: failure == "inventedPassage" ? "Invented original" : document.text)
    let provider = SearchProviderProbe([hit])
    let useCases = MemorySearchUseCases(
      keyword: provider, semantic: provider, readCollection: { collection })
    await #expect(throws: MemorySearchFailure.invalidResult) {
      try await useCases.search(query: "original", mode: .keyword)
    }
  }

  @MainActor @Test func viewModelClearsPriorResultsWhenQueryOrModeChanges() async throws {
    let document = searchDocument("Morning plans")
    let collection = MemorySearchCollection(documents: [document], connections: [])
    let model = MemorySearchViewModel(
      useCases: MemorySearchUseCases(
        keyword: SearchProviderProbe(), semantic: SearchProviderProbe(),
        readCollection: { collection }))
    model.query = "Morning"
    await model.search()
    #expect(model.results.map(\.id) == [document.id])
    model.mode = .semantic
    #expect(model.results.isEmpty)
    #expect(!model.searched)
    model.query = "unrelated"
    await model.search()
    #expect(model.results.isEmpty)
    #expect(model.searched)
    #expect(model.failure == nil)
  }

  @MainActor @Test func failedReloadRemovesGraphAndSearchEvidence() async throws {
    let document = searchDocument("Morning plans")
    let collection = MemorySearchCollection(documents: [document], connections: [])
    let store = SearchFailingCollectionStore(collection)
    let provider = SearchProviderProbe()
    let model = MemorySearchViewModel(
      useCases: MemorySearchUseCases(
        keyword: provider, semantic: provider, readCollection: { try await store.read() }))
    model.query = "Morning"
    await model.search()
    #expect(!model.graph.documents.isEmpty)
    await store.setFailure()
    await model.load()
    #expect(model.graph.documents.isEmpty)
    #expect(model.results.isEmpty)
    #expect(model.failure == .unavailable)
  }

  @Test func graphUsesRealSourceContextAndExcludesTrash() async throws {
    let useCases = PersonalMemoryUseCases(repository: SearchPersonalRepository())
    let conversation = UUID()
    let earlier = PersonalMemorySource(
      conversationID: conversation, text: "My first view",
      createdAt: Date(timeIntervalSince1970: 1), kind: .interpretation)
    let later = PersonalMemorySource(
      conversationID: conversation, text: "A later clarification",
      createdAt: Date(timeIntervalSince1970: 2), kind: .fact)
    _ = try await useCases.ingest(source: earlier)
    _ = try await useCases.resolve(sourceID: earlier.id, kind: .interpretation)
    _ = try await useCases.ingest(source: later)
    let personal = try await useCases.resolve(sourceID: later.id, kind: .fact)
    let deleted = LocalRecord(
      kind: .capture, originalText: "removed", text: "removed", deletedAt: Date())
    let graph = MemorySearchCollection.make(personal: personal, local: .init(records: [deleted]))
    #expect(graph.document(deleted.id) == nil)
    #expect(graph.document(earlier.id)?.contextIDs == [earlier.id, later.id])
    let hypothesis = try #require(personal.entries.first { $0.kind == .interpretation })
    #expect(graph.document(hypothesis.id)?.kind == .confirmedInterpretation)
    #expect(graph.document(hypothesis.id)?.contextIDs == [earlier.id])
    #expect(graph.connections(to: hypothesis.id).contains { $0.1.id == earlier.id })
    #expect(graph.document(earlier.id)?.text == "My first view")
    let corrected = try await useCases.updateEntry(
      id: hypothesis.id, text: "My confirmed interpretation")
    let correctedGraph = MemorySearchCollection.make(personal: corrected, local: .init())
    #expect(correctedGraph.document(hypothesis.id)?.kind == .confirmedInterpretation)
    #expect(correctedGraph.document(earlier.id)?.text == "My first view")
  }
}

private actor SearchFailingCollectionStore {
  let value: MemorySearchCollection
  var failed = false
  init(_ value: MemorySearchCollection) { self.value = value }
  func setFailure() { failed = true }
  func read() throws -> MemorySearchCollection {
    if failed { throw MemorySearchFailure.unavailable }
    return value
  }
}

private actor SearchPersonalRepository: PersonalMemoryRepository {
  var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ snapshot: PersonalMemorySnapshot) { value = snapshot }
}
