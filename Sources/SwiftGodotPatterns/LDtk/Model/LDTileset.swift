import Foundation
import SwiftGodot

// MARK: - Tileset Definition

/// Definition of a tileset in the LDtk project
public struct LDTilesetDef: Codable {
  /// Unique identifier
  public let uid: Int

  /// User-defined identifier
  public let identifier: String

  /// Relative path to the tileset image file
  public let relPath: String?

  /// Image width in pixels
  public let pxWid: Int

  /// Image height in pixels
  public let pxHei: Int

  /// Grid-based width (number of tiles horizontally)
  public let cWid: Int

  /// Grid-based height (number of tiles vertically)
  public let cHei: Int

  /// Size of a single tile in pixels
  public let tileGridSize: Int

  /// Padding from image borders in pixels
  public let padding: Int

  /// Spacing between tiles in pixels
  public let spacing: Int

  /// Custom tile metadata
  public let customData: [LDTileCustomMetadata]

  /// Tags for organizing tilesets
  public let tags: [String]

  enum CodingKeys: String, CodingKey {
    case uid
    case identifier
    case relPath
    case pxWid
    case pxHei
    case cWid = "__cWid"
    case cHei = "__cHei"
    case tileGridSize
    case padding
    case spacing
    case customData
    case tags
  }

  /// Get the full resource path for the tileset image
  public func resourcePath(relativeTo projectPath: String) -> String {
    guard let relPath = relPath else { return "" }

    // LDtk uses relative paths like "../atlas/tileset.png" or "atlas/tileset.png"
    // We need to resolve these relative to the project file

    // Remove "res://" prefix if present in projectPath
    let cleanProjectPath = projectPath.replacingOccurrences(of: "res://", with: "")

    // Get the directory containing the .ldtk file
    let projectDir = (cleanProjectPath as NSString).deletingLastPathComponent

    // Append the relative path
    let fullPath = (projectDir as NSString).appendingPathComponent(relPath)

    // Normalize the path (resolve .. and .)
    let normalizedPath = (fullPath as NSString).standardizingPath

    // Ensure it starts with "res://"
    if normalizedPath.hasPrefix("res://") {
      return normalizedPath
    } else {
      return "res://\(normalizedPath)"
    }
  }
}

// MARK: - Tile Custom Metadata

/// User-defined metadata for a specific tile
public struct LDTileCustomMetadata: Codable {
  /// Tile ID in the tileset
  public let tileId: Int

  /// Custom metadata string
  public let data: String
}

// MARK: - Tile Instance

/// A single tile instance in a layer
public struct LDTile: Codable {
  /// Tile ID in the tileset
  public let t: Int

  /// Pixel coordinates in the layer [x, y]
  public let px: [Int]

  /// Source pixel coordinates in the tileset [x, y]
  public let src: [Int]

  /// Flip bits: 0=none, 1=X, 2=Y, 3=both
  public let f: Int

  /// Alpha/opacity (0-1)
  public let a: Double

  /// Internal data (for auto-layer tiles: [ruleId, coordId], for tile-layer: [coordId])
  public let d: [Int]

  /// Position as Vector2
  public var position: Vector2 {
    Vector2(x: Float(px[0]), y: Float(px[1]))
  }

  /// Source position as Vector2
  public var sourcePosition: Vector2 {
    Vector2(x: Float(src[0]), y: Float(src[1]))
  }

  /// Whether the tile is flipped horizontally
  public var isFlippedX: Bool {
    (f & 1) != 0
  }

  /// Whether the tile is flipped vertically
  public var isFlippedY: Bool {
    (f & 2) != 0
  }

  /// Get flip as Godot's flip booleans
  public var flips: (flipH: Bool, flipV: Bool) {
    (isFlippedX, isFlippedY)
  }
}

// MARK: - Tileset Rectangle

/// A custom rectangle in a tileset (used for entity tiles, etc.)
public struct LDTilesetRect: Codable {
  /// Tileset UID
  public let tilesetUid: Int

  /// X coordinate in the tileset
  public let x: Int

  /// Y coordinate in the tileset
  public let y: Int

  /// Width in pixels
  public let w: Int

  /// Height in pixels
  public let h: Int

  /// Rectangle as Rect2
  public var rect: Rect2 {
    Rect2(position: Vector2(x: Float(x), y: Float(y)), size: Vector2(x: Float(w), y: Float(h)))
  }
}
