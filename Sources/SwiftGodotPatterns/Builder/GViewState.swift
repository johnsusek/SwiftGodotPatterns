import SwiftGodot

// MARK: - Stateful Node Wrapper

/// Wraps a closure-based view that can access and respond to state
public struct GStatefulNode<Content: GView>: GView {
  private let builder: () -> Content

  public init(@NodeBuilder _ builder: @escaping () -> Content) {
    self.builder = builder
  }

  public func toNode() -> Node {
    builder().toNode()
  }
}

// MARK: - Reactive GView that rebuilds on state changes

public final class GReactiveView<V>: GView {
  private let state: GState<V>
  private let builder: (V) -> any GView
  private weak var rootNode: Node?

  public init(watching state: GState<V>, @NodeBuilder _ builder: @escaping (V) -> any GView) {
    self.state = state
    self.builder = builder
  }

  public func toNode() -> Node {
    let container = Node2D()
    rootNode = container

    // Initial render
    let initial = builder(state.wrappedValue).toNode()
    container.addChild(node: initial)

    // Listen for state changes and rebuild
    state.onChange { [weak container] value in
      guard let container else { return }

      // Remove old children
      for i in (0 ..< container.getChildCount()).reversed() {
        if let child = container.getChild(idx: Int32(i)) {
          container.removeChild(node: child)
          child.queueFree()
        }
      }

      // Rebuild with new state
      let newNode = self.builder(value).toNode()
      container.addChild(node: newNode)
    }

    return container
  }
}

// MARK: - State-driven conditional rendering

public struct GConditional<TrueContent: GView, FalseContent: GView>: GView {
  private let state: GState<Bool>
  private let trueBuilder: () -> TrueContent
  private let falseBuilder: () -> FalseContent

  public init(
    _ state: GState<Bool>,
    @NodeBuilder then trueBuilder: @escaping () -> TrueContent,
    @NodeBuilder else falseBuilder: @escaping () -> FalseContent
  ) {
    self.state = state
    self.trueBuilder = trueBuilder
    self.falseBuilder = falseBuilder
  }

  public func toNode() -> Node {
    let container = Node2D()

    let update = { [weak container] (value: Bool) in
      guard let container else { return }

      // Remove all children
      for i in (0 ..< container.getChildCount()).reversed() {
        if let child = container.getChild(idx: Int32(i)) {
          container.removeChild(node: child)
          child.queueFree()
        }
      }

      // Add appropriate child
      let newNode = value ? self.trueBuilder().toNode() : self.falseBuilder().toNode()
      container.addChild(node: newNode)
    }

    state.onChange(update)

    return container
  }
}

// MARK: - Empty GView for else cases

public struct GEmpty: GView {
  public init() {}

  public func toNode() -> Node {
    Node2D()
  }
}

// MARK: - Convenience constructors

public extension GView {
  static func reactive<V>(_ state: GState<V>, @NodeBuilder builder: @escaping (V) -> any GView) -> GReactiveView<V> {
    GReactiveView(watching: state, builder)
  }

  static func conditional(
    _ state: GState<Bool>,
    @NodeBuilder then: @escaping () -> some GView,
    @NodeBuilder else: @escaping () -> some GView = { GEmpty() }
  ) -> some GView {
    GConditional(state, then: then, else: `else`)
  }
}
