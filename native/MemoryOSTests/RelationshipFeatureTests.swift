import ChatCore
import Foundation
import MemoryCore
import Testing

@testable import MemoryOS

private enum RelationshipFeatureError: Error { case unavailable }

private actor RelationshipFeatureRepository: PersonalMemoryRepository {
  private var value = PersonalMemorySnapshot()
  var fail = false
  func setFailure(_ flag: Bool) { fail = flag }
  func load() throws -> PersonalMemorySnapshot {
    if fail { throw PersonalMemoryError.storage }
    return value
  }
  func save(_ snapshot: PersonalMemorySnapshot) throws {
    if fail { throw PersonalMemoryError.storage }
    value = snapshot
  }
}

private actor RelationshipWireModel: StructuredChatModel {
  let output: String
  let auditSupported: Bool
  let auditComplete: Bool
  let accountOutput: String?
  private(set) var turns: [ChatTurn] = []
  private(set) var maximumTokens = 0
  private(set) var grammar = ""
  private(set) var auditTurns: [ChatTurn] = []
  private(set) var calls = 0
  init(
    output: String, auditSupported: Bool = true, auditComplete: Bool = true,
    accountOutput: String? = nil
  ) {
    self.output = output
    self.auditSupported = auditSupported
    self.auditComplete = auditComplete
    self.accountOutput = accountOutput
  }
  func generateJSON(turns: [ChatTurn], grammar: String, maximumOutputTokens: Int) -> String {
    calls += 1
    if grammar.contains("comparison"), let accountOutput { return accountOutput }
    if grammar.contains("assessment") {
      auditTurns = turns
      return
        "{\"assessment\":\"Fictional controlled audit\",\"supported\":\(auditSupported),\"complete\":\(auditComplete)}"
    }
    self.turns = turns
    self.grammar = grammar
    maximumTokens = maximumOutputTokens
    return output
  }
  func generate(turns: [ChatTurn], onText: @escaping @Sendable (String) -> Void) {}
  func unload() {}
}

private actor RelationshipFeatureAnalyzer: RelationshipAnalyzing {
  let proposal: RelationshipAnalysisProposal
  let fail: Bool
  let waitForCancellation: Bool
  let mutation: (@Sendable () async throws -> Void)?
  private var started = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init(
    proposal: RelationshipAnalysisProposal = .init(), fail: Bool = false,
    waitForCancellation: Bool = false, mutation: (@Sendable () async throws -> Void)? = nil
  ) {
    self.proposal = proposal
    self.fail = fail
    self.waitForCancellation = waitForCancellation
    self.mutation = mutation
  }
  func waitUntilStarted() async {
    if started { return }
    await withCheckedContinuation { waiters.append($0) }
  }
  func analyze(_ input: RelationshipAnalysisInput) async throws -> RelationshipAnalysisProposal {
    started = true
    for waiter in waiters { waiter.resume() }
    waiters.removeAll()
    if waitForCancellation { try await Task.sleep(for: .seconds(30)) }
    if fail { throw RelationshipFeatureError.unavailable }
    try await mutation?()
    return proposal
  }
}

private actor RelationshipFeatureReports: RelationshipReportRepository {
  private var reports: [RelationshipSavedReport] = []
  private let beforeLoad: (@Sendable () async -> Void)?
  init(beforeLoad: (@Sendable () async -> Void)? = nil) { self.beforeLoad = beforeLoad }
  func load() async -> [RelationshipSavedReport] {
    await beforeLoad?()
    return reports
  }
  func save(_ report: RelationshipSavedReport) throws {
    reports = try RelationshipSavedReport.retaining(report, in: reports)
  }
  func remove(_ stale: [RelationshipSavedReport]) throws {
    reports = try RelationshipSavedReport.removing(stale, from: reports)
  }
  func removeAll() { reports = [] }
}

private actor RecoverableRelationshipReports: RelationshipReportRepository {
  private var failed = false
  func setFailure(_ value: Bool) { failed = value }
  func load() throws -> [RelationshipSavedReport] {
    if failed { throw PersonalMemoryError.storage }
    return []
  }
  func save(_ report: RelationshipSavedReport) {}
  func remove(_ stale: [RelationshipSavedReport]) {}
  func removeAll() {}
}

