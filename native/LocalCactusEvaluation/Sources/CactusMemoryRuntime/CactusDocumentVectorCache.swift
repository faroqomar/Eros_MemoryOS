import CryptoKit
import Foundation
import RetrievalCore

/// Disposable, content-addressed document vectors. This file never stores query text or source text.
/// The pipeline fingerprint covers the reviewed model, tokenizer and pooling implementation.
enum CactusDocumentVectorCache {
  static let fileName = "memoryos-cactus-document-vectors-v1.bin"
  static let maximumVectorBytes = 64 * 1024 * 1024
  private static let magic = Data("MOSVEC01".utf8)
  private static let headerBytes = 48
  private static let checksumBytes = 32

  static func load(directory: URL, pipeline: Data, dimension: Int) throws -> [Data: [Float]] {
    try Task.checkCancellation()
    let url = directory.appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
    let attributes = try url.resourceValues(forKeys: [
      .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
    ])
    guard attributes.isRegularFile == true, attributes.isSymbolicLink != true,
      let size = attributes.fileSize, size >= headerBytes + checksumBytes,
      size <= maximumVectorBytes + headerBytes + checksumBytes
    else {
      try remove(directory: directory)
      return [:]
    }
    let data = try Data(contentsOf: url)
    guard let result = try decode(data, pipeline: pipeline, dimension: dimension) else {
      try remove(directory: directory)
      return [:]
    }
    return result
  }

  static func save(_ vectors: [Data: [Float]], directory: URL, pipeline: Data, dimension: Int)
    throws
  {
    guard !vectors.isEmpty else {
      try remove(directory: directory)
      return
    }
    guard pipeline.count == 32, (1...8192).contains(dimension),
      vectors.count <= maximumVectorBytes / (32 + dimension * 4),
      vectors.allSatisfy({
        $0.key.count == 32 && $0.value.count == dimension && $0.value.allSatisfy(\.isFinite)
      })
    else { throw RetrievalError.invalidResult("Invalid document-vector cache values.") }
    try Task.checkCancellation()
    var data = magic
    data.append(pipeline)
    append(UInt32(dimension), to: &data)
    append(UInt32(vectors.count), to: &data)
    for key in vectors.keys.sorted(by: { $0.lexicographicallyPrecedes($1) }) {
      try Task.checkCancellation()
      data.append(key)
      for value in vectors[key]! { append(value.bitPattern, to: &data) }
    }
    data.append(contentsOf: SHA256.hash(data: data))
    try RecallDirectory.prepare(directory)
    try Task.checkCancellation()
    let url = directory.appendingPathComponent(fileName)
    if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
      try FileManager.default.removeItem(at: url)
    }
    #if os(iOS)
      try data.write(to: url, options: [.atomic, .completeFileProtection])
    #else
      try data.write(to: url, options: [.atomic])
    #endif
  }

  static func remove(directory: URL) throws {
    let url = directory.appendingPathComponent(fileName)
    // Also remove dangling links without following their target.
    if FileManager.default.fileExists(atPath: url.path)
      || (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    {
      try FileManager.default.removeItem(at: url)
    }
  }

  private static func decode(_ data: Data, pipeline: Data, dimension: Int) throws -> [Data:
    [Float]]?
  {
    guard pipeline.count == 32, (1...8192).contains(dimension),
      data.count >= headerBytes + checksumBytes,
      data.count <= maximumVectorBytes + headerBytes + checksumBytes,
      data.prefix(8) == magic, data[8..<40] == pipeline,
      read(data, at: 40) == UInt32(dimension)
    else { return nil }
    let count = Int(read(data, at: 44))
    let stride = 32 + dimension * 4
    guard count > 0, count <= maximumVectorBytes / stride,
      data.count == headerBytes + count * stride + checksumBytes,
      Data(SHA256.hash(data: data.dropLast(checksumBytes))) == data.suffix(checksumBytes)
    else { return nil }
    var result: [Data: [Float]] = [:]
    for index in 0..<count {
      try Task.checkCancellation()
      let offset = headerBytes + index * stride
      let key = Data(data[offset..<offset + 32])
      guard result[key] == nil else { return nil }
      var vector: [Float] = []
      vector.reserveCapacity(dimension)
      for component in 0..<dimension {
        let value = Float(bitPattern: read(data, at: offset + 32 + component * 4))
        guard value.isFinite else { return nil }
        vector.append(value)
      }
      result[key] = vector
    }
    return result
  }

  private static func append(_ value: UInt32, to data: inout Data) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
  }

  private static func read(_ data: Data, at offset: Int) -> UInt32 {
    data.withUnsafeBytes {
      UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }
  }
}
