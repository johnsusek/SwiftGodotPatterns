import Compression
import Foundation
import SwiftGodot

// MARK: - NetworkStore

/// A bridge node that ships opaque payloads between your local store/model
/// and Godot's High-Level Multiplayer API (HLMP).
///
/// It provides three lanes:
/// - Client -> Server: batched *intents*
/// - Server -> Clients (delta): batched *events*
/// - Server -> Clients (snapshot): *full model* state
///
/// The node does **not** interpret domain types. It only encodes/decodes via
/// `Codable` (JSON) and forwards raw bytes over RPC.
///
/// - Important: This node performs no reliability/ordering beyond HLMP config.
///   Use `.reliable` only for rare snapshots; keep deltas unordered for speed.
@Godot
public final class NetworkStore: Node {
  /// Full-state snapshot used for reliable resyncs and join-in-progress.
  ///
  /// Encode your entire model plus an authoritative `tick` to help clients
  /// reconcile local prediction.
  public struct ModelSnapshot<Model: Codable>: Codable {
    /// Authoritative frame/tick associated with `model`.
    public var tick: Int64
    /// The complete model to replace the client's local state.
    public var model: Model
    public init(tick: Int64, model: Model) {
      self.tick = tick
      self.model = model
    }
  }

  // MARK: Hooks (compressed bytes)

  /// Client -> Server hook. Receives raw payload bytes for *intents*.
  /// - Note: Bytes are whatever your encoding produced (currently JSON Data).
  public var onClientIntentsData: ((Data) -> Void)?

  /// Server -> Clients hook. Receives raw payload bytes for *events*.
  public var onServerEventsData: ((Data) -> Void)?

  /// Server -> Clients hook. Receives raw payload bytes for *full model* state.
  public var onModelStateData: ((Data) -> Void)?

  /// Current peer id from `MultiplayerAPI`. Returns `0` if unavailable.
  public var peerID: Int32 { getTree()?.getMultiplayer()?.getUniqueId() ?? 0 }

  /// Godot lifecycle: configure RPC permissions and minimal diagnostics.
  override public func _ready() {
    configureRpcPermissions()
    hookMultiplayerSignals()
  }

  // MARK: Client -> Server (send)

  /// Sends a batch of client *intents* to the authority.
  ///
  /// - Parameters:
  ///   - items: Encodable intents. Empty arrays are ignored.
  /// - Note: Encoded via `JSONEncoder` and sent with unordered unreliable RPC.
  public func sendIntents<T: Codable>(_ items: [T]) {
    if items.isEmpty { return }
    guard let data = encodeJSON(items) else { return }
    sendBytes(method: RPC.recvClientIntents, data)
  }

  // MARK: Server -> Clients (send)

  /// Broadcasts server *events* to all clients (delta updates).
  ///
  /// - Parameters:
  ///   - events: Encodable events. Empty arrays are ignored.
  /// - Note: Unordered unreliable RPC by default for throughput.
  public func broadcast<T: Codable>(_ events: [T]) {
    if events.isEmpty { return }
    guard let data = encodeJSON(events) else { return }
    sendBytes(method: RPC.applyServerEvents, data)
  }

  /// Sends a reliable full-model snapshot to all clients.
  ///
  /// Use sparingly (e.g., on join or periodic desync correction).
  public func sendModelState<Model: Codable>(_ snap: ModelSnapshot<Model>) {
    guard let data = encodeJSON(snap) else { return }
    sendBytes(method: RPC.applyFullModelState, data)
  }

  /// Wires `NetworkStore` to a local `Store` by installing encode/decode bridges
  /// and publishing events produced by the local reducer.
  ///
  /// - Parameters:
  ///   - store: Your game store (`model`, `intents`, `events`).
  /// - Behavior:
  ///   - Incoming client intents -> `store.push` then `store.pump()`
  ///   - Incoming server events -> `store.events.publish`
  ///   - Incoming full model -> `store.model = snapshot.model`
  ///   - Outbound events (locally produced) -> `broadcast(_:)`
  /// - Warning: This assumes matching `Model/Intent/Event` types across peers.
  public func wire<Model: Codable, Intent: Codable, Event: Codable>(to store: Store<Model, Intent, Event>) {
    onClientIntentsData = { [weak store] raw in
      let intents = decodeJSON([Intent].self, from: raw) ?? []
      if intents.isEmpty { return }
      intents.forEach { store?.push($0) }
      store?.pump()
    }
    onServerEventsData = { [weak store] raw in
      let events = decodeJSON([Event].self, from: raw) ?? []
      if events.isEmpty { return }
      store?.events.publish(events)
    }
    onModelStateData = { [weak store] raw in
      guard let snap = decodeJSON(ModelSnapshot<Model>.self, from: raw) else { return }
      store?.model = snap.model
    }

    store.use(.init(after: { [weak self] _, _, events in
      if events.isEmpty { return }
      self?.broadcast(events)
    }))
  }

  // MARK: RPC targets (receive)

  /// RPC target (authority only): receives client *intents* bytes.
  /// - Parameter bytes: Payload as `PackedByteArray`.
  /// - Note: Drops calls if not server/authority.
  @Callable func recvClientIntents(_ bytes: PackedByteArray) {
    if getTree()?.getMultiplayer()?.isServer() != true { return }
    let data = bytes.toData()
    onClientIntentsData?(data)
  }

  /// RPC target: applies server *events* bytes on all peers.
  @Callable func applyServerEvents(_ bytes: PackedByteArray) {
    let data = bytes.toData()
    onServerEventsData?(data)
  }

