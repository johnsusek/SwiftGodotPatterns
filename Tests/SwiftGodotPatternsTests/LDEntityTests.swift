@testable import SwiftGodotPatterns
import XCTest

final class LDEntityTests: XCTestCase {
  var project: LDProject!
  var level: LDLevel!

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
      level = project.levels.first!
    } catch {
      XCTFail("Failed to load test project: \(error)")
    }
  }

  // MARK: - Entity Definitions

  func testEntityDefinitionPivot() {
    for entityDef in project.defs.entities {
      XCTAssertGreaterThanOrEqual(entityDef.pivotX, 0.0)
      XCTAssertLessThanOrEqual(entityDef.pivotX, 1.0)
      XCTAssertGreaterThanOrEqual(entityDef.pivotY, 0.0)
      XCTAssertLessThanOrEqual(entityDef.pivotY, 1.0)

      let pivot = entityDef.pivot
      XCTAssertEqual(pivot.x, Float(entityDef.pivotX))
      XCTAssertEqual(pivot.y, Float(entityDef.pivotY))
    }
  }

  func testEntityDefinitionSize() {
    for entityDef in project.defs.entities {
      let size = entityDef.size
      XCTAssertEqual(size.x, Float(entityDef.width))
      XCTAssertEqual(size.y, Float(entityDef.height))
    }
  }

  // MARK: - Entity Instances

  func testEntityInstancePositionPivot() {
    for entity in level.allEntities {
      // positionPivot returns raw LDtk position
      let pos = entity.positionPivot
      XCTAssertEqual(pos.x, Float(entity.px[0]))
      XCTAssertEqual(pos.y, Float(entity.px[1]))
    }
  }

  func testEntityInstancePositionCalculation() {
    for entity in level.allEntities {
      // position applies pivot adjustments for Godot centering
      let pos = entity.position
      let pivotOffsetX = Float(entity.pivot[0]) * Float(entity.width)
      let pivotOffsetY = Float(entity.pivot[1]) * Float(entity.height)
      let halfWidth = Float(entity.width) / 2.0
      let halfHeight = Float(entity.height) / 2.0

      let expectedX = Float(entity.px[0]) - pivotOffsetX + halfWidth
      let expectedY = Float(entity.px[1]) - pivotOffsetY + halfHeight

      XCTAssertEqual(pos.x, expectedX, accuracy: 0.01)
      XCTAssertEqual(pos.y, expectedY, accuracy: 0.01)
    }
  }

  func testEntityInstanceGridPosition() {
    for entity in level.allEntities {
      let gridPos = entity.gridPosition
      XCTAssertEqual(gridPos.x, Int32(entity.grid[0]))
      XCTAssertEqual(gridPos.y, Int32(entity.grid[1]))
    }
  }

  func testEntityInstancePivot() {
    for entity in level.allEntities {
      let pivot = entity.pivotVector
      XCTAssertEqual(pivot.x, Float(entity.pivot[0]))
      XCTAssertEqual(pivot.y, Float(entity.pivot[1]))
    }
  }

  func testEntityInstanceSize() {
    for entity in level.allEntities {
      let size = entity.size
      XCTAssertEqual(size.x, Float(entity.width))
      XCTAssertEqual(size.y, Float(entity.height))
    }
  }

  // MARK: - Entity Field Access

  func testEntityFieldAccess() {
    // Find entity with fields
    let entityWithFields = level.allEntities.first { !$0.fieldInstances.isEmpty }

    guard let entity = entityWithFields else {
      // If no entities have fields, that's ok for this test
      return
    }

    XCTAssertFalse(entity.fieldInstances.isEmpty)

    for fieldInstance in entity.fieldInstances {
      // Test that we can access the field by identifier
      let value = entity.field(fieldInstance.identifier)
      XCTAssertNotNil(value)
    }
  }

  func testEntityFieldIntAccessor() {
    // Try to find an entity with an integer field
    for entity in level.allEntities {
      if let intValue = entity.field("Integer")?.asInt() {
        XCTAssertGreaterThanOrEqual(intValue, Int.min)
        XCTAssertLessThanOrEqual(intValue, Int.max)
        break
      }
    }
  }

  func testEntityFieldStringAccessor() {
    // Try to find an entity with a string field
    for entity in level.allEntities {
      if let stringValue = entity.field("text")?.asString() {
        XCTAssertNotNil(stringValue)
        break
      }
    }
  }

  // MARK: - Level Entity Queries

  func testLevelAllEntities() {
    let allEntities = level.allEntities
    XCTAssertFalse(allEntities.isEmpty)

    // Verify all entities come from entity layers
    let entityLayers = level.entityLayers
    let totalEntities = entityLayers.reduce(0) { $0 + $1.entityInstances.count }
    XCTAssertEqual(allEntities.count, totalEntities)
  }

  func testLevelEntitiesByIdentifier() {
    // Get first entity's identifier
    guard let firstEntity = level.allEntities.first else {
      XCTFail("No entities in level")
      return
    }

    let matchingEntities = level.entities(withIdentifier: firstEntity.identifier)
    XCTAssertFalse(matchingEntities.isEmpty)

    for entity in matchingEntities {
      XCTAssertEqual(entity.identifier, firstEntity.identifier)
    }
  }

  func testLevelEntityByIdentifier() {
    guard let firstEntity = level.allEntities.first else {
      XCTFail("No entities in level")
      return
    }

    let foundEntity = level.entity(withIdentifier: firstEntity.identifier)
    XCTAssertNotNil(foundEntity)
    XCTAssertEqual(foundEntity?.identifier, firstEntity.identifier)
  }

  // MARK: - Entity World Position

  func testEntityWorldPosition() {
    for entity in level.allEntities {
      if let worldPos = entity.worldPosition {
        XCTAssertNotNil(entity.worldX)
        XCTAssertNotNil(entity.worldY)
        XCTAssertEqual(worldPos.x, Float(entity.worldX!))
        XCTAssertEqual(worldPos.y, Float(entity.worldY!))
      }
    }
  }

  // MARK: - Entity Definition Lookup

  func testEntityDefinitionLookup() {
    for entity in level.allEntities {
      let entityDef = project.defs.entity(uid: entity.defUid)
      XCTAssertNotNil(entityDef, "Should find definition for entity \(entity.identifier)")

      if let def = entityDef {
        XCTAssertEqual(def.identifier, entity.identifier)
      }
    }
  }

  // MARK: - Entity Tiles

  func testEntityTileRect() {
    for entity in level.allEntities {
      if let tile = entity.tile {
        XCTAssertGreaterThan(tile.tilesetUid, 0)
        XCTAssertGreaterThanOrEqual(tile.x, 0)
        XCTAssertGreaterThanOrEqual(tile.y, 0)
        XCTAssertGreaterThan(tile.w, 0)
        XCTAssertGreaterThan(tile.h, 0)

        // Test rect conversion
        let rect = tile.rect
        XCTAssertEqual(rect.position.x, Float(tile.x))
        XCTAssertEqual(rect.position.y, Float(tile.y))
        XCTAssertEqual(rect.size.x, Float(tile.w))
        XCTAssertEqual(rect.size.y, Float(tile.h))
      }
    }
  }
}
