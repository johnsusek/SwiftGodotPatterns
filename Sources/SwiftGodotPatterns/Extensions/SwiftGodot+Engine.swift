import SwiftGodot

public extension Engine {
  static func getSceneTree() -> SceneTree? {
    Engine.getMainLoop() as? SceneTree
  }

  @discardableResult
  static func onNextFrame(_ f: @escaping () -> Void) -> Bool {
    guard let tree = Engine.getMainLoop() as? SceneTree,
          let timer = tree.createTimer(timeSec: 0.0) else { return false }
    _ = timer.timeout.connect { f() }
    return true
  }
}

import SwiftGodot
