import Foundation
import SwiftGodot

/// Notifies that `source` has acquired or locked onto `target`.
///
/// Useful for aim-assist, homing projectiles, AI threat selection, or UI highlights.
/// This is informational; losing the target is a separate concern/event.
///
/// Example publish:
/// ```swift
/// lockBus.publish(TargetAcquired(source: turret.getPath(), target: enemy.getPath()))
/// ```
public struct TargetAcquired {
  /// Scene-tree path of the entity that gained a target.
  public let source: NodePath
  /// Scene-tree path of the acquired target.
  public let target: NodePath
}
