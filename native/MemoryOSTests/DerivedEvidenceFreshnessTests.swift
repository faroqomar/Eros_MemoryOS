import Foundation
import MemoryCore
import RetrievalCore
import Testing

@testable import MemoryOS

private actor FreshnessMemoryRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

private struct FreshnessAnalyzer: RelationshipAnalyzing {
  func analyze(_ input: RelationshipAnalysisInput) -> RelationshipAnalysisProposal {
    let source = input.sources[0].source
    return .init(findings: [
      .init(
        id: "agreement", kind: .agreement, text: "Friday was accepted.",
        evidence: [.init(sourceID: source.id, quote: source.text)])
    ])
  }
}

private actor PendingReportSave: RelationshipReportRepository {
  enum Failure: Error { case unavailable }
  private var rows: [RelationshipSavedReport] = []
  private var entered = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var paused: CheckedContinuation<Void, Never>?
  private(set) var removals = 0
  let fails: Bool
  init(fails: Bool = false) { self.fails = fails }
  func waitUntilSaving() async {
    if entered { return }
    await withCheckedContinuation { waiters.append($0) }
  }
  func resume() {
    paused?.resume()
    paused = nil
  }
  func load() -> [RelationshipSavedReport] { rows }
  func save(_ report: RelationshipSavedReport) async throws {
    entered = true
    let waiting = waiters
    waiters = []
    for waiter in waiting { waiter.resume() }
    await withCheckedContinuation { paused = $0 }
    if fails { throw Failure.unavailable }
    rows = try RelationshipSavedReport.retaining(report, in: rows)
  }
  func remove(_ stale: [RelationshipSavedReport]) throws {
    rows = try RelationshipSavedReport.removing(stale, from: rows)
  }
  func removeAll() {
    rows = []
    removals += 1
  }
}

private actor SearchSnapshotSequence {
  private var values: [MemorySearchCollection]
  init(_ values: [MemorySearchCollection]) { self.values = values }
  func next() -> MemorySearchCollection {
    values.count > 1 ? values.removeFirst() : values[0]
  }
}

private struct FreshnessSearchProvider: MemorySearching {
  let id: UUID
  func search(query: String, records: [MemorySearchRecord], limit: Int) -> [MemorySearchHit] {
    records.filter { $0.id == id.uuidString }.map {
      .init(sourceID: $0.id, score: 1, matchedText: $0.text)
    }
  }
}

@MainActor struct DerivedEvidenceFreshnessTests {
  enum SaveInterruption: CaseIterable { case inputEdit, cancel, newerAnalysis }
  enum GraphChange: CaseIterable {
    case removedLink, renamedLink, identityMembership, correctedSource, deletedSource
    case canonicallyEquivalentSource, canonicallyEquivalentLink
  }

  private func relationship(fails: Bool = false) async throws -> (
    RelationshipViewModel, PendingReportSave
  ) {
    let memory = PersonalMemoryUseCases(repository: FreshnessMemoryRepository())
    let source = PersonalMemorySource(text: "Rana: Friday works.", kind: .conversationOnly)
    _ = try await memory.ingest(source: source)
    let reports = PendingReportSave(fails: fails)
    let viewModel = RelationshipViewModel(
      useCases: .init(memory: memory, analyzer: FreshnessAnalyzer(), reports: reports))
    viewModel.selected = [source.id]
    viewModel.question = "Earlier question"
    await viewModel.analyze()
    _ = try #require(viewModel.result)
    return (viewModel, reports)
  }

  @Test(arguments: SaveInterruption.allCases)
  func oldSaveCannotRestoreInvalidatedResult(_ interruption: SaveInterruption) async throws {
    let (viewModel, reports) = try await relationship()
    let saving = Task { await viewModel.saveReport() }
    await reports.waitUntilSaving()
    #expect(viewModel.isBusy)
    switch interruption {
    case .inputEdit: viewModel.question = "Changed question"
    case .cancel:
      viewModel.cancel()
      viewModel.invalidate()
    case .newerAnalysis:
      viewModel.question = "Newer question"
      await viewModel.analyze()
      #expect(viewModel.result?.input.request.question.hasSuffix("Newer question") == true)
    }
    let expectedQuestion = viewModel.question
    let expectedResult = viewModel.result
    await reports.resume()
    await saving.value
    #expect(viewModel.question == expectedQuestion)
    #expect(viewModel.result == expectedResult)
    #expect(viewModel.error == nil && !viewModel.isBusy)
    // The explicit save still stores its reviewed request, without changing the edited form.
    #expect(await reports.load().first?.request.question.hasSuffix("Earlier question") == true)
  }

