import Foundation

public struct RunContext: Codable, Equatable, Sendable {
  public enum Environment: String, Codable, Sendable { case host, simulator, physical }
  public enum Purpose: String, Codable, Sendable { case smoke, comparison }

  public let environment: Environment
  public let purpose: Purpose
  public let deviceModel: String
  public let operatingSystem: String
  public let sourceIdentity: String
  public let buildConfiguration: String
  public let toolchain: String
  public let offlineConfirmed: Bool
  public let conditions: String
  public let batchID: String?
  public let repetition: Int?
  public let repetitionCount: Int?

  public init(
    environment: Environment, purpose: Purpose, deviceModel: String, operatingSystem: String,
    sourceIdentity: String, buildConfiguration: String, toolchain: String,
    offlineConfirmed: Bool = false, conditions: String = "", batchID: String? = nil,
    repetition: Int? = nil, repetitionCount: Int? = nil
  ) {
    self.environment = environment
    self.purpose = purpose
    self.deviceModel = deviceModel
    self.operatingSystem = operatingSystem
    self.sourceIdentity = sourceIdentity
    self.buildConfiguration = buildConfiguration
    self.toolchain = toolchain
    self.offlineConfirmed = offlineConfirmed
    self.conditions = conditions
    self.batchID = batchID
    self.repetition = repetition
    self.repetitionCount = repetitionCount
  }
}

/// Measurement values have a method and remain absent until a collector provides them.
public struct RunTelemetry: Codable, Equatable, Sendable {
  public let peakMemoryBytes: UInt64?
  public let storageBytes: UInt64?
  public let batteryDropPercentagePoints: Double?
  public let highestThermalState: String?
  public let measurementMethod: String?

  public init(
    peakMemoryBytes: UInt64? = nil, storageBytes: UInt64? = nil,
    batteryDropPercentagePoints: Double? = nil, highestThermalState: String? = nil,
    measurementMethod: String? = nil
  ) {
    self.peakMemoryBytes = peakMemoryBytes
    self.storageBytes = storageBytes
    self.batteryDropPercentagePoints = batteryDropPercentagePoints
    self.highestThermalState = highestThermalState
    self.measurementMethod = measurementMethod
  }
}

public enum MeasurementStatus: String, Codable, Sendable {
  case completed, blocked, failed, notApplicable
}

public struct CaseResult: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let language: String
  public let retrievalStatus: MeasurementStatus
  public let generationStatus: MeasurementStatus
  public let retrievedSourceIDs: [String]
  /// Provider-native scores, keyed by source ID. Scales are not comparable across providers.
  public let retrievedScores: [String: Double]?
  /// Fraction of expected sources found in the retrieved set. nil for unavailable retrieval.
  public let sourceRecall: Double?
  /// An empty ground truth expects no evidence. It does not prove a generated answer abstains.
  public let exactSourceSetMatch: Bool?
  public let searchSeconds: Double?
  public let generationSeconds: Double?
  public let output: TextOutput?
  public let retrievalIssue: String?
  public let generationIssue: String?
}

public struct ManualQualityReview: Codable, Equatable, Sendable {
  public enum Verdict: String, Codable, Sendable { case pass, fail }
  public let caseID: String
  public let verdict: Verdict
  public let reviewer: String
  public let notes: String

  public init(caseID: String, verdict: Verdict, reviewer: String, notes: String) {
    self.caseID = caseID
    self.verdict = verdict
    self.reviewer = reviewer
    self.notes = notes
  }
}

public struct EvaluationReport: Codable, Equatable, Sendable {
  public let formatVersion: Int
  public let suiteID: String
  public let configuration: CandidateConfiguration
  public let context: RunContext
  public let generatedAt: Date
  public let settings: GenerationSettings
  public let telemetry: RunTelemetry
  public let results: [CaseResult]
  public let manualReviews: [ManualQualityReview]
  public let indexBuildSeconds: Double?

