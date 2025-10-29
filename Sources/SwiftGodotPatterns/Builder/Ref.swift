import Foundation
import SwiftGodot

// MARK: - Class ref

// Marker for views that need to bind refs into the eventual root.
protocol _RefBindTag {
  func _makeAndBind(into root: Node) -> Node
}

struct _BindWeakRef<Root: Node, U: Node>: GView, _RefBindTag {
  let inner: any GView
  let kp: ReferenceWritableKeyPath<Root, U?>

  func toNode() -> Node { inner.toNode() }

  func _makeAndBind(into host: Node) -> Node {
    let built = inner.toNode()

    // Fast path: the host being built is already the Root
    if let owner = host as? Root, let child = built as? U {
      owner[keyPath: kp] = child
      return built
    }

    // Fallback: we were nested; bind on next frame once the tree is complete
    _ = Engine.onNextFrame {
      guard let owner = _findAncestor(startingAt: built, as: Root.self),
            let child = built as? U else { return }
      owner[keyPath: kp] = child
    }
    return built
  }
}

struct _BindWeakRefs<Root: Node, U: Node>: GView, _RefBindTag {
  let inner: any GView
  let kp: ReferenceWritableKeyPath<Root, NSHashTable<U>>

  func toNode() -> Node { inner.toNode() }

  func _makeAndBind(into host: Node) -> Node {
    let built = inner.toNode()

    if let owner = host as? Root, let child = built as? U {
      owner[keyPath: kp].add(child)
      return built
    }

    _ = Engine.onNextFrame {
      guard let owner = _findAncestor(startingAt: built, as: Root.self),
            let child = built as? U else { return }
      owner[keyPath: kp].add(child)
    }
    return built
  }
}

// MARK: - Public builder API

public extension GNode {
  /// Bind the created node into a `weak` optional property on an ancestor `Root`.
  /// Usage:
  ///   final class Player: Node { public weak var gun: Gun? }
  ///   GNode<Gun>().ref(\Player.gun)
  func ref<Root: Node>(_ kp: ReferenceWritableKeyPath<Root, T?>) -> any GView {
    _BindWeakRef(inner: self, kp: kp)
  }

  /// Bind the created node into an `NSHashTable<T>` on an ancestor `Root`.
  /// Usage:
  ///   final class Spawner: Node { public let bullets = NSHashTable<Bullet>.weakObjects() }
  ///   GNode<Bullet>().ref(into: \Spawner.bullets)
  func ref<Root: Node>(into kp: ReferenceWritableKeyPath<Root, NSHashTable<T>>) -> any GView {
    _BindWeakRefs(inner: self, kp: kp)
  }
}

// MARK: - Direct Ref/Refs API

import SwiftGodot

public final class Ref<T: Node> {
  public weak var node: T?
  public init() {}
}

public final class Refs<T: Node> {
  @_documentation(visibility: private)
  public struct WeakBox { public weak var value: T? }
  public private(set) var items: [WeakBox] = []
  public init() {}
  @inlinable public var alive: [T] { items.compactMap(\.value) }
  public func add(_ n: T) { items.append(.init(value: n)) }
}

public extension GNode {
  func ref(_ r: Ref<T>) -> Self {
    var s = self
    s.ops.append { n in r.node = n }
    return s
  }

  func ref(into r: Refs<T>) -> Self {
    var s = self
    s.ops.append { n in r.add(n) }
    return s
  }
}

private func _findAncestor<Root: Node>(startingAt node: Node, as _: Root.Type) -> Root? {
  var cur = node.getParent()
  while let p = cur {
    if let r = p as? Root { return r }
    cur = p.getParent()
  }
  return nil
}

struct _BindRef<Root: Node, U: Node>: GView, _RefBindTag {
  let inner: any GView
  let kp: KeyPath<Root, Ref<U>>
  func toNode() -> Node { inner.toNode() }
  func _makeAndBind(into host: Node) -> Node {
    let built = inner.toNode()
    if let owner = host as? Root, let child = built as? U {
      owner[keyPath: kp].node = child
      return built
    }
    _ = Engine.onNextFrame {
      guard let owner = _findAncestor(startingAt: built, as: Root.self),
            let child = built as? U else { return }
      owner[keyPath: kp].node = child
    }
    return built
  }
}

struct _BindRefs<Root: Node, U: Node>: GView, _RefBindTag {
  let inner: any GView
  let kp: KeyPath<Root, Refs<U>>
  func toNode() -> Node { inner.toNode() }
  func _makeAndBind(into host: Node) -> Node {
    let built = inner.toNode()
    if let owner = host as? Root, let child = built as? U {
      owner[keyPath: kp].add(child)
      return built
    }
    _ = Engine.onNextFrame {
      guard let owner = _findAncestor(startingAt: built, as: Root.self),
            let child = built as? U else { return }
      owner[keyPath: kp].add(child)
    }
    return built
  }
}

public extension GNode {
  func ref<Root: Node>(_ kp: KeyPath<Root, Ref<T>>) -> any GView {
    _BindRef(inner: self, kp: kp)
  }

  func ref<Root: Node>(into kp: KeyPath<Root, Refs<T>>) -> any GView {
    _BindRefs(inner: self, kp: kp)
  }
}
