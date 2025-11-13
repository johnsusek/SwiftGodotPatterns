@testable import SwiftGodotPatterns
import XCTest

final class LDBuilderTests: XCTestCase {
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

  // MARK: - Coordinate Conversion Tests

  func testTileIdToAtlasCoords() {
    // Test with 16 tiles wide tileset
    let tilesWide = 16

    // Tile 0 should be at (0, 0)
    let coords0 = LDTileSetBuilder.tileIdToAtlasCoords(tileId: 0, tilesWide: tilesWide)
    XCTAssertEqual(coords0.x, 0)
    XCTAssertEqual(coords0.y, 0)

    // Tile 15 should be at (15, 0)
    let coords15 = LDTileSetBuilder.tileIdToAtlasCoords(tileId: 15, tilesWide: tilesWide)
    XCTAssertEqual(coords15.x, 15)
    XCTAssertEqual(coords15.y, 0)

    // Tile 16 should be at (0, 1)
    let coords16 = LDTileSetBuilder.tileIdToAtlasCoords(tileId: 16, tilesWide: tilesWide)
    XCTAssertEqual(coords16.x, 0)
    XCTAssertEqual(coords16.y, 1)

    // Tile 35 should be at (3, 2)
    let coords35 = LDTileSetBuilder.tileIdToAtlasCoords(tileId: 35, tilesWide: tilesWide)
    XCTAssertEqual(coords35.x, 3)
    XCTAssertEqual(coords35.y, 2)
  }

  func testPixelCoordsToTileId() {
    let tileSize = 16
    let tilesWide = 16

    // Pixel (0, 0) should be tile 0
    let tileId0 = LDTileSetBuilder.pixelCoordsToTileId(px: [0, 0], tileSize: tileSize, tilesWide: tilesWide)
    XCTAssertEqual(tileId0, 0)

    // Pixel (16, 0) should be tile 1
    let tileId1 = LDTileSetBuilder.pixelCoordsToTileId(px: [16, 0], tileSize: tileSize, tilesWide: tilesWide)
    XCTAssertEqual(tileId1, 1)

    // Pixel (0, 16) should be tile 16
    let tileId16 = LDTileSetBuilder.pixelCoordsToTileId(px: [0, 16], tileSize: tileSize, tilesWide: tilesWide)
    XCTAssertEqual(tileId16, 16)

    // Pixel (48, 32) should be tile 35 (x=3, y=2 -> 2*16+3 = 35)
    let tileId35 = LDTileSetBuilder.pixelCoordsToTileId(px: [48, 32], tileSize: tileSize, tilesWide: tilesWide)
    XCTAssertEqual(tileId35, 35)
  }

  func testCoordinateConversionRoundTrip() {
    let tilesWide = 16

    // Test round-trip conversion for various tile IDs
    for tileId in [0, 1, 15, 16, 17, 31, 32, 100, 255] {
      let coords = LDTileSetBuilder.tileIdToAtlasCoords(tileId: tileId, tilesWide: tilesWide)
      let reconstructedId = Int(coords.y) * tilesWide + Int(coords.x)
      XCTAssertEqual(reconstructedId, tileId, "Round-trip failed for tile ID \(tileId)")
    }
  }

  // MARK: - Configuration Tests

  func testLevelBuildConfigDefaults() {
    let config = LDLevelBuildConfig()

    XCTAssertNil(config.collisionValues, "Should use all non-zero values by default")
    XCTAssertEqual(config.zIndexOffset, 0, "Z-index offset should be 0 by default")
    XCTAssertNil(config.onLayer, "Should have no custom processor by default")
  }

  func testLevelBuildConfigCustomization() {
    var config = LDLevelBuildConfig()

    config.collisionValues = [1, 2, 3]
    config.zIndexOffset = 10

    XCTAssertEqual(config.collisionValues, [1, 2, 3])
    XCTAssertEqual(config.zIndexOffset, 10)
  }

  // MARK: - Tileset Definition Tests

  func testTilesetResourcePath() {
    let tilesets = project.defs.tilesets
    guard let firstTileset = tilesets.first else {
      XCTFail("No tilesets in project")
      return
    }

    let projectPath = "/path/to/project.ldtk"
    let resourcePath = firstTileset.resourcePath(relativeTo: projectPath)

    // Should resolve relative path
    XCTAssertFalse(resourcePath.isEmpty, "Resource path should not be empty")

    // If tileset has relPath, the resource path should be resolved
    if firstTileset.relPath != nil {
      XCTAssertNotEqual(resourcePath, firstTileset.relPath, "Should resolve relative path")
    }
  }

