import Foundation

/// A single resource cost (e.g. `"mana": 20`, `"stamina": 5`).
public struct ResourceCost: Sendable, Codable, Hashable {
  /// Resource kind identifier (e.g. `"mana"`, `"energy"`).
  public var kind: String
  /// Amount to spend (must be non-negative at authoring time).
  public var amount: Int

  /// Creates a new resource cost.
  public init(_ kind: String, _ amount: Int) {
    self.kind = kind
    self.amount = amount
  }
}
