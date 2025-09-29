
<a href="#"><img src="media/patterns.png?raw=true" width="210" align="right" title="Pictured: Ancient Roman seamstress at a loom, holding a shuttle."></a>

### SwiftGodotPatterns

Game-agnostic utilities for [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot), companion to [SwiftGodotBuilder](https://github.com/johnsusek/SwiftGodotBuilder).

#### 📕 [API Documentation](https://swiftpackageindex.com/johnsusek/SwiftGodotPatterns/documentation/swiftgodotpatterns)

<br>
<br>
<br>
<br>
<br>

## Lifecycle

### 📦 ObjectPool (+ PoolScope)

Pool any `Object` subclass. `PoolScope` does scoped acquire/release.

```swift
final class Bullet: Node2D, PoolItem {
  func onAcquire() { visible = true }
  func onRelease() { visible = false; position = .zero }
}

let pool = ObjectPool<Bullet>(factory: Bullet.init)
pool.preload(64)

if let b = pool.acquire() { /* attach & use */ pool.release(b) }

PoolScope(pool).using { b in
  scene.addChild(node: b)
  // released automatically at the end of the closure
}
```

### 🌱 Spawner

Rate-based generator.

```swift
let spawner = Spawner<Bullet>()
spawner.rate = 5
spawner.jitter = 0.05
spawner.usePool(pool.acquire) // or spawner.make = Bullet.init
spawner.onSpawn = { bullet in /* configure & attach */ }
spawner.reset()
func _process(delta: Double) { spawner.tick(delta: delta) }
```

### 🧹 AutoDespawn2D

Time/offscreen-driven despawn. Attach as a child helper.

```swift
@Godot
final class Bullet: Node2D {
  override func _ready() {
    let d = AutoDespawn2D()
    d.seconds = 2.0
    d.offscreen = true
    addChild(node: d)
  }
}
```

## Architecture

### 📣 EventHub & GlobalEventBuses

Type-safe pub/sub with per-event and batch handlers.

```swift
enum GameEvent { case spawned, died }

let bus = GlobalEventBuses.hub(GameEvent.self)
let token = bus.onEach { e in print("event:", e) }

bus.publish(.spawned)
bus.cancel(token)
```

### 🧩 Store (state/intent/event + mutations)

Tiny ECS/Redux-ish store with middleware and event bus.

```swift
struct State { var score = 0 } // Your game state
enum Intent { case add(Int) } // "What we want to do" (inputs to the Store)
enum Event { case scoreChanged(Int) } // "What actually happened" (outputs from mutations)

let store = Store<State, Intent, Event>(state: .init())

// Register a mutator: consumes intents, mutates state, emits events.
store.register(.init { intents, state, events in
  for intent in intents {
    guard case let .add(amount) = intent else { continue }
    state.score += amount // Mutate state
    events.append(.scoreChanged(state.score)) // Broadcast what happened
  }
})

// Subscribe to events (returns a token you can cancel later).
let token = store.events.onEach { event in
  switch event {
  case let .scoreChanged(newScore):
    GD.print("scoreChanged ->", newScore) // Update node properties, etc.
  }
}

// Using the Store
store.commit(.add(10))
```

## Sprites

### 🎨 AseSprite (Aseprite JSON + atlas)

Aseprite importer for `AnimatedSprite2D`.

```swift
let dino = AseSprite("player.json",
                     layer: "Body",
                     options: .init(trimming: .applyPivotOrCenter),
                     autoplay: "idle")
// or:
let s = AseSprite()
s.loadAse("player", autoplay: "idle")
```

### 🎞️ Animation Machine

A declarative mapping between **gameplay states** and **animation clips**.

```swift
let rules = AnimationMachineRules {
  When("Idle", play: "standing") // State `Idle` loops `standing` animation
  When("Move", play: "running") // State `Move` loops `running` animation
  When("Hurt", play: "damaged", loop: false) // State `Hurt` plays `damaged` once

  OnFinish("damaged", go: "Idle")  // Animation `damaged` sets state `Idle` when finished
}

let sm = StateMachine()
let sprite = AseSprite(path: "dino", autoplay: "standing") // any AnimatedSprite2D

let animator = AnimationMachine(machine: sm, sprite: sprite, rules: rules)
animator.activate()

sm.start(in: "Idle")
sm.transition(to: "Hurt") // plays "damaged", then auto-returns to "Idle"
```

## Gameplay

### ⏲️ Cooldown

Frame-friendly cooldown timer.

```swift
var fire = Cooldown(duration: 0.25)
if wantsToFire, fire.tryUse() { shoot() }
func _process(delta: Double) { fire.tick(delta: delta) }
```


### ❤️ Health

Game-agnostic hit points.

```swift
var hp = Health(max: 100)
hp.onChanged = { old, new in print("HP: \(old) -> \(new)") }
hp.onDied = { print("You died!") }
hp.damage(30)   // HP: 100 -> 70
hp.heal(10)     // HP: 70 -> 80
hp.invulnerable = true
hp.damage(999)  // no change
hp.invulnerable = false
hp.damage(200)  // HP: 80 -> 0, prints "You died!", then onDamaged(200)

```

### 🧪 Stats & Effects

Lightweight RPG stats with timed effects.

```swift
var stats = StatBlock(hp: 20, atk: 3, def: 1)

struct Berserk: StatEffect {
  let id = "berserk"
  var remaining = 3

  func modify(_ s: inout StatBlock) {
    s.atk += 5
  }
}

let bag = StatEffectBag()
bag.add(Berserk())
bag.apply(to: &stats) // stats.atk == 8
bag.tick() // remaining -> 2
```

### 🗡️ Phases (startup/active/recovery)

Timeboxed phase runner.

```swift
let phases: [PhaseSpec<StandardPhase>] = [.startup(0.2), .active(0.6), .recovery(0.3)]
let runner = PhaseRunner<StandardPhase>()

runner.onEnter = { if $0 == .active { attack() } }
runner.begin(phases)

func _process(delta: Double) { runner.tick(delta) }
```

### 🕒 TurnScheduler (ATB-style)

Speed-based turn order.

```swift
struct Goblin: TurnActor {
  let id: Int
  let speed: Int
  func takeTurn(_ c: TurnContext) { /* act using c.act(self) if needed */ }
}

let ts = TurnScheduler()
ts.add(Goblin(id: 1, speed: 120))
ts.add(Goblin(id: 2, speed: 80))

func _process(delta: Double) { ts.tick() } // call every frame/tick
```

### 🔁 StateMachine

String-keyed finite state machine with enter/exit/update hooks.

```swift
let sm = StateMachine()
sm.add("Idle", .init(onEnter: { print("Idle") }))
sm.add("Run",  .init(onUpdate: { dt in /* move */ }))
sm.onChange = { from, to in print("\(from) -> \(to)") }

sm.start(in: "Idle")
sm.transition(to: "Run")
func _process(delta: Double) { sm.update(delta: delta) }
```

### 🧱 Commands

Validate-then-apply queue (useful for grid moves).

```swift
let queue = CommandQueue()
let command = MoveCommand(
  from: pos,
  to: next,
  passable: { grid.passable($0) },
  move: { pos = $0 }
)
queue.push(command)
queue.drain() // applies if not blocked; otherwise stays queued
```

### ⏳ GameTimer

Manual timer with repetition and a static `schedule`.

```swift
@Godot
final class Blinker: Control {
  private let timer = GameTimer(duration: 0.4, repeats: true)

  override func _ready() {
    _ = GameTimer.schedule(after: 1.0) { [weak self] in
      guard let self, let box: ColorRect = self.getNode("Box") else { return }
      box.visible = true
      self.timer.start()
    }
    timer.onTimeout = { [weak self] in self?.getNode("Box")?.visible.toggle() }
  }

  override func _process(delta: Double) { timer.tick(delta: delta) }
}
```



## 🎮 Input

### InputSnapshot

Per-frame action polling with pressed/released edges.

```swift
var input = InputSnapshot()
override func _process(delta: Double) {
  input.poll(["move_left", "move_right", "fire"])
  if input.pressed("fire") { shoot() }
  if input.down("move_left") { walk(-1) }
  if input.released("move_right") { stopSkating() }
}
```

## 🧭 Grid & Pathfinding

`GridPos`/`Grid` helpers, A* pathfinding, BFS/Dijkstra maps, roguelike FOV, tiny AI tasks.

```swift
struct TileGrid: Grid {
  let size: GridSize
  let tileSize: Float = 16
  let walls: Set<GridPos>
  func passable(_ p: GridPos) -> Bool { inside(p) && !walls.contains(p) }
}

let grid = TileGrid(size: .init(w: 10, h: 8), walls: [GridPos(x: 3, y: 3)])
let start = GridPos(x: 0, y: 0), goal = GridPos(x: 5, y: 4)

// A*
let path = AStar.find(grid: grid, start: start, goal: goal, passable: { grid.passable($0) })

// Dijkstra (distance field from goals)
let field = Dijkstra.solve(grid: grid, passable: { grid.passable($0) }, goals: [goal])

// Roguelike FOV (shadowcasting)
let fov = Fov.compute(map: { grid.passable($0) ? .open : .wall }, grid: grid, origin: start, radius: 6)

// Tiny AI tasks
var wander = Wander(pos: start, grid: grid, passable: { grid.passable($0) }, move: { pos = $0 })
_ = wander.tick(dt: 0)
var chase = ChaseDijkstra(pos: start, field: field, move: { pos = $0 }, grid: grid)
_ = chase.tick(dt: 0)
```

## 🧰 Utilities

```swift
// MsgLog: simple append with hook
MsgLog.shared.onAppend = { GD.print($0) }
MsgLog.shared.write("Loaded")

// onNextFrame: defer execution until next frame
_ = Engine.onNextFrame { setupAfterFirstFrame() }

// Node sugar
let ui: Control? = node.getNode("UI/Root")// typed helper avoids `child as? Label`
let labels: [Label] = node.getChildren() // ditto for arrays

// Vector2 sugar (+ Codable)
var v = Vector2(2, 3) * 4    // (8,12)
let w = 0.5 * Vector2(10, 6) // (5,3)

// Shapes constructors
let rect = RectangleShape2D(w: 16, h: 8)
let circ = CircleShape2D(radius: 6)
let cap  = CapsuleShape2D(radius: 4, height: 12)

// Named 2D Physics layers (bitmask convenience)
let mask = Physics2DLayer.alpha // instead of 1 << 0
```

## 📜 License

[MIT](LICENSE)

