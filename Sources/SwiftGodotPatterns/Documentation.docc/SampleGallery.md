# Sample Gallery

## Property Wrappers

- Important: Call `bindProps()` in `_ready` to populate the wrappers.


### Node Query

#### 🧑‍🧒 Child
```swift
final class Menu: Node {
  @Child var button: Button

  override func _ready() { bindProps() }
}
```

#### 🧑‍🧒‍🧒 Children
```swift
final class Menu: Node {
  @Children var buttons: [Button] // direct children
  @Children("Cells", deep: true) var tiles: [Node2D] // deep search under "Cells"

  override func _ready() { bindProps() }
}
```

#### 🧑‍🧑‍🧒 Ancestors

```swift
final class HealthBar: Node {
  @Ancestor<Node2D> var owner2D: Node2D?

  override func _ready() {
    bindProps()
    owner2D?.show()
  }
}
```

#### 👯 Groups

```swift
final class EnemyHUD: Node {
  @Group("enemies") var enemies: [CharacterBody2D]
  @Group(["interactables", "doors"]) var interactables: [Node]

  override func _ready() {
    bindProps()
    enemies.forEach { _ = $0.isVisibleInTree() }
    let fresh = $enemies() // re-query later
    GD.print("Enemy count: \(fresh.count)")
  }
}
```

### 📡 Signals

```swift
final class MainMenu: Control {
  @OnSignal("PlayButton", \Button.pressed)
  func onPlay(_ button: Button) {
    startGame()
  }

  @OnSignal("NameField", \LineEdit.textSubmitted)
  func onSubmit(_ line: LineEdit, _ text: StringName) {
    accept(name: String(text))
  }

  override func _ready() { bindProps() }
}
```

### 📍 Service Locator

```swift
enum GameEvent { case playerDied, score(Int) }

final class ScoreView: Node {
  @Service<GameEvent> var events: EventBus<GameEvent>?

  override func _ready() {
    bindProps()
    events?.subscribe(self) { [weak self] evt in
      if case let .score(s) = evt { self?.updateLabel(s) }
    }
  }

  private func updateLabel(_ value: Int) { /* ... */ }
}
```

### 🍓 Resources

```swift
final class Logo: Sprite2D {
  @Resource<Texture2D>("res://icon.png") var icon: Texture2D?

  override func _ready() { bindProps() }
}
```

### 🗃️ Autoload

```swift
final class Overlay: CanvasLayer {
  @Autoload<GameState>("GameState") var gameState: GameState?

  override func _ready() {
    bindProps()
    if let gs = gameState { GD.print("level: \(gs.level)") }
  }
}
```

## Components


### ❤️ HealthComponent2D

```swift
import SwiftGodot

@Godot
final class Enemy: Node2D {
  @Child("Health") var health: HealthComponent2D?
  @Service<DamageEvent> var bus: EventBus<DamageEvent>?

  override func _ready() {
    bindProps()
    health?.max = 120
    health?.onChanged = { value in GD.print("HP:", value) }
    health?.onDied = { GD.print("Enemy died") }

    // Simulate damage via the shared bus
    bus.publish(.init(target: getPath(), amount: 15, element: nil))
  }
}
```

### 🧱 Hitbox2D

```swift
import SwiftGodot

@Godot
final class SpikeTrap: Node2D {
  @Child var hitbox: Hitbox2D?

  override func _ready() {
    bindProps()
    hitbox?.amount = 10
    hitbox?.oncePerBody = true
  }
}
```

### 💨 Knockback2DComponent

```swift
import SwiftGodot

@Godot
final class Slime: Node2D {
  @Child var knockback: Knockback2DComponent?
  @Service<KnockbackEvent> var bus: EventBus<KnockbackEvent>?

  override func _ready() {
    bindProps()

    // Fire a knockback at this slime
    bus.publish(.init(
      target: getPath(),
      direction: Vector2.left,
      distance: 64,
      duration: 0.25
    ))
  }
}
```

### 🎯 TargetScanner2D

