@testable import SwiftGodotPatterns
import Testing

@Suite("EventBus Tests")
struct EventBusTests {
  enum TestEvent {
    case ping(String)
    case pong
  }

  @Test("EventBus publishes events to subscribers")
  func testBasicPublishSubscribe() {
    let bus = EventBus<TestEvent>()
    var receivedEvents: [TestEvent] = []

    let token = bus.onEach { event in
      receivedEvents.append(event)
    }

    bus.publish(.ping("hello"))
    bus.publish(.pong)
    bus.publish(.ping("world"))

    #expect(receivedEvents.count == 3)

    // Verify the events are in the correct order
    if case let .ping(msg1) = receivedEvents[0] {
      #expect(msg1 == "hello")
    } else {
      Issue.record("Expected ping(\"hello\") as first event")
    }

    if case .pong = receivedEvents[1] {
      // Success
    } else {
      Issue.record("Expected pong as second event")
    }

    if case let .ping(msg2) = receivedEvents[2] {
      #expect(msg2 == "world")
    } else {
      Issue.record("Expected ping(\"world\") as third event")
    }

    bus.cancel(token)
  }

  @Test("EventBus cancel removes subscriber")
  func testCancelRemovesSubscriber() {
    let bus = EventBus<TestEvent>()
    var receivedCount = 0

    let token = bus.onEach { _ in
      receivedCount += 1
    }

    bus.publish(.ping("first"))
    #expect(receivedCount == 1)

    bus.cancel(token)

    bus.publish(.ping("second"))
    #expect(receivedCount == 1, "Count should still be 1 after cancellation")
  }

  @Test("EventBus supports multiple subscribers")
  func testMultipleSubscribers() {
    let bus = EventBus<TestEvent>()
    var count1 = 0
    var count2 = 0

    let token1 = bus.onEach { _ in count1 += 1 }
    let token2 = bus.onEach { _ in count2 += 1 }

    bus.publish(.pong)

    #expect(count1 == 1)
    #expect(count2 == 1)

    bus.cancel(token1)
    bus.publish(.pong)

    #expect(count1 == 1, "First subscriber should not receive event after cancellation")
    #expect(count2 == 2, "Second subscriber should still receive events")

    bus.cancel(token2)
  }
}
