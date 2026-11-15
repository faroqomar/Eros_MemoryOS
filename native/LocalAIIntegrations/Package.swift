// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "LocalAIIntegrations",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "WaxEvaluationAdapter", targets: ["WaxEvaluationAdapter"]),
    .executable(name: "wax-evaluation", targets: ["WaxEvaluationCLI"]),
  ],
  dependencies: [
    .package(path: "../LocalAIEvaluation"),
    .package(
      url: "https://github.com/christopherkarani/Wax.git",
      revision: "e4587f8cebb76aa92ece008253f13c66b756e68b",
      traits: []
    ),
  ],
  targets: [
    .target(
      name: "WaxEvaluationAdapter",
      dependencies: [
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
        .product(name: "Wax", package: "Wax"),
      ]
    ),
    .executableTarget(
      name: "WaxEvaluationCLI",
      dependencies: [
        "WaxEvaluationAdapter",
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]
    ),
    .testTarget(
      name: "WaxEvaluationAdapterTests",
      dependencies: [
        "WaxEvaluationAdapter",
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
