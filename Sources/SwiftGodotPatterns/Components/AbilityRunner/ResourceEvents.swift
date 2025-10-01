import SwiftGodot

/// Describes a one-time additive change to a single resource kind for a specific owner.
///
/// Use this to grant (or refund) a fixed `amount` of a resource to an entity identified
/// by its `NodePath`.
///
/// ### Example
/// ```swift
/// castBus.publish(ResourceGrantEvent(owner: owner.getPath(), kind: "mana", amount: 15))
/// ```
public struct ResourceGrantEvent {
  /// The entity receiving the grant.
  public let owner: NodePath
  /// The logical name of the resource (e.g., `"health"`, `"mana"`, `"stamina"`).
  public let kind: String
  /// The quantity to add to the resource (may be negative to apply a refund reversal).
  public let amount: Int
}

/// Sets the exact value of a resource kind for a specific owner, replacing any previous value.
///
/// Prefer this for authoritative updates (e.g., syncing from server state or a save file).
///
/// ### Example
/// ```swift
/// effectBus.publish(ResourceSetEvent(owner: unit.getPath(), kind: "health", value: 42))
/// ```
public struct ResourceSetEvent {
  /// The entity whose resource value should be set.
  public let owner: NodePath
  /// The logical name of the resource (e.g., `"health"`).
  public let kind: String
  /// The new absolute value for the resource.
  public let value: Int
}

/// Applies multiple additive changes to resources for a specific owner in a single message.
///
/// Each entry in `deltas` maps a resource kind to a signed integer delta. Positive values grant,
/// negative values consume.
///
/// ### Example
/// ```swift
/// effectBus.publish(ResourceDeltaEvent(
///   owner: unit.getPath(),
///   deltas: ["health": -10, "rage": 3]
/// ))
/// ```
public struct ResourceDeltaEvent {
  /// The entity whose resources should be changed.
  public let owner: NodePath
  /// A map of resource kind → signed delta. Positive adds; negative subtracts.
  public let deltas: [String: Int]
}

/// Requests that one or more resource costs be consumed from an owner.
///
/// This is a *query* message: a system that owns resource state should validate the costs
/// and reply with a matching `ResourceConsumeResult` using the same `correlation`.
///
/// ### Example
/// ```swift
/// let corr = UInt64(GD.randi())
/// castBus.publish(ResourceConsumeRequest(
///   owner: caster.getPath(),
///   costs: [ResourceCost("mana", 20), ResourceCost("stamina", 5)],
///   correlation: corr
/// ))
/// // A resource system should respond with `ResourceConsumeResult(correlation: corr, ...)`.
/// ```
public struct ResourceConsumeRequest {
  /// The entity from which resources should be consumed.
  public let owner: NodePath
  /// The list of resource costs to check and (if valid) deduct.
  public let costs: [ResourceCost]
  /// Correlation identifier used to match the eventual `ResourceConsumeResult`.
  public let correlation: UInt64
}

/// The outcome of a `ResourceConsumeRequest`.
///
/// When `ok == true`, the costs were successfully deducted. When `ok == false`, nothing
/// should have been deducted, and `remaining` reflects the current resource snapshot so
/// the caller can decide how to proceed (e.g., show “Not enough mana”).
///
/// The `correlation` must match the originating request.
///
/// ### Example
/// ```swift
/// // In the resource system:
/// resultBus.publish(ResourceConsumeResult(
///   correlation: req.correlation,
///   ok: canAfford,
///   remaining: currentValues
/// ))
/// ```
public struct ResourceConsumeResult {
  /// Correlates this response to the original request.
  public let correlation: UInt64
  /// Whether all requested costs were affordable and have been deducted.
  public let ok: Bool
  /// A snapshot of current resource values after evaluation (and deduction if `ok`).
  public let remaining: [String: Int]
}

/// Requests a point-in-time snapshot of all resource values for an owner.
///
/// This is a *query* message; a system that owns resource state should answer with a
/// `ResourceSnapshotEvent` using the same `correlation`.
///
/// ### Example
/// ```swift
/// let corr = UInt64(GD.randi())
/// effectBus.publish(ResourceSnapshotRequest(owner: unit.getPath(), correlation: corr))
/// // Expect ResourceSnapshotEvent(correlation: corr, ...) as a reply.
/// ```
public struct ResourceSnapshotRequest {
  /// The entity whose resources are being queried.
  public let owner: NodePath
  /// Correlation identifier used to match the eventual `ResourceSnapshotEvent`.
  public let correlation: UInt64
}

/// A point-in-time snapshot of resource values for an owner, sent in response
/// to a `ResourceSnapshotRequest`.
///
/// The `values` dictionary contains the absolute value for each known resource kind.
/// The `correlation` must match the originating request.
///
/// ### Example
/// ```swift
/// snapshotBus.publish(ResourceSnapshotEvent(
///   owner: unit.getPath(),
///   values: ["health": 87, "mana": 12],
///   correlation: req.correlation
/// ))
/// ```
public struct ResourceSnapshotEvent {
  /// The entity this snapshot describes.
  public let owner: NodePath
  /// Absolute values for each resource kind at the moment of capture.
  public let values: [String: Int]
  /// Correlates this snapshot to the original request.
  public let correlation: UInt64
}
