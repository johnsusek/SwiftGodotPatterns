import Foundation
import SwiftGodot

/// Runs data-driven abilities for its owning node:
/// resolves an `AbilityType`, validates targeting & range,
/// spends resources, starts cooldowns, publishes events, and applies effects.
///
/// ### Usage
/// ```swift
/// // In your scene:
/// // AbilityRunnerComponent (Node2D)
/// // └─ ResourceMirrorComponent (Node)  // provides canPay/tryConsume
///
/// // Configure lookup (choose one)
/// runner.resolveAbility = { id in myRegistry.abilities[id] }
/// // or:
/// runner.registry = myRegistry.snapshot()
///
/// // Cast:
/// let ok = await runner.cast("fireball", target: .unit(enemyPath))
/// ```
///
/// ### Threading
/// All methods are expected to run on the main thread (Godot thread).
@Godot
public final class AbilityRunnerComponent: Node2D {
  // MARK: Lookup

  /// Closure to resolve an ability by identifier.
  ///
  /// If provided, this takes precedence over `registry`.
  /// Return `nil` for unknown identifiers.
  public var resolveAbility: ((String) -> AbilityType?)?

  /// Snapshot of a type registry used to resolve abilities when
  /// `resolveAbility` is not set.
  public var registry: TypeRegistry.Snapshot?

  // MARK: Hooks

  /// Called after a cast successfully begins (resources paid and cooldown started).
  public var onCast: ((AbilityType) -> Void)?

  /// Called when a cast is rejected. The string is a concise reason
  /// such as `"cooldown"`, `"costs"`, or `"out of range"`.
  public var onRejected: ((String) -> Void)? // reason

  // MARK: Defaults

  /// Default duration (seconds) used for auto-generated knockback effects.
  public var knockbackDuration: Double = 0.25

  // MARK: State

  /// Per-ability cooldown instances, keyed by `AbilityType.id`.
  private var cooldowns: [String: Cooldown] = [:]

  // MARK: Node relations

  /// Optional 2D owner used as the origin for range checks.
  ///
  /// Bound automatically by `bindProps()` via the `@Ancestor` wrapper.
  @Ancestor<Node2D> var owner2D: Node2D?

  /// Child that mirrors and manages resource spending.
  ///
  /// Bound automatically by `bindProps()` via the `@Child` wrapper.
  @Child<ResourceMirrorComponent> var resourceMirror: ResourceMirrorComponent?

  // MARK: Event buses

  /// Broadcasts that an ability was cast (who/what/target/spec).
  @Service<AbilityCastEvent> var castBus: EventBus<AbilityCastEvent>?

  /// Broadcasts high-level ability effects emitted by this runner.
  @Service<AbilityEffectEvent> var effectBus: EventBus<AbilityEffectEvent>?

  /// Publishes damage applications to targets.
  @Service<DamageEvent> var damageBus: EventBus<DamageEvent>?

  /// Publishes heals to targets.
  @Service<HealEvent> var healBus: EventBus<HealEvent>?

  /// Publishes resource grants/deltas to an owner.
  @Service<ResourceGrantEvent> var grantBus: EventBus<ResourceGrantEvent>?

  /// Requests spawning of a prefab/projectile/visual.
  @Service<SpawnPrefabRequest> var spawnBus: EventBus<SpawnPrefabRequest>?

  /// Publishes sound effects to be played (optionally at a position).
  @Service<SfxEvent> var sfxBus: EventBus<SfxEvent>?

  /// Publishes physics knockback instructions.
  @Service<KnockbackEvent> var knockbackBus: EventBus<KnockbackEvent>?

  // MARK: Lifecycle

  /// Binds property wrappers and enables processing to tick cooldowns.
  override public func _ready() {
    bindProps()
    setProcess(enable: true)
  }

  /// Advances cooldown timers each frame.
  /// - Parameter delta: Elapsed seconds since last frame.
  override public func _process(delta: Double) {
    for (_, abilityCooldown) in cooldowns {
      abilityCooldown.tick(delta: delta)
    }
  }
}

// MARK: - Public API

