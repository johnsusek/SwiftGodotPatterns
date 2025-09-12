import Foundation
import SwiftGodot

/// A rectangular grid's width/height in cells.
public struct GridSize {
  public let w: Int
  public let h: Int
}

/// An integer cell coordinate in a grid (x to the right, y downward).
public struct GridPos: Codable, Hashable {
  public let x: Int
  public let y: Int
}

/// Utility for integer tile grids: bounds checks, neighborhood queries, and tile/world transforms.
///
/// Coordinates are zero-based. `x` grows rightward `y` grows downward.
public struct Grid {
  /// Grid dimensions in cells.
  public let size: GridSize

  /// Creates a grid of `w × h` cells.
  ///
  /// - Parameters:
  ///   - w: Width in cells.
  ///   - h: Height in cells.
  public init(_ w: Int, _ h: Int) { size = .init(w: w, h: h) }

  /// Returns whether `p` is inside the grid bounds.
  ///
  /// - Parameter p: Cell coordinate to test.
  /// - Returns: `true` if `0 ≤ p.x < w` and `0 ≤ p.y < h`.
  /// - Complexity: O(1).
  public func inside(_ p: GridPos) -> Bool { p.x >= 0 && p.y >= 0 && p.x < size.w && p.y < size.h }

  /// Returns the 4-connected neighbors (cardinals) inside the grid.
  ///
  /// - Parameter p: Center cell.
  /// - Returns: Up to four positions (left, right, up, down) filtered to grid bounds.
  /// - Example:
  ///   ```swift
  ///   let grid = Grid(3, 3)
  ///   grid.neighbors4(GridPos(x: 1, y: 1))  // 4 cells
  ///   grid.neighbors4(GridPos(x: 0, y: 0))  // 2 cells (right, down)
  ///   ```
  public func neighbors4(_ p: GridPos) -> [GridPos] {
    let n = [GridPos(x: p.x + 1, y: p.y), GridPos(x: p.x - 1, y: p.y), GridPos(x: p.x, y: p.y + 1), GridPos(x: p.x, y: p.y - 1)]
    return n.filter(inside)
  }

  /// Returns the 8-connected neighbors (cardinals + diagonals) inside the grid.
  ///
  /// - Parameter p: Center cell.
  /// - Returns: Up to eight positions filtered to grid bounds.
  /// - Note: This includes diagonals use `neighbors4` to avoid diagonal motion.
  public func neighbors8(_ p: GridPos) -> [GridPos] {
    var r: [GridPos] = []

    r.reserveCapacity(8)

    for dy in -1 ... 1 {
      for dx in -1 ... 1 where dx != 0 || dy != 0 {
        let q = GridPos(x: p.x + dx, y: p.y + dy)
        if inside(q) { r.append(q) }
      }
    }

    return r
  }

  /// Converts a cell coordinate to a Godot world position at the center of the tile.
  ///
  /// - Parameters:
  ///   - p: Cell coordinate.
  ///   - tile: Tile size in world units.
  /// - Returns: A `Vector2` centered in the tile: `(p.x + 0.5, p.y + 0.5) * tile`.
  public func toWorld(_ p: GridPos, tile: Float) -> Vector2 { Vector2(Float(p.x) * tile + tile * 0.5, Float(p.y) * tile + tile * 0.5) }

  /// Converts a world position to the containing cell coordinate.
  ///
  /// - Parameters:
  ///   - v: World position.
  ///   - tile: Tile size in world units.
  /// - Returns: The floor-divided cell index containing `v`.
  /// - Warning: No bounds check is performed
  //  use `inside(_:)` if needed.
  public func toCell(_ v: Vector2, tile: Float) -> GridPos { GridPos(x: Int(floor(v.x / tile)), y: Int(floor(v.y / tile))) }
}

/// Multi-source, uniform-cost distance transform (Dijkstra) over a grid.
///
/// `solve` treats each passable step as cost 1, starting from one or more goal cells
/// and expanding outward (useful for “nearest goal” queries and flood-fills).
public enum Dijkstra {
  /// A large sentinel distance used as “infinity.”
  public static let inf = Int.max / 4

