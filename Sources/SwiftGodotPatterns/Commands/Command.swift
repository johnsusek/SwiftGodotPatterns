/// A unit of work that must be validated before it is applied.
public protocol Command {
  /// Checks whether the command can be applied at this time.
  func validate() -> CmdResult

  /// Performs the side effect of the command.
  func execute()
}

/// The result of attempting to validate a `Command`.
public enum CmdResult {
  /// The command can be executed now.
  case ok
  /// The command cannot be executed; includes a brief reason (e.g., `"wall"`).
  case blocked(String)
}
