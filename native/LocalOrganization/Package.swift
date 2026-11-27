// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalOrganization", platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "OrganizationCore", targets: ["OrganizationCore"]),
    .library(name: "OrganizationPersistence", targets: ["OrganizationPersistence"]),
  ],
  dependencies: [.package(path: "../LocalMemory")],
  targets: [
    .target(
      name: "OrganizationCore", dependencies: [.product(name: "MemoryCore", package: "LocalMemory")]
    ),
    .target(name: "OrganizationPersistence", dependencies: ["OrganizationCore"]),
    .testTarget(
      name: "OrganizationTests",
      dependencies: [
        "OrganizationCore", "OrganizationPersistence",
        .product(name: "MemoryCore", package: "LocalMemory"),
      ]),
  ], swiftLanguageModes: [.v6]
)
