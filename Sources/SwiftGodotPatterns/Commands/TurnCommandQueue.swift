/// FIFO-like queue that validates and applies commands, retaining blocked ones
/// for a later attempt.
///
/// The queue is designed for turn/tick systems: each `drain()` pass tries
/// every enqueued command once. Commands that validate are applied and removed;
/// commands that are blocked are preserved for the next tick.
public final class CommandQueue {
  private var items: [TurnCommand] = []

  /// Creates an empty command queue.
  public init() {}

  /// Enqueues a command for future validation and application.
  /// - Parameter c: The command to append.
  public func push(_ c: TurnCommand) { items.append(c) }

  /// Attempts to run all queued commands once.
  ///
  /// For each command:
  /// - If `validate()` returns `.ok`, `execute()` is called and the command is dropped.
  /// - If `validate()` returns `.blocked`, the command is kept to try again later.
  public func drain() {
    var next: [TurnCommand] = []

    for c in items {
      switch c.validate() {
      case .ok: c.execute()
      case .blocked: next.append(c)
      }
    }

    items = next
  }
}
