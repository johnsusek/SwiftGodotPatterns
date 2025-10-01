import Foundation
import SwiftGodot

/// Authoritative, event-driven resource ledger for game entities.
///
/// The system owns canonical resource values per owner (`NodePath`) and
/// communicates changes via event buses:
///
/// - **Input**:
///   - `ResourceGrantEvent`: add a signed amount to one resource kind
///   - `ResourceSetEvent`: set an absolute value for one resource kind
///   - `ResourceConsumeRequest`: atomically try to deduct a list of costs
///   - `ResourceSnapshotRequest`: request a full values map for an owner
/// - **Output**:
///   - `ResourceDeltaEvent`: broadcast signed deltas after grant/set/consume
///   - `ResourceConsumeResult`: reply to consume requests (ok/remaining)
///   - `ResourceSnapshotEvent`: reply with a full values map
///
/// Entities can mirror state locally using `ResourceMirrorComponent` to avoid
/// TOCTOU (time-of-check/time-of-use) issues, while this system remains the
/// single source of truth.
@Godot
public final class ResourceSystem: Node {
  /// Canonical store: `owner → (resourceKind → absoluteValue)`.
  private var accounts: [NodePath: [String: Int]] = [:]

  /// Collected cancellation closures for active bus subscriptions.
  private var cancels: [() -> Void] = []

  /// Grants (signed) amounts into the ledger; results emitted as `ResourceDeltaEvent`.
  @Service<ResourceGrantEvent> var grantBus: EventBus<ResourceGrantEvent>?

  /// Sets absolute values into the ledger; delta emitted as `ResourceDeltaEvent`.
  @Service<ResourceSetEvent> var setBus: EventBus<ResourceSetEvent>?

  /// Outbound bus for broadcasting applied signed changes.
  @Service<ResourceDeltaEvent> var deltaBus: EventBus<ResourceDeltaEvent>?

  /// Inbound bus for atomic affordability checks + deductions.
  @Service<ResourceConsumeRequest> var consumeReqBus: EventBus<ResourceConsumeRequest>?

  /// Outbound bus replying to consume requests with success/failure and remaining values.
  @Service<ResourceConsumeResult> var consumeResBus: EventBus<ResourceConsumeResult>?

  /// Inbound bus for snapshot requests (full current values per owner).
  @Service<ResourceSnapshotRequest> var snapshotReqBus: EventBus<ResourceSnapshotRequest>?

  /// Outbound bus sending snapshot replies.
  @Service<ResourceSnapshotEvent> var snapshotResBus: EventBus<ResourceSnapshotEvent>?

  /// Binds services and installs bus handlers.
  override public func _ready() {
    bindProps()
    if let bus = grantBus { track(bus.onEach { [weak self] e in self?.handleGrant(e) }) { [weak self] t in self?.grantBus?.cancel(t) } }
    if let bus = setBus { track(bus.onEach { [weak self] e in self?.handleSet(e) }) { [weak self] t in self?.setBus?.cancel(t) } }
    if let bus = snapshotReqBus { track(bus.onEach { [weak self] r in self?.handleSnapshot(r) }) { [weak self] t in self?.snapshotReqBus?.cancel(t) } }
    if let bus = consumeReqBus { track(bus.onEach { [weak self] r in self?.handleConsume(r) }) { [weak self] t in self?.consumeReqBus?.cancel(t) } }
  }

  /// Cancels all subscriptions to avoid leaks when the node leaves the tree.
  override public func _exitTree() {
    for cancel in cancels {
      cancel()
    }
    cancels.removeAll()
  }

  /// Tracks a subscription token alongside its canceler for later cleanup.
  private func track(_ token: EventBus.Token, _ canceler: @escaping (EventBus.Token) -> Void) {
    cancels.append { canceler(token) }
  }

  /// Ensures an owner has a resource bag, returning the current (possibly empty) map.
  private func ensure(_ owner: NodePath) -> [String: Int] {
    if let bag = accounts[owner] { return bag }
    accounts[owner] = [:]
    return [:]
  }

  /// Applies a signed grant, updates storage, and emits a matching delta.
  private func handleGrant(_ e: ResourceGrantEvent) {
    var bag = ensure(e.owner)
    bag[e.kind, default: 0] += e.amount
    accounts[e.owner] = bag
    deltaBus?.publish(.init(owner: e.owner, deltas: [e.kind: e.amount]))
  }

  /// Sets an absolute value, derives the delta, updates storage, and emits if nonzero.
  private func handleSet(_ e: ResourceSetEvent) {
    var bag = ensure(e.owner)
    let old = bag[e.kind, default: 0]
    bag[e.kind] = e.value
    accounts[e.owner] = bag
    let delta = e.value - old
    if delta != 0 { deltaBus?.publish(.init(owner: e.owner, deltas: [e.kind: delta])) }
  }

  /// Replies to a snapshot request with the full current values for the owner.
  private func handleSnapshot(_ r: ResourceSnapshotRequest) {
    let bag = accounts[r.owner] ?? [:]
    snapshotResBus?.publish(.init(owner: r.owner, values: bag, correlation: r.correlation))
  }

  /// Validates affordability for all positive costs, performs atomic deduction if possible,
  /// emits aggregate deltas, and replies with `ResourceConsumeResult`.
  private func handleConsume(_ r: ResourceConsumeRequest) {
    var bag = ensure(r.owner)

    for c in r.costs where c.amount > 0 {
      if (bag[c.kind] ?? 0) < c.amount {
        consumeResBus?.publish(.init(correlation: r.correlation, ok: false, remaining: bag))
        return
      }
    }

    for c in r.costs where c.amount > 0 {
      bag[c.kind, default: 0] -= c.amount
    }
    accounts[r.owner] = bag

    let deltas = Dictionary(uniqueKeysWithValues: r.costs
      .filter { $0.amount > 0 }
      .map { ($0.kind, -$0.amount) })

    if !deltas.isEmpty { deltaBus?.publish(.init(owner: r.owner, deltas: deltas)) }
    consumeResBus?.publish(.init(correlation: r.correlation, ok: true, remaining: bag))
  }
}
