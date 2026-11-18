public import AIEvaluationCore
public import Foundation
internal import RetrievalCore
internal import WaxMemoryRuntime

/// Compatibility boundary for the isolated evaluation lab.
public actor WaxMemoryIndexAdapter: MemoryIndexAdapter {
  private let index: WaxRecallIndex

  public init(directory: URL) { index = WaxRecallIndex(directory: directory) }
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
  public func close() async throws { try await index.close() }
  private func translate(_ error: RetrievalError) -> EvaluationError {
    switch error {
    case .invalidInput(let message): return .invalidSuite(message)
    case .invalidResult(let message): return .invalidResult(message)
    case .unavailable(let message): return .unavailable(message)
    case .busy: return .unavailable("The retrieval provider is busy.")
    }
  }
}
