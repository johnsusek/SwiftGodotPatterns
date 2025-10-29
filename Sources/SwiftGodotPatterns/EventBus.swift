import Foundation

/// A thread-safe publish/subscribe bus for in-process events.
///
/// For engine-layer or cross-cutting services (audio, input, event bus, save system).
/// Keep gameplay/domain logic on constructor injection so dependencies are explicit where
/// it matters for reasoning and tests.
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
  private let lock = NSLock()

  init(handlers: [Token: (Event) -> Void] = [:]) {
    self.handlers = handlers
  }

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

  /// Cancels a previously registered handler.
  public func cancel(_ id: Token) {
    lock.lock()
    handlers.removeValue(forKey: id)
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
}

/// Convenience extensions for logging events to MsgLog.
public extension EventBus {
  /// Logs every event to MsgLog until the returned token is cancelled.
  @discardableResult
  func tapLog(level: MsgLog.Level = .debug, name: String? = nil, format: ((Event) -> String)? = nil) -> Token {
    onEach { event in
      let body = format?(event) ?? String(describing: event)
      if body.isEmpty { return }
      MsgLog.shared.write("[\(name ?? "EventBus")] \(body)", level: level)
    }
  }
}

/// A type-indexed global registry of shared ``EventBus`` instances.
///
/// Acts like a lazy singleton per event type within the current process. Useful when many
/// parts of an app need to rendezvous on a common bus without passing references around.
///
/// ### Example
/// ```swift
/// enum LogEvent { case line(String) }
/// let bus = ServiceLocator.resolve(LogEvent.self)
/// let token = bus.onEach { print($0) }
/// bus.publish(.line("ready"))
/// ```
public enum ServiceLocator {
  private static var map: [ObjectIdentifier: Any] = [:]
  private static let lock = NSLock()

  /// Returns the shared bus for the given event type.
  ///
  /// - Parameter _: The event type used to key the bus.
  /// - Returns: The process-wide shared ``EventBus`` for `E`.
  /// - Discussion: The bus is created on first access and reused thereafter.
  public static func resolve<E>(_: E.Type) -> EventBus<E> {
    let key = ObjectIdentifier(E.self)
    lock.lock()
    defer { lock.unlock() }
    if let any = map[key], let bus = any as? EventBus<E> { return bus }
    let bus = EventBus<E>()
    map[key] = bus
    return bus
  }
}
