// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PaperShaders",
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
  ],
  products: [
    .library(name: "PaperShaders", targets: ["PaperShaders"]),
    .library(name: "PaperShadersSwiftUI", targets: ["PaperShadersSwiftUI"]),
  ],
  targets: [
    .target(
      name: "PaperShaders",
      resources: [
        .copy("Resources/noise.png"),
        .copy("Resources/flowers.png"),
        .copy("Resources/gem-smoke.png"),
        .copy("Resources/heatmap.png"),
        .copy("Resources/liquid-metal.png"),
      ]
    ),
    .target(
      name: "PaperShadersSwiftUI",
      dependencies: ["PaperShaders"]
    ),
    .testTarget(
      name: "ParityTests",
      dependencies: ["PaperShaders"]
    ),
  ]
)
