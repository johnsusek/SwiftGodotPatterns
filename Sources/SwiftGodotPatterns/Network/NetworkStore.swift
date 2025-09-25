import Foundation
import SwiftGodot

/// A networking bridge node that wires your game's model/store to Godot's
/// high-level multiplayer API (HLMP).
///
/// `NetworkStore` handles three lanes of traffic:
/// - **Client -> Server**: batched *intents* from a client to the authority.
/// - **Server -> Clients (delta)**: batched *events* fan-out to all clients.
/// - **Server -> Clients (snapshot)**: occasional *full-state* snapshots (reliable).
///
/// It also configures per-RPC permissions (authority/anyPeer), transfer modes
/// (reliable/unreliableOrdered), and channels (e.g. gameplay vs reliable).
///
/// The node does not interpret your domain data; it only ships JSON strings and
/// exposes closures you can bind to your own store/model.
@Godot
public final class NetworkStore: Node {
  /// A full-state snapshot used for reliable resyncs and join-in-progress.
  ///
  /// - Parameters:
  ///   - tick: An authoritative tick/frame index to aid client reconciliation.
  ///   - model: The complete model payload to replace the client's local model.
  public struct ModelSnapshot<Model: Codable>: Codable {
    /// Authoritative tick/frame index for reconciliation.
    public var tick: Int64
    /// Complete authoritative model.
    public var model: Model

    /// Creates a new model snapshot.
    public init(tick: Int64, model: Model) {
      self.tick = tick
      self.model = model
    }
  }

  // MARK: Hooks

  /// Called **on the server** when a client batch of intents arrives (already a JSON string).
  ///
  /// You usually bind this to a function that decodes into your `Intent` array and pushes
  /// them into your authoritative store, then pumps the store.
  public var onClientIntentsPayload: ((String) -> Void)?

  /// Called **on clients** when the server broadcasts a batch of events (JSON string).
  ///
  /// Bind this to your event bus to apply deltas to your client-side model.
  public var onServerEventsPayload: ((String) -> Void)?

  /// Called **on clients** when the server sends a full model snapshot (JSON string).
  ///
  /// Bind this to a decoder that sets your client-side model wholesale.
  public var onModelStatePayload: ((String) -> Void)?

  /// The current peer's unique identifier from Godot's multiplayer layer.
  ///
  /// Returns `0` if the tree or multiplayer interface is missing.
  public var peerID: Int32 { getTree()?.getMultiplayer()?.getUniqueId() ?? 0 }

  /// Godot lifecycle entry; configures RPC permissions and subscribes multiplayer signals.
  override public func _ready() { configureRpcPermissions(); hookMultiplayerSignals() }

  // MARK: Client -> Server

  /// Sends a raw JSON batch of **intents** from a client to the server.
  ///
  /// - Parameter s: A UTF-8 JSON string representing `[Intent]` (your type).
  ///
  /// The RPC is configured as:
  /// - `mode`: `.anyPeer` (only non-authority callers are allowed)
  /// - `transfer`: `.unreliableOrdered`
  /// - `channel`: ``NetChannel/gameplay``
  ///
  /// - Important: You are responsible for encoding your intent array into the string.
  public func sendIntentsPayload(_ s: String) {
    let res = rpc(method: RPC.recvClientIntents, Variant(s))
    if res != .ok { GD.print("RPC error sendIntentsPayload:", res) }
  }

  // MARK: Server -> Clients (events)

  /// Broadcasts a raw JSON batch of **events** from the server to all clients.
  ///
  /// - Parameter s: A UTF-8 JSON string representing `[Event]` (your type).
  ///
  /// The RPC is configured as:
  /// - `mode`: `.authority` (only the server may call)
  /// - `transfer`: `.unreliableOrdered`
  /// - `channel`: ``NetChannel/gameplay``
  ///
  /// Use this for frame-to-frame deltas (positions, inputs that became events, etc.).
  public func broadcastEventsPayload(_ s: String) {
    let res = rpc(method: RPC.applyServerEvents, Variant(s))
    if res != .ok { GD.print("RPC error broadcastEventsPayload:", res) }
  }

  // MARK: Server -> Clients (full model snapshot)

