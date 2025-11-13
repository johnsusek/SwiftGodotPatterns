import Foundation
import SwiftParser
import SwiftSyntax

/**
 # LDEnumGen

 Scans Swift source files for enums conforming to `LDExported` and generates
 an `LDExported.json` file in the format LDtk expects:

 ```json
 {
   "Item": ["Knife", "Healing_Plant", "Meat"],
   "Direction": ["North", "South", "East", "West"]
 }
 ```

 This allows Swift code to be the source of truth for enum definitions,
 which LDtk will automatically sync when the file changes.
 */

struct EnumInfo {
  let identifier: String
  let ldtkName: String
  let cases: [String]
}

@inline(__always) func die(_ m: String) -> Never {
  fputs(m + "\n", stderr)
  exit(1)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
  die("usage: LDEnumGen <source-dir> <output-json>")
}

let sourceDir = URL(fileURLWithPath: args[1])
let outputJSON = URL(fileURLWithPath: args[2])

// MARK: - Swift Source File Scanner

class EnumVisitor: SyntaxVisitor {
  var enums: [EnumInfo] = []

  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    // Check if enum conforms to LDExported
    guard let inheritanceClause = node.inheritanceClause else {
      return .skipChildren
    }

    let inheritedTypes = inheritanceClause.inheritedTypes.map {
      $0.type.trimmedDescription
    }

    guard inheritedTypes.contains("LDExported") else {
      return .skipChildren
    }

    // Extract enum name
    let enumName = node.name.text

    // Extract ldtkIdentifier from static var if present
    var ldtkName = enumName
    for member in node.memberBlock.members {
      if let variableDecl = member.decl.as(VariableDeclSyntax.self),
         let binding = variableDecl.bindings.first,
         let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
         pattern.identifier.text == "ldtkIdentifier",
         variableDecl.modifiers.contains(where: { $0.name.text == "static" }),
         let initializer = binding.initializer,
         let stringLiteral = initializer.value.as(StringLiteralExprSyntax.self),
         let segment = stringLiteral.segments.first,
         case let .stringSegment(stringSegment) = segment
      {
        ldtkName = stringSegment.content.text
        break
      }
    }

    // Extract all enum cases with their raw values
    var cases: [String] = []
    for member in node.memberBlock.members {
      if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
        for element in caseDecl.elements {
          // Extract raw value from case (e.g., case knife = "Knife")
          if let rawValue = element.rawValue?.value.as(StringLiteralExprSyntax.self),
             let segment = rawValue.segments.first,
             case let .stringSegment(stringSegment) = segment
          {
            cases.append(stringSegment.content.text)
          } else {
            // If no raw value, use the case name capitalized
            cases.append(element.name.text.capitalized)
          }
        }
      }
    }

    if !cases.isEmpty {
      enums.append(EnumInfo(
        identifier: enumName,
        ldtkName: ldtkName,
        cases: cases
      ))
    }

    return .skipChildren
  }
}

// MARK: - File System Scanning

func findSwiftFiles(in directory: URL) -> [URL] {
  let fileManager = FileManager.default
  guard let enumerator = fileManager.enumerator(
    at: directory,
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles]
  ) else {
    return []
  }

  var swiftFiles: [URL] = []
  for case let fileURL as URL in enumerator {
    guard fileURL.pathExtension == "swift" else { continue }
    swiftFiles.append(fileURL)
  }
  return swiftFiles
}

// MARK: - Main Generation Logic

let swiftFiles = findSwiftFiles(in: sourceDir)
var allEnums: [EnumInfo] = []

for fileURL in swiftFiles {
  do {
    let source = try String(contentsOf: fileURL, encoding: .utf8)
    let sourceFile = Parser.parse(source: source)
    let visitor = EnumVisitor(viewMode: .sourceAccurate)
    visitor.walk(sourceFile)
    allEnums.append(contentsOf: visitor.enums)
  } catch {
    fputs("Warning: Failed to parse \(fileURL.path): \(error)\n", stderr)
  }
}

// MARK: - JSON Generation

if allEnums.isEmpty {
  fputs("No LDExported enums found in \(sourceDir.path)\n", stderr)
  // Create empty JSON
  let emptyJSON = "{}"
  try Data(emptyJSON.utf8).write(to: outputJSON, options: .atomic)
  exit(0)
}

// Build JSON dictionary
var jsonDict: [String: [String]] = [:]
for enumInfo in allEnums {
  jsonDict[enumInfo.ldtkName] = enumInfo.cases
}

// Encode to JSON
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let jsonData = try encoder.encode(jsonDict)

// Check if file changed to avoid unnecessary writes
if let existingData = try? Data(contentsOf: outputJSON),
   existingData == jsonData
{
  fputs("LDtk enums unchanged (\(allEnums.count) enums)\n", stderr)
} else {
  try jsonData.write(to: outputJSON, options: .atomic)
  fputs("Generated LDtk enums: \(allEnums.count) enums\n", stderr)
  for enumInfo in allEnums.sorted(by: { $0.ldtkName < $1.ldtkName }) {
    fputs("  \(enumInfo.ldtkName): \(enumInfo.cases.count) values\n", stderr)
  }
}
