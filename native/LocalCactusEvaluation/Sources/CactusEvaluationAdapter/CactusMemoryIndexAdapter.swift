public import AIEvaluationCore
internal import CactusMemoryRuntime
public import Foundation
internal import RetrievalCore

/// Compatibility boundary for the isolated evaluation lab.
public actor CactusMemoryIndexAdapter: MemoryIndexAdapter {
  private let index: CactusRecallIndex
  public static var upstreamRevision: String { CactusRecallIndex.upstreamRevision }
  public static var modelRevision: String { CactusRecallIndex.modelRevision }
  public static var modelArchiveSHA256: String { CactusRecallIndex.modelArchiveSHA256 }
  public static var modelManifestSHA256: String { CactusRecallIndex.modelManifestSHA256 }
  public static var isLocalOnlyRuntime: Bool { CactusRecallIndex.isLocalOnlyRuntime }
  public static var isCPUBackendAvailable: Bool { CactusRecallIndex.isCPUBackendAvailable }
  public static var configuredWorkerCount: Int { CactusRecallIndex.configuredWorkerCount }
  public init(modelDirectory: URL, indexDirectory: URL, minimumSimilarity: Float = 0.35) {
    index = CactusRecallIndex(
      modelDirectory: modelDirectory, indexDirectory: indexDirectory,
      minimumSimilarity: minimumSimilarity)
  }
  public func rebuild(records: [SourceRecord]) async throws {
    do {
      try await index.rebuild(records: records.map { .init(id: $0.id, text: $0.text) })
    } catch let error as RetrievalError { throw translate(error) }
  }
  public func search(query: String, limit: Int) async throws -> [RetrievedSource] {
    do {
      return try await index.search(query: query, limit: limit).map {
        .init(sourceID: $0.sourceID, score: $0.score)
      }
    } catch let error as RetrievalError { throw translate(error) }
  }
  public func close() async { await index.close() }
  private func translate(_ error: RetrievalError) -> EvaluationError {
    switch error {
    case .invalidInput(let message): return .invalidSuite(message)
    case .invalidResult(let message): return .invalidResult(message)
    case .unavailable(let message): return .unavailable(message)
    case .busy: return .unavailable("The retrieval provider is busy.")
    }
  }
}