  @Test func obsoleteSaveFailureCannotOverwriteEditedInputState() async throws {
    let (viewModel, reports) = try await relationship(fails: true)
    let saving = Task { await viewModel.saveReport() }
    await reports.waitUntilSaving()
    viewModel.question = "Changed question"
    await reports.resume()
    await saving.value
    #expect(viewModel.question == "Changed question")
    #expect(viewModel.result == nil && viewModel.error == nil && !viewModel.isBusy)
    #expect(!viewModel.isUpdatingSavedReports)
  }

  @Test(arguments: SaveInterruption.allCases)
  func clearRejectsPendingSaveUntilPersistenceCompletes(_ interruption: SaveInterruption)
    async throws
  {
    let (viewModel, reports) = try await relationship()
    let saving = Task { await viewModel.saveReport() }
    await reports.waitUntilSaving()
    #expect(viewModel.isBusy && viewModel.isUpdatingSavedReports)
    #expect(await !viewModel.clearSavedReports())
    #expect(await reports.removals == 0)
    switch interruption {
    case .inputEdit: viewModel.question = "Changed question"
    case .cancel: viewModel.cancel()
    case .newerAnalysis:
      viewModel.question = "Newer question"
      await viewModel.analyze()
    }
    let expectedQuestion = viewModel.question
    let expectedResult = viewModel.result
    #expect(!viewModel.isBusy && viewModel.isUpdatingSavedReports)
    #expect(await !viewModel.clearSavedReports())
    #expect(await reports.removals == 0)
    await reports.resume()
    await saving.value
    #expect(!viewModel.isUpdatingSavedReports)
    #expect(await reports.load().count == 1)
    #expect(await viewModel.clearSavedReports())
    #expect(await reports.load().isEmpty)
    #expect(await reports.removals == 1)
    #expect(viewModel.savedReports.isEmpty && !viewModel.isUpdatingSavedReports)
    #expect(viewModel.question == expectedQuestion && viewModel.result == expectedResult)
    await viewModel.load()
    #expect(viewModel.savedReports.isEmpty)
  }

  @Test(arguments: GraphChange.allCases)
  func finalSearchRecheckRejectsChangedGraphAndAllowsRetry(_ change: GraphChange) async throws {
    let one = UUID()
    let two = UUID()
    func document(_ id: UUID, _ text: String) -> MemorySearchDocument {
      .init(
        id: id, text: text, kind: .original, date: nil, originalText: nil,
        detail: "originalStatement", destination: .source(id))
    }
    let original = MemorySearchCollection(
      documents: [document(one, "Caf\u{00E9}"), document(two, "Friday agreement")],
      connections: [.init(from: one, to: two, label: "Caf\u{00E9}")],
      identityAliases: [.init(names: ["Mira"], documentIDs: [one.uuidString])])
    var current = original
    switch change {
    case .removedLink: current.connections = []
    case .renamedLink: current.connections = [.init(from: one, to: two, label: "revised topic")]
    case .identityMembership:
      current.identityAliases = [.init(names: ["Mira"], documentIDs: [two.uuidString])]
    case .correctedSource: current.documents[1] = document(two, "Saturday agreement")
    case .deletedSource:
      current.documents.removeLast()
      current.connections = []
    case .canonicallyEquivalentSource: current.documents[0] = document(one, "Cafe\u{0301}")
    case .canonicallyEquivalentLink:
      current.connections = [.init(from: one, to: two, label: "Cafe\u{0301}")]
    }
    let store = SearchSnapshotSequence([original, original, current])
    let provider = FreshnessSearchProvider(id: one)
    let viewModel = MemorySearchViewModel(
      useCases: .init(keyword: provider, semantic: provider, readCollection: { await store.next() })
    )
    viewModel.query = "Mira"
    viewModel.mode = .linked
    await viewModel.search()
    #expect(viewModel.results.isEmpty && viewModel.failure == .changed)
    #expect(!viewModel.isBusy && !viewModel.searched && viewModel.elapsedSeconds == nil)
    #expect(viewModel.query == "Mira" && viewModel.mode == .linked)
    await viewModel.search()
    #expect(viewModel.failure == nil && viewModel.searched && !viewModel.results.isEmpty)
    #expect(viewModel.graph == current)
    for result in viewModel.results {
      #expect(result.document == current.document(result.id))
      if let connection = result.connection {
        #expect(current.connections.contains { $0.label.utf8.elementsEqual(connection.utf8) })
      }
    }
  }
}
