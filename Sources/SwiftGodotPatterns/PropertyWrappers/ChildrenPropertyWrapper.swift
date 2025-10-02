import SwiftGodot

/// Collects child nodes of a given type into an array, optionally under a sub-path and/or recursively.
///
/// Use this when you want a typed slice of your scene subtree without manual `getChildren()` plumbing.
/// The array is populated when `bindProps()` runs.
///
/// - Parameters:
///   - path: Optional relative path under the host from which to start the search.
///   - deep: If `true`, traverses descendants recursively otherwise only direct children are considered.
///
/// ### Usage: direct children
/// ```swift
/// final class Menu: Node {
///   @Children var buttons: [Button]   // all Button children
///
///   override func _ready() {
///     bindProps()
///     for button in buttons { button.disabled = false }
///   }
/// }
/// ```
///
/// ### Usage: scoped, deep search
/// ```swift
/// final class Board: Node {
///   @Children("Cells", deep: true) var tiles: [Node2D]
///   override func _ready() { bindProps() }
/// }
/// ```
@propertyWrapper
public final class Children<T: Node>: _AutoBindProp {
  private(set) var list: [T] = []
  private let path: String?
  private let deep: Bool

  public init(_ path: String? = nil, deep: Bool = false) {
    self.path = path
    self.deep = deep
  }

  public var wrappedValue: [T] { list }

  func _bind(host: Node) {
    list.removeAll()

    func collect(from n: Node) {
      for c in n.getChildren() {
        if let t = c as? T { list.append(t) }
        if deep, let c { collect(from: c) }
      }
    }

    if let p = path, let n = host.getNode(p) {
      collect(from: n)
    } else {
      collect(from: host)
    }
  }
}

/// Resolves a single child node of a given type, optionally under a sub-path.
///
/// Use this when you want a typed reference to a specific child node without manual `getNode()` plumbing.
/// The node is populated when `bindProps()` runs.
///
/// ### Usage:
/// ```swift
/// final class Player: Node {
///   @Child("Sprite") var sprite: Sprite2D?
///
///   override func _ready() {
///     bindProps()
///     sprite?.visible = false
///   }
/// }
/// ```
@propertyWrapper
public final class Child<T: Node>: _AutoBindProp {
  private(set) var node: T?
  private let path: String?

  public init(_ path: String? = nil) {
    self.path = path
  }

  public var wrappedValue: T? { node }

  func _bind(host: Node) {
    if let p = path, let n = host.getNode(p) as? T {
      node = n
    } else if let n = host as? T {
      node = n
    }
  }
}
