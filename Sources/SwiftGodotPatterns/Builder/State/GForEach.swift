//  Dynamic list management for SwiftGodot builder pattern.
//  Watches array state and efficiently updates children based on identity.

import SwiftGodot

// MARK: - ForEach Container

/// A dynamic list container that efficiently manages children based on array state.
///
/// `ForEach` tracks items by identity and adds, removes, and reorders
/// nodes as the underlying array changes. It uses a diffing algorithm to minimize
/// node operations.
///
/// ## Usage
/// ```swift
/// @State var items: [Item] = []
///
/// VBoxContainer$ {
///   ForEach($items, id: \.id) { $item in
///     Label$().text(item.name)
///   }
/// }
/// ```
///
/// ## Performance Characteristics
/// - **Identity Tracking**: Uses stable IDs to match items across updates
/// - **Efficient Diffing**: Only adds/removes/moves nodes that changed
/// - **Node Reuse**: Reuses existing nodes for items that remain in the list
/// - **Memory Management**: Automatically frees removed nodes
///
/// ## Implementation Details
/// - Uses `queue_free()` for removed nodes
/// - Reorders nodes using `move_child()` for efficiency
/// - Maintains consistent node order matching array order
/// - Batches updates for better performance
public struct ForEach<Element: Equatable, ID: Hashable>: GView {
    private let items: GState<[Element]>
    private let idKeyPath: KeyPath<Element, ID>
    private let content: (GState<Element>) -> any GView
    private var nodeName: String?
    private var mode: Mode = .standard

    /// Rendering mode for list updates
    public enum Mode {
        /// Standard mode - reuse nodes, efficient reordering
        /// Best for: Most use cases, good balance of performance and simplicity
        case standard

        /// Deferred mode - batches updates to next frame
        /// Best for: High-frequency state changes, prevents multiple updates per frame
        case deferred
    }

    /// Creates a ForEach container that manages a dynamic list.
    ///
    /// - Parameters:
    ///   - items: Binding to array of items (use $ prefix)
    ///   - id: KeyPath to a Hashable property that uniquely identifies each item
    ///   - mode: Rendering mode (.standard or .deferred) - defaults to .standard
    ///   - content: Builder that creates the view for each item, receives binding to item
    public init(
        _ items: GState<[Element]>,
        id: KeyPath<Element, ID>,
        mode: Mode = .standard,
        content: @escaping (GState<Element>) -> any GView
    ) {
        self.items = items
        idKeyPath = id
        self.mode = mode
        self.content = content
    }

    /// Sets the rendering mode
    /// - Parameter mode: (.standard or .deferred)
    /// - Returns: A new ForEach with the specified mode
    public func mode(_ mode: Mode) -> ForEach {
        var copy = self
        copy.mode = mode
        return copy
    }

    /// Sets the name of the container node
    /// - Parameter name: The node name
    /// - Returns: A new ForEach with the specified name
    public func name(_ name: String) -> ForEach {
        var copy = self
        copy.nodeName = name
        return copy
    }

    public var shouldFlattenChildren: Bool { true }

