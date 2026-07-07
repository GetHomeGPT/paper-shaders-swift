// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PaperShadersDemo",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
  ],
  dependencies: [
    .package(name: "PaperShaders", path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "PaperShadersDemo",
      dependencies: [
        .product(name: "PaperShaders", package: "PaperShaders"),
        .product(name: "PaperShadersSwiftUI", package: "PaperShaders"),
      ],
      resources: [
        .process("Resources"),
      ]
    )
  ]
)
