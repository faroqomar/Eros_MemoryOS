import CryptoKit
import Foundation
import RetrievalCore
import Testing

@testable import CactusMemoryRuntime

struct VectorPreparationTests {
  private enum ProbeFailure: Error { case interrupted, checkpoint }
  private func key(_ text: String) -> Data { Data(SHA256.hash(data: Data(text.utf8))) }

  @Test func interruptedPreparationResumesFromProtectedCheckpoint()
    throws
  {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "memoryos-vector-checkpoint-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let pipeline = Data(repeating: 9, count: 32)
    let records = (0..<5).map { MemorySearchRecord(id: "id-\($0)", text: "Fictional source \($0)") }
    var embedded = 0
    #expect(throws: ProbeFailure.self) {
      _ = try CactusVectorPreparation.prepare(
        records: records, cached: [:], dimension: 2, checkpointInterval: 2,
        embed: { _ in
          embedded += 1
          if embedded == 4 { throw ProbeFailure.interrupted }
          return [1, Float(embedded)]
        },
        checkpoint: {
          try CactusDocumentVectorCache.save(
            $0, directory: directory, pipeline: pipeline, dimension: 2)
        })
    }
    let persisted = try CactusDocumentVectorCache.load(
      directory: directory, pipeline: pipeline, dimension: 2)
    #expect(Set(persisted.keys) == Set(records.prefix(2).map { key($0.text) }))
    var resumed = 0
    let result = try CactusVectorPreparation.prepare(
      records: records, cached: persisted, dimension: 2, checkpointInterval: 2,
      embed: { _ in
        resumed += 1
        return [0, Float(resumed)]
      }, checkpoint: { _ in })
    #expect(resumed == 3)
    #expect(result.ordered.count == records.count)
    #expect(result.ordered[0] == [1, 1])
    #expect(result.ordered[1] == [1, 2])
    #expect(result.cache.count == 5)
  }

  @Test func correctionAndDeletionPruneBeforeAnyNewEmbeddingCanFail() throws {
    let original = "Fictional older statement"
    let unchanged = "Fictional retained statement"
    let corrected = "Fictional corrected statement"
    var checkpoints: [[Data: [Float]]] = []
    #expect(throws: ProbeFailure.self) {
      _ = try CactusVectorPreparation.prepare(
        records: [.init(id: "same", text: corrected), .init(id: "kept", text: unchanged)],
        cached: [key(original): [1, 0], key(unchanged): [0, 1]], dimension: 2,
        embed: { _ in throw ProbeFailure.interrupted }, checkpoint: { checkpoints.append($0) })
    }
    #expect(checkpoints.count == 1)
    #expect(checkpoints[0] == [key(unchanged): [0, 1]])
  }

  @Test func repeatedTextUsesOneEmbeddingAndKeepsInputOrder() throws {
    var embedded = 0
    var checkpoints = 0
    let result = try CactusVectorPreparation.prepare(
      records: [
        .init(id: "a", text: "First"), .init(id: "b", text: "Second"),
        .init(id: "c", text: "First"),
      ], cached: [:], dimension: 2,
      embed: { _ in
        embedded += 1
        return [Float(embedded), 0]
      },
      checkpoint: { _ in checkpoints += 1 })
    #expect(embedded == 2)
    #expect(result.ordered == [[1, 0], [2, 0], [1, 0]])
    #expect(checkpoints == 1)
  }

  @Test func checkpointFailureAndInvalidVectorsCannotCompletePreparation() {
    #expect(throws: ProbeFailure.self) {
      _ = try CactusVectorPreparation.prepare(
        records: [.init(id: "a", text: "First")], cached: [:], dimension: 2,
        embed: { _ in [1, 0] }, checkpoint: { _ in throw ProbeFailure.checkpoint })
    }
    var checkpointed = false
    #expect(throws: RetrievalError.self) {
      _ = try CactusVectorPreparation.prepare(
        records: [.init(id: "a", text: "First")], cached: [:], dimension: 2,
        embed: { _ in [.nan, 0] }, checkpoint: { _ in checkpointed = true })
    }
    #expect(!checkpointed)
  }
}
