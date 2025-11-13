
<a href="#"><img src="https://github.com/johnsusek/SwiftGodotPatterns/raw/main/media/patterns.png?raw=true" width="210" align="right" title="Pictured: Ancient Roman seamstress at a loom, holding a shuttle."></a>

### SwiftGodotPatterns

Game-agnostic utilities for [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot).

📕 [API Documentation](https://swiftpackageindex.com/johnsusek/SwiftGodotPatterns/documentation/swiftgodotpatterns)

<br><br><br><br>

## Builder

### 🏗️ Core Concepts

SwiftGodotPatterns provides a SwiftUI-inspired declarative builder pattern for creating Godot node hierarchies.

**Basic GNode Creation:**

```swift
// Create a node with default initializer
let sprite = GNode<Sprite2D> {
  // Children go here
}

// With custom initializer
let hud = GNode<CustomHUD>("HUD", make: { CustomHUD(config: myConfig) }) {
  HealthBar()
  ScoreLabel()
}
```

**$ Syntax Shorthand:**

```swift
// Instead of GNode<Sprite2D>(), use Sprite2D$()
Sprite2D$()
  .texture(myTexture)
  .position(Vector2(x: 100, y: 100))

// Works for all Godot node types
VBoxContainer$ {
  Label$().text("Hello")
  Button$().text("Click me")
}
```

**Dynamic Member Lookup:**

```swift
// Set any property using keypaths
Node2D$()
  .position(Vector2(x: 100, y: 200))
  .scale(Vector2(x: 2, y: 2))
  .rotation(45)

// StringName properties accept strings
Label$().name("MyLabel")  // Converted to StringName automatically
```

**Configure Closure:**

```swift
// For complex configuration
ColorRect$().configure { rect in
  // do anything with rect here
}
```

**Capture node references:**

```swift
@State var playerNode: CharacterBody2D?
CharacterBody2D$().ref($playerNode) // replaces: .onReady { node in playerNode = node }
```
## Node Modifiers

Custom modifiers available on `GNode` instances.

### 🗂️ Resource Loading

Load Godot resources using declarative syntax.

```swift
// Load resource into property
.res(\.texture, "player.png")

// Load with custom apply logic
.withResource("shader.gdshader", as: Shader.self) { node, shader in
  node.material = ShaderMaterial()
  (node.material as? ShaderMaterial)?.shader = shader
}
```

### 👥 Groups & Scene Instancing

Manage node groups and instantiate packed scenes.

```swift
// Add to single group
.group("enemies")
.group("enemies", persistent: true)

// Add to multiple groups
.groups(["enemies", "damageable"])

// Instance a packed scene as child
.fromScene("scenes/enemy.tscn") { child in
    // Optional: configure the instanced node
}
```

### 📡 Signal Connections

Connect to Godot signals with type-safe closures.

```swift
// No arguments
.onSignal(\.pressed) { node in
  print("\(node) was pressed")
}

// One argument
.onSignal(\.areaEntered) { node, area in
  print("Area entered: \(area)")
}

// Multiple arguments (up to 7 supported)
.onSignal(\.bodyShapeEntered) { node, bodyRid, body, bodyShapeIndex, localShapeIndex in
  // Handle collision
}
```

### 🎯 Event Bus

Subscribe to events from the EventBus system.

```swift
// Subscribe to all events of type
.onEvent(GameEvent.self) { node, event in
  // Handle event
}

// Subscribe with filter
.onEvent(GameEvent.self, match: { $0.isImportant }) { node, event in
  // Handle only important events
}
```

### 📐 Control Layout

Layout helpers for `Control` nodes (non-container and container contexts).

**Anchor/Offset System** (for non-container parents):

```swift
// Apply layout presets
.offsets(.topRight)
.anchors(.center)
.anchorsAndOffsets(.fullRect, margin: 10)

// Manual anchor/offset control
.anchor(top: 0, right: 1, bottom: 1, left: 0)
.offset(top: 12, right: -12, bottom: -12, left: 12)
```

**Container Size Flags** (for container parents like VBoxContainer):

```swift
// Set horizontal size flags
.sizeH(.expandFill)

// Set vertical size flags
.sizeV(.shrinkCenter)

// Set both
.size(.expandFill, .shrinkCenter)

// Set same for both axes
.size(.expandFill)
```

### ⚡ Process Hooks

Register callbacks for node lifecycle events.

```swift
// Called when node enters tree
.onReady { node in
  print("Node is ready!")
}

// Called every frame
.onProcess { node, delta in
  node.position.x += 100 * delta
}

// Called every physics frame
.onPhysicsProcess { node, delta in
  // Physics updates
}
```

## 📦 State Management

**@State Property Wrapper:**

```swift
@State var position: Vector2 = .zero

Node2D$().position($position)
```

### 🔄 State Binding

Bind `GState` to node properties for reactive updates.

**One-way Bindings:**

```swift
// Dynamic member syntax
.position($playerPosition)

// Binding by keypath
.bind(\.position, to: $playerPosition)

// Binding with transformation
.bind(\.text, to: $score) { "Score: \($0)" }

// Multi-State Bindings
.bind(\.text, to: $first, $second) { "\($0) - \($1)" }

// Binding to sub-property
.bind(\.x, to: $position, \.x)

// Custom update logic
.watch($health) { node, health in
    node.modulate = health < 20 ? .red : .white
}
```

### ↔️ Two-Way Bindings

Form controls with automatic two-way state synchronization.

```swift
// Text input
LineEdit$().text($username)
TextEdit$().text($notes)
CodeEdit$().text($code)

// Range controls
Slider$().value($volume)
ScrollBar$().value($scrollPos)
SpinBox$().value($count)

// Buttons
CheckBox$().pressed($isEnabled)

// Selection controls
OptionButton$().selected($optionIndex)
ItemList$().selected($selectedItem)
TabBar$().currentTab($activeTab)
TabContainer$().currentTab($activeTab)

// Color pickers
ColorPicker$().color($selectedColor)
ColorPickerButton$().color($backgroundColor)
```


### 🔄 Dynamic Views

**ForEach - Dynamic Lists:**

```swift
@State var items: [Item] = []

VBoxContainer$ {
  ForEach($items, id: \.id) { item in
    HBoxContainer$ {
      Label$().text(item.wrappedValue.name)
      Button$().text("Delete").onSignal(\.pressed) { _ in
        items.removeAll { $0.id == item.wrappedValue.id }
      }
    }
  }
}

// For Identifiable types, no need to specify id
ForEach($items) { item in
  ItemRow(item: item)
}

// Modes: .standard (default) or .deferred (batches updates to next frame)
ForEach($items, mode: .deferred) { item in
  // ...
}
```

**If - Conditional Rendering:**

```swift
@State var showDetails = false

VBoxContainer$ {
  Button$()
    .text("Toggle")
    .onSignal(\.pressed) { _ in showDetails.toggle() }

  If($showDetails) {
    Label$().text("Details are visible!")
  }
  .Else {
    Label$().text("Details are hidden")
  }
}
```

**Modes:**

```swift
If($condition) { /* ... */ }                // .hide (default) - Toggles visible property (fast)
If($condition) { /* ... */ }.mode(.remove)  // .remove - Uses addChild/removeChild (slow, cleaner tree)
If($condition) { /* ... */ }.mode(.destroy) // .destroy - Uses queueFree/rebuild (slowest, frees memory)
```

### 🎨 Theme Building

Create themes declaratively from dictionaries with automatic camelCase to snake_case conversion.

```swift
let myTheme = Theme([
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

// Apply theme to node
Control$().theme(myTheme)
```

## 📢 EventBus

Thread-safe publish/subscribe event bus for in-process messaging.

```swift
// Define event types
enum GameEvent {
  case playerDied
  case scoreChanged(Int)
  case levelComplete
}

// Create or resolve a bus
let bus = ServiceLocator.resolve(GameEvent.self)

// Subscribe to events
let token = bus.onEach { event in
  switch event {
  case .playerDied:
    print("Game Over")
  case .scoreChanged(let score):
    print("Score: \(score)")
  case .levelComplete:
    print("Level Complete!")
  }
}

// Publish events
bus.publish(.scoreChanged(100))

// Cancel subscription
bus.cancel(token)

// Debug logging
bus.tapLog(level: .debug, name: "GameEvents")
```

**ServiceLocator** provides global singleton buses per event type:

```swift
// Different event types get different buses
let gameBus = ServiceLocator.resolve(GameEvent.self)
let uiBus = ServiceLocator.resolve(UIEvent.self)
```

## 🗄️ Store

A uni-directional data store for managing application state with events and reducers.

**Basic Setup:**

```swift
// Define your state
struct GameState {
  var playerHealth: Int = 100
  var score: Int = 0
  var level: Int = 1
}

// Define events that can change state
enum GameEvent {
  case tookDamage(Int)
  case scoreAdded(Int)
}

// Create a pure reducer function
func gameReducer(state: inout GameState, event: GameEvent) {
  switch event {
  case .tookDamage(let amount):
    state.playerHealth = max(0, state.playerHealth - amount)
  case .scoreAdded(let points):
    state.score += points
  }
}

// Create the store
let store = Store(
  initialState: GameState(),
  reducer: gameReducer
)

// Send events to update state
store.commit(.tookDamage(20))
store.commit(.scoreAdded(100))

// Read current state
print(store.state.playerHealth) // 80
print(store.state.score)        // 100

// Binding to views
ProgressBar$().value(store.bind(\.playerHealth))
Label$().text(store.bind(\.score)) { "Score: \($0)" }
```

## Input Actions

Declarative input mapping with type-safe DSL.

### 🎮 Basic Actions

```swift
Actions {
  Action("jump") {
    Key(.space)
    JoyButton(.a, device: 0)
  }

  Action("shoot") {
    MouseButton(1)
    Key(.leftCtrl)
  }

  Action("pause") {
    Key(.escape)
  }
}
.install()
```

### 🕹️ Analog Axes

```swift
Actions {
  // Vertical axis (up/down)
  ActionRecipes.axisUD(
    namePrefix: "move",
    device: 0,
    axis: .leftY,
    dz: 0.2,
    keyDown: .s,
    keyUp: .w
  )

  // Horizontal axis (left/right)
  ActionRecipes.axisLR(
    namePrefix: "move",
    device: 0,
    axis: .leftX,
    dz: 0.2,
    keyLeft: .a,
    keyRight: .d
  )
}
.install()

// Creates actions: move_up, move_down, move_left, move_right
```

### 🎯 Runtime Polling

```swift
// Query action state
if Action("jump").isJustPressed {
  player.jump()
}

if Action("shoot").isPressed {
  player.shoot(Action("shoot").strength)
}

// Axis helpers
let horizontal = RuntimeAction.axis(negative: "move_left", positive: "move_right")
let movement = RuntimeAction.vector(
  negativeX: "move_left",
  positiveX: "move_right",
  negativeY: "move_up",
  positiveY: "move_down"
)
```

## Property Wrappers

Call `bindProps()` in `_ready()` to activate.

### 👶 @Child - Single Child Reference

```swift
final class Player: Node {
  @Child("Sprite") var sprite: Sprite2D?
  @Child("Health", deep: true) var healthBar: ProgressBar?

  override func _ready() {
    bindProps()
    sprite?.visible = true
  }
}
```

### 👨‍👩‍👧‍👦 @Children - Multiple Children

```swift
final class Menu: Node {
  @Children var buttons: [Button]
  @Children("Items", deep: true) var items: [Node2D]

  override func _ready() {
    bindProps()
    buttons.forEach { $0.disabled = false }
  }
}
```

### 👴 @Ancestor - Find Parent by Type

```swift
final class HealthBar: Node {
  @Ancestor var player: Player?

  override func _ready() {
    bindProps()
    player?.health.onChange { [weak self] hp in
      self?.updateBar(hp)
    }
  }
}
```

### 👫 @Sibling - Reference Sibling Node

```swift
final class PlayerController: Node {
  @Sibling("Sprite") var sprite: Sprite2D?
  @Sibling var firstNode: Node?  // First sibling of any type

  override func _ready() {
    bindProps()
  }
}
```

### 🌍 @Autoload - Reference Autoload Singleton

```swift
final class GameUI: CanvasLayer {
  @Autoload("GameState") var gameState: GameState?
  @Autoload("AudioManager") var audio: AudioManager?

  override func _ready() {
    bindProps()
    print("Level: \(gameState?.level ?? 0)")
  }
}
```

### 👥 @Group - Query by Group

```swift
final class EnemyManager: Node {
  @Group("enemies") var enemies: [CharacterBody2D]
  @Group(["interactive", "collectible"]) var items: [Node]

  override func _ready() {
    bindProps()

    // Use immediately
    print("Enemy count: \(enemies.count)")

    // Refresh later
    let current = $enemies()  // Re-queries and returns fresh list
  }
}
```

### 🔌 @Service - Inject EventBus

```swift
enum PlayerEvent {
  case died
  case healed(Int)
}

final class PlayerHealth: Node {
  @Service var events: EventBus<PlayerEvent>?

  override func _ready() {
    bindProps()
    events?.publish(.healed(50))
  }
}
```

### 💾 @Prefs - Persistent Preferences

```swift
final class Settings: Node {
  @Prefs("musicVolume", default: 0.5) var musicVolume: Double
  @Prefs("showHints", default: true) var showHints: Bool

  override func _ready() {
    bindProps()

    // Auto-loads from user://prefs.json
    print("Volume: \(musicVolume)")

    // Auto-saves on change
    musicVolume = 0.8
  }
}
```

### 📡 @OnSignal - Declarative Signal Binding

Automatically connect Godot signals to Swift methods using a macro. Call `bindProps()` in `_ready()` to activate.

```swift
final class MainMenu: Node {
  @OnSignal("StartButton", \Button.pressed)
  func onStartPressed(_ sender: Button) {
    print("Game starting!")
  }

  @OnSignal("Player/Area2D", \Area2D.bodyEntered)
  func onPlayerAreaEntered(_ sender: Area2D, _ body: Node) {
    print("Body entered: \(body.name)")
  }

  @OnSignal("QuitButton", \Button.pressed, flags: .oneShot)
  func onQuitPressed(_ sender: Button) {
    // Automatically disconnects after first call
    getTree()?.quit()
  }

  override func _ready() {
    bindProps()
  }
}
```

## Utilities

### 📝 MsgLog

Simple leveled logging singleton.

```swift
// Basic logging
MsgLog.shared.debug("Player spawned")
MsgLog.shared.info("Game started")
MsgLog.shared.warn("Low health")
MsgLog.shared.error("Failed to load")

// Configure minimum level
MsgLog.shared.minLevel = .warn  // Only warn and error

// Custom sink
MsgLog.shared.sink = { level, message in
  myCustomLogger.log(level, message)
}

// Access history
for (level, message) in MsgLog.shared.lines {
  print("[\(level)] \(message)")
}
```

### 🔧 SwiftGodot Extensions

**Engine:**

```swift
// Get SceneTree
if let tree = Engine.getSceneTree() {
  // ...
}

// Schedule next frame callback aka deferred
Engine.onNextFrame {
  print("Next frame!")
}

Engine.onNextPhysicsFrame {
  print("Next physics frame!")
}
```

**Node:**

```swift
// Typed node queries
let sprites: [Sprite2D] = node.getChildren()
// replaces: node.getChildren().compactMap { $0 as? Sprite2D }

let firstSprite: Sprite2D? = node.getChild()
// replaces: node.getChildren().first(where: { $0 is Sprite2D }) as? Sprite2D

let enemySprite: Sprite2D? = node.getNode("Enemy")
// replaces: node.getNode(path: NodePath("Enemy")) as? Sprite2D

// Group queries
let enemies: [Enemy] = node.getNodes(inGroup: "enemies")
// replaces: node.getTree()?.getNodesInGroup("enemies").compactMap { $0 as? Enemy } ?? []

// Parent chain
let parents: [Node2D] = node.getParents()

// Metadata queries (recursive search)
let coinSpawns: [Node2D] = root.queryMeta(key: "type", value: "coin_spawn")
let valuable: [Node2D] = root.queryMeta(key: "value", value: 100)
let spawners: [Node2D] = root.queryMetaKey("spawn_point")  // any value

// Get metadata safely
let coinValue: Int? = node.getMetaValue("coin_value")
```

**Vector2:**

```swift
// Convenience init
let pos = Vector2(100, 200)

// Array literal init
let pos: Vector2 = [100, 200]

// Scalar multiplication (Float, Double, Int)
let doubled = pos * 2
let scaled = pos * 1.5
```

**Shapes Inits:**

Configure shapes directly from inits, helpful for passing to properties in views.

```swift
RectangleShape2D(w: 50, h: 100)
CircleShape2D(radius: 25)
CapsuleShape2D(radius: 10, height: 50)
SegmentShape2D(a: [0, 0], b: [100, 100])
SeparationRayShape2D(length: 100)
WorldBoundaryShape2D(normal: [0, -1], distance: 0)
ConvexPolygonShape2D(points: myPoints)
ConcavePolygonShape2D(segments: mySegments)
```

## Components

### 🗺️ LDLevelView

Declaratively loads [LDtk](https://ldtk.io) levels - builds tile layers, collision shapes from IntGrid, and spawns entities.

LDExported enums let you work with typed data from LDtk. JSON is generated each build that syncs with the LDtk editor.

```swift
enum Item: String, LDExported {
  case knife = "Knife"
  case boots = "Boots"
}

struct GameView: GView {
  let project: LDProject

  @State var inventory: [Item] = []

  var body: some GView {
    Node2D$ {
      LDLevelView(project, level: "Level_0")
        .onSpawn("Player") { entity, level, project in
          let wallLayer = project.collisionLayer(for: "walls", in: level)

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
        .onSpawn("Chest") { entity, _, _ in
          let loot: [Item] = entity.field("loot")?.asEnumArray() ?? []

          Area2D$ {
            Sprite2D$().res(\.texture, "chest.png")
          }
          .position(entity.position)
          .onSignal(\.bodyEntered) { _, body in
            inventory.append(contentsOf: loot)
          }
        }
        .onSpawned { node, entity in
          // Post-process - add debugging labels to all entities
          node.addChild(node: Label$().text(entity.identifier).toNode())
        }
    }
  }
}

let project = LDProject.load("res://game.ldtk")
GameView(project: project)
```

**Field Accessors:**

All LDtk types are supported.

```swift
entity.field("health")?.asInt() -> Int?
entity.field("distance")?.asFloat() -> Double?
entity.field("is_locked")?.asBool() -> Bool?
entity.field("name")?.asString() -> String?
entity.field("tint")?.asColor() -> Color?
entity.field("destination")?.asPoint() -> LDPoint?
entity.field("destination")?.asVector2(gridSize: 16) -> Vector2?
entity.field("target")?.asEntityRef() -> LDEntityRef?
entity.field("items")?.asEnum<MyItemEnum>() -> MyItemEnum?

entity.field("scores")?.asIntArray() -> [Int]?
entity.field("distances")?.asFloatArray() -> [Double]?
entity.field("flags")?.asBoolArray() -> [Bool]?
entity.field("names")?.asStringArray() -> [String]?
entity.field("path")?.asPointArray() -> [LDPoint]?
entity.field("path")?.asVector2Array(gridSize: 16) -> [Vector2]?
entity.field("palette")?.asColorArray() -> [Color]?
entity.field("targets")?.asEntityRefArray() -> [LDEntityRef]?
entity.field("loot")?.asEnumArray<MyItemEnum>() -> [MyItemEnum]?
```

### 🎨 AseSprite

Loads and plays [Aseprite](https://www.aseprite.org) animations directly. Builds Godot SpriteFrames resources from Aseprite frame/timing data. Maps Aseprite tags to Godot animations.

```swift
// Basic usage
let character = AseSprite(
  "character.json",
  layer: "Body",
  options: .init(
    timing: .delaysGCD,
    trimming: .applyPivotOrCenter
  ),
  autoplay: "Idle"
)

// In builder pattern
AseSprite$(path: "player", layer: "Main")
  .configure { sprite in
    sprite.play(anim: "Walk")
  }
```
