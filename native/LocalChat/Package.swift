// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalChat",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "ChatCore", targets: ["ChatCore"]),
    .library(name: "ChatPersistence", targets: ["ChatPersistence"]),
    .library(name: "ChatPresentation", targets: ["ChatPresentation"]),
  ],
  targets: [
    .target(name: "ChatCore"),
    .target(name: "ChatPersistence", dependencies: ["ChatCore"]),
    .target(name: "ChatPresentation", dependencies: ["ChatCore"]),
    .testTarget(
      name: "ChatTests", dependencies: ["ChatCore", "ChatPersistence", "ChatPresentation"]),
  ],
  swiftLanguageModes: [.v6]
)
