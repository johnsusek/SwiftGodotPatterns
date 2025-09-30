import Foundation

/// In-memory index of all loaded type objects (abilities, items, etc.).
///
/// Provides registration, snapshotting, overlay, queries by tag, and validation.
///
/// ### Usage
/// ```swift
/// var reg = TypeRegistry()
/// let data = Data() // JSON data
/// try reg.loadAbilitiesJSON(data)
/// let issues = reg.validate()
/// if !issues.isEmpty { issues.forEach { print("Type issue: \($0)") } }
///
/// if let heal = reg.ability("heal_basic") {
///   // use `heal` in gameplay systems...
/// }
/// ```
public struct TypeRegistry: Sendable {
  /// An immutable view of the registry contents, suitable for overlays and hot-reload.
  public struct Snapshot: Sendable {
    public let abilities: [String: AbilityType]
    public let items: [String: ItemType]
  }

  private var abilitiesById: [String: AbilityType] = [:]
  private var itemsById: [String: ItemType] = [:]

  /// Creates an empty registry.
  public init() {}

  /// Registers (or replaces) a single ability.
  public mutating func register(_ a: AbilityType) { abilitiesById[a.id] = a }
  /// Registers (or replaces) a single item.
  public mutating func register(_ i: ItemType) { itemsById[i.id] = i }

  /// Registers many abilities.
  public mutating func register(abilities: [AbilityType]) {
    for a in abilities {
      register(a)
    }
  }

  /// Registers many items.
  public mutating func register(items: [ItemType]) {
    for i in items {
      register(i)
    }
  }

  /// Looks up an ability by id.
  public func ability(_ id: String) -> AbilityType? { abilitiesById[id] }

  /// Looks up an item by id.
  public func item(_ id: String) -> ItemType? { itemsById[id] }

  /// Returns all abilities, optionally filtered by a tag.
  public func allAbilities(tag: String? = nil) -> [AbilityType] {
    guard let tag else { return Array(abilitiesById.values) }
    return abilitiesById.values.filter { $0.tags.contains(tag) }
  }

  /// Returns all items, optionally filtered by a tag.
  public func allItems(tag: String? = nil) -> [ItemType] {
    guard let tag else { return Array(itemsById.values) }
    return itemsById.values.filter { $0.tags.contains(tag) }
  }

  /// Captures the current contents for later overlay or diff.
  public func snapshot() -> Snapshot { .init(abilities: abilitiesById, items: itemsById) }

  /// Overlays the provided snapshot, replacing any matching ids.
  ///
  /// Useful for hot-reloading changed content while preserving the rest.
  public mutating func overlay(_ other: Snapshot) {
    for a in other.abilities.values {
      abilitiesById[a.id] = a
    }
    for i in other.items.values {
      itemsById[i.id] = i
    }
  }

  /// Decodes and registers ability definitions from JSON or JSONL data.
  public mutating func loadAbilitiesJSON(_ data: Data) throws {
    let arr = try decodeMany(AbilityType.self, from: data)
    register(abilities: arr)
  }

  /// Decodes and registers item definitions from JSON or JSONL data.
  public mutating func loadItemsJSON(_ data: Data) throws {
    let arr = try decodeMany(ItemType.self, from: data)
    register(items: arr)
  }

  /// Recursively loads all `.json` and `.jsonl` files from `url`.
  ///
  /// Filenames containing `"ability"` are parsed as abilities; filenames
  /// containing `"item"` are parsed as items. Files that do not match either
  /// pattern are skipped.
  public mutating func loadDirectory(url: URL) throws {
    let fm = FileManager.default

    guard let it = fm.enumerator(at: url, includingPropertiesForKeys: nil) else { return }

    for case let file as URL in it where file.pathExtension.lowercased() == "json" || file.pathExtension.lowercased() == "jsonl" {
      let data = try Data(contentsOf: file)
      if file.lastPathComponent.lowercased().contains("ability") { try? loadAbilitiesJSON(data) }
      else if file.lastPathComponent.lowercased().contains("item") { try? loadItemsJSON(data) }
    }
  }

  /// Performs static checks and returns any authoring issues discovered.
  public func validate(references: Bool = true) -> [String] {
    var issues: [String] = []

    for (id, a) in abilitiesById {
      if a.cooldown < 0 { issues.append("Ability[\(id)]: cooldown < 0") }
      for e in a.effects {
        if case let .addStatus(statusId, _, _) = e, references && abilitiesById[statusId] == nil {
          issues.append("Ability[\(id)]: addStatus references missing id '\(statusId)'")
        }
      }
    }

    for (id, i) in itemsById {
      if i.stackMax < 1 { issues.append("Item[\(id)]: stackMax < 1") }
      if let ab = i.onUseAbilityId, references && abilitiesById[ab] == nil {
        issues.append("Item[\(id)]: onUseAbilityId references missing ability '\(ab)'")
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
