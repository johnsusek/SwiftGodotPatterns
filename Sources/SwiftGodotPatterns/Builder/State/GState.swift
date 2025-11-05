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
///
/// Use the projected value (`$counter`) to pass bindings to child components:
///
/// ```swift
/// ChildView(count: $counter)
/// ```
@propertyWrapper
public final class GState<Value> {
  private var value: Value
  private var listeners: [(Value) -> Void] = []
  private let isEquatable: Bool

  /// The underlying value being wrapped by this state container.
  ///
  /// Reading this property returns the current value. Setting this property
  /// updates the value and notifies all registered listeners.
  public var wrappedValue: Value {
    get { value }
    set {
      // Prevent infinite loops by checking if the value actually changed
      if isEquatable, let oldEquatable = value as? any Equatable,
         let newEquatable = newValue as? any Equatable,
         equal(oldEquatable, newEquatable)
      {
        return
      }

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
    isEquatable = wrappedValue is any Equatable
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

// MARK: - Equatable Helper

/// Helper function to compare two equatable values using type erasure.
///
/// This function enables safe comparison of type-erased `Equatable` values, which is
/// necessary for the infinite loop prevention mechanism in `GState`.
///
/// - Parameters:
///   - lhs: The left-hand side equatable value
///   - rhs: The right-hand side equatable value
/// - Returns: `true` if the values are equal, `false` otherwise
@inline(__always)
private func equal(_ lhs: any Equatable, _ rhs: any Equatable) -> Bool {
  guard type(of: lhs) == type(of: rhs) else { return false }

  // Fast path for common primitive types
  if let lhs = lhs as? String, let rhs = rhs as? String { return lhs == rhs }
  if let lhs = lhs as? Int, let rhs = rhs as? Int { return lhs == rhs }
  if let lhs = lhs as? Double, let rhs = rhs as? Double { return lhs == rhs }
  if let lhs = lhs as? Bool, let rhs = rhs as? Bool { return lhs == rhs }

  // Fallback to Mirror-based comparison for custom types
  let lhsMirror = Mirror(reflecting: lhs)
  let rhsMirror = Mirror(reflecting: rhs)

  if lhsMirror.children.count != rhsMirror.children.count {
    return false
  }

  for (lhsChild, rhsChild) in zip(lhsMirror.children, rhsMirror.children) {
    if let lhsValue = lhsChild.value as? any Equatable,
       let rhsValue = rhsChild.value as? any Equatable
    {
      if !equal(lhsValue, rhsValue) {
        return false
      }
    }
  }

  return true
}
