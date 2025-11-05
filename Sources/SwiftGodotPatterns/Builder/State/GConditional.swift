//  Conditional rendering containers for SwiftGodot builder pattern.
//  Watches state and shows/hides or adds/removes children based on conditions.

import Foundation
import SwiftGodot

// MARK: - If Conditional Container

/// A conditional container that shows/hides or adds/removes children based on a boolean state.
///
/// ## Modes
///
/// - `.hide` (default): Toggles `visible` property. Fast, keeps nodes in tree and memory.
/// - `.remove`: Uses `addChild`/`removeChild`. Cleaner tree, keeps nodes in memory for reuse.
/// - `.destroy`: Uses `queueFree()`/rebuild. Frees memory, rebuilds nodes each time.
///
/// ## Usage
/// ```swift
/// // Hide/show mode (default - best for frequent toggling)
/// If($showDetails) {
///     DetailPanel$()
/// }
///
/// // Remove mode (cleaner tree, preserves node state)
/// If($isLoggedIn) {
///     UserProfile$()
/// }
/// .mode(.remove)
///
/// // Destroy mode (best for heavy resources like particles)
/// If($showBigExplosion) {
///     MassiveParticleSystem$()
/// }
/// .mode(.destroy)
///
/// // With Else
/// If($isLoggedIn) {
///     UserProfile$()
/// }
/// .Else {
///     LoginButton$()
/// }
/// ```
public struct If: GView {
    private let condition: GState<Bool>
    private let trueContent: [any GView]
    private let falseContent: [any GView]
    private var renderMode: Mode = .hide
    private var nodeName: String?

    /// Rendering mode for conditional content
    public enum Mode {
        /// Uses `visible` property - keeps nodes in tree, keeps nodes in memory
        /// Best for: Frequent toggling, lightweight nodes
        case hide

        /// Uses `addChild`/`removeChild` - cleaner tree, keeps nodes in memory
        /// Best for: Infrequent changes, when you want to preserve node state
        case remove

        /// Uses `addChild`/`queue_free()` - frees memory when hidden, rebuilds when shown
        /// Best for: Heavy resources (particles, 3D scenes), infrequent changes
        case destroy
    }

    /// Creates a conditional container
    /// - Parameters:
    ///   - condition: The boolean state to watch
    ///   - content: The content to show when condition is true
    public init(
        _ condition: GState<Bool>,
        @NodeBuilder content: () -> [any GView]
    ) {
        self.condition = condition
        trueContent = content()
        falseContent = []
    }

    // Private initializer for method chaining
    private init(
        condition: GState<Bool>,
        trueContent: [any GView],
        falseContent: [any GView],
        mode: Mode,
        name: String?
    ) {
        self.condition = condition
        self.trueContent = trueContent
        self.falseContent = falseContent
        renderMode = mode
        nodeName = name
    }

    /// Adds content to show when condition is false
    /// - Parameter content: The content to show when condition is false
    /// - Returns: A new If with the else content
    public func Else(@NodeBuilder content: () -> [any GView]) -> If {
        If(
            condition: condition,
            trueContent: trueContent,
            falseContent: content(),
            mode: renderMode,
            name: nodeName
        )
    }

    /// Sets the rendering mode
    /// - Parameter mode: `.hide` (show/hide) or `.remove` (add/remove from tree)
    /// - Returns: A new If with the specified mode
    public func mode(_ mode: Mode) -> If {
        If(
            condition: condition,
            trueContent: trueContent,
            falseContent: falseContent,
            mode: mode,
            name: nodeName
        )
    }

    /// Sets the name of the container node
    /// - Parameter name: The node name
    /// - Returns: A new If with the specified name
    public func name(_ name: String) -> If {
        If(
            condition: condition,
            trueContent: trueContent,
            falseContent: falseContent,
            mode: renderMode,
            name: name
        )
    }

    public var shouldFlattenChildren: Bool { true }

