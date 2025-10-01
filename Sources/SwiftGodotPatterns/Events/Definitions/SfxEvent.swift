import Foundation
import SwiftGodot

/// Requests playback of a named sound effect, optionally at a world position.
///
/// Implementations may resolve `name` to an `AudioStream` or an addressable key,
/// and choose 2D/3D emitters based on `at`.
///
/// Example publish:
/// ```swift
/// sfxBus.publish(SfxEvent(name: "fx/explosion_small", at: impactPoint))
/// ```
public struct SfxEvent {
  /// Identifier or path for the effect to play (e.g., `"fx/hit"`, `"res://sfx/hit.ogg"`).
  public let name: String
  /// Optional world-space position; `nil` implies UI/global playback.
  public let at: Vector2?
}
