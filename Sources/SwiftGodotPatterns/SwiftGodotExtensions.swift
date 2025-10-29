import SwiftGodot

/// Convenience extensions for Godot types.
// TODO: Put some of these into a SwiftGodot PR

public extension Vector2 {
  /// Convenience initializer.
  init(_ x: Float, _ y: Float) {
    self.init(x: x, y: y)
  }

  @inlinable static func * (lhs: Self, rhs: Float) -> Self { Self(x: lhs.x * rhs, y: lhs.y * rhs) }
  @inlinable static func * (lhs: Float, rhs: Self) -> Self { rhs * lhs }
  @inlinable static func *= (lhs: inout Self, rhs: Float) { lhs = lhs * rhs }
  @inlinable static func *= <S: BinaryFloatingPoint>(lhs: inout Self, rhs: S) { lhs = lhs * rhs }

  @inlinable static func * <S: BinaryFloatingPoint>(lhs: Self, rhs: S) -> Self { Self(x: lhs.x * Float(rhs), y: lhs.y * Float(rhs)) }
  @inlinable static func * <S: BinaryFloatingPoint>(lhs: S, rhs: Self) -> Self { rhs * lhs }

  @inlinable static func * <S: BinaryInteger>(lhs: Self, rhs: S) -> Self { lhs * Float(rhs) }
  @inlinable static func * <S: BinaryInteger>(lhs: S, rhs: Self) -> Self { rhs * lhs }

  @inlinable static func *= <S: BinaryInteger>(lhs: inout Self, rhs: S) { lhs = lhs * rhs }
}

// MARK: Sendable conformances

extension NodePath: @retroactive @unchecked Sendable {
  public func toSendable() -> String { description }
  public static func fromSendable(_ value: String) -> NodePath { NodePath(value) }
}

extension Vector2: @retroactive @unchecked Sendable {
  public func toSendable() -> (Float, Float) { (x, y) }
  public static func fromSendable(_ value: (Float, Float)) -> Vector2 { Vector2(value.0, value.1) }
}

extension Vector2i: @retroactive @unchecked Sendable {
  public func toSendable() -> (Int32, Int32) { (x, y) }
  public static func fromSendable(_ value: (Int32, Int32)) -> Vector2i { Vector2i(x: value.0, y: value.1) }
}

// MARK: Codable conformances

extension Vector2: @retroactive Codable {
  enum CodingKeys: String, CodingKey { case x, y }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(x, forKey: .x)
    try container.encode(y, forKey: .y)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let x = try container.decode(Float.self, forKey: .x)
    let y = try container.decode(Float.self, forKey: .y)
    self.init(x: x, y: y)
  }
}

// MARK: Type-safe Node lookups

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

// MARK: Convenience initializers

public extension RectangleShape2D {
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

// MARK: Engine / SceneTree extensions

public extension Engine {
  /// Get the current SceneTree, if it exists.
  /// - Returns: The current SceneTree, or nil if it doesn't exist.
  /// ### Usage:
  /// ```swift
  /// if let tree = Engine.getSceneTree() {
  ///   // do something with tree
  /// }
  /// ```
  /// Replaces:
  /// ```swift
  /// if let tree = Engine.getMainLoop() as? SceneTree {
  ///   // do something with tree
  /// }
  /// ```
  static func getSceneTree() -> SceneTree? {
    Engine.getMainLoop() as? SceneTree
  }

  /// Schedule a closure to be called on the next frame.
  /// - Parameter f: The closure to be called.
  /// - Returns: True if the timer was created successfully, else false.
  /// ### Usage:
  /// ```swift
  /// Engine.onNextFrame {
  ///   // do something on the next frame
  /// }
  /// ```
  /// Replaces:
  /// ```swift
  /// if let tree = Engine.getMainLoop() as? SceneTree,
  ///    let timer = tree.createTimer(timeSec: 0.0) {
  ///   _ = timer.timeout.connect {
  ///     // do something on the next frame
  ///   }
  @discardableResult
  static func onNextFrame(_ f: @escaping () -> Void) -> Bool {
    guard let tree = Engine.getMainLoop() as? SceneTree,
          let timer = tree.createTimer(timeSec: 0.0) else { return false }
    _ = timer.timeout.connect { f() }
    return true
  }

  /// Schedule a closure to be called on the next physics frame.
  /// - Parameter f: The closure to be called.
  /// - Returns: True if the timer was created successfully, else false.
  /// ### Usage:
  /// ```swift
  /// Engine.onNextPhysicsFrame {
  ///   // do something on the next physics frame
  /// }
  /// ```
  /// Replaces:
  /// ```swift
  /// if let tree = Engine.getMainLoop() as? SceneTree,
  ///    let timer = tree.createTimer(timeSec: 0.0, processInPhysics: true) {
  ///   _ = timer.timeout.connect {
  ///     // do something on the next physics frame
  ///   }
  /// }
  /// ```
  @discardableResult
  static func onNextPhysicsFrame(_ f: @escaping () -> Void) -> Bool {
    guard let tree = Engine.getMainLoop() as? SceneTree,
          let timer = tree.createTimer(timeSec: 0.0, processInPhysics: true) else { return false }
    _ = timer.timeout.connect { f() }
    return true
  }
}

/// Register multiple types with Godot.
/// - Parameter types: An array of types to register.
/// ### Usage:
/// ```swift
/// register(types: [MyNode.self, MyOtherNode.self])
/// ```
/// Replaces:
/// ```swift
/// register(type: MyNode.self)
/// register(type: MyOtherNode.self)
/// ```
public func register(types: [Object.Type]) {
  for t in types {
    register(type: t)
  }
}