public extension AbilityRunnerComponent {
  /// Checks whether an ability id could be cast at a given target *right now*.
  ///
  /// Validation includes:
  /// - ability existence
  /// - cooldown ready
  /// - resource affordability (via `resourceMirror`)
  /// - target kind match (`TargetingSpec.kind`)
  /// - range check (if `TargetingSpec.range` is set)
  ///
  /// - Parameters:
  ///   - id: Ability identifier.
  ///   - target: Desired target (unit/path, point, self, etc.).
  /// - Returns: `true` if all gates pass; otherwise `false`.
  func canCast(_ id: String, target: AbilityTarget) -> Bool {
    guard let ability = resolve(id) else { return false }
    if let cd = cooldowns[ability.id], !cd.ready { return false }
    guard let mirror = resourceMirror, mirror.canPay(ability.costs) else { return false }
    return matchesTarget(ability.targeting, target) && withinRange(ability.targeting, target)
  }

  /// Returns all gating issues that currently prevent casting `id` at `target`.
  func castIssues(_ id: String, target: AbilityTarget) -> [CastGate] {
    var issues: [CastGate] = []
    guard let a = resolve(id) else { return [.missingAbility] }
    if let cd = cooldowns[a.id], !cd.ready { issues.append(.cooldown) }
    if let mirror = resourceMirror, !mirror.canPay(a.costs) { issues.append(.costs) }
    if !matchesTarget(a.targeting, target) { issues.append(.targetType) }
    if !withinRange(a.targeting, target) { issues.append(.outOfRange) }
    return issues
  }

  /// Attempts to cast an ability:
  /// validates gates, pays costs, starts cooldown, emits events, and applies effects.
  ///
  /// Order of operations:
  /// 1. Resolve ability
  /// 2. Check cooldown, target kind, and range
  /// 3. Attempt resource consumption via `resourceMirror.tryConsume`
  /// 4. Start cooldown and invoke `onCast`
  /// 5. Publish `AbilityCastEvent`
  /// 6. Emit effects (damage/heal/knockback/spawn/sfx/resource, etc.)
  @discardableResult
  func cast(_ id: String, target: AbilityTarget) async -> Bool {
    guard let ability = resolve(id) else { onRejected?("missing ability"); return false }
    if let cd = cooldowns[ability.id], !cd.ready { onRejected?("cooldown"); return false }
    guard matchesTarget(ability.targeting, target) else { onRejected?("target type"); return false }
    guard withinRange(ability.targeting, target) else { onRejected?("out of range"); return false }
    guard let mirror = resourceMirror else { onRejected?("no resource mirror"); return false }

    let ok = await mirror.tryConsume(ability.costs)
    if !ok { onRejected?("costs"); return false }

    let cd = cooldown(for: ability)
    _ = cd.tryUse()
    onCast?(ability)
    castBus?.publish(.init(caster: ownerPath(), abilityId: ability.id, target: target, spec: ability.targeting))
    applyEffects(ability, target: target)
    return true
  }

  /// Time remaining (seconds) on cooldown for the given id, or `nil` if not cooling down.
  func cooldownTimeLeft(for id: String) -> Double? { cooldowns[id]?.timeLeft }

  /// Convenience check for cooldown readiness (defaults to `true` if no cooldown exists yet).
  func isOffCooldown(_ id: String) -> Bool { cooldowns[id]?.ready ?? true }

  /// Canonical reasons a cast may be rejected by `castIssues(_:target:)`.
  enum CastGate: String { case missingAbility, cooldown, costs, targetType, outOfRange }
}

// MARK: - Internals

extension AbilityRunnerComponent {
  /// Resolves an `AbilityType` by id using `resolveAbility` first, then `registry`.
  private func resolve(_ id: String) -> AbilityType? {
    if let resolver = resolveAbility, let ability = resolver(id) { return ability }
    if let ability = registry?.abilities[id] { return ability }
    return nil
  }

  /// Retrieves or creates the cooldown instance for an ability.
  private func cooldown(for ability: AbilityType) -> Cooldown {
    if let existing = cooldowns[ability.id] { return existing }
    let created = Cooldown(duration: max(0, ability.cooldown))
    cooldowns[ability.id] = created
    return created
  }

