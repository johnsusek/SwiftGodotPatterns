import SwiftGodot

// MARK: - Two-way binding for Range controls

/// Two-way binding helpers for Range controls (Slider, ScrollBar, SpinBox)
public extension GNode where T: Slider {
  /// Creates a two-way binding between a Slider control and a GState.
  ///
  /// This method:
  /// - Sets the initial value of the control from the state
  /// - Updates the state whenever the control's value changes via the `valueChanged` signal
  ///
  /// Use this for range input controls to automatically sync their values with your state.
  ///
  /// ```swift
  /// @State var volume: Double = 0.5
  ///
  /// Slider$()
  ///   .min(0)
  ///   .max(1)
  ///   .value($volume) // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func value(_ state: GState<Double>) -> Self {
    var s = self
    s.ops.append { node in
      node.value = state.wrappedValue
      _ = node.valueChanged.connect { newValue in
        state.wrappedValue = newValue
      }
      state.onChange { newValue in
        node.value = newValue
      }
    }
    return s
  }
}

/// Two-way binding helpers for ScrollBar controls
public extension GNode where T: ScrollBar {
  /// Creates a two-way binding between a ScrollBar control and a GState.
  ///
  /// This method:
  /// - Sets the initial value of the control from the state
  /// - Updates the state whenever the control's value changes via the `valueChanged` signal
  ///
  /// Use this for scroll bar controls to automatically sync their values with your state.
  ///
  /// ```swift
  /// @State var scrollPosition: Double = 0.0
  ///
  /// ScrollBar$()
  ///   .min(0)
  ///   .max(1)
  ///   .value($scrollPosition) // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func value(_ state: GState<Double>) -> Self {
    var s = self
    s.ops.append { node in
      node.value = state.wrappedValue
      _ = node.valueChanged.connect { newValue in
        state.wrappedValue = newValue
      }
      state.onChange { newValue in
        node.value = newValue
      }
    }
    return s
  }
}

/// Two-way binding helpers for SpinBox controls
public extension GNode where T: SpinBox {
  /// Creates a two-way binding between a SpinBox control and a GState.
  /// This method:
  /// - Sets the initial value of the control from the state
  /// - Updates the state whenever the control's value changes via the `valueChanged` signal
  ///
  /// Use this for spin box controls to automatically sync their values with your state.
  ///
  /// ```swift
  /// @State var spinValue: Double = 0.0
  ///
  /// SpinBox$()
  ///   .min(0)
  ///   .max(100)
  ///   .value($spinValue) // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func value(_ state: GState<Double>) -> Self {
    var s = self
    s.ops.append { node in
      node.value = state.wrappedValue
      _ = node.valueChanged.connect { newValue in
        state.wrappedValue = newValue
      }
      state.onChange { newValue in
        node.value = newValue
      }
    }
    return s
  }
}

// MARK: - Two-way binding for LineEdit

/// Two-way binding helpers for LineEdit controls
public extension GNode where T: LineEdit {
  /// Creates a two-way binding between a LineEdit control and a GState.
  ///
  /// This method:
  /// - Sets the initial text of the control from the state
  /// - Updates the state whenever the control's text changes via the `textChanged` signal
  ///
  /// Use this for text input fields to automatically sync their values with your state.
  ///
  /// ```swift
  /// @State var username: String = ""
  ///
  /// LineEdit$()
  ///   .placeholderText("Enter username")
  ///   .text($username)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func text(_ state: GState<String>) -> Self {
    var s = self
    s.ops.append { node in
      node.text = state.wrappedValue
      _ = node.textChanged.connect { newText in
        state.wrappedValue = newText
      }
      state.onChange { newValue in
        // Only update if the text actually changed to avoid resetting cursor
        if node.text != newValue {
          node.text = newValue
        }
      }
    }
    return s
  }
}

// MARK: - Two-way binding for TextEdit

