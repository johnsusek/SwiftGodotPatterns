# SwiftGodotPatterns

Game-agnostic utilities for [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot), companion to [SwiftGodotBuilder](https://github.com/johnsusek/SwiftGodotBuilder).

## 📕 API Documentation

- [SwiftGodotPatterns](https://swiftpackageindex.com/johnsusek/SwiftGodotPatterns/main/documentation/swiftgodotpatterns)

## 💁 Class Registry

Register custom `@Godot` classes without needing to call `register(type)`

```swift
struct MyClass {
  init() {
    GodotRegistry.append(Paddle.self)
  }
}

// Call just before scene loads
GodotRegistry.flush()
```

- `SwiftGodotBuilder` will flush the registry automatically when you call `toNode`

## 🎞️ Animation Machine

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

## Cooldown

A frame-friendly cooldown timer.

```swift
var fireCooldown = Cooldown(duration: 0.25)

// In your code:
if wantsToFire, fireCooldown.tryUse() {
  fireBullet()
}

func _process(delta: Double) {
  fireCooldown.tick(delta: delta)
}
```

## StateMachine

A string-keyed finite state machine with enter/exit/update hooks.

```swift
let sm = StateMachine()
sm.add("Idle", StateMachine.State(onEnter: { print("Idle") }))
sm.add("Run",  StateMachine.State(onUpdate: { dt in /* move */ }))
sm.onChange = { from, to in print("\(from) -> \(to)") }

// In your code:
sm.start(in: "Idle")
sm.transition(to: "Run")

func _process(delta: Double) {
  sm.update(delta: delta)
}
```

## GameTimer

A manually-driven timer with optional repetition and a timeout callback.

```swift
@Godot
class Blinker: Control {
  private let blink = GameTimer(duration: 0.4, repeats: true)

  override func _ready() {
    _ = GameTimer.schedule(after: 1.0) { [weak self] in
      guard let self, let box: ColorRect = getNode("Box") else { return }
      box.visible = true
      blink.start()
    }

    blink.onTimeout = { [weak self] in
      guard let self, let box: ColorRect = getNode("Box") else { return }
      box.visible.toggle()
    }
  }

  override func _process(delta: Double) {
    blink.tick(delta: delta)
  }
}
```

```swift
struct BlinkerView: GView {
  init() {
    GodotRegistry.append(contentsOf: [Blinker.self])
  }

  var body: some GView {
    GNode<Blinker> {
      ColorRect$("Box")
        .color(Color(r: 0.9, g: 0.2, b: 0.3, a: 1))
        .customMinimumSize(Vector2(x: 64, y: 64))
        .visible(false)
    }
  }
}
```

## Health

A game-agnostic hit-point model.

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

## ObjectPool

An object pool for Godot `Object` subclasses.

```swift
final class Bullet: Node2D, PoolItem {
  func onAcquire() { visible = true }
  func onRelease() { visible = false; position = .zero }
}

let pool = ObjectPool<Bullet>(factory: { Bullet() })
pool.preload(64)

if let bullet = pool.acquire() {
  bullet.onAcquire()
  // configure and add to scene...
  // later:
  pool.release(bullet)
}
```

## Spawner

A timer-driven generator of objects at a target rate.

```swift
let spawner = Spawner<Bullet>()
spawner.rate = 5            // 5 bullets/sec
spawner.jitter = 0.05       // small timing variance
spawner.make = { Bullet() } // or spawner.usePool(pool.acquire)

spawner.onSpawn = { bullet in
  bullet.configureAndAttach()
}

spawner.reset() // spawn on next tick

func _process(delta: Double) {
  spawner.tick(delta: delta)
}
```


## 📜 License

[MIT](LICENSE)

