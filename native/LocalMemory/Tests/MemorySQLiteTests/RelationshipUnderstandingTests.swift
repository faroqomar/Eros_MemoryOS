import Foundation
import MemoryCore
import Testing

private actor RelationshipTestRepository: PersonalMemoryRepository {
  private var snapshot = PersonalMemorySnapshot()
  private(set) var writes = 0
  func load() -> PersonalMemorySnapshot { snapshot }
  func save(_ snapshot: PersonalMemorySnapshot) {
    self.snapshot = snapshot
    writes += 1
  }
}

private struct RelationshipTestAnalyzer: RelationshipAnalyzing {
  let proposal: RelationshipAnalysisProposal
  var duringAnalysis: (@Sendable () async throws -> Void)? = nil
  func analyze(_ input: RelationshipAnalysisInput) async throws -> RelationshipAnalysisProposal {
    try await duringAnalysis?()
    return proposal
  }
}

private actor RelationshipTestReports: RelationshipReportRepository {
  private(set) var value: [RelationshipSavedReport] = []
  private(set) var removed = 0
  func load() -> [RelationshipSavedReport] { value }
  func save(_ report: RelationshipSavedReport) throws {
    value = try RelationshipSavedReport.retaining(report, in: value)
  }
  func remove(_ stale: [RelationshipSavedReport]) throws {
    value = try RelationshipSavedReport.removing(stale, from: value)
    removed += 1
  }
  func removeAll() {
    value = []
    removed += 1
  }
}

private actor RelationshipMutatingReports: RelationshipReportRepository {
  let memory: PersonalMemoryUseCases
  private(set) var value: [RelationshipSavedReport] = []
  init(memory: PersonalMemoryUseCases) { self.memory = memory }
  func load() -> [RelationshipSavedReport] { value }
  func save(_ report: RelationshipSavedReport) async throws {
    _ = try await memory.ingest(source: PersonalMemorySource(text: "Concurrent fictional capture"))
    value = [report]
  }
  func remove(_ stale: [RelationshipSavedReport]) throws {
    value = try RelationshipSavedReport.removing(stale, from: value)
  }
  func removeAll() { value = [] }
}

private struct RelationshipFixture {
  let repository = RelationshipTestRepository()
  let memory: PersonalMemoryUseCases
  let conversation = UUID()
  let first: PersonalMemorySource
  let second: PersonalMemorySource
  let third: PersonalMemorySource

  init() {
    memory = PersonalMemoryUseCases(repository: repository)
    first = PersonalMemorySource(
      conversationID: conversation, text: "Rana: I can meet on Friday.",
      createdAt: Date(timeIntervalSince1970: 100), origin: "fictional imported transcript",
      kind: .fact)
    second = PersonalMemorySource(
      conversationID: conversation, text: "Omar: Friday works for me. Let's meet at six.",
      createdAt: Date(timeIntervalSince1970: 200), origin: "fictional imported transcript",
      kind: .fact)
    third = PersonalMemorySource(
      conversationID: conversation, text: "Rana: I need to change Friday to Saturday.",
      createdAt: Date(timeIntervalSince1970: 300), origin: "fictional imported transcript",
      kind: .fact)
  }

  func seed() async throws {
    for source in [first, second, third] { _ = try await memory.ingest(source: source) }
  }

  func finding(
    kind: RelationshipFindingKind = .agreement, quote: String? = nil,
    sourceID: UUID? = nil, alternatives: [String] = [], tradeoffs: [String] = []
  ) -> RelationshipFinding {
    RelationshipFinding(
      id: "finding", kind: kind, text: "The available messages contain a proposed meeting.",
      evidence: [.init(sourceID: sourceID ?? second.id, quote: quote ?? second.text)],
      alternatives: alternatives, tradeoffs: tradeoffs)
  }

  func useCases(_ proposal: RelationshipAnalysisProposal) -> RelationshipUnderstandingUseCases {
    RelationshipUnderstandingUseCases(
      memory: memory, analyzer: RelationshipTestAnalyzer(proposal: proposal))
  }
}

