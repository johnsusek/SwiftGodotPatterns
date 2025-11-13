import Foundation
import SwiftGodot

// MARK: - Field Value

/// Represents a value from an LDtk field instance
/// Fields can be various types: Int, Float, String, Bool, Color, Point, EntityRef, Tile, etc.
public enum LDFieldValue: Codable {
  case null
  case int(Int)
  case float(Double)
  case bool(Bool)
  case string(String)
  case color(String) // Hex color string "#rrggbb"
  case point(LDPoint)
  case entityRef(LDEntityRef)
  case filePath(String)
  case array([LDFieldValue])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    // Try null first
    if container.decodeNil() {
      self = .null
      return
    }

    // Try array
    if let array = try? container.decode([LDFieldValue].self) {
      self = .array(array)
      return
    }

    // Try basic types
    if let value = try? container.decode(Int.self) {
      self = .int(value)
      return
    }

    if let value = try? container.decode(Double.self) {
      self = .float(value)
      return
    }

    if let value = try? container.decode(Bool.self) {
      self = .bool(value)
      return
    }

    if let value = try? container.decode(String.self) {
      // Check if it's a color (starts with #)
      if value.hasPrefix("#") {
        self = .color(value)
      } else {
        self = .string(value)
      }
      return
    }

    // Try complex types
    if let value = try? container.decode(LDPoint.self) {
      self = .point(value)
      return
    }

    if let value = try? container.decode(LDEntityRef.self) {
      self = .entityRef(value)
      return
    }

    // Fallback to null if we can't decode
    self = .null
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .null:
      try container.encodeNil()
    case let .int(value):
      try container.encode(value)
    case let .float(value):
      try container.encode(value)
    case let .bool(value):
      try container.encode(value)
    case let .string(value), let .color(value), let .filePath(value):
      try container.encode(value)
    case let .point(value):
      try container.encode(value)
    case let .entityRef(value):
      try container.encode(value)
    case let .array(value):
      try container.encode(value)
    }
  }
}

// MARK: - Value Accessors

public extension LDFieldValue {
  /// Get as Int, returns nil if not an int
  func asInt() -> Int? {
    if case let .int(value) = self { return value }
    return nil
  }

  /// Get as Float/Double, returns nil if not a float
  func asFloat() -> Double? {
    if case let .float(value) = self { return value }
    if case let .int(value) = self { return Double(value) }
    return nil
  }

  /// Get as Bool, returns nil if not a bool
  func asBool() -> Bool? {
    if case let .bool(value) = self { return value }
    return nil
  }

  /// Get as String, returns nil if not a string
  func asString() -> String? {
    if case let .string(value) = self { return value }
    if case let .filePath(value) = self { return value }
    return nil
  }

  /// Get as hex color string, returns nil if not a color
  func asColorString() -> String? {
    if case let .color(value) = self { return value }
    return nil
  }

  /// Get as Godot Color, returns nil if not a color
  func asColor() -> Color? {
    guard let hex = asColorString() else { return nil }
    return Color.fromHex(hex)
  }

  /// Get as Point (grid coordinates), returns nil if not a point
  func asPoint() -> LDPoint? {
    if case let .point(value) = self { return value }
    return nil
  }

  /// Get as Vector2 (converted from grid point), returns nil if not a point
  func asVector2(gridSize: Int = 16) -> Vector2? {
    guard let point = asPoint() else { return nil }
    return Vector2(x: Float(point.cx * gridSize), y: Float(point.cy * gridSize))
  }

  /// Get as entity reference, returns nil if not an entity ref
  func asEntityRef() -> LDEntityRef? {
    if case let .entityRef(value) = self { return value }
    return nil
  }

  /// Get as array, returns nil if not an array
  func asArray() -> [LDFieldValue]? {
    if case let .array(value) = self { return value }
    return nil
  }

  /// Get as array of Ints
  func asIntArray() -> [Int]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asInt() }
  }

  /// Get as array of Floats/Doubles
  func asFloatArray() -> [Double]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asFloat() }
  }

  /// Get as array of Bools
  func asBoolArray() -> [Bool]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asBool() }
  }

  /// Get as array of Strings
  func asStringArray() -> [String]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asString() }
  }

  /// Get as array of Points
  func asPointArray() -> [LDPoint]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asPoint() }
  }

  /// Get as array of Vector2 (converted from points)
  func asVector2Array(gridSize: Int = 16) -> [Vector2]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asVector2(gridSize: gridSize) }
  }

  /// Get as array of Colors
  func asColorArray() -> [Color]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asColor() }
  }

  /// Get as array of EntityRefs
  func asEntityRefArray() -> [LDEntityRef]? {
    guard let array = asArray() else { return nil }
    return array.compactMap { $0.asEntityRef() }
  }

  /// Check if value is null
  var isNull: Bool {
    if case .null = self { return true }
    return false
  }
}

// MARK: - Field Instance

/// An instance of a field with its value
public struct LDFieldInstance: Codable {
  /// Field identifier
  public let identifier: String

  /// Field type (e.g., "Int", "String", "Array<Point>", "Enum(MyEnum)")
  public let type: String

  /// The actual field value
  public let value: LDFieldValue

  /// Reference to the field definition UID
  public let defUid: Int

  enum CodingKeys: String, CodingKey {
    case identifier = "__identifier"
    case type = "__type"
    case value = "__value"
    case defUid
  }
}

// MARK: - Supporting Types

/// A grid-based point (used in Point fields)
public struct LDPoint: Codable {
  /// X grid coordinate
  public let cx: Int

  /// Y grid coordinate
  public let cy: Int

  /// Convert to Vector2 with given grid size
  public func toVector2(gridSize: Int = 16) -> Vector2 {
    Vector2(x: Float(cx * gridSize), y: Float(cy * gridSize))
  }
}

/// Reference to another entity instance
public struct LDEntityRef: Codable {
  /// IID of the referenced entity
  public let entityIid: String

  /// IID of the layer containing the referenced entity
  public let layerIid: String

  /// IID of the level containing the referenced entity
  public let levelIid: String

  /// IID of the world containing the referenced entity
  public let worldIid: String
}

// MARK: - Color Extension

extension Color {
  /// Create a Color from a hex string (#rrggbb or #rrggbbaa)
  static func fromHex(_ hex: String) -> Color? {
    var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexString = hexString.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0
    guard Scanner(string: hexString).scanHexInt64(&rgb) else { return nil }

    let length = hexString.count

    if length == 6 {
      // #rrggbb
      let r = Float((rgb >> 16) & 0xFF) / 255.0
      let g = Float((rgb >> 8) & 0xFF) / 255.0
      let b = Float(rgb & 0xFF) / 255.0
      return Color(r: r, g: g, b: b, a: 1.0)
    } else if length == 8 {
      // #rrggbbaa
      let r = Float((rgb >> 24) & 0xFF) / 255.0
      let g = Float((rgb >> 16) & 0xFF) / 255.0
      let b = Float((rgb >> 8) & 0xFF) / 255.0
      let a = Float(rgb & 0xFF) / 255.0
      return Color(r: r, g: g, b: b, a: a)
    }

    return nil
  }
}

// MARK: - Field Collection Extension

public extension Array where Element == LDFieldInstance {
  /// Get a field value by identifier
  func field(_ identifier: String) -> LDFieldValue? {
    first(where: { $0.identifier == identifier })?.value
  }
}
