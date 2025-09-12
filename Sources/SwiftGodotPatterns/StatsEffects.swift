public struct StatBlock {
  public var hp: Int; public var hpMax: Int
  public var atk: Int; public var def: Int
  public init(hp: Int, atk: Int, def: Int) { self.hp = hp; hpMax = hp; self.atk = atk; self.def = def }
  public mutating func heal(_ n: Int) { hp = min(hpMax, hp + max(0, n)) }
  public mutating func damage(_ n: Int) { hp = max(0, hp - max(0, n)) }
}

public protocol Effect {
  var id: String { get }
  var remaining: Int { get set }
  func modify(_ s: inout StatBlock)
}

public final class EffectBag {
  public private(set) var effects: [String: Effect] = [:]
  public init() {}
  public func add(_ e: Effect) { effects[e.id] = e }
  public func remove(_ id: String) { effects.removeValue(forKey: id) }
  public func tick() { for (k, var e) in effects {
    e.remaining -= 1; if e.remaining <= 0 { effects.removeValue(forKey: k) } else { effects[k] = e }
  } }
  public func apply(to s: inout StatBlock) { for e in effects.values {
    e.modify(&s)
  } }
}
