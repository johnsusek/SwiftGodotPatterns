import Foundation
import SwiftGodot

public typealias Binding = GBinding
public typealias State = GState

// MARK: - State Property Wrapper

@propertyWrapper
public final class GState<Value> {
  private var value: Value
  private var listeners: [(Value) -> Void] = []

  public var wrappedValue: Value {
    get { value }
    set {
      value = newValue
      notifyListeners()
    }
  }

  public var projectedValue: GState<Value> { self }

  public init(wrappedValue: Value) {
    value = wrappedValue
  }

  func onChange(_ handler: @escaping (Value) -> Void) {
    listeners.append(handler)
    handler(value) // Call immediately with current value
  }

  private func notifyListeners() {
    for listener in listeners {
      listener(value)
    }
  }
}

// MARK: - Binding Property Wrapper

@propertyWrapper
public final class GBinding<Value> {
  private let getter: () -> Value
  private let setter: (Value) -> Void
  private let sourceState: GState<Value>?

  public var wrappedValue: Value {
    get { getter() }
    set { setter(newValue) }
  }

  public var projectedValue: GBinding<Value> { self }

  public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
    getter = get
    setter = set
    sourceState = nil
  }

  public init(_ state: GState<Value>) {
    getter = { state.wrappedValue }
    setter = { state.wrappedValue = $0 }
    sourceState = state
  }

  // Allow @Binding to accept $state directly (like SwiftUI)
  public init(projectedValue: GState<Value>) {
    getter = { projectedValue.wrappedValue }
    setter = { projectedValue.wrappedValue = $0 }
    sourceState = projectedValue
  }

  func onChange(_ handler: @escaping (Value) -> Void) {
    if let sourceState {
      // If we have a source state, subscribe to its changes
      sourceState.onChange(handler)
    } else {
      // Otherwise just call once with current value
      handler(wrappedValue)
    }
  }
}

// MARK: - State Node Relay

@Godot
public final class GStateRelay: Node {
  var updateHandler: (() -> Void)?

  override public func _ready() {
    super._ready()
    updateHandler?()
  }
}
