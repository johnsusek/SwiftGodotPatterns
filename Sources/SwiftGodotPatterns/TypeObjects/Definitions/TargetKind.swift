import Foundation

/// High-level targeting modes supported by abilities.
public enum TargetKind: String, Codable, Sendable {
  case selfOnly
  case ally
  case enemy
  case anyUnit
  case point
  case cone
  case line
  case sphere
}
