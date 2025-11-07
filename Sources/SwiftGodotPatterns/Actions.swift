import SwiftGodot

// MARK: - Event modeling

/// Describes a single input event in a declarative, strongly-typed way.
/// Use these to build actions without hard-coding raw integers.
public enum InputEventSpec {
  /// Keyboard event using a Godot `Key` (physical scancode).
  case key(_ key: Key)
  /// Joypad button event for a specific device and button.
  case joyButton(button: JoyButton, device: Int)
  /// Joypad axis motion event with a signed axis value (−1.0...1.0).
  case joyAxis(axis: JoyAxis, device: Int, value: Double)
  /// Mouse button event by numerical index (mapped to `MouseButton`).
  case mouseButton(index: Int)

  /// Builds the corresponding Godot `InputEvent` instance.
  ///
  /// This materializes the declarative spec into an engine object that
  /// can be registered with `InputMap`. Defaults `pressed` to `false`
  /// for button/keyboard types to represent the "binding" rather than state.
  func make() -> InputEvent {
    switch self {
    case let .key(key):
      let e = InputEventKey()
      e.physicalKeycode = key
      return e
    case let .joyButton(button, device):
      let e = InputEventJoypadButton()
      e.device = Int32(device)
      e.buttonIndex = button
      return e
    case let .joyAxis(axis, device, value):
      let e = InputEventJoypadMotion()
      e.device = Int32(device)
      e.axis = axis
      e.axisValue = value
      return e
    case let .mouseButton(index):
      let e = InputEventMouseButton()
      e.buttonIndex = MouseButton(rawValue: Int64(index)) ?? .none
      return e
    }
  }
}

// MARK: - Action modeling

/// A named input action and the set of events that trigger it.
///
/// Use `installing(clearExisting:)` to register this action with `InputMap`.
public struct ActionSpec {
  /// Action name as used by Godot's `InputMap` and `Input.is_action_*` APIs.
  public let name: String
  /// Optional deadzone to apply to the action (commonly for analog axes).
  public let deadzone: Double?
  /// Events (keys, buttons, axes, mouse) that will trigger this action.
  public let events: [InputEventSpec]

  /// Creates a new `ActionSpec`.
  public init(_ name: String, deadzone: Double? = nil, events: [InputEventSpec]) {
    self.name = name
    self.deadzone = deadzone
    self.events = events
  }

  /// Registers this action and its events with Godot's `InputMap`.
  ///
  /// - Parameter clearExisting: If `true`, erases any existing events
  ///   for this action before adding the new ones.
  public func installing(clearExisting: Bool = false) {
    let sn = StringName(name)

    if !InputMap.hasAction(sn) {
      InputMap.addAction(sn)
    }

    if let dz = deadzone {
      InputMap.actionSetDeadzone(action: sn, deadzone: Double(dz))
    }

    if clearExisting {
      InputMap.actionEraseEvents(action: sn)
    }

    for e in events {
      InputMap.actionAddEvent(action: sn, event: e.make())
    }
  }
}

// MARK: - Builders

/// Result builder for composing `[InputEventSpec]` in a DSL block.
///
/// Enables:
/// ```swift
/// Action("jump") {
///   Key(.space)
///   JoyButton(0, .a)
/// }
/// ```
@_documentation(visibility: private)
@resultBuilder
public enum InputEventBuilder {
  public static func buildBlock(_ parts: [InputEventSpec]...) -> [InputEventSpec] { parts.flatMap { $0 } }
  public static func buildExpression(_ e: InputEventSpec) -> [InputEventSpec] { [e] }
  public static func buildExpression(_ es: [InputEventSpec]) -> [InputEventSpec] { es }
  public static func buildOptional(_ e: [InputEventSpec]?) -> [InputEventSpec] { e ?? [] }
  public static func buildEither(first: [InputEventSpec]) -> [InputEventSpec] { first }
  public static func buildEither(second: [InputEventSpec]) -> [InputEventSpec] { second }
  public static func buildArray(_ arr: [[InputEventSpec]]) -> [InputEventSpec] { arr.flatMap { $0 } }
}

