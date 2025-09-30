import Foundation

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
