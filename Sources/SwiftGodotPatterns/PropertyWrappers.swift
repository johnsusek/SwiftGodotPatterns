import Foundation
import SwiftGodot

/// Walks up the parent chain to find the first ancestor of type `T`.
///
/// Useful when child nodes need a reference to a typed controller/owner without hard-coding paths.
///
/// ### Example
/// ```swift
/// final class HealthBar: Node {
///   @Ancestor<Node2D> var owner2D: Node2D?
///
///   override func _ready() {
///     bindProps()
///     owner2D?.show()
///   }
/// }
/// ```
@propertyWrapper
public final class Ancestor<T: Node>: _AutoBindProp {
  private var ref: T?

  public init() {}

  public var wrappedValue: T? {
    return ref
  }

  public var projectedValue: T? { ref }

  func _bind(host: Node) {
    var cur = host.getParent()

    while let p = cur {
      if let t = p as? T {
        ref = t
        return
      }

      cur = p.getParent()
    }
  }
}

/// Resolves and type-casts a node from the Autoload list by name.
///
/// ### Example
/// ```swift
/// final class Overlay: CanvasLayer {
///   @Autoload<GameState>("GameState") var gameState: GameState?
///   override func _ready() {
///     bindProps()
///     if let gs = gameState { GD.print("level: \\(gs.level)") }
///   }
/// }
/// ```
@propertyWrapper
public final class Autoload<T: Node>: _AutoBindProp {
  private var ref: T?
  private let name: String

  public init(_ name: String) { self.name = name }

  public var wrappedValue: T? { ref }
  public var projectedValue: T? { ref }

  func _bind(host _: Node) {
    let tree = Engine.getMainLoop() as? SceneTree
    ref = tree?.root?.getNode(path: NodePath("/root/\(name)")) as? T
  }
}

/// Collects child nodes of a given type into an array, optionally under a sub-path and/or recursively.
///
/// Use this when you want a typed slice of your scene subtree without manual `getChildren()` plumbing.
/// The array is populated when `bindProps()` runs.
///
/// - Parameters:
///   - path: Optional relative path under the host from which to start the search.
///   - deep: If `true`, traverses descendants recursively otherwise only direct children are considered.
///
/// ### Usage: direct children
/// ```swift
/// final class Menu: Node {
///   @Children var buttons: [Button]   // all Button children
///
///   override func _ready() {
///     bindProps()
///     for button in buttons { button.disabled = false }
///   }
/// }
/// ```
///
/// ### Usage: scoped, deep search
/// ```swift
/// final class Board: Node {
///   @Children("Cells", deep: true) var tiles: [Node2D]
///   override func _ready() { bindProps() }
/// }
/// ```
@propertyWrapper
public final class Children<T: Node>: _AutoBindProp {
  private(set) var list: [T] = []
  private let path: String?
  private let deep: Bool

  public init(_ path: String? = nil, deep: Bool = false) {
    self.path = path
    self.deep = deep
  }

  public var wrappedValue: [T] { list }

  func _bind(host: Node) {
    list.removeAll()

    func collect(from n: Node) {
      for c in n.getChildren() {
        if let t = c as? T { list.append(t) }
        if deep, let c { collect(from: c) }
      }
    }

    if let p = path, let n = host.getNode(p) {
      collect(from: n)
    } else {
      collect(from: host)
    }
  }
}

/// Resolves a single child node of a given type, optionally under a sub-path and/or recursively.
///
/// Use this when you want a typed reference to a specific child node without manual `getNode()` plumbing.
/// The node is populated when `bindProps()` runs.
///
/// - Parameters:
///   - path: Optional relative path under the host from which to start the search.
///   - deep: If `true`, traverses descendants recursively; otherwise only direct children are considered.
///
/// ### Usage: direct child
/// ```swift
/// final class Player: Node {
///   @Child("Sprite") var sprite: Sprite2D?
///
///   override func _ready() {
///     bindProps()
///     sprite?.visible = false
///   }
/// }
/// ```
///
/// ### Usage: deep search
/// ```swift
/// final class GameScene: Node {
///   @Child("Ball", deep: true) var ball: RigidBody2D?
///   override func _ready() { bindProps() }
/// }
/// ```
@propertyWrapper
public final class Child<T: Node>: _AutoBindProp {
  private(set) var node: T?
  private let path: String?
  private let deep: Bool

