// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "LocalWaxRuntimeBinary", platforms: [.iOS(.v18), .macOS(.v14)],
  products: [.library(name: "WaxMemoryRuntimeBinary", targets: ["WaxMemoryRuntimeDependencies"])],
  dependencies: [.package(path: "../../LocalRetrievalCore")],
  targets: [
    .binaryTarget(name: "WaxMemoryRuntime", path: "Artifacts/WaxMemoryRuntime.xcframework"),
    .target(
      name: "WaxMemoryRuntimeDependencies",
      dependencies: [
        "WaxMemoryRuntime", .product(name: "RetrievalCore", package: "LocalRetrievalCore"),
      ], resources: [.copy("Resources")]),
  ], swiftLanguageModes: [.v6])
