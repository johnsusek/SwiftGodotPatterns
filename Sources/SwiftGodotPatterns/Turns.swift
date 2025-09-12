public protocol Actor {
  var id: Int { get }
  var speed: Int { get } // energy per tick (e.g. 100 normal)
  func takeTurn(_ context: TurnContext)
}

public struct TurnContext {
  public let now: Int
  public let act: (Actor) -> Void
}

public final class TurnScheduler {
  private struct Slot { var energy: Int; var actor: Actor }
  private var queue: [Int: Slot] = [:]
  private var time = 0
  public init() {}
  public func add(_ a: Actor, startingEnergy: Int = 0) { queue[a.id] = .init(energy: startingEnergy, actor: a) }
  public func remove(_ id: Int) { queue.removeValue(forKey: id) }

  public func tick() {
    time += 1
    for (id, var s) in queue {
      s.energy += s.actor.speed
      if s.energy < 100 { queue[id] = s; continue }
      s.energy -= 100
      queue[id] = s
      let ctx = TurnContext(now: time) { actor in actor.takeTurn(ctx) }
      s.actor.takeTurn(ctx)
    }
  }
}
