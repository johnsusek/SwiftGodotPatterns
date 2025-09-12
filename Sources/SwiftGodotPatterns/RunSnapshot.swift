/// A codable snapshot of an in-progress run.
///
/// Captures the RNG seed, the player's grid position, the current dungeon
/// depth (e.g., floor level), and the set of tiles the player has discovered.
public struct RunSnapshot: Codable {
  /// RNG seed used to reproduce procedural content.
  public let seed: UInt64
  /// Player's current tile position.
  public let player: GridPos
  /// Current dungeon depth/floor index.
  public let depth: Int
  /// Tiles that have been revealed (e.g., for fog-of-war).
  public let discovered: [GridPos]

  /// Initializes a snapshot of the run state.
  public init(seed: UInt64, player: GridPos, depth: Int, discovered: [GridPos]) {
    self.seed = seed
    self.player = player
    self.depth = depth
    self.discovered = discovered
  }
}
