import SwiftGodot

/// Internal protocol adopted by property wrappers that support binding.
///
/// Conforming wrappers implement `._bind(host:)`, which is invoked by `Node.bindProps()`
/// to wire themselves up (resolve nodes, connect signals, schedule process loops, etc.).
@_documentation(visibility: private)
protocol _AutoBindProp: AnyObject {
  /// Performs the one-time binding against the given host node.
  ///
  /// - Important: Designed to be called once per instance (typically from `_ready()`).
  func _bind(host: Node)
}

public extension Node {
  /// Reflectively binds all `_AutoBindProp` property wrappers declared on `self` (and superclasses).
  ///
  /// Call this once from your node’s `_ready()` to activate wrappers like `@Children`, `@Group`,
  /// `@OnSignal`, `@ProcessLoop`, etc. It walks the inheritance chain to catch wrappers declared
  /// in base classes as well.
  ///
  /// - Warning: Many wrappers have side effects (e.g., adding child relays, joining groups).
  ///   Calling this multiple times on the same instance may duplicate those effects. Prefer
  ///   a single call from `_ready()`.
  func bindProps() {
    var m: Mirror? = Mirror(reflecting: self)

    while let cur = m {
      for child in cur.children {
        (child.value as? _AutoBindProp)?._bind(host: self)
      }

      m = cur.superclassMirror
    }
  }
}
