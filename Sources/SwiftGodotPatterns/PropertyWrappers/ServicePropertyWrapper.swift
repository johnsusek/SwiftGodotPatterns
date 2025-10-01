import SwiftGodot

/// Resolves a service from a `ServiceLocator` as an `EventBus<E>`.
///
/// This is a convenience wrapper for dependency retrieval.
///
/// ### Example
/// ```swift
/// enum GameEvent { case playerDied, score(Int) }
///
/// final class ScoreView: Node {
///   @Service<GameEvent> var events: EventBus<GameEvent>?
///
///   override func _ready() {
///     bindProps()
///     events?.subscribe(self) { [weak self] evt in
///       switch evt {
///       case .score(let s): self?.updateLabel(s)
///       default: break
///       }
///     }
///   }
///   private func updateLabel(_ value: Int) { /* ... */ }
/// }
/// ```
@propertyWrapper
final class Service<E>: _AutoBindProp {
  private var bus: EventBus<E>?

  var wrappedValue: EventBus<E>? { bus }
  var projectedValue: EventBus<E>? { bus }

  func _bind(host _: Node) {
    bus = ServiceLocator.resolve(E.self)
  }
}
