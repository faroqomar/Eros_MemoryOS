// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalMemory",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "MemoryCore", targets: ["MemoryCore"]),
    .library(name: "MemorySQLite", targets: ["MemorySQLite"]),
  ],
  targets: [
    .systemLibrary(name: "CSQLite"),
    .target(name: "MemoryCore"),
    .target(name: "MemorySQLite", dependencies: ["MemoryCore", "CSQLite"]),
    .testTarget(
      name: "MemorySQLiteTests", dependencies: ["MemoryCore", "MemorySQLite", "CSQLite"]),
  ],
  swiftLanguageModes: [.v6]
)
