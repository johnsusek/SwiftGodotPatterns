import SwiftGodot

public extension Node {
  /// Typed group lookup; returns [] if no tree or group is empty.
  /// - Parameter name: The group name.
  /// - Parameter as: The expected type of the nodes in the group.
  /// - Returns: An array of nodes in the group cast to the expected type.
  /// ### Usage:
  /// ```swift
  /// let dinos: [Dino] = nodes(inGroup: "dinosaurs")
  /// ```
  /// Replaces:
  /// ```swift
  /// let dinos = getTree()?.getNodesInGroup("dinosaurs").compactMap { $0 as? Dino } ?? []
  /// ```
  func getNodes<T: Node>(inGroup name: StringName, as _: T.Type = T.self) -> [T] {
    guard let arr = getTree()?.getNodesInGroup(name) else { return [] }
    return arr.compactMap { $0 as? T }
  }

  /// Get a child node of a specific type.
  ///
  /// - Returns: The node if it exists and is of the correct type, else nil.
  /// ### Usage:
  /// ```swift
  /// let sprite: Sprite2D? = getNode("Sprite")
  /// ```
  /// Replaces:
  /// ```swift
  /// let sprite = getNode("Sprite") as? Sprite2D
  /// ```
  func getNode<T: Node>(_ path: String) -> T? {
    let nodePath = NodePath(path)
    guard hasNode(path: nodePath) else { return nil }
    return getNode(path: nodePath) as? T
  }

  /// Get all children of a specific type.
  ///
  /// ### Usage:
  /// ```swift
  /// let sprites: [Sprite2D] = getChildren()
  /// ```
  /// Replaces:
  /// ```swift
  /// let sprites = getChildren().compactMap { $0 as? Sprite2D }
  /// ```
  func getChildren<T: Node>() -> [T] {
    getChildren().compactMap { $0 as? T }
  }

  /// Get the first child of a specific type.
  ////
  /// - Returns: The first child of the specified type, or nil if none found.
  /// ### Usage:
  /// ```swift
  /// let sprite: Sprite2D? = getChild()
  /// ```
  /// Replaces:
  /// ```swift
  /// let sprite = getChildren().first(where: { $0 is Sprite2D }) as? Sprite2D
  /// ```
  func getChild<C: Node>() -> C? {
    getChildren().first(where: { $0 is C }) as? C
  }

  /// Get all parents of a specific type.
  ///
  /// ### Usage:
  /// ```swift
  /// let dinoViews: [Dino] = getParents()
  /// ```
  func getParents<T: Node>() -> [T] {
    var parents: [T] = []
    var cur = getParent()
    while let p = cur {
      if let t = p as? T { parents.append(t) }
      cur = p.getParent()
    }
    return parents
  }

  // MARK: - Metadata Queries

  /// Query all children recursively that have metadata matching a key-value pair.
  ///
  /// ### Usage:
  /// ```swift
  /// // Find all nodes with metadata "type" = "coin_spawn"
  /// let coinSpawns: [Node2D] = root.queryMeta(key: "type", value: "coin_spawn")
  /// let valuable: [Node2D] = root.queryMeta(key: "value", value: 100)
  /// ```
  func queryMeta<T: Node>(
    key: String,
    value: Variant,
    as _: T.Type = T.self
  ) -> [T] {
    var results: [T] = []
    queryMetaRecursive(key: key, value: value, node: self, results: &results)
    return results
  }

  /// Query all children recursively that have string metadata matching a key-value pair.
  func queryMeta<T: Node>(
    key: String,
    value: String,
    as _: T.Type = T.self
  ) -> [T] {
    queryMeta(key: key, value: Variant(value))
  }

  /// Query all children recursively that have integer metadata matching a key-value pair.
  func queryMeta<T: Node>(
    key: String,
    value: Int,
    as _: T.Type = T.self
  ) -> [T] {
    queryMeta(key: key, value: Variant(value))
  }

  /// Query all children recursively that have boolean metadata matching a key-value pair.
  func queryMeta<T: Node>(
    key: String,
    value: Bool,
    as _: T.Type = T.self
  ) -> [T] {
    queryMeta(key: key, value: Variant(value))
  }

  /// Query all children recursively that have floating-point metadata matching a key-value pair.
  func queryMeta<T: Node>(
    key: String,
    value: Double,
    as _: T.Type = T.self
  ) -> [T] {
    queryMeta(key: key, value: Variant(value))
  }

  private func queryMetaRecursive<T: Node>(
    key: String,
    value: Variant,
    node: Node,
    results: inout [T]
  ) {
    // Check if this node matches
    let keyName = StringName(key)
    if node.hasMeta(name: keyName) {
      if let metaValue = node.getMeta(name: keyName, default: nil) {
        if metaValue == value, let typedNode = node as? T {
          results.append(typedNode)
        }
      }
    }

    // Recursively check children
    for maybeChild in node.getChildren() {
      guard let child = maybeChild else { continue }
      queryMetaRecursive(key: key, value: value, node: child, results: &results)
    }
  }

  /// Query all children recursively that have a specific metadata key (any value).
  ///
  /// ### Usage:
  /// ```swift
  /// let spawners: [Node2D] = root.queryMetaKey("spawn_point")
  /// ```
  func queryMetaKey<T: Node>(_ key: String, as _: T.Type = T.self) -> [T] {
    var results: [T] = []
    queryMetaKeyRecursive(key: key, node: self, results: &results)
    return results
  }

  private func queryMetaKeyRecursive<T: Node>(
    key: String,
    node: Node,
    results: inout [T]
  ) {
    if node.hasMeta(name: StringName(key)), let typedNode = node as? T {
      results.append(typedNode)
    }

    for maybeChild in node.getChildren() {
      guard let child = maybeChild else { continue }
      queryMetaKeyRecursive(key: key, node: child, results: &results)
    }
  }

  /// Safely get metadata value with type casting.
  ///
  /// ### Usage:
  /// ```swift
  /// let coinValue: Int? = node.getMetaValue("coin_value")
  /// let spawnType: String? = node.getMetaValue("type")
  /// ```
  func getMetaValue<T>(_ key: String) -> T? {
    let keyName = StringName(key)
    guard hasMeta(name: keyName) else { return nil }
    guard let variant = getMeta(name: keyName, default: nil) else { return nil }

    // Try common types
    if T.self == Int.self {
      return Int(variant) as? T
    } else if T.self == String.self {
      return String(variant) as? T
    } else if T.self == Double.self {
      return Double(variant) as? T
    } else if T.self == Float.self {
      return Float(variant) as? T
    } else if T.self == Bool.self {
      return Bool(variant) as? T
    } else if T.self == Vector2.self {
      return Vector2(variant) as? T
    } else if T.self == Vector3.self {
      return Vector3(variant) as? T
    }

    return nil
  }
}
