import Foundation
import SwiftGodot

/// A simple message logging singleton.
///
/// Thread-safe via internal NSLock.
public final class MsgLog: @unchecked Sendable {
  public enum Level: Int, Comparable, Sendable {
    case debug = 10
    case info = 20
    case warn = 30
    case error = 40

    public static func < (lhs: Level, rhs: Level) -> Bool {
      return lhs.rawValue < rhs.rawValue
    }
  }

  public static let shared = MsgLog()

  private let lock = NSLock()
  private var _minLevel: Level = .debug
  private var _sink: ((Level, String) -> Void)?
  private var _lines: [(level: Level, message: String)] = []
  private var _onAppend: ((Level, String) -> Void)?

  // The minimum level that will actually log (others drop)
  public var minLevel: Level {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _minLevel
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _minLevel = newValue
    }
  }

  // Custom sink closure; receives (level, message). If nil, uses default routing
  public var sink: ((Level, String) -> Void)? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _sink
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _sink = newValue
    }
  }

  public var lines: [(level: Level, message: String)] {
    lock.lock()
    defer { lock.unlock() }
    return _lines
  }

  public var onAppend: ((Level, String) -> Void)? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _onAppend
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _onAppend = newValue
    }
  }

  private init() {}

  public func write(_ message: String, level: Level = .info) {
    lock.lock()
    guard level >= _minLevel else {
      lock.unlock()
      return
    }
    _lines.append((level, message))
    let append = _onAppend
    let currentSink = _sink
    lock.unlock()

    append?(level, message)
    if let currentSink {
      currentSink(level, message)
    } else {
      defaultSink(level, message)
    }
  }

  private func defaultSink(_ level: Level, _ message: String) {
    switch level {
    case .debug, .info:
      GD.print("[\(level)] \(message)")
    case .warn:
      GD.pushWarning("[\(level)] \(message)")
    case .error:
      GD.pushError("[\(level)] \(message)")
    }
  }

  public func debug(_ msg: String) { write(msg, level: .debug) }
  public func info(_ msg: String) { write(msg, level: .info) }
  public func warn(_ msg: String) { write(msg, level: .warn) }
  public func error(_ msg: String) { write(msg, level: .error) }
}
