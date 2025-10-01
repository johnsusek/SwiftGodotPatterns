import Foundation
import SwiftGodot

/// The destination of an ability cast or effect.
///
/// Typical creation:
/// ```swift
/// let target: AbilityTarget = .unit(enemy.getPath())
/// let splash: AbilityTarget = .points([Vector2(2, 3), Vector2(4, 5)])
/// ```
public enum AbilityTarget: Sendable {
  /// The caster targets itself.
  case selfOnly
  /// A single unit identified by its `NodePath`.
  case unit(NodePath)
  /// Multiple units identified by their `NodePath`s.
  case units([NodePath])
  /// A single world-space point.
  case point(Vector2)
  /// Multiple world-space points.
  case points([Vector2])
}

/// Emitted when an ability is requested or successfully initiated by a caster.
///
/// Downstream systems (validation, cost payment, animations, VFX, cooldowns)
/// can subscribe to this event to coordinate the start of an ability.
/// This event does not imply any gameplay effect has been applied yet.
///
/// Example publish:
/// ```swift
/// castBus.publish(AbilityCastEvent(
///   caster: caster.getPath(),
///   abilityId: "fireball",
///   target: .point(aimPoint),
///   spec: targetingSpec
/// ))
/// ```
public struct AbilityCastEvent {
  /// Scene-tree path to the casting entity.
  public let caster: NodePath
  /// Stable identifier for the ability (e.g., catalog key).
  public let abilityId: String
  /// Intended target(s) for this cast attempt.
  public let target: AbilityTarget
  /// Targeting requirements that governed this cast (e.g., range, arc, filters).
  ///
  /// Useful for consumers to reproduce validation or drive UI hints.
  public let spec: TargetingSpec
}

/// Emitted when an ability produces a concrete gameplay effect.
///
/// This usually follows a validated cast and represents an actual application
/// of game logic (e.g., damage, heal, knockback). Multiple effect events may be
/// emitted for a single cast if the ability has several effect stages or
/// multiplexed outcomes (e.g., damage + slow).
///
/// Example publish:
/// ```swift
/// effectBus.publish(AbilityEffectEvent(
///   caster: caster.getPath(),
///   abilityId: "fireball",
///   effect: .damage(Amount(45)),
///   target: .units(hitUnitPaths),
///   spec: targetingSpec
/// ))
/// ```
public struct AbilityEffectEvent {
  /// Scene-tree path to the entity that caused the effect.
  public let caster: NodePath
  /// Identifier of the originating ability.
  public let abilityId: String
  /// The concrete effect payload (game-defined type).
  public let effect: AbilityEffect
  /// The resolved target(s) that received the effect.
  public let target: AbilityTarget
  /// Targeting context used when resolving the effect.
  ///
  /// Retaining this alongside the effect helps auditing and replay.
  public let spec: TargetingSpec
}
