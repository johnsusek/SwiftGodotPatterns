/// A simple message log singleton.
///
/// You can append messages to it, and optionally set a closure to be called when a new
/// message is appended.
///
/// Usage:
/// ```swift
/// MsgLog.shared.write("A new message")
/// MsgLog.shared.onAppend = { newMessage in
///     GD.print("New log message: \(newMessage)")
/// }
/// ```
public final class MsgLog {
  public static let shared = MsgLog()

  private(set) var lines: [String] = []

  public var onAppend: ((String) -> Void)?

  private init() {}

  public func write(_ s: String) {
    lines.append(s)
    onAppend?(s)
  }
}
