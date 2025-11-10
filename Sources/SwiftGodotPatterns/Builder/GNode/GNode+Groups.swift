import SwiftGodot

public extension GNode {
  /// Grouping operations for `GNode` instances.
  func group(_ name: StringName, persistent: Bool = false) -> Self {
    var s = self
    s.ops.append { $0.addToGroup(name, persistent: persistent) }
    return s
  }

  /// Adds this node to a group.
  func group(_ name: String, persistent: Bool = false) -> Self {
    group(StringName(name), persistent: persistent)
  }

  /// Adds this node to multiple groups.
  func groups<S: Sequence>(_ names: S, persistent: Bool = false) -> Self where S.Element == StringName {
    var s = self
    s.ops.append { n in for g in names {
      n.addToGroup(g, persistent: persistent)
    } }
    return s
  }

  /// Instantiates a PackedScene and attaches it as a child.
  ///
  /// ### Usage:
  /// ```swift
  /// Node2D$().fromScene("scenes/enemy.tscn")
  /// ```
  func fromScene(_ path: String, configure: ((Node) -> Void)? = nil) -> Self {
    withResource(path, as: PackedScene.self) { host, scene in
      guard let child = scene.instantiate() else { return }
      configure?(child)
      host.addChild(node: child)
    }
  }
}
