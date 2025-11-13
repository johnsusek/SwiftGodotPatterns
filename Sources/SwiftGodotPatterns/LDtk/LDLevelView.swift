import Foundation
import SwiftGodot

/// A declarative view that loads and renders an LDtk level.
///
/// ### Basic Usage:
/// ```swift
/// LDLevelView(project, level: "Level_0")
/// ```
///
/// ### With Configuration:
/// ```swift
/// LDLevelView(project, level: "Level_0")
///   .generateCollision(values: [1, 2])
///   .zIndexOffset(10)
/// ```
///
/// ### With Entity Mappers:
/// ```swift
/// LDLevelView(project, level: "Level_0")
///   .onSpawn("Player") { entity, level in
///     CharacterBody2D$ {
///       Sprite2D$().res(\.texture, "player.png")
///     }
///     .position(entity.position)
///   }
/// ```
public struct LDLevelView: GView {
  /// Pre-loaded project instance
  private let project: LDProject

  /// Level identifier to load
  private let levelIdentifier: String

  /// Build configuration
  private var config: LDLevelBuildConfig

  /// Local entity mappers (registered for this level only)
  private var localMappers: [String: LDEntityMapper] = [:]

  /// Whether to use global registry or only local mappers
  private var useGlobalRegistry: Bool = true

  /// Initialize with a pre-loaded project
  /// - Parameters:
  ///   - project: Pre-loaded LDProject (must have been loaded via LDProject.load())
  ///   - level: Level identifier to build
  public init(_ project: LDProject, level levelIdentifier: String) {
    self.project = project
    self.levelIdentifier = levelIdentifier
    config = LDLevelBuildConfig()
  }

  public func toNode() -> Node {
    // Create level builder with pre-loaded project
    let levelBuilder = LDLevelBuilder(project: project)

    // Create a mutable copy of config for local modifications
    var buildConfig = config

    // Set up entity mappers if we have local mappers
    if !localMappers.isEmpty {
      // Use global registry as base if enabled
      if useGlobalRegistry {
        buildConfig.entityConfig.registry = LDEntityMapperRegistry.shared
      }

      // Register local mappers on top
      for (_, mapper) in localMappers {
        buildConfig.entityConfig.registry.register(mapper)
      }
    }

    // Build the level
    guard let levelNode = levelBuilder.buildLevel(identifier: levelIdentifier, config: buildConfig) else {
      GD.printErr("Failed to build LDtk level: \(levelIdentifier)")
      return Node2D()
    }

    return levelNode
  }

  // MARK: - Configuration Modifiers

  /// Explicitly enable or disable entity spawning.
  /// Note: Entity spawning is enabled by default. Use `.spawnEntities(false)` to disable.
  public func spawnEntities(_ enabled: Bool = true) -> Self {
    var view = self
    view.config.spawnEntities = enabled
    return view
  }

  /// Set z-index offset for layers.
  public func zIndexOffset(_ offset: Int32) -> Self {
    var view = self
    view.config.zIndexOffset = offset
    return view
  }

  /// Create marker nodes for unmapped entities.
  public func createEntityMarkers(_ enabled: Bool = true) -> Self {
    var view = self
    view.config.entityConfig.createMarkersForUnmapped = enabled
    return view
  }

  /// Set entity z-index offset.
  public func entityZIndexOffset(_ offset: Int32) -> Self {
    var view = self
    view.config.entityConfig.zIndexOffset = offset
    return view
  }

  /// Add an entity filter to control which entities are spawned.
  public func entityFilter(_ filter: @escaping (LDEntity) -> Bool) -> Self {
    var view = self
    view.config.entityConfig.entityFilter = filter
    return view
  }

  /// Add a post-processor for spawned entity nodes.
  public func onSpawned(_ processor: @escaping (Node2D, LDEntity) -> Void) -> Self {
    var view = self
    view.config.entityConfig.onSpawned = processor
    return view
  }

  /// Add custom layer processor.
  public func onLayer(_ processor: @escaping (LDLayerInstance) -> Node?) -> Self {
    var view = self
    view.config.onLayer = processor
    return view
  }

  // MARK: - Entity Mapper Registration

