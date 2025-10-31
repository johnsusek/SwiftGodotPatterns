import SwiftGodot

// MARK: - Two-way binding for Range controls

public extension GNode where T: Slider {
  func value(_ state: GState<Double>) -> Self {
    var s = self
    s.ops.append { $0.value = state.wrappedValue }
    s.ops.append { node in
      _ = node.valueChanged.connect { newValue in
        state.wrappedValue = newValue
      }
    }
    return s
  }
}

public extension GNode where T: ScrollBar {
  func value(_ state: GState<Double>) -> Self {
    var s = self
    s.ops.append { $0.value = state.wrappedValue }
    s.ops.append { node in
      _ = node.valueChanged.connect { newValue in
        state.wrappedValue = newValue
      }
    }
    return s
  }
}

public extension GNode where T: SpinBox {
  func value(_ state: GState<Double>) -> Self {
    var s = self
    s.ops.append { $0.value = state.wrappedValue }
    s.ops.append { node in
      _ = node.valueChanged.connect { newValue in
        state.wrappedValue = newValue
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
    // Set initial value
    s.ops.append { $0.text = state.wrappedValue }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.textChanged.connect { newText in
        state.wrappedValue = newText
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
    // Set initial value
    s.ops.append { $0.text = state.wrappedValue }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.textChanged.connect {
        state.wrappedValue = node.text
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
    // Set initial value
    s.ops.append { $0.text = state.wrappedValue }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.textChanged.connect {
        state.wrappedValue = node.text
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
    // Set initial value
    s.ops.append { $0.buttonPressed = state.wrappedValue }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.toggled.connect { pressed in
        state.wrappedValue = pressed
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
    }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.itemSelected.connect { index in
        state.wrappedValue = Int(index)
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
    // Set initial value
    s.ops.append { node in
      let value = state.wrappedValue
      if value >= 0 {
        node.select(idx: Int32(value))
      } else {
        node.deselectAll()
      }
    }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.itemSelected.connect { index in
        state.wrappedValue = Int(index)
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
    // Set initial value
    s.ops.append { $0.currentTab = Int32(state.wrappedValue) }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.tabSelected.connect { tab in
        state.wrappedValue = Int(tab)
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
    // Set initial value
    s.ops.append { $0.currentTab = Int32(state.wrappedValue) }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.tabSelected.connect { tab in
        state.wrappedValue = Int(tab)
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
    // Set initial value
    s.ops.append { $0.color = state.wrappedValue }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.colorChanged.connect { newColor in
        state.wrappedValue = newColor
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
    // Set initial value
    s.ops.append { $0.color = state.wrappedValue }
    // Listen for changes and update state
    s.ops.append { node in
      _ = node.colorChanged.connect { newColor in
        state.wrappedValue = newColor
      }
    }
    return s
  }
}
