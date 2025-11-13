import Foundation
import SwiftGodot

// MARK: - Layer Definition

/// Definition of a layer type in the project
public struct LDLayerDef: Codable {
  /// Unique identifier
  public let uid: Int

  /// User-defined identifier
  public let identifier: String

  /// Layer type
  public let type: LDLayerType

  /// Grid size in pixels
  public let gridSize: Int

  /// Display opacity (0-1)
  public let displayOpacity: Double

  /// X offset in pixels
  public let pxOffsetX: Int

  /// Y offset in pixels
  public let pxOffsetY: Int

  /// Parallax factor X (-1 to 1)
  public let parallaxFactorX: Double

  /// Parallax factor Y (-1 to 1)
  public let parallaxFactorY: Double

  /// Whether parallax scaling is enabled
  public let parallaxScaling: Bool

  /// Tileset UID (if this is a tile layer)
  public let tilesetDefUid: Int?

  /// IntGrid value definitions (for IntGrid layers)
  public let intGridValues: [LDIntGridValueDef]

  /// IntGrid value groups (for organizing collision layers)
  public let intGridValuesGroups: [LDIntGridValueGroupDef]

  enum CodingKeys: String, CodingKey {
    case uid
    case identifier
    case type = "__type"
    case gridSize
    case displayOpacity
    case pxOffsetX
    case pxOffsetY
    case parallaxFactorX
    case parallaxFactorY
    case parallaxScaling
    case tilesetDefUid
    case intGridValues
    case intGridValuesGroups
  }

  /// Get offset as Vector2
  public var offset: Vector2 {
    Vector2(x: Float(pxOffsetX), y: Float(pxOffsetY))
  }

  /// Get parallax factor as Vector2
  public var parallaxFactor: Vector2 {
    Vector2(x: Float(parallaxFactorX), y: Float(parallaxFactorY))
  }

  /// Build a mapping of group identifiers to auto-assigned physics layer indices
  /// Groups are indexed in the order they appear, with ungrouped (nil) first
  /// Returns: [groupIdentifier: physicsLayerIndex]
  public func buildCollisionGroupMapping() -> [String?: Int] {
    var mapping: [String?: Int] = [:]
    var layerIndex = 0

    // First, check if there are any ungrouped values (groupUid == 0)
    let hasUngrouped = intGridValues.contains { $0.groupUid == 0 }
    if hasUngrouped {
      mapping[nil] = layerIndex
      layerIndex += 1
    }

    // Then, map all named groups in order
    for group in intGridValuesGroups {
      mapping[group.identifier] = layerIndex
      layerIndex += 1
    }

    return mapping
  }

  /// Get collision group names in order
  /// Returns array like: [nil, "walls"] where index = physics layer
  public func collisionGroupNames() -> [String?] {
    var names: [String?] = []

    // Ungrouped first (if any)
    let hasUngrouped = intGridValues.contains { $0.groupUid == 0 }
    if hasUngrouped {
      names.append(nil)
    }

    // Named groups after
    for group in intGridValuesGroups {
      names.append(group.identifier)
    }

    return names
  }
}

// MARK: - Layer Instance

/// An instance of a layer in a level
public struct LDLayerInstance: Codable {
  /// Unique instance identifier
  public let iid: String

  /// Layer definition identifier
  public let identifier: String

  /// Layer type
  public let type: LDLayerType

  /// Grid-based width
  public let cWid: Int

  /// Grid-based height
  public let cHei: Int

  /// Grid size in pixels
  public let gridSize: Int

  /// Layer opacity (0-1)
  public let opacity: Double

  /// Total X pixel offset (includes both instance and definition offsets)
  public let pxTotalOffsetX: Int

  /// Total Y pixel offset (includes both instance and definition offsets)
  public let pxTotalOffsetY: Int

  /// Reference to layer definition UID
  public let layerDefUid: Int

  /// Reference to level ID
  public let levelId: Int

  /// Whether the layer is visible
  public let visible: Bool

  /// Tileset UID (if applicable)
  public let tilesetDefUid: Int?

