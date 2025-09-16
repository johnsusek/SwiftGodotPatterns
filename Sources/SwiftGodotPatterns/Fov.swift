import Foundation

/// Tiles used by the field-of-view pass.
public enum FovTile { case open, wall }

/// Recursive shadowcasting field-of-view (FOV) on an integer grid.
///
/// Visibility is computed in eight octants around `origin` up to `radius` cells,
/// stopping at walls (opaque tiles). The origin is always visible.
public enum Fov {
  /// Computes visible cells from `origin`.
  ///
  /// - Parameters:
  ///   - map: Returns `.wall` for opaque cells, `.open` otherwise.
  ///   - grid: Grid bounds for clipping.
  ///   - origin: Source cell (always included).
  ///   - radius: Maximum range in cells (Euclidean squared check).
  /// - Returns: A set of visible cell positions.
  /// - Note: This implementation minimizes floating-point math and clips to `grid`.
  public static func compute(map: (GridPos) -> FovTile,
                             grid: Grid,
                             origin: GridPos,
                             radius: Int) -> Set<GridPos>
  {
    var visible: Set<GridPos> = [origin]

    func blocked(_ p: GridPos) -> Bool { map(p) == .wall }

    // 8 octants
    for oct in 0 ..< 8 {
      shadowcast(oct: oct, origin: origin, radius: radius, grid: grid, blocked: blocked, out: &visible)
    }

    return visible
  }

  // Shadowcasting adapted to integer grid; keeps floats minimal.
  private static func shadowcast(oct: Int, origin: GridPos, radius: Int, grid: Grid,
                                 blocked: (GridPos) -> Bool, out: inout Set<GridPos>)
  {
    var row = 1
    var startSlope = -1.0
    let endSlope = 1.0

    while row <= radius {
      var prevBlocked = false
      var nextStartSlope = startSlope
      let dxMin = Int(round(Double(row) * startSlope))
      let dxMax = Int(round(Double(row) * endSlope))

      for dx in dxMin ... dxMax {
        let dy = row
        let (cx, cy) = transform(oct, dx, dy)
        let p = GridPos(x: origin.x + cx, y: origin.y + cy)

        if !grid.inside(p) { continue }

        let dist2 = dx * dx + dy * dy

        if dist2 <= radius * radius { out.insert(p) }

        let tileBlocked = blocked(p)

        if tileBlocked {
          if !prevBlocked { nextStartSlope = slope(dx - 1, dy, dx, dy) }
          prevBlocked = true
        } else {
          if prevBlocked {
            shadowcast(oct: oct, origin: origin, radius: radius, grid: grid, blocked: blocked, out: &out)
            startSlope = nextStartSlope
            nextStartSlope = slope(dx, dy, dx + 1, dy)
          }
          prevBlocked = false
        }
      }

      if prevBlocked { startSlope = nextStartSlope }

      row += 1
    }

    func slope(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int) -> Double { Double(x1 + x2) / Double(y1 + y2 + (y1 == -y2 ? 1 : 0)) }

    func transform(_ o: Int, _ x: Int, _ y: Int) -> (Int, Int) {
      switch o {
      case 0: return (x, y)
      case 1: return (y, x)
      case 2: return (-y, x)
      case 3: return (-x, y)
      case 4: return (-x, -y)
      case 5: return (-y, -x)
      case 6: return (y, -x)
      default: return (x, -y)
      }
    }
  }
}
