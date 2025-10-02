import SwiftGodot

/// Queries nodes by Godot group membership at bind time, returning a typed array.
///
/// Use this to get all nodes in one or more groups across the active `SceneTree`.
/// Results are the union of all provided groups and are de-duplicated. The list
/// is captured when `bindProps()` runs; call `$property()` to refresh on demand.
///
/// ### Examples
/// ```swift
/// final class EnemyHUD: Node {
///   // All enemies anywhere in the tree, typed:
///   @Group("enemies") var enemies: [CharacterBody2D]
///
///   // Union of multiple groups:
///   @Group(["interactables", "doors"]) var interactables: [Node]
///
///   override func _ready() {
///     bindProps()
///     // Use immediately:
///     enemies.forEach { _ = $0.isVisibleInTree() }
///
///     // Refresh later if the scene composition changes:
///     let current = $enemies()  // re-queries and returns the fresh list
///     GD.print("Enemy count: \(current.count)")
///   }
/// }
/// ```
@propertyWrapper
public final class Group<T: Node>: _AutoBindProp {
  private let names: [StringName]
  private weak var hostNode: Node?
  private var cached: [T] = []

  /// Query a single group.
  public init(_ name: String) {
    names = [StringName(name)]
  }

  /// Query the union of multiple groups.
  public init(_ names: [String]) {
    self.names = names.map { StringName($0) }
  }

  /// The last queried result. Populated by `bindProps()` and updated by `$property()`.
  public var wrappedValue: [T] { cached }

  /// Call `$property()` to refresh and *return* the latest result in one step.
  public var projectedValue: () -> [T] {
    { [weak self] in self?.refresh(); return self?.cached ?? [] }
  }

  func _bind(host: Node) {
    hostNode = host
    refresh()
  }

  private func refresh() {
    guard let tree = hostNode?.getTree() else { cached = []; return }
    var seen = Set<ObjectIdentifier>()
    var list: [T] = []

    for groupName in names {
      // Godot: SceneTree.getNodesInGroup(StringName) -> Array<Node>
      let groupNodes = tree.getNodesInGroup(groupName)
      for anyNode in groupNodes {
        guard let node = anyNode as? T else { continue }
        let identifier = ObjectIdentifier(node)
        if seen.insert(identifier).inserted { list.append(node) }
      }
    }
    cached = list
  }
}
