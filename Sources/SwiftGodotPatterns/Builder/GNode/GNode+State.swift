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

  /// Dynamic member lookup for GBinding binding
  subscript<V>(dynamicMember kp: ReferenceWritableKeyPath<T, V>) -> (GBinding<V>) -> Self {
    { binding in
      var s = self
      s.ops.append { node in
        binding.onChange { value in
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

  /// Dynamic member lookup for GBinding with transform to StringName
  subscript(dynamicMember kp: ReferenceWritableKeyPath<T, StringName>) -> (GBinding<String>) -> Self {
    { binding in
      var s = self
      s.ops.append { node in
        binding.onChange { value in
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
            GD.print("⚠️ Invalid rawValue for \(E.self):", raw)
            return
          }
          node[keyPath: kp] = e
        }
      }
      return s
    }
  }

  /// Dynamic member lookup for GBinding with RawRepresentable enum
  subscript<E>(dynamicMember kp: ReferenceWritableKeyPath<T, E>) -> (GBinding<E.RawValue>) -> Self where E: RawRepresentable {
    { binding in
      var s = self
      s.ops.append { node in
        binding.onChange { raw in
          guard let e = E(rawValue: raw) else {
            GD.print("⚠️ Invalid rawValue for \(E.self):", raw)
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
  func bind<V>(_ state: GState<V>, to kp: ReferenceWritableKeyPath<T, V>) -> Self {
    var s = self
    s.ops.append { node in
      state.onChange { value in
        node[keyPath: kp] = value
      }
    }
    return s
  }

  /// Bind a GBinding to a keyPath, updating the node property whenever the binding changes
  func bind<V>(_ binding: GBinding<V>, to kp: ReferenceWritableKeyPath<T, V>) -> Self {
    var s = self
    s.ops.append { node in
      binding.onChange { value in
        node[keyPath: kp] = value
      }
    }
    return s
  }

  /// Bind a GState with a transformation function
  func bind<V, U>(_ state: GState<V>, to kp: ReferenceWritableKeyPath<T, U>, transform: @escaping (V) -> U) -> Self {
    var s = self
    s.ops.append { node in
      state.onChange { value in
        node[keyPath: kp] = transform(value)
      }
    }
    return s
  }

  /// Bind a GBinding with a transformation function
  func bind<V, U>(_ binding: GBinding<V>, to kp: ReferenceWritableKeyPath<T, U>, transform: @escaping (V) -> U) -> Self {
    var s = self
    s.ops.append { node in
      binding.onChange { value in
        node[keyPath: kp] = transform(value)
      }
    }
    return s
  }

  /// Bind multiple states that combine to set a single property
  func bind<A, B, V>(_ a: GState<A>, _ b: GState<B>, to kp: ReferenceWritableKeyPath<T, V>, transform: @escaping (A, B) -> V) -> Self {
    var s = self
    s.ops.append { node in
      let update = {
        node[keyPath: kp] = transform(a.wrappedValue, b.wrappedValue)
      }
      a.onChange { _ in update() }
      b.onChange { _ in update() }
    }
    return s
  }

  /// Update node when state changes using a custom closure
  func onStateChange<V>(_ state: GState<V>, _ handler: @escaping (T, V) -> Void) -> Self {
    var s = self
    s.ops.append { node in
      state.onChange { value in
        handler(node, value)
      }
    }
    return s
  }

  /// Update node when binding changes using a custom closure
  func onStateChange<V>(_ binding: GBinding<V>, _ handler: @escaping (T, V) -> Void) -> Self {
    var s = self
    s.ops.append { node in
      binding.onChange { value in
        handler(node, value)
      }
    }
    return s
  }
}
