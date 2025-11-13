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
}
