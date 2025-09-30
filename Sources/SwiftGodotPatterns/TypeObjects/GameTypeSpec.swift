import Foundation

/// A common interface for all game "type objects" (data-driven definitions).
///
/// Conforming types are intended to be pure data, they describe things like
/// abilities or items without any engine/runtime behavior. This allows you to
/// author content in JSON/JSONL, load it at runtime, and keep gameplay logic
/// data-driven.
///
/// Conformers must be codable, hashable, and sendable for easy persistence,
/// lookups, and safe cross-concurrency use.
///
/// - SeeAlso: ``AbilityType``, ``ItemType``, ``TypeRegistry``
public protocol GameTypeSpec: Codable, Hashable, Sendable {
  /// Stable identifier used for lookups and references.
  var id: String { get }
  /// Human-readable display name.
  var name: String { get }
  /// Optional short description for UI.
  var summary: String? { get }
  /// Free-form labels used for search, filtering, and grouping.
  var tags: Set<String> { get }
}

extension GameTypeSpec {
  /// Returns `true` when the receiver has a tag equal to `t` (case-sensitive).
  @inlinable
  func hasTag(_ t: String) -> Bool { tags.contains(t) }
}
