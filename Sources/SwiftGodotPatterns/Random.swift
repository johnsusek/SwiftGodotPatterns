import Foundation

public struct Rng {
  private var state: UInt64
  public init(seed: UInt64) { state = seed != 0 ? seed : 0x9E37_79B9_7F4A_7C15 }
  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  public mutating func uniform(_ upper: Int) -> Int { Int(next() % UInt64(max(1, upper))) }
  public mutating func chance(_ p: Double) -> Bool { Double(next() & 0xFFFFFF) / Double(0x1000000) < max(0, min(1, p)) }
}

public struct Weighted<T> {
  private struct Entry { let item: T; let w: Int }
  private let total: Int
  private let items: [Entry]
  public init(_ pairs: [(T, Int)]) {
    items = pairs.filter { $0.1 > 0 }.map { Entry(item: $0.0, w: $0.1) }
    total = items.reduce(0) { $0 + $1.w }
  }

  public func roll(_ rng: inout Rng) -> T? {
    if total <= 0 { return nil }
    var n = rng.uniform(total)
    for e in items {
      n -= e.w; if n < 0 { return e.item }
    }
    return items.last?.item
  }
}
