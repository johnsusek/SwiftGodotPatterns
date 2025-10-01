import SwiftGodot

/// Applies 2D kinematics (acceleration -> velocity -> position) to a `Node2D`.
///
/// `Velocity2DComponent` accumulates `acceleration` into `velocity`, optionally
/// applies linear damping, clamps to `maxSpeed`, and finally adds the result to the
/// owner's position.
@Godot
public final class Velocity2DComponent: Node {
  /// Per-second acceleration applied to the owner (in project units).
  public var acceleration: Vector2 = .zero

  /// Current velocity (in project units per second).
  public var velocity: Vector2 = .zero

  /// Maximum allowed speed magnitude. Defaults to `infinity` (no cap).
  public var maxSpeed: Float = .infinity

  /// Per-second multiplicative damping coefficient.
  ///
  /// Effective update is `v = v * (1 - linearDamping * dt)`. Set to `0` to
  /// disable damping. Choose small values (e.g., `2–10`) for snappy decay.
  public var linearDamping: Float = 0.0

  /// The `Node2D` driven by this component. Resolved automatically.
  @Ancestor<Node2D> var owner2D: Node2D?

  /// Binds property wrappers and enables physics only when an owner is present.
  override public func _ready() {
    bindProps()
    setPhysicsProcess(enable: owner2D != nil)
  }

  /// Integrates velocity and position each physics tick.
  override public func _physicsProcess(delta: Double) {
    guard let owner2D else { return }
    let dt = Float(delta)

    velocity += acceleration * dt
    if linearDamping > 0 { velocity *= max(0, 1 - linearDamping * dt) }

    if maxSpeed.isFinite, velocity.length() > Double(maxSpeed) {
      velocity = velocity.normalized() * maxSpeed
    }

    owner2D.position += velocity * dt
  }
}
