public struct Rect { public let x: Int; public let y: Int; public let w: Int; public let h: Int
  public var center: GridPos { GridPos(x: x + w / 2, y: y + h / 2) }
}

public enum Tile { case wall, floor }

public enum MapGen {
  public static func dungeon(w: Int, h: Int, rooms: ClosedRange<Int>, rng: inout Rng) -> ([[Tile]], [Rect]) {
    var tiles = Array(repeating: Array(repeating: Tile.wall, count: h), count: w)
    var rs: [Rect] = []
    let count = Int.random(in: rooms, using: &SystemRandomNumberGenerator())
    for _ in 0 ..< count {
      let rw = 4 + rng.uniform(8), rh = 4 + rng.uniform(8)
      let rx = max(1, rng.uniform(w - rw - 1)), ry = max(1, rng.uniform(h - rh - 1))
      let r = Rect(x: rx, y: ry, w: rw, h: rh)
      if rs.contains(where: { overlap($0, r, pad: 1) }) { continue }
      carve(&tiles, r)
      if let prev = rs.last { carveCorridor(&tiles, prev.center, r.center) }
      rs.append(r)
    }
    return (tiles, rs)
  }

  private static func carve(_ t: inout [[Tile]], _ r: Rect) {
    for x in r.x ..< (r.x + r.w) {
      for y in r.y ..< (r.y + r.h) {
        t[x][y] = .floor
      }
    }
  }

  private static func carveCorridor(_ t: inout [[Tile]], _ a: GridPos, _ b: GridPos) {
    var x = a.x, y = a.y
    while x != b.x {
      x += (b.x > x ? 1 : -1); t[x][y] = .floor
    }
    while y != b.y {
      y += (b.y > y ? 1 : -1); t[x][y] = .floor
    }
  }

  private static func overlap(_ a: Rect, _ b: Rect, pad: Int) -> Bool {
    let ax2 = a.x + a.w + pad, ay2 = a.y + a.h + pad
    let bx2 = b.x + b.w + pad, by2 = b.y + b.h + pad
    return !(a.x - pad >= bx2 || b.x - pad >= ax2 || a.y - pad >= by2 || b.y - pad >= ay2)
  }
}