/// Result builder for composing `[ActionSpec]` in a DSL block.
///
/// Enables:
/// ```swift
/// Actions {
///   Action("fire") { MouseButton(1) }
///   Action("left") { Key(.a) }
///   Action("right") { Key(.d) }
/// }
/// ```
@_documentation(visibility: private)
@resultBuilder
public enum ActionBuilder {
  public static func buildBlock(_ parts: [ActionSpec]...) -> [ActionSpec] { parts.flatMap { $0 } }
  public static func buildExpression(_ a: ActionSpec) -> [ActionSpec] { [a] }
  public static func buildExpression(_ asv: [ActionSpec]) -> [ActionSpec] { asv }
  public static func buildOptional(_ a: [ActionSpec]?) -> [ActionSpec] { a ?? [] }
  public static func buildEither(first: [ActionSpec]) -> [ActionSpec] { first }
  public static func buildEither(second: [ActionSpec]) -> [ActionSpec] { second }
  public static func buildArray(_ arr: [[ActionSpec]]) -> [ActionSpec] { arr.flatMap { $0 } }
}

// MARK: - DSL surface

/// Top-level container for a set of actions to be installed into `InputMap`.
///
/// ### Usage:
/// ```swift
/// let inputs = Actions {
///   Action("jump") { Key(.space) }
///   Action("shoot") { MouseButton(1) }
/// }
/// inputs.install(clearExisting: true)
/// ```
public struct Actions {
  /// The actions to be installed.
  public let actions: [ActionSpec]

  /// Builds an `Actions` from a declarative block of `ActionSpec`s.
  public init(@ActionBuilder _ content: () -> [ActionSpec]) { actions = content() }

  /// Installs all actions into the `InputMap` in declaration order.
  ///
  /// - Parameter clearExisting: When `true`, purges existing events for each
  ///   action name before re-adding the declared bindings.
  public func install(clearExisting: Bool = false) {
    for a in actions {
      a.installing(clearExisting: clearExisting)
    }
  }
}

/// Convenience function for building a single `ActionSpec` with an `InputEventBuilder` block.
///
/// ### Usage:
/// ```swift
/// Action("move_left", deadzone: 0.2) {
///   JoyAxis(0, .leftX, -1)
///   Key(.a)
/// }
/// ```
@inlinable public func Action(
  _ name: String,
  deadzone: Double? = nil,
  @InputEventBuilder events: () -> [InputEventSpec]
) -> ActionSpec {
  ActionSpec(name, deadzone: deadzone, events: events())
}

// MARK: - Sugar for event literals inside InputEventBuilder

/// Shorthand constructor for a keyboard event.
@inlinable public func Key(_ key: Key) -> InputEventSpec { .key(key) }

/// Shorthand constructor for a joypad button event.
@inlinable public func JoyButton(_ button: JoyButton, device: Int) -> InputEventSpec {
  .joyButton(button: button, device: device)
}

/// Shorthand constructor for a joypad axis event.
@inlinable public func JoyAxis(_ axis: JoyAxis, device: Int, _ value: Double) -> InputEventSpec {
  .joyAxis(axis: axis, device: device, value: value)
}

/// Shorthand constructor for a mouse button event (by integer index).
@inlinable public func MouseButton(_ index: Int) -> InputEventSpec { .mouseButton(index: index) }

// MARK: - Recipes

/// Ready-made helpers that expand into multiple `ActionSpec`s for common patterns.
/// Useful for mapping analog axes to paired digital actions (e.g. up/down, left/right).
public enum ActionRecipes {
  /// Produces `<prefix>_down` and `<prefix>_up` actions for a vertical axis.
  ///
  /// Each action includes the axis motion plus any optional key or button,
  /// with a shared deadzone applied to both.
  ///
  /// - Parameters:
  ///   - namePrefix: Action name prefix, e.g. `"move"` -> `"move_down"`, `"move_up"`.
  ///   - device: Joypad device index.
  ///   - axis: The joypad axis to sample.
  ///   - dz: Deadzone for both actions (default `0.2`).
  ///   - keyDown: Optional keyboard keys to include.
  ///   - keyUp: Optional keyboard keys to include.
  ///   - btnDown: Optional joypad buttons to include.
  ///   - btnUp: Optional joypad buttons to include.
  /// - Returns: Two `ActionSpec`s: `*_down` (value `+1.0`) and `*_up` (value `-1.0`).
  @inlinable public static func axisUD(
    namePrefix: String,
    device: Int,
    axis: JoyAxis,
    dz: Double = 0.2,
    keyDown: Key? = nil, keyUp: Key? = nil,
    btnDown: JoyButton? = nil, btnUp: JoyButton? = nil
  ) -> [ActionSpec] {
    let downEv: [InputEventSpec] = [
      .joyAxis(axis: axis, device: device, value: 1.0),
      keyDown.map { .key($0) },
      btnDown.map { .joyButton(button: $0, device: device) },
    ].compactMap { $0 }

    let upEv: [InputEventSpec] = [
      .joyAxis(axis: axis, device: device, value: -1.0),
      keyUp.map { .key($0) },
      btnUp.map { .joyButton(button: $0, device: device) },
    ].compactMap { $0 }

    return [
      ActionSpec("\(namePrefix)_down", deadzone: dz, events: downEv),
      ActionSpec("\(namePrefix)_up", deadzone: dz, events: upEv),
    ]
  }

