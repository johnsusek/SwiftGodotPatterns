import SwiftGodot

/// Convenience extensions for Godot types.

extension Vector2: @retroactive ExpressibleByArrayLiteral {
  public typealias ArrayLiteralElement = Float
  /// Initializes a Vector2 from an array literal of two Float values.
  /// - Example:
  /// ```swift
  /// let vector: Vector2 = [1.0, 2.0]
  /// ```
  public init(arrayLiteral elements: Float...) {
    if elements.count != 2 {
      GD.printErr("Vector2 initialized with \(elements.count) elements, expected 2.")
    }
    if elements.count == 1 { self.init(x: elements[0], y: elements[0]); return }
    if elements.count >= 2 { self.init(x: elements[0], y: elements[1]); return }
    self.init(x: 0.0, y: 0.0) // fallback
    return
  }
}

public extension Vector2 {
  /// Convenience initializer.
  init(_ x: Float, _ y: Float) {
    self.init(x: x, y: y)
  }

  @inlinable static func * (lhs: Self, rhs: Float) -> Self { Self(x: lhs.x * rhs, y: lhs.y * rhs) }
  @inlinable static func * (lhs: Float, rhs: Self) -> Self { rhs * lhs }
  @inlinable static func *= (lhs: inout Self, rhs: Float) { lhs = lhs * rhs }
  @inlinable static func *= <S: BinaryFloatingPoint>(lhs: inout Self, rhs: S) { lhs = lhs * rhs }

  @inlinable static func * <S: BinaryFloatingPoint>(lhs: Self, rhs: S) -> Self { Self(x: lhs.x * Float(rhs), y: lhs.y * Float(rhs)) }
  @inlinable static func * <S: BinaryFloatingPoint>(lhs: S, rhs: Self) -> Self { rhs * lhs }

  @inlinable static func * <S: BinaryInteger>(lhs: Self, rhs: S) -> Self { lhs * Float(rhs) }
  @inlinable static func * <S: BinaryInteger>(lhs: S, rhs: Self) -> Self { rhs * lhs }

  @inlinable static func *= <S: BinaryInteger>(lhs: inout Self, rhs: S) { lhs = lhs * rhs }
}

extension Vector2: @retroactive @unchecked Sendable {
  public func toSendable() -> (Float, Float) { (x, y) }
  public static func fromSendable(_ value: (Float, Float)) -> Vector2 { Vector2(value.0, value.1) }
}

extension Vector2i: @retroactive @unchecked Sendable {
  public func toSendable() -> (Int32, Int32) { (x, y) }
  public static func fromSendable(_ value: (Int32, Int32)) -> Vector2i { Vector2i(x: value.0, y: value.1) }
}

// MARK: Codable conformances

extension Vector2: @retroactive Codable {
  enum CodingKeys: String, CodingKey { case x, y }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(x, forKey: .x)
    try container.encode(y, forKey: .y)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let x = try container.decode(Float.self, forKey: .x)
    let y = try container.decode(Float.self, forKey: .y)
    self.init(x: x, y: y)
  }
}