  public init(
    suiteID: String, configuration: CandidateConfiguration, context: RunContext,
    generatedAt: Date = Date(), settings: GenerationSettings = .init(),
    telemetry: RunTelemetry = .init(), results: [CaseResult],
    manualReviews: [ManualQualityReview] = [], indexBuildSeconds: Double? = nil
  ) {
    self.formatVersion = 2
    self.suiteID = suiteID
    self.configuration = configuration
    self.context = context
    self.generatedAt = generatedAt
    self.settings = settings
    self.telemetry = telemetry
    self.results = results
    self.manualReviews = manualReviews
    self.indexBuildSeconds = indexBuildSeconds
  }

  /// Advisory evidence gaps only. An empty list does not mean a component passed acceptance.
  /// Selection still needs repeated comparisons and owner-reviewed numeric acceptance targets.
  public var selectionBlockers: [String] {
    var blockers: [String] = []
    if context.environment != .physical {
      blockers.append("Physical-phone measurements are missing.")
    }
    if context.purpose != .comparison { blockers.append("This is a smoke run, not a comparison.") }
    if context.deviceModel != "iPhone 15 Pro Max" {
      blockers.append("The target iPhone 15 Pro Max has not been measured.")
    }
    if context.buildConfiguration != "Release" { blockers.append("A Release run is required.") }
    if !context.offlineConfirmed { blockers.append("Offline operation has not been confirmed.") }
    if context.sourceIdentity.isEmpty || context.sourceIdentity == "unrecorded"
      || context.toolchain.isEmpty || context.operatingSystem.isEmpty
    {
      blockers.append("Source and toolchain identity are required.")
    }
    if configuration.provenance.isEmpty
      || configuration.provenance.contains(where: { $0.revision.isEmpty || $0.sourceURL.isEmpty })
    {
      blockers.append("Reviewed component provenance is missing.")
    }
    if (configuration.scope != .retrieval
      || configuration.provenance.contains(where: { $0.modelAsset != nil }))
      && !configuration.provenance.contains(where: {
        guard let asset = $0.modelAsset, let hash = $0.modelSHA256 else { return false }
        return !asset.isEmpty && hash.count == 64 && hash.allSatisfy(\.isHexDigit)
      })
    {
      blockers.append("The model asset and its SHA-256 are missing.")
    }
    if telemetry.peakMemoryBytes == nil || telemetry.storageBytes == nil
      || telemetry.batteryDropPercentagePoints == nil || telemetry.highestThermalState == nil
      || telemetry.measurementMethod?.isEmpty != false
    {
      blockers.append("Memory, storage, battery, heat and measurement methods are required.")
    }
    if telemetry.peakMemoryBytes == 0
      || (telemetry.storageBytes == 0 && configuration.scope != .retrieval)
      || telemetry.batteryDropPercentagePoints.map({ !$0.isFinite || $0 < 0 || $0 > 100 }) == true
      || telemetry.highestThermalState.map({
        !["nominal", "fair", "serious", "critical"].contains($0)
      }) == true
    {
      blockers.append("Some supplied telemetry values are invalid.")
    }
    if results.isEmpty
      || results.contains(where: {
        (configuration.scope != .text
          && ($0.retrievalStatus != .completed || $0.searchSeconds == nil))
          || (configuration.scope != .retrieval
            && ($0.generationStatus != .completed || $0.generationSeconds == nil
              || $0.output == nil))
      })
    {
      blockers.append("Some retrieval or generation cases have no successful measurements.")
    }
    let reviewed = Dictionary(grouping: manualReviews, by: \.caseID)
    if configuration.scope != .retrieval
      && results.contains(where: { result in
        guard let reviews = reviewed[result.id], reviews.count == 1, let review = reviews.first
        else {
          return true
        }
        return review.verdict != .pass || review.reviewer.isEmpty || review.notes.isEmpty
      })
    {
      blockers.append("Each generated answer needs one passing human language/source review.")
    }
    return blockers
  }

  public func jsonData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(self)
  }

  public static func decode(_ data: Data) throws -> EvaluationReport {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(EvaluationReport.self, from: data)
    guard (1...2).contains(report.formatVersion) else {
      throw EvaluationError.invalidResult("Unsupported evaluation report version.")
    }
    return report
  }
}
