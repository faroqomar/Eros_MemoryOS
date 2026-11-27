import CryptoKit
import Foundation
import RetrievalCore
import Testing

@testable import CactusMemoryRuntime

@Suite(.serialized)
struct PersistentEmbeddingCacheTests {
  private let pipeline = Data(repeating: 7, count: 32)
  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(
      path: "memoryos-vector-cache-" + UUID().uuidString)
  }

  @Test func cacheRoundTripsExactFloatBitsAndRejectsChangedPipeline() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let key = Data(SHA256.hash(data: Data("Fictional Arabic إجازة".utf8)))
    let vector: [Float] = [0.25, -0.5, 0.75]
    try CactusDocumentVectorCache.save(
      [key: vector], directory: directory, pipeline: pipeline, dimension: 3)
    let restored = try CactusDocumentVectorCache.load(
      directory: directory, pipeline: pipeline, dimension: 3)
    #expect(restored[key]?.map(\.bitPattern) == vector.map(\.bitPattern))
    #expect(
      try CactusDocumentVectorCache.load(
        directory: directory, pipeline: Data(repeating: 8, count: 32), dimension: 3
      ).isEmpty)
    #expect(
      !FileManager.default.fileExists(
        atPath: directory.appending(path: CactusDocumentVectorCache.fileName).path))
  }

  @Test func corruptOrTruncatedCacheIsDiscardedWithoutSourceReads() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let key = Data(repeating: 1, count: 32)
    let url = directory.appending(path: CactusDocumentVectorCache.fileName)
    for corruption in [0, 1] {
      try CactusDocumentVectorCache.save(
        [key: [1, 0]], directory: directory, pipeline: pipeline, dimension: 2)
      var bytes = try Data(contentsOf: url)
      if corruption == 0 { bytes[80] ^= 1 } else { bytes.removeLast() }
      try bytes.write(to: url)
      #expect(
        try CactusDocumentVectorCache.load(directory: directory, pipeline: pipeline, dimension: 2)
          .isEmpty)
      #expect(!FileManager.default.fileExists(atPath: url.path))
    }
  }

  @Test func oversizedCacheAndChangedDimensionsAreDiscarded() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let key = Data(repeating: 1, count: 32)
    let url = directory.appending(path: CactusDocumentVectorCache.fileName)
    try CactusDocumentVectorCache.save(
      [key: [1, 0]], directory: directory, pipeline: pipeline, dimension: 2)
    #expect(
      try CactusDocumentVectorCache.load(directory: directory, pipeline: pipeline, dimension: 3)
        .isEmpty)
    try Data().write(to: url)
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: UInt64(CactusDocumentVectorCache.maximumVectorBytes + 81))
    try handle.close()
    #expect(
      try CactusDocumentVectorCache.load(directory: directory, pipeline: pipeline, dimension: 2)
        .isEmpty)
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }

  @Test func rejectsNonfiniteVectorsAndKeepsIndependentDirectoriesIsolated() throws {
    let first = temporaryDirectory()
    let second = temporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: first)
      try? FileManager.default.removeItem(at: second)
    }
    let key = Data(repeating: 1, count: 32)
    #expect(throws: RetrievalError.self) {
      try CactusDocumentVectorCache.save(
        [key: [.nan, 0]], directory: first, pipeline: pipeline, dimension: 2)
    }
    try CactusDocumentVectorCache.save(
      [key: [1, 0]], directory: first, pipeline: pipeline, dimension: 2)
    #expect(
      try CactusDocumentVectorCache.load(directory: second, pipeline: pipeline, dimension: 2)
        .isEmpty)
    #expect(
      try CactusDocumentVectorCache.load(directory: first, pipeline: pipeline, dimension: 2)[key]
        == [1, 0])
  }

  @Test func replacingSnapshotPrunesOldHashesAndEmptySnapshotRemovesFile() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let first = Data(repeating: 1, count: 32)
    let second = Data(repeating: 2, count: 32)
    try CactusDocumentVectorCache.save(
      [first: [1, 0], second: [0, 1]], directory: directory, pipeline: pipeline, dimension: 2)
    try CactusDocumentVectorCache.save(
      [second: [0, 1]], directory: directory, pipeline: pipeline, dimension: 2)
    let restored = try CactusDocumentVectorCache.load(
      directory: directory, pipeline: pipeline, dimension: 2)
    #expect(Set(restored.keys) == [second])
    try CactusDocumentVectorCache.save([:], directory: directory, pipeline: pipeline, dimension: 2)
    #expect(
      !FileManager.default.fileExists(
        atPath: directory.appending(path: CactusDocumentVectorCache.fileName).path))
  }

  @Test func cancelledSavePreservesPreviousCompleteSnapshot() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let key = Data(repeating: 1, count: 32)
    try CactusDocumentVectorCache.save(
      [key: [1, 0]], directory: directory, pipeline: pipeline, dimension: 2)
    let pipeline = pipeline
    let task = Task {
      while !Task.isCancelled { await Task.yield() }
      try CactusDocumentVectorCache.save(
        [key: [0, 1]], directory: directory, pipeline: pipeline, dimension: 2)
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(
      try CactusDocumentVectorCache.load(directory: directory, pipeline: pipeline, dimension: 2)[
        key] == [1, 0])
  }

  @Test func symlinkCacheCannotReadOrModifyUnrelatedTarget() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let target = directory.appending(path: "unrelated.bin")
    let bytes = Data(repeating: 5, count: 100)
    try bytes.write(to: target)
    let url = directory.appending(path: CactusDocumentVectorCache.fileName)
    try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
    #expect(
      try CactusDocumentVectorCache.load(directory: directory, pipeline: pipeline, dimension: 2)
        .isEmpty)
    #expect(try Data(contentsOf: target) == bytes)
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
  func reopeningReusesOnlyUnchangedDocumentVectors() async throws {
    let model = URL(
      fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"]))
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "memoryos-vector-reopen-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let records: [MemorySearchRecord] = [
      .init(id: "one", text: "Maya cycles to work."),
      .init(id: "two", text: "Omar prefers tea."),
    ]
    let first = CactusRecallIndex(modelDirectory: model, indexDirectory: directory)
    let clock = ContinuousClock()
    let coldStart = clock.now
    try await first.rebuild(records: records)
    let cold = coldStart.duration(to: clock.now)
    #expect(await first.embeddedDocumentCount == 2)
    await first.close()
    let second = CactusRecallIndex(modelDirectory: model, indexDirectory: directory)
    let reopenStart = clock.now
    try await second.rebuild(records: records.reversed())
    let reopened = reopenStart.duration(to: clock.now)
    #expect(await second.embeddedDocumentCount == 0)
    #expect(await second.cachedDocumentCount == 2)
    let privateQuery = "PRIVATE_QUERY_TRANSPORT_5A87160D"
    _ = try await second.search(query: privateQuery, limit: 2)
    let persisted = try Data(
      contentsOf: directory.appending(path: CactusRecallIndex.documentVectorCacheFileName))
    #expect(persisted.range(of: Data(privateQuery.utf8)) == nil)
    #expect(persisted.range(of: Data(records[0].text.utf8)) == nil)
    try await second.rebuild(records: [records[0], .init(id: "two", text: "Omar prefers coffee.")])
    #expect(await second.embeddedDocumentCount == 1)
    #expect(await second.cachedDocumentCount == 2)
    try await second.rebuild(records: [records[0]])
    #expect(await second.embeddedDocumentCount == 1)
    #expect(await second.cachedDocumentCount == 1)
    await second.close()
    let third = CactusRecallIndex(modelDirectory: model, indexDirectory: directory)
    try await third.rebuild(records: [records[0]])
    #expect(await third.embeddedDocumentCount == 0)
    #expect(await third.cachedDocumentCount == 1)
    try await third.rebuild(records: [])
    #expect(
      !FileManager.default.fileExists(
        atPath: directory.appending(path: CactusRecallIndex.documentVectorCacheFileName).path))
    await third.close()
    print(
      "RECALL_PERSISTENCE_METRIC cold2=\(cold) reopen2=\(reopened) reopened_documents_embedded=0 corrected_documents_embedded=1"
    )
  }
  @Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
  func cancelledRealPreparationRetainsCheckpointAndReopenEmbedsOnlyRemainder() async throws {
    let model = URL(
      fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"]))
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let count = 64
    let records = (0..<count).map { offset in
      MemorySearchRecord(
        id: "checkpoint-\(offset)",
        text: "Fictional record \(offset). "
          + String(
            repeating: "A local project keeps its original dated sources and revised plans. ",
            count: 8))
    }
    let originals = records.map { Data($0.text.utf8) }
    let first = CactusRecallIndex(modelDirectory: model, indexDirectory: directory)
    let cacheURL = directory.appending(path: CactusRecallIndex.documentVectorCacheFileName)
    let task = Task { try await first.rebuild(records: records) }
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(60))
    while !FileManager.default.fileExists(atPath: cacheURL.path), clock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    let data = try Data(contentsOf: cacheURL)
    let checkpointed = data.withUnsafeBytes {
      Int(UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 44, as: UInt32.self)))
    }
    #expect(checkpointed == CactusVectorPreparation.checkpointInterval)
    await #expect(throws: RetrievalError.self) {
      _ = try await first.search(query: "project", limit: 1)
    }
    await first.close()
    let resumed = CactusRecallIndex(modelDirectory: model, indexDirectory: directory)
    try await resumed.rebuild(records: records)
    #expect(await resumed.embeddedDocumentCount == count - checkpointed)
    #expect(await resumed.cachedDocumentCount == count)
    #expect(records.map { Data($0.text.utf8) } == originals)
    await resumed.close()
    print(
      "RECALL_CHECKPOINT_METRIC saved=\(checkpointed) resumed_embeddings=\(count - checkpointed) total=\(count)"
    )
  }

}
