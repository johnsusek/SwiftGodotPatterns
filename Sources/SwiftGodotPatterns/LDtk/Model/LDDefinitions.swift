import Foundation

// MARK: - Definitions

/// Container for all project definitions (entities, layers, tilesets, enums)
public struct LDDefinitions: Codable {
  /// All entity definitions
  public let entities: [LDEntityDef]

  /// All layer definitions
  public let layers: [LDLayerDef]

  /// All tileset definitions
  public let tilesets: [LDTilesetDef]

  /// All enum definitions
  public let enums: [LDEnumDef]

  /// All external enum definitions
  public let externalEnums: [LDEnumDef]

  /// Custom level fields
  public let levelFields: [LDFieldDef]

  /// Get entity definition by identifier
  public func entity(_ identifier: String) -> LDEntityDef? {
    entities.first(where: { $0.identifier == identifier })
  }

  /// Get entity definition by UID
  public func entity(uid: Int) -> LDEntityDef? {
    entities.first(where: { $0.uid == uid })
  }

  /// Get layer definition by identifier
  public func layer(_ identifier: String) -> LDLayerDef? {
    layers.first(where: { $0.identifier == identifier })
  }

  /// Get layer definition by UID
  public func layer(uid: Int) -> LDLayerDef? {
    layers.first(where: { $0.uid == uid })
  }

  /// Get tileset definition by identifier
  public func tileset(_ identifier: String) -> LDTilesetDef? {
    tilesets.first(where: { $0.identifier == identifier })
  }

  /// Get tileset definition by UID
  public func tileset(uid: Int) -> LDTilesetDef? {
    tilesets.first(where: { $0.uid == uid })
  }

  /// Get enum definition by identifier
  public func enumDef(_ identifier: String) -> LDEnumDef? {
    let all = enums + externalEnums
    return all.first(where: { $0.identifier == identifier })
  }

  /// Get enum definition by UID
  public func enumDef(uid: Int) -> LDEnumDef? {
    let all = enums + externalEnums
    return all.first(where: { $0.uid == uid })
  }
}

// MARK: - Enum Definition

/// Definition of an enum in the project
public struct LDEnumDef: Codable {
  /// Unique identifier
  public let uid: Int

  /// User-defined identifier
  public let identifier: String

  /// All possible values
  public let values: [LDEnumValue]

  /// Tags for organizing enums
  public let tags: [String]

  /// External file path (for external enums)
  public let externalRelPath: String?

  /// Tileset UID for icons (if applicable)
  public let iconTilesetUid: Int?

  /// Get enum value by identifier
  public func value(_ identifier: String) -> LDEnumValue? {
    values.first(where: { $0.id == identifier })
  }
}

// MARK: - Enum Value

/// A single value in an enum definition
public struct LDEnumValue: Codable {
  /// Value identifier
  public let id: String

  /// Color for this value
  public let color: Int

  /// Optional tile rectangle
  public let tileRect: LDTilesetRect?

  enum CodingKeys: String, CodingKey {
    case id
    case color
    case tileRect
  }
}
