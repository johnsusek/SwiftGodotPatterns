import Foundation
import SwiftGodot

// MARK: - Entity Mapping Protocol

/// Protocol for mapping LDtk entities to Godot nodes
public protocol LDEntityMapper {
  /// The LDtk entity identifier this mapper handles (e.g., "Player", "Enemy", "Item")
  var entityIdentifier: String { get }

  /// Create and configure a Godot node from an LDtk entity instance
  /// - Parameters:
  ///   - entity: The LDtk entity instance to map
  ///   - level: The level containing this entity (for context)
  /// - Returns: A configured Godot node, or nil to skip spawning
  func createNode(from entity: LDEntity, level: LDLevel) -> Node2D?
}

// MARK: - Closure-Based Mapper

/// Convenience mapper that uses a closure instead of subclassing
public struct LDClosureEntityMapper: LDEntityMapper {
  public let entityIdentifier: String

  private let builder: (LDEntity, LDLevel) -> Node2D?

  /// Create a mapper with a closure
  /// - Parameters:
  ///   - identifier: The entity identifier to handle
  ///   - builder: Closure that creates the node
  public init(identifier: String, builder: @escaping (LDEntity, LDLevel) -> Node2D?) {
    entityIdentifier = identifier
    self.builder = builder
  }

  public func createNode(from entity: LDEntity, level: LDLevel) -> Node2D? {
    return builder(entity, level)
  }
}

// MARK: - Entity Mapper Registry

/// Registry for entity mappers
public class LDEntityMapperRegistry {
  /// Shared singleton registry
  public nonisolated(unsafe) static let shared = LDEntityMapperRegistry()

  /// Registered mappers by entity identifier
  private var mappers: [String: LDEntityMapper] = [:]

  /// Default mapper used when no specific mapper is registered
  public var defaultMapper: LDEntityMapper?

  public init() {}

  /// Register a mapper for an entity type
  /// - Parameter mapper: The mapper to register
  public func register(_ mapper: LDEntityMapper) {
    mappers[mapper.entityIdentifier] = mapper
  }

  /// Register a closure-based mapper
  /// - Parameters:
  ///   - identifier: Entity identifier to handle
  ///   - builder: Closure that creates the node
  public func register(identifier: String, builder: @escaping (LDEntity, LDLevel) -> Node2D?) {
    let mapper = LDClosureEntityMapper(identifier: identifier, builder: builder)
    register(mapper)
  }

  /// Unregister a mapper for an entity type
  /// - Parameter identifier: The entity identifier
  public func unregister(_ identifier: String) {
    mappers.removeValue(forKey: identifier)
  }

  /// Clear all registered mappers
  public func clearAll() {
    mappers.removeAll()
    defaultMapper = nil
  }

  /// Get the mapper for an entity identifier
  /// - Parameter identifier: The entity identifier
  /// - Returns: The registered mapper, default mapper, or nil
  public func mapper(for identifier: String) -> LDEntityMapper? {
    return mappers[identifier] ?? defaultMapper
  }

  /// Check if a mapper is registered for an entity
  /// - Parameter identifier: The entity identifier
  /// - Returns: True if a specific mapper is registered
  public func hasMapper(for identifier: String) -> Bool {
    return mappers[identifier] != nil
  }
}

// MARK: - Default Entity Marker

/// Default mapper that creates a simple marker node with metadata
public struct LDDefaultEntityMapper: LDEntityMapper {
  public let entityIdentifier: String = "*"

  public init() {}

  public func createNode(from entity: LDEntity, level _: LDLevel) -> Node2D? {
    let node = Node2D()
    node.name = StringName(entity.identifier)
    node.position = entity.position

    // Store entity data as metadata for later processing
    node.setMeta(name: "ldtk_entity_iid", value: Variant(entity.iid))
    node.setMeta(name: "ldtk_entity_identifier", value: Variant(entity.identifier))

    // Store all fields as metadata
    for field in entity.fieldInstances {
      let metaKey = StringName("ldtk_field_\(field.identifier)")

      // Convert field value to Variant
      if let intValue = field.value.asInt() {
        node.setMeta(name: metaKey, value: Variant(intValue))
      } else if let floatValue = field.value.asFloat() {
        node.setMeta(name: metaKey, value: Variant(floatValue))
      } else if let boolValue = field.value.asBool() {
        node.setMeta(name: metaKey, value: Variant(boolValue))
      } else if let stringValue = field.value.asString() {
        node.setMeta(name: metaKey, value: Variant(stringValue))
      } else if let vector = field.value.asVector2() {
        node.setMeta(name: metaKey, value: Variant(vector))
      } else if let color = field.value.asColor() {
        node.setMeta(name: metaKey, value: Variant(color))
      }
    }

    return node
  }
}
