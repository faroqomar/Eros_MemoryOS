// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "LocalWaxBinaryEvaluation",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "WaxEvaluationAdapterBinary", targets: ["WaxEvaluationBinaryDependencies"])
  ],
  dependencies: [.package(path: "../../LocalAIEvaluation")],
  targets: [
    .binaryTarget(name: "WaxEvaluationAdapter", path: "Artifacts/WaxEvaluationAdapter.xcframework"),
    .target(
      name: "WaxEvaluationBinaryDependencies",
      dependencies: [
        "WaxEvaluationAdapter",
        .product(name: "AIEvaluationCore", package: "LocalAIEvaluation"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
