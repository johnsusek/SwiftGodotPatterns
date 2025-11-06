
<a href="#"><img src="media/patterns.png?raw=true" width="210" align="right" title="Pictured: Ancient Roman seamstress at a loom, holding a shuttle."></a>

### SwiftGodotPatterns

Game-agnostic utilities for [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot).

📕 [API Documentation](https://swiftpackageindex.com/johnsusek/SwiftGodotPatterns/documentation/swiftgodotpatterns)

<br><br><br><br>

## Builder Pattern

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

### 📦 State Management

**@State Property Wrapper:**

```swift
@State var position: Vector2 = .zero

Node2D$().position($position)
```

### 🔄 Dynamic Views

**ForEach - Dynamic Lists:**

```swift
@State var items: [Item] = []

VBoxContainer$ {
  ForEach($items, id: \.id) { $item in
    HBoxContainer$ {
      Label$().text(item.wrappedValue.name)
      Button$().text("Delete").onSignal(\.pressed) { _ in
        items.removeAll { $0.id == item.wrappedValue.id }
      }
    }
  }
}

// For Identifiable types, no need to specify id
ForEach($items) { $item in
  ItemRow(item: $item)
}

// Modes: .standard (default) or .deferred (batches updates)
ForEach($items, mode: .deferred) { $item in
  // ...
}
```

**If - Conditional Rendering:**

```swift
@State var showDetails = false

VBoxContainer$ {
  Button$().text("Toggle")
    .onSignal(\.pressed) { _ in showDetails.toggle() }

  If($showDetails) {
    Label$().text("Details are visible!")
  }
  .Else {
    Label$().text("Details are hidden")
  }
}
```

**If Modes:**

```swift
// .hide (default) - Toggles visible property (fast)
If($condition) { /* ... */ }

// .remove - Uses addChild/removeChild (cleaner tree)
If($condition) { /* ... */ }.mode(.remove)

// .destroy - Uses queueFree/rebuild (frees memory)
If($condition) { /* ... */ }.mode(.destroy)
```

## GNode Modifiers

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
.instanceScene("scenes/enemy.tscn") { child in
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

### 💥 Collision (2D)

Set collision layers and masks for `CollisionObject2D` nodes.

```swift
.collisionLayer(.alpha)
.collisionMask([.beta, .gamma])
```

Available layers: `.alpha`, `.beta`, `.gamma`, `.delta`, `.epsilon`, `.zeta`, `.eta`, `.theta`, `.iota`, `.kappa`, `.lambda`, `.mu`, `.nu`, `.xi`, `.omicron`, `.pi`, `.rho`, `.sigma`, `.tau`, `.upsilon`, `.phi`, `.chi`, `.psi`, `.omega`

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

// Binding to sub-property
.bind(\.x, to: $position, \.x)

// Custom update logic
.watch($health) { node, health in
    node.modulate = health < 20 ? .red : .white
}
```

**Multi-State Bindings:**

```swift
// Combine two states
.bind(\.text, to: $first, $second) { "\($0) - \($1)" }

// Combine three states
.bind(\.text, to: $a, $b, $c) { "\($0), \($1), \($2)" }

// Combine four states
.bind(\.text, to: $a, $b, $c, $d) { a, b, c, d in
    // Complex transformation
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

## Event System

### 📢 EventBus

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
.install(clearExisting: true)
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

## Property Wrappers

For node references and dependency injection. Call `bindProps()` in `_ready()` to activate.

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

// Schedule next frame callback
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
let firstSprite: Sprite2D? = node.getChild()
let enemySprite: Sprite2D? = node.getNode("Enemy")

// Group queries
let enemies: [Enemy] = node.nodes(inGroup: "enemies")

// Parent chain
let parents: [Node2D] = node.getParents()
```

**Vector2:**

```swift
// Convenience init
let pos = Vector2(100, 200)

// Scalar multiplication (Float, Double, Int)
let doubled = pos * 2
let scaled = pos * 1.5
```

## Components

### 🎨 AseSprite

Loads and plays Aseprite animations directly in Godot.

**Features:**
- Loads Aseprite JSON + spritesheet exports
- Maps Aseprite tags to Godot animations
- Supports layer filtering
- Handles trimmed frames with automatic offset
- Multiple timing strategies

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
GNode<AseSprite>(path: "player", layer: "Main")
  .configure { sprite in
    sprite.play(anim: "Walk")
  }
```

**Options:**
- `timing`: `.uniformFPS`, `.exactDelays`, `.delaysGCD`
- `trimming`: `.applyPivotOrCenter`, `.none`
- Layer filtering for multi-layer exports
- Tag filtering/mapping
