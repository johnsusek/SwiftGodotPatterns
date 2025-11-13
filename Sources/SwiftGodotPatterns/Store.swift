import Foundation

/// A unidirectional data flow store that manages application state through events and reducers.
///
/// `Store` provides an architecture for managing state in a predictable way.
/// All state changes flow through a single reducer function, making the logic testable and
/// debuggable.
///
/// ## Basic Usage
///
/// ```swift
/// enum CounterEvent {
///   case increment
///   case decrement
///   case reset
/// }
///
/// struct CounterState {
///   var count: Int = 0
/// }
///
/// let store = Store(
///   initialState: CounterState(),
///   reducer: { state, event in
///     switch event {
///     case .increment: state.count += 1
///     case .decrement: state.count -= 1
///     case .reset: state.count = 0
///     }
///   }
/// )
///
/// store.commit(.increment)
/// print(store.state.count) // 1
/// ```
///
/// ## Observation
///
/// Subscribe to state changes using `observe`:
///
/// ```swift
/// let token = store.observe { state in
///   print("Count is now: \(state.count)")
/// }
/// store.commit(.increment)
/// // Prints: "Count is now: 1"
/// store.cancel(token)
/// ```
///
/// ## Middleware
///
/// Add middleware for side effects, logging, or async operations:
///
/// ```swift
/// let store = Store(
///   initialState: GameState(),
///   reducer: gameReducer,
///   middleware: [
///     loggingMiddleware,
///     analyticsMiddleware,
///     networkSyncMiddleware
///   ]
/// )
/// ```
public final class Store<State, Event>: @unchecked Sendable {
  /// Opaque handle for cancelling observations.
  public typealias Token = UUID

  /// The current state of the store.
  ///
  /// This property is read-only from outside the store. To modify state,
  /// send events through `commit(_:)`.
  public private(set) var state: State

  /// The reducer function that transforms state based on events.
  private let reducer: (inout State, Event) -> Void

  /// Middleware functions that can intercept and handle events.
  private let middleware: [Middleware<State, Event>]

  /// Registered observers that get notified when state changes.
  private var observers: [Token: (State) -> Void] = [:]

  /// Lock for thread-safe access to state and observers.
  private let lock = NSLock()

  /// Creates a new store with the given initial state and reducer.
  ///
  /// - Parameters:
  ///   - initialState: The starting state for the store.
  ///   - reducer: A pure function that takes the current state and an event,
  ///              and produces a new state.
  ///   - middleware: Optional array of middleware for handling side effects.
  public init(
    initialState: State,
    reducer: @escaping (inout State, Event) -> Void,
    middleware: [Middleware<State, Event>] = []
  ) {
    state = initialState
    self.reducer = reducer
    self.middleware = middleware
  }

  /// Sends an event to the store, triggering the reducer and notifying observers.
  ///
  /// The event flows through middleware first, then to the reducer, and finally
  /// observers are notified if the state changed.
  ///
  /// - Parameter event: The event to process.
  public func commit(_ event: Event) {
    // Run middleware (outside lock since they may dispatch)
    let currentState: State
    lock.lock()
    currentState = state
    lock.unlock()

    for mw in middleware {
      mw.handle(event: event, state: currentState, dispatch: { [weak self] in
        self?.commit($0)
      })
    }

    // Apply reducer and notify observers
    lock.lock()
    reducer(&state, event)
    let currentObservers = Array(observers.values)
    let newState = state
    lock.unlock()

    // Notify observers outside the lock
    for observer in currentObservers {
      observer(newState)
    }
  }

  /// Registers an observer that will be called whenever the state changes.
  ///
  /// The observer is called immediately with the current state, and then
  /// whenever `commit(_:)` causes a state change.
  ///
  /// - Parameter handler: A closure that receives the new state.
  /// - Returns: A token that can be used to cancel the observation.
  @discardableResult
  public func observe(_ handler: @escaping (State) -> Void) -> Token {
    let token = UUID()
    lock.lock()
    observers[token] = handler
    let currentState = state
    lock.unlock()
    handler(currentState) // Call immediately with current state
    return token
  }

  /// Cancels a previously registered observer.
  ///
  /// - Parameter token: The token returned from `observe(_:)`.
  public func cancel(_ token: Token) {
    lock.lock()
    observers.removeValue(forKey: token)
    lock.unlock()
  }
}

// MARK: - Middleware

/// A middleware function that can intercept events and perform side effects.
///
/// Middleware sits between the `commit(_:)` call and the reducer, allowing you to:
/// - Log events for debugging
/// - Trigger analytics
/// - Perform async operations
/// - Dispatch additional events
///
/// ## Example
///
/// ```swift
/// let logger = Middleware<GameState, GameEvent> { event, state, dispatch in
///   print("Event: \(event), State: \(state)")
/// }
/// ```
public struct Middleware<State, Event> {
  private let _handle: (Event, State, @escaping (Event) -> Void) -> Void

