import Foundation
import SwiftGodot

/// A gameplay event indicating that `amount` of healing should be applied to `target`.
///
/// This is a plain data carrier; systems owning health should subscribe and clamp,
/// trigger VFX, logs, etc.
///
/// Example publish:
/// ```swift
/// healBus.publish(HealEvent(target: ally.getPath(), amount: 25))
/// ```
public struct HealEvent {
  /// Scene-tree path of the healed entity.
  public let target: NodePath
  /// Raw healing amount before caps or modifiers. Expected to be ≥ 0.
  public let amount: Int
}
