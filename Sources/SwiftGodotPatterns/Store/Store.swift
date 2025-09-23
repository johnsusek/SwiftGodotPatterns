import Foundation
import SwiftGodot

/// Hooks that run before and after a store pump cycle.
///
/// Use middleware to log, profile, enforce invariants, or emit analytics
/// around a single call to ``Store/pump()`` or ``Store/commit(_:)``.
/// The `before` closure observes the *snapshot* of intents and the current model
/// prior to systems running. The `after` closure observes the same snapshot,
/// the mutated model, and the batch of events produced by systems.
///
/// Middleware are invoked in the order they were added via ``Store/use(_:)``.
public struct StoreMiddleware<M, I, E> {
  /// Called immediately before systems run for a given cycle.
  /// - Parameters:
  ///   - intents: Immutable snapshot of intents for this cycle.
  ///   - model: Current model *before* mutation.
  public var before: (([I], M) -> Void)?

  /// Called after systems finish for a given cycle.
  /// - Parameters:
  ///   - intents: The same snapshot passed to `before`.
  ///   - model: Model *after* mutation by systems.
  ///   - events: Events emitted during this cycle (may be empty).
  public var after: (([I], M, [E]) -> Void)?

  /// Creates middleware with optional hooks.
  public init(before: (([I], M) -> Void)? = nil, after: (([I], M, [E]) -> Void)? = nil) {
    self.before = before
    self.after = after
  }
}

/// A minimal unidirectional data-flow store for games and simulations.
///
/// `Store` coordinates three things:
/// * **Intents** (`I`) you enqueue via ``push(_:)``/``commit(_:)``
/// * **Systems** that consume the intents, mutate the **model** (`M`), and emit **events** (`E`)
/// * An **event hub** that publishes each event and the final batch
///
/// Systems are registered in order with ``register(_:)`` and must conform to your
/// `GameSystem<M, I, E>` API (expected to implement something like `apply(_:inout M:inout [E])`).
public final class Store<M, I, E> {
  /// The authoritative state mutated by systems during a pump.
  public private(set) var model: M

  private var intents: [I] = []
  private var systems: [GameSystem<M, I, E>] = []
  private var middlewares: [StoreMiddleware<M, I, E>] = []

  /// The event hub used to publish system outputs.
  ///
  /// If `bus` is not provided at init, a type-scoped global hub is resolved via
  /// `GlobalEventBuses.hub(E.self)`.
  public let events: EventHub<E>

  /// Creates a store with an initial model and optional event hub.
  /// - Parameters:
  ///   - model: Initial state value.
  ///   - bus: Event hub; defaults to a shared hub for `E`.
  public init(model: M, bus: EventHub<E>? = nil) {
    self.model = model
    events = bus ?? GlobalEventBuses.hub(E.self)
  }

  /// Registers a system to run during pumps. Systems execute in registration order.
  public func register(_ s: GameSystem<M, I, E>) { systems.append(s) }

  /// Installs a middleware. Middleware run in the order they are added.
  public func use(_ mw: StoreMiddleware<M, I, E>) { middlewares.append(mw) }

  /// Enqueues an intent to be applied on the next pump.
  public func push(_ i: I) { intents.append(i) }

  /// Enqueues an intent and immediately runs a pump.
  public func commit(_ i: I) {
    intents.append(i)
    pump()
  }

  /// Runs one processing cycle:
  /// snapshots intents, clears the queue, invokes middleware and systems,
  /// publishes events individually *and* as a batch, then calls `after` middleware.
  public func pump() {
    if intents.isEmpty, systems.isEmpty { return }
    let snapshot = intents
    intents.removeAll()

    for m in middlewares {
      m.before?(snapshot, model)
    }

    var batch: [E] = []
    for s in systems {
      s.apply(snapshot, &model, &batch)
    }

    if !batch.isEmpty {
      for e in batch {
        events.publish(e)
      }
      events.publish(batch)
    }

    for m in middlewares {
      m.after?(snapshot, model, batch)
    }
  }
}
