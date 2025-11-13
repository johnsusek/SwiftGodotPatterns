import Foundation
import SwiftGodot

// MARK: - Level Build Configuration

/// Configuration options for building LDtk levels
public struct LDLevelBuildConfig {
  /// IntGrid values that should create collision (nil = all non-zero)
  public var collisionValues: [Int]?

  /// Whether to spawn entity instances (requires registered entity mappers)
  public var spawnEntities: Bool = true

  /// Entity build configuration (used when spawnEntities is true)
  public var entityConfig: LDEntityBuildConfig = .init()

  /// Z-index offset for layers (useful for stacking multiple levels)
  public var zIndexOffset: Int32 = 0

  /// Custom layer processor - called for each layer before building
  /// Return nil to skip the layer, or a custom node to use instead
  public var onLayer: ((LDLayerInstance) -> Node?)?

  public init() {}
}

// MARK: - Level Builder

/// Builds complete Godot node hierarchies from LDtk levels
public class LDLevelBuilder {
  /// The LDtk project
  private let project: LDProject

  /// TileSet builder for creating tilesets
  private let tilesetBuilder: LDTileSetBuilder

  /// TileMap builder for creating tile layers
  private let tileMapBuilder: LDTileMapBuilder

  /// Entity builder for spawning entities
  private let entityBuilder: LDEntityBuilder

  /// Cache of built levels by identifier
  private var levelCache: [String: Node2D] = [:]

  /// Whether to use caching
  public var cachingEnabled: Bool = true

  public init(project: LDProject) {
    guard let projectPath = project.projectPath else {
      GD.printErr("LDProject must be loaded via LDProject.load() to have projectPath set")
      fatalError("LDProject.projectPath is nil")
    }

    self.project = project
    tilesetBuilder = LDTileSetBuilder(projectPath: projectPath)
    tileMapBuilder = LDTileMapBuilder(project: project, tilesetBuilder: tilesetBuilder)
    entityBuilder = LDEntityBuilder(project: project)
  }

  /// Build a level by identifier
  /// - Parameters:
  ///   - identifier: The level identifier
  ///   - config: Build configuration
  ///   - useCache: Whether to use cached level if available
  /// - Returns: Node2D containing the complete level, or nil if not found
  public func buildLevel(
    identifier: String,
    config: LDLevelBuildConfig = LDLevelBuildConfig(),
    useCache: Bool = true
  ) -> Node2D? {
    // Check cache
    if useCache, cachingEnabled, let cached = levelCache[identifier] {
      return cached
    }

    // Find the level
    guard let level = project.level(identifier) else {
      GD.printErr("Level '\(identifier)' not found in project")
      return nil
    }

    return buildLevel(level: level, config: config, useCache: useCache)
  }

  /// Build a level from a level instance
  /// - Parameters:
  ///   - level: The LDtk level instance
  ///   - config: Build configuration
  ///   - useCache: Whether to cache the result
  /// - Returns: Node2D containing the complete level
  public func buildLevel(
    level: LDLevel,
    config: LDLevelBuildConfig = LDLevelBuildConfig(),
    useCache: Bool = true
  ) -> Node2D? {
    // Check cache
    if useCache, cachingEnabled, let cached = levelCache[level.identifier] {
      return cached
    }

    // Create root node for the level
    let levelNode = Node2D()
    levelNode.name = StringName(level.identifier)
    levelNode.position = level.worldPosition

    // Add background ColorRect if requested
    if let bgColor = level.backgroundColor ?? project.defaultLevelBackgroundColor {
      let backgroundLayer = CanvasLayer()
      backgroundLayer.layer = -1

      let colorRect = ColorRect()
      colorRect.color = bgColor
      colorRect.setAnchorsAndOffsetsPreset(.fullRect)

      backgroundLayer.addChild(node: colorRect)
      levelNode.addChild(node: backgroundLayer)
    }

    // Get layer instances (in reverse order - LDtk layers are top-to-bottom, we want bottom-to-top for z-index)
    guard let layerInstances = level.layerInstances else {
      GD.printErr("Level '\(level.identifier)' has no layer instances")
      return nil
    }

    // Build layers in reverse order (bottom to top)
    // Space layers by 100 to allow entities within each layer to have their own z-ordering
    let layerZSpacing: Int32 = 100
    for (index, layerInstance) in layerInstances.reversed().enumerated() {
      // Check custom processor first
      if let customProcessor = config.onLayer {
        if let customNode = customProcessor(layerInstance) {
          customNode.name = StringName(layerInstance.identifier)
          levelNode.addChild(node: customNode)
          continue
        }
        // If custom processor returns nil, skip this layer
        continue
      }

      let zIndex = config.zIndexOffset + (Int32(index) * layerZSpacing)

      // Build based on layer type
      switch layerInstance.type {
      case .tiles, .autoLayer:
        if let tileMapLayer = tileMapBuilder.buildTileMapLayer(from: layerInstance, zIndex: zIndex) {
          levelNode.addChild(node: tileMapLayer)
        } else {
          GD.printErr("LDLevelBuilder: Failed to build TileMapLayer for '\(layerInstance.identifier)'")
        }

      case .intGrid:
        // Build visual tiles if available
        if let tileMapLayer = tileMapBuilder.buildTileMapLayer(from: layerInstance, zIndex: zIndex) {
          levelNode.addChild(node: tileMapLayer)
        }

        // Build collision if requested
        // Auto-generate group mapping
        var groupMapping = [String?: Int]()

        if let layerDef = project.defs.layer(uid: layerInstance.layerDefUid) {
          groupMapping = layerDef.buildCollisionGroupMapping()
        }

        let collisionNode = tileMapBuilder.buildCollisionLayerByGroups(
          from: layerInstance,
          groupToPhysicsLayer: groupMapping
        )

        if let collisionNode = collisionNode {
          collisionNode.zIndex = zIndex
          levelNode.addChild(node: collisionNode)
        }

      case .entities:
        // Spawn entities if enabled
        if config.spawnEntities {
          if let entityLayerNode = entityBuilder.buildEntityLayer(
            from: layerInstance,
            level: level,
            config: config.entityConfig,
            zIndex: zIndex
          ) {
            levelNode.addChild(node: entityLayerNode)
          }
        }
      }
    }

    // Cache the level
    if cachingEnabled {
      levelCache[level.identifier] = levelNode
    }

    return levelNode
  }
}
