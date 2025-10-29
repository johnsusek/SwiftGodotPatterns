import Foundation

/// A common interface for all game "type objects" (data-driven definitions).
///
/// Conforming types are intended to be pure data, they describe things like
/// abilities or items without any engine/runtime behavior. This allows you to
/// author content in JSON/JSONL, load it at runtime, and keep gameplay logic
/// data-driven.
public protocol GameTypeSpec: Hashable {
  var id: String { get }
  var name: String { get }
  var summary: String? { get }
  var tags: Set<String> { get }
}

extension GameTypeSpec {
  @inlinable
  func hasTag(_ t: String) -> Bool { tags.contains(t) }
}

public struct AbilityType: Sendable, Codable, GameTypeSpec {
  public var id: String
  public var name: String
  public var summary: String?
  public var tags: Set<String>
  public var icon: String?
  public var cooldown: Double
  public var costs: [ResourceCost]
  public var effects: [AbilityEffect]

  public init(id: String,
              name: String,
              summary: String? = nil,
              tags: Set<String> = [],
              icon: String? = nil,
              cooldown: Double = 0,
              costs: [ResourceCost] = [],
              effects: [AbilityEffect])
  {
    self.id = id
    self.name = name
    self.summary = summary
    self.tags = tags
    self.icon = icon
    self.cooldown = cooldown
    self.costs = costs
    self.effects = effects
  }
}

public struct TypeRegistry: Sendable {
  public var abilities: [String: AbilityType] = [:]

  public init() {}

  public mutating func register(_ a: AbilityType) { abilities[a.id] = a }

  public mutating func register(abilities: [AbilityType]) {
    for a in abilities {
      register(a)
    }
  }

  public func ability(_ id: String) -> AbilityType? { abilities[id] }

  public func allAbilities(tag: String? = nil) -> [AbilityType] {
    guard let tag else { return Array(abilities.values) }
    return abilities.values.filter { $0.tags.contains(tag) }
  }

  public mutating func loadAbilitiesJSON(_ data: Data) throws {
    let arr = try decodeMany(AbilityType.self, from: data)
    register(abilities: arr)
  }

  public func validate(references: Bool = true) -> [String] {
    var issues: [String] = []

    for (id, a) in abilities {
      if a.cooldown < 0 { issues.append("Ability[\(id)]: cooldown < 0") }
      for e in a.effects {
        if case let .addStatus(statusId, _, _) = e, references && abilities[statusId] == nil {
          issues.append("Ability[\(id)]: addStatus references missing id '\(statusId)'")
        }
      }
    }

    return issues
  }
}

// MARK: - Decoding Utilities

/// Decodes either a JSON array of `T` or JSONL (newline-delimited JSON),
/// returning a homogeneous array of decoded values.
func decodeMany<T: Decodable>(_: T.Type, from data: Data) throws -> [T] {
  if let first = data.first, first == UInt8(ascii: "[") {
    return try JSONDecoder().decode([T].self, from: data)
  }
  var out: [T] = []
  out.reserveCapacity(64)
  var start = data.startIndex
  while start < data.endIndex {
    guard let nl = data[start ..< data.endIndex].firstIndex(of: 0x0A) else {
      let slice = data[start ..< data.endIndex]
      if !slice.isEmpty { try out.append(JSONDecoder().decode(T.self, from: slice)) }
      break
    }
    let slice = data[start ..< nl]
    if !slice.isEmpty { try out.append(JSONDecoder().decode(T.self, from: slice)) }
    start = data.index(after: nl)
  }
  return out
}
