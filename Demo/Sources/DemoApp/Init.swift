import SwiftGodot
import SwiftGodotPatterns

#initSwiftExtension(
  cdecl: "swift_entry_point",
  types: [
    GEventRelay.self,
    GProcessRelay.self,
    PongGame.self,
  ]
)