private actor SuspendedRelationshipLoadRepository: PersonalMemoryRepository {
  let value: PersonalMemorySnapshot
  let fail: Bool
  private var started = false
  private var startedWaiters: [CheckedContinuation<Void, Never>] = []
  private var release: CheckedContinuation<Void, Never>?

  init(value: PersonalMemorySnapshot, fail: Bool = false) {
    self.value = value
    self.fail = fail
  }

  func load() async throws -> PersonalMemorySnapshot {
    await withCheckedContinuation { continuation in
      release = continuation
      started = true
      for waiter in startedWaiters { waiter.resume() }
      startedWaiters.removeAll()
    }
    if fail { throw PersonalMemoryError.storage }
    return value
  }

  func waitUntilStarted() async {
    if started { return }
    await withCheckedContinuation { startedWaiters.append($0) }
  }

  func resume() {
    release?.resume()
    release = nil
  }

  func save(_ snapshot: PersonalMemorySnapshot) {}
}

@MainActor struct RelationshipFeatureTests {
  private func setup(text: String = "Rana: Friday at six works for me.") async throws
    -> (PersonalMemoryUseCases, PersonalMemorySource)
  {
    let memory = PersonalMemoryUseCases(repository: RelationshipFeatureRepository())
    let source = PersonalMemorySource(
      text: text, createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      origin: "fictional test", kind: .conversationOnly)
    _ = try await memory.ingest(source: source)
    return (memory, source)
  }