struct RelationshipUnderstandingTests {
  @Test func sourceContextIncludesDatesNeighborsAndSeparateMemoryLayersWithoutWrites() async throws
  {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let revision = try await fixture.memory.snapshot().revision
    let input = try await fixture.useCases(.init()).prepare(
      .init(sourceIDs: [fixture.second.id], question: "What changed?", relationship: .friend))
    #expect(input.revision == revision)
    #expect(input.sources.map(\.id) == [fixture.second.id])
    #expect(input.sources[0].surrounding.map(\.id) == [fixture.first.id, fixture.third.id])
    #expect(input.sources[0].source.createdAt == Date(timeIntervalSince1970: 200))
    #expect(input.memories.allSatisfy { $0.layer == .extractedInformation })
    #expect(input.limits.contains { $0.contains("one-sided") })
    #expect(try await fixture.memory.snapshot().revision == revision)
  }

  @Test func explicitOwnerCorrectionSeparatesAcceptedInterpretationFromUnreviewedReport()
    async throws
  {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    var snapshot = try await fixture.memory.addEntry(
      text: "They may be changing the plan.", kind: .interpretation,
      sourceIDs: [fixture.second.id])
    let interpretation = try #require(snapshot.entries.first { $0.kind == .interpretation })
    let useCases = fixture.useCases(.init())
    let request = RelationshipAnalysisRequest(sourceIDs: [fixture.second.id], question: "Explain")
    let before = try await useCases.prepare(request)
    #expect(
      before.memories.first { $0.id == interpretation.id }?.layer == .unreviewedInterpretation)
    snapshot = try await fixture.memory.updateEntry(
      id: interpretation.id, text: "My interpretation: they accepted Friday at six.")
    let after = try await useCases.prepare(request)
    #expect(after.memories.first { $0.id == interpretation.id }?.layer == .confirmedInterpretation)
    #expect(snapshot.entries.first { $0.id == interpretation.id }?.confirmed == false)
    #expect(snapshot.sources.first { $0.id == fixture.second.id }?.text == fixture.second.text)
  }

  @Test func keptOwnerAccountSurvivesDerivedReportInvalidationAndPreservesOriginal() async throws {
    let repository = RelationshipTestRepository()
    let memory = PersonalMemoryUseCases(repository: repository)
    let source = PersonalMemorySource(text: "Rana: Friday works.", kind: .conversationOnly)
    _ = try await memory.ingest(source: source)
    let proposal = RelationshipAnalysisProposal(
      findings: [
        .init(
          id: "account", kind: .interpretation, text: "The supplied message accepts Friday.",
          evidence: [.init(sourceID: source.id, quote: source.text)],
          alternatives: ["The owner may mean another unavailable message."])
      ], conflictsWithOwner: true,
      clarification: "Do you mean another message?")
    let reports = RelationshipTestReports()
    let useCases = RelationshipUnderstandingUseCases(
      memory: memory, analyzer: RelationshipTestAnalyzer(proposal: proposal), reports: reports)
    let result = try await useCases.analyze(
      .init(
        sourceIDs: [source.id], question: "Explain the refusal",
        ownerInterpretation: "Rana refused Friday."))
    let kept = try await useCases.save(result)
    #expect(kept.input.revision > result.input.revision)
    let accountSource = try #require(
      try await memory.snapshot().sources.first { $0.origin == "relationship account" })
    #expect(accountSource.text == "Rana refused Friday.")
    #expect(try await memory.snapshot().sources.first { $0.id == source.id } == source)
    let repeated = try await useCases.save(kept)
    #expect(repeated == kept)
    #expect(
      try await memory.snapshot().sources.filter { $0.origin == "relationship account" }.count == 1)
    _ = try await memory.ingest(source: PersonalMemorySource(text: "New unrelated original"))
    #expect(try await useCases.loadSaved().isEmpty)
    let current = try await memory.snapshot()
    let accountEntry = try #require(
      current.entries.first { $0.sourceIDs.contains(accountSource.id) })
    #expect(
      accountEntry.text == "Rana refused Friday."
        && accountEntry.interpretationStatus == .ownerReviewed)
    #expect(!accountEntry.confirmed)
    #expect(current.links.contains { $0.fromID == accountEntry.id && $0.toID == source.id })
    _ = try await memory.updateEntry(id: accountEntry.id, text: "My corrected account")
    #expect(
      try await memory.snapshot().sources.contains {
        $0.id == accountSource.id && $0.text == "Rana refused Friday."
      })
    let erased = try await useCases.forgetSource(sourceID: source.id, confirmed: true)
    #expect(!erased.sources.contains { $0.id == source.id || $0.id == accountSource.id })
    #expect(!erased.entries.contains { $0.id == accountEntry.id })
    try erased.validate()
  }

  @Test func staleOwnerAccountSaveDoesNotWriteCanonicalHistory() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let before = try await fixture.memory.snapshot()
    await #expect(throws: RelationshipUnderstandingError.staleResult) {
      try await fixture.memory.preserveRelationshipAccount(
        sourceIDs: [fixture.second.id], account: "My account", expectedRevision: before.revision - 1
      )
    }
    #expect(try await fixture.memory.snapshot() == before)
  }

  @Test func savePurgesReportIfCanonicalMemoryChangesDuringRepositoryWrite() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let reports = RelationshipMutatingReports(memory: fixture.memory)
    let useCases = RelationshipUnderstandingUseCases(
      memory: fixture.memory,
      analyzer: RelationshipTestAnalyzer(proposal: .init(findings: [fixture.finding()])),
      reports: reports)
    let result = try await useCases.analyze(
      .init(sourceIDs: [fixture.second.id], question: "Explain"))
    await #expect(throws: RelationshipUnderstandingError.staleResult) {
      try await useCases.save(result)
    }
    #expect(await reports.value.isEmpty)
    #expect(
      try await fixture.memory.snapshot().sources.contains {
        $0.id == fixture.second.id && $0.text == fixture.second.text
      })
  }

  @Test func explicitFocusPreventsHypothesesFromBeingMislabelledAsObservations() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    await #expect(throws: RelationshipUnderstandingError.unsupportedCertainty) {
      try await fixture.useCases(.init(findings: [fixture.finding(kind: .agreement)])).analyze(
        .init(sourceIDs: [fixture.second.id], question: "Explain the tone", focus: .patterns))
    }
    let cautious = fixture.finding(
      kind: .communicationPattern,
      alternatives: ["The available record may reflect practical scheduling."])
    let patterns = try await fixture.useCases(.init(findings: [cautious])).analyze(
      .init(sourceIDs: [fixture.second.id], question: "Explain the tone", focus: .patterns))
    #expect(patterns.findings == [cautious])
    for focus in [RelationshipAnalysisFocus.discussion, .draft] {
      await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
        try await fixture.useCases(.init(findings: [cautious])).analyze(
          .init(
            sourceIDs: [fixture.second.id], question: "Explain the original",
            draftRequested: focus == .draft, focus: focus))
      }
    }
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await fixture.useCases(.init(findings: [fixture.finding()])).analyze(
        .init(sourceIDs: [fixture.second.id], question: "What next?", focus: .advice))
    }
    await #expect(throws: RelationshipUnderstandingError.invalidRequest) {
      try await fixture.useCases(.init()).prepare(
        .init(sourceIDs: [fixture.second.id], question: "Draft", focus: .draft))
    }
  }

  @Test func oldReportRequestsDecodeWithoutFocusAndNewFocusSeparatesSavedViews() async throws {
    let request = RelationshipAnalysisRequest(sourceIDs: [], question: "Explain")
    let data = try JSONEncoder().encode(request)
    #expect(try JSONDecoder().decode(RelationshipAnalysisRequest.self, from: data).focus == nil)
    let discussion = RelationshipSavedReport(
      revision: 1,
      request: .init(sourceIDs: [], question: "Same question", focus: .discussion),
      proposal: .init())
    let patterns = RelationshipSavedReport(
      revision: 1,
      request: .init(sourceIDs: [], question: "Same question", focus: .patterns), proposal: .init())
    let both = try RelationshipSavedReport.retaining(patterns, in: [discussion])
    #expect(both.count == 2)
  }

  @Test func summaryFocusCannotReturnAnotherSummaryLayer() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let summary = RelationshipSummary(
      id: "wrong", level: .topic, title: "Meeting", text: "Meeting discussion",
      evidence: [.init(sourceID: fixture.second.id, quote: fixture.second.text)])
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await fixture.useCases(.init(summaries: [summary])).analyze(
        .init(
          sourceIDs: [fixture.second.id], question: "Conversation summary", focus: .conversation))
    }
  }

  @Test func noEvidenceAbstainsWithoutModelOrFabricatedSummary() async throws {
    let fixture = RelationshipFixture()
    let useCases = fixture.useCases(.init(draft: "Should not be delivered"))
    let result = try await useCases.analyze(.init(sourceIDs: [], question: "What happened?"))
    #expect(result.insufficientEvidence)
    #expect(result.findings.isEmpty && result.summaries.isEmpty && result.draft == nil)
  }

  @Test(arguments: ["Friday WORKS for me", "There was no disagreement", ""])
  func inventedOrChangedQuotesAreRejected(quote: String) async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let useCases = fixture.useCases(.init(findings: [fixture.finding(quote: quote)]))
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await useCases.analyze(.init(sourceIDs: [fixture.second.id], question: "What happened?"))
    }
  }

  @Test func unrelatedSourceIDCannotSupplyEvidenceEvenWhenQuoteMatches() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let unrelated = PersonalMemorySource(text: fixture.second.text, kind: .fact)
    _ = try await fixture.memory.ingest(source: unrelated)
    let useCases = fixture.useCases(.init(findings: [fixture.finding(sourceID: unrelated.id)]))
    await #expect(throws: RelationshipUnderstandingError.missingSource) {
      try await useCases.analyze(.init(sourceIDs: [fixture.second.id], question: "What happened?"))
    }
  }

  @Test(arguments: [
    RelationshipFindingKind.possibleEmotion, .communicationPattern, .interpretation,
  ])
  func psychologicalFindingsRequireAlternatives(kind: RelationshipFindingKind) async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    await #expect(throws: RelationshipUnderstandingError.unsupportedCertainty) {
      try await fixture.useCases(.init(findings: [fixture.finding(kind: kind)])).analyze(
        .init(sourceIDs: [fixture.second.id], question: "Explain the tone"))
    }
    let result = try await fixture.useCases(
      .init(findings: [
        fixture.finding(kind: kind, alternatives: ["The phrasing may simply reflect scheduling."])
      ])
    ).analyze(.init(sourceIDs: [fixture.second.id], question: "Explain the tone"))
    #expect(result.findings.count == 1)
  }

  @Test func adviceRequiresTradeoffsAndDraftNeedsSpecificRequest() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await fixture.useCases(.init(findings: [fixture.finding(kind: .nextStep)])).analyze(
        .init(sourceIDs: [fixture.second.id], question: "What next?"))
    }
    let advice = fixture.finding(kind: .nextStep, tradeoffs: ["Asking now may interrupt them."])
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await fixture.useCases(.init(findings: [advice], draft: "Can we confirm Saturday?"))
        .analyze(
          .init(sourceIDs: [fixture.second.id], question: "What next?"))
    }
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await fixture.useCases(.init(draft: "Can we confirm Saturday?"))
        .analyze(
          .init(sourceIDs: [fixture.second.id], question: "Draft a reply", draftRequested: true))
    }
    let result = try await fixture.useCases(
      .init(findings: [advice], draft: "Can we confirm Saturday?")
    )
    .analyze(.init(sourceIDs: [fixture.second.id], question: "Draft a reply", draftRequested: true))
    #expect(result.draft == "Can we confirm Saturday?")
  }

  @Test func conflictingOwnerAccountStopsAdviceAndRetainsOriginalAndAccount() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let request = RelationshipAnalysisRequest(
      sourceIDs: [fixture.second.id], question: "Why did they refuse?",
      ownerInterpretation: "They refused Friday.")
    let result = try await fixture.useCases(
      .init(
        findings: [fixture.finding()], conflictsWithOwner: true,
        clarification: "Do you mean a later message? This available message accepts Friday.",
        draft: nil)
    ).analyze(request)
    #expect(result.findings.isEmpty && result.summaries.isEmpty && result.draft == nil)
    #expect(result.clarification != nil)
    #expect(result.input.request.ownerInterpretation == "They refused Friday.")
    #expect(result.input.sources[0].source.text == fixture.second.text)
  }

  @Test func timelinesUseRecordDatesAndSummariesLinkOriginals() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let summary = RelationshipSummary(
      id: "conversation", level: .conversation, title: "Meeting plan",
      text: "The plan changed in the available conversation.",
      evidence: [.init(sourceID: fixture.third.id, quote: fixture.third.text)])
    let result = try await fixture.useCases(
      .init(
        findings: [fixture.finding(kind: .changeOverTime)], summaries: [summary])
    ).analyze(
      .init(sourceIDs: [fixture.second.id], question: "Summarize the discussion"))
    #expect(result.timeline[0].firstRecordedAt == fixture.second.createdAt)
    #expect(result.summaries[0].evidence[0].sourceID == fixture.third.id)
  }

  @Test func conversationSummaryCannotCombineDifferentConversations() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let unrelated = PersonalMemorySource(
      conversationID: UUID(), text: "Other discussion", kind: .fact)
    _ = try await fixture.memory.ingest(source: unrelated)
    let summary = RelationshipSummary(
      id: "mixed", level: .conversation, title: "Wrong grouping", text: "Combined",
      evidence: [
        .init(sourceID: fixture.second.id, quote: fixture.second.text),
        .init(sourceID: unrelated.id, quote: unrelated.text),
      ])
    await #expect(throws: RelationshipUnderstandingError.invalidProposal) {
      try await fixture.useCases(.init(summaries: [summary])).analyze(
        .init(sourceIDs: [fixture.second.id, unrelated.id], question: "Summarize"))
    }
  }

  @Test func correctionDuringAnalysisRejectsStaleModelResult() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let entry = try #require(try await fixture.memory.snapshot().entries.first)
    let analyzer = RelationshipTestAnalyzer(proposal: .init(findings: [fixture.finding()])) {
      _ = try await fixture.memory.updateEntry(id: entry.id, text: "Corrected account")
    }
    let useCases = RelationshipUnderstandingUseCases(memory: fixture.memory, analyzer: analyzer)
    await #expect(throws: RelationshipUnderstandingError.staleResult) {
      try await useCases.analyze(.init(sourceIDs: [fixture.second.id], question: "Explain"))
    }
  }

  @Test func forgettingRequiresConfirmationAndRemovesDerivedAndUndoCopies() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let original = try await fixture.memory.snapshot()
    await #expect(throws: PersonalMemoryError.confirmationRequired) {
      try await fixture.memory.forgetSource(sourceID: fixture.second.id, confirmed: false)
    }
    #expect(try await fixture.memory.snapshot() == original)
    let result = try await fixture.memory.forgetSource(sourceID: fixture.second.id, confirmed: true)
    #expect(!result.sources.contains { $0.id == fixture.second.id })
    #expect(!result.entries.contains { $0.sourceIDs.contains(fixture.second.id) })
    #expect(result.events.isEmpty)
    #expect(result.sources.contains { $0.id == fixture.first.id && $0.text == fixture.first.text })
    try result.validate()
    await #expect(throws: PersonalMemoryError.nothingToUndo) { try await fixture.memory.undo() }
    let exported = try await fixture.memory.exportArchive()
    #expect(!String(decoding: exported, as: UTF8.self).contains(fixture.second.text))
  }

  @Test(arguments: RelationshipKind.allCases)
  func relationshipKindsDoNotFilterEitherParticipantsHistory(kind: RelationshipKind) async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let result = try await fixture.useCases(.init(findings: [fixture.finding()])).analyze(
      .init(
        sourceIDs: [fixture.first.id, fixture.second.id], question: "Explain", relationship: kind))
    #expect(result.input.sources.count == 2)
    #expect(result.input.request.relationship == kind)
  }

  @Test func savedLayeredReportReopensAndCorrectionPurgesObsoleteDerivedText() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let reports = RelationshipTestReports()
    let useCases = RelationshipUnderstandingUseCases(
      memory: fixture.memory,
      analyzer: RelationshipTestAnalyzer(
        proposal: .init(
          findings: [fixture.finding()],
          summaries: [
            RelationshipSummary(
              id: "topic", level: .topic, title: "Meeting", text: "A Friday meeting was discussed.",
              evidence: [.init(sourceID: fixture.second.id, quote: fixture.second.text)])
          ])), reports: reports)
    let result = try await useCases.analyze(
      .init(sourceIDs: [fixture.second.id], question: "Summarize"))
    try await useCases.save(result)
    #expect(try await useCases.loadSaved() == [result])
    let encoded = try JSONEncoder().encode(await reports.value)
    #expect(!String(decoding: encoded, as: UTF8.self).contains("surrounding"))
    let entry = try #require(try await fixture.memory.snapshot().entries.first)
    _ = try await fixture.memory.updateEntry(id: entry.id, text: "Corrected account")
    #expect(try await useCases.loadSaved().isEmpty)
    #expect(await reports.value.isEmpty)
    await #expect(throws: RelationshipUnderstandingError.staleResult) {
      try await useCases.save(result)
    }
  }

  @Test func confirmedForgettingErasesSavedReportBeforeOriginal() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let reports = RelationshipTestReports()
    let useCases = RelationshipUnderstandingUseCases(
      memory: fixture.memory,
      analyzer: RelationshipTestAnalyzer(proposal: .init(findings: [fixture.finding()])),
      reports: reports)
    let result = try await useCases.analyze(
      .init(sourceIDs: [fixture.second.id], question: "Explain"))
    try await useCases.save(result)
    await #expect(throws: PersonalMemoryError.confirmationRequired) {
      try await useCases.forgetSource(sourceID: fixture.second.id, confirmed: false)
    }
    #expect(await !reports.value.isEmpty)
    _ = try await useCases.forgetSource(sourceID: fixture.second.id, confirmed: true)
    #expect(await reports.value.isEmpty)
    #expect(try await useCases.loadSaved().isEmpty)
  }

  @Test func proactiveInsightsUseSavedCategoriesAndCommitmentsAndRebuildAfterDeletion() async throws
  {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    _ = try await fixture.memory.addEntry(
      text: "Review meeting commitment", kind: .commitment, sourceIDs: [fixture.second.id])
    var snapshot = try await fixture.memory.snapshot()
    let firstEntry = try #require(
      snapshot.entries.first { $0.sourceIDs.contains(fixture.first.id) })
    let secondEntry = try #require(
      snapshot.entries.first { $0.sourceIDs.contains(fixture.second.id) })
    _ = try await fixture.memory.organize(
      entryID: firstEntry.id, categories: ["meeting"], profileIDs: [])
    snapshot = try await fixture.memory.organize(
      entryID: secondEntry.id, categories: ["meeting"], profileIDs: [])
    let insights = RelationshipInsightProjector.project(snapshot)
    #expect(insights.contains { $0.kind == .commitmentReview })
    #expect(insights.contains { $0.kind == .recurringTopic && $0.topic == "meeting" })
    let deleted = try await fixture.memory.forgetSource(
      sourceID: fixture.second.id, confirmed: true)
    #expect(RelationshipInsightProjector.project(deleted).isEmpty)
    #expect(RelationshipInsightProjector.project(snapshot, limit: 0).isEmpty)
  }

  @Test func savedReportsKeepEachSummaryLayerAndBoundHistory() async throws {
    let fixture = RelationshipFixture()
    try await fixture.seed()
    let reports = RelationshipTestReports()
    let snapshot = try await fixture.memory.snapshot()
    for level in RelationshipSummaryLevel.allCases {
      let report = RelationshipSavedReport(
        revision: snapshot.revision,
        request: .init(sourceIDs: [fixture.second.id], question: "Summarize \(level.rawValue)"),
        proposal: .init(summaries: [
          .init(
            id: level.rawValue, level: level, title: "Meeting", text: "A meeting was discussed.",
            evidence: [.init(sourceID: fixture.second.id, quote: fixture.second.text)])
        ]))
      try await reports.save(report)
    }
    let useCases = RelationshipUnderstandingUseCases(
      memory: fixture.memory, analyzer: RelationshipTestAnalyzer(proposal: .init()),
      reports: reports)
    let restored = try await useCases.loadSaved()
    #expect(
      Set(restored.flatMap(\.summaries).map(\.level)) == Set(RelationshipSummaryLevel.allCases))
    for index in 0..<20 {
      try await reports.save(
        RelationshipSavedReport(
          revision: snapshot.revision,
          request: .init(sourceIDs: [fixture.second.id], question: "Question \(index)"),
          proposal: .init()))
    }
    #expect(await reports.value.count == 12)
    let last = try #require(await reports.value.last)
    try await reports.save(last)
    #expect(await reports.value.count == 12)
    let stale = RelationshipSavedReport(
      revision: snapshot.revision - 1, request: last.request, proposal: last.proposal)
    await #expect(throws: RelationshipUnderstandingError.staleResult) {
      try await reports.save(stale)
    }
    #expect(await reports.value.count == 12)
  }

  @Test func oversizedOriginalSelectionRefusesInsteadOfTruncatingContext() async throws {
    let fixture = RelationshipFixture()
    let originals = (0..<3).map { index in
      PersonalMemorySource(text: String(repeating: "x", count: 20_000) + "\(index)")
    }
    for original in originals { _ = try await fixture.memory.ingest(source: original) }
    let before = try await fixture.memory.snapshot()
    await #expect(throws: RelationshipUnderstandingError.inputTooLarge) {
      try await fixture.useCases(.init()).prepare(
        .init(sourceIDs: originals.map(\.id), question: "Explain these"))
    }
    #expect(try await fixture.memory.snapshot() == before)
  }
}
