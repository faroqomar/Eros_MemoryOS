import Foundation
import Testing
import cactus

@testable import CactusMemoryRuntime

struct QwenEmbeddingPreprocessorTests {
  private func data() throws -> Data {
    let url = try #require(
      Bundle.module.url(
        forResource: "qwen-embedding-tokenizer", withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
  }

  @Test func exactAddedTokensPrecedeNFCAndRegexPreservesCoverage() throws {
    let preprocessor = try QwenEmbeddingPreprocessor(tokenizerData: data())
    let original = "e\u{301}<|endoftext|> سارة؟"
    let originalBytes = Data(original.utf8)
    #expect(
      try preprocessor.pieces(in: original) == [
        .text("é"), .token(151643), .text(" سارة"), .text("؟"),
      ])
    let pieces = try preprocessor.pieces(in: original)
    guard case .text(let normalized) = pieces.first else {
      Issue.record("Missing normalized text")
      return
    }
    #expect(Array(normalized.utf8) == [0xC3, 0xA9])
    #expect(Data(original.utf8) == originalBytes)
    #expect(
      try preprocessor.pieces(in: "a  b\t c") == [
        .text("a"), .text(" "), .text(" b"), .text("\t"), .text(" c"),
      ])
  }

  @Test func recognizesAllAddedTokensAndAlwaysAppendsOnePostprocessorEOS() throws {
    let bytes = try data()
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let added = try #require(object["added_tokens"] as? [[String: Any]])
    let preprocessor = try QwenEmbeddingPreprocessor(tokenizerData: bytes)
    for item in added {
      let content = try #require(item["content"] as? String)
      let id = try #require(item["id"] as? UInt32)
      var called = false
      let result = try preprocessor.tokenIDs(for: content) { _ in
        called = true
        return [1]
      }
      #expect(!called)
      #expect(result == [id, 151643])
    }
    #expect(try preprocessor.tokenIDs(for: "") { _ in [1] } == [151643])
  }

  @Test func boundsTokensBeforeNativeInferenceAndRejectsInvalidPieces() throws {
    let preprocessor = try QwenEmbeddingPreprocessor(tokenizerData: data())
    #expect(
      try preprocessor.tokenIDs(for: "x") { _ in Array(repeating: 1, count: 32767) }.count == 32768)
    #expect(throws: QwenEmbeddingPreprocessor.Failure.self) {
      try preprocessor.tokenIDs(for: "x") { _ in Array(repeating: 1, count: 32768) }
    }
    #expect(throws: QwenEmbeddingPreprocessor.Failure.self) {
      try preprocessor.tokenIDs(for: "x") { _ in [] }
    }
    #expect(throws: QwenEmbeddingPreprocessor.Failure.self) {
      try preprocessor.tokenIDs(for: "x") { _ in [151669] }
    }
    #expect(throws: QwenEmbeddingPreprocessor.Failure.self) { try preprocessor.pieces(in: "x\0y") }
    #expect(throws: QwenEmbeddingPreprocessor.Failure.self) {
      try preprocessor.pieces(in: String(repeating: "a", count: 131073))
    }
    // Unknown is a valid model token, including an explicitly supplied <unk> added token.
    #expect(try preprocessor.tokenIDs(for: "x") { _ in [128244] } == [128244, 151643])
  }

  @Test func rejectsUnsupportedMetadataAndIncompleteRegexCoverage() throws {
    let baseline = try #require(JSONSerialization.jsonObject(with: data()) as? [String: Any])
    for flag in ["normalized", "single_word", "lstrip", "rstrip"] {
      var changed = baseline
      var added = try #require(changed["added_tokens"] as? [[String: Any]])
      added[0][flag] = true
      changed["added_tokens"] = added
      let bytes = try JSONSerialization.data(withJSONObject: changed)
      #expect(throws: QwenEmbeddingPreprocessor.Failure.self) {
        try QwenEmbeddingPreprocessor(tokenizerData: bytes)
      }
    }
    var changed = baseline
    changed["normalizer"] = ["type": "NFKC"]
    #expect(throws: QwenEmbeddingPreprocessor.Failure.self) {
      try QwenEmbeddingPreprocessor(tokenizerData: JSONSerialization.data(withJSONObject: changed))
    }
    for pattern in ["x", "(?=x)"] {
      changed = baseline
      var pre = try #require(changed["pre_tokenizer"] as? [String: Any])
      var steps = try #require(pre["pretokenizers"] as? [[String: Any]])
      steps[0]["pattern"] = ["Regex": pattern]
      pre["pretokenizers"] = steps
      changed["pre_tokenizer"] = pre
      let preprocessor = try QwenEmbeddingPreprocessor(
        tokenizerData: JSONSerialization.data(withJSONObject: changed))
      #expect(throws: QwenEmbeddingPreprocessor.Failure.self) { try preprocessor.pieces(in: "x y") }
    }
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
  func nativeByteMappingAndModelPipelineMatchReferenceTokens() throws {
    let path = try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"])
    let model = try #require(cactus_init(path, nil, false))
    defer { cactus_destroy(model) }
    let preprocessor = try QwenEmbeddingPreprocessor(
      tokenizerData: Data(
        contentsOf: URL(fileURLWithPath: path).appendingPathComponent("tokenizer.json")))
    let cases: [(String, [UInt32])] = [
      (
        "بأي أيام سارة ما تروح للمكتب؟",
        [
          21360, 69682, 14558, 133674, 59842, 124226, 126198, 39434, 131429, 128883, 128667, 128332,
          151643,
        ]
      ),
      (
        "كيف تتنقل سارة إلى وظيفتها؟",
        [
          132558, 39434, 124706, 124388, 59842, 124226, 128252, 37524, 92381, 124394, 128412,
          128332, 151643,
        ]
      ),
      ("How does Maya commute?", [4340, 1558, 50344, 58163, 30, 151643]),
      ("a  b\t c", [64, 220, 293, 197, 272, 151643]),
      ("e\u{301}", [963, 151643]),
      ("##", [565, 151643]),
      ("<|endoftext|>", [151643, 151643]),
    ]
    for (input, expected) in cases {
      let tokens = try preprocessor.tokenIDs(for: input) { piece in
        var ids = [UInt32](repeating: 0, count: piece.utf8.count + 1)
        var count = 0
        let status = cactus_tokenize(model, piece, &ids, ids.count, &count)
        #expect(status == 0)
        try #require(count <= ids.count)
        return Array(ids.prefix(count))
      }
      #expect(tokens == expected)
    }
  }
}
