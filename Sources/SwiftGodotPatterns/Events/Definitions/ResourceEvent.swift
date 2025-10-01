import Foundation
import SwiftGodot

/// Adds or removes a quantity of a named resource on an owner entity.
///
/// Positive `delta` grants, negative consumes. The resource system decides on
/// validation, floors/ceilings, and side effects.
///
/// Example publish:
/// ```swift
/// resourceBus.publish(ResourceEvent(owner: player.getPath(), kind: "mana", delta: -30))
/// ```
public struct ResourceEvent {
  /// Scene-tree path of the resource owner.
  public let owner: NodePath
  /// Logical resource kind (e.g., `"mana"`, `"stamina"`, `"ammo.rocket"`).
  public let kind: String
  /// Change amount: positive to grant, negative to consume.
  public let delta: Int
}
