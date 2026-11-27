import Foundation

/// Read-only analysis. It cannot replace originals, change confirmed facts or send replies.
public struct RelationshipUnderstandingUseCases: Sendable {
  public let memory: PersonalMemoryUseCases
  private let analyzer: any RelationshipAnalyzing
  private let reports: (any RelationshipReportRepository)?

  public init(
    memory: PersonalMemoryUseCases, analyzer: any RelationshipAnalyzing,
    reports: (any RelationshipReportRepository)? = nil
  ) {
    self.memory = memory
    self.analyzer = analyzer
    self.reports = reports
  }

  public func prepare(_ request: RelationshipAnalysisRequest) async throws
    -> RelationshipAnalysisInput
  {
    let snapshot = try await memory.snapshot()
    guard !request.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      request.question.utf8.count <= 2_000,
      request.ownerInterpretation.map({ !$0.isEmpty && $0.utf8.count <= 4_000 }) ?? true,
      request.sourceIDs.count <= 40,
      Set(request.sourceIDs).count == request.sourceIDs.count
    else { throw RelationshipUnderstandingError.invalidRequest }
    if let focus = request.focus, (focus == .draft) != request.draftRequested {
      throw RelationshipUnderstandingError.invalidRequest
    }
    let selected = Set(request.sourceIDs)
    guard selected.isSubset(of: Set(snapshot.sources.map(\.id))) else {
      throw RelationshipUnderstandingError.missingSource
    }
    let ordered = snapshot.sources.sorted {
      $0.createdAt == $1.createdAt
        ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
    }
    var contexts: [RelationshipSourceContext] = []
    for source in ordered where selected.contains(source.id) {
      let conversation =
        source.conversationID.map { conversation in
          ordered.filter { $0.conversationID == conversation }
        } ?? [source]
      let index = conversation.firstIndex(where: { $0.id == source.id })!
      let surrounding = Array(
        conversation[max(0, index - 1)...min(conversation.count - 1, index + 1)]
      )
      .filter { $0.id != source.id }
      contexts.append(RelationshipSourceContext(source: source, surrounding: surrounding))
    }
    let visibleSources = Set(contexts.flatMap { [$0.source.id] + $0.surrounding.map(\.id) })
    let memories = snapshot.currentEntries.filter {
      !$0.sourceIDs.isEmpty && Set($0.sourceIDs).isSubset(of: visibleSources)
    }.map { entry in
      RelationshipMemoryContext(
        entry: entry,
        layer: entry.kind == .interpretation
          ? (entry.interpretationStatus == .ownerReviewed
            ? .confirmedInterpretation
            : entry.interpretationStatus == .aiProposed ? .aiHypothesis : .unreviewedInterpretation)
          : (entry.confirmed ? .ownerConfirmedInformation : .extractedInformation))
    }
    let input = RelationshipAnalysisInput(
      revision: snapshot.revision, request: request, sources: contexts, memories: memories,
      limits: [
        "Available history may be one-sided, incomplete or missing messages.",
        "Source dates record capture time unless the original states an event date.",
        "Origin labels do not establish the speaker. Do not invent participant attribution.",
        "Sarcasm, language, culture and missing context can change interpretation.",
        "Emotions, motives and patterns are hypotheses. Do not diagnose or assign personality labels.",
        "Silence does not prove agreement, commitment completion, intent or relationship closeness.",
        "An owner's confirmed account is a reported account, not independent proof.",
      ])
    // A bounded selection must fit the local model. Never truncate evidence without disclosure.
    guard try JSONEncoder().encode(input).count <= 48_000 else {
      throw RelationshipUnderstandingError.inputTooLarge
    }
    return input
  }

  public func analyze(_ request: RelationshipAnalysisRequest) async throws
    -> RelationshipUnderstandingResult
  {
    let input = try await prepare(request)
    try Task.checkCancellation()
    guard !input.sources.isEmpty else {
      return RelationshipUnderstandingResult(
        input: input, proposal: .init(), findings: [], summaries: [], timeline: [],
        clarification: nil,
        draft: nil, insufficientEvidence: true)
    }
    let proposal = try await analyzer.analyze(input)
    try Task.checkCancellation()
    guard try await memory.snapshot().revision == input.revision else {
      throw RelationshipUnderstandingError.staleResult
    }
    return try Self.validate(proposal, input: input)
  }

