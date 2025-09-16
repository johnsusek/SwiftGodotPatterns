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
