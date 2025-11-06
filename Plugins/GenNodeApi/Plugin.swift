// Sources/GenNodeApi/GenNodeApi.swift
#if canImport(PackagePlugin)
  import Foundation
  import PackagePlugin

  @main
  struct GenNodeApi: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
      guard let swiftTarget = target as? SwiftSourceModuleTarget else { return [] }

      let tool = try context.tool(named: "NodeApiGen")

      // Resolve extension_api.json; override with SWIFTGODOT_EXTENSION_API if you like.
      let apiPath = resolveAPIPath(context: context, target: swiftTarget)

      let outDir = context.pluginWorkDirectoryURL.appending(path: "nodeapi")
      let outFile = outDir.appending(path: "GeneratedGNodeAliases.swift")

      return [.buildCommand(
        displayName: "NodeApiGen -> \(outFile.lastPathComponent)",
        executable: tool.url,
        arguments: [apiPath.path(), outFile.path()],
        environment: [:],
        inputFiles: [apiPath, tool.url], // rerun if API or generator changes
        outputFiles: [outFile] // incremental cache key
      )]
    }

    private func resolveAPIPath(context: PluginContext, target: SwiftSourceModuleTarget) -> URL {
      if let env = ProcessInfo.processInfo.environment["SWIFTGODOT_EXTENSION_API"], !env.isEmpty { return URL(fileURLWithPath: env) }
      let root = context.package.directoryURL
      let local = root.appending(path: "extension_api.json")
      if FileManager.default.fileExists(atPath: local.path()) { return local }
      return target.directoryURL.appending(path: "Resources/extension_api.json")
    }
  }
#endif
