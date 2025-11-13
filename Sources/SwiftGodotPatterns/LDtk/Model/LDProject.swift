import Foundation
import SwiftGodot

// MARK: - Project

/// Root structure of an LDtk project JSON file
public struct LDProject: Codable {
  /// LDtk version used to create this file
  public let jsonVersion: String

  /// Unique project identifier
  public let iid: String

  /// Project background color
  public let bgColor: String

  /// Default background color for levels
  public let defaultLevelBgColor: String

  /// Default grid size for new layers
  public let defaultGridSize: Int

  /// Default entity width
  public let defaultEntityWidth: Int

  /// Default entity height
  public let defaultEntityHeight: Int

  /// Default entity pivot X
  public let defaultPivotX: Double

  /// Default entity pivot Y
  public let defaultPivotY: Double

  /// How levels are organized (may be null for multi-world)
  public let worldLayout: LDWorldLayout?

  /// World grid width (may be null for multi-world)
  public let worldGridWidth: Int?

  /// World grid height (may be null for multi-world)
  public let worldGridHeight: Int?

  /// Default level width (may be null for multi-world)
  public let defaultLevelWidth: Int?

  /// Default level height (may be null for multi-world)
  public let defaultLevelHeight: Int?

  /// All project definitions
  public let defs: LDDefinitions

  /// All levels (empty if using multi-world mode)
  public let levels: [LDLevel]

  /// All worlds (empty if not using multi-world mode)
  public let worlds: [LDWorld]

  /// Whether levels are saved in external files
  public let externalLevels: Bool

  /// Image export mode
  public let imageExportMode: LDImageExportMode

  /// Identifier naming style
  public let identifierStyle: LDIdentifierStyle

  /// Level name pattern
  public let levelNamePattern: String

  /// Whether JSON is minified
  public let minifyJson: Bool

  /// Dummy world IID (for non-multi-world projects)
  public let dummyWorldIid: String

  /// Path to the .ldtk file (stored at load time, not part of JSON)
  /// Used to resolve relative paths for tilesets and external resources
  public var projectPath: String?

  enum CodingKeys: String, CodingKey {
    case jsonVersion
    case iid
    case bgColor
    case defaultLevelBgColor
    case defaultGridSize
    case defaultEntityWidth
    case defaultEntityHeight
    case defaultPivotX
    case defaultPivotY
    case worldLayout
    case worldGridWidth
    case worldGridHeight
    case defaultLevelWidth
    case defaultLevelHeight
    case defs
    case levels
    case worlds
    case externalLevels
    case imageExportMode
    case identifierStyle
    case levelNamePattern
    case minifyJson
    case dummyWorldIid
  }

  /// Whether this project uses multi-world mode
  public var isMultiWorld: Bool {
    !worlds.isEmpty
  }

  /// Get all levels (combines single-world and multi-world)
  public var allLevels: [LDLevel] {
    if isMultiWorld {
      return worlds.flatMap { $0.levels }
    } else {
      return levels
    }
  }

  /// Get background color as Godot Color
  public var backgroundColor: Color? {
    Color.fromHex(bgColor)
  }

  /// Get default level background color as Godot Color
  public var defaultLevelBackgroundColor: Color? {
    Color.fromHex(defaultLevelBgColor)
  }

  /// Get default entity pivot as Vector2
  public var defaultEntityPivot: Vector2 {
    Vector2(x: Float(defaultPivotX), y: Float(defaultPivotY))
  }

  /// Get level by identifier
  public func level(_ identifier: String) -> LDLevel? {
    allLevels.first(where: { $0.identifier == identifier })
  }

  /// Get level by IID
  public func level(iid: String) -> LDLevel? {
    allLevels.first(where: { $0.iid == iid })
  }

  /// Get level by UID
  public func level(uid: Int) -> LDLevel? {
    allLevels.first(where: { $0.uid == uid })
  }

  /// Get world by identifier
  public func world(_ identifier: String) -> LDWorld? {
    worlds.first(where: { $0.identifier == identifier })
  }

