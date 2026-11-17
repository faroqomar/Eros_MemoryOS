// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalAudio",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "AudioCore", targets: ["AudioCore"]),
    .library(name: "AudioPersistence", targets: ["AudioPersistence"]),
  ],
  targets: [
    .target(name: "AudioCore"),
    .target(name: "AudioPersistence", dependencies: ["AudioCore"]),
    .testTarget(name: "AudioTests", dependencies: ["AudioCore", "AudioPersistence"]),
  ],
  swiftLanguageModes: [.v6]
)
