import Foundation
import SwiftGodot

// MARK: - TileMap Builder

/// Builds Godot TileMapLayer nodes from LDtk layer instances
public class LDTileMapBuilder {
  /// Reference to tileset builder for creating tilesets
  private let tilesetBuilder: LDTileSetBuilder

  /// Reference to the project for definitions
  private let project: LDProject

  public init(project: LDProject, tilesetBuilder: LDTileSetBuilder) {
    self.project = project
    self.tilesetBuilder = tilesetBuilder
  }

  /// Build a TileMapLayer from an LDtk layer instance
  /// - Parameters:
  ///   - layer: The LDtk layer instance
  ///   - zIndex: Optional z-index for the layer (defaults to 0)
  /// - Returns: Configured Node2D (TileMapLayer or container with multiple TileMapLayers), or nil if not a tile layer
  public func buildTileMapLayer(from layer: LDLayerInstance, zIndex: Int32 = 0) -> Node2D? {
    // Get tileset definition - if the layer has a tileset, it can render tiles
    // This includes: Tiles layers, AutoLayer layers, and IntGrid layers with auto-tiles
    guard let tilesetDefUid = layer.tilesetDefUid else {
      return nil
    }

    // Check if there are actually tiles to render
    let tiles = layer.allTiles
    if tiles.isEmpty {
      return nil
    }

    // Get or create tileset
    guard let tileSet = tilesetBuilder.getTileSet(uid: tilesetDefUid, from: project) else {
      GD.printErr("Failed to get tileset for layer \(layer.identifier)")
      return nil
    }

    guard let tilesetDef = project.defs.tileset(uid: tilesetDefUid) else {
      GD.printErr("Tileset definition not found for UID \(tilesetDefUid)")
      return nil
    }

    // Group tiles by grid coordinate to detect stacking
    var tilesByCoord: [String: [LDTile]] = [:]
    for tile in tiles {
      let coordKey = "\(tile.px[0] / layer.gridSize)_\(tile.px[1] / layer.gridSize)"
      tilesByCoord[coordKey, default: []].append(tile)
    }

    // Determine how many layers we need (max stack depth)
    let maxStackDepth = tilesByCoord.values.map { $0.count }.max() ?? 1

    if maxStackDepth == 1 {
      // Simple case: no stacked tiles, create single TileMapLayer
      let tileMapLayer = createTileMapLayer(
        name: layer.identifier,
        tileSet: tileSet,
        layer: layer,
        zIndex: zIndex
      )

      for tile in tiles {
        placeTile(tile, in: tileMapLayer, tilesetDef: tilesetDef, layerGridSize: layer.gridSize)
      }

      return tileMapLayer
    } else {
      // Complex case: stacked tiles, create multiple TileMapLayers in a container
      let stackedCoords = tilesByCoord.values.filter { $0.count > 1 }
      GD.print("LDTileMapBuilder: Layer '\(layer.identifier)' has \(stackedCoords.count) coordinates with stacked tiles (max: \(maxStackDepth))")

      let containerNode = Node2D()
      containerNode.name = StringName(layer.identifier)
      containerNode.position = layer.totalOffset

      // Create a TileMapLayer for each stack level
      for stackLevel in 0 ..< maxStackDepth {
        let subLayer = createTileMapLayer(
          name: "\(layer.identifier)_stack\(stackLevel)",
          tileSet: tileSet,
          layer: layer,
          zIndex: zIndex + Int32(stackLevel)
        )
        subLayer.position = Vector2.zero // Offset already set on container

        // Place tiles at this stack level
        for (_, tilesAtCoord) in tilesByCoord {
          if stackLevel < tilesAtCoord.count {
            let tile = tilesAtCoord[stackLevel]
            placeTile(tile, in: subLayer, tilesetDef: tilesetDef, layerGridSize: layer.gridSize)
          }
        }

        containerNode.addChild(node: subLayer)
      }

      return containerNode
    }
  }

  /// Create and configure a TileMapLayer
  private func createTileMapLayer(
    name: String,
    tileSet: TileSet,
    layer: LDLayerInstance,
    zIndex: Int32
  ) -> TileMapLayer {
    let tileMapLayer = TileMapLayer()
    tileMapLayer.name = StringName(name)
    tileMapLayer.tileSet = tileSet
    tileMapLayer.zIndex = zIndex

    // Set texture filtering to nearest for pixel art (avoids blurring and artifacts)
    tileMapLayer.textureFilter = .nearest

    // Set opacity/modulate
    if layer.opacity < 1.0 {
      let alpha = Float(layer.opacity)
      tileMapLayer.modulate = Color(r: 1.0, g: 1.0, b: 1.0, a: alpha)
    }

    // Set visibility
    tileMapLayer.visible = layer.visible

    return tileMapLayer
  }

