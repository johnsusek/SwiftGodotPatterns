//  Reactive switch/case container for SwiftGodot builder pattern.
//  Watches state and renders different content based on the current value.

import Foundation
import SwiftGodot

// MARK: - Switch Container

/// A reactive switch container that renders different content based on a state value.
///
/// Similar to Swift's `switch` statement, this renders one of several possible
/// content blocks based on which `Case` matches the current state value.
///
/// ## Usage
/// ```swift
/// @State var currentPage = 0
///
/// Switch($currentPage) {
///   Case(0) {
///     Label$().text("Main Menu")
///     Button$().text("Start")
///   }
///   Case(1) {
///     Label$().text("Level Select")
///     Button$().text("Back")
///   }
///   Case(2) {
///     Label$().text("Settings")
///   }
/// }
/// .default {
///   Label$().text("Unknown page")
/// }
/// ```
///
/// ## Rendering Modes
///
/// Like `If`, `Switch` supports different rendering modes:
/// - `.hide` (default): Toggle visibility, keeps all nodes in tree
/// - `.remove`: Add/remove from tree, keeps nodes in memory
/// - `.destroy`: Free memory when hidden, rebuild when shown
///
/// ```swift
/// Switch($gameState)
///   .mode(.destroy)  // Good for heavy scenes
/// ```
public struct Switch<Value: Hashable>: GView {
  private let state: GState<Value>
  private let cases: [Case<Value>]
  private var defaultContent: [any GView]
  private var renderMode: If.Mode = .hide
  private var nodeName: String?

  /// Creates a switch container that renders content based on state value
  /// - Parameters:
  ///   - state: The state to watch
  ///   - cases: The cases to match against
  public init(
    _ state: GState<Value>,
    @CaseBuilder cases: () -> [Case<Value>]
  ) {
    self.state = state
    self.cases = cases()
    defaultContent = []
  }

  // Private initializer for method chaining
  private init(
    state: GState<Value>,
    cases: [Case<Value>],
    defaultContent: [any GView],
    mode: If.Mode,
    name: String?
  ) {
    self.state = state
    self.cases = cases
    self.defaultContent = defaultContent
    renderMode = mode
    nodeName = name
  }

  /// Adds default content to show when no case matches
  /// - Parameter content: The content to show when no case matches
  /// - Returns: A new Switch with the default content
  public func `default`(@NodeBuilder content: () -> [any GView]) -> Switch {
    Switch(
      state: state,
      cases: cases,
      defaultContent: content(),
      mode: renderMode,
      name: nodeName
    )
  }

  /// Sets the rendering mode
  /// - Parameter mode: `.hide` (show/hide), `.remove` (add/remove), or `.destroy` (free/rebuild)
  /// - Returns: A new Switch with the specified mode
  public func mode(_ mode: If.Mode) -> Switch {
    Switch(
      state: state,
      cases: cases,
      defaultContent: defaultContent,
      mode: mode,
      name: nodeName
    )
  }

  /// Sets the name of the container node
  /// - Parameter name: The node name
  /// - Returns: A new Switch with the specified name
  public func name(_ name: String) -> Switch {
    Switch(
      state: state,
      cases: cases,
      defaultContent: defaultContent,
      mode: renderMode,
      name: name
    )
  }