```swift
import SwiftGodot

@Godot
final class Turret: Node2D {
  @Child var scanner: TargetScanner2D?
  @Service<TargetAcquired> var bus: EventBus<TargetAcquired>?

  private var token: EventBus<TargetAcquired>.Token?

  override func _ready() {
    bindProps()
    scanner?.targetGroups = ["Enemies"]
    scanner?.pickNearest = true

    token = bus?.onEach { [weak self] e in
      guard let self, e.source == self.getPath() else { return }
      GD.print("New target:", e.target)
      // Rotate/aim here if desired.
    }
  }

  override func _exitTree() {
    if let token { bus?.cancel(token) }
  }
}
```


### 🌀 TweenOneShot

```swift
import SwiftGodot

@Godot
final class FXDemo: Node2D {
  @Child var sprite: Sprite2D?

  override func _ready() {
    bindProps()

    // Fade out
    let fade = TweenOneShot.new()
    addChild(node: fade)
    _ = fade.fadeOut(sprite, duration: 0.25)

    // Punch scale
    let punch = TweenOneShot.new()
    addChild(node: punch)
    _ = punch.punchScale(self, amount: Vector2(0.2, 0.2), duration: 0.2)
  }
}
```

### 🏃 Velocity2DComponent

```swift
import SwiftGodot

@Godot
final class Mover: Node2D {
  @Child var motion: Velocity2DComponent?

  override func _ready() {
    bindProps()
    motion?.linearDamping = 6
    motion?.maxSpeed = 300
    motion?.acceleration = Vector2(800, 0) // accelerate right
  }

  // Example: tap to brake
  override func _unhandledInput(event: InputEvent) {
    if event.isActionPressed(action: "brake") {
      motion?.acceleration = .zero
    }
  }
}
```

## Lifecycle

### 📦 ObjectPool (+ PoolLease)

Pool any `Object` subclass. `PoolLease` does scoped acquire/release.

```swift
final class Bullet: Node2D, PooledObject {
  func onAcquire() { visible = true }
  func onRelease() { visible = false; position = .zero }
}

let pool = ObjectPool<Bullet>(factory: Bullet.init)
pool.preload(64)

if let b = pool.acquire() { /* attach & use */ pool.release(b) }

PoolLease(pool).using { b in
  scene.addChild(node: b)
  // released automatically at the end of the closure
}
```

### 🌱 SpawnSystem

Rate-based generator.

```swift
let spawner = SpawnSystem<Bullet>()
spawner.rate = 5
spawner.jitter = 0.05
spawner.usePool(pool.acquire) // or spawner.make = Bullet.init
spawner.onSpawn = { bullet in /* configure & attach */ }
spawner.reset()
func _process(delta: Double) { spawner.tick(delta: delta) }
```

### 🧹 LifetimeComponent2D

Time/offscreen-driven despawn. Attach as a child helper.

```swift
@Godot
final class Bullet: Node2D {
  override func _ready() {
    let d = LifetimeComponent2D()
    d.seconds = 2.0
    d.offscreen = true
    addChild(node: d)
  }
}
```

## Architecture

### 📣 EventBus & ServiceLocator

Type-safe pub/sub with per-event and batch handlers.

```swift
enum GameEvent { case spawned, died }

let bus = ServiceLocator.resolve(GameEvent.self)
let token = bus.onEach { e in print("event:", e) }

bus.publish(.spawned)
bus.cancel(token)
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

A declarative mapping between gameplay states and animation clips.

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

### 🗡️ Phases (startup/active/recovery)

Timeboxed phase runner.

```swift
let phases: [PhaseSpec<StandardPhase>] = [.startup(0.2), .active(0.6), .recovery(0.3)]
let runner = PhaseMachine<StandardPhase>()

runner.onEnter = { if $0 == .active { attack() } }
runner.begin(phases)

func _process(delta: Double) { runner.tick(delta) }
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

## 🧭 Grid

`GridPos`/`Grid` helpers

```swift
struct TileGrid: Grid {
  let size: GridSize
  let tileSize: Float = 16
  let walls: Set<GridPos>
  func passable(_ p: GridPos) -> Bool { inside(p) && !walls.contains(p) }
}

let grid = TileGrid(size: .init(w: 10, h: 8), walls: [GridPos(x: 3, y: 3)])
let start = GridPos(x: 0, y: 0), goal = GridPos(x: 5, y: 4)

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

