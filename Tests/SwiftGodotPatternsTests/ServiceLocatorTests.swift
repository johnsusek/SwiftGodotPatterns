import Foundation
@testable import SwiftGodotPatterns
import Testing

@Suite("ServiceLocator Tests")
struct ServiceLocatorTests {
  @Test("ServiceLocator returns singleton per event type")
  func testSingletonBehavior() {
    enum UniqueEvent1 { case foo }

    let bus1 = ServiceLocator.resolve(UniqueEvent1.self)
    let bus2 = ServiceLocator.resolve(UniqueEvent1.self)

    // Should return the exact same instance
    #expect(bus1 === bus2, "ServiceLocator should return same instance for same event type")
  }

  @Test("ServiceLocator returns different buses for different types")
  func testDifferentTypesGetDifferentBuses() {
    enum UniqueEvent2a { case foo }
    enum UniqueEvent2b { case bar }

    let bus1 = ServiceLocator.resolve(UniqueEvent2a.self)
    let bus2 = ServiceLocator.resolve(UniqueEvent2b.self)

    // Different event types should get different buses
    var count1 = 0
    var count2 = 0

    let token1 = bus1.onEach { _ in count1 += 1 }
    let token2 = bus2.onEach { _ in count2 += 1 }

    bus1.publish(.foo)
    #expect(count1 == 1)
    #expect(count2 == 0)

    bus2.publish(.bar)
    #expect(count1 == 1)
    #expect(count2 == 1)

    bus1.cancel(token1)
    bus2.cancel(token2)
  }

  @Test("ServiceLocator is thread-safe")
  func testThreadSafety() async {
    enum UniqueEvent3 { case tick }

    // Access the same bus from multiple concurrent tasks
    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 10 {
        group.addTask {
          let bus = ServiceLocator.resolve(UniqueEvent3.self)
          var count = 0
          let token = bus.onEach { _ in count += 1 }
          bus.publish(.tick)
          #expect(count >= 1, "Task \(i) should receive at least one event")
          bus.cancel(token)
        }
      }
    }

    // Verify we still get the singleton after concurrent access
    let bus1 = ServiceLocator.resolve(UniqueEvent3.self)
    let bus2 = ServiceLocator.resolve(UniqueEvent3.self)
    #expect(bus1 === bus2)
  }

  @Test("ServiceLocator anyBus creates type-erased wrapper")
  func testAnyBus() {
    enum UniqueEvent4 { case foo }

    let anyBus = ServiceLocator.anyBus(UniqueEvent4.self)
    var receivedCount = 0

    let token = anyBus.onEach { event in
      if event is UniqueEvent4 {
        receivedCount += 1
      }
    }

    let typedBus = ServiceLocator.resolve(UniqueEvent4.self)
    typedBus.publish(.foo)

    #expect(receivedCount == 1)
    anyBus.cancel(token)
  }
}
