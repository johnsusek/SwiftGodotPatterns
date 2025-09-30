import Foundation

/// A single modification applied to a named stat (e.g. `"attackSpeed"`, `"armor"`).
public struct StatMod: Codable, Hashable, Sendable {
  /// How the `value` combines with the base stat.
  public enum Op: String, Codable, Sendable {
    /// `base + value`
    case add
    /// `base - value`
    case sub
    /// `base * value`
    /// use numbers less than 1 for division (e.g. `0.5` to halve)
    case mul
    /// `value` replaces `base`
    case set
  }

  /// The stat key this modifier targets. Keys are game-defined and case-sensitive.
  public var key: String
  /// The operation to apply.
  public var op: Op
  /// The numeric amount used by `op`.
  public var value: Double

  /// Creates a new stat modifier.
  public init(key: String, op: Op, value: Double) {
    self.key = key
    self.op = op
    self.value = value
  }
}
