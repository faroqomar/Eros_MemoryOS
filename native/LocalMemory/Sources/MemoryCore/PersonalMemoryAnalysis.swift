import Foundation

public enum PersonalMemoryAnalysisStatus: String, Codable, Equatable, Sendable {
  case pending, processed, needsClarification, deferred, ignored
}

/// Processing metadata never changes the source's original text, identity, or date.
public struct PersonalMemoryAnalysisState: Codable, Equatable, Sendable {
  public var status: PersonalMemoryAnalysisStatus
  /// The latest attached answer keeps its asked question after processing as well as during retry.
  public var question: String?
  public var quote: String?
  public var answerSourceID: UUID?
  public var protectedEntryID: UUID?
  public var appliedRevision: UInt64?
  public var version: Int
  /// An answered or dismissed question must not consume another disputed clause.
  public var hasDeferredRemainder: Bool?

  public init(
    status: PersonalMemoryAnalysisStatus, question: String? = nil, quote: String? = nil,
    answerSourceID: UUID? = nil, protectedEntryID: UUID? = nil,
    appliedRevision: UInt64? = nil, version: Int = 1, hasDeferredRemainder: Bool? = nil
  ) {
    self.status = status
    self.question = question
    self.quote = quote
    self.answerSourceID = answerSourceID
    self.protectedEntryID = protectedEntryID
    self.appliedRevision = appliedRevision
    self.version = version
    self.hasDeferredRemainder = hasDeferredRemainder
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    func same(_ left: String?, _ right: String?) -> Bool {
      switch (left, right) {
      case (nil, nil): true
      case (.some(let left), .some(let right)): left.utf8.elementsEqual(right.utf8)
      default: false
      }
    }
    return lhs.status == rhs.status && same(lhs.question, rhs.question)
      && same(lhs.quote, rhs.quote)
      && lhs.answerSourceID == rhs.answerSourceID && lhs.protectedEntryID == rhs.protectedEntryID
      && lhs.appliedRevision == rhs.appliedRevision && lhs.version == rhs.version
      && lhs.hasDeferredRemainder == rhs.hasDeferredRemainder
  }
}

/// Immutable provenance for one clarification answer, independent of the bounded undo history.
public struct PersonalMemoryClarificationContext: Codable, Equatable, Sendable {
  public let parentSourceID: UUID
  public let question: String
  public let quote: String

  public init(parentSourceID: UUID, question: String, quote: String) {
    self.parentSourceID = parentSourceID
    self.question = question
    self.quote = quote
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.parentSourceID == rhs.parentSourceID
      && lhs.question.utf8.elementsEqual(rhs.question.utf8)
      && lhs.quote.utf8.elementsEqual(rhs.quote.utf8)
  }
}

public struct PersonalMemoryEvidence: Codable, Equatable, Sendable {
  public let sourceID: UUID
  public let quote: String
  public init(sourceID: UUID, quote: String) {
    self.sourceID = sourceID
    self.quote = quote
  }
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.sourceID == rhs.sourceID && lhs.quote.utf8.elementsEqual(rhs.quote.utf8)
  }
}

/// Models propose exact source text; they cannot manufacture a stored paraphrase.
public struct PersonalMemoryProposal: Equatable, Sendable {
  public let quote: String
  public let kind: PersonalMemoryKind
  public let subjectName: String?
  public let subjectKind: PersonalProfileKind?
  public let replacesEntryID: UUID?
  public let contextEvidence: [PersonalMemoryEvidence]
  public let isEpisode: Bool
  public let eventTimeExpression: String?

  public init(
    quote: String, kind: PersonalMemoryKind, subjectName: String? = nil,
    subjectKind: PersonalProfileKind? = nil, replacesEntryID: UUID? = nil,
    contextEvidence: [PersonalMemoryEvidence] = [], isEpisode: Bool = false,
    eventTimeExpression: String? = nil
  ) {
    self.quote = quote
    self.kind = kind
    self.subjectName = subjectName
    self.subjectKind = subjectKind
    self.replacesEntryID = replacesEntryID
    self.contextEvidence = contextEvidence
    self.isEpisode = isEpisode
    self.eventTimeExpression = eventTimeExpression
  }
}

public struct PersonalMemoryClarification: Equatable, Sendable {
  public let quote: String
  public let question: String
  public init(quote: String, question: String) {
    self.quote = quote
    self.question = question
  }
}

public struct PersonalMemoryAnalysis: Equatable, Sendable {
  public let memories: [PersonalMemoryProposal]
  public let clarification: PersonalMemoryClarification?
  /// Exact disputed spans, never alternative facts or invented questions.
  public let deferredQuotes: [String]
  public init(
    memories: [PersonalMemoryProposal] = [], clarification: PersonalMemoryClarification? = nil,
    deferredQuotes: [String] = []
  ) {
    self.memories = memories
    self.clarification = clarification
    self.deferredQuotes = deferredQuotes
  }
}

/// Every context item is an app-owned user source, never an assistant reply or private turn.
public struct PersonalMemoryAnalysisInput: Sendable {
  public let source: PersonalMemorySource
  public let context: [PersonalMemorySource]
  public let clarificationAnswer: PersonalMemorySource?
  public let profiles: [PersonalProfile]
  public let entries: [PersonalMemoryEntry]
  public let revision: UInt64

  public init(
    source: PersonalMemorySource, context: [PersonalMemorySource] = [],
    clarificationAnswer: PersonalMemorySource? = nil, profiles: [PersonalProfile] = [],
    entries: [PersonalMemoryEntry] = [], revision: UInt64
  ) {
    self.source = source
    self.context = context
    self.clarificationAnswer = clarificationAnswer
    self.profiles = profiles
    self.entries = entries
    self.revision = revision
  }
}

public protocol PersonalMemoryAnalyzing: Sendable {
  func analyze(_ input: PersonalMemoryAnalysisInput) async throws -> PersonalMemoryAnalysis
}
