import SwiftGodot

/// Walks up the parent chain to find the first ancestor of type `T`.
///
/// Useful when child nodes need a reference to a typed controller/owner without hard-coding paths.
///
/// ### Example
/// ```swift
/// final class HealthBar: Node {
///   @Ancestor<Node2D> var owner2D: Node2D?
///
///   override func _ready() {
///     bindProps()
///     owner2D?.show()
///   }
/// }
/// ```
@propertyWrapper
final class Ancestor<T: Node>: _AutoBindProp {
  private var ref: T?

  var wrappedValue: T? {
    return ref
  }

  var projectedValue: T? { ref }

  func _bind(host: Node) {
    var cur = host.getParent()

    while let p = cur {
      if let t = p as? T {
        ref = t
        return
      }

      cur = p.getParent()
    }
  }
}
