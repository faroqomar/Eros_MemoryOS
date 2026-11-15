// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalTextEvaluation",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "LlamaEvaluationAdapter", targets: ["LlamaEvaluationAdapter"]),
    .executable(name: "llama-evaluation", targets: ["LlamaEvaluationCLI"]),
  ],
  dependencies: [.package(path: "../LocalAIEvaluation")],
  targets: [
    // The official b12387 binary omits Simulator. Build this exact reviewed revision
    // with scripts/prepare-llama-evaluation.py; retain its source/binary hash receipt.
    .binaryTarget(name: "llama", path: "Artifacts/llama.xcframework"),
    .target(
      name: "LlamaEvaluationAdapter",
      dependencies: ["llama", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation")],
      linkerSettings: [.linkedFramework("Accelerate"), .linkedLibrary("c++")]),
    .executableTarget(
      name: "LlamaEvaluationCLI",
      dependencies: [
        "LlamaEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]),
    .testTarget(
      name: "LlamaEvaluationAdapterTests",
      dependencies: [
        "LlamaEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]),
  ],
  swiftLanguageModes: [.v6]
)
