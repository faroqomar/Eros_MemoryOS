// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VerifierBenchmark", platforms: [.macOS(.v14)], dependencies: [.package(path: "/Users/eros/Dev/Eros_Projects/Eros_MemoryOS/native/LocalMemory")], targets: [.executableTarget(name: "Benchmark", dependencies: [.product(name: "MemoryCore", package: "LocalMemory"), .product(name: "MemorySQLite", package: "LocalMemory")])], swiftLanguageModes: [.v6])