/// Two-way binding helpers for TextEdit controls
public extension GNode where T: TextEdit {
  /// Creates a two-way binding between a TextEdit control and a GState.
  ///
  /// This method:
  /// - Sets the initial text of the control from the state
  /// - Updates the state whenever the control's text changes via the `textChanged` signal
  ///
  /// Use this for multi-line text input fields to automatically sync their values with your state.
  ///
  /// ```swift
  /// @State var notes: String = ""
  ///
  /// TextEdit$()
  ///   .text($notes)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func text(_ state: GState<String>) -> Self {
    var s = self
    s.ops.append { node in
      node.text = state.wrappedValue
      _ = node.textChanged.connect {
        state.wrappedValue = node.text
      }
      state.onChange { newValue in
        // Only update if the text actually changed to avoid resetting cursor
        if node.text != newValue {
          node.text = newValue
        }
      }
    }
    return s
  }
}

// MARK: - Two-way binding for CodeEdit

/// Two-way binding helpers for CodeEdit controls
public extension GNode where T: CodeEdit {
  /// Creates a two-way binding between a CodeEdit control and a GState.
  ///
  /// This method:
  /// - Sets the initial text of the control from the state
  /// - Updates the state whenever the control's text changes via the `textChanged` signal
  ///
  /// Use this for code editor fields to automatically sync their values with your state.
  ///
  /// ```swift
  /// @State var code: String = ""
  ///
  /// CodeEdit$()
  ///   .text($code)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func text(_ state: GState<String>) -> Self {
    var s = self
    s.ops.append { node in
      node.text = state.wrappedValue
      _ = node.textChanged.connect {
        state.wrappedValue = node.text
      }
      state.onChange { newValue in
        // Only update if the text actually changed to avoid resetting cursor
        if node.text != newValue {
          node.text = newValue
        }
      }
    }
    return s
  }
}

// MARK: - Two-way binding for BaseButton

/// Two-way binding helpers for BaseButton controls (CheckBox, CheckButton, Button with toggle mode)
public extension GNode where T: BaseButton {
  /// Creates a two-way binding between a BaseButton control and a GState.
  ///
  /// This method:
  /// - Sets the initial button pressed state from the state
  /// - Updates the state whenever the button's pressed state changes via the `toggled` signal
  ///
  /// Use this for checkboxes, check buttons, and toggle buttons to automatically sync their values with your state.
  ///
  /// ```swift
  /// @State var isEnabled: Bool = false
  ///
  /// CheckBox$()
  ///   .text("Enable feature")
  ///   .pressed($isEnabled)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func pressed(_ state: GState<Bool>) -> Self {
    var s = self
    s.ops.append { node in
      node.buttonPressed = state.wrappedValue
      _ = node.toggled.connect { pressed in
        state.wrappedValue = pressed
      }
      state.onChange { newValue in
        node.buttonPressed = newValue
      }
    }
    return s
  }
}

// MARK: - Two-way binding for OptionButton

/// Two-way binding helpers for OptionButton controls
public extension GNode where T: OptionButton {
  /// Creates a two-way binding between an OptionButton control and a GState.
  ///
  /// This method:
  /// - Sets the initial selected index from the state
  /// - Updates the state whenever the selection changes via the `itemSelected` signal
  ///
  /// Use this for dropdown menus to automatically sync their selected index with your state.
  ///
  /// ```swift
  /// @State var selectedOption: Int = 0
  ///
  /// OptionButton$()
  ///   .selected($selectedOption)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func selected(_ state: GState<Int>) -> Self {
    var s = self
    // Set initial value
    s.ops.append { node in
      node.select(idx: Int32(state.wrappedValue))
      // Listen for changes and update state
      _ = node.itemSelected.connect { index in
        state.wrappedValue = Int(index)
      }
      state.onChange { newValue in
        node.select(idx: Int32(newValue))
      }
    }
    return s
  }
}

// MARK: - Two-way binding for ItemList

/// Two-way binding helpers for ItemList controls
public extension GNode where T: ItemList {
  /// Creates a two-way binding between an ItemList control and a GState.
  ///
  /// This method:
  /// - Sets the initial selected index from the state (use -1 for no selection)
  /// - Updates the state whenever the selection changes via the `itemSelected` signal
  ///
  /// Use this for list selections to automatically sync their selected index with your state.
  ///
  /// ```swift
  /// @State var selectedItem: Int = -1
  ///
  /// ItemList$()
  ///   .selected($selectedItem)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func selected(_ state: GState<Int>) -> Self {
    var s = self
    s.ops.append { node in
      let value = state.wrappedValue
      if value >= 0 {
        node.select(idx: Int32(value))
      } else {
        node.deselectAll()
      }
      _ = node.itemSelected.connect { index in
        state.wrappedValue = Int(index)
      }
      state.onChange { newValue in
        if newValue >= 0 {
          node.select(idx: Int32(newValue))
        } else {
          node.deselectAll()
        }
      }
    }
    return s
  }
}