  /// Checks whether a target shape/kind satisfies the targeting spec.
  private func matchesTarget(_ spec: TargetingSpec, _ target: AbilityTarget) -> Bool {
    switch (spec.kind, target) {
    case (.selfOnly, .selfOnly): return true
    case (.ally, .unit), (.enemy, .unit), (.anyUnit, .unit): return true
    case (.ally, .units), (.enemy, .units), (.anyUnit, .units): return true
    case (.point, .point), (.point, .points): return true
    case (.cone, .point), (.line, .point), (.sphere, .point): return true
    case (.cone, .points), (.line, .points), (.sphere, .points): return true
    default: return false
    }
  }

  /// Verifies that all targeted positions/units lie within `spec.range` (if any).
  private func withinRange(_ spec: TargetingSpec, _ target: AbilityTarget) -> Bool {
    guard let range = spec.range, range > 0 else { return true }
    let origin = owner2D?.globalPosition ?? globalPosition

    func within(_ point: Vector2) -> Bool { origin.distanceTo(point) <= range }

    switch target {
    case .selfOnly:
      return true
    case let .unit(path):
      guard let p = globalPos(path) else { return false }
      return within(p)
    case let .units(paths):
      return paths.allSatisfy {
        guard let p = globalPos($0) else { return false }
        return within(p)
      }
    case let .point(point):
      return within(point)
    case let .points(points):
      return points.allSatisfy(within(_:))
    }
  }

  /// Resolves a node for a possibly absolute `NodePath`.
  private func node(at path: NodePath) -> Node? {
    if path.isAbsolute() { return Engine.getSceneTree()?.root?.getNode(path: path) }
    return getNode(path: path)
  }

  /// Global position for a node path if it exists and is a `Node2D`.
  private func globalPos(_ path: NodePath) -> Vector2? {
    guard let n = node(at: path), !n.isQueuedForDeletion() else { return nil }
    return (n as? Node2D)?.globalPosition
  }

  /// Path used to attribute effects/casts to the owner (parent if present, else self).
  private func ownerPath() -> NodePath { (getParent() ?? self).getPath() }

  /// Iterates all configured effects on the ability and emits them via buses.
  private func applyEffects(_ ability: AbilityType, target: AbilityTarget) {
    let origin = owner2D?.globalPosition ?? globalPosition
    for effect in ability.effects {
      emit(effect: effect, abilityId: ability.id, target: target, origin: origin, spec: ability.targeting)
    }
  }

  /// Publishes an effect to the appropriate bus(es), expanding multi-target cases.
  private func emit(effect: AbilityEffect,
                    abilityId: String,
                    target: AbilityTarget,
                    origin: Vector2?,
                    spec: TargetingSpec)
  {
    effectBus?.publish(.init(caster: ownerPath(), abilityId: abilityId, effect: effect, target: target, spec: spec))

    switch effect {
    case let .damage(amount, element):
      switch target {
      case .selfOnly:
        damageBus?.publish(.init(target: ownerPath(), amount: amount, element: element))
      case let .unit(path):
        damageBus?.publish(.init(target: path, amount: amount, element: element))
      case let .units(paths):
        damageBus?.publish(paths.map { .init(target: $0, amount: amount, element: element) })
      case .point, .points:
        break
      }

    case let .heal(amount):
      switch target {
      case .selfOnly:
        healBus?.publish(.init(target: ownerPath(), amount: amount))
      case let .unit(path):
        healBus?.publish(.init(target: path, amount: amount))
      case let .units(paths):
        healBus?.publish(paths.map { .init(target: $0, amount: amount) })
      default:
        break
      }

    case let .applyStatMods(modifiers, duration):
      _ = (modifiers, duration) // TODO: route to a status/modifier system

    case let .addStatus(id, stacks, duration):
      _ = (id, stacks, duration) // TODO: route to a status system

    case let .resource(kind, delta):
      grantBus?.publish(.init(owner: ownerPath(), kind: kind, amount: delta))

    case let .knockback(distance):
      guard let origin, case let .unit(path) = target else { break }
      if let targetPos = globalPos(path) {
        let v = targetPos - origin
        let dir = v.length() > 0.0001 ? v.normalized() : Vector2.right
        knockbackBus?.publish(.init(target: path, direction: dir, distance: distance, duration: knockbackDuration))
      }

    case let .spawnPrefab(path, speed, lifetime):
      if let origin { spawnBus?.publish(.init(path: path, origin: origin, direction: nil, speed: speed, lifetime: lifetime)) }

    case let .playSfx(name):
      sfxBus?.publish(.init(name: name, at: origin))
    }
  }
}