  public func isCurrent(_ result: RelationshipUnderstandingResult) async throws -> Bool {
    try await memory.snapshot().revision == result.input.revision
  }

  @discardableResult
  public func save(_ result: RelationshipUnderstandingResult) async throws
    -> RelationshipUnderstandingResult
  {
    guard let reports else { throw RelationshipUnderstandingError.invalidRequest }
    guard try await isCurrent(result) else { throw RelationshipUnderstandingError.staleResult }
    _ = try Self.validate(result.proposal, input: result.input)
    var kept = result
    if let account = result.input.request.ownerInterpretation {
      let snapshot = try await memory.preserveRelationshipAccount(
        sourceIDs: result.input.request.sourceIDs, account: account,
        expectedRevision: result.input.revision)
      let input = try await prepare(result.input.request)
      guard input.revision == snapshot.revision else {
        throw RelationshipUnderstandingError.staleResult
      }
      kept = try Self.validate(result.proposal, input: input)
    }
    let report = RelationshipSavedReport(
      revision: kept.input.revision, request: kept.input.request, proposal: kept.proposal)
    guard try JSONEncoder().encode(report).count <= 40_000 else {
      throw RelationshipUnderstandingError.inputTooLarge
    }
    try await reports.save(report)
    guard try await isCurrent(kept) else {
      try await reports.remove([report])
      throw RelationshipUnderstandingError.staleResult
    }
    return kept
  }

  public func loadSaved() async throws -> [RelationshipUnderstandingResult] {
    guard let reports else { return [] }
    let saved = try await reports.load()
    guard saved.count <= 12, try JSONEncoder().encode(saved).count <= 256_000 else {
      try await reports.remove(saved)
      throw RelationshipUnderstandingError.invalidProposal
    }
    let revision = try await memory.snapshot().revision
    guard saved.allSatisfy({ $0.revision == revision }) else {
      try await reports.remove(saved)
      return []
    }
    var results: [RelationshipUnderstandingResult] = []
    do {
      for report in saved {
        guard report.formatVersion == 1, report.createdAt.timeIntervalSince1970.isFinite,
          try JSONEncoder().encode(report).count <= 40_000
        else { throw RelationshipUnderstandingError.invalidProposal }
        let input = try await prepare(report.request)
        guard input.revision == report.revision else {
          try await reports.remove(saved)
          return []
        }
        results.append(try Self.validate(report.proposal, input: input))
      }
    } catch {
      try await reports.remove(saved)
      throw error
    }
    guard try await memory.snapshot().revision == revision else {
      try await reports.remove(saved)
      return []
    }
    return results
  }

  /// Call before source/interpretation edits so obsolete derived text leaves disk too.
  public func invalidateReports() async throws { try await reports?.removeAll() }

  public func forgetSource(sourceID: UUID, confirmed: Bool) async throws -> PersonalMemorySnapshot {
    guard confirmed else { throw PersonalMemoryError.confirmationRequired }
    try await invalidateReports()
    return try await memory.forgetSource(sourceID: sourceID, confirmed: true)
  }

