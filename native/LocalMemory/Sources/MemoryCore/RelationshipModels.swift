import Foundation

public enum RelationshipKind: String, Codable, CaseIterable, Sendable {
  case unspecified, partner, friend, family, colleague
}

public enum RelationshipAnalysisFocus: String, Codable, CaseIterable, Sendable {
  case discussion, patterns, advice, draft, conversation, topic, period
}

public enum RelationshipMemoryLayer: String, Codable, Sendable {
  case originalStatement, extractedInformation, ownerConfirmedInformation
  case confirmedInterpretation, aiHypothesis, unreviewedInterpretation
}

public enum RelationshipFindingKind: String, Codable, CaseIterable, Sendable {
  case agreement, disagreement, unresolved, commitment, repairAttempt, changeOverTime
  case possibleEmotion, communicationPattern, interpretation, nextStep, insight

  public var requiresAlternatives: Bool {
    [.possibleEmotion, .communicationPattern, .interpretation].contains(self)
  }
}

public struct RelationshipAnalysisRequest: Codable, Equatable, Sendable {
  public let sourceIDs: [UUID]
  public let question: String
  public let ownerInterpretation: String?
  public let draftRequested: Bool
  public let relationship: RelationshipKind
  public let focus: RelationshipAnalysisFocus?

  public init(
    sourceIDs: [UUID], question: String, ownerInterpretation: String? = nil,
    draftRequested: Bool = false, relationship: RelationshipKind = .unspecified,
    focus: RelationshipAnalysisFocus? = nil
  ) {
    self.sourceIDs = sourceIDs
    self.question = question
    self.ownerInterpretation = ownerInterpretation
    self.draftRequested = draftRequested
    self.relationship = relationship
    self.focus = focus
  }
}

public struct RelationshipSourceContext: Codable, Equatable, Identifiable, Sendable {
  public let source: PersonalMemorySource
  public let surrounding: [PersonalMemorySource]
  public var id: UUID { source.id }
}

public struct RelationshipMemoryContext: Codable, Equatable, Identifiable, Sendable {
  public let entry: PersonalMemoryEntry
  public let layer: RelationshipMemoryLayer
  public var id: UUID { entry.id }
}

/// Contains available records only. Origin is a provenance label, not proof of authorship.
public struct RelationshipAnalysisInput: Codable, Equatable, Sendable {
  public let revision: UInt64
  public let request: RelationshipAnalysisRequest
  public let sources: [RelationshipSourceContext]
  public let memories: [RelationshipMemoryContext]
  public let limits: [String]
}

public struct RelationshipFinding: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let kind: RelationshipFindingKind
  public let text: String
  public let evidence: [PersonalMemoryEvidence]
  public let alternatives: [String]
  public let counterevidence: [PersonalMemoryEvidence]
  public let tradeoffs: [String]

  public init(
    id: String, kind: RelationshipFindingKind, text: String,
    evidence: [PersonalMemoryEvidence], alternatives: [String] = [],
    counterevidence: [PersonalMemoryEvidence] = [], tradeoffs: [String] = []
  ) {
    self.id = id
    self.kind = kind
    self.text = text
    self.evidence = evidence
    self.alternatives = alternatives
    self.counterevidence = counterevidence
    self.tradeoffs = tradeoffs
  }
}

public enum RelationshipSummaryLevel: String, Codable, CaseIterable, Sendable {
  case conversation, topic, period
}

public struct RelationshipSummary: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let level: RelationshipSummaryLevel
  public let title: String
  public let text: String
  public let evidence: [PersonalMemoryEvidence]

  public init(
    id: String, level: RelationshipSummaryLevel, title: String, text: String,
    evidence: [PersonalMemoryEvidence]
  ) {
    self.id = id
    self.level = level
    self.title = title
    self.text = text
    self.evidence = evidence
  }
}

/// Untrusted model output. Domain checks provenance and presentation gates before use.
public struct RelationshipAnalysisProposal: Codable, Equatable, Sendable {
  public let findings: [RelationshipFinding]
  public let summaries: [RelationshipSummary]
  public let conflictsWithOwner: Bool
  public let clarification: String?
  public let draft: String?

