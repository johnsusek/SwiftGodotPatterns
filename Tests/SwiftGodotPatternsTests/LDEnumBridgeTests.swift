@testable import SwiftGodotPatterns
import XCTest

// Test enum matching LDtk Item enum
enum TestItem: String, LDExported {
  case knife = "Knife"
  case healingPlant = "Healing_Plant"
  case meat = "Meat"
  case boots = "Boots"
  case water = "Water"
  case gem = "Gem"

  static var ldtkIdentifier: String { "Item" }
}

final class LDtkEnumBridgeTests: XCTestCase {
  func testSingleEnumValue() throws {
    // Parse a single enum value from string
    let value = LDFieldValue.string("Knife")
    let item: TestItem? = value.asEnum()

    XCTAssertEqual(item, .knife)
  }

  func testEnumArray() throws {
    // Parse array of enum values
    let values: [LDFieldValue] = [
      .string("Knife"),
      .string("Boots"),
      .string("Water"),
    ]
    let arrayValue = LDFieldValue.array(values)
    let items: [TestItem]? = arrayValue.asEnumArray()

    XCTAssertEqual(items, [.knife, .boots, .water])
  }

  func testEnumArrayWithInvalidValues() throws {
    // Invalid values should be filtered out
    let values: [LDFieldValue] = [
      .string("Knife"),
      .string("InvalidItem"), // Should be skipped
      .string("Boots"),
      .int(42), // Wrong type, should be skipped
    ]
    let arrayValue = LDFieldValue.array(values)
    let items: [TestItem]? = arrayValue.asEnumArray()

    XCTAssertEqual(items, [.knife, .boots])
  }

  // External enum generation is now handled by the GenLDEnums build plugin
  // which generates LDExported.json at build time

  func testEnumCaseSensitivity() throws {
    // LDtk enums are case-sensitive
    let value = LDFieldValue.string("knife") // lowercase
    let item: TestItem? = value.asEnum()

    XCTAssertNil(item, "Should fail on case mismatch")
  }

  func testEnumWithUnderscores() throws {
    // Test enum value with underscores (Healing_Plant)
    let value = LDFieldValue.string("Healing_Plant")
    let item: TestItem? = value.asEnum()

    XCTAssertEqual(item, .healingPlant)
  }

  func testEmptyEnumArray() throws {
    let arrayValue = LDFieldValue.array([])
    let items: [TestItem]? = arrayValue.asEnumArray()

    XCTAssertEqual(items, [])
  }

  func testNullEnumValue() throws {
    let value = LDFieldValue.null
    let item: TestItem? = value.asEnum()

    XCTAssertNil(item)
  }
}
