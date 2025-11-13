import SwiftGodot

// MARK: - Sprite Anchor/Pivot Extensions

public extension GNode where T: Sprite2D {
  /// Anchors a sprite within a container using pivot points (0-1 normalized coordinates).
  ///
  /// This is useful when working with LD entities where you want to position a sprite
  /// within the entity's bounding box using the same pivot system as LD.
  ///
  /// - Parameters:
  ///   - spriteSize: The actual size of the sprite texture in pixels
  ///   - within: The size of the container/entity bounds
  ///   - pivot: Pivot point as Vector2 (0-1 normalized: 0=top/left, 0.5=center, 1=bottom/right)
  ///
  /// ## Example
  /// ```swift
  /// // Position a 16x17 sprite at bottom-center of a 24x24 entity
  /// Sprite2D$()
  ///   .res(\.texture, "chest.png")
  ///   .anchor(Vector2(16, 17), within: entity.size, pivot: Vector2(0.5, 1.0))
  ///
  /// // Use entity's pivot from LD
  /// Sprite2D$()
  ///   .res(\.texture, "chest.png")
  ///   .anchor(Vector2(16, 17), within: entity.size, pivot: entity.pivotVector)
  /// ```
  func anchor(_ spriteSize: Vector2, within containerSize: Vector2, pivot: Vector2 = Vector2(0.5, 1.0)) -> Self {
    let offsetValue = Vector2(
      x: (containerSize.x - spriteSize.x) * (pivot.x - 0.5),
      y: (containerSize.y - spriteSize.y) * (pivot.y - 0.5)
    )
    return offset(offsetValue)
  }
}
