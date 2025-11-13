#if canImport(PackagePlugin)
  import Foundation
  import PackagePlugin

  @main
  struct GenLDEnums: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
      guard let swiftTarget = target as? SwiftSourceModuleTarget else { return [] }
      let tool = try context.tool(named: "LDEnumGen")
      let sourceDir = swiftTarget.directoryURL

      let outDir: URL

      if let overrideOutDir = ProcessInfo.processInfo.environment["LD_ENUM_GEN_OUT_DIR"] {
        outDir = URL(fileURLWithPath: overrideOutDir)
      } else {
        outDir = context.pluginWorkDirectoryURL
      }

      let outFile = outDir.appending(path: "LDExported.json")

      return [.buildCommand(
        displayName: "LDEnumGen -> \(outFile.lastPathComponent)",
        executable: tool.url,
        arguments: [sourceDir.path(), outFile.path()],
        environment: [:],
        inputFiles: swiftTarget.sourceFiles(withSuffix: "swift").map(\.url),
        outputFiles: [outFile]
      )]
    }
  }
#endif
