import Foundation
import SwiftGodot

// MARK: - Entity Build Configuration

/// Configuration for entity building
public struct LDEntityBuildConfig {
  /// The mapper registry to use (defaults to shared)
  public var registry: LDEntityMapperRegistry = .shared

  /// Whether to create default marker nodes for unmapped entities
  public var createMarkersForUnmapped: Bool = true

  /// Z-index offset for entity nodes (defaults to 11 so entities render above tile layers)
  public var zIndexOffset: Int32 = 11

  /// Optional filter - only spawn entities that pass this check
  public var entityFilter: ((LDEntity) -> Bool)?

  /// Optional post-processor - called after node creation
  public var onSpawned: ((Node2D, LDEntity) -> Void)?

  public init() {}
}

// MARK: - Entity Builder

/// Builds Godot nodes from LDtk entity instances
public class LDEntityBuilder {
  /// Reference to the project for definitions
  private let project: LDProject

  /// Default mapper for unmapped entities
  private let defaultMapper = LDDefaultEntityMapper()

  public init(project: LDProject) {
    self.project = project
  }

  /// Build entity nodes from a layer instance
  /// - Parameters:
  ///   - layer: The entity layer instance
  ///   - level: The level containing this layer
  ///   - config: Build configuration
  ///   - zIndex: Z-index for the entity layer
  /// - Returns: Node2D container with all spawned entities
  public func buildEntityLayer(
    from layer: LDLayerInstance,
    level: LDLevel,
    config: LDEntityBuildConfig = LDEntityBuildConfig(),
    zIndex: Int32 = 0
  ) -> Node2D? {
    guard layer.type == .entities else {
      GD.printErr("Layer \(layer.identifier) is not an entity layer")
      return nil
    }

    // Create container node
    let container = Node2D()
    container.name = StringName(layer.identifier)
    container.position = layer.totalOffset
    container.zIndex = zIndex

    // Process each entity
    // First entity in LDtk should be drawn on top (highest z-index)
    let totalEntities = layer.entityInstances.count
    for (index, entity) in layer.entityInstances.enumerated() {
      // Apply filter if configured
      if let filter = config.entityFilter, !filter(entity) {
        continue
      }

      // Try to spawn the entity
      if let entityNode = spawnEntity(entity, level: level, config: config) {
        // Set z-index so first entity draws on top
        // Higher z-index = drawn on top in Godot
        entityNode.zIndex += Int32(totalEntities - index)
        container.addChild(node: entityNode)
      }
    }

    return container
  }

  /// Build all entity layers from a level
  /// - Parameters:
  ///   - level: The level to process
  ///   - config: Build configuration
  ///   - zIndexBase: Base z-index for layers
  /// - Returns: Array of entity layer container nodes
  public func buildAllEntityLayers(
    from level: LDLevel,
    config: LDEntityBuildConfig = LDEntityBuildConfig(),
    zIndexBase: Int32 = 0
  ) -> [Node2D] {
    guard let layers = level.layerInstances else {
      return []
    }

    var result: [Node2D] = []

    for (index, layer) in layers.enumerated() where layer.type == .entities {
      let zIndex = zIndexBase + Int32(index)
      if let entityLayer = buildEntityLayer(from: layer, level: level, config: config, zIndex: zIndex) {
        result.append(entityLayer)
      }
    }

    return result
  }

  /// Spawn a single entity
  /// - Parameters:
  ///   - entity: The entity instance to spawn
  ///   - level: The level containing this entity
  ///   - config: Build configuration
  /// - Returns: The spawned node, or nil if not spawned
  public func spawnEntity(
    _ entity: LDEntity,
    level: LDLevel,
    config: LDEntityBuildConfig = LDEntityBuildConfig()
  ) -> Node2D? {
    // Try to get a mapper from the registry
    let mapper: LDEntityMapper?

    if let registeredMapper = config.registry.mapper(for: entity.identifier) {
      mapper = registeredMapper
    } else if config.createMarkersForUnmapped {
      mapper = defaultMapper
    } else {
      mapper = nil
    }

    guard let mapper = mapper else {
      return nil
    }

    // Create the node
    guard let node = mapper.createNode(from: entity, level: level) else {
      return nil
    }

    // Apply z-index offset
    node.zIndex = config.zIndexOffset

    // Apply post-processor if configured
    config.onSpawned?(node, entity)

    return node
  }

  /// Spawn multiple entities
  /// - Parameters:
  ///   - entities: Array of entity instances
  ///   - level: The level containing these entities
  ///   - config: Build configuration
  /// - Returns: Array of spawned nodes
  public func spawnEntities(
    _ entities: [LDEntity],
    level: LDLevel,
    config: LDEntityBuildConfig = LDEntityBuildConfig()
  ) -> [Node2D] {
    return entities.compactMap { spawnEntity($0, level: level, config: config) }
  }
}
