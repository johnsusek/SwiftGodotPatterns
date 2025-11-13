import Foundation

/// Protocol for Swift enums that can be decoded from LDtk enum string values
///
/// ### Usage:
/// ```swift
/// // 1. Define your enum matching LDtk enum values
/// enum Item: String, LDEnum {
///   case knife = "Knife"
///   case healingPlant = "Healing_Plant"
///   case meat = "Meat"
///   case boots = "Boots"
///   case water = "Water"
///   case gem = "Gem"
///
///   // For external enum generation
///   static var ldtkIdentifier: String { "Item" }
/// }
///
/// // 2. Use with field accessors
/// let items: [Item] = entity.field("items")?.asEnumArray() ?? []
/// let equipped: Item? = entity.field("equipped")?.asEnum()
/// ```
public protocol LDEnum: RawRepresentable where RawValue == String {
  /// The identifier used in LDtk (for external enum generation)
  static var ldtkIdentifier: String { get }
}

// Default implementation - use Swift type name
public extension LDEnum {
  static var ldtkIdentifier: String {
    String(describing: Self.self)
  }
}

public extension LDFieldValue {
  /// Get as Swift enum conforming to LDEnum
  func asEnum<E: LDEnum>() -> E? {
    guard let string = asString() else { return nil }
    return E(rawValue: string)
  }

  /// Get as array of Swift enums
  func asEnumArray<E: LDEnum>() -> [E]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asEnum() }
  }
}
