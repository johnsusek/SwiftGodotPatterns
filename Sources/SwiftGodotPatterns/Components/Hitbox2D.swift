import SwiftGodot

/// A simple `Area2D`-based hitbox that publishes `DamageEvent`s on body entry.
///
/// `Hitbox2D` connects to Godot's `body_entered` signal and emits a
/// `DamageEvent` via a shared `EventBus`. It optionally enforces a
/// "hit once per body" rule using an internal `NodePath` set.
///
/// ### How it works
/// - On `_ready()`, the node enables monitoring and connects `bodyEntered`.
/// - When a physics body enters, `onBody(_:)` resolves its `NodePath`.
/// - If `oncePerBody` is `true` and the body was already hit, the event is skipped.
/// - Otherwise, the body path is recorded and a `DamageEvent` is published.
///
/// ### Usage
/// Add a `CollisionShape2D` (or similar) as a child of this node so the hitbox
/// can detect overlaps. Configure `amount` in the inspector or at runtime.
/// Ensure an `EventBus<DamageEvent>` is registered and discoverable by `@Service`.
///
/// ```swift
/// @Godot
/// final class SpikeTrap: Node2D {
///   @Child("Hitbox") var hitbox: Hitbox2D!
///   override func _ready() {
///     hitbox.amount = 10
///     hitbox.oncePerBody = true
///   }
/// }
/// ```
///
/// - Important: This implementation calls `bindProps()` in `_ready()` to activate
///   property-wrapper bindings (`@Service`, etc.).
@Godot
public final class Hitbox2D: Area2D {
  // MARK: Configuration

  /// Damage amount applied when a body enters the hitbox.
  public var amount: Int = 1

  /// If `true`, each unique body can only trigger damage once for the lifetime
  /// of this node. When `false`, every entry triggers damage.
  public var oncePerBody: Bool = false

  // MARK: Internals

  /// Set of bodies already processed (by `NodePath`) when `oncePerBody` is enabled.
  private var touched: Set<NodePath> = []

  /// Shared bus used to publish `DamageEvent`s.
  @Service<DamageEvent> var bus: EventBus<DamageEvent>?

  // MARK: Godot Lifecycle

  /// Enables monitoring and wires the `bodyEntered` signal to `onBody(_:)`.
  override public func _ready() {
    bindProps()
    monitoring = true
    monitorable = true
    _ = bodyEntered.connect { [weak self] body in self?.onBody(body) }
  }

  // MARK: Signal Handler

  /// Processes a body-enter event and publishes a `DamageEvent` if applicable.
  private func onBody(_ node: Node?) {
    guard let path = node?.getPath() else { return }
    if oncePerBody, touched.contains(path) { return }
    touched.insert(path)
    bus?.publish(.init(target: path, amount: amount, element: nil))
  }
}
