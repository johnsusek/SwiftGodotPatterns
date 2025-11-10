import SwiftGodot
import SwiftGodotPatterns

#initSwiftExtension(
  cdecl: "swift_entry_point",
  types: [
    GEventRelay.self,
    GProcessRelay.self,
    AsteroidsGame.self,
    PongGame.self,
    BreakoutGame.self,
    SpaceInvadersGame.self,
    PlatformerGame.self,
  ]
)
