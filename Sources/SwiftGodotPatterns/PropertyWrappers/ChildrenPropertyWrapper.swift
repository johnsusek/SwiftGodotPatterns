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
/// ### Example: direct children
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
/// ### Example: scoped, deep search
/// ```swift
/// final class Board: Node {
///   @Children("Cells", deep: true) var tiles: [Node2D]
///   override func _ready() { bindProps() }
/// }
/// ```
@propertyWrapper
final class Children<T: Node>: _AutoBindProp {
  private(set) var list: [T] = []
  private let path: String?
  private let deep: Bool

  init(_ path: String? = nil, deep: Bool = false) {
    self.path = path
    self.deep = deep
  }

  var wrappedValue: [T] { list }

  func _bind(host: Node) {
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
