import Foundation
import SwiftGodot

/// Theme dictionary extensions.
///
/// These extensions provide convenient methods for building themes from dictionaries:
///
/// ### Example: Creating a theme from a dictionary (camelCase or snake_case)
/// ```swift
/// let myTheme = Theme.build([
///   "Button": [
///     "colors": ["fontColor": Color.white],       // camelCase keys automatically converted
///     "constants": ["outlineSize": 2],
///     "fontSizes": ["fontSize": 16]               // Both outer and inner keys support camelCase
///   ],
///   "Label": [
///     "colors": ["font_color": Color.white],      // snake_case also works
///     "font_sizes": ["font_size": 14]
///   ]
/// ])
/// ```
public extension Theme {
  /// Creates a theme from a dictionary structure.
  ///
  /// The dictionary structure supports both camelCase and snake_case keys.
  /// All keys (both outer category keys and inner property names) are automatically
  /// converted from camelCase to snake_case when applying to Godot's theme system.
  ///
  /// ```
  /// [
  ///   "ControlType": [
  ///     "colors": ["fontColor" or "font_color": Color],
  ///     "constants": ["outlineSize" or "outline_size": Int],
  ///     "fonts": ["fontName" or "font_name": Font],
  ///     "fontSizes" or "font_sizes": ["fontSize" or "font_size": Int],
  ///     "icons": ["iconName" or "icon_name": Texture2D],
  ///     "styleBoxes" or "styleboxes": ["normalStyle" or "normal_style": StyleBox]
  ///   ]
  /// ]
  /// ```
  ///
  /// - Parameter dict: Dictionary mapping control types to their theme properties
  convenience init(_ dict: [String: [String: Any]]) {
    self.init()
    applyDict(dict)
  }

  /// Applies theme properties from a dictionary structure.
  ///
  /// - Parameter dict: Dictionary mapping control types to their theme properties
  func applyDict(_ dict: [String: [String: Any]]) {
    for (controlType, properties) in dict {
      let typeName = StringName(controlType)

      // Apply colors
      if let colors = (properties["colors"] ?? properties["colors".fromCamelCase()]) as? [String: Color] {
        for (name, value) in colors {
          setColor(name: StringName(name.fromCamelCase()), themeType: typeName, color: value)
        }
      }

      // Apply constants
      if let constants = (properties["constants"] ?? properties["constants".fromCamelCase()]) as? [String: Int] {
        for (name, value) in constants {
          setConstant(name: StringName(name.fromCamelCase()), themeType: typeName, constant: Int32(value))
        }
      }

      // Apply fonts
      if let fonts = (properties["fonts"] ?? properties["fonts".fromCamelCase()]) as? [String: Font] {
        for (name, value) in fonts {
          setFont(name: StringName(name.fromCamelCase()), themeType: typeName, font: value)
        }
      }

      // Apply font sizes
      if let fontSizes = (properties["font_sizes"] ?? properties["fontSizes"]) as? [String: Int] {
        for (name, value) in fontSizes {
          setFontSize(name: StringName(name.fromCamelCase()), themeType: typeName, fontSize: Int32(value))
        }
      }

      // Apply icons
      if let icons = (properties["icons"] ?? properties["icons".fromCamelCase()]) as? [String: Texture2D] {
        for (name, value) in icons {
          setIcon(name: StringName(name.fromCamelCase()), themeType: typeName, texture: value)
        }
      }

      // Apply styleboxes
      if let styleBoxes = (properties["styleboxes"] ?? properties["styleBoxes"]) as? [String: StyleBox] {
        for (name, value) in styleBoxes {
          setStylebox(name: StringName(name.fromCamelCase()), themeType: typeName, texture: value)
        }
      }
    }
  }

  /// Converts a camelCase string to snake_case.
  private func camelToSnake(_ string: String) -> String {
    let pattern = "([a-z0-9])([A-Z])"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(string.startIndex..., in: string)
    return regex.stringByReplacingMatches(
      in: string,
      range: range,
      withTemplate: "$1_$2"
    ).lowercased()
  }
}

private extension String {
  /// Returns the snake_case version of this camelCase string.
  func fromCamelCase() -> String {
    let pattern = "([a-z0-9])([A-Z])"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(startIndex..., in: self)
    return regex.stringByReplacingMatches(
      in: self,
      range: range,
      withTemplate: "$1_$2"
    ).lowercased()
  }
}

/// Helper for creating StyleBox instances with less boilerplate
public extension StyleBox {
  /// Creates a flat StyleBox with a background color.
  ///
  /// - Parameters:
  ///   - color: Background color
  ///   - contentMargin: Margin on all sides (default: 0)
  /// - Returns: A configured StyleBoxFlat
  static func flat(
    color: Color,
    contentMargin: Double = 0
  ) -> StyleBoxFlat {
    let box = StyleBoxFlat()
    box.bgColor = color
    if contentMargin > 0 {
      box.contentMarginLeft = contentMargin
      box.contentMarginTop = contentMargin
      box.contentMarginRight = contentMargin
      box.contentMarginBottom = contentMargin
    }
    return box
  }

  /// Creates a flat StyleBox with a background color and border.
  ///
  /// - Parameters:
  ///   - color: Background color
  ///   - borderColor: Border color
  ///   - borderWidth: Border width on all sides
  ///   - contentMargin: Content margin on all sides (default: 0)
  /// - Returns: A configured StyleBoxFlat
  static func flat(
    color: Color,
    borderColor: Color,
    borderWidth: Double,
    contentMargin: Double = 0
  ) -> StyleBoxFlat {
    let box = StyleBoxFlat()
    box.bgColor = color
    box.borderColor = borderColor
    box.borderWidthLeft = Int32(borderWidth)
    box.borderWidthTop = Int32(borderWidth)
    box.borderWidthRight = Int32(borderWidth)
    box.borderWidthBottom = Int32(borderWidth)
    if contentMargin > 0 {
      box.contentMarginLeft = contentMargin
      box.contentMarginTop = contentMargin
      box.contentMarginRight = contentMargin
      box.contentMarginBottom = contentMargin
    }
    return box
  }

  /// Creates a flat StyleBox with rounded corners.
  ///
  /// - Parameters:
  ///   - color: Background color
  ///   - cornerRadius: Radius for all corners
  ///   - contentMargin: Content margin on all sides (default: 0)
  /// - Returns: A configured StyleBoxFlat
  static func flat(
    color: Color,
    cornerRadius: Double,
    contentMargin: Double = 0
  ) -> StyleBoxFlat {
    let box = StyleBoxFlat()
    box.bgColor = color
    box.cornerRadiusTopLeft = Int32(cornerRadius)
    box.cornerRadiusTopRight = Int32(cornerRadius)
    box.cornerRadiusBottomLeft = Int32(cornerRadius)
    box.cornerRadiusBottomRight = Int32(cornerRadius)
    if contentMargin > 0 {
      box.contentMarginLeft = contentMargin
      box.contentMarginTop = contentMargin
      box.contentMarginRight = contentMargin
      box.contentMarginBottom = contentMargin
    }
    return box
  }
}