  /// Place a single tile in the TileMapLayer
  private func placeTile(
    _ tile: LDTile,
    in tileMapLayer: TileMapLayer,
    tilesetDef: LDTilesetDef,
    layerGridSize: Int
  ) {
    // Convert pixel position to tile coordinates
    let tileCoordsX = tile.px[0] / layerGridSize
    let tileCoordsY = tile.px[1] / layerGridSize
    let tileCoords = Vector2i(x: Int32(tileCoordsX), y: Int32(tileCoordsY))

    // Convert LDtk tile ID to atlas coordinates
    let atlasCoords = LDTileSetBuilder.tileIdToAtlasCoords(
      tileId: tile.t,
      tilesWide: tilesetDef.cWid
    )

    // Set the tile
    tileMapLayer.setCell(
      coords: tileCoords,
      sourceId: Int32(tilesetDef.uid),
      atlasCoords: atlasCoords,
      alternativeTile: 0
    )

    // Handle flipping using alternative tiles
    if tile.isFlippedX || tile.isFlippedY {
      // Get or create alternative tile with flip transformation
      if let altTileId = getOrCreateFlippedAlternativeTile(
        tileSet: tileMapLayer.tileSet,
        sourceId: Int32(tilesetDef.uid),
        atlasCoords: atlasCoords,
        flipH: tile.isFlippedX,
        flipV: tile.isFlippedY
      ) {
        // Re-set the cell with the flipped alternative tile
        tileMapLayer.setCell(
          coords: tileCoords,
          sourceId: Int32(tilesetDef.uid),
          atlasCoords: atlasCoords,
          alternativeTile: altTileId
        )
      }
    }
  }

  /// Cache for alternative tile IDs by flip configuration
  /// Key format: "sourceId_x_y_flipH_flipV" -> alternativeTileId
  private var alternativeTileCache: [String: Int32] = [:]

  /// Get or create an alternative tile with the specified flip configuration
  private func getOrCreateFlippedAlternativeTile(
    tileSet: TileSet?,
    sourceId: Int32,
    atlasCoords: Vector2i,
    flipH: Bool,
    flipV: Bool
  ) -> Int32? {
    guard let tileSet = tileSet else { return nil }

    // Create cache key
    let cacheKey = "\(sourceId)_\(atlasCoords.x)_\(atlasCoords.y)_\(flipH)_\(flipV)"

    // Check cache first
    if let cachedAltId = alternativeTileCache[cacheKey] {
      return cachedAltId
    }

    // Get the atlas source
    guard let atlasSource = tileSet.getSource(sourceId: sourceId) as? TileSetAtlasSource else {
      return nil
    }

    // Create a new alternative tile
    let newAltTileId = atlasSource.createAlternativeTile(atlasCoords: atlasCoords)

    // Get the tile data for the new alternative
    if let altTileData = atlasSource.getTileData(atlasCoords: atlasCoords, alternativeTile: newAltTileId) {
      // Set flip properties
      altTileData.flipH = flipH
      altTileData.flipV = flipV
    }

    // Cache the alternative tile ID
    alternativeTileCache[cacheKey] = newAltTileId

    return newAltTileId
  }

  /// Create a simple tileset with a single tile that has collision
  private func createCollisionTileSet(gridSize: Int) -> TileSet {
    let tileSet = TileSet()
    tileSet.tileSize = Vector2i(x: Int32(gridSize), y: Int32(gridSize))

    // Add a physics layer to the tileset (required in Godot 4 before setting collision)
    tileSet.addPhysicsLayer(toPosition: -1)

    // Create a simple atlas source with one invisible tile
    let atlasSource = TileSetAtlasSource()

    // Create a minimal placeholder texture (1x1 transparent pixel)
    // In Godot 4, TileSetAtlasSource requires a texture even for collision-only tiles
    let placeholderTexture = createPlaceholderTexture(size: gridSize)
    atlasSource.texture = placeholderTexture

    atlasSource.textureRegionSize = Vector2i(x: Int32(gridSize), y: Int32(gridSize))

    // Create tile at (0,0)
    let atlasCoords = Vector2i(x: 0, y: 0)
    atlasSource.createTile(atlasCoords: atlasCoords)

    // Add the atlas source to the tileset FIRST (before setting collision data)
    tileSet.addSource(atlasSource, atlasSourceIdOverride: 0)

    // Now set collision polygon (full square)
    let tileData = atlasSource.getTileData(atlasCoords: atlasCoords, alternativeTile: 0)
    if let tileData = tileData {
      // Add collision layer 0
      let halfSize = Float(gridSize) / 2.0

      // Create a rectangle collision shape
      let polygon = PackedVector2Array()
      polygon.append(Vector2(x: -halfSize, y: -halfSize))
      polygon.append(Vector2(x: halfSize, y: -halfSize))
      polygon.append(Vector2(x: halfSize, y: halfSize))
      polygon.append(Vector2(x: -halfSize, y: halfSize))

      tileData.setCollisionPolygonsCount(layerId: 0, polygonsCount: 1)
      tileData.setCollisionPolygonPoints(layerId: 0, polygonIndex: 0, polygon: polygon)
    }

    return tileSet
  }

