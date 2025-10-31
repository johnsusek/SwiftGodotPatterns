import SwiftGodot

/// Register multiple types with Godot.
/// - Parameter types: An array of types to register.
/// ### Usage:
/// ```swift
/// register(types: [MyNode.self, MyOtherNode.self])
/// ```
/// Replaces:
/// ```swift
/// register(type: MyNode.self)
/// register(type: MyOtherNode.self)
/// ```
public func register(types: [Object.Type]) {
  for t in types {
    register(type: t)
  }
}

// MARK: Sendable conformances

// extension NodePath: @retroactive @unchecked Sendable {
//   public func toSendable() -> String { description }
//   public static func fromSendable(_ value: String) -> NodePath { NodePath(value) }
// }
