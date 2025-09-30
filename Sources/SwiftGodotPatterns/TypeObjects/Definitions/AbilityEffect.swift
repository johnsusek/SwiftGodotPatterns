import Foundation

/// A tagged, codable description of an ability side-effect, such as damage,
/// healing, status change, or visual/sound effects.
///
///
/// ### JSONL Sample
/// ```json
/// {"type":"damage","amount":25,"element":"fire"}
/// {"type":"applyStatMods","mods":[{"key":"armor","op":"add","value":10}], "duration":5.0}
/// {"type":"spawnPrefab","path":"res://fx/ice_shard.tscn","speed":14.0,"lifetime":2.0}
/// ```
public enum AbilityEffect: Hashable, Sendable {
  /// Deal `amount` damage, optionally typed by `element` (e.g. `"fire"`).
  case damage(amount: Int, element: String?)
  /// Restore `amount` health.
  case heal(amount: Int)
  /// Apply one or more stat modifiers for an optional duration.
  case applyStatMods(mods: [StatMod], duration: Double?)
  /// Apply or refresh a status by `id` with optional `stacks` and `duration`.
  /// Interpretation of `id` is game-specific (e.g. a status registry).
  case addStatus(id: String, stacks: Int?, duration: Double?)
  /// Adjust a resource pool by `delta` (positive or negative).
  case resource(kind: String, delta: Int)
  /// Push the target(s) away by `distance` units.
  case knockback(distance: Double)
  /// Spawn a visual prefab (e.g. projectile or VFX). Optional `speed`/`lifetime`.
  case spawnPrefab(path: String, speed: Double?, lifetime: Double?)
  /// Play a named sound effect.
  case playSfx(name: String)
}

extension AbilityEffect: Codable {
  private enum K: String, CodingKey { case type }

  private enum T: String, Codable {
    case damage
    case heal
    case applyStatMods
    case addStatus
    case resource
    case knockback
    case spawnPrefab
    case playSfx
  }

  /// Encodes the payload
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: K.self)
    switch self {
    case let .damage(amount, element):
      try c.encode(T.damage, forKey: .type)
      var s = encoder.container(keyedBy: CodingKeys.self)
      try s.encode(amount, forKey: .amount)
      try s.encodeIfPresent(element, forKey: .element)
    case let .heal(amount):
      try c.encode(T.heal, forKey: .type)
      var s = encoder.container(keyedBy: CodingKeys.self)
      try s.encode(amount, forKey: .amount)
    case let .applyStatMods(mods, duration):
      try c.encode(T.applyStatMods, forKey: .type)
      var s = encoder.container(keyedBy: CodingKeys.self)
      try s.encode(mods, forKey: .mods)
      try s.encodeIfPresent(duration, forKey: .duration)
    case let .addStatus(id, stacks, duration):
      try c.encode(T.addStatus, forKey: .type)
      var s = encoder.container(keyedBy: CodingKeys.self)
      try s.encode(id, forKey: .id)
      try s.encodeIfPresent(stacks, forKey: .stacks)
      try s.encodeIfPresent(duration, forKey: .duration)
    case let .resource(kind, delta):
      try c.encode(T.resource, forKey: .type)
      var s = encoder.container(keyedBy: CodingKeys.self)
      try s.encode(kind, forKey: .kind)
      try s.encode(delta, forKey: .delta)
    case let .knockback(distance):
      try c.encode(T.knockback, forKey: .type)
      var s = encoder.container(keyedBy: CodingKeys.self)
      try s.encode(distance, forKey: .distance)
    case let .spawnPrefab(path, speed, lifetime):
      try c.encode(T.spawnPrefab, forKey: .type)
      var s = encoder.container(keyedBy: CodingKeys.self)
      try s.encode(path, forKey: .path)
      try s.encodeIfPresent(speed, forKey: .speed)
      try s.encodeIfPresent(lifetime, forKey: .lifetime)
    case let .playSfx(name):
      try c.encode(T.playSfx, forKey: .type)
      var s = encoder.container(keyedBy: CodingKeys.self)
      try s.encode(name, forKey: .name)
    }
  }

  /// Decodes the payload
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: K.self)
    let t = try c.decode(T.self, forKey: .type)
    let s = try decoder.container(keyedBy: CodingKeys.self)
    switch t {
    case .damage:
      self = try .damage(
        amount: s.decode(Int.self, forKey: .amount),
        element: s.decodeIfPresent(String.self, forKey: .element)
      )
    case .heal:
      self = try .heal(amount: s.decode(Int.self, forKey: .amount))
    case .applyStatMods:
      self = try .applyStatMods(
        mods: s.decode([StatMod].self, forKey: .mods),
        duration: s.decodeIfPresent(Double.self, forKey: .duration)
      )
    case .addStatus:
      self = try .addStatus(
        id: s.decode(String.self, forKey: .id),
        stacks: s.decodeIfPresent(Int.self, forKey: .stacks),
        duration: s.decodeIfPresent(Double.self, forKey: .duration)
      )
    case .resource:
      self = try .resource(
        kind: s.decode(String.self, forKey: .kind),
        delta: s.decode(Int.self, forKey: .delta)
      )
    case .knockback:
      self = try .knockback(distance: s.decode(Double.self, forKey: .distance))
    case .spawnPrefab:
      self = try .spawnPrefab(
        path: s.decode(String.self, forKey: .path),
        speed: s.decodeIfPresent(Double.self, forKey: .speed),
        lifetime: s.decodeIfPresent(Double.self, forKey: .lifetime)
      )
    case .playSfx:
      self = try .playSfx(name: s.decode(String.self, forKey: .name))
    }
  }

  private enum CodingKeys: String, CodingKey {
    case amount, element, mods, duration, id, stacks, kind, delta, distance, path, speed, lifetime, name
  }
}
