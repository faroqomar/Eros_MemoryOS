// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalAIEvaluation",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "AIEvaluationCore", targets: ["AIEvaluationCore"]),
    .library(name: "AIEvaluationPresentation", targets: ["AIEvaluationPresentation"]),
    .executable(name: "ai-evaluation", targets: ["AIEvaluationCLI"]),
  ],
  targets: [
    .target(name: "AIEvaluationCore"),
    .target(name: "AIEvaluationPresentation", dependencies: ["AIEvaluationCore"]),
    .executableTarget(name: "AIEvaluationCLI", dependencies: ["AIEvaluationCore"]),
    .testTarget(name: "AIEvaluationCoreTests", dependencies: ["AIEvaluationCore"]),
    .testTarget(
      name: "AIEvaluationPresentationTests",
      dependencies: ["AIEvaluationCore", "AIEvaluationPresentation"]),
  ],
  swiftLanguageModes: [.v6]
)
