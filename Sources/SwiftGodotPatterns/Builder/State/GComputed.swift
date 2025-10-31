import Foundation
import SwiftGodot

/// A type alias for ``GComputed`` to provide a more convenient API surface.
public typealias Computed = GComputed

// MARK: - Computed Value

/// A reactive computed value that automatically updates when dependencies change.
///
/// `GComputed` provides a way to derive values from `@State` properties with automatic
/// recalculation when dependencies change.
///
/// **Important:** Since Swift property wrappers require specific initialization patterns,
/// `GComputed` must be initialized with explicit dependencies using the convenience initializers:
///
/// ```swift
/// @State var width = 10.0
/// var formatted = GComputed($width) { "\($0)px" }
/// ```
///
/// Then use `formatted.$` to bind to UI components (the `$` accesses `projectedValue`).
public final class GComputed<Value> {
  private var computedValue: Value
  private var listeners: [(Value) -> Void] = []
  private let compute: () -> Value

  /// The current computed value.
  public var value: Value {
    computedValue
  }

  /// A projection that can be passed to binding methods.
  ///
  /// Use `.$ ` to access this for binding:
  ///
  /// ```swift
  /// var formatted = GComputed($width) { "\($0)px" }
  /// Label$().text(formatted.$)
  /// ```
  public var projectedValue: GComputed<Value> { self }

  /// Creates a new computed property with a computation closure.
  ///
  /// **Note:** This initializer creates a non-reactive computed value.
  /// For reactive updates, use the dependency-based initializers instead.
  ///
  /// - Parameter compute: A closure that computes the derived value.
  internal init(compute: @escaping () -> Value) {
    self.compute = compute
    self.computedValue = compute()
  }

  /// Registers a closure to be called whenever the computed value changes.
  ///
  /// The handler is called immediately with the current value, and then
  /// again each time the value is recalculated.
  ///
  /// - Parameter handler: A closure that receives the new value whenever it changes.
  func onChange(_ handler: @escaping (Value) -> Void) {
    listeners.append(handler)
    handler(computedValue) // Call immediately with current value
  }

  /// Recalculates the computed value and notifies all listeners if it changed.
  ///
  /// This method should be called by dependency tracking whenever a dependency changes.
  internal func recalculate() {
    let newValue = compute()
    computedValue = newValue
    notifyListeners()
  }

  /// Notifies all registered listeners of the current value.
  private func notifyListeners() {
    for listener in listeners {
      listener(computedValue)
    }
  }
}

// MARK: - Dependency Tracking Helpers

extension GComputed {
  /// Creates a computed property that explicitly depends on one state value.
  ///
  /// This is the recommended way to create computed properties with automatic updates:
  ///
  /// ```swift
  /// @State var count = 0
  /// @Computed var doubled = GComputed.depend(on: $count) { count in
  ///   count * 2
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - dependency: The state to track for changes.
  ///   - compute: A closure that computes the value from the dependency.
  public static func depend<T>(
    on dependency: GState<T>,
    _ compute: @escaping (T) -> Value
  ) -> GComputed<Value> {
    let computed = GComputed(compute: { compute(dependency.wrappedValue) })
    dependency.onChange { _ in
      computed.recalculate()
    }
    return computed
  }

  /// Creates a computed property that depends on one state value.
  ///
  /// Convenience initializer for inline usage:
  ///
  /// ```swift
  /// @State var width = 10.0
  /// let formatted = GComputed($width) { "\($0)px" }
  /// ```
  ///
  /// - Parameters:
  ///   - dependency: The state to track for changes.
  ///   - compute: A closure that computes the value from the dependency.
  public convenience init<T>(
    _ dependency: GState<T>,
    _ compute: @escaping (T) -> Value
  ) {
    self.init(compute: { compute(dependency.wrappedValue) })
    dependency.onChange { [weak self] _ in
      self?.recalculate()
    }
  }

  /// Creates a computed property that depends on two state values.
  ///
  /// Convenience initializer for inline usage:
  ///
  /// ```swift
  /// @State var width = 10.0
  /// @State var height = 20.0
  /// let area = GComputed($width, $height) { w, h in w * h }
  /// ```
  public convenience init<T1, T2>(
    _ dep1: GState<T1>,
    _ dep2: GState<T2>,
    _ compute: @escaping (T1, T2) -> Value
  ) {
    self.init(compute: {
      compute(dep1.wrappedValue, dep2.wrappedValue)
    })
    dep1.onChange { [weak self] _ in self?.recalculate() }
    dep2.onChange { [weak self] _ in self?.recalculate() }
  }

  /// Creates a computed property that depends on three state values.
  public convenience init<T1, T2, T3>(
    _ dep1: GState<T1>,
    _ dep2: GState<T2>,
    _ dep3: GState<T3>,
    _ compute: @escaping (T1, T2, T3) -> Value
  ) {
    self.init(compute: {
      compute(dep1.wrappedValue, dep2.wrappedValue, dep3.wrappedValue)
    })
    dep1.onChange { [weak self] _ in self?.recalculate() }
    dep2.onChange { [weak self] _ in self?.recalculate() }
    dep3.onChange { [weak self] _ in self?.recalculate() }
  }

  /// Creates a computed property that explicitly depends on two state values.
  ///
  /// ```swift
  /// @State var width = 10.0
  /// @State var height = 20.0
  /// @Computed var area = GComputed.depend(on: $width, $height) { w, h in
  ///   w * h
  /// }
  /// ```
  public static func depend<T1, T2>(
    on dep1: GState<T1>,
    _ dep2: GState<T2>,
    _ compute: @escaping (T1, T2) -> Value
  ) -> GComputed<Value> {
    let computed = GComputed(compute: {
      compute(dep1.wrappedValue, dep2.wrappedValue)
    })
    dep1.onChange { _ in computed.recalculate() }
    dep2.onChange { _ in computed.recalculate() }
    return computed
  }

  /// Creates a computed property that explicitly depends on three state values.
  public static func depend<T1, T2, T3>(
    on dep1: GState<T1>,
    _ dep2: GState<T2>,
    _ dep3: GState<T3>,
    _ compute: @escaping (T1, T2, T3) -> Value
  ) -> GComputed<Value> {
    let computed = GComputed(compute: {
      compute(dep1.wrappedValue, dep2.wrappedValue, dep3.wrappedValue)
    })
    dep1.onChange { _ in computed.recalculate() }
    dep2.onChange { _ in computed.recalculate() }
    dep3.onChange { _ in computed.recalculate() }
    return computed
  }
}
