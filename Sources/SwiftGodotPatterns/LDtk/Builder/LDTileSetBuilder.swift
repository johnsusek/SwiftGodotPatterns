import Foundation
import SwiftGodot

// MARK: - TileSet Builder

/// Builds Godot TileSet resources from LD tileset definitions
public class LDTileSetBuilder {
  /// Cache of built tilesets by UID
  private var tilesetCache: [Int: TileSet] = [:]

  /// Path to the LD project file (for resolving relative paths)
  private let projectPath: String

  /// Whether to cache tilesets
  public var cachingEnabled: Bool = true

  public init(projectPath: String) {
    self.projectPath = projectPath
  }

  /// Build a TileSet from an LD tileset definition
  /// - Parameters:
  ///   - tilesetDef: The LD tileset definition
  ///   - useCache: Whether to use cached tileset if available
  /// - Returns: Configured TileSet resource
  public func buildTileSet(from tilesetDef: LDTilesetDef, useCache: Bool = true) -> TileSet? {
    // Check cache
    if useCache, cachingEnabled, let cached = tilesetCache[tilesetDef.uid] {
      return cached
    }

    // Get full path to tileset image
    let imagePath = tilesetDef.resourcePath(relativeTo: projectPath)

    // Create TileSet
    let tileSet = TileSet()

    // Set the tile size to match the tileset's grid size
    tileSet.tileSize = Vector2i(x: Int32(tilesetDef.tileGridSize), y: Int32(tilesetDef.tileGridSize))

    // Create TileSetAtlasSource
    guard let atlasSource = createAtlasSource(
      from: tilesetDef,
      imagePath: imagePath
    ) else {
      GD.printErr("Failed to create atlas source for tileset: \(tilesetDef.identifier)")
      return nil
    }

    // Add the atlas source to the tileset
    // Use the tileset UID as the source ID
    tileSet.addSource(atlasSource, atlasSourceIdOverride: Int32(tilesetDef.uid))

    // Cache it
    if cachingEnabled {
      tilesetCache[tilesetDef.uid] = tileSet
    }

    return tileSet
  }

  /// Create a TileSetAtlasSource from tileset definition
  private func createAtlasSource(from tilesetDef: LDTilesetDef, imagePath: String) -> TileSetAtlasSource? {
    // Load texture
    guard let texture = loadTexture(path: imagePath) else {
      GD.printErr("Failed to load texture: \(imagePath)")
      return nil
    }

    let atlasSource = TileSetAtlasSource()
    atlasSource.texture = texture

    // Enable texture filter mode for pixel art (nearest neighbor)
    atlasSource.textureRegionSize = Vector2i(x: Int32(tilesetDef.tileGridSize), y: Int32(tilesetDef.tileGridSize))

    // Set margins (padding) and separation
    atlasSource.margins = Vector2i(x: Int32(tilesetDef.padding), y: Int32(tilesetDef.padding))
    atlasSource.separation = Vector2i(x: Int32(tilesetDef.spacing), y: Int32(tilesetDef.spacing))

    // Create tiles for the atlas
    // LD uses a continuous tile ID system, we need to create tiles for all valid positions
    let tilesWide = tilesetDef.cWid
    let tilesHigh = tilesetDef.cHei

    for y in 0 ..< tilesHigh {
      for x in 0 ..< tilesWide {
        let atlasCoords = Vector2i(x: Int32(x), y: Int32(y))
        atlasSource.createTile(atlasCoords: atlasCoords)
      }
    }

    return atlasSource
  }

  /// Load a texture from a file path
  private func loadTexture(path: String) -> Texture2D? {
    // Try to load using Godot's ResourceLoader
    let resource = ResourceLoader.load(path: path)
    return resource as? Texture2D
  }

  /// Clear the tileset cache
  public func clearCache() {
    tilesetCache.removeAll()
  }

  /// Get or build a tileset by UID
  public func getTileSet(uid: Int, from project: LDProject) -> TileSet? {
    // Check cache first
    if cachingEnabled, let cached = tilesetCache[uid] {
      return cached
    }

    // Find the tileset definition
    guard let tilesetDef = project.defs.tileset(uid: uid) else {
      GD.printErr("Tileset with UID \(uid) not found in project")
      return nil
    }

    return buildTileSet(from: tilesetDef)
  }
}

// MARK: - Tile Coordinate Conversion

public extension LDTileSetBuilder {
  /// Convert LD tile ID to atlas coordinates
  /// - Parameters:
  ///   - tileId: The LD tile ID
  ///   - tilesWide: Number of tiles horizontally in the tileset
  /// - Returns: Atlas coordinates as Vector2i
  static func tileIdToAtlasCoords(tileId: Int, tilesWide: Int) -> Vector2i {
    let x = tileId % tilesWide
    let y = tileId / tilesWide
    return Vector2i(x: Int32(x), y: Int32(y))
  }

  /// Convert pixel coordinates to tile ID
  /// - Parameters:
  ///   - px: Pixel coordinates [x, y]
  ///   - tileSize: Size of each tile in pixels
  ///   - tilesWide: Number of tiles horizontally
  /// - Returns: Tile ID
  static func pixelCoordsToTileId(px: [Int], tileSize: Int, tilesWide: Int) -> Int {
    let tileX = px[0] / tileSize
    let tileY = px[1] / tileSize
    return tileY * tilesWide + tileX
  }
}
