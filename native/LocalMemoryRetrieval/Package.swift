// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "LocalMemoryRetrieval", platforms: [.iOS(.v18), .macOS(.v14)],
  products: [.library(name: "LocalMemoryRetrieval", targets: ["LocalMemoryRetrieval"])],
  dependencies: [
    .package(path: "../LocalRetrievalCore"),
    .package(path: "../LocalAIIntegrations/RuntimeBinaryIntegration"),
    .package(path: "../LocalCactusEvaluation"),
  ],
  targets: [
    .target(
      name: "LocalMemoryRetrieval",
      dependencies: [
        .product(name: "RetrievalCore", package: "LocalRetrievalCore"),
        .product(name: "WaxMemoryRuntimeBinary", package: "RuntimeBinaryIntegration"),
        .product(name: "CactusMemoryRuntime", package: "LocalCactusEvaluation"),
      ]),
    .testTarget(
      name: "LocalMemoryRetrievalTests",
      dependencies: [
        .product(name: "CactusMemoryRuntime", package: "LocalCactusEvaluation"),
        "LocalMemoryRetrieval", .product(name: "RetrievalCore", package: "LocalRetrievalCore"),
      ]),
  ], swiftLanguageModes: [.v6]
)
