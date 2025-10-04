/// Per-frame button state with edge detection.
///
/// `PressState` tracks three booleans commonly needed for input handling:
/// - ``down``: whether the control is currently held
/// - ``pressed``: became held **this frame** (rising edge)
/// - ``released``: became unheld **this frame** (falling edge)
///
/// Call ``update(isDown:)`` once per frame with the current physical/virtual
/// state to advance edges. Edges are computed by comparing the new state to the
/// previously observed state.
public struct PressState: Codable, Sendable, CustomStringConvertible {
  /// `true` while the control is held on this frame.
  public var down = false

  /// `true` only on the frame where `down` transitions `false -> true`.
  public var pressed = false

  /// `true` only on the frame where `down` transitions `true -> false`.
  public var released = false

  /// Advances this state machine using the current raw state.
  ///
  /// - Parameter isDown: The instantaneous state for this frame.
  ///
  /// On each call:
  /// - ``pressed`` becomes `true` iff `isDown` is `true` and ``down`` was `false`.
  /// - ``released`` becomes `true` iff `isDown` is `false` and ``down`` was `true`.
  /// - ``down`` is then updated to `isDown`.
  public mutating func update(isDown: Bool) {
    pressed = isDown && !down
    released = !isDown && down
    down = isDown
  }

  public var description: String {
    var s = ""
    if down { s += "down" }
    if pressed { s += "pressed" }
    if released { s += "released" }
    return s.isEmpty ? "" : s
  }
}
