import ChatCore
import Foundation
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

/// Models source I/O that completes after cancellation instead of observing it immediately.
private actor LifecyclePreparationGate {
  private var entered = false
  private var released = false
  private var observers: [CheckedContinuation<Void, Never>] = []
  private var continuation: CheckedContinuation<Void, Never>?

  func hold() async {
    entered = true
    for observer in observers { observer.resume() }
    observers = []
    if !released { await withCheckedContinuation { continuation = $0 } }
  }
  func waitUntilEntered() async {
    if entered { return }
    await withCheckedContinuation { observers.append($0) }
  }
  func release() {
    released = true
    continuation?.resume()
    continuation = nil
  }
}

private actor LifecycleModelProbe: StructuredChatModel {
  private(set) var calls = 0
  private(set) var unloads = 0
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) -> String {
    calls += 1
    return "{}"
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) { calls += 1 }
  func unload() { unloads += 1 }
}

private actor LifecycleCandidateSearch: MemorySearching {
  let gate: LifecyclePreparationGate?
  private(set) var calls = 0
  init(gate: LifecyclePreparationGate? = nil) { self.gate = gate }
  func search(query: String, records: [MemorySearchRecord], limit: Int) async -> [MemorySearchHit] {
    calls += 1
    await gate?.hold()
    return records.prefix(limit).map { .init(sourceID: $0.id, score: 1, matchedText: $0.text) }
  }
}

private actor LifecyclePersonalRepository: PersonalMemoryRepository {
  let initial: PersonalMemorySnapshot
  let gate: LifecyclePreparationGate
  private(set) var saves = 0
  init(initial: PersonalMemorySnapshot, gate: LifecyclePreparationGate) {
    self.initial = initial
    self.gate = gate
  }
  func load() async -> PersonalMemorySnapshot {
    await gate.hold()
    return initial
  }
  func save(_ snapshot: PersonalMemorySnapshot) { saves += 1 }
}

/// Counts entry into the real analyzer; it does not replace its validation or model adapter.
private actor LifecycleAnalyzerProbe: RelationshipAnalyzing {
  let base: LocalRelationshipAnalyzer
  private(set) var calls = 0
  init(model: any StructuredChatModel) { base = LocalRelationshipAnalyzer(model: model) }
  func analyze(_ input: RelationshipAnalysisInput) async throws -> RelationshipAnalysisProposal {
    calls += 1
    return try await base.analyze(input)
  }
}

@Suite @MainActor struct LifecycleInferenceCancellationTests {
  @Test(arguments: [false, true])
  func cancelledSearchCannotReloadAfterHeldPreparation(holdRanking: Bool) async throws {
    let gate = LifecyclePreparationGate()
    let raw = LifecycleModelProbe()
    let coordinator = LocalInferenceCoordinator(model: raw)
    let id = UUID()
    let document = MemorySearchDocument(
      id: id, text: "Nora: We can meet on Thursday.", kind: .original, date: nil,
      originalText: nil, detail: "originalStatement", destination: .source(id))
    let collection = MemorySearchCollection(documents: [document], connections: [])
    let candidates = LifecycleCandidateSearch(gate: holdRanking ? gate : nil)
    let viewModel = MemorySearchViewModel(
      useCases: .init(
        keyword: candidates,
        semantic: LocalMeaningSearch(candidates: candidates, model: coordinator),
        readCollection: {
          if !holdRanking { await gate.hold() }
          return collection
        }))
    viewModel.query = "When can Nora meet?"
    viewModel.mode = .semantic
    let request = Task { await viewModel.search() }
    await gate.waitUntilEntered()
    // Memory warning and nonactive scene handlers cancel the parent before unloading.
    viewModel.cancel()
    await coordinator.unload()
    await gate.release()
    await request.value
    #expect(await candidates.calls == (holdRanking ? 1 : 0))
    #expect(await raw.calls == 0)
    #expect(await raw.unloads == 1)
    #expect(viewModel.results.isEmpty && !viewModel.isBusy && !viewModel.searched)
    #expect(viewModel.failure == nil)
    #expect(viewModel.query == "When can Nora meet?" && viewModel.mode == .semantic)
  }

  @Test func cancelledRelationshipPreparationCannotEnterAnalyzerOrReload() async throws {
    let gate = LifecyclePreparationGate()
    let source = PersonalMemorySource(
      text: "Nora: We can meet on Thursday.", origin: "fictional lifecycle fixture",
      kind: .conversationOnly)
    var initial = PersonalMemorySnapshot()
    initial.sources = [source]
    let repository = LifecyclePersonalRepository(initial: initial, gate: gate)
    let memory = PersonalMemoryUseCases(repository: repository)
    let raw = LifecycleModelProbe()
    let coordinator = LocalInferenceCoordinator(model: raw)
    let analyzer = LifecycleAnalyzerProbe(model: coordinator)
    let viewModel = RelationshipViewModel(useCases: .init(memory: memory, analyzer: analyzer))
    viewModel.selected = [source.id]
    viewModel.question = "What was proposed?"
    viewModel.ownerInterpretation = "I remember Thursday."
    let request = Task { await viewModel.analyze() }
    await gate.waitUntilEntered()
    viewModel.cancel()
    await coordinator.unload()
    await gate.release()
    await request.value
    #expect(await analyzer.calls == 0)
    #expect(await raw.calls == 0)
    #expect(await raw.unloads == 1)
    #expect(viewModel.result == nil && !viewModel.isBusy && viewModel.error == nil)
    #expect(viewModel.selected == [source.id])
    #expect(viewModel.question == "What was proposed?")
    #expect(viewModel.ownerInterpretation == "I remember Thursday.")
    #expect(try await memory.snapshot() == initial)
    #expect(await repository.saves == 0)
  }

  @Test func cancelledSearchLoadIgnoresLatePreparedCollection() async {
    let gate = LifecyclePreparationGate()
    let id = UUID()
    let collection = MemorySearchCollection(
      documents: [
        .init(
          id: id, text: "Fictional retained source", kind: .original, date: nil,
          originalText: nil, detail: "originalStatement", destination: .source(id))
      ], connections: [])
    let provider = LifecycleCandidateSearch()
    let viewModel = MemorySearchViewModel(
      useCases: .init(
        keyword: provider, semantic: provider,
        readCollection: {
          await gate.hold()
          return collection
        }))
    viewModel.query = "Retain this query"
    let loading = Task { await viewModel.load() }
    await gate.waitUntilEntered()
    viewModel.cancel()
    await gate.release()
    await loading.value
    #expect(viewModel.graph.documents.isEmpty && !viewModel.isBusy)
    #expect(viewModel.query == "Retain this query")
    #expect(await provider.calls == 0)
  }
}
