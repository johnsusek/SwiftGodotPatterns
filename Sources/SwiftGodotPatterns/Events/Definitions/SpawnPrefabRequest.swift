import Foundation
import SwiftGodot

/// Requests instancing and spawning of a prefab (PackedScene) with optional motion and lifetime.
///
/// Receivers typically `load(path) as PackedScene`, instance it, place at `origin`,
/// apply initial velocity from `direction * speed` if provided, and queue free after `lifetime`.
///
/// Example publish:
/// ```swift
/// spawnBus.publish(SpawnPrefabRequest(
///   path: "res://prefabs/fireball.tscn",
///   origin: caster.globalPosition,
///   direction: (aimPoint - caster.globalPosition).normalized(),
///   speed: 420,
///   lifetime: 3.0
/// ))
/// ```
public struct SpawnPrefabRequest {
  /// Resource path to a `PackedScene` (e.g., `"res://prefabs/projectile.tscn"`).
  public let path: String
  /// Spawn position in world space.
  public let origin: Vector2
  /// Optional initial direction (will be normalized by receivers if needed).
  public let direction: Vector2?
  /// Optional initial speed in pixels per second.
  public let speed: Double?
  /// Optional lifetime in seconds before auto-despawn.
  public let lifetime: Double?
}