  public static func validate(
    _ proposal: RelationshipAnalysisProposal, input: RelationshipAnalysisInput
  ) throws -> RelationshipUnderstandingResult {
    guard proposal.findings.count <= 24, proposal.summaries.count <= 12,
      Set(proposal.findings.map(\.id)).count == proposal.findings.count,
      Set(proposal.summaries.map(\.id)).count == proposal.summaries.count,
      proposal.draft == nil || (input.request.draftRequested && !proposal.findings.isEmpty),
      try JSONEncoder().encode(proposal).count <= 32_000
    else { throw RelationshipUnderstandingError.invalidProposal }
    let originals = Dictionary(
      (input.sources.flatMap { [$0.source] + $0.surrounding }).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    func text(_ value: String, limit: Int = 4_000) throws {
      guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        value.utf8.count <= limit
      else { throw RelationshipUnderstandingError.invalidProposal }
    }
    func evidence(_ values: [PersonalMemoryEvidence], required: Bool = true) throws {
      guard !required || !values.isEmpty, values.count <= 16 else {
        throw RelationshipUnderstandingError.invalidProposal
      }
      for value in values {
        try text(value.quote, limit: 8_000)
        guard let original = originals[value.sourceID] else {
          throw RelationshipUnderstandingError.missingSource
        }
        // Use exact UTF-8 matching. Canonical equivalence cannot validate a quotation.
        guard Data(original.text.utf8).range(of: Data(value.quote.utf8)) != nil else {
          throw RelationshipUnderstandingError.invalidProposal
        }
      }
    }
    for finding in proposal.findings {
      try text(finding.id, limit: 80)
      try text(finding.text)
      try evidence(finding.evidence)
      try evidence(finding.counterevidence, required: false)
      guard finding.alternatives.count <= 6, finding.tradeoffs.count <= 6 else {
        throw RelationshipUnderstandingError.invalidProposal
      }
      for alternative in finding.alternatives { try text(alternative, limit: 2_000) }
      for tradeoff in finding.tradeoffs { try text(tradeoff, limit: 2_000) }
      if finding.kind.requiresAlternatives && finding.alternatives.isEmpty {
        throw RelationshipUnderstandingError.unsupportedCertainty
      }
      if finding.kind == .nextStep && finding.tradeoffs.isEmpty {
        throw RelationshipUnderstandingError.invalidProposal
      }
      if input.request.focus == .patterns && !finding.kind.requiresAlternatives {
        throw RelationshipUnderstandingError.unsupportedCertainty
      }
      if input.request.focus == .advice && proposal.clarification == nil
        && finding.kind != .nextStep
      {
        throw RelationshipUnderstandingError.invalidProposal
      }
      if [.discussion, .draft].contains(input.request.focus), proposal.clarification == nil,
        finding.kind.requiresAlternatives || finding.kind == .nextStep
      {
        throw RelationshipUnderstandingError.invalidProposal
      }
    }
    for summary in proposal.summaries {
      try text(summary.id, limit: 80)
      try text(summary.title, limit: 240)
      try text(summary.text)
      try evidence(summary.evidence)
      let expectedLevel: RelationshipSummaryLevel?
      switch input.request.focus {
      case .conversation: expectedLevel = .conversation
      case .topic: expectedLevel = .topic
      case .period: expectedLevel = .period
      default: expectedLevel = nil
      }
      if let expectedLevel, summary.level != expectedLevel {
        throw RelationshipUnderstandingError.invalidProposal
      }
      if summary.level == .conversation {
        let conversations = summary.evidence.compactMap { originals[$0.sourceID]?.conversationID }
        guard conversations.count == summary.evidence.count, Set(conversations).count == 1 else {
          throw RelationshipUnderstandingError.invalidProposal
        }
      }
    }
    if let draft = proposal.draft { try text(draft) }
    if let clarification = proposal.clarification { try text(clarification, limit: 1_600) }
    if proposal.conflictsWithOwner {
      guard input.request.ownerInterpretation != nil, let clarification = proposal.clarification,
        !proposal.findings.isEmpty
      else { throw RelationshipUnderstandingError.invalidProposal }
      // Preserve input/account and evidence; do not deliver advice before clarification.
      return RelationshipUnderstandingResult(
        input: input, proposal: proposal, findings: [], summaries: [], timeline: [],
        clarification: clarification,
        draft: nil, insufficientEvidence: false)
    }
    if proposal.clarification != nil {
      return RelationshipUnderstandingResult(
        input: input, proposal: proposal, findings: [], summaries: [], timeline: [],
        clarification: proposal.clarification, draft: nil, insufficientEvidence: false)
    }
    var timeline: [RelationshipTimelineEvent] = []
    let timelineKinds: Set<RelationshipFindingKind> = [
      .agreement, .disagreement, .unresolved, .commitment, .repairAttempt, .changeOverTime,
    ]
    for finding in proposal.findings where timelineKinds.contains(finding.kind) {
      var dates: [Date] = []
      for quote in finding.evidence {
        if let source = originals[quote.sourceID] { dates.append(source.createdAt) }
      }
      if let first = dates.min(), let last = dates.max() {
        timeline.append(
          RelationshipTimelineEvent(
            finding: finding, firstRecordedAt: first, lastRecordedAt: last))
      }
    }
    timeline.sort {
      $0.firstRecordedAt == $1.firstRecordedAt
        ? $0.id < $1.id : $0.firstRecordedAt < $1.firstRecordedAt
    }
    return RelationshipUnderstandingResult(
      input: input, proposal: proposal, findings: proposal.findings, summaries: proposal.summaries,
      timeline: timeline,
      clarification: nil, draft: proposal.draft,
      insufficientEvidence: proposal.findings.isEmpty && proposal.summaries.isEmpty)
  }
}