// MARK: - Two-way binding for TabBar

/// Two-way binding helpers for TabBar controls
public extension GNode where T: TabBar {
  /// Creates a two-way binding between a TabBar control and a GState.
  ///
  /// This method:
  /// - Sets the initial current tab from the state
  /// - Updates the state whenever the tab changes via the `tabSelected` signal
  ///
  /// Use this for tab bars to automatically sync their current tab with your state.
  ///
  /// ```swift
  /// @State var currentTab: Int = 0
  ///
  /// TabBar$()
  ///   .currentTab($currentTab)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func currentTab(_ state: GState<Int>) -> Self {
    var s = self
    s.ops.append { node in
      node.currentTab = Int32(state.wrappedValue)
      _ = node.tabSelected.connect { tab in
        state.wrappedValue = Int(tab)
      }
      state.onChange { newValue in
        node.currentTab = Int32(newValue)
      }
    }
    return s
  }
}

// MARK: - Two-way binding for TabContainer

/// Two-way binding helpers for TabContainer controls
public extension GNode where T: TabContainer {
  /// Creates a two-way binding between a TabContainer control and a GState.
  ///
  /// This method:
  /// - Sets the initial current tab from the state
  /// - Updates the state whenever the tab changes via the `tabSelected` signal
  ///
  /// Use this for tab containers to automatically sync their current tab with your state.
  ///
  /// ```swift
  /// @State var currentTab: Int = 0
  ///
  /// TabContainer$()
  ///   .currentTab($currentTab)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func currentTab(_ state: GState<Int>) -> Self {
    var s = self
    s.ops.append { node in
      node.currentTab = Int32(state.wrappedValue)
      _ = node.tabSelected.connect { tab in
        state.wrappedValue = Int(tab)
      }
      state.onChange { newValue in
        node.currentTab = Int32(newValue)
      }
    }
    return s
  }
}

// MARK: - Two-way binding for ColorPicker

/// Two-way binding helpers for ColorPicker controls
public extension GNode where T: ColorPicker {
  /// Creates a two-way binding between a ColorPicker control and a GState.
  ///
  /// This method:
  /// - Sets the initial color from the state
  /// - Updates the state whenever the color changes via the `colorChanged` signal
  ///
  /// Use this for color pickers to automatically sync their color with your state.
  ///
  /// ```swift
  /// @State var selectedColor: Color = .white
  ///
  /// ColorPicker$()
  ///   .color($selectedColor)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func color(_ state: GState<Color>) -> Self {
    var s = self
    s.ops.append { node in
      node.color = state.wrappedValue
      _ = node.colorChanged.connect { newColor in
        state.wrappedValue = newColor
      }
      state.onChange { newValue in
        node.color = newValue
      }
    }
    return s
  }
}

// MARK: - Two-way binding for ColorPickerButton

/// Two-way binding helpers for ColorPickerButton controls
public extension GNode where T: ColorPickerButton {
  /// Creates a two-way binding between a ColorPickerButton control and a GState.
  ///
  /// This method:
  /// - Sets the initial color from the state
  /// - Updates the state whenever the color changes via the `colorChanged` signal
  ///
  /// Use this for color picker buttons to automatically sync their color with your state.
  ///
  /// ```swift
  /// @State var selectedColor: Color = .white
  ///
  /// ColorPickerButton$()
  ///   .color($selectedColor)  // Two-way binding
  /// ```
  ///
  /// - Parameter state: The state variable to bind to (use $ prefix)
  /// - Returns: The modified `GNode` with the binding established
  func color(_ state: GState<Color>) -> Self {
    var s = self
    s.ops.append { node in
      node.color = state.wrappedValue
      _ = node.colorChanged.connect { newColor in
        state.wrappedValue = newColor
      }
      state.onChange { newValue in
        node.color = newValue
      }
    }
    return s
  }
}