  /// Sends a **full model snapshot** from the server to clients (reliable).
  ///
  /// - Parameter s: A UTF-8 JSON string representing ``ModelSnapshot`` of your `Model`.
  ///
  /// The RPC is configured as:
  /// - `mode`: `.authority`
  /// - `transfer`: `.reliable`
  /// - `channel`: ``NetChannel/reliable``
  ///
  /// Use snapshots to correct drift or for join-in-progress.
  public func sendModelStatePayload(_ s: String) {
    let res = rpc(method: RPC.applyFullModelState, Variant(s))
    if res != .ok { GD.print("RPC error sendModelStatePayload:", res) }
  }

  // MARK: RPC targets

  /// RPC target invoked on the **server** when a client sent a batch of intents.
  ///
  /// - Parameter payload: JSON string `[Intent]`.
  /// - Note: Guarded so only the authority processes it.
  @Callable func recvClientIntents(_ payload: String) {
    if getTree()?.getMultiplayer()?.isServer() != true { return }
    onClientIntentsPayload?(payload)
  }

  /// RPC target invoked on **clients** when the server broadcasted events.
  ///
  /// - Parameter payload: JSON string `[Event]`.
  @Callable func applyServerEvents(_ payload: String) { onServerEventsPayload?(payload) }

  /// RPC target invoked on **clients** when the server sent a full model snapshot.
  ///
  /// - Parameter payload: JSON string `ModelSnapshot<Model>`.
  @Callable func applyFullModelState(_ payload: String) { onModelStatePayload?(payload) }

  // MARK: RPC Permissions

  /// Defines per-method RPC permissions, transport, and channel assignments.
  ///
  /// - Important: Keep channels stable across client and server; mismatched channels will
  ///   silently drop messages.
  private func configureRpcPermissions() {
    // Client -> Server: anyPeer on gameplay channel (unreliable ordered)
    let cfgRecv = rpcConfigDict(mode: .anyPeer,
                                transfer: .unreliableOrdered,
                                callLocal: false,
                                channel: NetChannel.gameplay.rawValue)
    rpcConfig(method: RPC.recvClientIntents, config: cfgRecv)

    // Server -> Clients (events): authority on gameplay channel (unreliable ordered)
    let cfgApplyEvents = rpcConfigDict(mode: .authority,
                                       transfer: .unreliableOrdered,
                                       callLocal: false,
                                       channel: NetChannel.gameplay.rawValue)
    rpcConfig(method: RPC.applyServerEvents, config: cfgApplyEvents)

    // Server -> Clients (snapshot): authority on reliable channel, callLocal=true for host-play
    let cfgModelState = rpcConfigDict(mode: .authority,
                                      transfer: .reliable,
                                      callLocal: true,
                                      channel: NetChannel.reliable.rawValue)
    rpcConfig(method: RPC.applyFullModelState, config: cfgModelState)
  }

  // MARK: Multiplayer signals

  /// Subscribes to useful multiplayer signals for minimal diagnostics.
  ///
  /// Prints events such as `peer_connected`, `peer_disconnected`,
  /// `connected_to_server`, `connection_failed`, and `server_disconnected`.
  private func hookMultiplayerSignals() {
    guard let mp = getTree()?.getMultiplayer() else { return }
    _ = mp.peerConnected.connect { id in GD.print("peer_connected:", id) }
    _ = mp.peerDisconnected.connect { id in GD.print("peer_disconnected:", id) }
    _ = mp.connectedToServer.connect { GD.print("connected_to_server") }
    _ = mp.connectionFailed.connect { GD.print("connection_failed") }
    _ = mp.serverDisconnected.connect { GD.print("server_disconnected") }
  }
}

// MARK: - Store wiring helpers

public extension NetworkStore {
  /// Wires the node's payload hooks into a generic authoritative store.
  ///
  /// - Parameters:
  ///   - store: Your store instance which exposes:
  ///     - `push(_:)` and `pump()` for intents (server-side),
  ///     - an `events` publisher for event fan-out (client-side),
  ///     - a mutable `model` for snapshots (client-side).
  func wire<Model: Codable, Intent: NetBatch, Event: NetBatch>(
    store: Store<Model, Intent, Event>
  ) {
    onClientIntentsPayload = { [weak store] s in
      let intents = Intent.decodeBatch(s)
      if intents.isEmpty { return }
      intents.forEach { store?.push($0) }
      store?.pump()
    }
    onServerEventsPayload = { [weak store] s in
      let events = Event.decodeBatch(s)
      if events.isEmpty { return }
      store?.events.publish(events)
    }
    onModelStatePayload = { [weak store] s in
      guard let d = s.data(using: .utf8),
            let snap = try? JSONDecoder().decode(ModelSnapshot<Model>.self, from: d) else { return }
      store?.model = snap.model
    }

    // Server-side: auto-broadcast post-commit
    store.use(.init(after: { [weak self] _, _, events in
      if events.isEmpty { return }
      self?.broadcast(events)
    }))
  }

