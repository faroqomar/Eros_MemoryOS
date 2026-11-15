import CactusEvaluationAdapter
import Foundation
import Testing
import cactus

@Test(.enabled(if: ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"] != nil))
func explicitLastTokenEmbeddingIsNormalizedAndDistinctFromMeanPooling() throws {
  let path = try #require(ProcessInfo.processInfo.environment["CACTUS_EVAL_MODEL_DIR"])
  #expect(CactusMemoryIndexAdapter.isLocalOnlyRuntime)
  let model = try #require(cactus_init(path, nil, false))
  defer { cactus_destroy(model) }
  let input = "The fictional Cedar launch is on 18 July."
  var last = [Float](repeating: 0, count: 4096)
  var mean = [Float](repeating: 0, count: 4096)
  var lastDimension = 0
  var meanDimension = 0
  let lastStatus = cactus_memoryos_evaluation_embed_last_token(
    model, input, &last, last.count * MemoryLayout<Float>.stride, &lastDimension, true)
  let meanStatus = cactus_embed(
    model, input, &mean, mean.count * MemoryLayout<Float>.stride, &meanDimension, true)
  #expect(lastStatus == 1024)
  #expect(lastDimension == 1024)
  #expect(meanStatus == 1024)
  #expect(meanDimension == 1024)
  let norm = last.prefix(lastDimension).reduce(0.0) { $0 + Double($1) * Double($1) }
  #expect(abs(norm - 1) < 0.0001)
  let differs = zip(last.prefix(lastDimension), mean.prefix(meanDimension)).contains {
    abs($0.0 - $0.1) > 0.0001
  }
  #expect(differs)
}
