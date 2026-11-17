// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalTranscription",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "WhisperKitTranscription", targets: ["WhisperKitTranscription"]),
    .library(name: "WhisperCppTranscription", targets: ["WhisperCppTranscription"]),
    .library(name: "TranscriptionSupport", targets: ["TranscriptionSupport"]),
    .executable(name: "transcription-comparison", targets: ["TranscriptionComparison"]),
  ],
  dependencies: [
    .package(path: "../LocalAudio"),
    .package(
      url: "https://github.com/argmaxinc/argmax-oss-swift.git",
      revision: "1bbc57cb7fe6410248a685b1c5a3c6d56adc2ed4"),
  ],
  targets: [
    // A dynamic two-level framework isolates its own ggml bindings from the app's
    // independently pinned dynamic llama.cpp. Preparation verifies Mach-O linkage.
    .binaryTarget(name: "whisper", path: "Artifacts/whisper.xcframework"),
    .target(name: "TranscriptionSupport"),
    .target(
      name: "WhisperKitTranscription",
      dependencies: [
        "TranscriptionSupport", .product(name: "AudioCore", package: "LocalAudio"),
        .product(name: "WhisperKit", package: "argmax-oss-swift"),
      ]),
    .target(
      name: "WhisperCppTranscription",
      dependencies: [
        "whisper", "TranscriptionSupport", .product(name: "AudioCore", package: "LocalAudio"),
      ]),
    .executableTarget(
      name: "TranscriptionComparison",
      dependencies: [
        "WhisperKitTranscription", "WhisperCppTranscription", "TranscriptionSupport",
        .product(name: "AudioCore", package: "LocalAudio"),
      ]),
    .testTarget(
      name: "TranscriptionTests",
      dependencies: [
        "TranscriptionSupport", "WhisperKitTranscription", "WhisperCppTranscription",
      ]),
  ],
  swiftLanguageModes: [.v6]
)
