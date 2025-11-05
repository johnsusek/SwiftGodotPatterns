//
//  GView.swift
//
//  Created by John Susek on 08/26/2025.
//

import SwiftGodot

/// A SwiftUI-inspired protocol for declaratively describing
/// Godot node hierarchies in Swift.
///
/// Conformers model *views* that ultimately materialize into a Godot
/// `Node` via ``toNode()``. Composition works similarly to SwiftUI:
/// a view either renders itself (a *leaf* view) or defers rendering to
/// its ``body`` (a *composite* view).
@_documentation(visibility: private)
public protocol GView {
  /// The declarative content of this view.
  ///
  /// Defaults to `NeverGView` for leaf views. If you provide a concrete
  /// `Body`, the default ``toNode()`` will delegate to `body.toNode()`.
  associatedtype Body: GView = NeverGView

  /// The view's body, used for composition.
  ///
  /// For leaf views (where `Body == NeverGView`) this property is provided
  /// by the protocol extension and traps if accessed.
  var body: Body { get }

  /// Materializes this view into a concrete Godot `Node`.
  ///
  /// - Returns: A fully constructed `Node` ready to be inserted in the tree.
  func toNode() -> Node

  /// Indicates whether this view's children should be flattened into the parent.
  ///
  /// When true, instead of adding this view's node as a child, the parent
  /// will call `toNodeWithParent()` passing itself as the parent.
  var shouldFlattenChildren: Bool { get }

  /// Materializes this view with a reference to its parent node.
  ///
  /// Only called when `shouldFlattenChildren` is true. The view can then
  /// add its children directly to the parent.
  func toNodeWithParent(_ parent: Node) -> Node?
}

public extension GView {
  /// Default implementation that delegates rendering to ``body``.
  ///
  /// Composite views typically rely on this; leaf views override it.
  ///
  /// - Returns: The node produced by `body.toNode()`.
  func toNode() -> Node { body.toNode() }

  /// Default implementation - views don't flatten by default.
  var shouldFlattenChildren: Bool { false }

  /// Default implementation - returns nil (node not used).
  func toNodeWithParent(_ parent: Node) -> Node? { nil }
}

@_documentation(visibility: private)
public extension GView where Body == NeverGView {
  /// Default `body` for leaf views.
  var body: NeverGView { NeverGView() }
}

/// A view used as the default `Body` for leaf `GView`s.
@_documentation(visibility: private)
public struct NeverGView: GView {
  /// Traps unconditionally - `NeverGView` should never be rendered.
  public func toNode() -> Node {
    GD.printErr("NeverGView should never render. Did you write `any GView` instead of `some GView`?")
    return Node()
  }
}

/// A result builder that collects `GView` children for container nodes.
@_documentation(visibility: private)
@resultBuilder
public enum NodeBuilder {
  /// Combines multiple child lists into a single flattened list.
  ///
  /// - Parameter c: Variadic groups of children.
  /// - Returns: A single flattened array of children.
  public static func buildBlock(_ c: [any GView]...) -> [any GView] { c.flatMap { $0 } }

  /// Flattens an array of child lists produced by loops/maps.
  ///
  /// - Parameter c: An array of child arrays.
  /// - Returns: A single flattened array of children.
  public static func buildArray(_ c: [[any GView]]) -> [any GView] { c.flatMap { $0 } }

  /// Passes through children when present, or yields an empty list.
  ///
  /// - Parameter c: Optional children.
  /// - Returns: `c` or `[]` if `nil`.
  public static func buildOptional(_ c: [any GView]?) -> [any GView] { c ?? [] }

  /// Chooses the `first` branch in `if/else` compositions.
  ///
  /// - Parameter first: Children from the first branch.
  /// - Returns: The provided children.
  public static func buildEither(first: [any GView]) -> [any GView] { first }

  /// Chooses the `second` branch in `if/else` compositions.
  ///
  /// - Parameter second: Children from the second branch.
  /// - Returns: The provided children.
  public static func buildEither(second: [any GView]) -> [any GView] { second }

  /// Lifts a single `GView` into a child list.
  ///
  /// - Parameter v: A child view.
  /// - Returns: A single-element child array.
  public static func buildExpression(_ v: any GView) -> [any GView] { [v] }

  /// Passes through an already-built child list (useful for `map`/loops).
  ///
  /// - Parameter v: A list of child views.
  /// - Returns: The same list.
  public static func buildExpression(_ v: [any GView]) -> [any GView] { v }
}
