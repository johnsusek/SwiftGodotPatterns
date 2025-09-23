/// A single, timed phase in a sequence executed by ``PhaseRunner``.
///
/// `PhaseSpec` pairs a domain-specific `Kind` (often an enum)
/// with a duration in seconds. Use it to describe the schedule
/// the runner should execute, e.g. `.startup(0.1)`, `.active(0.3)`, `.recovery(0.2)`.
///
/// ```swift
/// enum AttackPhase { case telegraph, swing, cooldown }
/// let script: [PhaseSpec<AttackPhase>] = [
///   .init(.telegraph, 0.15),
///   .init(.swing, 0.25),
///   .init(.cooldown, 0.40),
/// ]
/// ```
///
/// - Note: `Kind` must be `Hashable` to encourage use of enums or small value types.
public struct PhaseSpec<Kind: Hashable> {
  /// The domain-specific identifier for this phase.
  public let kind: Kind
  /// The duration of this phase, in seconds. Must be non-negative.
  public let duration: Double

  /// Creates a phase with the given kind and duration.
  /// - Parameters:
  ///   - kind: Domain-specific label for the phase.
  ///   - duration: Duration in seconds. Negative values are treated as elapsed immediately by the runner.
  public init(_ kind: Kind, _ duration: Double) { self.kind = kind; self.duration = duration }
}

/// Executes a deterministic sequence of timed phases, advancing via ``tick(_:)``.
///
/// `PhaseRunner` is a lightweight, frame-agnostic state machine. You describe
/// a sequence with an array of ``PhaseSpec`` values and call ``begin(_:)``.
/// Each call to ``tick(_:)`` advances time; transitions trigger the `onEnter`,
/// `onExit`, and `onFinish` callbacks synchronously during the call.
///
/// ### Design notes
/// - One boundary per tick: a single call to ``tick(_:)`` will advance at most
///   one phase boundary. Any overshoot is discarded; `t` starts at `0` for the next phase.
/// - Callbacks are synchronous: they run during `begin`, `tick`, or `cancel`.
/// - Not thread-safe: mutate and tick from one execution context (e.g. the game loop).
///
/// ### Example
/// ```swift
/// let runner = PhaseRunner<StandardPhase>()
/// runner.onEnter  = { print("→ \($0)") }
/// runner.onExit   = { print("← \($0)") }
/// runner.onFinish = { print("✔ finished") }
/// runner.begin([.startup(0.1), .active(0.3), .recovery(0.2)])
///
/// // 60 FPS loop
/// for _ in 0..<60 { runner.tick(1.0 / 60.0) }
/// ```
///
/// - SeeAlso: ``PhaseSpec``, ``StandardPhase``.
public final class PhaseRunner<Kind: Hashable> {
  /// The execution state of the runner.
  public enum State {
    /// No sequence is active.
    case idle
    /// A sequence is active.
    /// - Parameters:
    ///   - kind: The current phase kind.
    ///   - t: Elapsed time in the current phase (seconds).
    ///   - index: Index into the phases array.
    case running(kind: Kind, t: Double, index: Int)
  }

  /// The current state of the runner.
  public private(set) var state: State = .idle

  private var phases: [PhaseSpec<Kind>] = []

  /// Called when the runner *enters* a phase (including the first phase of `begin`).
  /// Invoked synchronously within `begin` or `tick`.
  public var onEnter: ((Kind) -> Void)?

  /// Called when the runner *exits* a phase (including when `cancel` is called while running).
  /// Invoked synchronously within `tick` or `cancel`.
  public var onExit: ((Kind) -> Void)?

  /// Called when the final phase completes and the runner returns to `idle`.
  /// Invoked synchronously within `tick` after the last exit.
  public var onFinish: (() -> Void)?

  /// Creates an idle runner.
  public init() {}

  /// Whether the runner is currently executing a sequence.
  public var busy: Bool { if case .running = state { return true }; return false }

  /// The kind of the current phase, or `nil` when idle.
  public var current: Kind? { if case let .running(k, _, _) = state { return k }; return nil }

  /// Starts executing a new sequence of phases from the first element.
  ///
  /// - Important: This *replaces* any in-flight sequence **without** firing `onExit`
  ///   for the old phase. To fire `onExit` for the current phase, call ``cancel()`` first.
  ///
  /// - Parameter phases: The ordered phases to run. If empty, the call is ignored.
  public func begin(_ phases: [PhaseSpec<Kind>]) {
    if phases.isEmpty { return }
    self.phases = phases
    state = .running(kind: phases[0].kind, t: 0, index: 0)
    onEnter?(phases[0].kind)
  }

  /// Cancels the active sequence (if any), firing `onExit` for the current phase, and returns to `idle`.
  public func cancel() {
    if case let .running(k, _, _) = state { onExit?(k) }
    phases.removeAll(); state = .idle
  }

  /// Advances time and performs phase transitions as needed.
  ///
  /// A single call will cross at most one boundary. If `dt` causes `t` to meet or exceed
  /// the current phase duration, `onExit` is fired, the next phase (if any) is entered
  /// with `t == 0` and `onEnter` is fired. If there is no next phase, the runner becomes
  /// idle and `onFinish` is fired.
  ///
  /// - Parameter dt: Delta time in seconds. Pass non-negative values.
  /// - Complexity: O(1).
  public func tick(_ dt: Double) {
    guard case var .running(kind, t, i) = state else { return }
    t += dt
    let d = phases[i].duration
    if t < d { state = .running(kind: kind, t: t, index: i); return }
    onExit?(kind)
    let next = i + 1
    if next >= phases.count { state = .idle; phases.removeAll(); onFinish?(); return }
    let nk = phases[next].kind
    state = .running(kind: nk, t: 0, index: next)
    onEnter?(nk)
  }
}

/// A tiny convenience enum for fighting-game style phases: startup → active → recovery.
public enum StandardPhase { case startup, active, recovery }

public extension PhaseSpec where Kind == StandardPhase {
  /// Creates a `.startup` phase with the given duration (seconds).
  static func startup(_ s: Double) -> Self { .init(.startup, s) }
  /// Creates an `.active` phase with the given duration (seconds).
  static func active(_ s: Double) -> Self { .init(.active, s) }
  /// Creates a `.recovery` phase with the given duration (seconds).
  static func recovery(_ s: Double) -> Self { .init(.recovery, s) }
}
