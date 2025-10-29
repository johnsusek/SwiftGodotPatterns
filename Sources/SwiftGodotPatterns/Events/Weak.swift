import SwiftGodot

public struct Weak<T: AnyObject> {
  public weak var value: T?
  public init(_ v: T?) { value = v }
}
