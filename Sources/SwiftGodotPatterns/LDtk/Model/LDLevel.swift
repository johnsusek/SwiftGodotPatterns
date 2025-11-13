import Foundation
import SwiftGodot

// MARK: - Level

/// A level in the LDtk project
public struct LDLevel: Codable {
  /// Unique identifier
  public let uid: Int

  /// Unique instance identifier
  public let iid: String

  /// User-defined identifier
  public let identifier: String

  /// Width in pixels
  public let pxWid: Int

  /// Height in pixels
  public let pxHei: Int

  /// World X coordinate (for GridVania/Free layouts)
  public let worldX: Int

  /// World Y coordinate (for GridVania/Free layouts)
  public let worldY: Int

  /// World depth (for stacking levels)
  public let worldDepth: Int

  /// Background color (may be null)
  public let bgColor: String?

  /// Default background color (never null)
  public let defaultBgColor: String

  /// Background image relative path
  public let bgRelPath: String?

  /// Background position mode
  public let bgPos: LDBgPos?

  /// Background position info
  public let bgPosInfo: LDLevelBgPosInfos?

  /// Background pivot X (0-1)
  public let bgPivotX: Double

  /// Background pivot Y (0-1)
  public let bgPivotY: Double

  /// Smart color for this level
  public let smartColor: String

  /// Custom field instances for this level
  public let fieldInstances: [LDFieldInstance]

  /// Layer instances (may be null if using external levels)
  public let layerInstances: [LDLayerInstance]?

  /// Neighboring level info
  public let neighbours: [LDNeighbourLevel]

  /// External relative path (if using separate level files)
  public let externalRelPath: String?

  enum CodingKeys: String, CodingKey {
    case uid
    case iid
    case identifier
    case pxWid
    case pxHei
    case worldX
    case worldY
    case worldDepth
    case bgColor
    case defaultBgColor = "__bgColor"
    case bgRelPath
    case bgPos
    case bgPosInfo = "__bgPos"
    case bgPivotX
    case bgPivotY
    case smartColor = "__smartColor"
    case fieldInstances
    case layerInstances
    case neighbours = "__neighbours"
    case externalRelPath
  }

  /// Get level size as Vector2
  public var size: Vector2 {
    Vector2(x: Float(pxWid), y: Float(pxHei))
  }

  /// Get world position as Vector2
  public var worldPosition: Vector2 {
    Vector2(x: Float(worldX), y: Float(worldY))
  }

  /// Get background color as Godot Color
  public var backgroundColor: Color? {
    if let bgColor = bgColor {
      return Color.fromHex(bgColor)
    }
    return Color.fromHex(defaultBgColor)
  }

  /// Get smart color as Godot Color
  public var color: Color? {
    Color.fromHex(smartColor)
  }

  /// Get background pivot as Vector2
  public var backgroundPivot: Vector2 {
    Vector2(x: Float(bgPivotX), y: Float(bgPivotY))
  }

  /// Get a field value by identifier
  public func field(_ identifier: String) -> LDFieldValue? {
    fieldInstances.field(identifier)
  }

  /// Get layer by identifier
  public func layer(_ identifier: String) -> LDLayerInstance? {
    layerInstances?.first(where: { $0.identifier == identifier })
  }

  /// Get all layers of a specific type
  public func layers(ofType type: LDLayerType) -> [LDLayerInstance] {
    layerInstances?.filter { $0.type == type } ?? []
  }

  /// Get all entity layers
  public var entityLayers: [LDLayerInstance] {
    layers(ofType: .entities)
  }

  /// Get all tile layers
  public var tileLayers: [LDLayerInstance] {
    layers(ofType: .tiles)
  }

  /// Get all intgrid layers
  public var intGridLayers: [LDLayerInstance] {
    layers(ofType: .intGrid)
  }

  /// Get all auto layers
  public var autoLayers: [LDLayerInstance] {
    layers(ofType: .autoLayer)
  }

  /// Get all entities from all entity layers
  public var allEntities: [LDEntity] {
    entityLayers.flatMap { $0.entityInstances }
  }

  /// Get entities by identifier
  public func entities(withIdentifier identifier: String) -> [LDEntity] {
    allEntities.filter { $0.identifier == identifier }
  }

  /// Get first entity with identifier
  public func entity(withIdentifier identifier: String) -> LDEntity? {
    allEntities.first(where: { $0.identifier == identifier })
  }
}

// MARK: - Level Background Position Info

/// Background image positioning information
public struct LDLevelBgPosInfos: Codable {
  /// Crop rectangle [x, y, width, height]
  public let cropRect: [Double]

  /// Scale [scaleX, scaleY]
  public let scale: [Double]

  /// Top-left position [x, y]
  public let topLeftPx: [Int]

  /// Get crop rect as Rect2
  public var rect: Rect2 {
    Rect2(
      position: Vector2(x: Float(cropRect[0]), y: Float(cropRect[1])),
      size: Vector2(x: Float(cropRect[2]), y: Float(cropRect[3]))
    )
  }

  /// Get scale as Vector2
  public var scaleVector: Vector2 {
    Vector2(x: Float(scale[0]), y: Float(scale[1]))
  }

  /// Get top-left position as Vector2
  public var position: Vector2 {
    Vector2(x: Float(topLeftPx[0]), y: Float(topLeftPx[1]))
  }
}

// MARK: - Neighbour Level

/// Information about a neighboring level
public struct LDNeighbourLevel: Codable {
  /// Neighbor instance identifier
  public let levelIid: String

  /// Direction: n/s/w/e or </>  (depth) or o (overlap)
  /// Since 1.5.3 can also be nw/ne/sw/se (corners)
  public let dir: String

  /// Whether neighbor is north
  public var isNorth: Bool { dir.contains("n") }

  /// Whether neighbor is south
  public var isSouth: Bool { dir.contains("s") }

  /// Whether neighbor is west
  public var isWest: Bool { dir.contains("w") }

  /// Whether neighbor is east
  public var isEast: Bool { dir.contains("e") }

  /// Whether neighbor is at lower depth
  public var isLower: Bool { dir == "<" }

  /// Whether neighbor is at greater depth
  public var isGreater: Bool { dir == ">" }

  /// Whether neighbor overlaps
  public var isOverlap: Bool { dir == "o" }
}

// MARK: - World

/// A world containing multiple levels (for multi-world projects)
public struct LDWorld: Codable {
  /// Unique instance identifier
  public let iid: String

  /// User-defined identifier
  public let identifier: String

  /// All levels in this world
  public let levels: [LDLevel]

  /// World layout type
  public let worldLayout: LDWorldLayout?

  /// World grid width in pixels
  public let worldGridWidth: Int

  /// World grid height in pixels
  public let worldGridHeight: Int

  /// Default level width
  public let defaultLevelWidth: Int

  /// Default level height
  public let defaultLevelHeight: Int

  /// Get world grid size as Vector2
  public var worldGridSize: Vector2 {
    Vector2(x: Float(worldGridWidth), y: Float(worldGridHeight))
  }

  /// Get default level size as Vector2
  public var defaultLevelSize: Vector2 {
    Vector2(x: Float(defaultLevelWidth), y: Float(defaultLevelHeight))
  }

  /// Get level by identifier
  public func level(_ identifier: String) -> LDLevel? {
    levels.first(where: { $0.identifier == identifier })
  }

  /// Get level by IID
  public func level(iid: String) -> LDLevel? {
    levels.first(where: { $0.iid == iid })
  }
}
