public enum CmdResult { case ok, blocked(String) }

public protocol Command {
  func validate() -> CmdResult
  func apply()
}

public struct MoveCommand: Command {
  public let from: GridPos
  public let to: GridPos
  public let passable: (GridPos) -> Bool
  public let move: (GridPos) -> Void
  public func validate() -> CmdResult { passable(to) ? .ok : .blocked("wall") }
  public func apply() { move(to) }
}

public final class CommandQueue {
  private var items: [Command] = []
  public init() {}
  public func push(_ c: Command) { items.append(c) }
  public func drain() {
    var next: [Command] = []
    for c in items {
      switch c.validate() {
      case .ok: c.apply()
      case .blocked: next.append(c)
      }
    }
    items = next.isEmpty ? [] : next
  }
}
