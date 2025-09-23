public final class MsgLog {
  public static let shared = MsgLog()
  private(set) var lines: [String] = []
  public var onAppend: ((String) -> Void)?
  private init() {}
  public func write(_ s: String) { lines.append(s); onAppend?(s) }
}
