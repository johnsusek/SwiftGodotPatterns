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