  public init(_ path: String? = nil, deep: Bool = false) {
    self.path = path
    self.deep = deep
  }

  public var wrappedValue: T? { node }

  func _bind(host: Node) {
    if let p = path, let n = host.getNode(p) as? T {
      node = n
      return
    }

    func findFirst(in parent: Node) -> T? {
      for c in parent.getChildren() {
        if let t = c as? T {
          if let p = path {
            if c?.name == StringName(p) {
              return t
            }
          } else {
            return t
          }
        }
        if deep, let c, node == nil {
          if let found = findFirst(in: c) {
            return found
          }
        }
      }
      return nil
    }

    node = findFirst(in: host)

    if node == nil {
      var m = "⚠️ No \(T.self) found"
      if let path { m += " at '\(path)'" }
      m += " in \(host)"
      GD.printErr(m)
    }
  }
}

/// Queries nodes by Godot group membership at bind time, returning a typed array.
///
/// Use this to get all nodes in one or more groups across the active `SceneTree`.
/// Results are the union of all provided groups and are de-duplicated. The list
/// is captured when `bindProps()` runs; call `$property()` to refresh on demand.
///
/// ### Examples
/// ```swift
/// final class EnemyHUD: Node {
///   // All enemies anywhere in the tree, typed:
///   @Group("enemies") var enemies: [CharacterBody2D]
///
///   // Union of multiple groups:
///   @Group(["interactables", "doors"]) var interactables: [Node]
///
///   override func _ready() {
///     bindProps()
///     // Use immediately:
///     enemies.forEach { _ = $0.isVisibleInTree() }
///
///     // Refresh later if the scene composition changes:
///     let current = $enemies()  // re-queries and returns the fresh list
///     GD.print("Enemy count: \(current.count)")
///   }
/// }
/// ```
@propertyWrapper
public final class Group<T: Node>: _AutoBindProp {
  private let names: [StringName]
  private weak var hostNode: Node?
  private var cached: [T] = []

  /// Query a single group.
  public init(_ name: String) {
    names = [StringName(name)]
  }

  /// Query the union of multiple groups.
  public init(_ names: [String]) {
    self.names = names.map { StringName($0) }
  }

  /// The last queried result. Populated by `bindProps()` and updated by `$property()`.
  public var wrappedValue: [T] { cached }

  /// Call `$property()` to refresh and *return* the latest result in one step.
  public var projectedValue: () -> [T] {
    { [weak self] in self?.refresh(); return self?.cached ?? [] }
  }

  func _bind(host: Node) {
    hostNode = host
    refresh()
  }

  private func refresh() {
    guard let tree = hostNode?.getTree() else { cached = []; return }
    var seen = Set<ObjectIdentifier>()
    var list: [T] = []

    for groupName in names {
      // Godot: SceneTree.getNodesInGroup(StringName) -> Array<Node>
      let groupNodes = tree.getNodesInGroup(groupName)
      for anyNode in groupNodes {
        guard let node = anyNode as? T else { continue }
        let identifier = ObjectIdentifier(node)
        if seen.insert(identifier).inserted { list.append(node) }
      }
    }
    cached = list
  }
}

/// Resolves a service from a `ServiceLocator` as an `EventBus<E>`.
///
/// This is a convenience wrapper for dependency retrieval.
///
/// ### Example
/// ```swift
/// enum GameEvent { case playerDied, score(Int) }
///
/// final class ScoreView: Node {
///   @Service<GameEvent> var events: EventBus<GameEvent>?
///
///   override func _ready() {
///     bindProps()
///     events?.subscribe(self) { [weak self] evt in
///       switch evt {
///       case .score(let s): self?.updateLabel(s)
///       default: break
///       }
///     }
///   }
///   private func updateLabel(_ value: Int) { /* ... */ }
/// }
/// ```
@propertyWrapper
public final class Service<E>: _AutoBindProp {
  private var bus: EventBus<E>?

  public init() {}

  public var wrappedValue: EventBus<E>? { bus }
  public var projectedValue: EventBus<E>? { bus }