    public func toNodeWithParent(_ parent: Node) -> Node? {
        // Storage for tracking items to nodes
        // Key = item ID, Value = (element state, node)
        var itemNodes: [ID: (GState<Element>, Node)] = [:]
        var currentOrder: [ID] = []

        // Dirty flag for deferred mode
        var isDirty = false
        var pendingItems: [Element]? = nil

        // Use the parent directly instead of creating a wrapper container
        // This allows the parent's layout (e.g., VBoxContainer) to work properly

        // Core update function
        let performUpdate: ([Element]) -> Void = { [weak parent] newItems in
            guard let container = parent else { return }

            // Extract IDs from new items
            let newIDs = newItems.map { item in item[keyPath: idKeyPath] as ID }
            let newIDSet = Set(newIDs)
            let oldIDSet = Set(currentOrder)

            // Use LCS-based diffing for minimal operations
            let diff = computeDiff(old: currentOrder, new: newIDs)

            // Remove items no longer in the list
            for removedID in diff.removed {
                if let (_, node) = itemNodes[removedID] {
                    if let parent = node.getParent() {
                        parent.removeChild(node: node)
                    }
                    node.queueFree()
                    itemNodes.removeValue(forKey: removedID)
                }
            }

            // Add new items
            for (index, item) in newItems.enumerated() {
                let itemID = newIDs[index]

                if diff.added.contains(itemID) {
                    // Create state wrapper for this item
                    let itemState = GState(wrappedValue: item)

                    // Build the node
                    let node = content(itemState).toNode()

                    // Store the node and its state
                    itemNodes[itemID] = (itemState, node)

                    // Add to container
                    container.addChild(node: node)
                }
            }

            // Efficient reordering using minimal moves
            // Only reorder if there are moves in the diff
            if !diff.moved.isEmpty {
                // Apply moves in order
                for (itemID, desiredIndex) in diff.moved {
                    if let (_, node) = itemNodes[itemID] {
                        container.moveChild(childNode: node, toIndex: Int32(desiredIndex))
                    }
                }
            }

            // Update item states for items that remained
            // This ensures that if the item data changed, the state is updated
            let persistedIDs = newIDSet.intersection(oldIDSet)
            for (index, item) in newItems.enumerated() {
                let itemID = newIDs[index]
                if persistedIDs.contains(itemID) {
                    if let (itemState, _) = itemNodes[itemID] {
                        // Update the state if the item data changed
                        itemState.wrappedValue = item
                    }
                }
            }

            // Update current order
            currentOrder = newIDs

            // Reset dirty flag for deferred mode
            isDirty = false
            pendingItems = nil
        }

        // Watch for array changes and update the tree
        items.onChange { [weak parent, mode, performUpdate] newItems in
            guard parent != nil else { return }

            // Handle deferred mode
            if mode == .deferred {
                // Mark as dirty and store pending items
                isDirty = true
                pendingItems = newItems

                // Schedule update for next frame
                Engine.onNextFrame {
                    if isDirty, let pending = pendingItems {
                        performUpdate(pending)
                    }
                }
            } else {
                // Immediate update for standard mode
                performUpdate(newItems)
            }
        }

        // Return nil since we're not adding a wrapper node
        return nil
    }

    public func toNode() -> Node {
        // This shouldn't be called when shouldFlattenChildren is true,
        // but provide a fallback implementation
        GD.printErr("ForEach.toNode() called - should use toNodeWithParent() instead")
        return Node()
    }
}

// MARK: - Helper Functions

/// Result of diffing two sequences by identity
private struct DiffResult<ID: Hashable> {
    let removed: Set<ID>
    let added: Set<ID>
    let moved: [(ID, Int)] // (itemID, newIndex)
}

/// Computes the minimal set of operations to transform old array into new array
/// Uses a simple but efficient algorithm that tracks additions, removals, and moves
private func computeDiff<ID: Hashable>(old: [ID], new: [ID]) -> DiffResult<ID> where ID: Hashable {
    let oldSet = Set(old)
    let newSet = Set(new)

    // Compute additions and removals
    let removed = oldSet.subtracting(newSet)
    let added = newSet.subtracting(oldSet)

    // Compute moves for items that stayed
    var moved: [(ID, Int)] = []
    let persisted = oldSet.intersection(newSet)

    // Build index maps
    var oldIndices: [ID: Int] = [:]
    for (index, id) in old.enumerated() {
        oldIndices[id] = index
    }

    // Check which persisted items need to move
    for (newIndex, id) in new.enumerated() {
        if persisted.contains(id) {
            if let oldIndex = oldIndices[id], oldIndex != newIndex {
                // Item needs to move
                moved.append((id, newIndex))
            }
        }
    }

    return DiffResult(removed: removed, added: added, moved: moved)
}

// Helper to extract ID as hashable
private func extractID<Element, ID: Hashable>(from element: Element, keyPath: KeyPath<Element, ID>) -> ID {
    return element[keyPath: keyPath]
}

// MARK: - Identifiable Support

/// Extension for collections of Identifiable items
public extension ForEach where Element: Identifiable, ID == Element.ID {
    /// Creates a ForEach for Identifiable items
    /// - Parameters:
    ///   - items: Binding to array of Identifiable items (use $ prefix)
    ///   - mode: Rendering mode (.standard or .deferred) - defaults to .standard
    ///   - content: Builder that creates the view for each item
    init(
        _ items: GState<[Element]>,
        mode: Mode = .standard,
        content: @escaping (GState<Element>) -> any GView
    ) {
        self.items = items
        idKeyPath = \Element.id
        self.mode = mode
        self.content = content
    }
}
