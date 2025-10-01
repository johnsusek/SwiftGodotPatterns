import Foundation
import SwiftGodot

/// Applies timed knockback to a `Node2D` owner in response to events.
///
/// `Knockback2DComponent` listens for `KnockbackEvent`s on a shared `EventBus`.
/// When an event targeting the owner arrives, it computes an initial velocity
/// such that the integrated displacement over the requested duration approximates the event's
/// `distance`. The component then advances the owner every physics tick until the timer elapses.
///
/// ### Usage
/// ```swift
/// @Godot
/// final class Slime: Node2D {
///   @Child("Knockback") var kb: Knockback2DComponent?
///   // Somewhere in damage handling:
///   // knockbackBus.publish(.init(target: getPath(), direction: Vector2.left, distance: 64, duration: 0.25))
/// }
/// ```
@Godot
public final class Knockback2DComponent: Node {
  // MARK: Configuration

  /// Per-second decay factor `k` used for multiplicative damping.
  public var decay: Float = 6.0

  // MARK: Wiring

  /// The `Node2D` this component moves. Resolved automatically at bind time.
  @Ancestor<Node2D> var owner2D: Node2D?

  /// Bus from which `KnockbackEvent`s are received.
  @Service<KnockbackEvent> var knockbackBus: EventBus<KnockbackEvent>?

  // MARK: State

  /// Current knockback velocity in project units per second.
  private var velocity: Vector2 = .zero

  /// Time remaining (seconds) for the active knockback.
  private var timeLeft: Double = 0

  /// Subscription token for the knockback event stream.
  private var token: EventBus<KnockbackEvent>.Token?

  // MARK: Lifecycle

  /// Binds property wrappers, enables physics processing when an owner is present,
  /// and subscribes to knockback events.
  override public func _ready() {
    bindProps()
    setPhysicsProcess(enable: owner2D != nil)
    token = knockbackBus?.onEach { [weak self] event in self?.apply(event) }
  }

  /// Cancels the event subscription on removal from the scene tree.
  override public func _exitTree() {
    if let token { knockbackBus?.cancel(token) }
  }

  // MARK: Event Handling

  /// Applies a new knockback if the event targets the owner.
  ///
  /// The direction is normalized (defaulting to `Vector2.right` if zero).
  /// The initial speed is chosen so that the damped motion covers approximately
  /// `event.distance` over `event.duration`.
  private func apply(_ event: KnockbackEvent) {
    guard let owner2D, event.target == owner2D.getPath() else { return }
    let unitDirection = event.direction.length() == 0 ? Vector2.right : event.direction.normalized()
    velocity = initialVelocity(distance: event.distance, duration: event.duration, decay: Double(decay)) * unitDirection
    timeLeft = event.duration
  }

  // MARK: Physics

  /// Integrates knockback motion each physics tick with multiplicative damping.
  override public func _physicsProcess(delta: Double) {
    guard let owner2D, timeLeft > 0 else { return }
    let dt = Float(delta)
    owner2D.position += velocity * dt
    if decay > 0 {
      let f = Float(exp(-Double(decay) * delta)) // exponential decay
      velocity *= f
    }
    timeLeft -= delta
  }

  // MARK: Math

  /// Computes the required initial scalar speed `v0` so that the damped motion
  /// traverses approximately `distance` over `duration`.
  private func initialVelocity(distance: Double, duration: Double, decay: Double) -> Double {
    if duration <= 0 { return 0 }
    if decay <= 0 { return distance / duration }
    let k = max(1e-6, decay)
    let factor = 1 - exp(-k * duration)
    return distance * k / max(1e-6, factor)
  }
}
