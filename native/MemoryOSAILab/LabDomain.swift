import AIEvaluationCore
import Foundation

struct LabCandidate: Identifiable, Sendable {
  let id: String
  let title: String
  let detail: String
}

enum LabCatalog {
  static let candidates = [
    LabCandidate(
      id: "keyword-control", title: "Keyword control",
      detail: "Lexical retrieval only. No text model."),
    LabCandidate(
      id: "wax-lexical", title: "Wax · keyword",
      detail: "Local lexical index. Embeddings disabled."),
    LabCandidate(
      id: "cactus", title: "Cactus-based memory",
      detail: "Patched local CPU SDK. Verified embedding assets required."),
    LabCandidate(
      id: "llama-qwen", title: "llama.cpp · Qwen3-1.7B",
      detail: "Reviewed Q4_K_M asset. Same examples and generation settings."),
    LabCandidate(
      id: "llama-qwen06", title: "llama.cpp · Qwen3-0.6B",
      detail: "Smaller Q4_K_M model. Compare source accuracy before selecting."),
    LabCandidate(
      id: "mlx-qwen", title: "MLX Swift · Qwen3",
      detail: "Upstream does not support iOS Simulator. Mac output checks are separate."),
  ]
}
