import Foundation

public struct EvaluationProgress: Equatable, Sendable {
  public let completedCases: Int
  public let totalCases: Int
  public let currentCaseID: String

  public init(completedCases: Int, totalCases: Int, currentCaseID: String) {
    self.completedCases = completedCases
    self.totalCases = totalCases
    self.currentCaseID = currentCaseID
  }
}

/// A fictional, app-owned source. Adapters receive values and cannot mutate the canonical suite.
public struct SourceRecord: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let text: String
  public let language: String
  public let revision: Int

  public init(id: String, text: String, language: String, revision: Int = 1) {
    self.id = id
    self.text = text
    self.language = language
    self.revision = revision
  }
}

public struct EvaluationCase: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let language: String
  public let query: String
  /// Ground truth stays in the evaluator. It is never passed to an adapter.
  public let expectedSourceIDs: [String]
  public let reviewGuidance: String

  public init(
    id: String, language: String, query: String, expectedSourceIDs: [String],
    reviewGuidance: String
  ) {
    self.id = id
    self.language = language
    self.query = query
    self.expectedSourceIDs = expectedSourceIDs
    self.reviewGuidance = reviewGuidance
  }
}

public struct EvaluationSuite: Codable, Equatable, Sendable {
  public let id: String
  public let records: [SourceRecord]
  public let cases: [EvaluationCase]

  public init(id: String, records: [SourceRecord], cases: [EvaluationCase]) {
    self.id = id
    self.records = records
    self.cases = cases
  }
}

public struct RetrievedSource: Codable, Equatable, Sendable {
  public let sourceID: String
  public let score: Double?

  public init(sourceID: String, score: Double? = nil) {
    self.sourceID = sourceID
    self.score = score
  }
}

public protocol MemoryIndexAdapter: Sendable {
  /// Replace the derived index. The sources remain owned by the app.
  func rebuild(records: [SourceRecord]) async throws
  func search(query: String, limit: Int) async throws -> [RetrievedSource]
}

public struct GenerationSettings: Codable, Equatable, Sendable {
  public let maximumOutputTokens: Int
  public let temperature: Double
  public let seed: UInt64

  public init(maximumOutputTokens: Int = 256, temperature: Double = 0, seed: UInt64 = 42) {
    self.maximumOutputTokens = maximumOutputTokens
    self.temperature = temperature
    self.seed = seed
  }
}

public struct TextRequest: Codable, Equatable, Sendable {
  public let instruction: String
  public let question: String
  public let sources: [SourceRecord]

  public init(instruction: String, question: String, sources: [SourceRecord]) {
    self.instruction = instruction
    self.question = question
    self.sources = sources
  }
}

public struct TextOutput: Codable, Equatable, Sendable {
  public let text: String
  /// Use nil when the runtime does not expose its tokenizer. Words are not token counts.
  public let generatedTokenCount: Int?
  /// Measure from request start to the first emitted token. Do not derive from total duration.
  public let firstTokenSeconds: Double?
  public let preparationSeconds: Double?
  public let wasColdLoad: Bool?

  public init(
    text: String, generatedTokenCount: Int? = nil, firstTokenSeconds: Double? = nil,
    preparationSeconds: Double? = nil, wasColdLoad: Bool? = nil
  ) {
    self.text = text
    self.generatedTokenCount = generatedTokenCount
    self.firstTokenSeconds = firstTokenSeconds
    self.preparationSeconds = preparationSeconds
    self.wasColdLoad = wasColdLoad
  }
}

public protocol TextRuntimeAdapter: Sendable {
  func generate(request: TextRequest, settings: GenerationSettings) async throws -> TextOutput
}

public struct ComponentProvenance: Codable, Equatable, Sendable {
  public let sourceURL: String
  public let revision: String
  public let modelAsset: String?
  public let modelSHA256: String?
  public let notes: String

  public init(
    sourceURL: String, revision: String, modelAsset: String? = nil,
    modelSHA256: String? = nil, notes: String = ""
  ) {
    self.sourceURL = sourceURL
    self.revision = revision
    self.modelAsset = modelAsset
    self.modelSHA256 = modelSHA256
    self.notes = notes
  }
}

public struct CandidateConfiguration: Codable, Equatable, Sendable, Identifiable {
  public enum Scope: String, Codable, Sendable { case retrieval, text, combined }
  public let id: String
  public let displayName: String
  public let provenance: [ComponentProvenance]
  public let scope: Scope

  public init(
    id: String, displayName: String, provenance: [ComponentProvenance] = [],
    scope: Scope = .combined
  ) {
    self.id = id
    self.displayName = displayName
    self.provenance = provenance
    self.scope = scope
  }
  private enum CodingKeys: String, CodingKey { case id, displayName, provenance, scope }
  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    displayName = try values.decode(String.self, forKey: .displayName)
    provenance = try values.decodeIfPresent([ComponentProvenance].self, forKey: .provenance) ?? []
    scope = try values.decodeIfPresent(Scope.self, forKey: .scope) ?? .combined
  }
}

public enum EvaluationError: Error, Equatable, Sendable, LocalizedError {
  case unavailable(String)
  case invalidSuite(String)
  case invalidResult(String)

  public var errorDescription: String? {
    switch self {
    case .unavailable(let reason), .invalidSuite(let reason), .invalidResult(let reason): reason
    }
  }
}
