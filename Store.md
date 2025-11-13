# Store Pattern

**Observing State Changes:**

```swift
// Subscribe to all state changes
let token = store.observe { state in
  print("Health: \(state.playerHealth)")
  print("Score: \(state.score)")
}

store.commit(.heal(10))
// Prints: Health: 90, Score: 100

// Cancel subscription when done
store.cancel(token)
```

**Middleware for Side Effects:**

```swift
// Logging middleware
let logger = Middleware<GameState, GameEvent>.logging(
  name: "Game",
  level: .debug
)

// Custom middleware
let scorer = Middleware<GameState, GameEvent> { event, state, dispatch in
  // Log analytics, trigger achievements, etc.
  if case .addScore(let points) = event, points >= 1000 {
    dispatch(.nextLevel) // Can dispatch additional events
  }
}

let store = Store(
  initialState: GameState(),
  reducer: gameReducer,
  middleware: [logger, scorer]
)
```

**Derived Stores:**

```swift
// Create a derived store that only sees part of the state
let (healthStore, token) = store.derived { $0.playerHealth }

healthStore.observe { health in
  print("Health changed: \(health)")
}

store.commit(.takeDamage(10))
// Prints: Health changed: 90
```

**Game Architecture Example:**

```swift
// All input sources funnel through events
enum GameEvent {
  case playerInput(PlayerInput)
  case aiAction(AIAction)
  case networkSync(NetworkState)
  case tick(delta: Double)
}

struct GameState {
  var players: [Player]
  var enemies: [Enemy]
  var frame: Int
}

let store = Store(
  initialState: GameState(),
  reducer: { state, event in
    switch event {
    case .playerInput(let input):
      // Handle player actions
    case .aiAction(let action):
      // Handle AI decisions
    case .networkSync(let sync):
      // Merge network state
    case .tick(let delta):
      state.frame += 1
      // Update physics, animations, etc.
    }
  }
)

// In your game loop
override func _process(delta: Double) {
  store.commit(.tick(delta: delta))
}

// Player input
func handleInput() {
  if Input.isActionJustPressed("jump") {
    store.commit(.playerInput(.jump))
  }
}
```
