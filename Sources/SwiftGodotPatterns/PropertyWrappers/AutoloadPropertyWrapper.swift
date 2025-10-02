import SwiftGodot

/// Resolves and type-casts a node from the Autoload list by name.
///
/// ### Example
/// ```swift
/// final class Overlay: CanvasLayer {
///   @Autoload<GameState>("GameState") var gameState: GameState?
///   override func _ready() {
///     bindProps()
///     if let gs = gameState { GD.print("level: \\(gs.level)") }
///   }
/// }
/// ```
@propertyWrapper
public final class Autoload<T: Node>: _AutoBindProp {
  private var ref: T?
  private let name: String

  public init(_ name: String) { self.name = name }

  public var wrappedValue: T? { ref }
  public var projectedValue: T? { ref }

  func _bind(host _: Node) {
    let tree = Engine.getMainLoop() as? SceneTree
    ref = tree?.root?.getNode(path: NodePath("/root/\(name)")) as? T
  }
}