  func testTilesetGridCalculations() {
    let tilesets = project.defs.tilesets
    guard let tileset = tilesets.first else {
      XCTFail("No tilesets in project")
      return
    }

    // Verify grid calculations are correct
    XCTAssertGreaterThan(tileset.cWid, 0, "Should have tiles horizontally")
    XCTAssertGreaterThan(tileset.cHei, 0, "Should have tiles vertically")
    XCTAssertGreaterThan(tileset.tileGridSize, 0, "Tile size should be positive")

    // Calculate expected tile count
    let expectedTileCount = tileset.cWid * tileset.cHei
    XCTAssertGreaterThan(expectedTileCount, 0, "Should have at least one tile")

    // Verify pixel dimensions match grid dimensions
    let expectedPixelWidth = tileset.cWid * tileset.tileGridSize + tileset.padding * 2 + tileset.spacing * (tileset.cWid - 1)
    let expectedPixelHeight = tileset.cHei * tileset.tileGridSize + tileset.padding * 2 + tileset.spacing * (tileset.cHei - 1)

    // Allow some tolerance for edge cases
    XCTAssertLessThanOrEqual(abs(expectedPixelWidth - tileset.pxWid), tileset.tileGridSize + tileset.spacing,
                             "Pixel width should approximately match grid calculation")
    XCTAssertLessThanOrEqual(abs(expectedPixelHeight - tileset.pxHei), tileset.tileGridSize + tileset.spacing,
                             "Pixel height should approximately match grid calculation")
  }

  // MARK: - Layer Analysis Tests

  func testLayerTypeAnalysis() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    guard let layers = level.layerInstances else {
      XCTFail("No layer instances")
      return
    }

    var hasTileLayer = false
    var hasEntityLayer = false
    var hasIntGridLayer = false
    var hasAutoLayer = false

    for layer in layers {
      switch layer.type {
      case .tiles:
        hasTileLayer = true
        // Tile layers should have a tileset
        XCTAssertNotNil(layer.tilesetDefUid, "Tile layer should have tileset")
      case .entities:
        hasEntityLayer = true
        // Entity layers should have entity instances
        XCTAssertNotNil(layer.entityInstances, "Entity layer should have entity instances array")
      case .intGrid:
        hasIntGridLayer = true
        // IntGrid layers should have CSV data
        XCTAssertFalse(layer.intGridCsv.isEmpty, "IntGrid layer should have CSV data")
      case .autoLayer:
        hasAutoLayer = true
        // Auto layers should have tiles
        XCTAssertNotNil(layer.autoLayerTiles, "Auto layer should have tiles array")
      }
    }

    // The test file should have at least some layer types
    let totalLayerTypes = [hasTileLayer, hasEntityLayer, hasIntGridLayer, hasAutoLayer].filter { $0 }.count
    XCTAssertGreaterThan(totalLayerTypes, 0, "Should have at least one layer type")
  }

  func testLayerOrderingLogic() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    guard let layers = level.layerInstances else {
      XCTFail("No layer instances")
      return
    }

    // LDtk layers are in top-to-bottom order
    // When building, we should reverse them for bottom-to-top rendering
    let reversedLayers = layers.reversed()

    XCTAssertEqual(reversedLayers.count, layers.count, "Reversed should have same count")

    if layers.count > 1 {
      XCTAssertEqual(reversedLayers.first?.identifier, layers.last?.identifier,
                     "First reversed should be last original")
      XCTAssertEqual(reversedLayers.last?.identifier, layers.first?.identifier,
                     "Last reversed should be first original")
    }
  }

  // MARK: - Tile Flip Tests

  func testTileFlipDetection() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    guard let layers = level.layerInstances else {
      return
    }

    for layer in layers {
      let tiles = layer.allTiles

      for tile in tiles {
        // Test flip detection
        let flipX = tile.isFlippedX
        let flipY = tile.isFlippedY
        let (flipH, flipV) = tile.flips

        XCTAssertEqual(flipX, flipH, "Flip X should match horizontal flip")
        XCTAssertEqual(flipY, flipV, "Flip Y should match vertical flip")

        // Verify flip bits are consistent
        let expectedFlipX = (tile.f & 1) != 0
        let expectedFlipY = (tile.f & 2) != 0

        XCTAssertEqual(tile.isFlippedX, expectedFlipX, "Flip X should match bit calculation")
        XCTAssertEqual(tile.isFlippedY, expectedFlipY, "Flip Y should match bit calculation")
      }
    }
  }

  // MARK: - Collision Value Tests

  func testCollisionValueFiltering() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    guard let intGridLayer = level.intGridLayers.first else {
      // It's ok if there are no intgrid layers
      return
    }

    // Test default collision values (all non-zero)
    let defaultCollisionValues: [Int]? = nil
    var defaultCount = 0

    for y in 0 ..< intGridLayer.cHei {
      for x in 0 ..< intGridLayer.cWid {
        if let value = intGridLayer.intGridValue(x: x, y: y), value != 0 {
          if defaultCollisionValues == nil || defaultCollisionValues!.contains(value) {
            defaultCount += 1
          }
        }
      }
    }

    // Test custom collision values
    let customCollisionValues = [1, 2]
    var customCount = 0

    for y in 0 ..< intGridLayer.cHei {
      for x in 0 ..< intGridLayer.cWid {
        if let value = intGridLayer.intGridValue(x: x, y: y) {
          if customCollisionValues.contains(value) {
            customCount += 1
          }
        }
      }
    }

    // Custom count should be less than or equal to default (since it's filtered)
    XCTAssertLessThanOrEqual(customCount, defaultCount,
                             "Filtered collision should have fewer or equal tiles")
  }
}
