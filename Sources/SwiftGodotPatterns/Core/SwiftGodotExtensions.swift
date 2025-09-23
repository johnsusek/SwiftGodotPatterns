import SwiftGodot

/// Convenience extensions for Godot types.

public extension Vector2 {
  /// Convenience initializer.
  init(_ x: Float, _ y: Float) {
    self.init(x: x, y: y)
  }

  @inlinable static func + (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
  @inlinable static func - (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }

  @inlinable static func * (lhs: Self, rhs: Float) -> Self { Self(x: lhs.x * rhs, y: lhs.y * rhs) }
  @inlinable static func * (lhs: Float, rhs: Self) -> Self { rhs * lhs }

  @inlinable static func * <S: BinaryFloatingPoint>(lhs: Self, rhs: S) -> Self { Self(x: lhs.x * Float(rhs), y: lhs.y * Float(rhs)) }
  @inlinable static func * <S: BinaryFloatingPoint>(lhs: S, rhs: Self) -> Self { rhs * lhs }

  @inlinable static func * <S: BinaryInteger>(lhs: Self, rhs: S) -> Self { lhs * Float(rhs) }
  @inlinable static func * <S: BinaryInteger>(lhs: S, rhs: Self) -> Self { rhs * lhs }

  @inlinable static func += (lhs: inout Self, rhs: Self) { lhs = lhs + rhs }
  @inlinable static func -= (lhs: inout Self, rhs: Self) { lhs = lhs - rhs }
  @inlinable static func *= (lhs: inout Self, rhs: Float) { lhs = lhs * rhs }
  @inlinable static func *= <S: BinaryFloatingPoint>(lhs: inout Self, rhs: S) { lhs = lhs * rhs }
  @inlinable static func *= <S: BinaryInteger>(lhs: inout Self, rhs: S) { lhs = lhs * rhs }
}

public extension Node {
  /// Typed group lookup; returns [] if no tree or group is empty.
  func nodes<T: Node>(inGroup name: StringName, as _: T.Type = T.self) -> [T] {
    guard let arr = getTree()?.getNodesInGroup(name) else { return [] }
    return arr.compactMap { $0 as? T }
  }

  var visibleSize: Vector2 { getViewport()?.getVisibleRect().size ?? Vector2(0, 0) }

  var visibleCenter: Vector2 { let s = visibleSize; return Vector2(x: s.x * 0.5, y: s.y * 0.5) }

  /// Node lookup by string path; returns nil if not found.
  func getNode(_ path: String) -> Node? { getNode(path: NodePath(path)) }

  /// Typed node lookup by string path; returns nil if not found or wrong type.
  ///
  /// Example:
  ///
  /// ```swift
  /// let box: ColorRect = getNode("Box")
  /// ```
  ///
  /// Replaces:
  ///
  /// ```swift
  /// let box = self.getNode(path: NodePath("Box")) as? ColorRect
  /// ```
  func getNode<T: Node>(_ path: String) -> T? { getNode(path: NodePath(path)) as? T }

  /// Get all children of a specific type.
  ///
  /// Example:
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

  /// Get all parents of a specific type.
  ///
  /// Example:
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

public extension RectangleShape2D {
  /// Convenience initializer.
  convenience init(w: Float, h: Float) {
    self.init()
    size = Vector2(x: w, y: h)
  }

  convenience init(size: Vector2) {
    self.init()
    self.size = size
  }
}

public extension CircleShape2D {
  /// Convenience initializer.
  convenience init(radius: Double) {
    self.init()
    self.radius = radius
  }
}

public extension CapsuleShape2D {
  /// Convenience initializer.
  convenience init(radius: Double, height: Double) {
    self.init()
    self.radius = radius
    self.height = height
  }
}

public extension Engine {
  static func getSceneTree() -> SceneTree? {
    Engine.getMainLoop() as? SceneTree
  }

  @discardableResult
  static func onNextFrame(_ f: @escaping () -> Void) -> Bool {
    guard let tree = Engine.getMainLoop() as? SceneTree,
          let timer = tree.createTimer(timeSec: 0.0) else { return false }
    _ = timer.timeout.connect { f() }
    return true
  }
}
