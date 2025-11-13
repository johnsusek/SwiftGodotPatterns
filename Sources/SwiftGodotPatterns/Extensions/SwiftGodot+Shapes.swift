import SwiftGodot

// MARK: 2D Shape Convenience Initializers

public extension RectangleShape2D {
  convenience init(w: Float, h: Float) {
    self.init()
    size = Vector2(x: w, y: h)
  }

  convenience init(w: Int, h: Int) {
    self.init()
    size = Vector2(x: Float(w), y: Float(h))
  }

  convenience init(size: Vector2) {
    self.init()
    self.size = size
  }
}

public extension CircleShape2D {
  convenience init(radius: Double) {
    self.init()
    self.radius = radius
  }

  convenience init(radius: Int) {
    self.init()
    self.radius = Double(radius)
  }
}

public extension CapsuleShape2D {
  convenience init(radius: Double, height: Double) {
    self.init()
    self.radius = radius
    self.height = height
  }

  convenience init(radius: Int, height: Int) {
    self.init()
    self.radius = Double(radius)
    self.height = Double(height)
  }
}

public extension SegmentShape2D {
  convenience init(a: Vector2, b: Vector2) {
    self.init()
    self.a = a
    self.b = b
  }
}

public extension SeparationRayShape2D {
  convenience init(length: Double) {
    self.init()
    self.length = length
  }

  convenience init(length: Int) {
    self.init()
    self.length = Double(length)
  }
}

public extension WorldBoundaryShape2D {
  convenience init(normal: Vector2, distance: Double) {
    self.init()
    self.normal = normal
    self.distance = distance
  }
}

public extension ConvexPolygonShape2D {
  convenience init(points: PackedVector2Array) {
    self.init()
    self.points = points
  }
}

public extension ConcavePolygonShape2D {
  convenience init(segments: PackedVector2Array) {
    self.init()
    self.segments = segments
  }
}

// MARK: 3D Shape Convenience Initializers

public extension BoxShape3D {
  convenience init(size: Vector3) {
    self.init()
    self.size = size
  }

  convenience init(x: Float, y: Float, z: Float) {
    self.init()
    self.size = Vector3(x: x, y: y, z: z)
  }

  convenience init(x: Int, y: Int, z: Int) {
    self.init()
    self.size = Vector3(x: Float(x), y: Float(y), z: Float(z))
  }
}

public extension SphereShape3D {
  convenience init(radius: Double) {
    self.init()
    self.radius = radius
  }

  convenience init(radius: Int) {
    self.init()
    self.radius = Double(radius)
  }
}

public extension CapsuleShape3D {
  convenience init(radius: Double, height: Double) {
    self.init()
    self.radius = radius
    self.height = height
  }

  convenience init(radius: Int, height: Int) {
    self.init()
    self.radius = Double(radius)
    self.height = Double(height)
  }
}

public extension CylinderShape3D {
  convenience init(radius: Double, height: Double) {
    self.init()
    self.radius = radius
    self.height = height
  }

  convenience init(radius: Int, height: Int) {
    self.init()
    self.radius = Double(radius)
    self.height = Double(height)
  }
}

public extension SeparationRayShape3D {
  convenience init(length: Double) {
    self.init()
    self.length = length
  }

  convenience init(length: Int) {
    self.init()
    self.length = Double(length)
  }
}

public extension WorldBoundaryShape3D {
  convenience init(plane: Plane) {
    self.init()
    self.plane = plane
  }
}

public extension ConvexPolygonShape3D {
  convenience init(points: PackedVector3Array) {
    self.init()
    self.points = points
  }
}