  /// Creates a new middleware.
  ///
  /// - Parameter handle: A closure that receives the event, current state,
  ///                     and a dispatch function for sending additional events.
  public init(handle: @escaping (Event, State, @escaping (Event) -> Void) -> Void) {
    _handle = handle
  }

  /// Handles an event passing through the middleware.
  ///
  /// - Parameters:
  ///   - event: The event being processed.
  ///   - state: The current state before the reducer runs.
  ///   - dispatch: A function to dispatch additional events.
  func handle(event: Event, state: State, dispatch: @escaping (Event) -> Void) {
    _handle(event, state, dispatch)
  }
}

// MARK: - Common Middleware

public extension Middleware {
  /// Creates middleware that logs all events to MsgLog.
  ///
  /// - Parameters:
  ///   - level: The log level to use (default: .debug).
  ///   - name: Optional name prefix for log messages.
  ///   - format: Optional custom formatter for events.
  /// - Returns: A middleware that logs events.
  static func logging(
    level: MsgLog.Level = .debug,
    name: String = "Store",
    format: ((Event) -> String)? = nil
  ) -> Middleware {
    Middleware { event, _, _ in
      let message = format?(event) ?? String(describing: event)
      MsgLog.shared.write("[\(name)] \(message)", level: level)
    }
  }
}

// MARK: - Store Extensions

public extension Store {
  /// Creates a reactive GState binding that automatically syncs with a store property.
  ///
  /// This allows you to bind store state directly to view properties without
  /// manually managing observers.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let store = Store(initialState: GameState(), reducer: gameReducer)
  ///
  /// // Bind directly to UI elements
  /// ProgressBar$()
  ///   .value(store.bind(\.playerHealth))
  ///   .maxValue(100)
  ///
  /// Label$()
  ///   .text(store.bind(\.score)) { "Score: \($0)" }
  /// ```
  ///
  /// - Parameter keyPath: The key path to the property in the store's state.
  /// - Returns: A GState that automatically updates when the store state changes.
  ///
  /// - Note: The observation uses a weak reference to the returned GState, so it will
  ///         automatically stop updating when the GState is deallocated.
  func bind<T: Equatable>(_ keyPath: KeyPath<State, T>) -> GState<T> {
    let state = GState(wrappedValue: self.state[keyPath: keyPath])
    observe { [weak state] newState in
      state?.wrappedValue = newState[keyPath: keyPath]
    }
    return state
  }

  /// Creates a derived store that transforms this store's state.
  ///
  /// Useful for providing view-specific slices of state without
  /// giving components access to the entire state tree.
  ///
  /// - Parameter transform: A function that extracts a subset of state.
  /// - Returns: A token that must be kept alive for the derived store to receive updates.
  func derived<DerivedState>(
    _ transform: @escaping (State) -> DerivedState
  ) -> (store: DerivedStore<DerivedState>, token: Token) {
    let derived = DerivedStore(initialState: transform(state))
    let token = observe { [weak derived] state in
      derived?.update(transform(state))
    }
    return (derived, token)
  }
}

/// A read-only store that derives its state from a parent store.
///
/// Use `Store.derived(_:)` to create derived stores.
public final class DerivedStore<State>: @unchecked Sendable {
  /// The current derived state.
  public private(set) var state: State

  /// Registered observers.
  private var observers: [UUID: (State) -> Void] = [:]

  /// Lock for thread-safe access.
  private let lock = NSLock()

  init(initialState: State) {
    state = initialState
  }

  /// Updates the derived state and notifies observers.
  fileprivate func update(_ newState: State) {
    lock.lock()
    state = newState
    let currentObservers = Array(observers.values)
    lock.unlock()

    for observer in currentObservers {
      observer(newState)
    }
  }

  /// Registers an observer for state changes.
  @discardableResult
  public func observe(_ handler: @escaping (State) -> Void) -> UUID {
    let token = UUID()
    lock.lock()
    observers[token] = handler
    let currentState = state
    lock.unlock()
    handler(currentState)
    return token
  }

  /// Cancels an observer.
  public func cancel(_ token: UUID) {
    lock.lock()
    observers.removeValue(forKey: token)
    lock.unlock()
  }
}

// MARK: - ServiceLocator Integration

public extension ServiceLocator {
  /// Registers a store in the service locator.
  ///
  /// This allows you to access the same store instance from anywhere
  /// in your application without passing references around.
  ///
  /// - Parameters:
  ///   - stateType: The state type to key the store by.
  ///   - store: The store instance to register.
  static func register<S, E>(_: S.Type, store: Store<S, E>) {
    register(S.self, value: store)
  }

  /// Retrieves a previously registered store.
  ///
  /// - Parameter stateType: The state type the store was registered with.
  /// - Returns: The registered store, or nil if none was registered.
  static func store<S, E>(_: S.Type) -> Store<S, E>? {
    retrieve(S.self)
  }
}
