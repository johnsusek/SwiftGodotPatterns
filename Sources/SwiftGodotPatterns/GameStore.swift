import Foundation
import SwiftGodot

/// A store for game state management.
///
/// `GameStore` coordinates three things:
/// 1. A mutable `Model` (your game state).
/// 2. A queue of `Intent` values enqueued by gameplay/UI.
/// 3. One or more `GameSystem`s that mutate `model` and emit `Event`s.
///
/// Call ``push(_:)`` to enqueue intents, then call ``pump()`` to process the current
/// snapshot of intents through every registered system.
///
/// ``commit(_:)`` enqueues a single intent and pumps immediately.
///
/// **Note:** Avoid calling ``commit(_:)`` from inside handlers, as that re-enters ``pump()``;
/// use ``commitNextFrame(_:)`` instead.
///
/// ``commitNextFrame(_:)`` enqueues a single intent and pumps on the next frame.
///
/// ### Example
/// ```swift
/// struct World { var hp = 10 }
/// enum Intent { case hit(Int) }
/// enum Event { case damaged(Int), dead }
///
/// let store = GameStore<World, Intent, Event>(model: .init())
/// store.register { intents, model, out in
///   for intent in intents {
///     switch intent {
///     case .hit(let dmg):
///       model.hp -= dmg
///       out.append(.damaged(dmg))
///     }
///   }
///   if model.hp <= 0 { model.hp = 0; out.append(.dead) }
/// }
///
/// let token = store.events.onEach { print($0) } // subscribe
/// store.commit(.hit(3)) // applies, emits .damaged(3)
/// store.commit(.hit(20)) // applies, emits .damaged(20), .dead
/// store.events.cancel(token)
/// ```
public final class GameStore<Model, Intent, Event> {
  /// The authoritative, mutable game state. Mutated only within systems during pumps.
  public private(set) var model: Model

  private var intents: [Intent] = []
  private var systems: [GameSystem<Model, Intent, Event>] = []

  /// Public event bus used to broadcast events produced during a pump.
  public let events: EventHub<Event>

  /// Creates a store with an initial model and an optional shared event bus.
  public init(model: Model, bus: EventHub<Event>? = nil) {
    self.model = model
    events = bus ?? GlobalEventBuses.hub(Event.self)
  }

  /// Registers a reducer system that will run on every pump.
  public func register(_ system: GameSystem<Model, Intent, Event>) { systems.append(system) }

  /// Registers a reducer using a closure.
  public func register(_ apply: @escaping ([Intent], inout Model, inout [Event]) -> Void) {
    systems.append(.init(apply))
  }

  /// Enqueues an intent and processes immediately.
  public func commit(_ intent: Intent) {
    push(intent)
    pump()
  }

  /// Enqueues an intent and processes the queue on the next frame.
  public func commitNextFrame(_ intent: Intent) {
    push(intent)

    Engine.onNextFrame {
      self.pump()
    }
  }

  /// Enqueues an intent without processing. Call ``pump()`` to process accumulated intents.
  public func push(_ intent: Intent) { intents.append(intent) }

  /// Processes the current queue of intents through all registered systems.
  public func pump() {
    if intents.isEmpty, systems.isEmpty { return }

    var batch: [Event] = []
    let snapshot = intents

    intents.removeAll()

    for s in systems {
      s.apply(snapshot, &model, &batch)
    }

    if batch.isEmpty { return }

    for e in batch {
      events.publish(e)
    }

    events.publish(batch)
  }
}
