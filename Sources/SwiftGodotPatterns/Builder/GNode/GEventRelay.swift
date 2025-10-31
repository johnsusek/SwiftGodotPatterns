import SwiftGodot

/// A Godot node that bridges an `EventBus` into the scene,
/// and relays payloads to registered receivers.
@_documentation(visibility: private)
@Godot
public final class GEventRelay: Node {
  /// The type-erased event bus to subscribe to.
  ///
  /// Set this before the node enters the tree; if `nil` at `_ready`, no subscription
  /// is created. You can build an instance via ``AnyEventBus`` or
  /// ``ServiceLocator/anyBus(_:)``.
  public var bus: AnyEventBus?

  /// Per-event receivers: `(weak node, callback)`.
  ///
  /// The callback receives each payload as `Any`. Downcast to your concrete type inside.
  /// Dead nodes (`weak` value is `nil`) are skipped at dispatch time.
  var each: [(Weak<Node>, (Any) -> Void)] = []
  /// Opaque tokens returned by the bus, used to cancel on exit.
  private var tokEach: Any?

  /// Godot lifecycle hook: subscribes to the bus, if present.
  ///
  /// Subscriptions are captured weakly to avoid retaining the relay.
  override public func _ready() {
    guard let bus else { return }
    tokEach = bus.onEach { [weak self] any in self?.routeEach(any) }
  }

  /// Godot lifecycle hook: cancels subscriptions and clears receiver lists.
  override public func _exitTree() {
    if let bus, let t = tokEach { bus.cancel(t) }
    tokEach = nil
    each.removeAll()
  }

  /// Forwards a single payload to all live per-event receivers.
  ///
  /// - Parameter any: The type-erased event payload.
  private func routeEach(_ any: Any) {
    for (weakNode, call) in each {
      guard weakNode.value != nil else { continue }
      call(any)
    }
  }
}

/// Type-erased facade over `EventBus<E>`.
///
/// `AnyEventBus` hides the concrete `Event` type, exposing:
/// - ``onEach(_:)`` delivering `Any` payloads,
/// - ``cancel(_:)`` accepting the opaque token returned by registration.
///
/// Tokens are stored as `Any` but are still the underlying `EventBus<E>.Token`.
@_documentation(visibility: private)
public struct AnyEventBus {
  private let _onEach: (@escaping (Any) -> Void) -> Any
  private let _cancel: (Any) -> Void

  /// Wraps a concrete `EventBus<E>` into a type-erased bus.
  /// - Parameter bus: The strongly typed bus to wrap.
  public init<E>(_ bus: EventBus<E>) {
    _onEach = { h in bus.onEach { h($0) } }
    _cancel = { tok in if let t = tok as? EventBus<E>.Token { bus.cancel(t) } }
  }

  /// Registers a per-event subscriber receiving type-erased payloads.
  /// - Parameter f: Callback invoked synchronously on the publisher's thread.
  /// - Returns: An opaque token to pass back to ``cancel(_:)``.
  @discardableResult public func onEach(_ f: @escaping (Any) -> Void) -> Any { _onEach(f) }

  /// Cancels a prior subscription created by ``onEach(_:)``.
  /// - Parameter token: The opaque token returned during registration.
  public func cancel(_ token: Any) { _cancel(token) }
}

public extension ServiceLocator {
  /// Returns a process-wide, type-erased bus for event type `E`.
  ///
  /// This is equivalent to `AnyEventBus(resolve(E.self))` and is convenient when you only
  /// need an `AnyEventBus` to wire into a relay.
  static func anyBus<E>(_: E.Type) -> AnyEventBus { AnyEventBus(resolve(E.self)) }
}

public struct Weak<T: AnyObject> {
  public weak var value: T?
  public init(_ v: T?) { value = v }
}