  func _bind(host _: Node) {
    bus = ServiceLocator.resolve(E.self)
  }
}

/// Resolves a single sibling node of a given type, optionally under a named nodepath (just the sibling's name).
///
/// Use this when you want a typed reference to a specific sibling node without manual `getNode
/// ()` plumbing. The node is populated when `bindProps()` runs.
///
///
@propertyWrapper
public final class Sibling<T: Node>: _AutoBindProp {
  private(set) var node: T?
  private let name: String?
  public init(_ name: String? = nil) {
    self.name = name
  }

  public var wrappedValue: T? { node }
  func _bind(host: Node) {
    guard let parent = host.getParent() else {
      GD.printErr("⚠️ No parent for \(host); cannot find sibling \(T.self)")
      return
    }

    if let name, let n = parent.getNode(name) as? T {
      node = n
      return
    }

    for c in parent.getChildren() {
      if c === host { continue }
      if let t = c as? T {
        node = t
        return
      }
    }

    var m = "⚠️ No sibling \(T.self) found"
    if let name { m += " named '\(name)'" }
    m += " for \(host)"
    GD.printErr(m)
  }
}

/// Internal protocol adopted by property wrappers that support binding.
///
/// Conforming wrappers implement `._bind(host:)`, which is invoked by `Node.bindProps()`
/// to wire themselves up (resolve nodes, connect signals, schedule process loops, etc.).
@_documentation(visibility: private)
protocol _AutoBindProp: AnyObject {
  /// Performs the one-time binding against the given host node.
  ///
  /// - Important: Designed to be called once per instance (typically from `_ready()`).
  func _bind(host: Node)
}

public extension Node {
  /// Reflectively binds all `_AutoBindProp` property wrappers declared on `self` (and superclasses).
  ///
  /// Call this once from your node’s `_ready()` to activate wrappers like `@Children`, `@Group`,
  /// `@OnSignal`, `@ProcessLoop`, etc. It walks the inheritance chain to catch wrappers declared
  /// in base classes as well.
  ///
  /// - Warning: Many wrappers have side effects (e.g., adding child relays, joining groups).
  ///   Calling this multiple times on the same instance may duplicate those effects. Prefer
  ///   a single call from `_ready()`.
  func bindProps() {
    var m: Mirror? = Mirror(reflecting: self)

    while let cur = m {
      for child in cur.children {
        (child.value as? _AutoBindProp)?._bind(host: self)
      }

      m = cur.superclassMirror
    }
  }
}

/// A property wrapper that persists a Codable value to user://prefs.json under a given key.
///
/// The value is loaded when the host node calls `bindProps()`, and saved whenever the value changes.
///
/// Example:
/// ```swift
/// final class SettingsMenu: Node {
///   @Prefs("musicVolume", default: 0.5) var musicVolume: Double
///   @Prefs("showHints", default: true) var showHints: Bool
///
///   override func _ready() {
///     bindProps()
///     GD.print("Music volume is \($musicVolume())")
///   }
/// }
/// ```
@propertyWrapper
final class Prefs<T>: _AutoBindProp where T: Codable {
  private let key: String; private let defaultValue: T
  private var value: T

  init(_ key: String, default: T) { self.key = key; defaultValue = `default`; value = `default` }

  var wrappedValue: T {
    get { value }
    set { value = newValue; save() }
  }

  func _bind(host _: Node) {
    if let text = FileAccess.getFileAsString(path: "user://prefs.json").nilIfEmpty,
       let data = text.data(using: .utf8),
       let obj = try? JSONDecoder().decode([String: T].self, from: data),
       let v = obj[key] { value = v }
  }

  private func save() {
    var dict: [String: T] = [:]
    if let text = FileAccess.getFileAsString(path: "user://prefs.json").nilIfEmpty,
       let data = text.data(using: .utf8),
       let obj = try? JSONDecoder().decode([String: T].self, from: data) { dict = obj }
    dict[key] = value
    if let data = try? JSONEncoder().encode(dict) {
      let f = FileAccess.open(path: "user://prefs.json", flags: .write)
      _ = f?.storeString(String(decoding: data, as: UTF8.self))
    }
  }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
