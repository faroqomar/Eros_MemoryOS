import Foundation
import Testing
import cactus

/// Real SDK index contract with controlled vectors. This does not test an embedding model.
@Test func nativeIndexRanksDeletesAndPersistsControlledVectors() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "memoryos-cactus-native-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directory) }
  cactus_log_set_level(4)
  let index = try #require(cactus_index_init(directory.path, 2))
  var current: UnsafeMutableRawPointer? = index
  defer { if let current { cactus_index_destroy(current) } }

  func add(_ id: Int32, _ text: String, vector: [Float]) throws {
    var numericID = id
    let status = text.withCString { textPointer in
      var document: UnsafePointer<CChar>? = textPointer
      return vector.withUnsafeBufferPointer { values in
        var embedding = values.baseAddress
        return cactus_index_add(index, &numericID, &document, nil, &embedding, 1, 2)
      }
    }
    #expect(status == 0)
  }
  func query(_ handle: UnsafeMutableRawPointer) throws -> [Int32] {
    var ids = [Int32](repeating: 0, count: 2)
    var scores = [Float](repeating: 0, count: 2)
    var idCount = 2
    var scoreCount = 2
    let status = [Float(1), Float(0)].withUnsafeBufferPointer { values in
      var vector = values.baseAddress
      return ids.withUnsafeMutableBufferPointer { idBuffer in
        var outputIDs = idBuffer.baseAddress
        return scores.withUnsafeMutableBufferPointer { scoreBuffer in
          var outputScores = scoreBuffer.baseAddress
          return cactus_index_query(
            handle, &vector, 1, 2, "{\"top_k\":2,\"score_threshold\":-1}", &outputIDs, &idCount,
            &outputScores, &scoreCount)
        }
      }
    }
    #expect(status == 0)
    #expect(idCount == scoreCount)
    #expect((0...2).contains(idCount))
    let finiteScores = scores.prefix(max(0, min(idCount, 2))).allSatisfy { $0.isFinite }
    #expect(finiteScores)
    return Array(ids.prefix(max(0, min(idCount, 2))))
  }
  try add(7, "Café نور 🌙", vector: [1, 0])
  try add(9, "A separate fictional record", vector: [0, 1])
  #expect(try query(index).first == 7)
  var removed: Int32 = 7
  #expect(cactus_index_delete(index, &removed, 1) == 0)
  #expect(try query(index) == [9])
  #expect(cactus_index_compact(index) == 0)
  cactus_index_destroy(index)
  current = nil
  let reopened = try #require(cactus_index_init(directory.path, 2))
  current = reopened
  #expect(try query(reopened) == [9])
}
