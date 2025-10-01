import SwiftGodot

@attached(peer)
public macro OnSignal(_ path: String, _ keyPath: Any, flags: Object.ConnectFlags = [])
  = #externalMacro(module: "SwiftGodotPatternsMacros", type: "OnSignalMacro")
