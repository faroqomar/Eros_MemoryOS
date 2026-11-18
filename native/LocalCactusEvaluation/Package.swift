// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalCactusEvaluation",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "CactusMemoryRuntime", targets: ["CactusMemoryRuntime"]),
    .library(name: "CactusEvaluationAdapter", targets: ["CactusEvaluationAdapter"]),
    .executable(name: "cactus-evaluation", targets: ["CactusEvaluationCLI"]),
  ],
  dependencies: [.package(path: "../LocalAIEvaluation"), .package(path: "../LocalRetrievalCore")],
  targets: [
    .binaryTarget(name: "cactus", path: "Artifacts/cactus.xcframework"),
    .target(
      name: "CactusMemoryRuntime",
      dependencies: ["cactus", .product(name: "RetrievalCore", package: "LocalRetrievalCore")],
      resources: [.copy("Resources")],
      linkerSettings: [
        .linkedLibrary("c++"), .linkedFramework("Accelerate"), .linkedFramework("CoreML"),
        .linkedFramework("Foundation"),
      ]),
    .target(
      name: "CactusEvaluationAdapter",
      dependencies: [
        "CactusMemoryRuntime", .product(name: "RetrievalCore", package: "LocalRetrievalCore"),
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ],
      linkerSettings: [
        .linkedLibrary("c++"), .linkedFramework("Accelerate"), .linkedFramework("CoreML"),
        .linkedFramework("Foundation"),
      ]),
    .executableTarget(
      name: "CactusEvaluationCLI",
      dependencies: [
        "CactusEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]),
    .testTarget(
      name: "CactusEvaluationAdapterTests",
      dependencies: [
        "cactus", "CactusEvaluationAdapter", "CactusMemoryRuntime",
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ], resources: [.copy("Fixtures")]),
  ],
  swiftLanguageModes: [.v6]
)
