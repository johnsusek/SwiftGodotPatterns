import Foundation
import MessagePack
import SwiftGodot

// MARK: - NetworkStore

/// Ships opaque payloads between your local store/model and Godot HLMP,
/// with client-side prediction + reconciliation.
///
/// Lanes:
/// - Client -> Server: `[NetIntentBlob]` (seq, from, payload MessagePack bytes)
/// - Server -> Clients (delta): `NetEvents<Event>` (tick, acks, events)
/// - Server -> Clients (snapshot): `Snap<Model>` (tick, acks, model)
///
/// The node does not interpret domain types beyond Codable encode/decode.
@Godot
public final class NetworkStore: Node {
  // MARK: Server authority state

  private var serverAcks: [PeerID: Int64] = [:] // last processed seq per peer
  private var authorityTick: Int64 = 0

  // MARK: Wiring / runtime bridges

  /// Client -> Server (raw bytes)
  public var onClientIntentsData: ((Data) -> Void)?
  /// Server -> Clients (raw bytes)
  public var onServerEventsData: ((Data) -> Void)?
  /// Server -> Clients (raw bytes, snapshot)
  public var onModelStateData: ((Data) -> Void)?

  /// Current peer id (0 if unavailable).
  public var peerID: Int32 { getTree()?.getMultiplayer()?.getUniqueId() ?? 0 }

  override public func _ready() {
    configureRpcPermissions()
    hookMultiplayerSignals()
  }

  // MARK: Public API (typed wiring + prediction)

  /// Wires prediction + reconciliation between this node and your store.
  ///
  /// - Behavior:
  ///   - Client commits wrap intents with per-client `seq`, send to server, and apply locally (optimistic).
  ///   - Client tracks un-acked intents and, upon authoritative events/snapshots, drops acked and replays remaining.
  ///   - Server decodes client blobs, updates `serverAcks[from]`, applies intents, and broadcasts `NetEvents` with acks.
  public func wire<Model: Codable, Intent: Codable, Event: Codable>(to store: Store<Model, Intent, Event>) {
    // --- Client-side prediction state (captured by closures)
    var baseline: Model = store.model // authoritative baseline (advanced only by server events/snapshots)
    var nextSeq: Int64 = 0 // per-client local sequence
    var pending: [(seq: Int64, intent: Intent)] = [] // un-acked local intents (ordered)
    let localPeer = PeerID(peerID == 0 ? 1 : peerID)

    // Prevents accidental network sends while reconciling/replaying
    var reconciling = false

    // After-hook: only server should broadcast
    store.use(.init(after: { [weak self] _, _, events in
      if events.isEmpty { return }
      guard let self, self.isServer else { return }
      self.broadcast(events) // wraps with acks + tick
    }))

    // --- CLIENT: installs commit bridges with optimistic apply
    // Single-intent commit
    clientCommitOne = { [weak self, weak store] any in
      guard let self, let store, let intent = any as? Intent else { return }
      nextSeq += 1
      let blob = NetIntentBlob(seq: nextSeq, from: localPeer, payload: serialize(intent) ?? Data())
      pending.append((seq: blob.seq, intent: intent))
      // Send to server
      if let data = serialize([blob]) { self.sendBytes(method: RPC.recvClientIntents, data) }
      // Optimistic local apply (no network broadcast from client due to .authority check in broadcast(_:))
      store.push(intent)
      store.pump()
    }

    // Batch commit
    clientCommitMany = { [weak self, weak store] anys in
      guard let self, let store else { return }
      var blobs: [NetIntentBlob] = []
      blobs.reserveCapacity(anys.count)
      for any in anys {
        guard let intent = any as? Intent else { continue }
        nextSeq += 1
        pending.append((seq: nextSeq, intent: intent))
        let payload = serialize(intent) ?? Data()
        blobs.append(.init(seq: nextSeq, from: localPeer, payload: payload))
        // Optimistic local apply
        store.push(intent)
      }
      store.pump()
      if blobs.isEmpty { return }
      if let data = serialize(blobs) { self.sendBytes(method: RPC.recvClientIntents, data) }
    }

    // --- SERVER: handle incoming client blobs
    onClientIntentsData = { [weak store, weak self] raw in
      guard let store, let self, self.isServer else { return }
      let blobs = deserialize([NetIntentBlob].self, from: raw) ?? []
      if blobs.isEmpty { return }
      // Update acks and apply payloads
      for b in blobs {
        let last = self.serverAcks[b.from] ?? 0
        if b.seq > last { self.serverAcks[b.from] = b.seq }
        if let intent = deserialize(Intent.self, from: b.payload) {
          store.push(intent)
        }
      }
      store.pump() // after-hook will broadcast NetEvents with acks
    }

    // --- CLIENT: authoritative deltas (events) => drop acked + replay pending
    onServerEventsData = { [weak store] raw in
      guard let store else { return }
      guard let net = deserialize(NetEvents<Event>.self, from: raw) else { return }
      let lastAck = net.acks[localPeer] ?? 0

      // Drop acked
      if !pending.isEmpty {
        var i = 0
        while i < pending.count && pending[i].seq <= lastAck {
          i += 1
        }
        if i > 0 { pending.removeFirst(i) }
      }

      // Reconcile:
      // 1) Reset model to authoritative baseline.
      // 2) Apply authoritative events to advance baseline.
      // 3) Replay remaining local intents on top.
      reconciling = true
      store.model = baseline
      store.events.publish(net.events)
      baseline = store.model
      if !pending.isEmpty {
        for item in pending {
          store.push(item.intent)
        }
        store.pump()
      }
      reconciling = false
    }

    // --- CLIENT: authoritative snapshot => same reconcile path with full model
    onModelStateData = { [weak store] raw in
      guard let store else { return }
      guard let snap = deserialize(Snap<Model>.self, from: raw) else { return }
      let lastAck = snap.acks[localPeer] ?? 0

      if !pending.isEmpty {
        var i = 0
        while i < pending.count && pending[i].seq <= lastAck {
          i += 1
        }
        if i > 0 { pending.removeFirst(i) }
      }

      reconciling = true
      baseline = snap.model
      store.model = baseline
      if !pending.isEmpty {
        for item in pending {
          store.push(item.intent)
        }
        store.pump()
      }
      reconciling = false
    }
  }

