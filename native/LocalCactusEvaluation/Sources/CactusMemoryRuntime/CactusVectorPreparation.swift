import CryptoKit
import Foundation
import RetrievalCore

/// Produces vectors in source order, with bounded durable progress before an index is published.
/// Checkpoints contain only current content hashes and completed vectors; never source IDs/text.
enum CactusVectorPreparation {
  static let checkpointInterval = 32

  struct Result {
    let ordered: [[Float]]
    let cache: [Data: [Float]]
  }

  static func prepare(
    records: [MemorySearchRecord], cached: [Data: [Float]], dimension: Int,
    checkpointInterval: Int = checkpointInterval,
    embed: (String) throws -> [Float], checkpoint: ([Data: [Float]]) throws -> Void
  ) throws -> Result {
    guard checkpointInterval > 0, (1...8192).contains(dimension) else {
      throw RetrievalError.invalidInput("Invalid vector preparation limits.")
    }
    let keys = records.map { Data(SHA256.hash(data: Data($0.text.utf8))) }
    let requested = Set(keys)
    var next = cached.filter { requested.contains($0.key) }
    guard next.allSatisfy({ valid($0.value, dimension: dimension) }) else {
      throw RetrievalError.invalidResult("Invalid cached document vectors.")
    }
    // Prune first, including on failure. Existing current vectors need not be visited
    // again before they can survive an interrupted preparation.
    if next.count != cached.count { try checkpoint(next) }
    let bytesPerVector = 32 + dimension * MemoryLayout<Float>.stride
    let maximumEntries = CactusDocumentVectorCache.maximumVectorBytes / bytesPerVector
    guard next.count <= maximumEntries else {
      throw RetrievalError.invalidResult("Document-vector cache exceeds its bound.")
    }
    var ordered: [[Float]] = []
    ordered.reserveCapacity(records.count)
    var pending = 0
    for (record, key) in zip(records, keys) {
      try Task.checkCancellation()
      let vector: [Float]
      if let value = next[key] {
        vector = value
      } else {
        vector = try embed(record.text)
        try Task.checkCancellation()
        guard valid(vector, dimension: dimension) else {
          throw RetrievalError.invalidResult("Cactus returned inconsistent embedding dimensions.")
        }
        if next.count < maximumEntries {
          next[key] = vector
          pending += 1
        }
      }
      ordered.append(vector)
      if pending >= checkpointInterval {
        try checkpoint(next)
        pending = 0
      }
    }
    try Task.checkCancellation()
    if pending > 0 { try checkpoint(next) }
    return Result(ordered: ordered, cache: next)
  }

  private static func valid(_ vector: [Float], dimension: Int) -> Bool {
    vector.count == dimension && vector.allSatisfy(\.isFinite)
  }
}
