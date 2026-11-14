// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MemoryOSFeatureChecks", platforms: [.macOS(.v14)], dependencies: [.package(path: "/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalMemory")], targets: [.target(name: "MemoryOS", dependencies: [.product(name: "MemoryCore", package: "LocalMemory")]), .testTarget(name: "MemoryOSTests", dependencies: ["MemoryOS", .product(name: "MemoryCore", package: "LocalMemory")])], swiftLanguageModes: [.v6])