  /// RPC target: applies a reliable full-model snapshot on all peers.
  @Callable func applyFullModelState(_ bytes: PackedByteArray) {
    let data = bytes.toData()
    onModelStateData?(data)
  }

  // MARK: RPC Permissions

  /// Configures HLMP RPC permissions, transfer modes, and channels.
  ///
  /// - Design:
  ///   - `recvClientIntents`: any peer -> server, unordered unreliable (gameplay)
  ///   - `applyServerEvents`: server -> all, unordered unreliable (gameplay)
  ///   - `applyFullModelState`: server -> all, reliable (separate channel)
  private func configureRpcPermissions() {
    let cfgRecv = rpcConfigDict(mode: .anyPeer, transfer: .unreliableOrdered, callLocal: false, channel: RPCChannel.gameplay.rawValue)
    rpcConfig(method: RPC.recvClientIntents, config: cfgRecv)

    let cfgApplyEvents = rpcConfigDict(mode: .authority, transfer: .unreliableOrdered, callLocal: false, channel: RPCChannel.gameplay.rawValue)
    rpcConfig(method: RPC.applyServerEvents, config: cfgApplyEvents)

    let cfgModelState = rpcConfigDict(mode: .authority, transfer: .reliable, callLocal: true, channel: RPCChannel.reliable.rawValue)
    rpcConfig(method: RPC.applyFullModelState, config: cfgModelState)
  }

  // MARK: Multiplayer signals (minimal diagnostics)

  /// Subscribes to a few `MultiplayerAPI` signals for lightweight logging.
  private func hookMultiplayerSignals() {
    guard let mp = getTree()?.getMultiplayer() else { return }
    _ = mp.peerConnected.connect { id in GD.print("peer_connected:", id) }
    _ = mp.peerDisconnected.connect { id in GD.print("peer_disconnected:", id) }
    _ = mp.connectedToServer.connect { GD.print("connected_to_server") }
    _ = mp.connectionFailed.connect { GD.print("connection_failed") }
    _ = mp.serverDisconnected.connect { GD.print("server_disconnected") }
  }

  // MARK: Send helper

  /// Encodes `Data` into a `PackedByteArray` and performs the RPC call.
  ///
  /// - Parameters:
  ///   - method: The RPC method name (`StringName`).
  ///   - data: Raw payload bytes (typically JSON).
  /// - Note: Logs non-`ok` status for quick diagnostics.
  @inline(__always) private func sendBytes(method: StringName, _ data: Data) {
    let pba = PackedByteArray.fromData(data)
    let res = rpc(method: method, Variant(pba))
    if res != .ok { GD.print("RPC error", method, res) }
  }
}

// MARK: - RPC Config

/// Internal RPC config dictionary keys for HLMP.
private enum RPCKeys {
  static let rpcMode: StringName = "rpc_mode"
  static let transferMode: StringName = "transfer_mode"
  static let callLocal: StringName = "call_local"
  static let channel: StringName = "channel"
}

/// Builds a `Variant` wrapping a `VariantDictionary` suitable for `rpcConfig`.
///
/// - Parameters:
///   - mode: Who may call (e.g., `.anyPeer`, `.authority`).
///   - transfer: Reliability/ordering (e.g., `.reliable`, `.unreliableOrdered`).
///   - callLocal: Whether local call should fire alongside networked call.
///   - channel: HLMP channel index (e.g., gameplay vs reliable).
/// - Returns: A `Variant` holding the config dictionary.
private func rpcConfigDict(mode: MultiplayerAPI.RPCMode,
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

/// RPC method names used by this node.
private enum RPC {
  static let recvClientIntents = StringName("recvClientIntents")
  static let applyServerEvents = StringName("applyServerEvents")
  static let applyFullModelState = StringName("applyFullModelState")
}

/// Channels for separating reliable vs gameplay traffic.
private enum RPCChannel: Int32 { case reliable = 0, gameplay = 1 }

// MARK: - JSON helpers

/// Encodes a `Codable` value using `JSONEncoder`.
/// - Returns: `Data` on success, otherwise `nil`.
@inline(__always) func encodeJSON<T: Codable>(_ value: T) -> Data? { try? JSONEncoder().encode(value) }

/// Decodes a `Codable` value from `Data` using `JSONDecoder`.
/// - Parameters:
///   - _: The target type (for inference only).
///   - data: Raw JSON bytes.
/// - Returns: Decoded instance on success, otherwise `nil`.
@inline(__always) func decodeJSON<T: Codable>(_: T.Type, from data: Data) -> T? { try? JSONDecoder().decode(T.self, from: data) }

// MARK: - PackedByteArray ↔︎ Data bridge

private extension PackedByteArray {
  /// Copies Swift `Data` into a new `PackedByteArray`.
  ///
  /// - Note: Performs a byte-wise append. Reserve/copy optimizations can be
  ///   introduced later if profiling shows this as a hotspot.
  static func fromData(_ data: Data) -> PackedByteArray {
    let p = PackedByteArray()
    data.withUnsafeBytes { raw in
      guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
      var i = 0
      while i < data.count {
        p.append(base[i])
        i += 1
      }
    }
    return p
  }

  /// Copies a `PackedByteArray` into Swift `Data`.
  ///
  /// - Note: Reserves capacity up front to avoid repeated reallocations.
  func toData() -> Data {
    var d = Data()
    d.reserveCapacity(Int(size()))
    var i = 0
    while i < Int(size()) {
      d.append(self[i])
      i += 1
    }
    return d
  }
}
