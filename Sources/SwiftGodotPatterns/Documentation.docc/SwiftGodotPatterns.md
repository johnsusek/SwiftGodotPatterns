# ``SwiftGodotPatterns``

Game Programming Patterns for SwiftGodot

## Overview

SwiftGodotPatterns is a collection of declarative, type-safe APIs for building games with SwiftGodot. It provides SwiftUI-inspired builders, reactive state management, property binding, and data-driven game content systems.

### Key Features

- **Declarative Node Hierarchies** - SwiftUI-style DSL for building scene trees
- **Reactive State Management** - `@State` and `@Binding` property wrappers with automatic updates
- **Declarative Actions Management** - Declarative action setup
- **Property Wrappers** - Declarative node resolution and binding
- **Type-Safe Events** - Generic publish/subscribe system with zero boilerplate

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Examples>

### Property Wrappers

Declarative property binding that activates via `node.bindProps()` from `_ready()`.

- ``Child``
- ``Children``
- ``Ancestor``
- ``Sibling``
- ``Group``
- ``Autoload``
- ``Service``
- ``Prefs``

### Builders

Declarative node construction with result builders.

- ``GView``
- ``GNode``
- ``NodeBuilder``

#### State Management

SwiftUI-style observable state with automatic listener notification.

- ``GState``

### Events

Type-safe publish/subscribe.

- ``EventBus``
- ``ServiceLocator``

### Macros

Compile-time code generation for common patterns.

- ``OnSignal(_:_:flags:)``

### AseSprite

- ``AseSprite``

### Input Handling

Declarative input action setup and state tracking.

- ``ActionSpec``
- ``Actions``
- ``ActionRecipes``
- ``ActionBuilder``

### Utilities

Supporting extensions and utilities.

- <doc:GodotExtensions>
- ``MsgLog``
- ``PatternsRegistry``

## See Also

- [SwiftGodot Documentation](https://migueldeicaza.github.io/SwiftGodotDocs/documentation/swiftgodot/)
- [Godot Documentation](https://docs.godotengine.org/)
