/// The result of attempting to validate a `Command`.
/// - Note: `.blocked` carries a human-readable reason intended for UI/logs.
public enum CmdResult {
  /// The command can be executed now.
  case ok
  /// The command cannot be executed; includes a brief reason (e.g., `"wall"`).
  case blocked(String)
}

/// A unit of work that must be validated before it is applied.
///
/// Conforming types encapsulate both the precondition check (`validate`)
/// and the state change (`apply`). This separation allows a queue to
/// re-attempt blocked commands in later ticks without side effects.
public protocol Command {
  /// Checks whether the command can be applied at this time.
  ///
  /// - Returns: `.ok` if the command may proceed, otherwise `.blocked(reason)`.
  func validate() -> CmdResult

  /// Performs the side effect of the command.
  ///
  /// - Important: Call only after `validate()` returns `.ok`.
  func apply()
}

/// Moves an entity from one grid position to another, if the destination is passable.
///
/// This command delegates environment knowledge to two closures:
/// `passable` determines if a cell can be entered, and `move` performs
/// the actual position update for the owning entity.
public struct MoveCommand: Command {
  /// Source position of the move.
  public let from: GridPos
  /// Destination position of the move.
  public let to: GridPos
  /// Predicate that returns `true` if `GridPos` can be entered.
  public let passable: (GridPos) -> Bool
  /// Effectful action that mutates the entity's position.
  public let move: (GridPos) -> Void

  /// Validates that `to` is currently enterable.
  /// - Returns: `.ok` when `passable(to)` is `true`; otherwise `.blocked("wall")`.
  public func validate() -> CmdResult { passable(to) ? .ok : .blocked("wall") }

  /// Applies the move by invoking `move(to)`.
  /// - Precondition: `validate()` previously returned `.ok`.
  public func apply() { move(to) }
}

/// FIFO-like queue that validates and applies commands, retaining blocked ones
/// for a later attempt.
///
/// The queue is designed for turn/tick systems: each `drain()` pass tries
/// every enqueued command once. Commands that validate are applied and removed;
/// commands that are blocked are preserved for the next tick.
public final class CommandQueue {
  private var items: [Command] = []

  /// Creates an empty command queue.
  public init() {}

  /// Enqueues a command for future validation and application.
  /// - Parameter c: The command to append.
  public func push(_ c: Command) { items.append(c) }

  /// Attempts to run all queued commands once.
  ///
  /// For each command:
  /// - If `validate()` returns `.ok`, `apply()` is called and the command is dropped.
  /// - If `validate()` returns `.blocked`, the command is kept to try again later.
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
