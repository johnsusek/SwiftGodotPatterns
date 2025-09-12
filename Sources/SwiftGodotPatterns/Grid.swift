import SwiftGodot

public struct GridSize { public let w: Int; public let h: Int }
public struct GridPos: Hashable { public let x: Int; public let y: Int }

public struct Grid {
  public let size: GridSize
  public init(_ w: Int, _ h: Int) { size = .init(w: w, h: h) }
  public func inside(_ p: GridPos) -> Bool { p.x >= 0 && p.y >= 0 && p.x < size.w && p.y < size.h }
  public func neighbors4(_ p: GridPos) -> [GridPos] {
    let n = [GridPos(x: p.x + 1, y: p.y), GridPos(x: p.x - 1, y: p.y), GridPos(x: p.x, y: p.y + 1), GridPos(x: p.x, y: p.y - 1)]
    return n.filter(inside)
  }

  public func neighbors8(_ p: GridPos) -> [GridPos] {
    var r: [GridPos] = []; r.reserveCapacity(8)
    for dy in -1 ... 1 {
      for dx in -1 ... 1 where dx != 0 || dy != 0 {
        let q = GridPos(x: p.x + dx, y: p.y + dy); if inside(q) { r.append(q) }
      }
    }
    return r
  }

  public func toWorld(_ p: GridPos, tile: Float) -> Vector2 { Vector2(Float(p.x) * tile + tile * 0.5, Float(p.y) * tile + tile * 0.5) }
  public func toCell(_ v: Vector2, tile: Float) -> GridPos { GridPos(x: Int(floor(v.x / tile)), y: Int(floor(v.y / tile))) }
}

public enum Dijkstra {
  public static let inf = Int.max / 4

  public static func solve(grid: Grid,
                           passable: (GridPos) -> Bool,
                           goals: [GridPos],
                           diagonal: Bool = false) -> [GridPos: Int]
  {
    var dist: [GridPos: Int] = [:]
    var queue: [GridPos] = []
    for g in goals where passable(g) {
      dist[g] = 0; queue.append(g)
    }
    var head = 0
    while head < queue.count {
      let p = queue[head]; head += 1
      let nd = (dist[p] ?? inf) + 1
      let ns = diagonal ? grid.neighbors8(p) : grid.neighbors4(p)
      for q in ns where passable(q) {
        if nd < (dist[q] ?? inf) { dist[q] = nd; queue.append(q) }
      }
    }
    return dist
  }
}

public enum FovTile { case open, wall }
public enum Fov {
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
    var endSlope = 1.0
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

public enum AStar {
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

  private static func h(_ a: GridPos, _ b: GridPos) -> Int { abs(a.x - b.x) + abs(a.y - b.y) }
  private static func reconstruct(_ came: [GridPos: GridPos], _ end: GridPos) -> [GridPos] {
    var p = end, out: [GridPos] = [p]
    while let c = came[p] {
      p = c; out.append(p)
    }
    return out.reversed()
  }
}