  /// Build collision from IntGrid using group identifiers
  /// Creates MULTIPLE TileMapLayers, one per collision group, each on its own Godot collision layer
  /// - Parameters:
  ///   - layer: The IntGrid layer
  ///   - groupToPhysicsLayer: Dictionary mapping group identifiers to physics layer indices
  ///     Example: ["walls": 1, nil: 0] maps "walls" group to layer 1, ungrouped to layer 0
  /// - Returns: Container Node2D with multiple TileMapLayers (one per group)
  public func buildCollisionLayerByGroups(
    from layer: LDLayerInstance,
    groupToPhysicsLayer: [String?: Int]
  ) -> Node2D? {
    guard layer.type == .intGrid else {
      return nil
    }

    guard let layerDef = project.defs.layer(uid: layer.layerDefUid) else {
      return nil
    }

    // Build mapping from IntGrid value -> (group name, physics layer)
    var valueToGroup: [Int: String?] = [:]
    var valueToPhysicsLayer: [Int: Int] = [:]

    for intGridValue in layerDef.intGridValues {
      // Find the group for this value
      let group = layerDef.intGridValuesGroups.first { $0.uid == intGridValue.groupUid }
      let groupIdentifier = group?.identifier

      // Map to physics layer
      if let physicsLayer = groupToPhysicsLayer[groupIdentifier] {
        valueToGroup[intGridValue.value] = groupIdentifier
        valueToPhysicsLayer[intGridValue.value] = physicsLayer
      }
    }

    // Group IntGrid values by their physics layer
    var layerGroups: [Int: (groupName: String?, values: [Int])] = [:]
    for (value, physicsLayer) in valueToPhysicsLayer {
      if layerGroups[physicsLayer] == nil {
        // valueToGroup[value] is String?? (doubly optional), flatten to String?
        let groupName: String? = valueToGroup[value] ?? nil
        let emptyValues: [Int] = []
        layerGroups[physicsLayer] = (groupName: groupName, values: emptyValues)
      }
      layerGroups[physicsLayer]!.values.append(value)
    }

    // If only one group, return a single TileMapLayer
    if layerGroups.count == 1, let (physicsLayer, groupData) = layerGroups.first {
      let tileMapLayer = buildSingleCollisionLayer(
        from: layer,
        layerDef: layerDef,
        forValues: groupData.values,
        physicsLayer: physicsLayer
      )
      return tileMapLayer
    }

    // Multiple groups: create container with one TileMapLayer per group
    let container = Node2D()
    container.name = StringName("\(layer.identifier)_Collision")
    container.position = layer.totalOffset

    for (physicsLayer, groupData) in layerGroups.sorted(by: { $0.key < $1.key }) {
      if let tileMapLayer = buildSingleCollisionLayer(
        from: layer,
        layerDef: layerDef,
        forValues: groupData.values,
        physicsLayer: physicsLayer
      ) {
        let groupName = groupData.groupName ?? "ungrouped"
        tileMapLayer.name = StringName("\(layer.identifier)_\(groupName)")
        tileMapLayer.position = Vector2.zero // Offset already on container
        container.addChild(node: tileMapLayer)
      }
    }

    return container
  }