    public func toNodeWithParent(_ parent: Node) -> Node? {
        // For destroy mode, we need to track currently built nodes
        var currentTrueNodes: [Node]? = nil
        var currentFalseNodes: [Node]? = nil

        // For hide/remove modes, build nodes once and reuse
        if renderMode != .destroy {
            currentTrueNodes = trueContent.map { $0.toNode() }
            currentFalseNodes = falseContent.map { $0.toNode() }
        }

        // Use the parent directly instead of creating a wrapper container
        let container = parent

        // Watch state changes with throttling and warnings
        condition.onChange { [weak container] isTrue in
            guard let container = container else { return }

            switch renderMode {
            case .hide:
                guard let trueNodes = currentTrueNodes, let falseNodes = currentFalseNodes else { return }

                // Show/hide mode - keeps nodes in tree
                // On first run, add all nodes to the tree
                if container.getChildCount() == 0 {
                    for node in trueNodes + falseNodes {
                        container.addChild(node: node)
                    }
                }
                // Toggle visibility
                let activeNodes = isTrue ? trueNodes : falseNodes
                let inactiveNodes = isTrue ? falseNodes : trueNodes
                activeNodes.forEach { setNodeVisible($0, visible: true) }
                inactiveNodes.forEach { setNodeVisible($0, visible: false) }

            case .remove:
                guard let trueNodes = currentTrueNodes, let falseNodes = currentFalseNodes else { return }

                let activeNodes = isTrue ? trueNodes : falseNodes
                let inactiveNodes = isTrue ? falseNodes : trueNodes

                // Remove mode - cleaner tree, nodes stay in memory
                // Remove inactive nodes from tree
                for node in inactiveNodes {
                    if let parent = node.getParent() {
                        parent.removeChild(node: node)
                    }
                }
                // Add active nodes to tree
                for node in activeNodes {
                    if node.getParent() == nil {
                        container.addChild(node: node)
                    }
                }

            case .destroy:
                // Destroy mode - free memory when hidden, rebuild when shown

                // Free the inactive nodes
                if isTrue {
                    // Free false nodes if they exist
                    currentFalseNodes?.forEach { node in
                        if let parent = node.getParent() {
                            parent.removeChild(node: node)
                        }
                        node.queueFree()
                    }
                    currentFalseNodes = nil

                    // Build and add true nodes if needed
                    if currentTrueNodes == nil {
                        let newNodes = trueContent.map { $0.toNode() }
                        newNodes.forEach { container.addChild(node: $0) }
                        currentTrueNodes = newNodes
                    }
                } else {
                    // Free true nodes if they exist
                    currentTrueNodes?.forEach { node in
                        if let parent = node.getParent() {
                            parent.removeChild(node: node)
                        }
                        node.queueFree()
                    }
                    currentTrueNodes = nil

                    // Build and add false nodes if needed
                    if currentFalseNodes == nil {
                        let newNodes = falseContent.map { $0.toNode() }
                        newNodes.forEach { container.addChild(node: $0) }
                        currentFalseNodes = newNodes
                    }
                }
            }
        }

        return nil
    }

    public func toNode() -> Node {
        // This shouldn't be called when shouldFlattenChildren is true,
        // but provide a fallback implementation
        GD.printErr("If.toNode() called - should use toNodeWithParent() instead")
        return Node()
    }
}

// MARK: - Helper Functions

/// Creates the appropriate container type based on the children's types
/// - Parameter sampleNode: An already-built node to check the type of (optional)
/// - Returns: Container for Control nodes, Node2D for 2D nodes, Node3D for 3D nodes, or Node for others
private extension If {
    func createContainer(sampleNode: Node?) -> Node {
        guard let sampleNode = sampleNode else {
            // No sample available (e.g., destroy mode on first run or empty conditional)
            // Default to Container for UI compatibility
            return Container()
        }

        // Determine container type based on sample
        if sampleNode is Control {
            // UI nodes - use Container for proper layout
            return Container()
        } else if sampleNode is Node2D {
            // 2D game nodes - use Node2D
            return Node2D()
        } else if sampleNode is Node3D {
            // 3D game nodes - use Node3D
            return Node3D()
        } else {
            // Fallback to plain Node
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
        // Fallback: use process mode for nodes that don't support visible
        node.processMode = visible ? .inherit : .disabled
    }
}

// MARK: - Convenience Extensions

public extension If {
    /// Creates a conditional with hide mode (default - visible property toggle)
    /// - Parameters:
    ///   - condition: The boolean state to watch
    ///   - content: The content to show when condition is true
    /// - Returns: A conditional configured with hide mode
    static func hide(
        _ condition: GState<Bool>,
        @NodeBuilder content: () -> [any GView]
    ) -> If {
        If(condition, content: content).mode(.hide)
    }

    /// Creates a conditional with remove mode (addChild/removeChild)
    /// - Parameters:
    ///   - condition: The boolean state to watch
    ///   - content: The content to show when condition is true
    /// - Returns: A conditional configured with remove mode
    static func remove(
        _ condition: GState<Bool>,
        @NodeBuilder content: () -> [any GView]
    ) -> If {
        If(condition, content: content).mode(.remove)
    }

    /// Creates a conditional with destroy mode (queue_free/rebuild)
    /// - Parameters:
    ///   - condition: The boolean state to watch
    ///   - content: The content to show when condition is true
    /// - Returns: A conditional configured with destroy mode
    static func destroy(
        _ condition: GState<Bool>,
        @NodeBuilder content: () -> [any GView]
    ) -> If {
        If(condition, content: content).mode(.destroy)
    }
}
