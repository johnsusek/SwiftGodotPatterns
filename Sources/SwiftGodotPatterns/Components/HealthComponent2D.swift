import SwiftGodot

/// A reusable health component.
///
/// `HealthComponent2D` owns a small `Health` model, exposes simple callbacks,
/// and subscribes to a global `EventBus<DamageEvent>` to apply incoming damage
/// when the event's `target` matches this component's parent node.
///
/// ### Usage
/// ```swift
/// @Godot
/// final class Enemy: Node2D {
///   @Child("Health") var health: HealthComponent2D!
///
///   override func _ready() {
///     health.onChanged = { newValue in GD.print("HP:", newValue) }
///     health.onDied = { GD.print("Enemy died") }
///   }
/// }
/// ```
///
/// - Important: This implementation calls `bindProps()` in `_ready()` to activate
///   property-wrapper bindings (`@Child`, etc.).

@Godot
public final class HealthComponent2D: Node {
  // MARK: Configuration

  /// Maximum hit points for the entity.
  ///
  /// Defaults to `100`. Changing this after `_ready()` has run does not
  /// retroactively resize the underlying `Health` model.
  public var max: Double = 100

  /// Optional starting hit points.
  ///
  /// If `nil`, the initial value equals `max`. Provide a value to start partially
  /// damaged or over-healed if your `Health` model permits it.
  public var start: Double? = nil

  // MARK: Callbacks

  /// Invoked exactly once when health reaches zero (or below) for the first time.
  ///
  /// Use this to trigger death VFX/SFX, drop loot, or queue-free the owner.
  public var onDied: (() -> Void)?

  /// Invoked whenever the health value changes.
  public var onChanged: ((Double) -> Void)?

  // MARK: Internals

  /// Backing health model. Created in `_ready()`.
  private var health: Health?

  /// Nearest `Node2D` ancestor, discovered automatically.
  ///
  /// Provided by the `@Ancestor` property wrapper, which walks up the parent
  /// chain at bind time. Useful for positioning effects relative to the owner.
  @Ancestor<Node2D> var owner2D: Node2D?

  /// Damage event bus resolved from the Autoload/services table.
  ///
  /// The `@Service` property wrapper looks up a shared `EventBus<DamageEvent>`
  /// instance by type. If no bus is registered, damage events are simply ignored.
  @Service<DamageEvent> var damageBus: EventBus<DamageEvent>?

  /// Subscription token used to cancel the damage event stream when detached
  /// from the scene tree.
  private var token: EventBus<DamageEvent>.Token?

  // MARK: Godot Lifecycle

  /// Godot entry point. Binds wrappers, builds the `Health` model, and subscribes
  /// to `DamageEvent`s.
  override public func _ready() {
    bindProps()

    let h = Health(max: max, start: start)
    h.onDied = { [weak self] in self?.onDied?() }
    h.onChanged = { [weak self] _, newValue in self?.onChanged?(newValue) }
    health = h

    token = damageBus?.onEach { [weak self] event in self?.maybeApply(event) }
  }

  /// Cancels the damage event subscription when the node leaves the scene tree.
  override public func _exitTree() {
    if let token { damageBus?.cancel(token) }
  }

  // MARK: Damage Handling

  /// Applies damage from an incoming event if it targets this component's parent.
  ///
  /// The check compares `event.target` with the parent node's `NodePath`.
  /// If they match, the damage amount is forwarded to the `Health` model.
  private func maybeApply(_ event: DamageEvent) {
    guard let parent = getParent(), event.target == parent.getPath() else { return }
    health?.damage(Double(event.amount))
  }
}
