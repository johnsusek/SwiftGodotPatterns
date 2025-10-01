import Foundation
import SwiftGodot

/// Mirrors authoritative resource state on the client by listening to events,
/// avoiding time-of-check/time-of-use (TOCTOU) race conditions in gameplay logic.
///
/// The "server" (or an authoritative system) remains the source of truth. This
/// component keeps a local `values` dictionary updated from:
/// - `ResourceDeltaEvent` (incremental changes)
/// - `ResourceSnapshotEvent` (full refresh)
/// - `ResourceConsumeResult` (authoritative consume outcome)
///
/// On startup it requests a snapshot so the mirror begins in a correct state.
/// Use `tryConsume(_:)` for atomic, round-trip resource spending that snaps
/// the mirror to the authoritative result.
@Godot
public final class ResourceMirrorComponent: Node {
  /// The latest known absolute values by resource kind (e.g., `"mana": 37`).
  ///
  /// Updated via deltas, snapshot replies, and successful consume results.
  public private(set) var values: [String: Int] = [:]

  /// Optional explicit owner whose `NodePath` qualifies events for this mirror.
  @Ancestor<Node> var ownerNode: Node?

  /// Bus that delivers additive resource changes (kind → delta).
  @Service<ResourceDeltaEvent> var deltaBus: EventBus<ResourceDeltaEvent>?

  /// Bus to *publish* consume requests (authoritative check & deduct).
  @Service<ResourceConsumeRequest> var consumeReqBus: EventBus<ResourceConsumeRequest>?

  /// Bus that yields authoritative consume outcomes (ok/remaining).
  @Service<ResourceConsumeResult> var consumeResBus: EventBus<ResourceConsumeResult>?

  /// Bus to *publish* snapshot requests (point-in-time full values).
  @Service<ResourceSnapshotRequest> var snapshotReqBus: EventBus<ResourceSnapshotRequest>?

  /// Bus that delivers snapshot replies (full values map).
  @Service<ResourceSnapshotEvent> var snapshotResBus: EventBus<ResourceSnapshotEvent>?

  /// Lazily collected cancellation actions for all active bus subscriptions.
  private var cancels: [() -> Void] = []

  /// Lock guarding the monotonic correlation counter.
  private static var corrLock = NSLock()

  /// Monotonic correlation used to pair requests with their responses.
  private static var corr: UInt64 = 0

  /// Continuations for pending consume requests keyed by correlation id.
  private var pendingConsume: [UInt64: (ResourceConsumeResult) -> Void] = [:]

  /// Binds property wrappers and wires bus subscriptions, then primes with a snapshot.
  ///
  /// Subscriptions:
  /// - `deltaBus`: applies per-kind signed deltas for this owner.
  /// - `consumeResBus`: resumes the matching `tryConsume` continuation.
  /// - `snapshotResBus`: installs the initial authoritative values.
  override public func _ready() {
    bindProps()

    if let bus = deltaBus {
      track(bus.onEach { [weak self] d in
        guard let self, d.owner == self.ownerPath() else { return }
        for (k, dv) in d.deltas {
          self.values[k, default: 0] += dv
        }
      }) { [weak self] t in self?.deltaBus?.cancel(t) }
    }

    if let bus = consumeResBus {
      track(bus.onEach { [weak self] res in
        guard let self, let cont = self.pendingConsume.removeValue(forKey: res.correlation) else { return }
        cont(res)
      }) { [weak self] t in self?.consumeResBus?.cancel(t) }
    }

    // Prime with a snapshot so mirrors start correct.
    let corr = Self.nextCorr()
    if let bus = snapshotResBus {
      track(bus.onEach { [weak self] snap in
        guard let self, snap.correlation == corr, snap.owner == self.ownerPath() else { return }
        self.values = snap.values
      }) { [weak self] t in self?.snapshotResBus?.cancel(t) }
    }
    snapshotReqBus?.publish(.init(owner: ownerPath(), correlation: corr))
  }

  /// Cancels all active subscriptions on exit to prevent leaks.
  override public func _exitTree() {
    for cancel in cancels {
      cancel()
    }
    cancels.removeAll()
  }

  /// Returns the current value for a `kind`, or `0` if unknown.
  public subscript(kind: String) -> Int { values[kind] ?? 0 }

  /// Local, non-authoritative affordability check for a set of costs.
  ///
  /// Useful for quick UI gating; does not change state and may be stale.
  /// - Parameter costs: Resource costs to evaluate.
  /// - Returns: `true` if all nonzero costs are currently affordable.
  public func canPay(_ costs: [ResourceCost]) -> Bool {
    for c in costs where c.amount > 0 {
      if (values[c.kind] ?? 0) < c.amount { return false }
    }
    return true
  }

  /// Attempts an authoritative consume via a request/response round-trip.
  ///
  /// Sends a `ResourceConsumeRequest` and suspends until a matching
  /// `ResourceConsumeResult` arrives. If `ok == true`, the mirror snaps to
  /// `remaining`. If `ok == false`, no local mutation is performed.
  ///
  /// - Important: Performs a fast local `canPay` precheck to avoid spam, but
  ///   only the response is authoritative. Callers should respect the boolean result.
  ///
  public func tryConsume(_ costs: [ResourceCost]) async -> Bool {
    if !canPay(costs) { return false }
    let corr = Self.nextCorr()
    let owner = ownerPath()

    return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
      pendingConsume[corr] = { [weak self] res in
        if res.ok, let self { self.values = res.remaining } // snap to truth
        cont.resume(returning: res.ok)
      }
      consumeReqBus?.publish(.init(owner: owner, costs: costs, correlation: corr))
    }
  }

  /// Resolves the qualifying owner path (explicit owner if present, else `self`).
  private func ownerPath() -> NodePath { (ownerNode ?? self).getPath() }

  /// Generates a new correlation id in a threadsafe manner.
  private static func nextCorr() -> UInt64 {
    corrLock.lock()
    defer { corrLock.unlock() }
    corr &+= 1
    return corr
  }

  /// Tracks a subscription token with its associated canceler for later cleanup.
  private func track(_ token: EventBus.Token, _ canceler: @escaping (EventBus.Token) -> Void) {
    cancels.append { canceler(token) }
  }
}
