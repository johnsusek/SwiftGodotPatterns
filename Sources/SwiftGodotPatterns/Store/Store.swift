import Foundation
import SwiftGodot

/// Hooks that run before and after a store pump cycle.
///
/// Use middleware to log, profile, enforce invariants, or emit analytics
/// around a single call to ``Store/pump()`` or ``Store/commit(_:)``.
/// The `before` closure observes the *snapshot* of intents and the current state
/// prior to mutators running. The `after` closure observes the same snapshot,
/// the mutated state, and the batch of events produced by mutators.
///
/// Middleware are invoked in the order they were added via ``Store/use(_:)``.
///
/// Example:
/// ```swift
/// let logger = StoreMiddleware<GameState, UserIntent, GameEvent>(
///   before: { intents, state in
///     print("Pumping with intents: \(intents) and state: \(state)")
///   },
///   after: { intents, state, events in
///     print("Finished pump. State: \(state), events: \(events)")
///   }
/// )
/// store.use(logger)
/// ```
public struct StoreMiddleware<S, I, E> {
  /// Called immediately before mutators run for a given cycle.
  /// - Parameters:
  ///   - intents: Immutable snapshot of intents for this cycle.
  ///   - state: Current state *before* mutation.
  public var before: ((S, [I]) -> Void)?

  /// Called after mutators finish for a given cycle.
  /// - Parameters:
  ///   - intents: The same snapshot passed to `before`.
  ///   - state: State *after* mutation by mutators.
  ///   - events: Events emitted during this cycle (may be empty).
  public var after: ((S, [I], [E]) -> Void)?

  /// Creates middleware with optional hooks.
  public init(before: ((S, [I]) -> Void)? = nil, after: ((S, [I], [E]) -> Void)? = nil) {
    self.before = before
    self.after = after
  }
}

/// A minimal unidirectional data-flow store for games and simulations.
///
/// `Store` coordinates three things:
/// * **Intents** (`I`) you enqueue via ``push(_:)``/``commit(_:)``
/// * **Mutators** that consume the intents, mutate the **state** (`M`), and emit **events** (`E`)
/// * An **event hub** that publishes each event and the final batch
///
/// Mutators are registered in order with ``register(_:)`` and must conform to your
/// `Mutator<M, I, E>` API (expected to implement something like `apply(_:inout M:inout [E])`).
public final class Store<S, I, E> {
  /// The authoritative state mutated by mutators during a pump.
  public var state: S

  private var intents: [I] = []
  private var mutators: [Mutator<S, I, E>] = []
  private var middlewares: [StoreMiddleware<S, I, E>] = []

  /// The event hub used to publish mutator outputs.
  ///
  /// If `bus` is not provided at init, a type-scoped global hub is resolved via
  /// `GlobalEventBuses.hub(E.self)`.
  public let events: EventHub<E>

  /// Creates a store with an initial state and optional event hub.
  /// - Parameters:
  ///   - state: Initial state value.
  ///   - bus: Event hub; defaults to a shared hub for `E`.
  public init(state: S, bus: EventHub<E>? = nil) {
    self.state = state
    events = bus ?? GlobalEventBuses.hub(E.self)
  }

  /// Registers a mutator to run during pumps. Mutators execute in registration order.
  public func register(_ s: Mutator<S, I, E>) { mutators.append(s) }

  /// Installs a middleware. Middleware run in the order they are added.
  public func use(_ mw: StoreMiddleware<S, I, E>) { middlewares.append(mw) }

  /// Enqueues an intent to be applied on the next pump.
  public func push(_ i: I) { intents.append(i) }

  /// Enqueues an intent and immediately runs a pump.
  public func commit(_ i: I) {
    intents.append(i)
    pump()
  }

  /// Enqueues multiple intents and immediately runs a pump.
  public func commitBatch(_ intents: [I]) {
    if intents.isEmpty { return }
    intents.forEach { push($0) }
    pump()
  }

  /// Runs one processing cycle:
  /// snapshots intents, clears the queue, invokes middleware and mutators,
  /// publishes events individually *and* as a batch, then calls `after` middleware.
  public func pump() {
    if intents.isEmpty, mutators.isEmpty { return }
    let snapshot = intents
    intents.removeAll()

    for m in middlewares {
      m.before?(state, snapshot)
    }

    var batch: [E] = []

    for s in mutators {
      s.apply(&state, snapshot, &batch)
    }

    if !batch.isEmpty {
      events.publish(batch)
    }

    for m in middlewares {
      m.after?(state, snapshot, batch)
    }
  }
}