  public init(
    findings: [RelationshipFinding] = [], summaries: [RelationshipSummary] = [],
    conflictsWithOwner: Bool = false, clarification: String? = nil, draft: String? = nil
  ) {
    self.findings = findings
    self.summaries = summaries
    self.conflictsWithOwner = conflictsWithOwner
    self.clarification = clarification
    self.draft = draft
  }
}

public protocol RelationshipAnalyzing: Sendable {
  func analyze(_ input: RelationshipAnalysisInput) async throws -> RelationshipAnalysisProposal
}

public struct RelationshipTimelineEvent: Equatable, Identifiable, Sendable {
  public let finding: RelationshipFinding
  /// Dates describe the supporting records; they do not establish an event's exact date.
  public let firstRecordedAt: Date
  public let lastRecordedAt: Date
  public var id: String { finding.id }
}

public struct RelationshipUnderstandingResult: Equatable, Sendable {
  public let input: RelationshipAnalysisInput
  public let proposal: RelationshipAnalysisProposal
  public let findings: [RelationshipFinding]
  public let summaries: [RelationshipSummary]
  public let timeline: [RelationshipTimelineEvent]
  public let clarification: String?
  public let draft: String?
  public let insufficientEvidence: Bool
}

/// A rebuildable, bounded derived report. Originals remain in the memory repository.
public struct RelationshipSavedReport: Codable, Equatable, Sendable {
  public let formatVersion: Int
  public let revision: UInt64
  public let request: RelationshipAnalysisRequest
  public let proposal: RelationshipAnalysisProposal
  public let createdAt: Date

  public init(
    revision: UInt64, request: RelationshipAnalysisRequest,
    proposal: RelationshipAnalysisProposal, createdAt: Date = Date()
  ) {
    formatVersion = 1
    self.revision = revision
    self.request = request
    self.proposal = proposal
    self.createdAt = createdAt
  }
}

public protocol RelationshipReportRepository: Sendable {
  func load() async throws -> [RelationshipSavedReport]
  func save(_ report: RelationshipSavedReport) async throws
  /// Atomically remove only these observed versions, preserving concurrent replacements.
  func remove(_ reports: [RelationshipSavedReport]) async throws
  func removeAll() async throws
}

public enum RelationshipUnderstandingError: Error, Equatable, Sendable {
  case invalidRequest, missingSource, inputTooLarge, invalidProposal, unsupportedCertainty
  case staleResult
}

extension RelationshipSavedReport {
  /// Adapters call this inside the same serialized read/write transaction as `retaining`.
  public static func removing(
    _ stale: [RelationshipSavedReport], from existing: [RelationshipSavedReport]
  ) throws -> [RelationshipSavedReport] {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let observed = Set(try stale.map { try encoder.encode($0) })
    // Compare stored bytes, including dates and Unicode spelling, rather than request identity.
    return try existing.filter { try !observed.contains(encoder.encode($0)) }
  }

  /// Repository adapters call this inside their serialized read/write transaction.
  public static func retaining(
    _ report: RelationshipSavedReport, in existing: [RelationshipSavedReport]
  ) throws -> [RelationshipSavedReport] {
    guard report.formatVersion == 1, report.createdAt.timeIntervalSince1970.isFinite,
      try JSONEncoder().encode(report).count <= 40_000
    else { throw RelationshipUnderstandingError.invalidProposal }
    guard !existing.contains(where: { $0.revision > report.revision }) else {
      throw RelationshipUnderstandingError.staleResult
    }
    let request = report.request
    var retained = existing.filter { old in
      old.formatVersion == 1 && old.revision == report.revision
        && !(Set(old.request.sourceIDs) == Set(request.sourceIDs)
          && old.request.question == request.question
          && old.request.ownerInterpretation == request.ownerInterpretation
          && old.request.draftRequested == request.draftRequested
          && old.request.relationship == request.relationship
          && old.request.focus == request.focus)
    }
    retained.append(report)
    retained = Array(retained.suffix(12))
    while try JSONEncoder().encode(retained).count > 256_000 && retained.count > 1 {
      retained.removeFirst()
    }
    return retained
  }
}