  // MARK: Client-facing commit entry points (type-erased)

  private var clientCommitOne: ((Any) -> Void)?
  private var clientCommitMany: (([Any]) -> Void)?

  /// Commit a single intent.
  public func commit<I: Codable>(_ intent: I) { clientCommitOne?(intent) }

  /// Commit multiple intents.
  public func commit<I: Codable>(_ intents: [I]) { clientCommitMany?(intents.map { $0 }) }

  // MARK: Server broadcast (wraps acks + tick)

  /// Server-only: broadcast authoritative events with acks.
  public func broadcast<E: Codable>(_ events: [E]) {
    if events.isEmpty { return }
    guard isServer else { return }
    authorityTick &+= 1
    let payload = NetEvents(tick: authorityTick, acks: serverAcks, events: events)
    guard let data = serialize(payload) else { return }
    sendBytes(method: RPC.applyServerEvents, data)
  }

  /// Server-only: send full snapshot with acks.
  public func sendModelState<M: Codable>(_ model: M) {
    guard isServer else { return }
    authorityTick &+= 1
    let snap = Snap(tick: authorityTick, model: model, acks: serverAcks)
    guard let data = serialize(snap) else { return }
    sendBytes(method: RPC.applyFullModelState, data)
  }

  // MARK: RPC receive targets

  @Callable func recvClientIntents(_ bytes: PackedByteArray) {
    if getTree()?.getMultiplayer()?.isServer() != true { return }
    onClientIntentsData?(bytes.toData())
  }

  @Callable func applyServerEvents(_ bytes: PackedByteArray) {
    onServerEventsData?(bytes.toData())
  }

  @Callable func applyFullModelState(_ bytes: PackedByteArray) {
    onModelStateData?(bytes.toData())
  }

  // MARK: RPC config / signals

  private var isServer: Bool { getTree()?.getMultiplayer()?.isServer() == true }

  private func configureRpcPermissions() {
    let cfgRecv = rpcConfigDict(mode: .anyPeer, transfer: .unreliableOrdered, callLocal: false, channel: RPCChannel.gameplay.rawValue)
    rpcConfig(method: RPC.recvClientIntents, config: cfgRecv)

    let cfgApplyEvents = rpcConfigDict(mode: .authority, transfer: .unreliableOrdered, callLocal: false, channel: RPCChannel.gameplay.rawValue)
    rpcConfig(method: RPC.applyServerEvents, config: cfgApplyEvents)

    let cfgModelState = rpcConfigDict(mode: .authority, transfer: .reliable, callLocal: true, channel: RPCChannel.reliable.rawValue)
    rpcConfig(method: RPC.applyFullModelState, config: cfgModelState)
  }

