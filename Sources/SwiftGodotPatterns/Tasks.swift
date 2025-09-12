public protocol Task { mutating func tick(dt: Double) -> Bool } // true = done

public struct Wander: Task {
  public var pos: GridPos; public let grid: Grid; public let passable: (GridPos) -> Bool; public let move: (GridPos) -> Void
  public mutating func tick(dt _: Double) -> Bool {
    let dirs = grid.neighbors4(pos).filter(passable)
    if let next = dirs.randomElement() { pos = next; move(next) }
    return true
  }
}

public struct ChaseDijkstra: Task {
  public var pos: GridPos; public let field: [GridPos: Int]; public let move: (GridPos) -> Void; public let grid: Grid
  public mutating func tick(dt _: Double) -> Bool {
    let ns = grid.neighbors4(pos)
    let best = ns.min { (field[$0] ?? .max) < (field[$1] ?? .max) }
    if let b = best, let db = field[b], let d0 = field[pos], db < d0 { pos = b; move(b) }
    return true
  }
}
