// swift-tools-version: 6.2
// TEMPORARY LOCAL SNAPSHOT CHECK. This does not replace the canonical direct-URL manifest.
import PackageDescription
let package = Package(
  name: "MLXLocalSourceChecks",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "MLXEvaluationAdapter", targets: ["MLXEvaluationAdapter"]),
    .executable(name: "mlx-evaluation", targets: ["MLXEvaluationCLI"]),
  ],
  dependencies: [
    .package(path: "/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIEvaluation"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/mlx-swift-lm", traits: []),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/mlx-swift"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/swift-transformers"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/swift-numerics"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/swift-jinja"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/EventSource"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/yyjson"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/swift-huggingface"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/swift-collections"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots/swift-syntax"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/wax-verified-snapshots/swift-crypto"),
    .package(path: "/Users/eros/Library/Caches/MemoryOS-AI-Evaluation/wax-verified-snapshots/swift-asn1"),
  ],
  targets: [
    .target(name: "MLXEvaluationAdapter", dependencies: [
      .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      .product(name: "MLXLLM", package: "mlx-swift-lm"),
      .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
      .product(name: "Tokenizers", package: "swift-transformers"),
    ]),
    .executableTarget(name: "MLXEvaluationCLI", dependencies: [
      "MLXEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation")
    ]),
    .testTarget(name: "MLXEvaluationAdapterTests", dependencies: [
      "MLXEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation")
    ]),
  ], swiftLanguageModes: [.v6]
)
