import SwiftGodot

/// Scans overlapping `Node2D` bodies, filters by groups, and emits a target when the best candidate changes.
///
/// `TargetScanner2D` is an `Area2D` that maintains a weak list of bodies
/// currently inside its collision shape(s). Each frame it prunes dead references,
/// selects a target (optionally the nearest to the owner), and publishes a
/// `TargetAcquired` event only when the chosen target differs from the previous
/// emission.
///
/// ### Filtering
/// If `targetGroups` is non-empty, only bodies that belong to at least one of
/// those groups are tracked. Use Godot groups to tag ally/enemy/friendly units.
///
/// ### Target selection
/// - When `pickNearest == true`, chooses the closest candidate to `owner2D`.
/// - Otherwise, returns the first live candidate (insertion order).
///
/// ### Usage
/// ```swift
/// @Godot
/// final class Turret: Node2D {
///   @Child("Scanner") var scanner: TargetScanner2D?
///   @Service<TargetAcquired> var bus: EventBus<TargetAcquired>?
///
///   override func _ready() {
///     // Configure groups the turret is interested in:
///     scanner?.targetGroups = ["Enemies"]
///     // Elsewhere: listen on the bus to rotate/aim at the target.
///   }
/// }
/// ```
///
/// - Important: This node calls `bindProps()` in `_ready()` to activate
///   property-wrapper bindings (`@Service`, `@Ancestor`, etc.).
/// - Note: Ensure a suitable `CollisionShape2D` is present so overlaps occur.
@Godot
public final class TargetScanner2D: Area2D {
  // MARK: Configuration

  /// Optional group names to filter candidates.
  ///
  /// When non-empty, only bodies in at least one of these groups are tracked.
  public var targetGroups: [String] = []

  /// Whether to pick the nearest candidate to `owner2D` each frame.
  ///
  /// If `false`, the first live candidate is used.
  public var pickNearest: Bool = true

  // MARK: Internals

  /// Weak references to overlapping `Node2D` bodies currently inside the area.
  private var candidates: [Weak<Node2D>] = []

  /// The last emitted `NodePath`, used to prevent redundant `TargetAcquired` events.
  private var lastEmitted: NodePath?

  /// Event bus used to publish `TargetAcquired` announcements.
  @Service<TargetAcquired> var bus: EventBus<TargetAcquired>?

  /// The owning `Node2D` used for distance calculations when `pickNearest` is enabled.
  @Ancestor<Node2D> var owner2D: Node2D?

  // MARK: Godot Lifecycle

  /// Enables monitoring, wires signals, and starts per-frame processing.
  override public func _ready() {
    bindProps()
    monitoring = true
    monitorable = true
    _ = bodyEntered.connect { [weak self] body in self?.onBody(body) }
    _ = bodyExited.connect { [weak self] body in self?.onBodyExit(body) }
  }

  /// Prunes dead candidates and publishes a `TargetAcquired` event when the
  /// best candidate changes from the previously emitted target.
  override public func _process(delta: Double) {
    _ = delta
    prune()
    guard let me = self as Node?, let best = select() else { return }
    let bestPath = best.getPath()
    if bestPath == lastEmitted { return }
    lastEmitted = bestPath
    bus?.publish(.init(source: me.getPath(), target: bestPath))
  }

  // MARK: Signal Handlers

  /// Handles `body_entered`: filters by `targetGroups` and tracks the body.
  private func onBody(_ node: Node?) {
    guard let node2D = node as? Node2D else { return }
    if !targetGroups.isEmpty, !targetGroups.contains(where: { node2D.isInGroup(StringName($0)) }) { return }
    candidates.append(.init(node2D))
  }

  /// Handles `body_exited`: removes the body from the candidate list.
  private func onBodyExit(_ node: Node?) {
    guard let node2D = node as? Node2D else { return }
    candidates.removeAll { $0.value === node2D || $0.value == nil }
  }

  // MARK: Maintenance

  /// Removes deallocated or soon-to-be-freed nodes from the candidate list.
  private func prune() { candidates.removeAll { $0.value == nil || $0.value?.isQueuedForDeletion() == true } }

  // MARK: Selection

  /// Selects the current best target among live candidates.
  private func select() -> Node2D? {
    let live = candidates.compactMap(\.value)
    guard let owner2D else { return live.first }
    if !pickNearest { return live.first }
    return live.min {
      $0.globalPosition.distanceTo(owner2D.globalPosition) < $1.globalPosition.distanceTo(owner2D.globalPosition)
    }
  }
}
