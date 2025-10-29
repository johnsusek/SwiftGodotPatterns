import SwiftGodot

/// Snapshot of multiple Godot input actions with edge-detected states.
///
/// `InputSnapshot` polls a set of Godot action names each frame using
/// `Input.isActionPressed`, storing a ``ButtonPressState`` per action (keyed by
/// `String`). Read convenience accessors like ``isDown(_:)``/``wasPressed(_:)``/``wasReleased(_:)``
/// after calling ``poll(_:)``.
///
/// ### Usage
/// ```swift
/// final class Player: CharacterBody2D {
///   private var input = InputSnapshot()
///   private let actions = ["move_left", "move_right", "jump", "attack"]
///
///   override func _physicsProcess(delta: Double) {
///     input.poll(actions)
///
///     if input.wasPressed("jump") { /* start jump */ }
///     if input.isDown("move_left") { /* apply left movement */ }
///     if input.wasReleased("attack") { /* finish attack charge */ }
///   }
/// }
/// ```
///
/// - Note: Only actions passed to ``poll(_:)`` are updated on a given frame.
///   Omitting an action leaves its previously stored state unchanged.
public struct InputSnapshot {
  /// Backing store of action states keyed by action `String`.
  public var map: [String: ButtonPressState] = [:]

  /// Creates an empty snapshot.
  public init() {}

  /// Polls the given action names and updates their states for this frame.
  ///
  /// - Parameter actions: Godot input action names (as configured in the project).
  ///
  /// For each `name`, this calls `Input.isActionPressed(action:)` and updates the
  /// per-action ``ButtonPressState``. Actions not listed are left untouched this frame.
  public mutating func poll(_ actions: [String]) {
    for name in actions {
      let key = StringName(name)
      var state = map[name] ?? ButtonPressState()
      state.update(isDown: Input.isActionPressed(action: key))
      map[name] = state
    }
  }

  /// Returns `true` if the named action is currently held.
  @inlinable public func isDown(_ name: String) -> Bool { map[String(name)]?.down == true }

  /// Returns `true` only on the frame when the named action transitions to held.
  @inlinable public func wasPressed(_ name: String) -> Bool { map[String(name)]?.pressed == true }

  /// Returns `true` only on the frame when the named action transitions to unheld.
  @inlinable public func wasReleased(_ name: String) -> Bool { map[String(name)]?.released == true }
}