  public func toNode() -> Node {
    // Build a map of value -> nodes for each case
    var caseNodes: [Value: [Node]] = [:]
    var defaultNodes: [Node]? = nil

    // For destroy mode, we'll rebuild nodes each time, so don't pre-build
    if renderMode != .destroy {
      for caseItem in cases {
        caseNodes[caseItem.value] = caseItem.content.map { $0.toNode() }
      }
      if !defaultContent.isEmpty {
        defaultNodes = defaultContent.map { $0.toNode() }
      }
    }

    // Auto-detect container type from first case's first node
    let sampleNode = caseNodes.values.first?.first ?? defaultNodes?.first
    let container = createContainer(sampleNode: sampleNode)
    if let nodeName = nodeName {
      container.name = StringName(nodeName)
    }

    // Track which nodes are currently active (for destroy mode)
    var currentActiveNodes: [Node]? = nil

    // Watch state changes
    state.onChange { [weak container] value in
      guard let container = container else { return }

      // Find matching case
      let matchingCase = cases.first { $0.value == value }
      let activeNodes: [Node]?

      switch renderMode {
      case .hide:
        // For hide mode, all nodes are in tree, just toggle visibility
        if container.getChildCount() == 0 {
          // First run - add all nodes to tree
          for nodes in caseNodes.values {
            for node in nodes {
              container.addChild(node: node)
            }
          }
          if let defNodes = defaultNodes {
            for node in defNodes {
              container.addChild(node: node)
            }
          }
        }

        // Determine which nodes should be visible
        if let matchingCase = matchingCase {
          activeNodes = caseNodes[matchingCase.value]
        } else {
          activeNodes = defaultNodes
        }

        // Hide all nodes first
        for nodes in caseNodes.values {
          for node in nodes {
            setNodeVisible(node, visible: false)
          }
        }
        if let defNodes = defaultNodes {
          for node in defNodes {
            setNodeVisible(node, visible: false)
          }
        }

        // Show active nodes
        if let active = activeNodes {
          for node in active {
            setNodeVisible(node, visible: true)
          }
        }

      case .remove:
        // For remove mode, add/remove nodes from tree but keep in memory
        if let matchingCase = matchingCase {
          activeNodes = caseNodes[matchingCase.value]
        } else {
          activeNodes = defaultNodes
        }

        // Remove all nodes from tree
        for nodes in caseNodes.values {
          for node in nodes {
            if let parent = node.getParent() {
              parent.removeChild(node: node)
            }
          }
        }
        if let defNodes = defaultNodes {
          for node in defNodes {
            if let parent = node.getParent() {
              parent.removeChild(node: node)
            }
          }
        }

        // Add active nodes to tree
        if let active = activeNodes {
          for node in active {
            if node.getParent() == nil {
              container.addChild(node: node)
            }
          }
        }

      case .destroy:
        // For destroy mode, free inactive nodes and rebuild active ones
        // Free currently active nodes if they exist
        if let current = currentActiveNodes {
          for node in current {
            if let parent = node.getParent() {
              parent.removeChild(node: node)
            }
            node.queueFree()
          }
        }

        // Build and add new active nodes
        if let matchingCase = matchingCase {
          let newNodes = matchingCase.content.map { $0.toNode() }
          for node in newNodes {
            container.addChild(node: node)
          }
          currentActiveNodes = newNodes
        } else if !defaultContent.isEmpty {
          let newNodes = defaultContent.map { $0.toNode() }
          for node in newNodes {
            container.addChild(node: node)
          }
          currentActiveNodes = newNodes
        } else {
          currentActiveNodes = nil
        }
      }
    }

    return container
  }
}

// MARK: - Case

/// Represents a single case in a `Switch` statement.
///
/// ## Usage
/// ```swift
/// Case(0) {
///   Label$().text("Page Zero")
/// }
/// ```
public struct Case<Value: Hashable> {
  let value: Value
  let content: [any GView]

  /// Creates a case that matches a specific value
  /// - Parameters:
  ///   - value: The value to match
  ///   - content: The content to render when this case matches
  public init(_ value: Value, @NodeBuilder content: () -> [any GView]) {
    self.value = value
    self.content = content()
  }
}

// MARK: - Result Builder

@resultBuilder
public enum CaseBuilder {
  public static func buildBlock<Value>(_ cases: Case<Value>...) -> [Case<Value>] {
    cases
  }

  public static func buildArray<Value>(_ cases: [[Case<Value>]]) -> [Case<Value>] {
    cases.flatMap { $0 }
  }

  public static func buildOptional<Value>(_ cases: [Case<Value>]?) -> [Case<Value>] {
    cases ?? []
  }

  public static func buildEither<Value>(first: [Case<Value>]) -> [Case<Value>] {
    first
  }

  public static func buildEither<Value>(second: [Case<Value>]) -> [Case<Value>] {
    second
  }

  public static func buildExpression<Value>(_ caseItem: Case<Value>) -> [Case<Value>] {
    [caseItem]
  }
}

// MARK: - Helper Functions

private extension Switch {
  func createContainer(sampleNode: Node?) -> Node {
    guard let sampleNode = sampleNode else {
      return Container()
    }

    if sampleNode is Control {
      return Container()
    } else if sampleNode is Node2D {
      return Node2D()
    } else if sampleNode is Node3D {
      return Node3D()
    } else {
      return Node()
    }
  }
}

/// Sets the visibility of a node, handling different node types
private func setNodeVisible(_ node: Node, visible: Bool) {
  if let canvasItem = node as? CanvasItem {
    canvasItem.visible = visible
  } else if let node3D = node as? Node3D {
    node3D.visible = visible
  } else {
    node.processMode = visible ? .inherit : .disabled
  }
}
