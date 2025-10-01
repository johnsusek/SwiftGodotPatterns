import Foundation
import SwiftGodot

/// A kinematic impulse request that moves `target` over time.
///
/// The receiver is responsible for interpreting direction magnitude (often normalizing),
/// moving the body over `duration` to cover `distance`, handling collisions, and
/// blending with existing velocity.
///
/// Example publish:
/// ```swift
/// knockbackBus.publish(KnockbackEvent(
///   target: enemy.getPath(),
///   direction: (enemy.globalPosition - caster.globalPosition),
///   distance: 64,
///   duration: 0.2
/// ))
/// ```
public struct KnockbackEvent {
  /// Scene-tree path of the entity to move.
  public let target: NodePath
  /// Direction vector. May be unit or non-unit; receivers commonly normalize.
  public let direction: Vector2
  /// Desired travel distance (Godot 2D pixels).
  public let distance: Double
  /// Intended duration of the motion in seconds.
  public let duration: Double
}
