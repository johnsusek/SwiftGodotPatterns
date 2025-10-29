// swift-tools-version: 5.9

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SwiftGodotPatterns",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SwiftGodotPatterns", type: .dynamic, targets: ["SwiftGodotPatterns"]),
        .plugin(name: "GenNodeApi", targets: ["GenNodeApi"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-atomics", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0"),
        .package(url: "https://github.com/fumoboy007/msgpack-swift", from: "2.0.6"),
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "20d2d7a35d2ad392ec556219ea004da14ab7c1d4"),
    ],
    targets: [
        // Codegen tool that reads extension_api.json and writes GeneratedGNodeAliases.swift
        .executableTarget(name: "NodeApiGen", path: "Sources/NodeApiGen"),

        // Build-tool plugin that invokes NodeApiGen every build.
        .plugin(
            name: "GenNodeApi",
            capability: .buildTool(),
            dependencies: ["NodeApiGen"]
        ),

        .macro(
            name: "SwiftGodotPatternsMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "SwiftGodotPatterns",
            dependencies: [
                "SwiftGodot",
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "DMMessagePack", package: "msgpack-swift"),
            ],
            plugins: ["GenNodeApi"]
        ),
    ]
)
