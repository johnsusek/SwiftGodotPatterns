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
final class Resource<R: SwiftGodot.Resource>: _AutoBindProp {
  private var loaded: R?
  private let path: String

  init(_ path: String) { self.path = path }

  var wrappedValue: R? { loaded }
  var projectedValue: R? { loaded }

  func _bind(host _: Node) {
    guard let resolved = ResourceLoader.load(path: path) as? R else {
      GD.pushWarning("Failed to load \(R.self) at \(path)")
      loaded = nil
      return
    }

    loaded = resolved
  }
}
