// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "LocalMLXEvaluation",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "MLXEvaluationAdapter", targets: ["MLXEvaluationAdapter"]),
    .executable(name: "mlx-evaluation", targets: ["MLXEvaluationCLI"]),
  ],
  dependencies: [
    .package(path: "../LocalAIEvaluation"),
    .package(
      url: "https://github.com/ml-explore/mlx-swift-lm",
      revision: "3b339ad6e3b3f44c8121ecff5131c7fd55e075e6", traits: []),
    .package(
      url: "https://github.com/huggingface/swift-transformers",
      revision: "402a8a1105f52038b0949d9596981fc9e32bed17"),
  ],
  targets: [
    .target(
      name: "MLXEvaluationAdapter",
      dependencies: [
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
        .product(name: "MLXLLM", package: "mlx-swift-lm"),
        .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
        .product(name: "Tokenizers", package: "swift-transformers"),
      ]),
    .executableTarget(
      name: "MLXEvaluationCLI",
      dependencies: [
        "MLXEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]),
    .testTarget(
      name: "MLXEvaluationAdapterTests",
      dependencies: [
        "MLXEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]),
  ],
  swiftLanguageModes: [.v6]
)
