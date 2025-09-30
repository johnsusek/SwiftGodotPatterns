// EventQueue.swift
import Atomics
import Foundation

/// Tiny bounded SPSC event queue (power-of-two capacity). Pump it each frame.
public final class EventQueue<Element> {
  private let capacity: Int
  private let mask: Int
  private let storage: UnsafeMutableBufferPointer<Element?>

  private let head: ManagedAtomic<Int>
  private let tail: ManagedAtomic<Int>

  public init(capacity: Int) {
    let cap = Self.nextPow2(max(2, capacity))
    self.capacity = cap
    mask = cap &- 1
    let ptr = UnsafeMutablePointer<Element?>.allocate(capacity: cap)
    ptr.initialize(repeating: nil, count: cap)
    storage = .init(start: ptr, count: cap)
    head = .init(0)
    tail = .init(0)
  }

  deinit {
    // Release any remaining elements.
    var index = 0
    while index < capacity {
      storage[index] = nil; index += 1
    }
    storage.baseAddress?.deinitialize(count: capacity)
    storage.baseAddress?.deallocate()
  }

  public var approximateCount: Int {
    let h = head.load(ordering: .relaxed)
    let t = tail.load(ordering: .relaxed)
    return max(0, t &- h)
  }

  public var isEmpty: Bool { approximateCount == 0 }
  public var isFull: Bool { approximateCount >= capacity }

  /// Enqueue one element. Returns false if the ring is full.
  @discardableResult
  public func enqueue(_ element: Element) -> Bool {
    let t = tail.load(ordering: .relaxed)
    let h = head.load(ordering: .acquiring)
    if t &- h >= capacity { return false }
    storage[t & mask] = element
    tail.store(t &+ 1, ordering: .releasing)
    return true
  }

  /// Dequeue one element; nil if empty.
  public func dequeue() -> Element? {
    let h = head.load(ordering: .relaxed)
    let t = tail.load(ordering: .acquiring)
    if h == t { return nil }
    let idx = h & mask
    let value = storage[idx]
    storage[idx] = nil
    head.store(h &+ 1, ordering: .releasing)
    return value
  }

  /// Drain up to `budget` events into `handler`. Returns number drained.
  @discardableResult
  public func pump(budget: Int = .max, _ handler: (Element) -> Void) -> Int {
    var processed = 0
    while processed < budget, let ev = dequeue() {
      handler(ev)
      processed &+= 1
    }
    return processed
  }

  /// Try to enqueue a sequence; stops on first full. Returns enqueued count.
  @discardableResult
  public func enqueueMany<S: Sequence>(_ elements: S) -> Int where S.Element == Element {
    var count = 0
    for element in elements {
      if !enqueue(element) { break }
      count &+= 1
    }
    return count
  }

  private static func nextPow2(_ n: Int) -> Int {
    var v = n &- 1
    v |= v >> 1; v |= v >> 2; v |= v >> 4
    v |= v >> 8; v |= v >> 16
    #if arch(x86_64) || arch(arm64)
      v |= v >> 32
    #endif
    return v &+ 1
  }
}
