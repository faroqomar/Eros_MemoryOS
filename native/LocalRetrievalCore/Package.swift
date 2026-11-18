// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalRetrievalCore", platforms: [.iOS(.v18), .macOS(.v14)],
  products: [.library(name: "RetrievalCore", targets: ["RetrievalCore"])],
  targets: [.target(name: "RetrievalCore")], swiftLanguageModes: [.v6])
