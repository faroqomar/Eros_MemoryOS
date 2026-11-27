import ChatCore
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private actor ContinuationScopeModel: StructuredChatModel {
  let subject: String
  let scope: [String]
  let otherSubjects: [String]

  init(subject: String, scope: [String] = ["s0"], otherSubjects: [String] = []) {
    self.subject = subject
    self.scope = scope
    self.otherSubjects = otherSubjects
  }

  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) throws -> String {
    let value: [String: Any]
    if grammar.contains("scope-status ::=") {
      value = ["assessment": "Controlled scope.", "status": "complete", "subjects": scope]
    } else if grammar.contains("subject ::=") {
      value = [
        "assessment": "Controlled subject.",
        "subjects": [subject] + otherSubjects,
      ]
    } else if grammar.contains("resolution") {
      value = ["assessment": "Controlled validation.", "resolution": "complete"]
    } else {
      value = ["relevant": true]
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }

  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {
    Issue.record("This control must not call unstructured generation")
  }
  func unload() {}
}

private actor ContinuationDelayedRepository: PersonalMemoryRepository {
  private var value: PersonalMemorySnapshot
  private let delayed: Bool
  private var started = false
  private var startWaiters: [CheckedContinuation<Void, Never>] = []
  private var release: CheckedContinuation<Void, Never>?

  init(value: PersonalMemorySnapshot = .init(), delayed: Bool = false) {
    self.value = value
    self.delayed = delayed
  }
  func load() async -> PersonalMemorySnapshot {
    if delayed {
      started = true
      for waiter in startWaiters { waiter.resume() }
      startWaiters = []
      await withCheckedContinuation { release = $0 }
    }
    return value
  }
  func save(_ value: PersonalMemorySnapshot) { self.value = value }
  func waitUntilLoading() async {
    if started { return }
    await withCheckedContinuation { startWaiters.append($0) }
  }
  func resumeLoad() {
    release?.resume()
    release = nil
  }
}

private struct ContinuationEmptyAnalyzer: RelationshipAnalyzing {
  func analyze(_ input: RelationshipAnalysisInput) -> RelationshipAnalysisProposal { .init() }
}

struct IndependentContinuationRegressionTests {
  /// The positive model verdict cannot recover a source discarded before topic validation.
  @Test(arguments: [false, true])
  func arabicConjunctionPreservesAnExplicitUnlinkedName(hints: Bool) async throws {
    let source = ChatEvidence(id: UUID(), text: "وصلتُ للمكتبة، ووداد قالت إن الاجتماع يوم الخميس.")
    let filter = SourceBoundedChatEvidenceFilter(
      model: ContinuationScopeModel(subject: "وداد"), useKnownIdentityHints: hints)
    let selected = try await filter.selectRelevant(
      query: "متى اجتماع وداد؟", candidates: [source],
      identities: [.init(names: ["وداد"], canGroundQuery: true)])
    #expect(selected == [source.id])
  }

  /// This checks the default path's whole requested set, not model semantic quality.
  @Test func defaultGroupRequestMustNotReturnOnlyTheFirstRequestedPerson() async throws {
    let first = ChatEvidence(id: UUID(), text: "Celine meets on Tuesday.")
    let second = ChatEvidence(id: UUID(), text: "Hugo meets on Thursday.")
    let filter = SourceBoundedChatEvidenceFilter(
      model: ContinuationScopeModel(
        subject: "Celine", scope: ["s0", "s1"], otherSubjects: ["Hugo"]))
    let selected = try await filter.selectRelevant(
      query: "Compare Celine and Hugo's meeting days.", candidates: [first, second],
      identities: [
        .init(names: ["Celine"], canGroundQuery: true),
        .init(names: ["Hugo"], canGroundQuery: true),
      ])
    #expect(selected == [first.id, second.id])
  }

  @MainActor @Test(arguments: [false, true])
  func delayedSavedReportDoesNotReplaceNewInputOrCancellation(cancel: Bool) async throws {
    let memory = PersonalMemoryUseCases(repository: ContinuationDelayedRepository())
    let source = PersonalMemorySource(
      text: "A fictional visit is planned for Tuesday.",
      createdAt: Date(timeIntervalSince1970: 1_800_000_000),
      origin: "independent fictional regression", kind: .conversationOnly)
    _ = try await memory.ingest(source: source)
    let existing = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: ContinuationEmptyAnalyzer())
    let report = try await existing.analyze(
      .init(sourceIDs: [source.id], question: "The older saved question."))
    let repository = ContinuationDelayedRepository(
      value: try await memory.snapshot(), delayed: true)
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: PersonalMemoryUseCases(repository: repository),
        analyzer: ContinuationEmptyAnalyzer()))
    viewModel.question = "The current question."
    let pending = Task { await viewModel.openSaved(report) }
    await repository.waitUntilLoading()
    if cancel { viewModel.cancel() } else { viewModel.question = "The newly edited question." }
    await repository.resumeLoad()
    await pending.value
    #expect(viewModel.question == (cancel ? "The current question." : "The newly edited question."))
    #expect(viewModel.result == nil)
    #expect(viewModel.selected.isEmpty)
  }
}
