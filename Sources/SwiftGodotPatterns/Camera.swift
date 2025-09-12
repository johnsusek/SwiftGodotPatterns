import SwiftGodot

/// A simple 2D camera clamping utility.
/// Clamps a Camera2D's position within a specified world rectangle,
/// ensuring the camera does not show areas outside the defined bounds.
///
/// Example:
/// ```swift
/// let cameraClamp = CameraClamp2D()
/// cameraClamp.worldRect = Rect2(x: 0, y: 0, width: 1024, height: 768)
/// // In your game loop or update method:
/// cameraClamp.apply(cameraNode, viewport: getViewport().size)
/// ```
public final class CameraClamp2D {
  public var worldRect = Rect2()

  public init() {}

  public func apply(_ cam: Camera2D, viewport: Vector2) {
    let half = viewport * 0.5
    var pos = cam.globalPosition

    pos.x = max(worldRect.position.x + half.x, min(worldRect.end.x - half.x, pos.x))
    pos.y = max(worldRect.position.y + half.y, min(worldRect.end.y - half.y, pos.y))
    cam.globalPosition = pos
  }
}
