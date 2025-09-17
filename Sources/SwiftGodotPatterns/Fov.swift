import Foundation

/// Tiles used by the field-of-view pass.
public enum FovTile { case open, wall }

/// Recursive shadowcasting field-of-view (FOV) on an integer grid.
///
/// Visibility is computed in eight octants around `origin` up to `radius` cells,
/// stopping at walls (opaque tiles). The origin is always visible.
public enum Fov {
  public static func compute(map: (GridPos) -> FovTile, grid: Grid, origin: GridPos, radius: Int) -> Set<GridPos> {
    var out: Set<GridPos> = [origin]
    for oct in 0 ..< 8 {
      scan(oct, origin, radius, 1, 1.0, 0.0, map, grid, &out)
    }
    return out
  }

  private static func scan(_ oct: Int, _ o: GridPos, _ r: Int, _ row: Int, _ start: Double, _ end: Double,
                           _ map: (GridPos) -> FovTile, _ grid: Grid, _ out: inout Set<GridPos>)
  {
    if start < end || row > r { return }
    var nextStart = start
    var blocked = false
    let y = row
    var x = Int(floor(Double(y) * nextStart + 0.5))
    let xEnd = Int(floor(Double(y) * end + 0.5))
    while x >= xEnd {
      let (dx, dy) = (x, y)
      let (cx, cy) = tf(oct, dx, dy)
      let p = GridPos(x: o.x + cx, y: o.y + cy)
      let lSlope = (Double(x) - 0.5) / (Double(y) + 0.5)
      let rSlope = (Double(x) + 0.5) / (Double(y) - 0.5)

      if grid.inside(p) {
        if dx * dx + dy * dy <= r * r { out.insert(p) }
        if blocked {
          if map(p) == .wall { nextStart = rSlope } else {
            blocked = false
            scan(oct, o, r, row + 1, nextStart, lSlope, map, grid, &out)
          }
        } else {
          if map(p) == .wall {
            blocked = true
            scan(oct, o, r, row + 1, nextStart, lSlope, map, grid, &out)
            nextStart = rSlope
          }
        }
      }
      x -= 1
    }
    if !blocked { scan(oct, o, r, row + 1, nextStart, end, map, grid, &out) }
  }

  @inline(__always) private static func tf(_ o: Int, _ x: Int, _ y: Int) -> (Int, Int) {
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
