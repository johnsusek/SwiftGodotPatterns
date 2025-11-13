// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SwiftGodotPatterns",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SwiftGodotPatterns", type: .dynamic, targets: ["SwiftGodotPatterns"]),
        .plugin(name: "GenNodeApi", targets: ["GenNodeApi"]),
        .plugin(name: "GenLDEnums", targets: ["GenLDEnums"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", branch: "main"),
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

        // Codegen tool that scans Swift sources for LDExported enums and writes ldtkEnums.json
        .executableTarget(
            name: "LDEnumGen",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Sources/LDEnumGen"
        ),

        // Build-tool plugin that invokes LDEnumGen every build.
        .plugin(
            name: "GenLDEnums",
            capability: .buildTool(),
            dependencies: ["LDEnumGen"]
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
                "SwiftGodotPatternsMacros",
            ],
            plugins: ["GenNodeApi"]
        ),

        .testTarget(
            name: "SwiftGodotPatternsTests",
            dependencies: ["SwiftGodotPatterns"],
            resources: [
                .copy("Test_file_for_API_showing_all_features.ldtk"),
            ]
        ),
    ]
)
