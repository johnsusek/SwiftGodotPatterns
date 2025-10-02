import SwiftGodot

/// Loads a Godot `Resource` of type `R` from a path during binding.
///
/// - Parameters:
///   - path: A resource path like `"res://art/icon.png"`.
///
/// ### Example
/// ```swift
/// final class Logo: Sprite2D {
///   @Resource<Texture2D>("res://icon.svg") var icon: Texture2D?
///
///   override func _ready() {
///     bindProps()
///     texture = icon
///   }
/// }
/// ```
@propertyWrapper
public final class Resource<R: SwiftGodot.Resource>: _AutoBindProp {
  private var loaded: R?
  private let path: String

  public init(_ path: String) { self.path = path }

  public var wrappedValue: R? { loaded }
  public var projectedValue: R? { loaded }

  func _bind(host _: Node) {
    if loaded != nil { return }

    guard let resolved = ResourceLoader.load(path: path) as? R else {
      GD.pushWarning("Failed to load \(R.self) at \(path)")
      loaded = nil
      return
    }

    loaded = resolved
  }
}
