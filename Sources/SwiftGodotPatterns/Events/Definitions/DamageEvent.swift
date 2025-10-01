import Foundation
import SwiftGodot

/// A gameplay event indicating that `amount` of damage should be applied to `target`.
///
/// This is a plain data carrier; systems that own health/defense should subscribe
/// and decide how to handle mitigation, shields, death, logging, etc.
///
/// Example publish:
/// ```swift
/// damageBus.publish(DamageEvent(
///   target: enemy.getPath(),
///   amount: 12,
///   element: "fire"
/// ))
/// ```
public struct DamageEvent {
  /// Scene-tree path of the damaged entity.
  public let target: NodePath
  /// Raw damage magnitude before mitigation. Expected to be ≥ 0.
  public let amount: Int
  /// Optional damage element/type (e.g., `"fire"`, `"ice"`, `"true"`).
  ///
  /// Consumers may use this for resistances, vulnerabilities, or on-hit effects.
  public let element: String?
}