  /// Build a single collision TileMapLayer for specific IntGrid values on one physics layer
  private func buildSingleCollisionLayer(
    from layer: LDLayerInstance,
    layerDef _: LDLayerDef,
    forValues values: [Int],
    physicsLayer: Int
  ) -> TileMapLayer? {
    // Create TileSet with collision configured for the specified Godot physics layer
    let tileSet = createSimpleCollisionTileSet(gridSize: layer.gridSize, godotCollisionLayer: physicsLayer)

    let tileMapLayer = TileMapLayer()
    tileMapLayer.tileSet = tileSet
    tileMapLayer.visible = layer.visible
    tileMapLayer.collisionEnabled = true

    // Place tiles for the specified IntGrid values
    for y in 0 ..< layer.cHei {
      for x in 0 ..< layer.cWid {
        if let value = layer.intGridValue(x: x, y: y), values.contains(value) {
          let tileCoords = Vector2i(x: Int32(x), y: Int32(y))
          tileMapLayer.setCell(
            coords: tileCoords,
            sourceId: 0,
            atlasCoords: Vector2i(x: 0, y: 0),
            alternativeTile: 0
          )
        }
      }
    }

    return tileMapLayer
  }

  /// Create a simple tileset with a single collision tile configured for a specific Godot collision layer
  /// - Parameters:
  ///   - gridSize: Size of the grid cells
  ///   - godotCollisionLayer: The Godot physics layer index (will be converted to bit flag)
  private func createSimpleCollisionTileSet(gridSize: Int, godotCollisionLayer: Int) -> TileSet {
    let tileSet = TileSet()
    tileSet.tileSize = Vector2i(x: Int32(gridSize), y: Int32(gridSize))

    // Add one physics layer to the tileset
    tileSet.addPhysicsLayer(toPosition: -1)

    // Configure which Godot collision layer this TileSet physics layer uses
    // Convert layer index to bit flag: layer N = 2^N
    let collisionBitFlag = UInt32(1 << godotCollisionLayer)
    tileSet.setPhysicsLayerCollisionLayer(layerIndex: 0, layer: collisionBitFlag)
    tileSet.setPhysicsLayerCollisionMask(layerIndex: 0, mask: 0) // Tiles don't detect collisions

    let atlasSource = TileSetAtlasSource()
    let placeholderTexture = createPlaceholderTexture(width: gridSize, height: gridSize)
    atlasSource.texture = placeholderTexture
    atlasSource.textureRegionSize = Vector2i(x: Int32(gridSize), y: Int32(gridSize))

    // Create tile at (0,0)
    let atlasCoords = Vector2i(x: 0, y: 0)
    atlasSource.createTile(atlasCoords: atlasCoords)

    tileSet.addSource(atlasSource, atlasSourceIdOverride: 0)

    // Set collision polygon on physics layer 0
    if let tileData = atlasSource.getTileData(atlasCoords: atlasCoords, alternativeTile: 0) {
      let halfSize = Float(gridSize) / 2.0
      let polygon = PackedVector2Array()
      polygon.append(Vector2(x: -halfSize, y: -halfSize))
      polygon.append(Vector2(x: halfSize, y: -halfSize))
      polygon.append(Vector2(x: halfSize, y: halfSize))
      polygon.append(Vector2(x: -halfSize, y: halfSize))

      tileData.setCollisionPolygonsCount(layerId: 0, polygonsCount: 1)
      tileData.setCollisionPolygonPoints(layerId: 0, polygonIndex: 0, polygon: polygon)
    }

    return tileSet
  }

  /// Build collision from IntGrid with custom shapes based on value
  /// - Parameters:
  ///   - layer: The IntGrid layer
  ///   - valueToLayerDef: Dictionary mapping IntGrid values to layer definition indices
  /// - Returns: TileMapLayer with collision
  private func buildCollisionLayerWithValues(
    from layer: LDLayerInstance,
    valueToLayerDef: [Int: Int] = [:]
  ) -> TileMapLayer? {
    guard layer.type == .intGrid else {
      return nil
    }

    // Get the layer definition for IntGrid value definitions
    guard let layerDef = project.defs.layer(uid: layer.layerDefUid) else {
      return nil
    }

    let tileSet = createCollisionTileSetWithValues(
      gridSize: layer.gridSize,
      intGridValues: layerDef.intGridValues,
      valueToLayerDef: valueToLayerDef
    )

    let tileMapLayer = TileMapLayer()
    tileMapLayer.name = StringName("\(layer.identifier)_Collision")
    tileMapLayer.tileSet = tileSet
    tileMapLayer.position = layer.totalOffset
    tileMapLayer.visible = layer.visible

    // Place tiles based on IntGrid values
    for y in 0 ..< layer.cHei {
      for x in 0 ..< layer.cWid {
        if let value = layer.intGridValue(x: x, y: y), value != 0 {
          let tileCoords = Vector2i(x: Int32(x), y: Int32(y))
          // Use the value as atlas coordinate to differentiate collision layers
          let atlasY = valueToLayerDef[value] ?? 0
          tileMapLayer.setCell(
            coords: tileCoords,
            sourceId: 0,
            atlasCoords: Vector2i(x: 0, y: Int32(atlasY)),
            alternativeTile: 0
          )
        }
      }
    }

    return tileMapLayer
  }

