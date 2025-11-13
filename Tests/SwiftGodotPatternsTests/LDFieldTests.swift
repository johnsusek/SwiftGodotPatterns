import SwiftGodot
@testable import SwiftGodotPatterns
import XCTest

final class LDFieldTests: XCTestCase {
  var project: LDProject!

  override func setUp() {
    super.setUp()

    guard let testFileURL = Bundle.module.url(forResource: "Test_file_for_API_showing_all_features", withExtension: "ldtk") else {
      XCTFail("Could not find test file in bundle")
      return
    }

    do {
      let data = try Data(contentsOf: testFileURL)
      let decoder = JSONDecoder()
      project = try decoder.decode(LDProject.self, from: data)
    } catch {
      XCTFail("Failed to load test project: \(error)")
    }
  }

  // MARK: - Field Value Types

  func testIntFieldValue() {
    let value = LDFieldValue.int(42)
    XCTAssertEqual(value.asInt(), 42)
    XCTAssertNil(value.asString())
    XCTAssertFalse(value.isNull)
  }

  func testFloatFieldValue() {
    let value = LDFieldValue.float(3.14)
    XCTAssertEqual(value.asFloat(), 3.14)
    XCTAssertNil(value.asInt())
    XCTAssertFalse(value.isNull)
  }

  func testBoolFieldValue() {
    let value = LDFieldValue.bool(true)
    XCTAssertEqual(value.asBool(), true)
    XCTAssertNil(value.asInt())
    XCTAssertFalse(value.isNull)
  }

  func testStringFieldValue() {
    let value = LDFieldValue.string("hello")
    XCTAssertEqual(value.asString(), "hello")
    XCTAssertNil(value.asInt())
    XCTAssertFalse(value.isNull)
  }

  func testColorFieldValue() {
    let value = LDFieldValue.color("#FF0000")
    XCTAssertEqual(value.asColorString(), "#FF0000")
  }

  func testNullFieldValue() {
    let value = LDFieldValue.null
    XCTAssertTrue(value.isNull)
    XCTAssertNil(value.asInt())
    XCTAssertNil(value.asString())
  }

  func testPointFieldValue() {
    let point = LDPoint(cx: 5, cy: 10)
    let value = LDFieldValue.point(point)

    let retrievedPoint = value.asPoint()
    XCTAssertNotNil(retrievedPoint)
    XCTAssertEqual(retrievedPoint?.cx, 5)
    XCTAssertEqual(retrievedPoint?.cy, 10)
  }

  func testEntityRefFieldValue() {
    let ref = LDEntityRef(
      entityIid: "entity-123",
      layerIid: "layer-456",
      levelIid: "level-789",
      worldIid: "world-000"
    )
    let value = LDFieldValue.entityRef(ref)

    let retrievedRef = value.asEntityRef()
    XCTAssertNotNil(retrievedRef)
    XCTAssertEqual(retrievedRef?.entityIid, "entity-123")
  }

  func testArrayFieldValue() {
    let array: [LDFieldValue] = [.int(1), .int(2), .int(3)]
    let value = LDFieldValue.array(array)

    let retrievedArray = value.asArray()
    XCTAssertNotNil(retrievedArray)
    XCTAssertEqual(retrievedArray?.count, 3)
    XCTAssertEqual(retrievedArray?[0].asInt(), 1)
  }

  // MARK: - Type Coercion

  func testIntToFloat() {
    let value = LDFieldValue.int(42)
    XCTAssertEqual(value.asFloat(), 42.0)
  }

  // MARK: - Point Conversion

  func testPointToVector2() {
    let point = LDPoint(cx: 5, cy: 10)
    let vector = point.toVector2(gridSize: 16)

    XCTAssertEqual(vector.x, 80.0, accuracy: 0.01)
    XCTAssertEqual(vector.y, 160.0, accuracy: 0.01)
  }

  func testPointToVector2DefaultGridSize() {
    let point = LDPoint(cx: 5, cy: 10)
    let vector = point.toVector2()

    XCTAssertEqual(vector.x, 80.0, accuracy: 0.01)
    XCTAssertEqual(vector.y, 160.0, accuracy: 0.01)
  }

  // MARK: - Field Collection Extension Tests

  func testFieldCollectionAccessors() {
    let fields: [LDFieldInstance] = [
      LDFieldInstance(
        identifier: "health",
        type: "Int",
        value: .int(100),
        defUid: 1
      ),
      LDFieldInstance(
        identifier: "name",
        type: "String",
        value: .string("Player"),
        defUid: 2
      ),
      LDFieldInstance(
        identifier: "position",
        type: "Point",
        value: .point(LDPoint(cx: 5, cy: 10)),
        defUid: 3
      ),
    ]

    XCTAssertEqual(fields.field("health")?.asInt(), 100)
    XCTAssertEqual(fields.field("name")?.asString(), "Player")
    XCTAssertNotNil(fields.field("position")?.asPoint())
    XCTAssertNil(fields.field("nonexistent")?.asInt())
  }

  func testFieldVector2Accessor() {
    let fields: [LDFieldInstance] = [
      LDFieldInstance(
        identifier: "spawnPoint",
        type: "Point",
        value: .point(LDPoint(cx: 10, cy: 20)),
        defUid: 1
      ),
    ]

    guard let vector = fields.field("spawnPoint")?.asVector2(gridSize: 16) else {
      XCTFail("Should get vector from field")
      return
    }
    XCTAssertEqual(Float(vector.x), 160.0, accuracy: 0.01)
    XCTAssertEqual(Float(vector.y), 320.0, accuracy: 0.01)
  }
}
