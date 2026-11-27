import CactusMemoryRuntime
import Darwin
import Foundation
import RetrievalCore
import WaxMemoryRuntime

public enum LocalRecallProvider: String, CaseIterable, Sendable { case wax, cactus, hybrid }

/// Disposable indexes contain only supplied durable sources, never query text or private chat.
/// Callers must revalidate returned IDs against their current canonical snapshot after awaiting.
public actor LocalMemorySearch: MemorySearching {
  private let indexes: [any RecallIndex]
  private let directory: URL?
  private var lockDescriptor: Int32 = -1
  private let embedding: CactusRecallIndex?
  private let requiresModel: Bool
  private var snapshot: [(id: Data, text: Data)]?
  private var mappings: [String: String] = [:]
  private var passages: [String: String] = [:]
  private var working = false
  private var purgeWaiters: [CheckedContinuation<Void, Never>] = []

  public init(
    directory: URL, cactusModelDirectory: URL?, provider: LocalRecallProvider = .hybrid,
    minimumSimilarity: Float = 0.65
  ) {
    self.directory = directory
    let cactus = cactusModelDirectory.map {
      CactusRecallIndex(
        modelDirectory: $0,
        indexDirectory: directory.appendingPathComponent("cactus"),
        minimumSimilarity: minimumSimilarity)
    }
    embedding = provider == .wax ? nil : cactus
    requiresModel = provider != .wax && cactus == nil
    switch provider {
    case .wax: indexes = [WaxRecallIndex(directory: directory.appendingPathComponent("wax"))]
    case .cactus: indexes = cactus.map { [$0] } ?? []
    case .hybrid:
      indexes =
        [WaxRecallIndex(directory: directory.appendingPathComponent("wax"))]
        + (cactus.map { [$0] } ?? [])
    }
  }

  /// Injection seam for contract tests and future reviewed providers.
  public init(indexes: [any RecallIndex]) {
    self.indexes = indexes
    embedding = nil
    requiresModel = false
    directory = nil
  }

  public func search(query: String, records: [MemorySearchRecord], limit: Int) async throws
    -> [MemorySearchHit]
  {
    guard !working else { throw RetrievalError.busy }
    working = true
    defer { finishOperation() }
    try Task.checkCancellation()
    guard !requiresModel else {
      throw RetrievalError.unavailable("The local Cactus embedding model is missing.")
    }
    guard !indexes.isEmpty, (1...20).contains(limit), query.utf8.count <= 4096,
      records.count <= 30000
    else {
      throw RetrievalError.invalidInput("Recall requires a configured provider and bounded input.")
    }
    let query = query.replacingOccurrences(of: "\0", with: " ")
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
    try prepareOwnedDirectory()
    var ids = Set<Data>()
    let identity = try records.map { record -> (id: Data, text: Data) in
      let id = Data(record.id.utf8)
      guard !record.id.isEmpty, record.id.utf8.count <= 512, ids.insert(id).inserted,
        !record.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        record.text.utf8.count <= 101000
      else {
        throw RetrievalError.invalidInput(
          "Recall requires unique IDs and nonempty bounded source text.")
      }
      return (id, Data(record.text.utf8))
    }
    let unchanged =
      snapshot.map { prior in
        prior.count == identity.count
          && zip(prior, identity).allSatisfy { $0.id == $1.id && $0.text == $1.text }
      } ?? false
    do {
      if !unchanged {
        // Split by Unicode scalar, retaining byte-exact text. No model summary becomes evidence.
        var chunks: [MemorySearchRecord] = []
        var nextMappings: [String: String] = [:]
        for record in records {
          var text = ""
          var bytes = 0
          func append() {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
              text = ""
              bytes = 0
              return
            }
            let chunkID = "chunk-\(chunks.count)"
            chunks.append(.init(id: chunkID, text: text))
            nextMappings[chunkID] = record.id
            text = ""
            bytes = 0
          }
          for scalar in record.text.unicodeScalars {
            if scalar.value == 0 {
              append()
              continue
            }
            let count = scalar.utf8.count
            if bytes + count > 1200 { append() }
            text.unicodeScalars.append(scalar)
            bytes += count
          }
          append()
        }
        // At most 30,000 canonical records, each at most 101,000 bytes.
        // No source is silently dropped to meet an arbitrary provider chunk count.
        // A partial provider rebuild must never authorize a mixed old/new snapshot.
        snapshot = nil
        mappings = [:]
        passages = [:]
        for index in indexes { try await index.rebuild(records: chunks) }
        mappings = nextMappings
        passages = Dictionary(uniqueKeysWithValues: chunks.map { ($0.id, $0.text) })
        snapshot = identity
      }
      var scores: [Data: Double] = [:]
      var matched: [Data: String] = [:]
      var canonicalIDs: [Data: String] = [:]
      for index in indexes {
        try Task.checkCancellation()
        let hits = try await index.search(query: query, limit: min(100, max(12, limit * 4)))
        var seen = Set<Data>()
        for (rank, hit) in hits.enumerated() {
          guard hit.score.isFinite, let id = mappings[hit.sourceID] else {
            throw RetrievalError.invalidResult(
              "The provider returned an unknown source or invalid score.")
          }
          // Reciprocal rank fusion combines providers without comparing incomparable score scales.
          let key = Data(id.utf8)
          canonicalIDs[key] = id
          if seen.insert(key).inserted {
            scores[key, default: 0] += 1.0 / Double(60 + rank + 1)
            if matched[key] == nil { matched[key] = passages[hit.sourceID] }
          }
        }
      }
      try Task.checkCancellation()
      await embedding?.unloadModel()
      return scores.map {
        MemorySearchHit(
          sourceID: canonicalIDs[$0.key]!, score: $0.value, matchedText: matched[$0.key])
      }
      .sorted {
        $0.score == $1.score
          ? $0.sourceID.utf8.lexicographicallyPrecedes($1.sourceID.utf8) : $0.score > $1.score
      }.prefix(limit).map { $0 }
    } catch {
      await embedding?.unloadModel()
      throw error
    }
  }

  public func close() async throws {
    guard !working else { throw RetrievalError.busy }
    working = true
    defer { finishOperation() }
    snapshot = nil
    mappings = [:]
    passages = [:]
    var firstError: (any Error)?
    for index in indexes {
      do { try await index.close() } catch { if firstError == nil { firstError = error } }
    }
    // Keep exclusive ownership if a provider might still hold an open index.
    if let firstError { throw firstError }
    releaseDirectory()
  }

  /// Await active ranking before removing every owned derived file. Canonical stores stay outside this namespace.
  public func purge() async throws {
    while working {
      await withCheckedContinuation { purgeWaiters.append($0) }
    }
    working = true
    defer { finishOperation() }
    try prepareOwnedDirectory()
    snapshot = nil
    mappings = [:]
    passages = [:]
    var firstError: (any Error)?
    for index in indexes {
      do { try await index.close() } catch { if firstError == nil { firstError = error } }
    }
    guard firstError == nil else { throw firstError! }
    if let directory {
      // Cactus close may leave a failed-removal directory. Verify removal ourselves under the process lock.
      for (name, prefix) in [
        ("wax", "memoryos-wax-recall-"), ("cactus", "memoryos-cactus-recall-"),
      ] {
        let owned = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: owned.path) else { continue }
        for child in try FileManager.default.contentsOfDirectory(
          at: owned, includingPropertiesForKeys: nil)
        where child.lastPathComponent.hasPrefix(prefix)
          || (name == "cactus"
            && child.lastPathComponent == CactusRecallIndex.documentVectorCacheFileName)
        {
          try FileManager.default.removeItem(at: child)
        }
      }
    }
  }

  private func finishOperation() {
    working = false
    let pending = purgeWaiters
    purgeWaiters.removeAll()
    for waiter in pending { waiter.resume() }
  }
  deinit { if lockDescriptor >= 0 { Darwin.close(lockDescriptor) } }

  private func prepareOwnedDirectory() throws {
    guard let directory, lockDescriptor < 0 else { return }
    try RecallDirectory.prepare(directory)
    let descriptor = open(
      directory.appendingPathComponent(".memoryos-recall.lock").path, O_CREAT | O_RDWR,
      S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
      throw RetrievalError.unavailable("Cannot open the recall cache lock.")
    }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      Darwin.close(descriptor)
      throw RetrievalError.busy
    }
    do {
      // The exclusive process lock prevents deleting another live instance's index.
      // Only our two provider namespaces are eligible, never canonical stores or model assets.
      for (name, prefix) in [
        ("wax", "memoryos-wax-recall-"), ("cactus", "memoryos-cactus-recall-"),
      ] {
        let providerDirectory = directory.appendingPathComponent(name)
        try RecallDirectory.prepare(providerDirectory)
        for child in try FileManager.default.contentsOfDirectory(
          at: providerDirectory, includingPropertiesForKeys: [.isSymbolicLinkKey])
        where child.lastPathComponent.hasPrefix(prefix) {
          try FileManager.default.removeItem(at: child)
        }
      }
      lockDescriptor = descriptor
    } catch {
      Darwin.close(descriptor)
      throw error
    }
  }

  private func releaseDirectory() {
    if lockDescriptor >= 0 {
      Darwin.close(lockDescriptor)
      lockDescriptor = -1
    }
  }

}
