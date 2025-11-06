import SwiftGodot

/// Helpers for setting collision layers and masks on `CollisionObject2D` nodes.
///
/// ### Usage:
/// ```swift
/// let wall = GNode<StaticBody2D>()
///   .layers([.alpha, .beta])
///   .mask([.gamma])
/// ```
public extension GNode where T: CollisionObject2D {
  func collisionLayer(_ set: Physics2DLayer) -> Self {
    var s = self
    s.ops.append { $0.collisionLayer = UInt32(set.rawValue) }
    return s
  }

  func collisionMask(_ set: Physics2DLayer) -> Self {
    var s = self
    s.ops.append { $0.collisionMask = UInt32(set.rawValue) }
    return s
  }
}

/// Named `Physics2DLayer` layers you can use to make your code more readable,
/// instead of using raw bitmasks.
public struct Physics2DLayer: OptionSet, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) { self.rawValue = rawValue }

  public static let alpha = Physics2DLayer(rawValue: 1 << 0)
  public static let beta = Physics2DLayer(rawValue: 1 << 1)
  public static let gamma = Physics2DLayer(rawValue: 1 << 2)
  public static let delta = Physics2DLayer(rawValue: 1 << 3)
  public static let epsilon = Physics2DLayer(rawValue: 1 << 4)
  public static let zeta = Physics2DLayer(rawValue: 1 << 5)
  public static let eta = Physics2DLayer(rawValue: 1 << 6)
  public static let theta = Physics2DLayer(rawValue: 1 << 7)
  public static let iota = Physics2DLayer(rawValue: 1 << 8)
  public static let kappa = Physics2DLayer(rawValue: 1 << 9)
  public static let lambda = Physics2DLayer(rawValue: 1 << 10)
  public static let mu = Physics2DLayer(rawValue: 1 << 11)
  public static let nu = Physics2DLayer(rawValue: 1 << 12)
  public static let xi = Physics2DLayer(rawValue: 1 << 13)
  public static let omicron = Physics2DLayer(rawValue: 1 << 14)
  public static let pi = Physics2DLayer(rawValue: 1 << 15)
  public static let rho = Physics2DLayer(rawValue: 1 << 16)
  public static let sigma = Physics2DLayer(rawValue: 1 << 17)
  public static let tau = Physics2DLayer(rawValue: 1 << 18)
  public static let upsilon = Physics2DLayer(rawValue: 1 << 19)
  public static let phi = Physics2DLayer(rawValue: 1 << 20)
  public static let chi = Physics2DLayer(rawValue: 1 << 21)
  public static let psi = Physics2DLayer(rawValue: 1 << 22)
  public static let omega = Physics2DLayer(rawValue: 1 << 23)
}