  /// Relative path to tileset (if applicable)
  public let tilesetRelPath: String?

  /// Auto-layer tiles (for AutoLayer type)
  public let autoLayerTiles: [LDTile]

  /// Grid tiles (for Tiles type)
  public let gridTiles: [LDTile]

  /// Entity instances (for Entities type)
  public let entityInstances: [LDEntity]

  /// IntGrid values as CSV (for IntGrid type)
  /// Order is left to right, top to bottom. 0 = empty cell.
  public let intGridCsv: [Int]

  enum CodingKeys: String, CodingKey {
    case iid
    case identifier = "__identifier"
    case type = "__type"
    case cWid = "__cWid"
    case cHei = "__cHei"
    case gridSize = "__gridSize"
    case opacity = "__opacity"
    case pxTotalOffsetX = "__pxTotalOffsetX"
    case pxTotalOffsetY = "__pxTotalOffsetY"
    case layerDefUid
    case levelId
    case visible
    case tilesetDefUid = "__tilesetDefUid"
    case tilesetRelPath = "__tilesetRelPath"
    case autoLayerTiles
    case gridTiles
    case entityInstances
    case intGridCsv
  }

  /// Get total offset as Vector2
  public var totalOffset: Vector2 {
    Vector2(x: Float(pxTotalOffsetX), y: Float(pxTotalOffsetY))
  }

  /// Get layer size in pixels
  public var pixelSize: Vector2 {
    Vector2(x: Float(cWid * gridSize), y: Float(cHei * gridSize))
  }

  /// Get grid size as Vector2i
  public var gridSizeVector: Vector2i {
    Vector2i(x: Int32(cWid), y: Int32(cHei))
  }

  /// Get all tiles (combines auto-layer and grid tiles)
  public var allTiles: [LDTile] {
    autoLayerTiles + gridTiles
  }

  /// Get IntGrid value at grid coordinates
  public func intGridValue(x: Int, y: Int) -> Int? {
    guard x >= 0, x < cWid, y >= 0, y < cHei else { return nil }
    let index = y * cWid + x
    guard index < intGridCsv.count else { return nil }
    return intGridCsv[index]
  }

  /// Get IntGrid value at index
  public func intGridValue(at index: Int) -> Int? {
    guard index >= 0, index < intGridCsv.count else { return nil }
    return intGridCsv[index]
  }

  /// Convert grid coordinates to index
  public func gridToIndex(x: Int, y: Int) -> Int? {
    guard x >= 0, x < cWid, y >= 0, y < cHei else { return nil }
    return y * cWid + x
  }

  /// Convert index to grid coordinates
  public func indexToGrid(_ index: Int) -> (x: Int, y: Int)? {
    guard index >= 0, index < cWid * cHei else { return nil }
    return (x: index % cWid, y: index / cWid)
  }

  /// Get IntGrid as 2D array
  public var intGrid2D: [[Int]] {
    var result: [[Int]] = []
    for y in 0 ..< cHei {
      var row: [Int] = []
      for x in 0 ..< cWid {
        let index = y * cWid + x
        row.append(index < intGridCsv.count ? intGridCsv[index] : 0)
      }
      result.append(row)
    }
    return result
  }
}

// MARK: - IntGrid Value Group Definition

/// Group for organizing IntGrid values
public struct LDIntGridValueGroupDef: Codable {
  /// Unique identifier
  public let uid: Int

  /// User-defined identifier
  public let identifier: String?

  /// Optional color for the group
  public let color: String?
}

// MARK: - IntGrid Value Definition

/// Definition of an IntGrid value (color and identifier)
public struct LDIntGridValueDef: Codable {
  /// The integer value
  public let value: Int

  /// User-defined identifier
  public let identifier: String?

  /// Color for this value
  public let color: String

  /// Group UID (0 for ungrouped)
  public let groupUid: Int

  enum CodingKeys: String, CodingKey {
    case value
    case identifier
    case color
    case groupUid
  }

  /// Get color as Godot Color
  public var godotColor: Color? {
    Color.fromHex(color)
  }
}
