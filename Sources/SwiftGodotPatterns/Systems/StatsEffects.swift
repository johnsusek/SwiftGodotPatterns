/// Snapshot of an entity's core combat stats.
///
/// - Note: `hpMax` is initialized to the starting `hp`.
public struct StatBlock {
  /// Current hit points (clamped to `0...hpMax` by `heal`/`damage`).
  public var hp: Int
  /// Maximum hit points.
  public var hpMax: Int
  /// Attack power used for outgoing damage calculations.
  public var atk: Int
  /// Defense value used for incoming damage mitigation.
  public var def: Int

  /// Creates a stat block; `hpMax` is set to the initial `hp`.
  public init(hp: Int, atk: Int, def: Int) {
    self.hp = hp
    hpMax = hp
    self.atk = atk
    self.def = def
  }

  /// Restores hit points, never exceeding `hpMax`.
  /// - Parameter n: Healing amount (non-negative; negative values are ignored).
  public mutating func heal(_ n: Int) { hp = min(hpMax, hp + max(0, n)) }

  /// Applies damage, never dropping below zero.
  /// - Parameter n: Damage amount (non-negative; negative values are ignored).
  public mutating func damage(_ n: Int) { hp = max(0, hp - max(0, n)) }
}

/// A time-bounded gameplay modifier that can alter a `StatBlock`.
///
/// Conformers may represent buffs, debuffs, auras, or status ailments.
/// `remaining` typically counts down in ticks/turns via an `EffectBag`.
public protocol Effect {
  /// Stable identifier used as the dictionary key in `EffectBag`.
  var id: String { get }
  /// Remaining duration in ticks/turns. When this reaches zero, the effect expires.
  var remaining: Int { get set }
  /// Applies this effect's modifications to the provided stats.
  /// - Parameter s: The stats to be modified in place.
  func modify(_ s: inout StatBlock)
}

/// A container that owns, updates, and applies active `Effect`s.
///
/// Effects are keyed by `Effect.id`. Adding an effect with an existing id replaces
/// the previous one (refresh/override semantics).
public final class EffectBag {
  /// Active effects keyed by id.
  public private(set) var effects: [String: Effect] = [:]

  /// Creates an empty bag.
  public init() {}

  /// Adds or replaces an effect by its `id`.
  /// - Parameter e: The effect to insert.
  public func add(_ e: Effect) { effects[e.id] = e }

  /// Removes an effect by id, if present.
  public func remove(_ id: String) { effects.removeValue(forKey: id) }

  /// Advances time by one tick for all effects, expiring those that hit zero.
  ///
  /// - Important: Duration accounting is responsibility of the effect; this
  ///   implementation simply decrements `remaining` and drops expired entries.
  public func tick() {
    for (k, var e) in effects {
      e.remaining -= 1
      if e.remaining <= 0 { effects.removeValue(forKey: k) } else { effects[k] = e }
    }
  }

  /// Applies all active effects to the provided stats.
  /// - Parameter s: The stats to be modified in place by each effect's `modify`.
  public func apply(to s: inout StatBlock) {
    for e in effects.values {
      e.modify(&s)
    }
  }
}
