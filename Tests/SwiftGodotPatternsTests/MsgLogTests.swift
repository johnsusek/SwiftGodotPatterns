import Foundation
@testable import SwiftGodotPatterns
import Testing

@Suite("MsgLog Tests")
struct MsgLogTests {
  @Test("MsgLog filters messages by level")
  func testLevelFiltering() {
    let log = MsgLog.shared
    let originalLevel = log.minLevel
    defer { log.minLevel = originalLevel } // Restore after test

    var capturedMessages: [(MsgLog.Level, String)] = []
    let originalSink = log.sink
    defer { log.sink = originalSink }

    log.sink = { level, message in
      capturedMessages.append((level, message))
    }

    log.minLevel = .warn

    log.debug("debug message")
    log.info("info message")
    log.warn("warn message")
    log.error("error message")

    #expect(capturedMessages.count == 2)
    #expect(capturedMessages[0].0 == .warn)
    #expect(capturedMessages[1].0 == .error)
  }

  @Test("MsgLog onAppend callback is invoked")
  func testOnAppendCallback() {
    let log = MsgLog.shared
    let originalSink = log.sink
    let originalOnAppend = log.onAppend
    let originalLevel = log.minLevel
    defer {
      log.sink = originalSink
      log.onAppend = originalOnAppend
      log.minLevel = originalLevel
    }

    log.minLevel = .debug
    log.sink = { _, _ in } // Silent sink

    var appendCount = 0
    log.onAppend = { _, _ in
      appendCount += 1
    }

    log.write("test", level: .info)
    #expect(appendCount == 1)

    log.write("test2", level: .warn)
    #expect(appendCount == 2)
  }

  @Test("MsgLog custom sink overrides default")
  func testCustomSink() {
    let log = MsgLog.shared
    let originalSink = log.sink
    let originalLevel = log.minLevel
    defer {
      log.sink = originalSink
      log.minLevel = originalLevel
    }

    log.minLevel = .debug

    var customSinkCalled = false
    log.sink = { level, message in
      customSinkCalled = true
      #expect(level == .info)
      #expect(message == "custom test")
    }

    log.write("custom test", level: .info)
    #expect(customSinkCalled)
  }
}
