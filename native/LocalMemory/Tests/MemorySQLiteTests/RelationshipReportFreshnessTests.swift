import Foundation
import MemoryCore
import Testing

private actor ReportFreshnessMemory: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  func load() -> PersonalMemorySnapshot { value }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
}

private struct ReportFreshnessAnalyzer: RelationshipAnalyzing {
  func analyze(_ input: RelationshipAnalysisInput) -> RelationshipAnalysisProposal {
    let source = input.sources[0].source
    return .init(findings: [
      .init(
        id: "agreement", kind: .agreement, text: "Friday was accepted.",
        evidence: [.init(sourceID: source.id, quote: source.text)])
    ])
  }
}

private actor SuspendedReportRepository: RelationshipReportRepository {
  enum Pause { case load, save }
  private var rows: [RelationshipSavedReport] = []
  private var nextPause: Pause?
  private var entered = false
  private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
  private var paused: CheckedContinuation<Void, Never>?

  func arm(_ pause: Pause) {
    nextPause = pause
    entered = false
  }
  func waitUntilPaused() async {
    if entered { return }
    await withCheckedContinuation { enteredWaiters.append($0) }
  }
  private func suspend() async {
    entered = true
    let waiters = enteredWaiters
    enteredWaiters = []
    for waiter in waiters { waiter.resume() }
    await withCheckedContinuation { paused = $0 }
  }
  func resume() {
    paused?.resume()
    paused = nil
  }
  func load() async -> [RelationshipSavedReport] {
    let observed = rows
    if nextPause == .load {
      nextPause = nil
      await suspend()
    }
    return observed
  }
  func save(_ report: RelationshipSavedReport) async throws {
    rows = try RelationshipSavedReport.retaining(report, in: rows)
    if nextPause == .save {
      nextPause = nil
      await suspend()
    }
  }
  func remove(_ stale: [RelationshipSavedReport]) throws {
    rows = try RelationshipSavedReport.removing(stale, from: rows)
  }
  func removeAll() { rows = [] }
}

struct RelationshipReportFreshnessTests {
  private func fixture() async throws -> (
    PersonalMemoryUseCases, RelationshipUnderstandingUseCases, SuspendedReportRepository,
    RelationshipAnalysisRequest
  ) {
    let memory = PersonalMemoryUseCases(repository: ReportFreshnessMemory())
    let source = PersonalMemorySource(text: "Rana: Friday works.", kind: .conversationOnly)
    _ = try await memory.ingest(source: source)
    let reports = SuspendedReportRepository()
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: ReportFreshnessAnalyzer(), reports: reports)
    return (
      memory, useCases, reports, .init(sourceIDs: [source.id], question: "What was accepted?")
    )
  }

  @Test func staleLoadCannotDeleteNewerSavedReport() async throws {
    let (memory, useCases, reports, request) = try await fixture()
    _ = try await useCases.save(useCases.analyze(request))
    await reports.arm(.load)
    let loading = Task { try await useCases.loadSaved() }
    await reports.waitUntilPaused()
    _ = try await memory.ingest(source: PersonalMemorySource(text: "Another fictional capture"))
    let current = try await useCases.analyze(request)
    _ = try await useCases.save(current)
    await reports.resume()
    #expect(try await loading.value.isEmpty)
    #expect(await reports.load().map(\.revision) == [current.input.revision])
    #expect(try await useCases.loadSaved() == [current])
  }

  @Test func staleSaveCannotDeleteNewerSavedReport() async throws {
    let (memory, useCases, reports, request) = try await fixture()
    let obsolete = try await useCases.analyze(request)
    await reports.arm(.save)
    let saving = Task { try await useCases.save(obsolete) }
    await reports.waitUntilPaused()
    _ = try await memory.ingest(source: PersonalMemorySource(text: "Another fictional capture"))
    let current = try await useCases.analyze(request)
    _ = try await useCases.save(current)
    await reports.resume()
    await #expect(throws: RelationshipUnderstandingError.staleResult) { try await saving.value }
    #expect(await reports.load().map(\.revision) == [current.input.revision])
    #expect(try await useCases.loadSaved() == [current])
  }

  @Test func conditionalRemovalPreservesChangedBytesAndReplacementDates() throws {
    let id = UUID()
    func report(_ question: String, _ date: TimeInterval) -> RelationshipSavedReport {
      .init(
        revision: 1, request: .init(sourceIDs: [id], question: question), proposal: .init(),
        createdAt: Date(timeIntervalSince1970: date))
    }
    let observed = report("Caf\u{00E9}", 100)
    let changedBytes = report("Cafe\u{0301}", 100)
    let replacement = report("Caf\u{00E9}", 101)
    // Swift String equality treats these spellings as equal; original storage must not.
    #expect(observed == changedBytes)
    let retained = try RelationshipSavedReport.removing(
      [observed], from: [observed, changedBytes, replacement])
    #expect(retained.count == 2)
    #expect(retained[0].request.question.utf8.elementsEqual(changedBytes.request.question.utf8))
    #expect(retained[1].createdAt == replacement.createdAt)
    #expect(try RelationshipSavedReport.removing([observed], from: retained) == retained)
  }
}