  private func wire(
    citations: [String] = ["P0"], kind: String = "acceptance", quote: String? = nil
  ) -> String {
    var event: [String: Any] = [
      "act": kind, "text": "Rana accepted Friday at six.", "citations": citations,
    ]
    if let quote { event["quote"] = quote }
    let value: [String: Any] = ["complete": true, "events": [event]]
    return String(decoding: try! JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }

  @Test func wireMapsAliasesToOriginalsAndUsesBoundedStructuredRuntime() async throws {
    let (memory, source) = try await setup()
    let model = RelationshipWireModel(output: wire())
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model))
    let result = try await useCases.analyze(
      .init(sourceIDs: [source.id], question: "What was agreed?"))
    #expect(result.findings.first?.evidence.first?.sourceID == source.id)
    #expect(result.findings.first?.evidence.first?.quote == source.text)
    #expect(await model.maximumTokens == 512)
    let grammar = try #require(await model.grammar)
    #expect(grammar.contains("P0"))
    #expect(!grammar.contains(source.text))
    #expect(!grammar.contains(source.id.uuidString))
    let input = try #require(await model.turns.last?.text)
    #expect(input.contains("S0") && !input.contains(source.id.uuidString))
    #expect(input.contains("fictional test"))
    #expect(try await memory.snapshot().sources == [source])
  }

  /// Mechanical transport mapping with a controlled audit, not evidence of model classification quality.
  @Test(arguments: [
    ("acceptance", RelationshipFindingKind.agreement),
    ("disagreement", RelationshipFindingKind.disagreement),
    ("refusal", RelationshipFindingKind.disagreement),
    ("request", RelationshipFindingKind.unresolved),
    ("offer", RelationshipFindingKind.unresolved),
    ("promise", RelationshipFindingKind.commitment),
    ("apology", RelationshipFindingKind.repairAttempt),
    ("repair", RelationshipFindingKind.repairAttempt),
    ("change", RelationshipFindingKind.changeOverTime),
    ("observation", RelationshipFindingKind.insight),
  ])
  func descriptiveWireKindsMapToExistingDomainCategories(
    wireKind: String, domainKind: RelationshipFindingKind
  ) async throws {
    let (memory, source) = try await setup()
    let model = RelationshipWireModel(output: wire(kind: wireKind))
    let analyzer = LocalRelationshipAnalyzer(model: model)
    let input = try await RelationshipUnderstandingUseCases(memory: memory, analyzer: analyzer)
      .prepare(.init(sourceIDs: [source.id], question: "What does this original state?"))
    let proposal = try await analyzer.analyze(input)
    #expect(proposal.findings.first?.kind == domainKind)
    #expect(proposal.findings.first?.evidence.first?.sourceID == source.id)
    #expect(try await memory.snapshot().sources == [source])
  }

  @Test(arguments: [
    "acceptedProposal", "explicitOpposition", "openOfferOrRequest", "explicitPromise",
    "explicitApologyOrReconciliationAttempt", "laterPlanUpdate", "sourceObservation",
    "unknownWireKind",
  ])
  func legacyAndUnknownWireKindsDoNotSilentlyMap(value: String) async throws {
    let (memory, source) = try await setup()
    let model = RelationshipWireModel(output: wire(kind: value))
    let analyzer = LocalRelationshipAnalyzer(model: model)
    let input = try await RelationshipUnderstandingUseCases(memory: memory, analyzer: analyzer)
      .prepare(.init(sourceIDs: [source.id], question: "What does this original state?"))
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await analyzer.analyze(input)
    }
    #expect(await model.calls == 2)
    #expect(try await memory.snapshot().sources == [source])
  }

  @Test(arguments: [false, true])
  func viewModelRejectsFabricatedQuotesAndUnknownAliases(unknownAlias: Bool) async throws {
    let (memory, source) = try await setup()
    let model = RelationshipWireModel(
      output: wire(
        citations: unknownAlias ? ["P99"] : ["P0"],
        quote: unknownAlias ? nil : "Rana refused Friday."))
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)))
    viewModel.selected = [source.id]
    await viewModel.analyze()
    #expect(viewModel.result == nil)
    #expect(viewModel.error == .invalidEvidence)
    #expect(!viewModel.isBusy)
  }

  @Test func oversizedInputRefusesWithoutCallingModelOrTruncating() async throws {
    let (memory, source) = try await setup(
      text: String(repeating: "Fictional long evidence. ", count: 180))
    let model = RelationshipWireModel(output: wire())
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)))
    viewModel.selected = [source.id]
    await viewModel.analyze()
    #expect(viewModel.error == .tooLarge && viewModel.result == nil)
    #expect(await model.turns.isEmpty)
    #expect(await model.calls == 0)
    #expect(try await memory.snapshot().sources.first?.text == source.text)
  }

  @Test func retryingStorageLoadClearsFailureAndPreservesTheQuestionAndSelection() async throws {
    let repository = RelationshipFeatureRepository()
    let memory = PersonalMemoryUseCases(repository: repository)
    let source = PersonalMemorySource(text: "Fictional original for recovery.", kind: .fact)
    _ = try await memory.ingest(source: source)
    let wireModel = RelationshipWireModel(output: wire())
    let reports = RecoverableRelationshipReports()
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: wireModel), reports: reports))
    await viewModel.load()
    viewModel.selected = [source.id]
    viewModel.question = "My unsent question"
    viewModel.ownerInterpretation = "My account"
    await reports.setFailure(true)
    await viewModel.load()
    #expect(viewModel.error == .storage)
    await reports.setFailure(false)
    await viewModel.load()
    #expect(viewModel.error == nil)
    #expect(viewModel.selected == [source.id])
    #expect(
      viewModel.question == "My unsent question" && viewModel.ownerInterpretation == "My account")
    #expect(viewModel.snapshot.sources.first?.text == source.text)
    #expect(await wireModel.calls == 0)
  }

  @Test func rejectedSemanticAuditNeverDisplaysOrSavesTheCandidate() async throws {
    let (memory, source) = try await setup()
    let model = RelationshipWireModel(output: wire(), auditSupported: false)
    let viewModel = RelationshipViewModel(
      useCases: .init(memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)))
    viewModel.selected = [source.id]
    await viewModel.analyze()
    #expect(viewModel.error == .invalidEvidence && viewModel.result == nil)
    #expect(viewModel.savedReports.isEmpty)
    #expect(try await memory.snapshot().sources == [source])
  }

  @Test func pointerExpansionPreservesEveryUnicodeByteAndSelectedPassage() async throws {
    let original = String(repeating: "Rana: cafe\u{301} 🙂 العربية مع علامات \"نص\". ", count: 10)
    let (memory, source) = try await setup(text: original)
    let model = RelationshipWireModel(output: wire(citations: ["P1"], kind: "observation"))
    let result = try await RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
    ).analyze(.init(sourceIDs: [source.id], question: "What is in the selected passage?"))
    let payload = try #require(await model.turns.last?.text)
    let fields = try #require(
      JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    let sources = try #require(fields["sources"] as? [[String: Any]])
    let passages = try #require(sources.first?["passages"] as? [[String: String]])
    #expect(passages.count > 1)
    #expect(Data(passages.compactMap { $0["text"] }.joined().utf8) == Data(original.utf8))
    let chosen = try #require(passages.first { $0["id"] == "P1" }?["text"])
    #expect(result.findings.first?.evidence == [.init(sourceID: source.id, quote: chosen)])
    #expect(try await memory.snapshot().sources.first?.text == original)
    #expect(!(await model.grammar).contains(original))
    #expect((await model.auditTurns.last?.text)?.contains("P1") == true)
  }

  @Test func identicalTextKeepsDistinctIdentityAndUncitedContextCannotSupplyClaimSupport()
    async throws
  {
    let memory = PersonalMemoryUseCases(repository: RelationshipFeatureRepository())
    let texts = [
      "Rana: I can help tomorrow.", "Uncited fictional private context.",
      "Rana: I can help tomorrow.",
    ]
    var sources: [PersonalMemorySource] = []
    for (index, text) in texts.enumerated() {
      let source = PersonalMemorySource(
        text: text,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
        origin: "fictional test", kind: .conversationOnly)
      sources.append(source)
      _ = try await memory.ingest(source: source)
    }
    let model = RelationshipWireModel(output: wire(citations: ["P2"], kind: "offer"))
    let result = try await RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
    ).analyze(.init(sourceIDs: sources.map(\.id), question: "What does the last record offer?"))
    #expect(result.findings.first?.evidence == [.init(sourceID: sources[2].id, quote: texts[2])])
    let audit = try #require(await model.auditTurns.last?.text)
    let contextText = audit.components(separatedBy: "\nProposed answer to check, not evidence:\n")[
      0
    ]
    .replacingOccurrences(of: "Cited originals and separate uncited coverage context:\n", with: "")
    let context = try #require(
      JSONSerialization.jsonObject(with: Data(contextText.utf8)) as? [String: Any])
    let cited = String(
      decoding: try JSONSerialization.data(withJSONObject: try #require(context["citedOriginals"])),
      as: UTF8.self)
    let uncited = String(
      decoding: try JSONSerialization.data(
        withJSONObject: try #require(context["uncitedContext"])),
      as: UTF8.self)
    #expect(!cited.contains(texts[1]) && !cited.contains("\"id\":\"P0\""))
    #expect(cited.contains("\"id\":\"P2\""))
    #expect(uncited.contains(texts[1]) && uncited.contains("\"id\":\"P0\""))
    #expect(
      (await model.auditTurns.first?.text)?.contains("They must NEVER justify a proposed claim")
        == true)

  }

  @Test func omittedLaterCorrectionReachesCoverageAuditAndCannotSaveTheEarlierClaim() async throws {
    let memory = PersonalMemoryUseCases(repository: RelationshipFeatureRepository())
    let texts = [
      "Rana: Friday at six works for me.",
      "Rana: Correction: I cannot make Friday. Please do not keep that plan.",
    ]
    var sources: [PersonalMemorySource] = []
    for (index, text) in texts.enumerated() {
      let source = PersonalMemorySource(
        text: text,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400),
        origin: "fictional correction", kind: .conversationOnly)
      sources.append(source)
      _ = try await memory.ingest(source: source)
    }
    // The earlier statement has a genuine citation, but omitting the later refusal
    // makes the requested current-plan answer incomplete. These are separate checks.
    let model = RelationshipWireModel(output: wire(), auditSupported: true, auditComplete: false)
    let reports = RelationshipFeatureReports()
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: model), reports: reports))
    viewModel.selected = Set(sources.map(\.id))
    viewModel.question = "Explain the current plan and its changes."
    let before = try await memory.snapshot()
    await viewModel.analyze()
    #expect(viewModel.result == nil && viewModel.error == .invalidEvidence)
    #expect(viewModel.savedReports.isEmpty)
    #expect(await reports.load().isEmpty)
    #expect(try await memory.snapshot() == before)
    #expect(await model.calls == 4)
    let audit = try #require(await model.auditTurns.last?.text)
    let contextText = audit.components(separatedBy: "\nProposed answer to check, not evidence:\n")[
      0
    ]
    .replacingOccurrences(of: "Cited originals and separate uncited coverage context:\n", with: "")
    let context = try #require(
      JSONSerialization.jsonObject(with: Data(contextText.utf8)) as? [String: Any])
    let cited = String(
      decoding: try JSONSerialization.data(withJSONObject: try #require(context["citedOriginals"])),
      as: UTF8.self)
    let uncited = String(
      decoding: try JSONSerialization.data(
        withJSONObject: try #require(context["uncitedContext"])),
      as: UTF8.self)
    #expect(cited.contains(texts[0]) && !cited.contains(texts[1]))
    #expect(uncited.contains(texts[1]))
  }

  @Test func threeDatedEventsReachTimelineWithoutCollapsingOrMutatingOriginals() async throws {
    let memory = PersonalMemoryUseCases(repository: RelationshipFeatureRepository())
    let entries = [
      ("Rana: I agree to Friday.", "acceptance"),
      ("Rana: I disagree with changing the venue.", "disagreement"),
      ("Rana: Sorry I interrupted you.", "apology"),
    ]
    var sources: [PersonalMemorySource] = []
    var events: [[String: Any]] = []
    for (index, entry) in entries.enumerated() {
      let source = PersonalMemorySource(
        text: entry.0,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400),
        origin: "fictional timeline", kind: .conversationOnly)
      sources.append(source)
      _ = try await memory.ingest(source: source)
      events.append(["text": entry.0, "act": entry.1, "citations": ["P\(index)"]])
    }
    let output = String(
      decoding: try JSONSerialization.data(withJSONObject: ["complete": true, "events": events]),
      as: UTF8.self)
    let model = RelationshipWireModel(output: output)
    let before = try await memory.snapshot()
    let result = try await RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
    ).analyze(
      .init(
        sourceIDs: sources.map(\.id), question: "Show the three dated events.", focus: .discussion))
    #expect(result.findings.map(\.kind) == [.agreement, .disagreement, .repairAttempt])
    #expect(result.timeline.map(\.firstRecordedAt) == sources.map(\.createdAt))
    #expect(result.timeline.map(\.lastRecordedAt) == sources.map(\.createdAt))
    #expect(try await memory.snapshot() == before)
  }

  @Test(arguments: ["empty", "unknown", "extraField", "tooMany"])
  func invalidPointerOrUnadvertisedShapeIsRejectedBeforeAudit(caseName: String) async throws {
    let (memory, source) = try await setup()
    var event: [String: Any] = [
      "text": "Fictional claim.", "act": "observation", "citations": ["P0"],
    ]
    switch caseName {
    case "empty": event["citations"] = [String]()
    case "unknown": event["citations"] = ["P404"]
    case "extraField": event["quote"] = "Fabricated quote."
    default: break
    }
    let output = String(
      decoding: try JSONSerialization.data(withJSONObject: [
        "complete": true, "events": Array(repeating: event, count: caseName == "tooMany" ? 5 : 1),
      ]), as: UTF8.self)
    let model = RelationshipWireModel(output: output)
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model))
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await useCases.analyze(.init(sourceIDs: [source.id], question: "What is recorded?"))
    }
    #expect(await model.calls == 2)
    #expect(try await memory.snapshot().sources == [source])
  }

  @Test func repeatedValidCitationNormalizesWithoutDroppingDistinctOrUnknownSources() async throws {
    let (memory, source) = try await setup()
    let model = RelationshipWireModel(output: wire(citations: ["P0", "P0"]))
    let result = try await RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
    ).analyze(.init(sourceIDs: [source.id], question: "What was agreed?"))
    #expect(result.findings.allSatisfy { $0.evidence.count == 1 })
    #expect(result.findings.allSatisfy { $0.evidence[0].sourceID == source.id })
    let invalid = RelationshipWireModel(output: wire(citations: ["P0", "P99", "P0"]))
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await RelationshipUnderstandingUseCases(
        memory: memory, analyzer: LocalRelationshipAnalyzer(model: invalid)
      ).analyze(.init(sourceIDs: [source.id], question: "What was agreed?"))
    }
    #expect(try await memory.snapshot().sources == [source])
  }

  @Test func incompleteBoundedAnswerRefusesInsteadOfReturningAPartialTimeline() async throws {
    let (memory, source) = try await setup()
    let model = RelationshipWireModel(output: #"{"complete":false,"events":[]}"#)
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model))
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await useCases.analyze(.init(sourceIDs: [source.id], question: "Explain all events."))
    }
    #expect(await model.calls == 2)
    #expect(try await memory.snapshot().sources == [source])
  }

  @Test(arguments: [RelationshipAnalysisFocus.patterns, .advice, .draft, .topic, .period])
  func focusedSchemasRetainAlternativesCostsDraftPermissionAndSummaryLevel(
    focus: RelationshipAnalysisFocus
  ) async throws {
    let (memory, source) = try await setup()
    let output: String
    switch focus {
    case .patterns:
      output =
        #"{"complete":true,"hypotheses":[{"text":"Rana may prefer this time.","kind":"interpretation","citations":["P0"],"alternative":"A different schedule may be unavailable.","counterevidence":[] }]}"#
    case .advice:
      output =
        #"{"complete":true,"options":[{"text":"You could confirm the time.","citations":["P0"],"downside":"Another message may interrupt Rana."}]}"#
    case .draft:
      output =
        #"{"complete":true,"events":[{"text":"Rana accepts Friday at six.","act":"acceptance","citations":["P0"]}],"draft":"Friday at six works for me too."}"#
    default:
      output =
        #"{"complete":true,"summary":{"title":"Friday","text":"Rana says Friday at six works.","citations":["P0"]}}"#
    }
    let model = RelationshipWireModel(output: output)
    let result = try await RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
    )
    .analyze(
      .init(
        sourceIDs: [source.id], question: "Explain the selected record.",
        draftRequested: focus == .draft, focus: focus))
    if focus == .patterns { #expect(result.findings.first?.alternatives.count == 1) }
    if focus == .advice { #expect(result.findings.first?.tradeoffs.count == 1) }
    #expect((result.draft != nil) == (focus == .draft))
    if focus == .topic { #expect(result.summaries.first?.level == .topic) }
    if focus == .period { #expect(result.summaries.first?.level == .period) }
    #expect(try await memory.snapshot().sources == [source])
  }

  @Test func accountConflictStillStopsBeforeAdviceAndKeepsBothAccounts() async throws {
    let (memory, source) = try await setup()
    let account = "Rana refused Friday at six."
    let model = RelationshipWireModel(
      output: "{}",
      accountOutput:
        #"{"source":"S0","comparison":"The source accepts Friday; the account says it was refused.","conflict":true}"#
    )
    let result = try await RelationshipUnderstandingUseCases(
      memory: memory, analyzer: LocalRelationshipAnalyzer(model: model)
    )
    .analyze(
      .init(
        sourceIDs: [source.id], question: "What should I do?", ownerInterpretation: account,
        focus: .advice))
    #expect(result.clarification != nil && result.findings.isEmpty && result.draft == nil)
    #expect(result.proposal.findings.first?.evidence.first?.quote == source.text)
    #expect(result.input.request.ownerInterpretation == account)
    #expect(await model.calls == 1)
    #expect(try await memory.snapshot().sources == [source])
  }

  @Test func selectionAndRuntimeFailuresKeepNoPartialInterpretation() async throws {
    let (memory, source) = try await setup()
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: memory, analyzer: RelationshipFeatureAnalyzer(fail: true)))
    await viewModel.analyze()
    #expect(viewModel.error == .selection && viewModel.result == nil)
    viewModel.selected = [source.id]
    await viewModel.analyze()
    #expect(viewModel.error == .unavailable && viewModel.result == nil)
    #expect(!viewModel.isBusy)
  }

  @Test(.timeLimit(.minutes(1))) func cancellationClearsBusyStateAndDropsPartialOutput()
    async throws
  {
    let (memory, source) = try await setup()
    let analyzer = RelationshipFeatureAnalyzer(waitForCancellation: true)
    let viewModel = RelationshipViewModel(useCases: .init(memory: memory, analyzer: analyzer))
    viewModel.selected = [source.id]
    let running = Task { await viewModel.analyze() }
    await analyzer.waitUntilStarted()
    #expect(viewModel.isBusy)
    viewModel.cancel()
    await running.value
    #expect(!viewModel.isBusy && viewModel.result == nil && viewModel.error == nil)
    #expect(viewModel.selected == [source.id])
  }

  @Test func changedMemoryDuringInferenceRejectsStaleResult() async throws {
    let (memory, source) = try await setup()
    let analyzer = RelationshipFeatureAnalyzer(mutation: {
      _ = try await memory.createProfile(kind: .person, name: "Fictional person")
    })
    let viewModel = RelationshipViewModel(useCases: .init(memory: memory, analyzer: analyzer))
    viewModel.selected = [source.id]
    await viewModel.analyze()
    #expect(viewModel.error == .stale && viewModel.result == nil && !viewModel.isBusy)
  }

  @Test(arguments: ["question", "sources", "account", "mode", "language", "relationship"])
  func editingInputCancelsTheOldAnalysis(field: String) async throws {
    let (memory, source) = try await setup()
    let analyzer = RelationshipFeatureAnalyzer(waitForCancellation: true)
    let viewModel = RelationshipViewModel(useCases: .init(memory: memory, analyzer: analyzer))
    viewModel.selected = [source.id]
    let running = Task { await viewModel.analyze() }
    await analyzer.waitUntilStarted()
    switch field {
    case "question": viewModel.question = "What remains unresolved?"
    case "sources": viewModel.selected = []
    case "account": viewModel.ownerInterpretation = "I remember another agreement."
    case "mode": viewModel.mode = .patterns
    case "language": viewModel.answerInArabic = true
    default: viewModel.relationship = .colleague
    }
    await running.value
    #expect(viewModel.result == nil && viewModel.error == nil && !viewModel.isBusy)
  }

  @Test func savingReopeningAndRefreshHonorCurrentSourceRevision() async throws {
    let (memory, source) = try await setup()
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory,
      analyzer: LocalRelationshipAnalyzer(model: RelationshipWireModel(output: wire())),
      reports: RelationshipFeatureReports())
    let viewModel = RelationshipViewModel(useCases: useCases)
    viewModel.selected = [source.id]
    await viewModel.analyze()
    let result = try #require(viewModel.result)
    await viewModel.saveReport()
    #expect(viewModel.savedReports == [result])
    let reopened = RelationshipViewModel(useCases: useCases)
    await reopened.load()
    #expect(reopened.savedReports == [result])
    await reopened.openSaved(result)
    #expect(reopened.result == result)
    _ = try await useCases.forgetSource(sourceID: source.id, confirmed: true)
    await reopened.load()
    #expect(reopened.result == nil && reopened.savedReports.isEmpty && reopened.selected.isEmpty)
    #expect(reopened.error == .stale)
  }

  @Test func storageFailureIsVisibleWithoutInventedSources() async throws {
    let repository = RelationshipFeatureRepository()
    await repository.setFailure(true)
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: PersonalMemoryUseCases(repository: repository),
        analyzer: RelationshipFeatureAnalyzer()))
    await viewModel.load()
    #expect(viewModel.error == .storage)
    #expect(viewModel.snapshot.sources.isEmpty && viewModel.savedReports.isEmpty)
  }

  @Test func reopeningSavedSummaryRestoresItsRequestControls() async throws {
    let (memory, source) = try await setup()
    let proposal = RelationshipAnalysisProposal(summaries: [
      .init(
        id: "topic", level: .topic, title: "Meeting", text: "Friday at six was accepted.",
        evidence: [.init(sourceID: source.id, quote: source.text)])
    ])
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: RelationshipFeatureAnalyzer(proposal: proposal))
    let original = RelationshipViewModel(useCases: useCases)
    original.selected = [source.id]
    original.mode = .topic
    original.question = "Which meeting time is stated?"
    await original.analyze()
    let report = try #require(original.result)
    let reopened = RelationshipViewModel(useCases: useCases)
    reopened.mode = .advice
    reopened.question = "An unrelated question."
    reopened.answerInArabic = true
    await reopened.openSaved(report)
    #expect(reopened.mode == .topic)
    #expect(reopened.question == original.question)
    #expect(!reopened.answerInArabic)
    #expect(reopened.selected == original.selected && reopened.result == report)
  }

  @Test func cancelledSavedReportTaskCannotPublishItsResult() async throws {
    let (memory, source) = try await setup()
    let report = try await RelationshipUnderstandingUseCases(
      memory: memory,
      analyzer: LocalRelationshipAnalyzer(model: RelationshipWireModel(output: wire()))
    ).analyze(.init(sourceIDs: [source.id], question: "Saved report question", focus: .discussion))
    let repository = SuspendedRelationshipLoadRepository(value: try await memory.snapshot())
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: PersonalMemoryUseCases(repository: repository),
        analyzer: RelationshipFeatureAnalyzer()))
    viewModel.selected = [source.id]
    viewModel.question = "Current question"
    let opening = Task { await viewModel.openSaved(report) }
    await repository.waitUntilStarted()
    opening.cancel()
    let question = viewModel.question
    let selected = viewModel.selected
    let account = viewModel.ownerInterpretation
    let mode = viewModel.mode
    let arabic = viewModel.answerInArabic
    let relationship = viewModel.relationship
    await repository.resume()
    await opening.value
    #expect(viewModel.result == nil && viewModel.error == nil)
    #expect(viewModel.question == question && viewModel.selected == selected)
    #expect(viewModel.ownerInterpretation == account && viewModel.mode == mode)
    #expect(viewModel.answerInArabic == arabic && viewModel.relationship == relationship)
  }

  @Test func suspendedSavedReportFailureDoesNotReplaceNewerInputState() async throws {
    let (memory, source) = try await setup()
    let report = try await RelationshipUnderstandingUseCases(
      memory: memory,
      analyzer: LocalRelationshipAnalyzer(model: RelationshipWireModel(output: wire()))
    ).analyze(.init(sourceIDs: [source.id], question: "Saved report question", focus: .discussion))
    let repository = SuspendedRelationshipLoadRepository(
      value: try await memory.snapshot(), fail: true)
    let viewModel = RelationshipViewModel(
      useCases: .init(
        memory: PersonalMemoryUseCases(repository: repository),
        analyzer: RelationshipFeatureAnalyzer()))
    let opening = Task { await viewModel.openSaved(report) }
    await repository.waitUntilStarted()
    viewModel.question = "Newer question"
    await repository.resume()
    await opening.value
    #expect(viewModel.question == "Newer question")
    #expect(viewModel.result == nil && viewModel.error == nil)
  }

  @Test func openingSavedReportCancelsOlderAnalysisWithTheSameRequest() async throws {
    let (memory, source) = try await setup()
    let original = RelationshipViewModel(
      useCases: .init(
        memory: memory,
        analyzer: LocalRelationshipAnalyzer(model: RelationshipWireModel(output: wire()))))
    original.selected = [source.id]
    original.question = "Saved report question"
    await original.analyze()
    let report = try #require(original.result)
    let gate = SuspendedRelationshipLoadRepository(value: try await memory.snapshot())
    let analyzer = RelationshipFeatureAnalyzer(mutation: { _ = try await gate.load() })
    let viewModel = RelationshipViewModel(useCases: .init(memory: memory, analyzer: analyzer))
    viewModel.selected = original.selected
    viewModel.question = original.question
    let pending = Task { await viewModel.analyze() }
    await gate.waitUntilStarted()
    await viewModel.openSaved(report)
    #expect(!viewModel.isBusy)
    #expect(viewModel.result == report)
    await gate.resume()
    await pending.value
    #expect(viewModel.result == report && viewModel.error == nil)
  }

  @Test func staleRefreshCannotClearANewerOpenedReport() async throws {
    let (memory, source) = try await setup()
    let gate = SuspendedRelationshipLoadRepository(value: try await memory.snapshot())
    let reports = RelationshipFeatureReports(beforeLoad: { _ = try? await gate.load() })
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory,
      analyzer: LocalRelationshipAnalyzer(model: RelationshipWireModel(output: wire())),
      reports: reports)
    let request = RelationshipAnalysisRequest(
      sourceIDs: [source.id], question: "Saved report question", focus: .discussion)
    let oldReport = try await useCases.analyze(request)
    let viewModel = RelationshipViewModel(useCases: useCases)
    await viewModel.openSaved(oldReport)
    _ = try await memory.createProfile(kind: .person, name: "Fictional person")
    let newReport = try await useCases.analyze(request)
    let refresh = Task { await viewModel.load() }
    await gate.waitUntilStarted()
    await viewModel.openSaved(newReport)
    await gate.resume()
    await refresh.value
    #expect(viewModel.result == newReport && viewModel.error == nil)
  }

}
