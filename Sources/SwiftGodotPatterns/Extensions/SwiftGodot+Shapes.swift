import SwiftGodot

// MARK: Convenience initializers

public extension RectangleShape2D {
  convenience init(w: Float, h: Float) {
    self.init()
    size = Vector2(x: w, y: h)
  }

  convenience init(size: Vector2) {
    self.init()
    self.size = size
  }
}

public extension CircleShape2D {
  /// Convenience initializer.
  convenience init(radius: Double) {
    self.init()
    self.radius = radius
  }
}

public extension CapsuleShape2D {
  /// Convenience initializer.
  convenience init(radius: Double, height: Double) {
    self.init()
    self.radius = radius
    self.height = height
  }
}
