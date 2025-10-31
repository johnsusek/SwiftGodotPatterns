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
  func nodes<T: Node>(inGroup name: StringName, as _: T.Type = T.self) -> [T] {
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
}
