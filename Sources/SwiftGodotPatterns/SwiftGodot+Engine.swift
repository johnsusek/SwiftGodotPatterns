import SwiftGodot

public extension Engine {
  /// Get the current SceneTree, if it exists.
  /// - Returns: The current SceneTree, or nil if it doesn't exist.
  /// ### Usage:
  /// ```swift
  /// if let tree = Engine.getSceneTree() {
  ///   // do something with tree
  /// }
  /// ```
  /// Replaces:
  /// ```swift
  /// if let tree = Engine.getMainLoop() as? SceneTree {
  ///   // do something with tree
  /// }
  /// ```
  static func getSceneTree() -> SceneTree? {
    Engine.getMainLoop() as? SceneTree
  }

  /// Schedule a closure to be called on the next frame.
  /// - Parameter f: The closure to be called.
  /// - Returns: True if the timer was created successfully, else false.
  /// ### Usage:
  /// ```swift
  /// Engine.onNextFrame {
  ///   // do something on the next frame
  /// }
  /// ```
  /// Replaces:
  /// ```swift
  /// if let tree = Engine.getMainLoop() as? SceneTree,
  ///    let timer = tree.createTimer(timeSec: 0.0) {
  ///   _ = timer.timeout.connect {
  ///     // do something on the next frame
  ///   }
  @discardableResult
  static func onNextFrame(_ f: @escaping () -> Void) -> Bool {
    guard let tree = Engine.getMainLoop() as? SceneTree,
          let timer = tree.createTimer(timeSec: 0.0) else { return false }
    _ = timer.timeout.connect { f() }
    return true
  }

  /// Schedule a closure to be called on the next physics frame.
  /// - Parameter f: The closure to be called.
  /// - Returns: True if the timer was created successfully, else false.
  /// ### Usage:
  /// ```swift
  /// Engine.onNextPhysicsFrame {
  ///   // do something on the next physics frame
  /// }
  /// ```
  /// Replaces:
  /// ```swift
  /// if let tree = Engine.getMainLoop() as? SceneTree,
  ///    let timer = tree.createTimer(timeSec: 0.0, processInPhysics: true) {
  ///   _ = timer.timeout.connect {
  ///     // do something on the next physics frame
  ///   }
  /// }
  /// ```
  @discardableResult
  static func onNextPhysicsFrame(_ f: @escaping () -> Void) -> Bool {
    guard let tree = Engine.getMainLoop() as? SceneTree,
          let timer = tree.createTimer(timeSec: 0.0, processInPhysics: true) else { return false }
    _ = timer.timeout.connect { f() }
    return true
  }
}
