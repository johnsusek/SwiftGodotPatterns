import Foundation

/// Declarative targeting information for an ability.
///
/// Ranges and radii are optional to support self or untargeted abilities.
public struct TargetingSpec: Codable, Hashable, Sendable {
  /// Targeting mode.
  public var kind: TargetKind
  /// Max selection range in world units, when relevant.
  public var range: Double?

  /// Creates a targeting specification.
  public init(kind: TargetKind, range: Double? = nil) {
    self.kind = kind
    self.range = range
  }
}
