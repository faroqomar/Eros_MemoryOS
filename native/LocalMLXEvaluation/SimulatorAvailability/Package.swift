// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "MLXSimulatorAvailability",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [.library(name: "MLXSimulatorAvailability", targets: ["MLXSimulatorAvailability"])],
  dependencies: [.package(path: "../../LocalAIEvaluation")],
  targets: [
    .target(
      name: "MLXSimulatorAvailability",
      dependencies: [.product(name: "AIEvaluationCore", package: "LocalAIEvaluation")]),
    .testTarget(
      name: "MLXSimulatorAvailabilityTests",
      dependencies: [
        "MLXSimulatorAvailability",
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]),
  ],
  swiftLanguageModes: [.v6]
)
