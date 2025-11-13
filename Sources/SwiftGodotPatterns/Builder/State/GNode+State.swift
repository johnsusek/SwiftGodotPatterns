import SwiftGodot

// MARK: - Dynamic State Binding via subscript

public extension GNode {
  /// Dynamic member lookup for GState binding
  /// Usage: .position($myState) or .scale($myScale)
  subscript<V>(dynamicMember kp: ReferenceWritableKeyPath<T, V>) -> (GState<V>) -> Self {
    { state in
      var s = self
      s.ops.append { node in
        state.onChange { value in
          node[keyPath: kp] = value
        }
      }
      return s
    }
  }

  /// Dynamic member lookup for GState with transform to StringName
  subscript(dynamicMember kp: ReferenceWritableKeyPath<T, StringName>) -> (GState<String>) -> Self {
    { state in
      var s = self
      s.ops.append { node in
        state.onChange { value in
          node[keyPath: kp] = StringName(value)
        }
      }
      return s
    }
  }

  /// Dynamic member lookup for GState with RawRepresentable enum
  subscript<E>(dynamicMember kp: ReferenceWritableKeyPath<T, E>) -> (GState<E.RawValue>) -> Self where E: RawRepresentable {
    { state in
      var s = self
      s.ops.append { node in
        state.onChange { raw in
          guard let e = E(rawValue: raw) else {
            GD.printErr("⚠️ Invalid rawValue for \(E.self):", raw)
            return
          }
          node[keyPath: kp] = e
        }
      }
      return s
    }
  }
}

// MARK: - State Binding Extensions for GNode

public extension GNode {
  /// Bind a GState to a keyPath, updating the node property whenever state changes
  /// Usage: .bind(\.position, to: $position)
  func bind<V>(_ kp: ReferenceWritableKeyPath<T, V>, to state: GState<V>) -> Self {
    var s = self
    s.ops.append { node in
      state.onChange { value in
        node[keyPath: kp] = value
      }
    }
    return s
  }

  /// Bind a GState with a transformation function
  /// Usage: .bind(\.text, to: $position) { "\($0.x), \($0.y)" }
  func bind<V, U>(_ kp: ReferenceWritableKeyPath<T, U>, to state: GState<V>, transform: @escaping (V) -> U) -> Self {
    var s = self
    s.ops.append { node in
      state.onChange { value in
        node[keyPath: kp] = transform(value)
      }
    }
    return s
  }

  /// Bind a sub-property of a GState to a node property
  /// Usage: .bind(\.width, to: $myState, \.x)
  func bind<V, U>(_ kp: ReferenceWritableKeyPath<T, U>, to state: GState<V>, _ sourceKeyPath: KeyPath<V, U>) -> Self {
    var s = self
    s.ops.append { node in
      state.onChange { value in
        node[keyPath: kp] = value[keyPath: sourceKeyPath]
      }
    }
    return s
  }

  /// Update node when state changes using a custom closure
  /// Usage: .watch($myState) { node, value in ... }
  func watch<V>(_ state: GState<V>, _ handler: @escaping (T, V) -> Void) -> Self {
    var s = self
    s.ops.append { node in
      state.onChange { value in
        handler(node, value)
      }
    }
    return s
  }
}

// MARK: - Multi-State Binding Extensions

public extension GNode {
  /// Bind two GStates with a transformation function
  /// Usage: .bind(\.text, to: $message, $width) { msg, w in "Message: \(msg.count) chars, width: \(w)px" }
  func bind<V1, V2, U>(
    _ kp: ReferenceWritableKeyPath<T, U>,
    to state1: GState<V1>,
    _ state2: GState<V2>,
    transform: @escaping (V1, V2) -> U
  ) -> Self {
    var s = self
    s.ops.append { node in
      let update = { [weak node] in
        guard let node = node else { return }
        node[keyPath: kp] = transform(state1.wrappedValue, state2.wrappedValue)
      }
      state1.onChange { _ in update() }
      state2.onChange { _ in update() }
    }
    return s
  }

  /// Bind three GStates with a transformation function
  /// Usage: .bind(\.text, to: $a, $b, $c) { a, b, c in "\(a) - \(b) - \(c)" }
  func bind<V1, V2, V3, U>(
    _ kp: ReferenceWritableKeyPath<T, U>,
    to state1: GState<V1>,
    _ state2: GState<V2>,
    _ state3: GState<V3>,
    transform: @escaping (V1, V2, V3) -> U
  ) -> Self {
    var s = self
    s.ops.append { node in
      let update = { [weak node] in
        guard let node = node else { return }
        node[keyPath: kp] = transform(state1.wrappedValue, state2.wrappedValue, state3.wrappedValue)
      }
      state1.onChange { _ in update() }
      state2.onChange { _ in update() }
      state3.onChange { _ in update() }
    }
    return s
  }

  /// Bind four GStates with a transformation function
  /// Usage: .bind(\.text, to: $a, $b, $c, $d) { a, b, c, d in "\(a) - \(b) - \(c) - \(d)" }
  func bind<V1, V2, V3, V4, U>(
    _ kp: ReferenceWritableKeyPath<T, U>,
    to state1: GState<V1>,
    _ state2: GState<V2>,
    _ state3: GState<V3>,
    _ state4: GState<V4>,
    transform: @escaping (V1, V2, V3, V4) -> U
  ) -> Self {
    var s = self
    s.ops.append { node in
      let update = { [weak node] in
        guard let node = node else { return }
        node[keyPath: kp] = transform(state1.wrappedValue, state2.wrappedValue, state3.wrappedValue, state4.wrappedValue)
      }
      state1.onChange { _ in update() }
      state2.onChange { _ in update() }
      state3.onChange { _ in update() }
      state4.onChange { _ in update() }
    }
    return s
  }
}
