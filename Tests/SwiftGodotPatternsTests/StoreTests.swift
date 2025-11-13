@testable import SwiftGodotPatterns
import Testing

@Suite("Store Tests")
struct StoreTests {
  // MARK: - Test Types

  enum CounterEvent {
    case increment
    case decrement
    case add(Int)
    case reset
  }

  struct CounterState: Equatable {
    var count: Int = 0
  }

  func counterReducer(state: inout CounterState, event: CounterEvent) {
    switch event {
    case .increment:
      state.count += 1
    case .decrement:
      state.count -= 1
    case let .add(value):
      state.count += value
    case .reset:
      state.count = 0
    }
  }

  // MARK: - Basic Tests

  @Test("Store initializes with initial state")
  func testInitialState() {
    let store = Store(
      initialState: CounterState(count: 42),
      reducer: counterReducer
    )
    #expect(store.state.count == 42)
  }

  @Test("Store processes events through reducer")
  func testReducer() {
    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer
    )

    store.commit(.increment)
    #expect(store.state.count == 1)

    store.commit(.increment)
    #expect(store.state.count == 2)

    store.commit(.decrement)
    #expect(store.state.count == 1)

    store.commit(.add(10))
    #expect(store.state.count == 11)

    store.commit(.reset)
    #expect(store.state.count == 0)
  }

  @Test("Store notifies observers on state change")
  func testObserver() {
    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer
    )

    var observedStates: [CounterState] = []
    let token = store.observe { state in
      observedStates.append(state)
    }

    // Should receive initial state immediately
    #expect(observedStates.count == 1)
    #expect(observedStates[0].count == 0)

    store.commit(.increment)
    #expect(observedStates.count == 2)
    #expect(observedStates[1].count == 1)

    store.commit(.add(5))
    #expect(observedStates.count == 3)
    #expect(observedStates[2].count == 6)

    store.cancel(token)
  }

  @Test("Store observer cancellation stops notifications")
  func testObserverCancellation() {
    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer
    )

    var count = 0
    let token = store.observe { _ in
      count += 1
    }

    #expect(count == 1) // Initial call

    store.commit(.increment)
    #expect(count == 2)

    store.cancel(token)

    store.commit(.increment)
    #expect(count == 2, "Count should not increase after cancellation")
  }

  @Test("Store supports multiple observers")
  func testMultipleObservers() {
    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer
    )

    var count1 = 0
    var count2 = 0

    let token1 = store.observe { _ in count1 += 1 }
    let token2 = store.observe { _ in count2 += 1 }

    #expect(count1 == 1)
    #expect(count2 == 1)

    store.commit(.increment)
    #expect(count1 == 2)
    #expect(count2 == 2)

    store.cancel(token1)
    store.commit(.increment)

    #expect(count1 == 2, "First observer should not receive updates")
    #expect(count2 == 3, "Second observer should still receive updates")

    store.cancel(token2)
  }

  // MARK: - Middleware Tests

  @Test("Middleware intercepts events")
  func testMiddleware() {
    var interceptedEvents: [CounterEvent] = []

    let middleware = Middleware<CounterState, CounterEvent> { event, _, _ in
      interceptedEvents.append(event)
    }

    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer,
      middleware: [middleware]
    )

    store.commit(.increment)
    store.commit(.decrement)
    store.commit(.add(5))

    #expect(interceptedEvents.count == 3)
  }

  @Test("Middleware can dispatch additional events")
  func testMiddlewareDispatch() {
    // Middleware that doubles increment events
    let doubler = Middleware<CounterState, CounterEvent> { event, _, dispatch in
      if case .increment = event {
        dispatch(.increment) // Dispatch a second increment
      }
    }

    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer,
      middleware: [doubler]
    )

    store.commit(.increment)
    // Should be 2 because middleware dispatched an additional increment
    #expect(store.state.count == 2)
  }

  @Test("Multiple middleware execute in order")
  func testMiddlewareOrder() {
    var log: [String] = []

    let mw1 = Middleware<CounterState, CounterEvent> { _, _, _ in
      log.append("mw1")
    }

    let mw2 = Middleware<CounterState, CounterEvent> { _, _, _ in
      log.append("mw2")
    }

    let mw3 = Middleware<CounterState, CounterEvent> { _, _, _ in
      log.append("mw3")
    }

    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer,
      middleware: [mw1, mw2, mw3]
    )

    store.commit(.increment)

    #expect(log == ["mw1", "mw2", "mw3"])
  }

  @Test("Logging middleware logs events")
  func testLoggingMiddleware() {
    let log = MsgLog.shared
    let originalSink = log.sink
    let originalLevel = log.minLevel
    defer {
      log.sink = originalSink
      log.minLevel = originalLevel
    }

    var capturedMessages: [String] = []
    log.minLevel = .debug
    log.sink = { _, message in
      capturedMessages.append(message)
    }

    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer,
      middleware: [.logging(name: "Counter")]
    )

    store.commit(.increment)
    store.commit(.decrement)

    #expect(capturedMessages.count >= 2)
    #expect(capturedMessages[0].contains("Counter"))
    #expect(capturedMessages[1].contains("Counter"))
  }

  @Test("EventBus middleware publishes to bus")
  func testEventBusMiddleware() {
    let bus = EventBus<CounterEvent>()
    var busEvents: [CounterEvent] = []

    let token = bus.onEach { event in
      busEvents.append(event)
    }

    // Custom middleware that publishes to EventBus
    let busMiddleware = Middleware<CounterState, CounterEvent> { event, _, _ in
      bus.publish(event)
    }

    let store = Store(
      initialState: CounterState(),
      reducer: counterReducer,
      middleware: [busMiddleware]
    )

    store.commit(.increment)
    store.commit(.add(5))

    #expect(busEvents.count == 2)

    bus.cancel(token)
  }

  // MARK: - Derived Store Tests

  @Test("Derived store extracts subset of state")
  func testDerivedStore() {
    struct AppState {
      var counter: Int = 0
      var name: String = "Test"
    }

    enum AppEvent {
      case incrementCounter
      case setName(String)
    }

    let store = Store(
      initialState: AppState(),
      reducer: { (state: inout AppState, event: AppEvent) in
        switch event {
        case .incrementCounter:
          state.counter += 1
        case let .setName(name):
          state.name = name
        }
      }
    )

    // Create derived store that only sees counter
    let (derivedStore, token) = store.derived { $0.counter }

    #expect(derivedStore.state == 0)

    store.commit(.incrementCounter)
    #expect(derivedStore.state == 1)

    store.commit(.setName("New"))
    #expect(derivedStore.state == 1) // Unchanged

    store.commit(.incrementCounter)
    #expect(derivedStore.state == 2)

    store.cancel(token)
  }

  @Test("Derived store supports observers")
  func testDerivedStoreObserver() {
    struct AppState {
      var value: Int = 0
    }

    enum AppEvent {
      case increment
    }

    let store = Store(
      initialState: AppState(),
      reducer: { (state: inout AppState, event: AppEvent) in
        switch event {
        case .increment:
          state.value += 1
        }
      }
    )

    let (derived, storeToken) = store.derived { $0.value * 2 }

    var observedValues: [Int] = []
    let observerToken = derived.observe { value in
      observedValues.append(value)
    }

    #expect(observedValues == [0])

    store.commit(.increment)
    #expect(observedValues == [0, 2])

    store.commit(.increment)
    #expect(observedValues == [0, 2, 4])

    derived.cancel(observerToken)
    store.cancel(storeToken)
  }

  // MARK: - ServiceLocator Integration Tests

  @Test("ServiceLocator can register and retrieve stores")
  func testServiceLocatorIntegration() {
    let store = Store(
      initialState: CounterState(count: 100),
      reducer: counterReducer
    )

    ServiceLocator.register(CounterState.self, store: store)

    let retrieved: Store<CounterState, CounterEvent>? = ServiceLocator.store(CounterState.self)
    #expect(retrieved != nil)
    #expect(retrieved?.state.count == 100)

    // Clean up by removing from map
    // (Note: ServiceLocator doesn't have a remove method, so we'll leave it)
  }

  // MARK: - Game Example Tests

  @Test("Store bind creates reactive GState")
  func testStoreBind() {
    let store = Store(
      initialState: CounterState(count: 10),
      reducer: counterReducer
    )

    // Create a binding to the count property
    let countBinding = store.bind(\.count)

    // Should have initial value
    #expect(countBinding.wrappedValue == 10)

    // Should update when store changes
    store.commit(.increment)
    #expect(countBinding.wrappedValue == 11)

    store.commit(.add(5))
    #expect(countBinding.wrappedValue == 16)

    store.commit(.reset)
    #expect(countBinding.wrappedValue == 0)
  }

  @Test("Store bind works with GState observers")
  func testStoreBindWithObservers() {
    let store = Store(
      initialState: CounterState(count: 0),
      reducer: counterReducer
    )

    let binding = store.bind(\.count)
    var observedValues: [Int] = []

    // Observe changes to the binding
    binding.onChange { value in
      observedValues.append(value)
    }

    // Should receive initial value
    #expect(observedValues == [0])

    // Should receive updates
    store.commit(.increment)
    #expect(observedValues == [0, 1])

    store.commit(.add(10))
    #expect(observedValues == [0, 1, 11])
  }

  @Test("Game state example with multiple input sources")
  func testGameStateExample() {
    // Example of a game with player/AI/network inputs all as events
    struct GameState {
      var playerHealth: Int = 100
      var enemyHealth: Int = 100
      var frame: Int = 0
    }

    enum GameEvent {
      case playerAttack(damage: Int)
      case enemyAttack(damage: Int)
      case heal(amount: Int)
      case tick
    }

    let store = Store(
      initialState: GameState(),
      reducer: { (state: inout GameState, event: GameEvent) in
        switch event {
        case let .playerAttack(damage):
          state.enemyHealth = max(0, state.enemyHealth - damage)
        case let .enemyAttack(damage):
          state.playerHealth = max(0, state.playerHealth - damage)
        case let .heal(amount):
          state.playerHealth = min(100, state.playerHealth + amount)
        case .tick:
          state.frame += 1
        }
      }
    )

    // Simulate game loop
    store.commit(.tick)
    #expect(store.state.frame == 1)

    // Player input
    store.commit(.playerAttack(damage: 20))
    #expect(store.state.enemyHealth == 80)

    // AI action
    store.commit(.enemyAttack(damage: 15))
    #expect(store.state.playerHealth == 85)

    // Network event (player heals)
    store.commit(.heal(amount: 10))
    #expect(store.state.playerHealth == 95)

    // Continue game loop
    store.commit(.tick)
    #expect(store.state.frame == 2)
  }
}