  /// Produces `<prefix>_left` and `<prefix>_right` actions for a horizontal axis.
  ///
  /// Mirrors `axisUD` but with left/right semantics and axis values `−1.0/ +1.0`.
  @inlinable public static func axisLR(
    namePrefix: String,
    device: Int,
    axis: JoyAxis,
    dz: Double = 0.2,
    keyLeft: Key? = nil,
    keyRight: Key? = nil,
    btnLeft: JoyButton? = nil,
    btnRight: JoyButton? = nil
  ) -> [ActionSpec] {
    let left: [InputEventSpec] = [
      .joyAxis(axis: axis, device: device, value: -1.0),
      keyLeft.map { .key($0) },
      btnLeft.map { .joyButton(button: $0, device: device) },
    ].compactMap { $0 }

    let right: [InputEventSpec] = [
      .joyAxis(axis: axis, device: device, value: 1.0),
      keyRight.map { .key($0) },
      btnRight.map { .joyButton(button: $0, device: device) },
    ].compactMap { $0 }

    return [
      ActionSpec("\(namePrefix)_left", deadzone: dz, events: left),
      ActionSpec("\(namePrefix)_right", deadzone: dz, events: right),
    ]
  }
}

// MARK: - API Surface

public struct InputPhase: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let pressed = InputPhase(rawValue: 1 << 0)
  public static let released = InputPhase(rawValue: 1 << 1)
  public static let echo = InputPhase(rawValue: 1 << 2)
}

public enum InputScope { case raw, unhandled, shortcut, unhandledKey }

public enum InputMatch {
  case any
  case pressed, released, echo
  case key(Key)
  case mouse(MouseButton)
  case joyButton(JoyButton)
  case action(String) // InputMap action
}

// MARK: - Filter compiler for the generic variant

struct _CompiledFilter {
  enum Kind { case any, key(Key), mouse(MouseButton), joy(JoyButton), action(StringName) }
  let kind: Kind
  let phases: InputPhase
  let acceptEcho: Bool

  static func compile(_ parts: [InputMatch]) -> _CompiledFilter {
    var kind: Kind = .any
    var phases: InputPhase = []
    var acceptEcho = false
    for p in parts {
      switch p {
      case .any: kind = .any
      case .pressed: phases.insert(.pressed)
      case .released: phases.insert(.released)
      case .echo: acceptEcho = true
      case let .key(k): kind = .key(k)
      case let .mouse(b): kind = .mouse(b)
      case let .joyButton(b): kind = .joy(b)
      case let .action(name): kind = .action(StringName(name))
      }
    }
    if phases.isEmpty { phases = [.pressed] }
    return .init(kind: kind, phases: phases, acceptEcho: acceptEcho)
  }

  func matches(_ ev: InputEvent) -> Bool {
    switch kind {
    case .any:
      return matchesPhase(ev)
    case let .key(k):
      guard let kev = ev as? InputEventKey, kev.physicalKeycode == k else { return false }
      return matchesKeyPhase(kev)
    case let .mouse(b):
      guard let mev = ev as? InputEventMouseButton, mev.buttonIndex == b else { return false }
      return matchesMousePhase(mev)
    case let .joy(b):
      guard let jev = ev as? InputEventJoypadButton, jev.buttonIndex == b else { return false }
      return matchesButtonPhase(jev.pressed)
    case let .action(name):
      if phases.contains(.pressed), ev.isActionPressed(action: name) { return true }
      if phases.contains(.released), ev.isActionReleased(action: name) { return true }
      return false
    }
  }

  private func matchesPhase(_ ev: InputEvent) -> Bool {
    if let kev = ev as? InputEventKey { return matchesKeyPhase(kev) }
    if let mev = ev as? InputEventMouseButton { return matchesMousePhase(mev) }
    if let btn = ev as? InputEventJoypadButton { return matchesButtonPhase(btn.pressed) }
    return false
  }

