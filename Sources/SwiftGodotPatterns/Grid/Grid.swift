import Foundation
import SwiftGodot

public enum CardinalDirection: String, Codable, CaseIterable { case north, south, east, west }

/// A rectangular grid's width/height in cells.
public struct GridSize: Codable {
  public let w: Int
  public let h: Int

  public init(w: Int, h: Int) {
    self.w = w
    self.h = h
  }
}

/// An integer cell coordinate in a grid (x to the right, y downward).
public struct GridPos: Codable, Hashable {
  public let x: Int
  public let y: Int

  public init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }
}

public extension GridPos {
  func toVector2i() -> Vector2i { Vector2i(x: Int32(x), y: Int32(y)) }

  func direction(to p: GridPos) -> CardinalDirection? {
    if p.x == x, p.y == y - 1 { return .north }
    if p.x == x, p.y == y + 1 { return .south }
    if p.x == x - 1, p.y == y { return .west }
    if p.x == x + 1, p.y == y { return .east }
    return nil
  }
}

/// Utility for integer tile grids: bounds checks, neighborhood queries, and tile/world transforms.
///
/// Coordinates are zero-based. `x` grows rightward `y` grows downward.
public protocol Grid: Codable {
  /// Grid dimensions in cells.
  var size: GridSize { get }

  /// Tile size in pixels.
  var tileSize: Float { get }
}

public extension Grid {
  /// Returns whether `p` is inside the grid bounds.
  func inside(_ p: GridPos) -> Bool { p.x >= 0 && p.y >= 0 && p.x < size.w && p.y < size.h }

  // Returns the neighbor in the given direction, or nil if out of bounds.
  func neighbor(in dir: CardinalDirection, from p: GridPos) -> GridPos? {
    switch dir {
    case .north: return inside(GridPos(x: p.x, y: p.y - 1)) ? GridPos(x: p.x, y: p.y - 1) : nil
    case .south: return inside(GridPos(x: p.x, y: p.y + 1)) ? GridPos(x: p.x, y: p.y + 1) : nil
    case .east: return inside(GridPos(x: p.x + 1, y: p.y)) ? GridPos(x: p.x + 1, y: p.y) : nil
    case .west: return inside(GridPos(x: p.x - 1, y: p.y)) ? GridPos(x: p.x - 1, y: p.y) : nil
    }
  }

  /// Returns the 4-connected neighbors (cardinals) inside the grid.
  ///
  /// - Usage:
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
  func toWorld(_ p: GridPos) -> Vector2 { Vector2(Float(p.x) * tileSize + tileSize * 0.5, Float(p.y) * tileSize + tileSize * 0.5) }

  /// Convenience without using GridPos
  func toWorld(_ x: Int, _ y: Int) -> Vector2 { toWorld(GridPos(x: x, y: y)) }

  /// Converts a world position to the containing cell coordinate.
  func toCell(_ v: Vector2) -> GridPos { GridPos(x: Int(floor(v.x / tileSize)), y: Int(floor(v.y / tileSize))) }
}
