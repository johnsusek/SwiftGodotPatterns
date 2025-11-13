import Foundation
import SwiftGodot

// MARK: - Entity Definition

/// Definition of an entity type in the LD project
public struct LDEntityDef: Codable {
  /// Unique identifier
  public let uid: Int

  /// User-defined identifier (e.g., "Player", "Enemy", "Coin")
  public let identifier: String

  /// Base entity color
  public let color: String

  /// Width in pixels
  public let width: Int

  /// Height in pixels
  public let height: Int

  /// Whether entity can be resized horizontally
  public let resizableX: Bool

  /// Whether entity can be resized vertically
  public let resizableY: Bool

  /// Whether entity can be placed outside level bounds
  public let allowOutOfBounds: Bool

  /// Pivot X (0-1)
  public let pivotX: Double

  /// Pivot Y (0-1)
  public let pivotY: Double

  /// Tags for organizing entities
  public let tags: [String]

  /// How the entity is rendered in the editor
  public let renderMode: LDEntityRenderMode

  /// How entity tile is rendered within bounds
  public let tileRenderMode: LDTileRenderMode

  /// Optional tile to display for this entity
  public let tileRect: LDTilesetRect?

  /// Field definitions for this entity
  public let fieldDefs: [LDFieldDef]

  /// Maximum number of instances
  public let maxCount: Int

  /// Limit scope (per layer, level, or world)
  public let limitScope: LDLimitScope

  /// Behavior when limit is reached
  public let limitBehavior: LDLimitBehavior

  /// Whether to show the entity name in editor
  public let showName: Bool

  /// Tileset UID if using tiles
  public let tilesetId: Int?

  enum CodingKeys: String, CodingKey {
    case uid
    case identifier
    case color
    case width
    case height
    case resizableX
    case resizableY
    case allowOutOfBounds
    case pivotX
    case pivotY
    case tags
    case renderMode
    case tileRenderMode
    case tileRect
    case fieldDefs
    case maxCount
    case limitScope
    case limitBehavior
    case showName
    case tilesetId
  }

  /// Get pivot as Vector2
  public var pivot: Vector2 {
    Vector2(x: Float(pivotX), y: Float(pivotY))
  }

  /// Get size as Vector2
  public var size: Vector2 {
    Vector2(x: Float(width), y: Float(height))
  }

  /// Get color as Godot Color
  public var godotColor: Color? {
    Color.fromHex(color)
  }
}

// MARK: - Entity Instance

/// An instance of an entity placed in a level
public struct LDEntity: Codable {
  /// Unique instance identifier
  public let iid: String

  /// Entity definition identifier
  public let identifier: String

  /// Reference to entity definition UID
  public let defUid: Int

  /// Pixel position in level [x, y]
  public let px: [Int]

  /// Grid position [x, y]
  public let grid: [Int]

  /// Width in pixels
  public let width: Int

  /// Height in pixels
  public let height: Int

  /// Pivot [x, y] (0-1)
  public let pivot: [Double]

  /// Smart color for this instance
  public let smartColor: String

  /// Tags from the entity definition
  public let tags: [String]

  /// Field values for this instance
  public let fieldInstances: [LDFieldInstance]

  /// Optional tile used to display this entity
  public let tile: LDTilesetRect?

  /// World X coordinate (for GridVania/Free layouts)
  public let worldX: Int?

  /// World Y coordinate (for GridVania/Free layouts)
  public let worldY: Int?

  enum CodingKeys: String, CodingKey {
    case iid
    case identifier = "__identifier"
    case defUid
    case px
    case grid = "__grid"
    case width
    case height
    case pivot = "__pivot"
    case smartColor = "__smartColor"
    case tags = "__tags"
    case fieldInstances
    case tile = "__tile"
    case worldX = "__worldX"
    case worldY = "__worldY"
  }

  /// Get position as Vector2, adjusted for entity center
  /// This is the most common use case - works perfectly with Godot's default centered sprites
  /// The position represents the center of the entity's bounding box
  public var position: Vector2 {
    let pivotOffsetX = Float(pivot[0]) * Float(width)
    let pivotOffsetY = Float(pivot[1]) * Float(height)
    let halfWidth = Float(width) / 2.0
    let halfHeight = Float(height) / 2.0
    return Vector2(
      x: Float(px[0]) - pivotOffsetX + halfWidth,
      y: Float(px[1]) - pivotOffsetY + halfHeight
    )
  }

  /// Get the raw pivot position from LD (before any adjustments)
  /// Use this if you need the exact pivot point position as stored in LD
  public var positionPivot: Vector2 {
    Vector2(x: Float(px[0]), y: Float(px[1]))
  }

  /// Get position adjusted for top-left corner
  /// Use this for non-centered sprites or when you need the top-left corner of the entity
  public var positionTopLeft: Vector2 {
    let pivotOffsetX = Float(pivot[0]) * Float(width)
    let pivotOffsetY = Float(pivot[1]) * Float(height)
    return Vector2(
      x: Float(px[0]) - pivotOffsetX,
      y: Float(px[1]) - pivotOffsetY
    )
  }

  /// Get grid position as Vector2i
  public var gridPosition: Vector2i {
    Vector2i(x: Int32(grid[0]), y: Int32(grid[1]))
  }

  /// Get pivot as Vector2
  public var pivotVector: Vector2 {
    Vector2(x: Float(pivot[0]), y: Float(pivot[1]))
  }

  /// Get size as Vector2
  public var size: Vector2 {
    Vector2(x: Float(width), y: Float(height))
  }

  /// Get world position as Vector2 (if available)
  public var worldPosition: Vector2? {
    guard let worldX = worldX, let worldY = worldY else { return nil }
    return Vector2(x: Float(worldX), y: Float(worldY))
  }

  /// Get smart color as Godot Color
  public var color: Color? {
    Color.fromHex(smartColor)
  }

  /// Get a field value by identifier
  public func field(_ identifier: String) -> LDFieldValue? {
    fieldInstances.field(identifier)
  }
}

// MARK: - Field Definition

/// Definition of a custom field
public struct LDFieldDef: Codable {
  /// Unique identifier
  public let uid: Int

  /// User-defined identifier
  public let identifier: String

  /// Human-readable type (e.g., "Int", "String", "Array<Point>")
  public let type: String

  /// Whether the value can be null
  public let canBeNull: Bool

  /// Whether the value is an array
  public let isArray: Bool

  /// Internal type identifier
  public let fieldType: String

  /// Default value
  public let defaultOverride: LDFieldValue?

  /// Minimum value (for numbers)
  public let min: Double?

  /// Maximum value (for numbers)
  public let max: Double?

  enum CodingKeys: String, CodingKey {
    case uid
    case identifier
    case type = "__type"
    case canBeNull
    case isArray
    case fieldType = "type"
    case defaultOverride
    case min
    case max
  }
}
