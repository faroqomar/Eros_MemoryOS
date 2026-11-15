// swift-tools-version: 6.2
import PackageDescription
let package = Package(
  name: "WaxSourceVerification",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "WaxEvaluationAdapter", targets: ["WaxEvaluationAdapter"]),
    .executable(name: "wax-evaluation", targets: ["WaxEvaluationCLI"]),
  ],
  dependencies: [
    .package(path: "/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalAIEvaluation"),
    .package(path: "SDK/Wax", traits: []),
    .package(path: "SDK/MetalANNS"),
    .package(path: "SDK/GRDB.swift"),
    .package(path: "SDK/swift-crypto"),
    .package(path: "SDK/swift-asn1"),
  ],
  targets: [
    .target(name: "WaxEvaluationAdapter", dependencies: [
      .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      .product(name: "Wax", package: "Wax"),
    ], swiftSettings: [.unsafeFlags(["-enable-library-evolution", "-emit-module-interface"])]),
    .executableTarget(name: "WaxEvaluationCLI", dependencies: [
      "WaxEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
    ]),
    .testTarget(name: "WaxEvaluationAdapterTests", dependencies: [
      "WaxEvaluationAdapter", .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
    ]),
  ],
  swiftLanguageModes: [.v6]
)