  /// Get world by IID
  public func world(iid: String) -> LDWorld? {
    worlds.first(where: { $0.iid == iid })
  }

  // MARK: - Collision Layer Helpers

  /// Get Godot collision layer bit flag for a collision group name
  /// Returns bit flag ready to use with Godot's collision_layer/collision_mask
  /// Returns 0 if the group doesn't exist (which means "no collision")
  /// - Parameters:
  ///   - groupName: The group name (e.g., "walls")
  ///   - level: The level to query
  ///   - layerIdentifier: The IntGrid layer identifier (uses first IntGrid layer if not specified)
  /// - Returns: Collision layer bit flag (2^N for layer N), or 0 if not found
  /// - Example: Layer 0 = 1, Layer 1 = 2, Layer 2 = 4, etc.
  public func collisionLayer(
    for groupName: String,
    in level: LDLevel,
    layer layerIdentifier: String? = nil
  ) -> UInt32 {
    let mapping: [String?: Int]

    if let layerIdentifier = layerIdentifier {
      mapping = collisionGroupMapping(forLayer: layerIdentifier, in: level)
    } else {
      mapping = collisionGroupMapping(in: level)
    }

    guard let layerIndex = mapping[groupName] else {
      return 0 // Not found = no collision layers
    }

    // Convert layer index to bit flag: layer N = 2^N
    return UInt32(1 << layerIndex)
  }

  // MARK: - Private Helpers

  /// Get collision group mapping for a specific IntGrid layer in a level
  private func collisionGroupMapping(
    forLayer layerIdentifier: String,
    in level: LDLevel
  ) -> [String?: Int] {
    guard let layerInstance = level.layer(layerIdentifier),
          let layerDef = defs.layer(uid: layerInstance.layerDefUid)
    else {
      return [:]
    }
    return layerDef.buildCollisionGroupMapping()
  }

  /// Get collision group mapping for the first IntGrid layer in a level
  private func collisionGroupMapping(in level: LDLevel) -> [String?: Int] {
    guard let firstIntGridLayer = level.intGridLayers.first else {
      return [:]
    }
    return collisionGroupMapping(forLayer: firstIntGridLayer.identifier, in: level)
  }
}

// MARK: - Loading

public extension LDProject {
  /// Load an LDtk project from a JSON file path
  /// - Parameter path: Absolute or resource path to the .ldtk file
  /// - Returns: Loaded project with projectPath set
  /// - Throws: Decoding errors or file errors
  static func load(fromPath path: String) throws -> LDProject {
    let fileAccess = FileAccess.open(path: path, flags: .read)
    guard let fileAccess = fileAccess else {
      throw LDError.fileNotFound(path)
    }

    let jsonString = fileAccess.getAsText()
    fileAccess.close()

    guard let jsonData = jsonString.data(using: .utf8) else {
      throw LDError.invalidJSON
    }

    let decoder = JSONDecoder()
    var project = try decoder.decode(LDProject.self, from: jsonData)

    // Store the path for resolving relative resource paths
    project.projectPath = path

    return project
  }

  /// Load an LDtk project from a resource path (res://)
  /// - Parameter resourcePath: Resource path like "res://levels/game.ldtk"
  /// - Returns: Loaded project with projectPath set
  /// - Throws: Decoding errors or file errors
  static func load(path resourcePath: String) throws -> LDProject {
    return try load(fromPath: resourcePath)
  }
}

// MARK: - Errors

/// Errors that can occur when loading LDtk files
public enum LDError: Error, CustomStringConvertible {
  case fileNotFound(String)
  case invalidJSON
  case externalLevelNotFound(String)
  case tilesetNotFound(String)
  case missingDefinition(String)

  public var description: String {
    switch self {
    case let .fileNotFound(path):
      return "LD file not found: \(path)"
    case .invalidJSON:
      return "Invalid JSON in LDtk file"
    case let .externalLevelNotFound(path):
      return "External level file not found: \(path)"
    case let .tilesetNotFound(path):
      return "Tileset file not found: \(path)"
    case let .missingDefinition(identifier):
      return "Definition not found: \(identifier)"
    }
  }
}
