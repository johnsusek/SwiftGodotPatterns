import SwiftGodot

/// An optional pair of lifecycle hooks for pooled objects.
///
/// Types placed in an `Pool` can conform to `PooledObject` to receive
/// hook calls during pooling:
/// - `onRelease()` is invoked **by the pool** whenever an object is returned
///   to the pool (and also right after creation to normalize the initial state).
/// - `onAcquire()` is a convenience hook you may choose to call yourself after
///   `acquire()` returns (this pool does **not** invoke it automatically).
///
/// Conformance is optional
// default implementations are no-ops.
public protocol PooledObject: AnyObject {
  /// Prepare the object for active use (e.g., make visible, enable physics).
  func onAcquire()

  /// Reset the object for reuse (e.g., hide, stop motion, clear timers).
  func onRelease()
}

/// Default no-op hooks so conformance is opt-in and low-friction.
public extension PooledObject {
  func onAcquire() {}
  func onRelease() {}
}

/// An object pool for Godot `Object` subclasses (e.g., `Node`).
///
/// The pool can produce instances in two ways:
/// 1. From a `PackedScene` via `instantiate()`
/// 2. From a custom `factory` closure
///
/// You can supply either (or both). When both are present, `scene` is preferred.
/// New instances are normalized by calling `onRelease()` immediately after
/// creation so they enter the pool in a reset state.
///
/// ### Example
/// ```swift
/// final class Bullet: Node2D, PooledObject {
///   func onAcquire() { visible = true }
///   func onRelease() { visible = false
// position = .zero }
/// }
///
/// let pool = Pool<Bullet>(factory: { Bullet() })
/// pool.preload(64)
///
/// if let b = pool.acquire() {
///   b.onAcquire()
///   // configure and add to scene...
///   // later:
///   pool.release(b)
/// }
/// ```
public final class ObjectPool<T: Object> {
  /// Optional scene used to instantiate pooled instances.
  ///
  /// When non-`nil`, this is the preferred source of new objects.
  public var scene: PackedScene?

  /// Optional closure to create new instances when needed.
  ///
  /// Used when `scene` is `nil` or instantiation fails.
  public var factory: (() -> T)?

  /// Maximum number of instances to retain in the pool.
  public var max: Int = .max

  /// Internal storage of free instances.
  private var free: [T] = []

  /// Creates a new object pool.
  public init(scene: PackedScene? = nil, factory: (() -> T)? = nil, max: Int = .max) {
    self.scene = scene
    self.factory = factory
    self.max = max
  }

  /// Eagerly creates and stores up to `count` instances.
  ///
  /// New instances (from `scene` or `factory`) are normalized by calling
  /// `onRelease()` before being placed in the pool.
  public func preload(_ n: Int) {
    for _ in 0 ..< Swift.max(0, n) where free.count < max {
      if let o = make() { free.append(o) }
    }
  }

  /// Creates a new instance from the `scene` or `factory`.
  private func make() -> T? {
    if let s = scene, let o = s.instantiate() as? T {
      (o as? PooledObject)?.onRelease()
      return o
    }

    if let f = factory { let o = f()
      (o as? PooledObject)?.onRelease()
      return o
    }
    return nil
  }

  /// Retrieves an instance from the pool or creates one on demand.
  ///
  /// Note: This method does **not** call `onAcquire()`
  // call it yourself if
  /// your type uses that hook.
  public func acquire() -> T? {
    let o = free.popLast() ?? make()
    (o as? PooledObject)?.onAcquire()
    return o
  }

  /// Returns an instance to the pool for reuse.
  ///
  /// Calls `onRelease()` on `PooledObject` conformers, then appends to the free list.
  public func release(_ o: T) {
    (o as? PooledObject)?.onRelease()
    if let node = o as? Node, let p = node.getParent() { p.removeChild(node: node) }
    if free.count < max { free.append(o) } else { (o as? Node)?.queueFree() }
  }
}

/// A convenience wrapper to use a pooled object within a closure.
///
/// ### Usage:
/// ```swift
/// let pool = Pool<Bullet>(factory: { Bullet() })
/// pool.preload(64)
///
/// PoolLease(pool).using { b in
///   b.onAcquire()
///   // configure and add to scene...
/// }
/// ```
public struct PoolLease<T: Object> {
  /// The underlying pool.
  private let pool: ObjectPool<T>

  /// Creates a scope for the given pool.
  public init(_ p: ObjectPool<T>) { pool = p }

  /// Acquires an object from the pool, invokes the closure, then releases it.
  public func using(_ body: (T) -> Void) {
    guard let o = pool.acquire() else { return }
    body(o)
    pool.release(o)
  }
}
