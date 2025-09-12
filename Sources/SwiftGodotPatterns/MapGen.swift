import Foundation

/// Axis-aligned integer rectangle in tile/grid coordinates.
/// The origin (`x`,`y`) is the top-left corner; width/height are in tiles.
public struct Rect {
  public let x: Int
  public let y: Int
  public let w: Int
  public let h: Int
  /// Center tile of the rectangle (rounded down).
  public var center: GridPos { GridPos(x: x + w / 2, y: y + h / 2) }
}

/// A single map cell.
public enum Tile {
  /// Impassable terrain.
  case wall
  /// Walkable terrain.
  case floor
}

/// Procedural dungeon generation utilities.
///
/// The generator lays out non-overlapping rectangular rooms and connects
/// each new room to the previous one with an L-shaped corridor
/// (first horizontal, then vertical).
public enum MapGen {
  /// Generates a simple room-and-corridor dungeon.
  ///
  /// - Parameters:
  ///   - w: Map width in tiles. Also the outer bound for `tiles[x][y]` indexing.
  ///   - h: Map height in tiles.
  ///   - rooms: Inclusive range for the target number of rooms to attempt.
  /// - Returns: `(tiles, rooms)` where `tiles` is indexed `[x][y]` and `rooms` are the carved `Rect`s.
  public static func dungeon(w: Int, h: Int, rooms: ClosedRange<Int>) -> ([[Tile]], [Rect]) {
    var tiles = Array(repeating: Array(repeating: Tile.wall, count: Int(h)), count: Int(w))
    var rs: [Rect] = []
    let count = Int.random(in: rooms)
    var rng = SystemRandomNumberGenerator()

    for _ in 0 ..< count {
      // update to use foundation rng
      let rw = 4 + Int.random(in: 0 ... 8, using: &rng), rh = 4 + Int.random(in: 0 ... 8, using: &rng)
      let rx = max(1, Int.random(in: 1 ... (w - rw - 1), using: &rng)), ry = max(1, Int.random(in: 1 ... (h - rh - 1), using: &rng))
      let r = Rect(x: rx, y: ry, w: rw, h: rh)

      if rs.contains(where: { overlap($0, r, pad: 1) }) { continue }

      carve(&tiles, r)

      if let prev = rs.last { carveCorridor(&tiles, prev.center, r.center) }

      rs.append(r)
    }

    return (tiles, rs)
  }

  /// Fills a rectangular region with `.floor`.
  private static func carve(_ t: inout [[Tile]], _ r: Rect) {
    for x in r.x ..< (r.x + r.w) {
      for y in r.y ..< (r.y + r.h) {
        t[x][y] = .floor
      }
    }
  }

  /// Carves an L-shaped corridor between two points (x first, then y).
  private static func carveCorridor(_ t: inout [[Tile]], _ a: GridPos, _ b: GridPos) {
    var x = a.x, y = a.y

    while x != b.x {
      x += (b.x > x ? 1 : -1)
      t[x][y] = .floor
    }

    while y != b.y {
      y += (b.y > y ? 1 : -1)
      t[x][y] = .floor
    }
  }

  /// Returns `true` if rectangles overlap when expanded by `pad` tiles.
  private static func overlap(_ a: Rect, _ b: Rect, pad: Int) -> Bool {
    let ax2 = a.x + a.w + pad, ay2 = a.y + a.h + pad
    let bx2 = b.x + b.w + pad, by2 = b.y + b.h + pad

    return !(a.x - pad >= bx2 || b.x - pad >= ax2 || a.y - pad >= by2 || b.y - pad >= ay2)
  }
}
