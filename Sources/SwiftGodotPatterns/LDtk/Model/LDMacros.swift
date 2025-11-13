import Foundation

/// Protocol for LDtk enums with automatic code generation.
///
/// Enums conforming to this protocol get:
/// - Build-time generation to `LDExported.json`
/// - Type-safe field accessors
///
/// ### Usage:
/// ```swift
/// enum Item: String, LDExported {
///   case knife = "Knife"
///   case boots = "Boots"
///
///   static var ldtkIdentifier: String { "Item" }
/// }
/// ```
///
/// The build tool automatically generates `LDExported.json`:
/// ```json
/// {
///   "Item": ["Knife", "Boots"]
/// }
/// ```
///
/// Use in game code:
/// ```swift
/// let items: [Item] = entity.fieldEnumArray("items") ?? []
/// ```
///
/// ### Requirements:
/// - Must have `String` raw values matching LDtk enum values exactly
/// - Raw values are case-sensitive
/// - Implement `ldtkIdentifier` to specify LDtk enum name (defaults to Swift type name)
public protocol LDExported: LDEnum, CaseIterable {}