  /// Encodes and sends a batch of `Intent` values from a client to the server.
  ///
  /// - Parameter xs: Intents to encode and send. No-op if empty.
  /// - SeeAlso: ``NetBatch`` for the default JSON encoder/decoder.
  func sendIntents<Intent: NetBatch>(_ xs: [Intent]) {
    if xs.isEmpty { return }
    sendIntentsPayload(Intent.encodeBatch(xs))
  }

  /// Encodes and broadcasts a batch of `Event` values from the server to clients.
  ///
  /// - Parameter xs: Events to encode and broadcast. No-op if empty.
  func broadcast<Event: NetBatch>(_ xs: [Event]) {
    if xs.isEmpty { return }
    broadcastEventsPayload(Event.encodeBatch(xs))
  }

  /// Encodes and sends a full model snapshot from the server to clients.
  ///
  /// - Parameter snap: The snapshot to serialize and send.
  func sendModelState<Model: Codable>(_ snap: ModelSnapshot<Model>) {
    guard let d = try? JSONEncoder().encode(snap),
          let s = String(data: d, encoding: .utf8) else { return }
    sendModelStatePayload(s)
  }
}

// MARK: - RPC configuration helpers

private enum RPCKeys {
  /// VariantDictionary key: `.rpc_mode` (authority/anyPeer)
  static let rpcMode: StringName = "rpc_mode"
  /// VariantDictionary key: `.transfer_mode` (reliable/unreliableOrdered/unreliable)
  static let transferMode: StringName = "transfer_mode"
  /// VariantDictionary key: `.call_local` (invoke locally on the caller too)
  static let callLocal: StringName = "call_local"
  /// VariantDictionary key: `.channel` (integer channel identifier)
  static let channel: StringName = "channel"
}

/// Builds a Variant dictionary for Godot's `rpc_config`.
@inline(__always)
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

// MARK: - RPC method names & channels

private enum RPC {
  static let recvClientIntents = StringName("recvClientIntents")
  static let applyServerEvents = StringName("applyServerEvents")
  static let applyFullModelState = StringName("applyFullModelState")
}

/// Logical channels for HLMP traffic.
private enum NetChannel: Int32 {
  case reliable = 0, gameplay = 1
}

// MARK: - Batch codec

/// A tiny protocol for batched JSON transport.
///
/// Conform your `Intent` and `Event` enums/structs to `NetBatch` to get
/// default JSON batch encoding/decoding helpers.
///
/// The default implementation uses `JSONEncoder`/`JSONDecoder` with UTF-8 strings.
public protocol NetBatch: Codable {
  /// Encodes an array of values into a compact JSON string.
  static func encodeBatch(_ items: [Self]) -> String
  /// Decodes values from a JSON string into an array.
  static func decodeBatch(_ s: String) -> [Self]
}

public extension NetBatch {
  /// Encodes an array into a UTF-8 JSON string, or `"[]"` on failure.
  static func encodeBatch(_ items: [Self]) -> String {
    let enc = JSONEncoder()
    enc.outputFormatting = []
    return (try? enc.encode(items)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
  }

  /// Decodes an array from a UTF-8 JSON string, or `[]` on failure.
  static func decodeBatch(_ s: String) -> [Self] {
    guard let data = s.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([Self].self, from: data)) ?? []
  }
}

/// An example intent envelope used by some games.
///
/// You can replace this with your own domain-specific intents, or
/// `extra` is provided so you can piggyback custom payloads without changing transport.
public enum NetworkIntent<Extra: Codable>: Codable {
  /// Client requests to join the session.
  case join
  /// Client requests to leave the session.
  case leave
  /// Domain-specific extensibility hook.
  case extra(Extra)
}

/// An example event envelope used by some games.
///
/// You can replace this with your own domain-specific events, or
/// `extra` is provided so you can piggyback custom payloads without changing transport.
public enum NetworkEvent<Extra: Codable>: Codable {
  /// A peer was spawned into the world at a position.
  case spawned(peer: Int32, at: Vector2)
  /// A peer was despawned/removed from the world.
  case despawned(peer: Int32)
  /// Domain-specific extensibility hook.
  case extra(Extra)
}
