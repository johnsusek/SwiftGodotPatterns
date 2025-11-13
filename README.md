
<a href="#"><img src="https://github.com/johnsusek/SwiftGodotPatterns/raw/main/media/patterns.png?raw=true" width="210" align="right" title="Pictured: Ancient Roman seamstress at a loom, holding a shuttle."></a>

### SwiftGodotPatterns

Declarative game development.

A SwiftUI-style library for building games with [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot), [LDtk](https://ldtk.io), and [Aseprite](https://aseprite.org).

<br>

📕 [API Documentation](https://swiftpackageindex.com/johnsusek/SwiftGodotPatterns/documentation/swiftgodotpatterns)

<br><br><br><br>

## Quick Start

```swift
import SwiftGodot
import SwiftGodotPatterns

@Godot
final class Game: Node2D {
  override func _ready() {
    addChild(node: GameView().toNode())
  }
}

struct GameView: GView {
  var body: some GView {
    Node2D$ {
      Label$().text("Hello World")
    }
  }
}
```

## Builder Syntax

```swift
// $ syntax - shorthand for GNode<T>
Sprite2D$()
CharacterBody2D$()
Label$()

// With children
Node2D$ {
  Sprite2D$()
  CollisionShape2D$()
}

// Named nodes
CharacterBody2D$("Player") {
  Sprite2D$()
}

// Custom initializer
GNode<CustomNode>("Name", make: { CustomNode(config: config) }) {
  // children
}
```

## Properties & Configuration

```swift
// Dynamic member lookup - set any property
Sprite2D$()
  .position(Vector2(100, 200))
  .scale(Vector2(2, 2))
  .rotation(45)
  .modulate(.red)
  .zIndex(10)

// Configure closure for complex setup
Sprite2D$().configure { sprite in
  sprite.texture = myTexture
  sprite.centered = true
}
```

## Resource Loading

```swift
// Load into property
Sprite2D$()
  .res(\.texture, "player.png")
  .res(\.material, "shader_material.tres")

// Custom resource loading
Sprite2D$()
  .withResource("shader.gdshader", as: Shader.self) { node, shader in
    let material = ShaderMaterial()
    material.shader = shader
    node.material = material
  }
```

## State Management

```swift
struct PlayerView: GView {
  @State var health: Int = 100
  @State var position: Vector2 = .zero
  @State var playerNode: CharacterBody2D?

  var body: some GView {
    CharacterBody2D$ {
      Sprite2D$()
      ProgressBar$()
        .value($health)  // One-way binding
    }
    .position($position)  // Bind to property
    .ref($playerNode)     // Capture node reference
    .onProcess { node, delta in
      health -= 1  // Modify state
    }
  }
}
```

## State Binding Patterns

```swift
// One-way bind to property
ProgressBar$().value($health)

// Bind with formatter
Label$().bind(\.text, to: $score) { "Score: \($0)" }

// Bind to sub-property
Sprite2D$().bind(\.x, to: $position, \.x)

// Multi-state binding
Label$().bind(\.text, to: $health, $maxHealth) { "\($0)/\($1)" }

// Watch state changes
Node2D$().watch($health) { node, health in
  node.modulate = health < 20 ? .red : .white
}

// Two-way bindings (form controls)
LineEdit$().text($username)
Slider$().value($volume)
CheckBox$().pressed($isEnabled)
OptionButton$().selected($selectedIndex)
```

## Signal Connections

```swift
// No arguments
Button$()
  .onSignal(\.pressed) { node in
    print("Pressed!")
  }

// With arguments
Area2D$()
  .onSignal(\.bodyEntered) { node, body in
    print("Body entered: \(body)")
  }

// Multiple arguments
Area2D$()
  .onSignal(\.bodyShapeEntered) { node, bodyRid, body, bodyShapeIndex, localShapeIndex in
    // Handle collision
  }
```

## Process Hooks

```swift
Node2D$()
  .onReady { node in
    print("Node ready!")
  }
  .onProcess { node, delta in
    node.position.x += 100 * Float(delta)
  }
  .onPhysicsProcess { node, delta in
    // Physics updates
  }
```

## Dynamic Views

```swift
// ForEach - dynamic lists
struct InventoryView: GView {
  @State var items: [Item] = []

  var body: some GView {
    VBoxContainer$ {
      ForEach($items) { item in
        HBoxContainer$ {
          Label$().text(item.wrappedValue.name)
          Button$().text("X").onSignal(\.pressed) { _ in
            items.removeAll { $0.id == item.wrappedValue.id }
          }
        }
      }
    }
  }
}

// If - conditional rendering
struct MenuView: GView {
  @State var showSettings = false

  var body: some GView {
    VBoxContainer$ {
      If($showSettings) {
        SettingsPanel()
      }
      .Else {
        MainMenu()
      }
    }
  }
}

// If modes
If($condition) { /* ... */ }                 // .hide (default) - toggle visible
If($condition) { /* ... */ }.mode(.remove)   // addChild/removeChild
If($condition) { /* ... */ }.mode(.destroy)  // queueFree/rebuild

// Switch/Case - multi-way branching
enum Page { case mainMenu, levelSelect, settings }

struct GameView: GView {
  @State var currentPage: Page = .mainMenu

  var body: some GView {
    VBoxContainer$ {
      Switch($currentPage) {
        Case(.mainMenu) {
          Label$().text("Main Menu")
          Button$().text("Start").onSignal(\.pressed) { _ in
            currentPage = .levelSelect
          }
        }
        Case(.levelSelect) {
          Label$().text("Level Select")
          Button$().text("Back").onSignal(\.pressed) { _ in
            currentPage = .mainMenu
          }
        }
        Case(.settings) {
          Label$().text("Settings")
        }
      }
      .default {
        Label$().text("Unknown page")
      }
    }
  }
}

// Computed state - derive new reactive states
@State var score = 0
let scoreText = $score.computed { "Score: \($0)" }
let isHighScore = $score.computed { $0 > 1000 }

Label$().text(scoreText)

If(isHighScore) {
  Label$().text("New High Score!").modulate(.yellow)
}

// Combine multiple states
@State var currentPage = 1
@State var totalPages = 10
let pageText = $currentPage.computed(with: $totalPages) { current, total in
  "Page \(current) of \(total)"
}

@State var health = 80
@State var maxHealth = 100
@State var playerName = "Hero"
let statusText = $health.computed(with: $maxHealth, $playerName) { hp, maxHp, name in
  "\(name): \(hp)/\(maxHp) HP"
}

Label$().text(statusText)
```

## Groups & Scene Instancing

```swift
Node2D$()
  .group("enemies")
  .group("damageable", persistent: true)
  .groups(["enemies", "damageable"])

Node2D$()
  .fromScene("enemy.tscn") { child in
    // Configure instanced scene
  }
```

## Control Layout

```swift
// Anchor/offset presets (non-container parents)
Control$()
  .anchors(.center)
  .offsets(.topRight)
  .anchorsAndOffsets(.fullRect, margin: 10)
  .anchor(top: 0, right: 1, bottom: 1, left: 0)
  .offset(top: 12, right: -12, bottom: -12, left: 12)

// Container size flags (for VBox/HBox parents)
Button$()
  .sizeH(.expandFill)
  .sizeV(.shrinkCenter)
  .size(.expandFill, .shrinkCenter)
  .size(.expandFill)  // Both axes
```

## Collision (2D)

```swift
CharacterBody2D$()
  .collisionLayer(.alpha)
  .collisionMask([.beta, .gamma])

// Available layers: .alpha, .beta, .gamma, .delta, .epsilon, .zeta, .eta, .theta,
// .iota, .kappa, .lambda, .mu, .nu, .xi, .omicron, .pi, .rho, .sigma, .tau,
// .upsilon, .phi, .chi, .psi, .omega

// Custom layers
CharacterBody2D$()
  .collisionMask(wallLayer | enemyLayer)
```

## Shape Helpers

```swift
CollisionShape2D$().shape(RectangleShape2D(w: 50, h: 100))
CollisionShape2D$().shape(CircleShape2D(radius: 25))
CollisionShape2D$().shape(CapsuleShape2D(radius: 10, height: 50))
CollisionShape2D$().shape(SegmentShape2D(a: [0, 0], b: [100, 100]))
CollisionShape2D$().shape(SeparationRayShape2D(length: 100))
CollisionShape2D$().shape(WorldBoundaryShape2D(normal: [0, -1], distance: 0))
```

## EventBus

```swift
enum GameEvent {
  case playerDied
  case scoreChanged(Int)
  case itemCollected(String)
}

// Subscribe via modifier
Node2D$()
  .onEvent(GameEvent.self) { node, event in
    switch event {
    case .playerDied: print("Game Over")
    case .scoreChanged(let score): print("Score: \(score)")
    case .itemCollected(let item): print("Got: \(item)")
    }
  }

// Subscribe with filter
Node2D$()
  .onEvent(GameEvent.self, match: { event in
    if case .scoreChanged = event { return true }
    return false
  }) { node, event in
    // Handle only score changes
  }

// Publish via ServiceLocator
let bus = ServiceLocator.resolve(GameEvent.self)
bus.publish(.scoreChanged(100))

// Or use EmittableEvent protocol
enum GameEvent: EmittableEvent {
  case playerDied
}
GameEvent.playerDied.emit()
```

## Store (Uni-directional State)

```swift
struct GameState {
  var health: Int = 100
  var score: Int = 0
}

enum GameEvent {
  case takeDamage(Int)
  case addScore(Int)
}

func gameReducer(state: inout GameState, event: GameEvent) {
  switch event {
  case .takeDamage(let amount):
    state.health = max(0, state.health - amount)
  case .addScore(let points):
    state.score += points
  }
}

let store = Store(initialState: GameState(), reducer: gameReducer)

// Use in views
ProgressBar$().value(store.bind(\.health))
Label$().text(store.bind(\.score)) { "Score: \($0)" }

// Send events
store.commit(.takeDamage(10))
store.commit(.addScore(100))
```

## Input Actions

```swift
// Define actions
Actions {
  Action("jump") {
    Key(.space)
    JoyButton(.a, device: 0)
  }

  Action("shoot") {
    MouseButton(1)
    Key(.leftCtrl)
  }

  // Analog axes
  ActionRecipes.axisUD(
    namePrefix: "move",
    device: 0,
    axis: .leftY,
    dz: 0.2,
    keyDown: .s,
    keyUp: .w
  )

  ActionRecipes.axisLR(
    namePrefix: "move",
    device: 0,
    axis: .leftX,
    dz: 0.2,
    keyLeft: .a,
    keyRight: .d
  )
}
.install(clearExisting: true)

// Runtime polling
if Action("jump").isJustPressed {
  player.jump()
}

if Action("shoot").isPressed {
  player.shoot(Action("shoot").strength)
}

let horizontal = RuntimeAction.axis(negative: "move_left", positive: "move_right")
let movement = RuntimeAction.vector(
  negativeX: "move_left",
  positiveX: "move_right",
  negativeY: "move_up",
  positiveY: "move_down"
)
```

## Property Wrappers

Call `bindProps()` in `_ready()` to activate all property wrappers.

```swift
@Godot
final class Player: CharacterBody2D {
  @Child("Sprite") var sprite: Sprite2D?
  @Child("Health", deep: true) var healthBar: ProgressBar?
  @Children var buttons: [Button]
  @Ancestor var level: Level?
  @Sibling("AudioPlayer") var audio: AudioStreamPlayer?
  @Autoload("GameManager") var gameManager: GameManager?
  @Group("enemies") var enemies: [Enemy]
  @Service var events: EventBus<GameEvent>?
  @Prefs("musicVolume", default: 0.5) var volume: Double

  @OnSignal("StartButton", \Button.pressed)
  func onStartPressed(_ sender: Button) {
    print("Started!")
  }

  override func _ready() {
    bindProps()

    sprite?.visible = true
    enemies.forEach { print($0) }

    // Refresh group query
    let currentEnemies = $enemies()
  }
}
```

## Theme Building

```swift
let theme = Theme([
  "Button": [
    "colors": ["fontColor": Color.white],
    "constants": ["outlineSize": 2],
    "fontSizes": ["fontSize": 16]
  ],
  "Label": [
    "colors": ["fontColor": Color.white],
    "fontSizes": ["fontSize": 14]
  ]
])

Control$().theme(theme)
```

## Vector2 Extensions

```swift
let pos = Vector2(100, 200)
let pos: Vector2 = [100, 200]  // Array literal
let doubled = pos * 2
let scaled = pos * 1.5
```

## Node Extensions

```swift
// Typed queries
let sprites: [Sprite2D] = node.getChildren()
let firstSprite: Sprite2D? = node.getChild()
let enemySprite: Sprite2D? = node.getNode("Enemy")

// Group queries
let enemies: [Enemy] = node.getNodes(inGroup: "enemies")

// Parent chain
let parents: [Node2D] = node.getParents()

// Metadata queries (recursive)
let spawns: [Node2D] = root.queryMeta(key: "type", value: "spawn")
let valuable: [Node2D] = root.queryMeta(key: "value", value: 100)
let markers: [Node2D] = root.queryMetaKey("marker")

// Get typed metadata
let coinValue: Int? = node.getMetaValue("coin_value")
```

## Engine Extensions

```swift
if let tree = Engine.getSceneTree() {
  // ...
}

Engine.onNextFrame {
  print("Next frame!")
}

Engine.onNextPhysicsFrame {
  print("Next physics frame!")
}
```

## LDtk Integration

Complete workflow for loading LDtk levels.

```swift
// Define type-safe enums (auto-generates LDExported.json on build)
enum Item: String, LDExported {
  case knife = "Knife"
  case boots = "Boots"
  case potion = "Potion"
}

enum EnemyType: String, LDExported {
  case goblin = "Goblin"
  case skeleton = "Skeleton"
}

struct GameView: GView {
  let project: LDProject
  @State var inventory: [Item] = []
  @State var health: Int = 100

  var body: some GView {
    Node2D$ {
      LDLevelView(project, level: "Level_0")
        .onSpawn("Player") { entity, level, project in
          let wallLayer = project.collisionLayer(for: "walls", in: level)
          let startItems: [Item] = entity.field("starting_items")?.asEnumArray() ?? []
          inventory.append(contentsOf: startItems)

          CharacterBody2D$ {
            Sprite2D$()
              .res(\.texture, "player.png")
              .anchor([16, 22], within: entity.size, pivot: entity.pivotVector)
            CollisionShape2D$()
              .shape(RectangleShape2D(w: 16, h: 22))
          }
          .position(entity.position)
          .collisionMask(wallLayer)
        }

        .onSpawn("Enemy") { entity, level, project in
          let enemyType: EnemyType? = entity.field("type")?.asEnum()
          let patrolPath: [Vector2] = entity.field("patrol")?.asVector2Array() ?? []
          let enemyHealth: Int = entity.field("health")?.asInt() ?? 10

          Area2D$ {
            Sprite2D$()
              .res(\.texture, "enemy_\(enemyType?.rawValue ?? "default").png")
              .anchor([12, 16], within: entity.size)
            CollisionShape2D$()
              .shape(RectangleShape2D(w: 12, h: 16))
          }
          .position(entity.position)
        }

        .onSpawn("Chest") { entity, level, project in
          let loot: [Item] = entity.field("loot")?.asEnumArray() ?? []
          let locked: Bool = entity.field("locked")?.asBool() ?? false

          Area2D$ {
            Sprite2D$().res(\.texture, locked ? "chest_locked.png" : "chest.png")
          }
          .position(entity.position)
          .onSignal(\.bodyEntered) { _, body in
            inventory.append(contentsOf: loot)
          }
        }

        .onSpawn("Door") { entity, level, project in
          let destination: String? = entity.field("destination")?.asString()
          let keyRequired: Item? = entity.field("key_required")?.asEnum()

          Area2D$()
            .position(entity.position)
        }

        .onSpawned { node, entity in
          // Post-process all entities
          if let debugMode = entity.field("debug")?.asBool(), debugMode {
            node.addChild(node: Label$().text(entity.identifier).toNode())
          }
        }
        .zIndexOffset(100)
        .createEntityMarkers()

      // HUD
      CanvasLayer$ {
        VBoxContainer$ {
          Label$()
            .bind(\.text, to: $health) { "Health: \($0)" }
          Label$()
            .bind(\.text, to: $inventory) { items in
              "Items: \(items.map(\.rawValue).joined(separator: ", "))"
            }
        }
        .offset(top: 10, left: 10)
      }
    }
  }
}

// Usage
let project = LDProject.load("res://game.ldtk")!
addChild(node: GameView(project: project).toNode())
```

### LDtk Field Accessors

All LDtk field types are supported:

```swift
// Single values
entity.field("health")?.asInt() -> Int?
entity.field("speed")?.asFloat() -> Double?
entity.field("locked")?.asBool() -> Bool?
entity.field("name")?.asString() -> String?
entity.field("tint")?.asColor() -> Color?
entity.field("destination")?.asPoint() -> LDPoint?
entity.field("spawn_pos")?.asVector2(gridSize: 16) -> Vector2?
entity.field("target")?.asEntityRef() -> LDEntityRef?
entity.field("item_type")?.asEnum<Item>() -> Item?

// Arrays
entity.field("scores")?.asIntArray() -> [Int]?
entity.field("distances")?.asFloatArray() -> [Double]?
entity.field("flags")?.asBoolArray() -> [Bool]?
entity.field("tags")?.asStringArray() -> [String]?
entity.field("waypoints")?.asPointArray() -> [LDPoint]?
entity.field("patrol")?.asVector2Array(gridSize: 16) -> [Vector2]?
entity.field("palette")?.asColorArray() -> [Color]?
entity.field("targets")?.asEntityRefArray() -> [LDEntityRef]?
entity.field("loot")?.asEnumArray<Item>() -> [Item]?
entity.field("values")?.asArray() -> [LDFieldValue]?  // Raw array
```

### LDtk Collision Helper

```swift
// Get physics layer bit for IntGrid group name
let wallLayer = project.collisionLayer(for: "walls", in: level)
let platformLayer = project.collisionLayer(for: "platforms", in: level)

CharacterBody2D$()
  .collisionMask(wallLayer | platformLayer)
```

## AseSprite

```swift
// Load Aseprite animations
let sprite = AseSprite(
  "character.json",
  layer: "Body",
  options: .init(
    timing: .delaysGCD,
    trimming: .applyPivotOrCenter
  ),
  autoplay: "Idle"
)

// Builder pattern
AseSprite$(path: "player", layer: "Main")
  .configure { sprite in
    sprite.play(anim: "Walk")
  }
```

## Complete Game Example

```swift
import SwiftGodot
import SwiftGodotPatterns

@Godot
final class Game: Node2D {
  override func _ready() {
    setupInput()
    let project = LDProject.load("res://game.ldtk")!
    addChild(node: GameView(project: project).toNode())
  }

  func setupInput() {
    Actions {
      Action("move_left") { Key(.a); Key(.left) }
      Action("move_right") { Key(.d); Key(.right) }
      Action("jump") { Key(.space); Key(.w) }
      Action("shoot") { MouseButton(1) }
    }.install()
  }
}

enum Item: String, LDExported {
  case coin = "Coin"
  case key = "Key"
  case potion = "Potion"
}

enum GameEvent: EmittableEvent {
  case itemCollected(Item)
  case enemyKilled
  case playerDied
}

struct GameView: GView {
  let project: LDProject
  @State var inventory: [Item] = []
  @State var health: Int = 100
  @State var score: Int = 0

  var body: some GView {
    Node2D$ {
      LDLevelView(project, level: "Main")
        .onSpawn("Player") { entity, level, project in
          PlayerView(
            startPos: entity.position,
            wallLayer: project.collisionLayer(for: "walls", in: level)
          )
        }
        .onSpawn("Enemy") { entity, level, project in
          EnemyView(
            startPos: entity.position,
            enemyType: entity.field("type")?.asEnum() ?? .goblin
          )
        }
        .onSpawn("Collectible") { entity, level, project in
          let item: Item? = entity.field("item")?.asEnum()

          Area2D$ {
            Sprite2D$().res(\.texture, "item_\(item?.rawValue ?? "unknown").png")
          }
          .position(entity.position)
          .onSignal(\.bodyEntered) { node, _ in
            if let item = item {
              GameEvent.itemCollected(item).emit()
              node.queueFree()
            }
          }
        }

      HUDView(inventory: $inventory, health: $health, score: $score)
    }
    .onEvent(GameEvent.self) { _, event in
      switch event {
      case .itemCollected(let item):
        inventory.append(item)
        score += 10
      case .enemyKilled:
        score += 100
      case .playerDied:
        health = 0
      }
    }
  }
}

struct PlayerView: GView {
  let startPos: Vector2
  let wallLayer: UInt32
  @State var position: Vector2
  @State var velocity: Vector2 = .zero
  @State var player: CharacterBody2D?

  let gravity: Float = 980
  let speed: Float = 200
  let jumpSpeed: Float = 300

  init(startPos: Vector2, wallLayer: UInt32) {
    self.startPos = startPos
    self.wallLayer = wallLayer
    self._position = State(initialValue: startPos)
  }

  var body: some GView {
    CharacterBody2D$ {
      Sprite2D$().res(\.texture, "player.png")
      CollisionShape2D$().shape(RectangleShape2D(w: 16, h: 22))
    }
    .position($position)
    .velocity($velocity)
    .collisionMask(wallLayer)
    .ref($player)
    .onProcess { _, delta in
      updatePlayer(delta)
    }
  }

  func updatePlayer(_ delta: Double) {
    guard let player = player else { return }

    var vel = velocity
    vel.y += gravity * Float(delta)

    var inputX: Float = 0
    if Action("move_left").isPressed { inputX -= 1 }
    if Action("move_right").isPressed { inputX += 1 }
    vel.x = inputX * speed

    if Action("jump").isJustPressed && player.isOnFloor() {
      vel.y = -jumpSpeed
    }

    player.velocity = vel
    player.moveAndSlide()

    velocity = player.velocity
    position = player.position
  }
}

struct EnemyView: GView {
  let startPos: Vector2
  let enemyType: EnemyType
  @State var position: Vector2
  @State var health: Int = 10

  init(startPos: Vector2, enemyType: EnemyType) {
    self.startPos = startPos
    self.enemyType = enemyType
    self._position = State(initialValue: startPos)
  }

  var body: some GView {
    Area2D$ {
      Sprite2D$().res(\.texture, "enemy_\(enemyType.rawValue).png")
      CollisionShape2D$().shape(CircleShape2D(radius: 8))
    }
    .position($position)
    .onSignal(\.bodyEntered) { node, _ in
      health -= 10
      if health <= 0 {
        GameEvent.enemyKilled.emit()
        node.queueFree()
      }
    }
  }
}

enum EnemyType: String, LDExported {
  case goblin = "Goblin"
  case skeleton = "Skeleton"
}

struct HUDView: GView {
  let inventory: State<[Item]>
  let health: State<Int>
  let score: State<Int>

  var body: some GView {
    CanvasLayer$ {
      VBoxContainer$ {
        Label$()
          .bind(\.text, to: health) { "Health: \(String(repeating: "♥", count: max(0, $0)))" }
        Label$()
          .bind(\.text, to: score) { "Score: \($0)" }
        Label$()
          .bind(\.text, to: inventory) { items in
            "Inventory: \(items.map(\.rawValue).joined(separator: ", "))"
          }
      }
      .offset(top: 10, left: 10)
    }
  }
}
```

## Common Patterns

### Character Controller

```swift
struct PlayerController: GView {
  @State var position: Vector2 = .zero
  @State var velocity: Vector2 = .zero
  @State var player: CharacterBody2D?

  let gravity: Float = 980
  let speed: Float = 200
  let jumpSpeed: Float = 300

  var body: some GView {
    CharacterBody2D$ {
      Sprite2D$().res(\.texture, "player.png")
      CollisionShape2D$().shape(RectangleShape2D(w: 16, h: 22))
    }
    .position($position)
    .velocity($velocity)
    .ref($player)
    .onProcess { _, delta in
      guard let player = player else { return }

      var vel = velocity
      vel.y += gravity * Float(delta)

      let input = RuntimeAction.axis(negative: "move_left", positive: "move_right")
      vel.x = input * speed

      if Action("jump").isJustPressed && player.isOnFloor() {
        vel.y = -jumpSpeed
      }

      player.velocity = vel
      player.moveAndSlide()

      velocity = player.velocity
      position = player.position
    }
  }
}
```

### Interactive Object

```swift
struct Chest: GView {
  let position: Vector2
  let loot: [Item]
  @State var isOpen = false

  var body: some GView {
    Area2D$ {
      If($isOpen) {
        Sprite2D$().res(\.texture, "chest_open.png")
      }
      .Else {
        Sprite2D$().res(\.texture, "chest_closed.png")
      }
      CollisionShape2D$().shape(RectangleShape2D(w: 16, h: 16))
    }
    .position(position)
    .onSignal(\.bodyEntered) { _, body in
      guard !isOpen else { return }
      isOpen = true
      GameEvent.lootCollected(loot).emit()
    }
  }
}
```

### Health Bar

```swift
struct HealthBar: GView {
  let health: State<Int>
  let maxHealth: Int

  var body: some GView {
    ProgressBar$()
      .maxValue(Double(maxHealth))
      // Formatter used for type conversion
      .bind(\.value, to: health) { Double($0) }
      .size(.expandFill)
  }
}
```

### Menu System

```swift
enum MenuPage {
  case mainMenu
  case levelSelect
  case settings
}

struct MainMenu: GView {
  @State var currentPage: MenuPage = .mainMenu

  var body: some GView {
    CanvasLayer$ {
      VBoxContainer$ {
        Label$().text("My Game")

        Switch($currentPage) {
          Case(.mainMenu) {
            Button$().text("Start").onSignal(\.pressed) { _ in
              currentPage = .levelSelect
            }
            Button$().text("Settings").onSignal(\.pressed) { _ in
              currentPage = .settings
            }
            Button$().text("Quit").onSignal(\.pressed) { _ in
              Engine.getSceneTree()?.quit()
            }
          }

          Case(.levelSelect) {
            Label$().text("Level Select")
            Button$().text("Back").onSignal(\.pressed) { _ in
              currentPage = .mainMenu
            }
          }

          Case(.settings) {
            Label$().text("Settings")
            Button$().text("Back").onSignal(\.pressed) { _ in
              currentPage = .mainMenu
            }
          }
        }
      }
      .anchorsAndOffsets(.center)
    }
  }
}
```

### Inventory System

```swift
struct InventoryView: GView {
  @State var items: [Item] = []

  var body: some GView {
    VBoxContainer$ {
      Label$().text("Inventory")

      ForEach($items, id: \.rawValue) { item in
        HBoxContainer$ {
          TextureRect$().res(\.texture, "icon_\(item.wrappedValue.rawValue).png")
          Label$().text(item.wrappedValue.rawValue)
          Button$().text("Drop").onSignal(\.pressed) { _ in
            items.removeAll { $0 == item.wrappedValue }
          }
        }
      }
    }
  }
}
```

### Timer/Countdown

```swift
struct Countdown: GView {
  @State var timeLeft: Double = 60.0
  @State var isRunning: Bool = true

  var body: some GView {
    Label$()
      .bind(\.text, to: $timeLeft) { String(format: "%.1f", $0) }
      .onProcess { _, delta in
        if isRunning && timeLeft > 0 {
          timeLeft -= delta
        }
      }
  }
}
```
