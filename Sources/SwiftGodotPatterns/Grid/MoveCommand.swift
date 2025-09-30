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
  public func execute() { move(to) }
}
