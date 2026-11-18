import Foundation
// swift-tools-version: 6.2
import PackageDescription

// Explicit developer override prepared by scripts/prepare-wax-ios-override.py.
// The canonical pin remains the default; the reviewed mobile guard patch is required for iOS.
let waxDependency: Package.Dependency
if let path = ProcessInfo.processInfo.environment["MEMORYOS_WAX_PACKAGE_PATH"] {
  precondition(path.hasPrefix("/"), "Wax override must be an absolute prepared source path")
  waxDependency = .package(path: path, traits: [])
} else {
  waxDependency = .package(
    url: "https://github.com/christopherkarani/Wax.git",
    revision: "e4587f8cebb76aa92ece008253f13c66b756e68b", traits: [])
}

let package = Package(
  name: "LocalAIIntegrations",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "WaxMemoryRuntime", targets: ["WaxMemoryRuntime"]),
    .library(name: "WaxEvaluationAdapter", targets: ["WaxEvaluationAdapter"]),
    .executable(name: "wax-evaluation", targets: ["WaxEvaluationCLI"]),
  ],
  dependencies: [
    .package(path: "../LocalRetrievalCore"),
    .package(path: "../LocalAIEvaluation"),
    waxDependency,
  ],
  targets: [
    .target(
      name: "WaxMemoryRuntime",
      dependencies: [
        .product(name: "RetrievalCore", package: "LocalRetrievalCore"),
        .product(name: "Wax", package: "Wax"),
      ]),
    .target(
      name: "WaxEvaluationAdapter",
      dependencies: [
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
        "WaxMemoryRuntime", .product(name: "RetrievalCore", package: "LocalRetrievalCore"),
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
