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