  private func hookMultiplayerSignals() {
    guard let mp = getTree()?.getMultiplayer() else { return }
    _ = mp.peerConnected.connect { id in GD.print("peer_connected:", id) }
    _ = mp.peerDisconnected.connect { id in GD.print("peer_disconnected:", id) }
    _ = mp.connectedToServer.connect { GD.print("connected_to_server") }
    _ = mp.connectionFailed.connect { GD.print("connection_failed") }
    _ = mp.serverDisconnected.connect { GD.print("server_disconnected") }
  }

  // MARK: Send helper

  @inline(__always) private func sendBytes(method: StringName, _ data: Data) {
    let pba = PackedByteArray.fromData(data)
    let res = rpc(method: method, Variant(pba))
    if res != .ok { GD.print("RPC error", method, res) }
  }
}

// MARK: - RPC Config / Bridges

public typealias PeerID = Int32

private enum RPCKeys {
  static let rpcMode: StringName = "rpc_mode"
  static let transferMode: StringName = "transfer_mode"
  static let callLocal: StringName = "call_local"
  static let channel: StringName = "channel"
}

func rpcConfigDict(mode: MultiplayerAPI.RPCMode,
                   transfer: MultiplayerPeer.TransferMode,
                   callLocal: Bool,
                   channel: Int32) -> Variant
{
  let cfg = VariantDictionary()
  cfg[RPCKeys.rpcMode] = Variant(mode.rawValue)
  cfg[RPCKeys.transferMode] = Variant(transfer.rawValue)
  cfg[RPCKeys.callLocal] = Variant(callLocal)
  cfg[RPCKeys.channel] = Variant(channel)
  return Variant(cfg)
}

enum RPC {
  static let recvClientIntents = StringName("recvClientIntents")
  static let applyServerEvents = StringName("applyServerEvents")
  static let applyFullModelState = StringName("applyFullModelState")
}

enum RPCChannel: Int32 { case reliable = 0, gameplay = 1 }

// MARK: - PackedByteArray ↔︎ Data

extension PackedByteArray {
  static func fromData(_ data: Data) -> PackedByteArray {
    let p = PackedByteArray()
    data.withUnsafeBytes { raw in
      guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
      var i = 0
      while i < data.count {
        p.append(base[i]); i += 1
      }
    }
    return p
  }

  func toData() -> Data {
    var d = Data()
    d.reserveCapacity(Int(size()))
    var i = 0
    while i < Int(size()) {
      d.append(self[i]); i += 1
    }
    return d
  }
}

// MARK: - Wire formats + helpers

/// Per-intent envelope sent Client -> Server, payload is MessagePack bytes of the intent.
/// Using a blob keeps NetworkStore API generic without knowing `Intent` at callsite.
public struct NetIntentBlob: Codable {
  public var seq: Int64
  public var from: PeerID
  public var payload: Data
  public init(seq: Int64, from: PeerID, payload: Data) { self.seq = seq; self.from = from; self.payload = payload }
}

/// Server -> Clients delta payload (authoritative).
public struct NetEvents<E: Codable>: Codable {
  public var tick: Int64
  public var acks: [PeerID: Int64]
  public var events: [E]
  public init(tick: Int64, acks: [PeerID: Int64], events: [E]) { self.tick = tick; self.acks = acks; self.events = events }
}

/// Server -> Clients full snapshot (authoritative).
public struct Snap<M: Codable>: Codable {
  public var tick: Int64
  public var model: M
  public var acks: [PeerID: Int64]
  public init(tick: Int64, model: M, acks: [PeerID: Int64]) { self.tick = tick; self.model = model; self.acks = acks }
}

// MessagePack helpers
@inline(__always) func serialize<T: Codable>(_ value: T) -> Data? { try? MessagePackEncoder().encode(value) }
@inline(__always) func deserialize<T: Codable>(_: T.Type, from data: Data) -> T? { try? MessagePackDecoder().decode(T.self, from: data) }
