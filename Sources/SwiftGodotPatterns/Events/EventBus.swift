import Foundation

/// A thread-safe publish/subscribe bus for in-process events.
///
/// ### Example
/// ```swift
/// enum AppEvent { case ping(String) }
/// let bus = EventBus<AppEvent>()
///
/// let token = bus.onEach { event in
///   if case let .ping(message) = event { print("got:", message) }
/// }
///
/// bus.publish(.ping("hello"))
/// bus.cancel(token)
/// ```
public final class EventBus<Event> {
  /// Opaque handle used to cancel a previously registered handler.
  public typealias Token = UUID

  private var handlers: [Token: (Event) -> Void] = [:]
  private var batchHandlers: [Token: ([Event]) -> Void] = [:]
  private let lock = NSLock()

  /// Registers a handler invoked once for every published event.
  ///
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
  @discardableResult
  public func onBatch(_ h: @escaping ([Event]) -> Void) -> Token {
    let id = UUID()
    lock.lock()
    batchHandlers[id] = h
    lock.unlock()
    return id
  }

  /// Cancels a previously registered handler.
  public func cancel(_ id: Token) {
    lock.lock()
    handlers.removeValue(forKey: id)
    batchHandlers.removeValue(forKey: id)
    lock.unlock()
  }

  /// Publishes a single event to all per-event handlers.
  public func publish(_ e: Event) {
    lock.lock()
    let hs = Array(handlers.values)
    lock.unlock()
    for h in hs {
      h(e)
    }
  }

  /// Publishes a batch of events.
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
