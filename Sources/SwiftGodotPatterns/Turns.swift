/// An entity that can participate in the turn system.
///
/// Conforming types should be lightweight value types or stable reference
/// types. `id` must be unique within a running `TurnScheduler`.
public protocol Actor {
  /// Stable identifier used as the scheduler key.
  var id: Int { get }

  /// Energy gained each tick. When an actor's energy reaches `100`, it acts.
  /// Typical baseline might be `100` (acts every tick); higher values act more often.
  var speed: Int { get }

  /// Called by the scheduler when this actor is ready to act.
  ///
  /// - Parameter context: Execution context for the current tick.
  func takeTurn(_ context: TurnContext)
}

/// Execution context passed to `Actor.takeTurn(_:)`.
public struct TurnContext {
  /// Current tick count (monotonic, starting from 1 on first `tick()`).
  public let now: Int

  /// Invokes another actor's `takeTurn(_:)` using the same context.
  ///
  /// This is a convenience to chain actions within the same tick.
  /// Avoid infinite recursion: use with care.
  public let act: (Actor) -> Void
}

/// Discrete-time, energy-based turn scheduler.
///
/// Each `tick()`:
/// - Increments time by 1
/// - Adds `speed` to each queued actor's energy
/// - For any actor with energy ≥ 100:
///   - Subtracts 100
///   - Invokes `takeTurn(_:)`
///
/// Actors accrue leftover energy; faster actors (higher `speed`) act more often.
///
/// ### Example
/// ```swift
/// struct Player: Actor {
///   let id: Int
///   let speed: Int
///   func takeTurn(_ ctx: TurnContext) {
///     // Do something, possibly:
///     // ctx.act(someOtherActor)
///   }
/// }
///
/// let player = Player(id: 1, speed: 100)
/// let scheduler = TurnScheduler()
/// scheduler.add(player)
/// for _ in 0..<10 { scheduler.tick() }
/// ```
public final class TurnScheduler {
  private struct Slot {
    var energy: Int
    var actor: Actor
  }

  private var queue: [Int: Slot] = [:]
  private var time = 0

  /// Creates an empty scheduler.
  public init() {}

  /// Adds an actor to the schedule.
  ///
  /// - Parameters:
  ///   - a: The actor to enqueue. Its `id` must be unique in this scheduler.
  ///   - startingEnergy: Initial energy (default `0`). If ≥ 100, the actor
  ///     may act on the next `tick()`.
  public func add(_ a: Actor, startingEnergy: Int = 0) { queue[a.id] = .init(energy: startingEnergy, actor: a) }

  /// Removes an actor by identifier. No-op if the id is not present.
  ///
  /// - Parameter id: The actor identifier to remove.
  public func remove(_ id: Int) { queue.removeValue(forKey: id) }

  /// Advances time by one tick and executes any actors whose energy reaches 100.
  ///
  /// This method is not thread-safe; call from a single thread/loop.
  public func tick() {
    time += 1

    for (id, var slot) in queue {
      slot.energy += slot.actor.speed

      if slot.energy < 100 {
        queue[id] = slot
        continue
      }

      slot.energy -= 100
      queue[id] = slot

      // Build a context whose `act` invokes `takeTurn` with the same context.
      var tmpCtx: TurnContext!
      let act: (Actor) -> Void = { actor in actor.takeTurn(tmpCtx) }
      tmpCtx = TurnContext(now: time, act: act)
      let ctx = tmpCtx!

      slot.actor.takeTurn(ctx)
    }
  }
}
