@testable import SwiftGodotPatterns
import XCTest

final class LDProjectTests: XCTestCase {
  var project: LDProject!

  override func setUp() {
    super.setUp()

    // Get path to test file from bundle
    guard let testFileURL = Bundle.module.url(forResource: "Test_file_for_API_showing_all_features", withExtension: "ldtk") else {
      XCTFail("Could not find test file in bundle")
      return
    }

    // Load project
    do {
      let data = try Data(contentsOf: testFileURL)
      let decoder = JSONDecoder()
      project = try decoder.decode(LDProject.self, from: data)
    } catch {
      XCTFail("Failed to load test project: \(error)")
    }
  }

  // MARK: - Accessor Tests

  func testAllLevelsAccessor() {
    let allLevels = project.allLevels
    XCTAssertEqual(allLevels.count, project.levels.count)
  }

  func testLevelByIdentifier() {
    // Get first level's identifier
    let firstLevelId = project.levels.first?.identifier
    XCTAssertNotNil(firstLevelId)

    let foundLevel = project.level(firstLevelId!)
    XCTAssertNotNil(foundLevel)
    XCTAssertEqual(foundLevel?.identifier, firstLevelId)
  }

  func testLevelByIID() {
    let firstLevel = project.levels.first
    XCTAssertNotNil(firstLevel)

    let foundLevel = project.level(iid: firstLevel!.iid)
    XCTAssertNotNil(foundLevel)
    XCTAssertEqual(foundLevel?.iid, firstLevel?.iid)
  }

  func testLevelByUID() {
    let firstLevel = project.levels.first
    XCTAssertNotNil(firstLevel)

    let foundLevel = project.level(uid: firstLevel!.uid)
    XCTAssertNotNil(foundLevel)
    XCTAssertEqual(foundLevel?.uid, firstLevel?.uid)
  }

  // MARK: - Lookup Methods

  func testLayerByUID() {
    let layers = project.defs.layers
    XCTAssertFalse(layers.isEmpty)

    let firstLayer = layers.first!
    let foundLayer = project.defs.layer(uid: firstLayer.uid)
    XCTAssertNotNil(foundLayer)
    XCTAssertEqual(foundLayer?.uid, firstLayer.uid)
  }

  func testEntityByIdentifier() {
    let entities = project.defs.entities
    guard let firstEntity = entities.first else {
      XCTFail("No entities in test file")
      return
    }

    let foundEntity = project.defs.entity(firstEntity.identifier)
    XCTAssertNotNil(foundEntity)
    XCTAssertEqual(foundEntity?.identifier, firstEntity.identifier)
  }

  func testEntityByUID() {
    let entities = project.defs.entities
    guard let firstEntity = entities.first else {
      XCTFail("No entities in test file")
      return
    }

    let foundEntity = project.defs.entity(uid: firstEntity.uid)
    XCTAssertNotNil(foundEntity)
    XCTAssertEqual(foundEntity?.uid, firstEntity.uid)
  }

  func testTilesetByIdentifier() {
    let tilesets = project.defs.tilesets
    guard let firstTileset = tilesets.first else {
      XCTFail("No tilesets in test file")
      return
    }

    let foundTileset = project.defs.tileset(firstTileset.identifier)
    XCTAssertNotNil(foundTileset)
    XCTAssertEqual(foundTileset?.identifier, firstTileset.identifier)
  }

  func testTilesetByUID() {
    let tilesets = project.defs.tilesets
    guard let firstTileset = tilesets.first else {
      XCTFail("No tilesets in test file")
      return
    }

    let foundTileset = project.defs.tileset(uid: firstTileset.uid)
    XCTAssertNotNil(foundTileset)
    XCTAssertEqual(foundTileset?.uid, firstTileset.uid)
  }

  // MARK: - Loader Tests

  // Note: LDLoader tests are not included in unit tests as they require
  // Godot runtime initialization. Test LDLoader in integration tests within
  // a running Godot project.
}
