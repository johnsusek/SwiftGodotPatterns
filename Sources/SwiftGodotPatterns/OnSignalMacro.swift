// Sources/SignalRuntime/SignalBinders.swift
import SwiftGodot

/// Property wrapper macro that binds a Godot signal to a Swift method.
///
/// ### Examples:
/// ```swift
/// @OnSignal("PlayButton", \Button.pressed)
/// func onPlay(_ sender: Button) { GD.print("Play!") }
/// ```
///
/// ```swift
/// @OnSignal("Area2D", \Area2D.bodyEntered)
/// func onEnter(_ sender: Area2D, _ body: Node) { /* ... */ }
/// ```
///

@attached(peer)
public macro OnSignal(_ path: String, _ keyPath: Any, flags: Object.ConnectFlags = [])
  = #externalMacro(module: "SwiftGodotPatternsMacros", type: "OnSignalMacro")

/// Binds a zero-argument Godot signal (`SimpleSignal`) to a Swift closure.
///
/// ### Example
/// ```swift
/// @OnSignal("PlayButton", \Button.pressed)
/// func onPlay(_ sender: Button) { GD.print("Play!") }
/// ```
final class _SignalBinder0<T: Object>: _AutoBindProp {
  /// Node path (relative to the host) used to resolve the signal sender.
  let path: String
  /// Key path to a `SimpleSignal` on the sender.
  let kp: KeyPath<T, SimpleSignal>
  /// Connection flags (e.g. `.deferred`, `.oneShot`).
  let flags: Object.ConnectFlags
  /// Handler invoked when the signal emits. Receives the typed sender.
  let f: (T) -> Void

  private var didConnect = false

  /// Creates a zero-arg signal binder.
  init(path: String, keyPath: KeyPath<T, SimpleSignal>, flags: Object.ConnectFlags, handler: @escaping (T) -> Void) {
    self.path = path; kp = keyPath; self.flags = flags; f = handler
  }

  /// Resolves the sender and connects the handler to the signal.
  func _bind(host: Node) {
    if didConnect { return }
    guard let sender = host.getNode(path) as? T else { return }
    _ = sender[keyPath: kp].connect(flags: flags) { self.f(sender) }
    didConnect = true
  }
}

/// Binds a one-argument Godot signal to a Swift closure.
///
/// ### Example
/// ```swift
/// @OnSignal("Area2D", \Area2D.bodyEntered)
/// func onEnter(_ sender: Area2D, _ body: Node) { /* ... */ }
/// ```
final class _SignalBinder1<T: Object, A: _GodotBridgeable>: _AutoBindProp {
  let path: String
  /// Key path to a `SignalWithArguments<A>` on the sender.
  let kp: KeyPath<T, SignalWithArguments<A>>
  let flags: Object.ConnectFlags
  /// Handler invoked as `f(sender, a0)`.
  let f: (T, A) -> Void

  private var didConnect = false

  /// Creates a one-arg signal binder.
  init(path: String, keyPath: KeyPath<T, SignalWithArguments<A>>, flags: Object.ConnectFlags, handler: @escaping (T, A) -> Void) {
    self.path = path; kp = keyPath; self.flags = flags; f = handler
  }

  /// Resolves the sender and connects the handler to the signal.
  func _bind(host: Node) {
    if didConnect { return }
    guard let sender = host.getNode(path) as? T else { return }
    _ = sender[keyPath: kp].connect(flags: flags) { a0 in self.f(sender, a0) }
    didConnect = true
  }
}

/// Binds a two-argument Godot signal to a Swift closure.
///
/// ### Example
/// ```swift
/// @OnSignal("Area2D", \Area2D.areaEntered)
/// func onArea(_ sender: Area2D, _ area: Area2D, _ local: int32) { /* ... */ }
/// ```
final class _SignalBinder2<T: Object, A: _GodotBridgeable, B: _GodotBridgeable>: _AutoBindProp {
  let path: String
  /// Key path to a `SignalWithArguments<A, B>` on the sender.
  let kp: KeyPath<T, SignalWithArguments<A, B>>
  let flags: Object.ConnectFlags
  /// Handler invoked as `f(sender, a0, a1)`.
  let f: (T, A, B) -> Void

  private var didConnect = false

  /// Creates a two-arg signal binder.
  init(path: String, keyPath: KeyPath<T, SignalWithArguments<A, B>>, flags: Object.ConnectFlags, handler: @escaping (T, A, B) -> Void) {
    self.path = path; kp = keyPath; self.flags = flags; f = handler
  }

  /// Resolves the sender and connects the handler to the signal.
  func _bind(host: Node) {
    if didConnect { return }
    guard let sender = host.getNode(path) as? T else { return }
    _ = sender[keyPath: kp].connect(flags: flags) { a0, a1 in self.f(sender, a0, a1) }
    didConnect = true
  }
}

/// Binds a three-argument Godot signal to a Swift closure.
///
/// ### Example
/// ```swift
/// @OnSignal("SomeNode", \SomeNode.someSignal)
/// func onSome(_ sender: SomeNode, _ a: Int32, _ b: Double, _ c: Node) { /* ... */ }
/// ```
final class _SignalBinder3<T: Object, A: _GodotBridgeable, B: _GodotBridgeable, C: _GodotBridgeable>: _AutoBindProp {
  let path: String
  /// Key path to a `SignalWithArguments<A, B, C>` on the sender.
  let kp: KeyPath<T, SignalWithArguments<A, B, C>>
  let flags: Object.ConnectFlags
  /// Handler invoked as `f(sender, a0, a1, a2)`.
  let f: (T, A, B, C) -> Void

  private var didConnect = false

  /// Creates a three-arg signal binder.
  init(path: String, keyPath: KeyPath<T, SignalWithArguments<A, B, C>>, flags: Object.ConnectFlags, handler: @escaping (T, A, B, C) -> Void) {
    self.path = path; kp = keyPath; self.flags = flags; f = handler
  }

  /// Resolves the sender and connects the handler to the signal.
  func _bind(host: Node) {
    if didConnect { return }
    guard let sender = host.getNode(path) as? T else { return }
    _ = sender[keyPath: kp].connect(flags: flags) { a0, a1, a2 in self.f(sender, a0, a1, a2) }
    didConnect = true
  }
}
