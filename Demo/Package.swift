// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "DemoApp",
  platforms: [.macOS(.v14)],
  products: [
    .library(
      name: "DemoApp",
      type: .dynamic,
      targets: ["DemoApp"]
    ),
  ],
  dependencies: [
    .package(path: ".."),
  ],
  targets: [
    .target(
      name: "DemoApp",
      dependencies: [
        "SwiftGodotPatterns",
      ]
    ),
  ]
)