  /// Computes shortest path distances from any of `goals` to all reachable cells.
  ///
  /// - Parameters:
  ///   - grid: Grid providing neighborhood topology.
  ///   - passable: Predicate determining if a cell may be traversed.
  ///   - goals: One or more seed cells. Non-passable goals are ignored.
  ///   - diagonal: If `true`, uses 8-connected neighbors
  //  otherwise 4-connected.
  /// - Returns: A dictionary mapping each reachable cell to its integer distance (0 at goals).
  /// - Example:
  ///   ```swift
  ///   let grid = Grid(10, 10)
  ///   let walls: Set<GridPos> = []
  ///   let dist = Dijkstra.solve(grid: grid, passable: { !walls.contains($0) }, goals: [GridPos(x: 5, y: 5)])
  ///   dist[GridPos(x: 5, y: 5)] == 0
  ///   ```
  /// - Complexity: O(V + E) for the explored region (linear in reachable cells and edges).
  public static func solve(grid: Grid,
                           passable: (GridPos) -> Bool,
                           goals: [GridPos],
                           diagonal: Bool = false) -> [GridPos: Int]
  {
    var dist: [GridPos: Int] = [:]
    var queue: [GridPos] = []

    for g in goals where passable(g) {
      dist[g] = 0
      queue.append(g)
    }

    var head = 0

    while head < queue.count {
      let p = queue[head]
      head += 1

      let nd = (dist[p] ?? inf) + 1
      let ns = diagonal ? grid.neighbors8(p) : grid.neighbors4(p)

      for q in ns where passable(q) {
        if nd < (dist[q] ?? inf) { dist[q] = nd
          queue.append(q)
        }
      }
    }

    return dist
  }
}

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

/// Grid-based A* pathfinding with Manhattan heuristic.
///
/// Uses unit edge costs (each step costs 1). Returns the path including `start` and `goal`
/// if reachable, otherwise an empty array.
public enum AStar {
  /// Finds a path from `start` to `goal`.
  ///
  /// - Parameters:
  ///   - grid: Grid providing neighborhood topology.
  ///   - start: Starting cell.
  ///   - goal: Target cell.
  ///   - passable: Predicate determining if a cell may be traversed.
  ///   - diagonal: If `true`, uses 8-connected neighbors
  //  otherwise 4-connected.
  /// - Returns: The path as a list of cells from `start` to `goal`, or `[]` if none exists.
  /// - Important: Heuristic is Manhattan distance, optimal for 4-connected motion with unit costs.
  /// - SeeAlso: ``Dijkstra`` for distance fields and multi-source expansion.
  public static func find(grid: Grid,
                          start: GridPos,
                          goal: GridPos,
                          passable: (GridPos) -> Bool,
                          diagonal: Bool = false) -> [GridPos]
  {
    if start == goal { return [start] }

    var open: Set<GridPos> = [start]
    var came: [GridPos: GridPos] = [:]
    var g: [GridPos: Int] = [start: 0]
    var f: [GridPos: Int] = [start: h(start, goal)]

    while !open.isEmpty {
      let current = open.min(by: { (f[$0] ?? .max) < (f[$1] ?? .max) })!

      if current == goal { return reconstruct(came, current) }

      open.remove(current)

      let ns = diagonal ? grid.neighbors8(current) : grid.neighbors4(current)

      for n in ns where passable(n) {
        let tentative = (g[current] ?? .max) + 1

        if tentative >= (g[n] ?? .max) { continue }

        came[n] = current
        g[n] = tentative
        f[n] = tentative + h(n, goal)

        open.insert(n)
      }
    }

    return []
  }

  /// Manhattan distance heuristic (L1 norm).
  private static func h(_ a: GridPos, _ b: GridPos) -> Int { abs(a.x - b.x) + abs(a.y - b.y) }

  /// Reconstructs the path by walking parent links back to the start.
  ///
  /// - Parameters:
  ///   - came: Parent map produced during search.
  ///   - end: Final node (usually the goal).
  /// - Returns: Reversed parent chain from start to `end`.
  private static func reconstruct(_ came: [GridPos: GridPos], _ end: GridPos) -> [GridPos] {
    var p = end, out: [GridPos] = [p]

    while let c = came[p] {
      p = c
      out.append(p)
    }

    return out.reversed()
  }
}