  private func matchesKeyPhase(_ kev: InputEventKey) -> Bool {
    if kev.echo { return acceptEcho }
    return kev.pressed ? phases.contains(.pressed) : phases.contains(.released)
  }

  private func matchesMousePhase(_ mev: InputEventMouseButton) -> Bool {
    return mev.pressed ? phases.contains(.pressed) : phases.contains(.released)
  }

  private func matchesButtonPhase(_ pressed: Bool) -> Bool {
    return pressed ? phases.contains(.pressed) : phases.contains(.released)
  }
}

// MARK: - Runtime Action Polling

/// A runtime wrapper for querying the state of an input action.
///
/// Caches the `StringName` to avoid repeated allocations when polling
/// input state each frame. Access via the `Action(_:)` function or
/// `Actions[_:]` subscript.
///
/// ### Usage:
/// ```swift
/// // In your _process or handleInput:
/// if Action("jump").isJustPressed {
///   player.jump()
/// }
///
/// if Action("move_left").isPressed {
///   player.moveLeft(Action("move_left").strength)
/// }
///
/// // Or via subscript:
/// if Actions["pause"].isJustPressed {
///   togglePause()
/// }
/// ```
public struct RuntimeAction {
  /// The action name as a cached `StringName`.
  public let action: StringName

  /// Creates a runtime action query for the given action name.
  ///
  /// The `StringName` is created once and cached, so repeated calls
  /// to the same action are efficient.
  public init(name: String) {
    action = StringName(name)
  }

  /// Returns `true` if the action is currently pressed.
  @inlinable public var isPressed: Bool {
    Input.isActionPressed(action: action)
  }

  /// Returns `true` if the action was just pressed this frame.
  @inlinable public var isJustPressed: Bool {
    Input.isActionJustPressed(action: action)
  }

  /// Returns `true` if the action was just released this frame.
  @inlinable public var isJustReleased: Bool {
    Input.isActionJustReleased(action: action)
  }

  /// Returns the analog strength of the action (0.0 to 1.0).
  ///
  /// For digital inputs, returns `1.0` when pressed, `0.0` otherwise.
  /// For analog inputs (axes), returns the current value after deadzone.
  @inlinable public var strength: Double {
    Input.getActionStrength(action: action)
  }

  /// Returns the raw analog strength without deadzone processing.
  @inlinable public var rawStrength: Double {
    Input.getActionRawStrength(action: action)
  }

  /// Returns the axis value for paired actions (e.g., "left"/"right").
  ///
  /// Typically used with action pairs like `move_left`/`move_right` to get
  /// a signed axis value (-1.0 to 1.0).
  ///
  /// - Parameters:
  ///   - negative: Action name for negative direction
  ///   - positive: Action name for positive direction
  @inlinable public static func axis(
    negative: String,
    positive: String
  ) -> Double {
    Input.getAxis(
      negativeAction: StringName(negative),
      positiveAction: StringName(positive)
    )
  }

  /// Returns the 2D vector for paired action sets (e.g., movement).
  ///
  /// Combines horizontal and vertical action pairs into a normalized
  /// `Vector2` suitable for 2D movement.
  ///
  /// - Parameters:
  ///   - negativeX: Action name for left/negative-x
  ///   - positiveX: Action name for right/positive-x
  ///   - negativeY: Action name for up/negative-y
  ///   - positiveY: Action name for down/positive-y
  ///   - deadzone: Optional deadzone override (default -1.0 uses InputMap value)
  @inlinable public static func vector(
    negativeX: String,
    positiveX: String,
    negativeY: String,
    positiveY: String,
    deadzone: Double = -1.0
  ) -> Vector2 {
    Input.getVector(
      negativeX: StringName(negativeX),
      positiveX: StringName(positiveX),
      negativeY: StringName(negativeY),
      positiveY: StringName(positiveY),
      deadzone: deadzone
    )
  }
}

// MARK: - Runtime Query Functions

/// Returns a `RuntimeAction` for querying the state of an input action.
///
/// This function provides a clean API for checking action state at runtime
/// without repeatedly constructing `StringName` objects.
///
/// ### Usage:
/// ```swift
/// if Action("jump").isJustPressed {
///   player.jump()
/// }
///
/// let moveSpeed = Action("run").strength * baseSpeed
/// ```
///
/// Note: This overload is distinct from the `Action(_:deadzone:events:)`
/// function used for declaring actions. That version requires the `events`
/// builder parameter.
@inlinable public func Action(_ name: String) -> RuntimeAction {
  RuntimeAction(name: name)
}