  /// Register an entity mapper for this level only using GView builder.
  /// - Parameters:
  ///   - identifier: Entity identifier to map
  ///   - builder: Closure that creates a GView for the entity with access to the project
  public func onSpawn(_ identifier: String, builder: @escaping (LDEntity, LDLevel, LDProject) -> any GView) -> Self {
    var view = self

    // Capture the project instance
    let capturedProject = project

    let mapper = LDClosureEntityMapper(identifier: identifier) { entity, level in
      let gView = builder(entity, level, capturedProject)
      let node = gView.toNode()

      guard let node2D = node as? Node2D else {
        GD.printErr("Entity mapper for '\(identifier)' must return a Node2D")
        return nil
      }

      return node2D
    }

    view.localMappers[identifier] = mapper
    return view
  }

  /// Register an entity mapper using a closure that directly creates a Node2D.
  /// - Parameters:
  ///   - identifier: Entity identifier to map
  ///   - builder: Closure that creates a Node2D with access to the project
  public func onSpawn(_ identifier: String, builder: @escaping (LDEntity, LDLevel, LDProject) -> Node2D?) -> Self {
    var view = self

    // Capture the project instance
    let capturedProject = project

    let mapper = LDClosureEntityMapper(identifier: identifier) { entity, level in
      builder(entity, level, capturedProject)
    }

    view.localMappers[identifier] = mapper
    return view
  }

  /// Use only local entity mappers (don't use global registry).
  public func useOnlyLocalMappers() -> Self {
    var view = self
    view.useGlobalRegistry = false
    return view
  }
}

// MARK: - Global Entity Mapper Registration

/// Register entity mappers globally using declarative syntax.
///
/// ### Usage:
/// ```swift
/// LDMappers {
///   LDMapper("Player") { entity, level in
///     CharacterBody2D$ {
///       Sprite2D$().res(\.texture, "player.png")
///     }
///     .position(entity.position)
///   }
///
///   LDMapper("Enemy") { entity, level in
///     Area2D$ {
///       Sprite2D$().res(\.texture, "enemy.png")
///     }
///     .position(entity.position)
///   }
/// }
/// ```
public struct LDMappers {
  public init(@EntityMapperBuilder _ mappers: () -> [LDEntityMapper]) {
    let registry = LDEntityMapperRegistry.shared
    for mapper in mappers() {
      registry.register(mapper)
    }
  }
}

/// A declarative entity mapper registration (global).
/// Note: For project-specific entity mappers with access to LDProject,
/// use the .onSpawn() method on LDLevelView instead.
public struct LDMapper {
  /// Register a mapper using GView builder syntax.
  /// The builder receives entity and level, but no project access.
  public init(_ identifier: String, builder: @escaping (LDEntity, LDLevel) -> any GView) {
    let mapper = LDClosureEntityMapper(identifier: identifier) { entity, level in
      let gView = builder(entity, level)
      let node = gView.toNode()

      guard let node2D = node as? Node2D else {
        GD.printErr("Entity mapper for '\(identifier)' must return a Node2D")
        return nil
      }

      return node2D
    }

    LDEntityMapperRegistry.shared.register(mapper)
  }

  /// Register a mapper using direct Node2D creation.
  /// The builder receives entity and level, but no project access.
  public init(_ identifier: String, builder: @escaping (LDEntity, LDLevel) -> Node2D?) {
    let mapper = LDClosureEntityMapper(identifier: identifier, builder: builder)
    LDEntityMapperRegistry.shared.register(mapper)
  }
}

// MARK: - Result Builder for Entity Mappers

@resultBuilder
public enum EntityMapperBuilder {
  public static func buildBlock(_ mappers: [LDEntityMapper]...) -> [LDEntityMapper] {
    mappers.flatMap { $0 }
  }

  public static func buildArray(_ mappers: [[LDEntityMapper]]) -> [LDEntityMapper] {
    mappers.flatMap { $0 }
  }

  public static func buildOptional(_ mapper: [LDEntityMapper]?) -> [LDEntityMapper] {
    mapper ?? []
  }

  public static func buildEither(first: [LDEntityMapper]) -> [LDEntityMapper] {
    first
  }

  public static func buildEither(second: [LDEntityMapper]) -> [LDEntityMapper] {
    second
  }

  public static func buildExpression(_ mapper: LDEntityMapper) -> [LDEntityMapper] {
    [mapper]
  }

  public static func buildExpression(_ mappers: [LDEntityMapper]) -> [LDEntityMapper] {
    mappers
  }
}

// Make LDMapper conform to LDEntityMapper for result builder
extension LDMapper: LDEntityMapper {
  public var entityIdentifier: String { "" }

  public func createNode(from _: LDEntity, level _: LDLevel) -> Node2D? {
    // This is never called - LDMapper is just for registration syntax
    return nil
  }
}
