public struct RunSnapshot: Codable {
  public let seed: UInt64
  public let player: GridPos
  public let depth: Int
  public let discovered: [GridPos]
  public init(seed: UInt64, player: GridPos, depth: Int, discovered: [GridPos]) {
    self.seed = seed; self.player = player; self.depth = depth; self.discovered = discovered
  }
}

public enum SaveIO {
  public static func save<T: Codable>(_ value: T, to url: URL) throws {
    let data = try JSONEncoder().encode(value)
    try data.write(to: url, options: .atomic)
  }

  public static func load<T: Codable>(_: T.Type, from url: URL) throws -> T {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
  }
}
