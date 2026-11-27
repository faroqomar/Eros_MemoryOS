import CactusMemoryRuntime
import Foundation
import LocalMemoryRetrieval
import RetrievalCore
import Testing

private actor PurgeIndex: RecallIndex {
  var records: [MemorySearchRecord] = []
  var closes = 0
  var failClose = false
  func rebuild(records: [MemorySearchRecord]) { self.records = records }
  func search(query: String, limit: Int) -> [MemorySearchHit] {
    records.filter { $0.text.contains(query) }.map { .init(sourceID: $0.id, score: 1) }
  }
  func fail() { failClose = true }
  func close() throws {
    closes += 1
    if failClose { throw RetrievalError.unavailable("Fixture close failure") }
    records = []
  }
}

struct RecallPurgeTests {
  @Test func purgeClosesEveryProviderAndRequiresCurrentSourcesToRebuild() async throws {
    let first = PurgeIndex()
    let second = PurgeIndex()
    let search = LocalMemorySearch(indexes: [first, second])
    _ = try await search.search(
      query: "Friday", records: [.init(id: "a", text: "Friday plan")], limit: 3)
    try await search.purge()
    #expect(await first.records.isEmpty)
    #expect(await second.records.isEmpty)
    #expect(await first.closes == 1)
    #expect(await second.closes == 1)
    let results = try await search.search(
      query: "Friday", records: [.init(id: "a", text: "Saturday plan")], limit: 3)
    #expect(results.isEmpty)
    #expect(await first.records.map(\.text) == ["Saturday plan"])
  }

  @Test func purgeReportsFailureAfterAttemptingAllProviders() async throws {
    let first = PurgeIndex()
    let second = PurgeIndex()
    await first.fail()
    let search = LocalMemorySearch(indexes: [first, second])
    await #expect(throws: RetrievalError.self) { try await search.purge() }
    #expect(await first.closes == 1)
    #expect(await second.closes == 1)
  }

  @Test func realWaxPurgeRemovesActiveAndStaleOwnedFilesAndPreservesUnrelatedFiles() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "memoryos-purge-proof-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let search = LocalMemorySearch(directory: directory, cactusModelDirectory: nil, provider: .wax)
    let old = [MemorySearchRecord(id: "old", text: "Fictional private Friday")]
    #expect(
      try await search.search(query: "Friday", records: old, limit: 3).map(\.sourceID) == ["old"])
    let stale = directory.appending(path: "cactus/memoryos-cactus-recall-stale")
    try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
    try Data("fictional derived payload".utf8).write(to: stale.appending(path: "derived.txt"))
    let persistedVectors = directory.appending(path: "cactus")
      .appending(path: CactusRecallIndex.documentVectorCacheFileName)
    try Data("fictional derived vectors".utf8).write(to: persistedVectors)
    let keep = directory.appending(path: "keep.txt")
    try Data("unrelated fixture".utf8).write(to: keep)
    try await search.purge()
    let files =
      (FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?.allObjects
        as? [URL]) ?? []
    #expect(
      !files.contains {
        $0.lastPathComponent.hasPrefix("memoryos-wax-recall-")
          || $0.lastPathComponent.hasPrefix("memoryos-cactus-recall-")
      })
    #expect(try Data(contentsOf: keep) == Data("unrelated fixture".utf8))
    #expect(!FileManager.default.fileExists(atPath: persistedVectors.path))
    #expect(
      try await search.search(
        query: "Friday", records: [.init(id: "new", text: "Saturday")], limit: 3
      ).isEmpty)
    try await search.close()
  }
}
