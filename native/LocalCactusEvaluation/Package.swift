// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalCactusEvaluation",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "CactusEvaluationAdapter", targets: ["CactusEvaluationAdapter"]),
    .executable(name: "cactus-evaluation", targets: ["CactusEvaluationCLI"]),
  ],
  dependencies: [.package(path: "../LocalAIEvaluation")],
  targets: [
    .binaryTarget(name: "cactus", path: "Artifacts/cactus.xcframework"),
    .target(
      name: "CactusEvaluationAdapter",
      dependencies: ["cactus", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation")],
      resources: [.copy("Resources")],
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
        "cactus", "CactusEvaluationAdapter",
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]),
  ],
  swiftLanguageModes: [.v6]
)
