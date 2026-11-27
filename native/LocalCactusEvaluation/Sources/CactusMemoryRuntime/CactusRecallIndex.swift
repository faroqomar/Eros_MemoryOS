import CryptoKit
import Foundation
import RetrievalCore
import cactus

/// Thin local-only Cactus adapter. Cactus owns embeddings and vector ranking; MemoryOS owns IDs/sources.
public actor CactusRecallIndex: RecallIndex {
  public static let upstreamRevision = "40a7123b0788f5b38c5fe0daa0d909b4286fe773"
  public static let modelRevision = "0df64898a34c75c209b9882110cd6f9aeb7115cd"
  public static let modelArchiveSHA256 =
    "22ff768a984fe931ac463b02cedce2ebd65172c6877d210bd5dc6d058fffbd7b"

  public static let modelManifestSHA256 =
    "229ba9eb5d361209c7f01d34cac0db77a623a33bb845c2eb90050ccc831c60af"

  public static let documentVectorCacheFileName = CactusDocumentVectorCache.fileName
  // Bump this identity when tokenization, document preparation, pooling or normalization changes.
  private static let vectorPipeline = Data(
    SHA256.hash(
      data: Data(
        (upstreamRevision + modelManifestSHA256 + "qwen-nfc-byte-bpe-last-token-l2-v1").utf8)))
  private static let embeddingDimension = 1024

  // The reviewed local-only build forces CPU after reading the model configuration.
  public static var isLocalOnlyRuntime: Bool { cactus_memoryos_evaluation_is_local_only() }
  public static var isCPUBackendAvailable: Bool { cpuAvailable }
  public static var configuredWorkerCount: Int { Int(cactus_memoryos_evaluation_thread_count()) }

  private static let cpuAvailable: Bool = {
    guard cactus_memoryos_evaluation_is_local_only() else { return false }
    cactus_log_set_level(4)
    return true
  }()

  private let modelDirectory: URL
  private let indexDirectory: URL
  private let minimumSimilarity: Float
  private var model: ModelOwner?
  private var preprocessor: QwenEmbeddingPreprocessor?
  private var index: IndexOwner?
  private var activeDirectory: URL?
  private var sourceIDs: [Int32: String] = [:]
  private var dimension = 0
  private var hasSnapshot = false
  private var documentVectors: [Data: [Float]] = [:]
  private var loadedPersistentVectors = false
  private(set) var embeddedDocumentCount = 0
  var cachedDocumentCount: Int { documentVectors.count }

  public init(modelDirectory: URL, indexDirectory: URL, minimumSimilarity: Float = 0.35) {
    self.modelDirectory = modelDirectory
    self.indexDirectory = indexDirectory
    self.minimumSimilarity = minimumSimilarity
  }

  public func rebuild(records: [MemorySearchRecord]) async throws {
    try Task.checkCancellation()
    guard modelDirectory.isFileURL, indexDirectory.isFileURL else {
      throw RetrievalError.invalidInput(
        "Cactus model and index directories must be local file URLs.")
    }
    var uniqueIDs = Set<Data>()
    guard minimumSimilarity.isFinite, (-1...1).contains(minimumSimilarity),
      records.count < Int(Int32.max),
      records.allSatisfy({
        !$0.id.isEmpty && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && !$0.text.utf8.contains(0)
          && uniqueIDs.insert(Data($0.id.utf8)).inserted
      })
    else {
      throw RetrievalError.invalidInput(
        "Cactus requires unique, nonempty source IDs/text and a valid similarity threshold.")
    }
    if records.isEmpty {
      try CactusDocumentVectorCache.remove(directory: indexDirectory)
      index = nil
      sourceIDs = [:]
      dimension = 0
      hasSnapshot = true
      documentVectors = [:]
      loadedPersistentVectors = true
      removePreviousDirectory()
      return
    }
    // A failed changed rebuild must not leave a searchable old snapshot. Durable
    // vector checkpoints are reusable inputs, never a partially published index.
    hasSnapshot = false
    sourceIDs = [:]
    index = nil
    removePreviousDirectory()
    if !loadedPersistentVectors {
      // A persisted vector never bypasses verification of the actual pinned local model files.
      try verifyModelFiles()
      documentVectors = try CactusDocumentVectorCache.load(
        directory: indexDirectory, pipeline: Self.vectorPipeline, dimension: Self.embeddingDimension
      )
      loadedPersistentVectors = true
    }
    let preparation = try CactusVectorPreparation.prepare(
      records: records, cached: documentVectors, dimension: Self.embeddingDimension,
      embed: { text in
        let vector = try embed(text, model: loadModel())
        embeddedDocumentCount += 1
        return vector
      },
      checkpoint: { vectors in
        try CactusDocumentVectorCache.save(
          vectors, directory: indexDirectory, pipeline: Self.vectorPipeline,
          dimension: Self.embeddingDimension)
        documentVectors = vectors
      })
    let vectors = preparation.ordered
    guard let first = vectors.first, first.count == Self.embeddingDimension,
      vectors.allSatisfy({ $0.count == first.count })
    else {
      throw RetrievalError.invalidResult("Cactus returned inconsistent embedding dimensions.")
    }
    try RecallDirectory.prepare(indexDirectory)
    let staging = indexDirectory.appendingPathComponent(
      "memoryos-cactus-recall-" + UUID().uuidString)
    try RecallDirectory.prepare(staging)
    do {
      guard let handle = cactus_index_init(staging.path, first.count) else {
        throw RetrievalError.invalidResult("Cactus could not create a derived vector index.")
      }
      let candidate = IndexOwner(handle)
      var mappings: [Int32: String] = [:]
      for offset in records.indices {
        try Task.checkCancellation()
        let id = Int32(offset + 1)
        var numericID = id
        let status = records[offset].text.withCString { text in
          var textPointer: UnsafePointer<CChar>? = text
          return vectors[offset].withUnsafeBufferPointer { vector in
            var vectorPointer = vector.baseAddress
            return cactus_index_add(
              candidate.pointer, &numericID, &textPointer, nil, &vectorPointer, 1, first.count)
          }
        }
        guard status == 0 else {
          throw RetrievalError.invalidResult("Cactus could not add a source to the derived index.")
        }
        mappings[id] = records[offset].id
      }
      try Task.checkCancellation()
      let previous = activeDirectory
      index = candidate
      activeDirectory = staging
      sourceIDs = mappings
      dimension = first.count
      hasSnapshot = true
      documentVectors = preparation.cache
      if let previous { try? FileManager.default.removeItem(at: previous) }
    } catch {
      try? FileManager.default.removeItem(at: staging)
      throw error
    }
  }

  public func search(query: String, limit: Int) async throws -> [MemorySearchHit] {
    try Task.checkCancellation()
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !query.utf8.contains(0),
      (1...1000).contains(limit)
    else {
      throw RetrievalError.invalidInput(
        "Cactus search requires nonempty text and a limit from 1 to 1000.")
    }
    guard hasSnapshot else {
      throw RetrievalError.unavailable("Rebuild the Cactus index before searching.")
    }
    guard !sourceIDs.isEmpty else { return [] }
    guard let index else {
      throw RetrievalError.invalidResult("The Cactus index is unavailable.")
    }
    let model = try loadModel()
    // Official Qwen3 Embedding query instruction. Documents remain their exact source text.
    let vector = try embed(
      "Instruct: Given a question, retrieve relevant passages that answer the question\nQuery: "
        + query, model: model)
    guard vector.count == dimension else {
      throw RetrievalError.invalidResult("Cactus query/index dimensions differ.")
    }
    let capacity = min(limit, sourceIDs.count)
    var ids = [Int32](repeating: 0, count: capacity)
    var scores = [Float](repeating: 0, count: capacity)
    var resultCount = capacity
    var scoreCount = capacity
    let options = "{\"top_k\":\(capacity),\"score_threshold\":\(minimumSimilarity)}"
    let status = vector.withUnsafeBufferPointer { vectorBuffer in
      var vectorPointer = vectorBuffer.baseAddress
      return ids.withUnsafeMutableBufferPointer { idBuffer in
        var idPointer = idBuffer.baseAddress
        return scores.withUnsafeMutableBufferPointer { scoreBuffer in
          var scorePointer = scoreBuffer.baseAddress
          return cactus_index_query(
            index.pointer, &vectorPointer, 1, dimension, options,
            &idPointer, &resultCount, &scorePointer, &scoreCount)
        }
      }
    }
    guard status == 0, resultCount >= 0, resultCount <= capacity, resultCount == scoreCount else {
      throw RetrievalError.invalidResult("Cactus returned an invalid vector search result.")
    }
    var seen = Set<Int32>()
    return try (0..<resultCount).map { offset in
      guard let sourceID = sourceIDs[ids[offset]], scores[offset].isFinite,
        seen.insert(ids[offset]).inserted
      else {
        throw RetrievalError.invalidResult(
          "Cactus returned an unknown or duplicate source ID or invalid score.")
      }
      return MemorySearchHit(sourceID: sourceID, score: Double(scores[offset]))
    }
  }

  public func unloadModel() { model = nil }

  public func close() {
    index = nil
    model = nil
    sourceIDs = [:]
    hasSnapshot = false
    documentVectors = [:]
    loadedPersistentVectors = false
    removePreviousDirectory()
  }

  private func removePreviousDirectory() {
    if let activeDirectory { try? FileManager.default.removeItem(at: activeDirectory) }
    activeDirectory = nil
  }

  private func loadModel() throws -> ModelOwner {
    if let model { return model }
    try verifyModelFiles()
    if preprocessor == nil {
      preprocessor = try QwenEmbeddingPreprocessor(
        tokenizerData: Data(contentsOf: modelDirectory.appendingPathComponent("tokenizer.json")))
    }
    // This build excludes the upstream telemetry implementation and curl transport.
    // Choosing CPU also keeps execution supported by the iOS simulator.
    guard Self.cpuAvailable else {
      throw RetrievalError.unavailable("Cactus CPU backend is unavailable.")
    }
    guard let pointer = cactus_init(modelDirectory.path, nil, false) else {
      throw RetrievalError.unavailable("Cactus could not load the reviewed local embedding model.")
    }
    let loaded = ModelOwner(pointer)
    model = loaded
    return loaded
  }

  private func embed(_ text: String, model: ModelOwner) throws -> [Float] {
    try Task.checkCancellation()
    var values = [Float](repeating: 0, count: 8192)
    var count = 0
    guard let preprocessor else {
      throw RetrievalError.unavailable("The model tokenizer has not been verified.")
    }
    let tokens = try preprocessor.tokenIDs(for: text) { piece in
      try Task.checkCancellation()
      var values = [UInt32](repeating: 0, count: piece.utf8.count + 1)
      var count = 0
      let status = cactus_tokenize(model.pointer, piece, &values, values.count, &count)
      guard status == 0, count > 0, count <= values.count else {
        throw RetrievalError.invalidResult("Cactus could not tokenize an embedding input.")
      }
      return Array(values.prefix(count))
    }
    let result = cactus_memoryos_evaluation_embed_tokens_last_token(
      model.pointer, tokens, tokens.count, &values,
      values.count * MemoryLayout<Float>.stride, &count, true)
    try Task.checkCancellation()
    guard result > 0, Int(result) == count, count <= values.count,
      values.prefix(count).allSatisfy(\.isFinite)
    else { throw RetrievalError.invalidResult("Cactus did not produce a valid local embedding.") }
    return Array(values.prefix(count))
  }

  private struct AssetManifest: Decodable {
    let repository: String
    let revision: String
    let archiveSHA256: String
    let files: [String: String]
  }

  private func verifyModelFiles() throws {
    let manifestURL = modelDirectory.appendingPathComponent(".memoryos-asset-manifest.json")
    guard let data = try? Data(contentsOf: manifestURL) else {
      throw RetrievalError.unavailable("The verified Cactus embedding asset manifest is missing.")
    }
    let manifestDigest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard manifestDigest == Self.modelManifestSHA256 else {
      throw RetrievalError.unavailable(
        "The Cactus model manifest SHA-256 differs from the reviewed asset.")
    }
    guard let manifest = try? JSONDecoder().decode(AssetManifest.self, from: data),
      manifest.repository == "Cactus-Compute/Qwen3-Embedding-0.6B",
      manifest.revision == Self.modelRevision,
      manifest.archiveSHA256 == Self.modelArchiveSHA256,
      !manifest.files.isEmpty
    else {
      throw RetrievalError.unavailable(
        "The verified Cactus embedding asset is missing. Run the explicit asset preparation step; no download or cloud fallback is enabled."
      )
    }
    let root = modelDirectory.resolvingSymlinksInPath().standardizedFileURL.path + "/"
    for (relative, expected) in manifest.files {
      try Task.checkCancellation()
      let url = modelDirectory.appendingPathComponent(relative).resolvingSymlinksInPath()
        .standardizedFileURL
      guard url.path.hasPrefix(root), expected.count == 64,
        let stream = InputStream(url: url)
      else { throw RetrievalError.unavailable("Invalid Cactus model file manifest.") }
      stream.open()
      defer { stream.close() }
      var hasher = SHA256()
      var buffer = [UInt8](repeating: 0, count: 65536)
      while true {
        try Task.checkCancellation()
        let count = stream.read(&buffer, maxLength: buffer.count)
        guard count >= 0 else {
          throw RetrievalError.unavailable("A Cactus model file cannot be read.")
        }
        if count == 0 { break }
        hasher.update(data: Data(buffer.prefix(count)))
      }
      let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
      guard actual == expected else {
        throw RetrievalError.unavailable(
          "A Cactus model file SHA-256 differs from the verified asset.")
      }
    }
  }
}

// These non-Sendable owners stay inside the adapter actor. Each handle has one owner;
// Swift releases it only after the actor stops using it, so destruction cannot race a call.
private final class ModelOwner {
  let pointer: UnsafeMutableRawPointer
  init(_ pointer: UnsafeMutableRawPointer) { self.pointer = pointer }
  deinit { cactus_destroy(pointer) }
}

private final class IndexOwner {
  let pointer: UnsafeMutableRawPointer
  init(_ pointer: UnsafeMutableRawPointer) { self.pointer = pointer }
  deinit { cactus_index_destroy(pointer) }
}
