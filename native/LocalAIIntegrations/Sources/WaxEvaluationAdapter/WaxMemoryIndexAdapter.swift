public import AIEvaluationCore
public import Foundation
internal import Wax

/// Real Wax lexical retrieval for the isolated lab. Canonical records remain app-owned.
/// This adapter does not load embeddings, generate text or configure cloud services.
public actor WaxMemoryIndexAdapter: MemoryIndexAdapter {
  private let directory: URL
  private var memory: Memory?
  private var activeDirectory: URL?
  private var sourceIDs: Set<Data> = []
  private var isWorking = false

  public init(directory: URL) {
    self.directory = directory
  }

  public func rebuild(records: [SourceRecord]) async throws {
    try beginOperation()
    defer { isWorking = false }
    var ids: Set<Data> = []
    var groups: [(text: String, ids: [String])] = []
    var groupOffsets: [Data: Int] = [:]
    for record in records {
      guard !record.id.isEmpty,
        !record.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        ids.insert(Data(record.id.utf8)).inserted
      else {
        throw EvaluationError.invalidSuite("Wax requires nonempty sources and unique source IDs.")
      }
      // Wax deduplicates document text. Preserve all canonical IDs for identical bytes.
      let bytes = Data(record.text.utf8)
      if let offset = groupOffsets[bytes] {
        groups[offset].ids.append(record.id)
      } else {
        groupOffsets[bytes] = groups.count
        groups.append((record.text, [record.id]))
      }
    }

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let staging = directory.appendingPathComponent("memoryos-wax-evaluation-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
    var candidate: Memory?
    do {
      let opened = try await Memory(
        at: staging.appendingPathComponent("derived.wax"),
        config: .init(
          enableTextSearch: true,
          enableVectorSearch: false,
          enableStructuredMemory: false,
          enableAccessStatsScoring: false,
          enableAsyncEnrichment: false,
          requireOnDeviceProviders: true
        )
      )
      candidate = opened
      for group in groups {
        try Task.checkCancellation()
        let metadata = String(decoding: try JSONEncoder().encode(group.ids), as: UTF8.self)
        try await opened.save(group.text, metadata: ["memoryos_source_ids": metadata])
      }
      try await opened.flush()
      let health = await opened.stats()
      guard !health.vectorSearchEnabled, !health.queryEmbedderConfigured else {
        throw EvaluationError.invalidResult(
          "Wax lexical evaluation unexpectedly enabled embeddings.")
      }
      try Task.checkCancellation()
      // Publish the completed index only after all saves succeed.
      let previousDirectory = activeDirectory
      try await memory?.close()
      memory = opened
      activeDirectory = staging
      sourceIDs = ids
      candidate = nil
      if let previousDirectory {
        try FileManager.default.removeItem(at: previousDirectory)
      }
    } catch {
      if let candidate { try? await candidate.close() }
      if activeDirectory != staging { try? FileManager.default.removeItem(at: staging) }
      throw error
    }
  }

  public func search(query: String, limit: Int) async throws -> [RetrievedSource] {
    try beginOperation()
    defer { isWorking = false }
    guard limit > 0, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw EvaluationError.invalidSuite("Wax search requires a nonempty query and positive limit.")
    }
    guard let memory else {
      throw EvaluationError.unavailable("Rebuild the Wax lexical index before searching.")
    }
    try Task.checkCancellation()
    let context = try await memory.search(
      query,
      options: .init(topK: limit, mode: .textOnly)
    )
    guard context.diagnostics?.effectiveMode == .textOnly else {
      throw EvaluationError.invalidResult("Wax did not report explicit lexical retrieval.")
    }
    var output: [RetrievedSource] = []
    var returned: Set<Data> = []
    for item in context.items {
      guard let encoded = item.metadata["memoryos_source_ids"] else {
        throw EvaluationError.invalidResult("Wax returned a source without canonical ID metadata.")
      }
      let ids = try JSONDecoder().decode([String].self, from: Data(encoded.utf8))
      guard !ids.isEmpty else {
        throw EvaluationError.invalidResult("Wax returned an empty canonical ID mapping.")
      }
      for id in ids {
        let bytes = Data(id.utf8)
        guard sourceIDs.contains(bytes) else {
          throw EvaluationError.invalidResult("Wax returned an unknown canonical source ID.")
        }
        if returned.insert(bytes).inserted {
          output.append(.init(sourceID: id, score: Double(item.score)))
        }
        if output.count == limit { return output }
      }
    }
    return output
  }

  /// Close the file handle and remove only this instance's generated index directory.
  public func close() async throws {
    try beginOperation()
    defer { isWorking = false }
    try await memory?.close()
    memory = nil
    sourceIDs = []
    if let activeDirectory {
      try FileManager.default.removeItem(at: activeDirectory)
      self.activeDirectory = nil
    }
  }

  private func beginOperation() throws {
    guard !isWorking else {
      throw EvaluationError.unavailable("The Wax evaluation adapter is busy.")
    }
    isWorking = true
  }
}
