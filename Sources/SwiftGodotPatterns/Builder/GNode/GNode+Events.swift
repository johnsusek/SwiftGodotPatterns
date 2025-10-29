import SwiftGodot

/// Builder conveniences for wiring `EventBus` traffic to a host `Node` via `GEventRelay`.
///
/// - Important: Ensure `GEventRelay` is registered with Godot at startup (e.g., `GodotRegistry.append(GEventRelay.self)`).
public extension GNode where T: Node {
  /// Subscribes the host node to per-event deliveries of type `E`.
  ///
  /// The handler is called for every emitted `E`, with both the host `T` and the typed event.
  func onEvent<E>(_: E.Type = E.self, _ handler: @escaping (T, E) -> Void) -> Self {
    var s = self
    s.ops.append { host in
      let relay = GEventRelay()
      relay.bus = ServiceLocator.anyBus(E.self)
      relay.each.append((Weak(host), { [weak host] any in
        guard let host, let e = any as? E else { return }
        handler(host, e)
      }))
      host.addChild(node: relay)
    }
    return s
  }

  func onEvent<E>(_: E.Type = E.self,
                  match: @escaping (E) -> Bool,
                  _ handler: @escaping (T, E) -> Void) -> Self
  {
    var s = self
    s.ops.append { host in
      let relay = GEventRelay()
      relay.bus = ServiceLocator.anyBus(E.self)
      relay.each.append((Weak(host), { [weak host] any in
        guard let host, let e = any as? E, match(e) else { return }
        handler(host, e)
      }))
      host.addChild(node: relay)
    }
    return s
  }

  /// Subscribes with a selective match that maps an `E` into an optional payload `A`.
  ///
  /// The handler runs only when `match(event)` returns a non-`nil` value, passing `(host, A)`.
  /// Use this to filter or destructure events without branching inside the handler.
  func onEvent<E, A>(_: E.Type = E.self,
                     match: @escaping (E) -> A?,
                     _ handler: @escaping (T, A) -> Void) -> Self
  {
    var s = self
    s.ops.append { host in
      let relay = GEventRelay()
      relay.bus = ServiceLocator.anyBus(E.self)
      relay.each.append((Weak(host), { [weak host] any in
        guard let host, let e = any as? E, let a = match(e) else { return }
        handler(host, a)
      }))
      host.addChild(node: relay)
    }
    return s
  }

  /// Subscribes with a selective match that extracts a pair `(A, B)` from `E`.
  ///
  /// The handler runs only when `match(event)` returns a non-`nil` tuple, passing `(host, A, B)`.
  func onEvent<E, A, B>(_: E.Type = E.self,
                        match: @escaping (E) -> (A, B)?,
                        _ handler: @escaping (T, A, B) -> Void) -> Self
  {
    var s = self
    s.ops.append { host in
      let relay = GEventRelay()
      relay.bus = ServiceLocator.anyBus(E.self)
      relay.each.append((Weak(host), { [weak host] any in
        guard let host, let e = any as? E, let t = match(e) else { return }
        handler(host, t.0, t.1)
      }))
      host.addChild(node: relay)
    }
    return s
  }
}
