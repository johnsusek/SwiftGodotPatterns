import Foundation
import SwiftGodot

/// A type alias for ``GState`` to provide a more convenient API surface.
public typealias State = GState

// MARK: - State Property Wrapper

/// A property wrapper that manages observable state in Godot nodes.
///
/// `GState` provides a reactive state management mechanism similar to SwiftUI's `@State`.
/// When the wrapped value changes, all registered listeners are notified automatically.
///
/// ## Usage
///
/// Use `@State` (or `@GState`) to declare state variables in your views:
///
/// ```swift
/// @State var counter = 0
/// @State var isVisible = true
/// ```
///
/// Access the state value directly, and modifications will trigger updates:
///
/// ```swift
/// counter += 1  // Notifies all listeners
/// ```
@propertyWrapper
public final class GState<Value: Equatable> {
  private var value: Value
  private var listeners: [(Value) -> Void] = []

  /// The underlying value being wrapped by this state container.
  ///
  /// Reading this property returns the current value. Setting this property
  /// updates the value and notifies all registered listeners.
  public var wrappedValue: Value {
    get { value }
    set {
      // Prevent infinite loops by checking if the value actually changed
      guard value != newValue else { return }
      value = newValue
      notifyListeners()
    }
  }

  /// A projection of the state that can be passed as a binding.
  ///
  /// Use the `$` prefix to access this property:
  ///
  /// ```swift
  /// @State var count = 0
  /// ChildView(value: $count)  // Passes the GState instance
  /// ```
  public var projectedValue: GState<Value> { self }

  /// Creates a new state container with an initial value.
  ///
  /// - Parameter wrappedValue: The initial value to store in this state container.
  public init(wrappedValue: Value) {
    value = wrappedValue
  }

  /// Registers a closure to be called whenever the state value changes.
  ///
  /// The handler is called immediately with the current value, and then
  /// again each time the value changes.
  ///
  /// - Parameter handler: A closure that receives the new value whenever it changes.
  func onChange(_ handler: @escaping (Value) -> Void) {
    listeners.append(handler)
    handler(value) // Call immediately with current value
  }

  /// Notifies all registered listeners of the current value.
  private func notifyListeners() {
    for listener in listeners {
      listener(value)
    }
  }
}
