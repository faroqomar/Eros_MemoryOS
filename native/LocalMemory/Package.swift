// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalMemory",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "MemoryCore", targets: ["MemoryCore"]),
    .library(name: "MemorySQLite", targets: ["MemorySQLite"]),
    .library(name: "PersonalMemoryExtraction", targets: ["PersonalMemoryExtraction"]),
  ],
  dependencies: [.package(path: "../LocalChat")],
  targets: [
    .systemLibrary(name: "CSQLite"),
    .target(name: "MemoryCore"),
    .target(name: "MemorySQLite", dependencies: ["MemoryCore", "CSQLite"]),
    .target(
      name: "PersonalMemoryExtraction",
      dependencies: ["MemoryCore", .product(name: "ChatCore", package: "LocalChat")]),
    .testTarget(
      name: "PersonalMemoryExtractionTests",
      dependencies: [
        "PersonalMemoryExtraction", "MemoryCore", .product(name: "ChatCore", package: "LocalChat"),
      ]),
    .testTarget(
      name: "MemorySQLiteTests", dependencies: ["MemoryCore", "MemorySQLite", "CSQLite"]),
  ],
  swiftLanguageModes: [.v6]
)
