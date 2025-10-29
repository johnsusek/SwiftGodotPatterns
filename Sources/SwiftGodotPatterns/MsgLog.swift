import SwiftGodot

/// A simple message logging singleton.
public final class MsgLog {
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

  // The minimum level that will actually log (others drop)
  public var minLevel: Level = .debug

  // Custom sink closure; receives (level, message). If nil, uses default routing
  public var sink: ((Level, String) -> Void)?

  private(set) var lines: [(level: Level, message: String)] = []
  public var onAppend: ((Level, String) -> Void)?

  private init() {}

  public func write(_ message: String, level: Level = .info) {
    guard level >= minLevel else { return }
    lines.append((level, message))
    onAppend?(level, message)
    if let sink = sink {
      sink(level, message)
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
