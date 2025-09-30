import Foundation

/// Transforms intents into state mutations and outbound events.
///
/// `System` wraps an `apply` function suitable for unidirectional data flow:
/// given a list of `Intent`, it mutates `State` in-place and appends produced `Event`s to `out`.
///
/// - Type Parameters:
///   - State: The mutable state being updated.
///   - Intent: The input commands/intentions to apply.
///   - Event: The side-effect outputs produced during application.
///
/// ### Example
/// ```swift
/// struct Counter { var value = 0 }
/// enum Intent { case inc, dec }
/// enum Event { case clamped }
///
/// let system = System<Counter, Intent, Event> { intents, state, out in
///   for intent in intents {
///     switch intent {
///     case .inc: state.value += 1
///     case .dec: state.value -= 1
///     }
///   }
///   if state.value < 0 { state.value = 0; out.append(.clamped) }
/// }
/// ```
public struct System<State, Intent, Event> {
  /// The reducer: applies `intents` to `state`, appending any produced events to `out`.
  public let apply: (_ state: inout State, _ intents: [Intent], _ out: inout [Event]) -> Void

  /// Creates a new system with the provided reducer.
  ///
  /// - Parameter apply: Closure that mutates `state` for each intent and appends any emitted events to `out`.
  public init(_ apply: @escaping (inout State, [Intent], inout [Event]) -> Void) { self.apply = apply }
}
