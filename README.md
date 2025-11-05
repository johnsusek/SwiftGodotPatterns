
<a href="#"><img src="media/patterns.png?raw=true" width="210" align="right" title="Pictured: Ancient Roman seamstress at a loom, holding a shuttle."></a>

### SwiftGodotPatterns

Game-agnostic utilities for [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot), companion to [SwiftGodotBuilder](https://github.com/johnsusek/SwiftGodotBuilder).

#### 📕 [Documentation](https://swiftpackageindex.com/johnsusek/SwiftGodotPatterns/documentation/swiftgodotpatterns)

#### 📔 [Examples](https://swiftpackageindex.com/johnsusek/SwiftGodotPatterns/documentation/swiftgodotpatterns/examples)

<br><br><br>

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
ColorRect$()
  .configure { rect in
    // do anything with rect: ColorRect
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

---
