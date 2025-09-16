import Foundation
import SwiftGodot

/// A rectangular grid's width/height in cells.
public struct GridSize {
  public let w: Int
  public let h: Int

  public init(w: Int, h: Int) { self.w = w; self.h = h }
}

/// An integer cell coordinate in a grid (x to the right, y downward).
public struct GridPos: Codable, Hashable {
  public let x: Int
  public let y: Int

  public init(x: Int, y: Int) { self.x = x; self.y = y }
}

/// Utility for integer tile grids: bounds checks, neighborhood queries, and tile/world transforms.
///
/// Coordinates are zero-based. `x` grows rightward `y` grows downward.
public protocol Grid {
  /// Grid dimensions in cells.
  var size: GridSize { get }

  /// Tile size in pixels.
  var tileSize: Float { get }
}

public extension Grid {
  /// Returns whether `p` is inside the grid bounds.
  ///
  /// - Parameter p: Cell coordinate to test.
  /// - Returns: `true` if `0 ≤ p.x < w` and `0 ≤ p.y < h`.
  /// - Complexity: O(1).
  func inside(_ p: GridPos) -> Bool { p.x >= 0 && p.y >= 0 && p.x < size.w && p.y < size.h }

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
  func neighbors4(_ p: GridPos) -> [GridPos] {
    let n = [GridPos(x: p.x + 1, y: p.y), GridPos(x: p.x - 1, y: p.y), GridPos(x: p.x, y: p.y + 1), GridPos(x: p.x, y: p.y - 1)]
    return n.filter(inside)
  }

  /// Returns the 8-connected neighbors (cardinals + diagonals) inside the grid.
  ///
  /// - Parameter p: Center cell.
  /// - Returns: Up to eight positions filtered to grid bounds.
  /// - Note: This includes diagonals use `neighbors4` to avoid diagonal motion.
  func neighbors8(_ p: GridPos) -> [GridPos] {
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
  func toWorld(_ p: GridPos) -> Vector2 { Vector2(Float(p.x) * tileSize + tileSize * 0.5, Float(p.y) * tileSize + tileSize * 0.5) }

  /// Convenience without using GridPos
  func toWorld(_ x: Int, _ y: Int) -> Vector2 { toWorld(GridPos(x: x, y: y)) }

  /// Converts a world position to the containing cell coordinate.
  ///
  /// - Parameters:
  ///   - v: World position.
  ///   - tile: Tile size in world units.
  /// - Returns: The floor-divided cell index containing `v`.
  /// - Warning: No bounds check is performed
  //  use `inside(_:)` if needed.
  func toCell(_ v: Vector2) -> GridPos { GridPos(x: Int(floor(v.x / tileSize)), y: Int(floor(v.y / tileSize))) }
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
