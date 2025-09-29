import Foundation

/// A thread-safe publish/subscribe hub for in-process events.
///
/// `EventHub` lets you:
/// - Register per-event handlers with ``onEach(_:)``.
/// - Register batch handlers with ``onBatch(_:)`` that receive whole arrays.
/// - Publish events synchronously on the caller's thread with ``publish(_:)``.
/// - Cancel handlers using an opaque ``Token`` from registration.
///
/// **Thread safety:** Registration/cancellation and handler snapshotting are protected by an internal `NSLock`.
/// Handlers are always invoked *after* the lock is released to avoid deadlocks and allow reentrancy
/// (handlers may publish or cancel).
///
/// **Ordering:** Delivery order is not guaranteed and should be treated as unspecified.
///
/// **Execution context:** Handlers run synchronously on the thread that calls `publish`. Offload long work.
///
/// ### Example
/// ```swift
/// enum AppEvent { case ping(String) }
/// let hub = EventHub<AppEvent>()
///
/// let token = hub.onEach { event in
///   if case let .ping(message) = event { print("got:", message) }
/// }
///
/// hub.publish(.ping("hello"))
/// hub.cancel(token)
/// ```
public final class EventHub<Event> {
  /// Opaque handle used to cancel a previously registered handler.
  public typealias Token = UUID

  private var handlers: [Token: (Event) -> Void] = [:]
  private var batchHandlers: [Token: ([Event]) -> Void] = [:]
  private let lock = NSLock()

  /// Registers a handler invoked once for every published event.
  ///
  /// The handler is called for single publishes via ``publish(_:)`` and for each element of a batch
  /// via ``publish(_:)`` (batch overload).
  ///
  /// - Parameter h: Closure executed synchronously on the publisher's thread for each event.
  /// - Returns: A ``Token`` that can be passed to ``cancel(_:)`` to stop receiving events.
  /// - Important: Keep the handler fast or dispatch to a background queue to avoid blocking the publisher.
  @discardableResult
  public func onEach(_ h: @escaping (Event) -> Void) -> Token {
    let id = UUID()
    lock.lock()
    handlers[id] = h
    lock.unlock()
    return id
  }

  /// Registers a handler invoked once per batch publish.
  ///
  /// The handler receives the entire batch array exactly once for each call to the batch
  /// ``publish(_:)`` overload.
  ///
  /// - Parameter h: Closure executed synchronously on the publisher's thread with the full batch.
  /// - Returns: A ``Token`` that can be passed to ``cancel(_:)``.
  /// - Note: Batch handlers are called *after* all per-event handlers have processed the batch.
  @discardableResult
  public func onBatch(_ h: @escaping ([Event]) -> Void) -> Token {
    let id = UUID()
    lock.lock()
    batchHandlers[id] = h
    lock.unlock()
    return id
  }

  /// Cancels a previously registered handler.
  ///
  /// - Parameter id: The registration token returned from ``onEach(_:)`` or ``onBatch(_:)``.
  /// - Discussion: If the token is unknown or already canceled, this is a no-op.
  public func cancel(_ id: Token) {
    lock.lock()
    handlers.removeValue(forKey: id)
    batchHandlers.removeValue(forKey: id)
    lock.unlock()
  }

  /// Publishes a single event to all per-event handlers.
  ///
  /// The handler list is snapshotted under lock, then invoked outside the lock to allow reentrancy.
  ///
  /// - Parameter e: The event to deliver.
  public func publish(_ e: Event) {
    lock.lock()
    let hs = Array(handlers.values)
    lock.unlock()
    for h in hs {
      h(e)
    }
  }

  /// Publishes a batch of events.
  ///
  /// Processing occurs in two phases:
  /// 1. Each element of `batch` is delivered to all per-event handlers (in batch order).
  /// 2. Each batch handler is invoked once with the full `batch`.
  ///
  /// - Parameter batch: Events to deliver. Empty arrays are ignored.
  /// - Note: Per-event handlers run before batch handlers.
  public func publish(_ batch: [Event]) {
    if batch.isEmpty { return }
    lock.lock()
    let es = Array(handlers.values)
    let bs = Array(batchHandlers.values)
    lock.unlock()
    for e in batch {
      for h in es {
        h(e)
      }
    }
    for h in bs {
      h(batch)
    }
  }
}

/// A type-indexed global registry of shared ``EventHub`` instances.
///
/// Acts like a lazy singleton per event type within the current process. Useful when many
/// parts of an app need to rendezvous on a common bus without passing references around.
///
/// ### Example
/// ```swift
/// enum LogEvent { case line(String) }
/// let hub = GlobalEventBuses.hub(LogEvent.self)
/// let token = hub.onEach { print($0) }
/// hub.publish(.line("ready"))
/// ```
public enum GlobalEventBuses {
  private static var map: [ObjectIdentifier: Any] = [:]
  private static let lock = NSLock()

  /// Returns the shared hub for the given event type.
  ///
  /// - Parameter _: The event type used to key the hub.
  /// - Returns: The process-wide shared ``EventHub`` for `E`.
  /// - Discussion: The hub is created on first access and reused thereafter.
  public static func hub<E>(_: E.Type) -> EventHub<E> {
    let key = ObjectIdentifier(E.self)
    lock.lock()
    defer { lock.unlock() }
    if let any = map[key], let hub = any as? EventHub<E> { return hub }
    let hub = EventHub<E>()
    map[key] = hub
    return hub
  }
}

/// Transforms intents into state mutations and outbound events.
///
/// `Mutator` wraps an `apply` function suitable for unidirectional data flow:
/// given a list of `Intent`, it mutates `State` in-place and appends produced `Event`s to `out`.
///
/// - Type Parameters:
///   - State: The mutable state being updated.
///   - Intent: The input commands/intentions to apply.
///   - Event: The side-effect outputs produced during application.
///
/// ### Example
/// ```swift
/// struct Counter { var value = 0 }
/// enum Intent { case inc, dec }
/// enum Event { case clamped }
///
/// let mutator = Mutator<Counter, Intent, Event> { intents, state, out in
///   for intent in intents {
///     switch intent {
///     case .inc: state.value += 1
///     case .dec: state.value -= 1
///     }
///   }
///   if state.value < 0 { state.value = 0; out.append(.clamped) }
/// }
/// ```
public struct Mutator<State, Intent, Event> {
  /// The reducer: applies `intents` to `state`, appending any produced events to `out`.
  public let apply: (_ state: inout State, _ intents: [Intent], _ out: inout [Event]) -> Void

  /// Creates a new mutator with the provided reducer.
  ///
  /// - Parameter apply: Closure that mutates `state` for each intent and appends any emitted events to `out`.
  public init(_ apply: @escaping (inout State, [Intent], inout [Event]) -> Void) { self.apply = apply }
}