  /// Create tileset with different collision layers per IntGrid value
  private func createCollisionTileSetWithValues(
    gridSize: Int,
    intGridValues _: [LDIntGridValueDef],
    valueToLayerDef: [Int: Int]
  ) -> TileSet {
    let tileSet = TileSet()
    tileSet.tileSize = Vector2i(x: Int32(gridSize), y: Int32(gridSize))

    // Get unique layer indices to know how many physics layers we need
    let uniqueLayerIndices = Set(valueToLayerDef.values)
    let maxLayerIndex = uniqueLayerIndices.max() ?? 0

    // Add physics layers to the tileset (one for each unique layer index)
    for _ in 0 ... maxLayerIndex {
      tileSet.addPhysicsLayer(toPosition: -1)
    }

    let atlasSource = TileSetAtlasSource()

    // Create a placeholder texture tall enough for all layer tiles
    // Each tile needs gridSize height, and we need (maxLayerIndex + 1) tiles vertically
    let textureHeight = gridSize * (maxLayerIndex + 1)
    let placeholderTexture = createPlaceholderTexture(width: gridSize, height: textureHeight)
    atlasSource.texture = placeholderTexture

    atlasSource.textureRegionSize = Vector2i(x: Int32(gridSize), y: Int32(gridSize))

    let halfSize = Float(gridSize) / 2.0
    let polygon = PackedVector2Array()
    polygon.append(Vector2(x: -halfSize, y: -halfSize))
    polygon.append(Vector2(x: halfSize, y: -halfSize))
    polygon.append(Vector2(x: halfSize, y: halfSize))
    polygon.append(Vector2(x: -halfSize, y: halfSize))

    // Create tiles for each unique layer def index
    for layerIndex in uniqueLayerIndices {
      let atlasCoords = Vector2i(x: 0, y: Int32(layerIndex))
      atlasSource.createTile(atlasCoords: atlasCoords)
    }

    // Also create default tile at (0,0) for unmapped values
    if !uniqueLayerIndices.contains(0) {
      let atlasCoords = Vector2i(x: 0, y: 0)
      atlasSource.createTile(atlasCoords: atlasCoords)
    }

    // Add the atlas source to the tileset FIRST
    tileSet.addSource(atlasSource, atlasSourceIdOverride: 0)

    // Now set collision data for each tile
    for layerIndex in uniqueLayerIndices {
      let atlasCoords = Vector2i(x: 0, y: Int32(layerIndex))
      if let tileData = atlasSource.getTileData(atlasCoords: atlasCoords, alternativeTile: 0) {
        tileData.setCollisionPolygonsCount(layerId: Int32(layerIndex), polygonsCount: 1)
        tileData.setCollisionPolygonPoints(
          layerId: Int32(layerIndex),
          polygonIndex: 0,
          polygon: polygon
        )
      }
    }

    // Set collision for default tile if it exists
    if !uniqueLayerIndices.contains(0) {
      let atlasCoords = Vector2i(x: 0, y: 0)
      if let tileData = atlasSource.getTileData(atlasCoords: atlasCoords, alternativeTile: 0) {
        tileData.setCollisionPolygonsCount(layerId: 0, polygonsCount: 1)
        tileData.setCollisionPolygonPoints(layerId: 0, polygonIndex: 0, polygon: polygon)
      }
    }

    return tileSet
  }

  /// Create a minimal placeholder texture for collision-only tilesets
  private func createPlaceholderTexture(width: Int, height: Int) -> Texture2D {
    // Create a transparent image with the specified dimensions
    let image = Image.createEmpty(
      width: Int32(width),
      height: Int32(height),
      useMipmaps: false,
      format: .rgba8
    )

    // Fill with transparent pixels
    image?.fill(color: Color(r: 0, g: 0, b: 0, a: 0))

    // Create texture from image
    let texture = ImageTexture()
    if let image = image {
      texture.setImage(image)
    }

    return texture
  }

  /// Convenience overload for square textures
  private func createPlaceholderTexture(size: Int) -> Texture2D {
    return createPlaceholderTexture(width: size, height: size)
  }
}
