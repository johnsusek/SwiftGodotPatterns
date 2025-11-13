@testable import SwiftGodotPatterns
import XCTest

final class LDLayerTests: XCTestCase {
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

  // MARK: - Layer Computed Properties

  func testLayerDefOffsets() {
    let layers = project.defs.layers

    for layer in layers {
      let offset = layer.offset
      XCTAssertEqual(offset.x, Float(layer.pxOffsetX))
      XCTAssertEqual(offset.y, Float(layer.pxOffsetY))
    }
  }

  func testLayerDefParallax() {
    let layers = project.defs.layers

    for layer in layers {
      let parallax = layer.parallaxFactor
      XCTAssertEqual(parallax.x, Float(layer.parallaxFactorX))
      XCTAssertEqual(parallax.y, Float(layer.parallaxFactorY))
    }
  }

  // MARK: - Layer Instances

  func testLevelHasLayerInstances() {
    XCTAssertNotNil(level.layerInstances)
    XCTAssertFalse(level.layerInstances?.isEmpty ?? true)
  }

  func testLayerInstanceTypes() {
    guard let layers = level.layerInstances else {
      XCTFail("No layer instances")
      return
    }

    for layer in layers {
      XCTAssertFalse(layer.identifier.isEmpty)
      XCTAssertGreaterThan(layer.gridSize, 0)
      XCTAssertGreaterThan(layer.cWid, 0)
      XCTAssertGreaterThan(layer.cHei, 0)
    }
  }

  func testLayerInstanceOffset() {
    guard let layers = level.layerInstances else {
      XCTFail("No layer instances")
      return
    }

    for layer in layers {
      let offset = layer.totalOffset
      XCTAssertEqual(offset.x, Float(layer.pxTotalOffsetX))
      XCTAssertEqual(offset.y, Float(layer.pxTotalOffsetY))
    }
  }

  func testLayerInstancePixelSize() {
    guard let layers = level.layerInstances else {
      XCTFail("No layer instances")
      return
    }

    for layer in layers {
      let size = layer.pixelSize
      let expectedWidth = Float(layer.cWid * layer.gridSize)
      let expectedHeight = Float(layer.cHei * layer.gridSize)

      XCTAssertEqual(size.x, expectedWidth, accuracy: 0.01)
      XCTAssertEqual(size.y, expectedHeight, accuracy: 0.01)
    }
  }

  func testLayerInstanceGridSize() {
    guard let layers = level.layerInstances else {
      XCTFail("No layer instances")
      return
    }

    for layer in layers {
      let gridSize = layer.gridSizeVector
      XCTAssertEqual(gridSize.x, Int32(layer.cWid))
      XCTAssertEqual(gridSize.y, Int32(layer.cHei))
    }
  }

  // MARK: - IntGrid Layer

  func testIntGridValueAt() {
    let intGridLayer = level.layerInstances?.first(where: { $0.type == .intGrid })

    guard let layer = intGridLayer else {
      return
    }

    // Test valid coordinates
    let value = layer.intGridValue(x: 0, y: 0)
    XCTAssertNotNil(value)

    // Test invalid coordinates
    let invalidValue = layer.intGridValue(x: -1, y: -1)
    XCTAssertNil(invalidValue)

    let outOfBounds = layer.intGridValue(x: layer.cWid + 10, y: layer.cHei + 10)
    XCTAssertNil(outOfBounds)
  }

  func testIntGridValueAtIndex() {
    let intGridLayer = level.layerInstances?.first(where: { $0.type == .intGrid })

    guard let layer = intGridLayer else {
      return
    }

    // Test first index
    let firstValue = layer.intGridValue(at: 0)
    XCTAssertNotNil(firstValue)

    // Test invalid index
    let invalidValue = layer.intGridValue(at: -1)
    XCTAssertNil(invalidValue)

    let outOfBounds = layer.intGridValue(at: layer.intGridCsv.count + 100)
    XCTAssertNil(outOfBounds)
  }

  func testIntGridCoordinateConversion() {
    let intGridLayer = level.layerInstances?.first(where: { $0.type == .intGrid })

    guard let layer = intGridLayer else {
      return
    }

    // Test grid to index
    if let index = layer.gridToIndex(x: 5, y: 3) {
      XCTAssertEqual(index, 3 * layer.cWid + 5)

      // Test index back to grid
      if let (x, y) = layer.indexToGrid(index) {
        XCTAssertEqual(x, 5)
        XCTAssertEqual(y, 3)
      } else {
        XCTFail("Failed to convert index back to grid")
      }
    }
  }

  func testIntGrid2D() {
    let intGridLayer = level.layerInstances?.first(where: { $0.type == .intGrid })

    guard let layer = intGridLayer else {
      return
    }

    let grid2D = layer.intGrid2D

    XCTAssertEqual(grid2D.count, layer.cHei)
    for row in grid2D {
      XCTAssertEqual(row.count, layer.cWid)
    }

    // Verify values match
    for y in 0 ..< layer.cHei {
      for x in 0 ..< layer.cWid {
        let value2D = grid2D[y][x]
        let valueFlat = layer.intGridValue(x: x, y: y)
        XCTAssertEqual(value2D, valueFlat)
      }
    }
  }

  // MARK: - Tile Layers

  func testTileLayerTiles() {
    let tileLayer = level.layerInstances?.first(where: { $0.type == .tiles || $0.type == .autoLayer })

    guard let layer = tileLayer else {
      // Ok if no tile layers
      return
    }

    let allTiles = layer.allTiles
    // Should combine auto-layer and grid tiles
    XCTAssertEqual(allTiles.count, layer.autoLayerTiles.count + layer.gridTiles.count)
  }

  func testTileProperties() {
    let tileLayer = level.layerInstances?.first(where: { $0.type == .tiles || $0.type == .autoLayer })

    guard let layer = tileLayer, !layer.allTiles.isEmpty else {
      return
    }

    for tile in layer.allTiles {
      // Test position
      let pos = tile.position
      XCTAssertEqual(pos.x, Float(tile.px[0]))
      XCTAssertEqual(pos.y, Float(tile.px[1]))

      // Test source position
      let srcPos = tile.sourcePosition
      XCTAssertEqual(srcPos.x, Float(tile.src[0]))
      XCTAssertEqual(srcPos.y, Float(tile.src[1]))

      // Test flips
      let (flipH, flipV) = tile.flips
      XCTAssertEqual(flipH, tile.isFlippedX)
      XCTAssertEqual(flipV, tile.isFlippedY)
    }
  }

  // MARK: - Level Layer Queries

  func testLevelLayerByIdentifier() {
    let layerIdentifier = level.layerInstances?.first?.identifier
    XCTAssertNotNil(layerIdentifier)

    let foundLayer = level.layer(layerIdentifier!)
    XCTAssertNotNil(foundLayer)
    XCTAssertEqual(foundLayer?.identifier, layerIdentifier)
  }

  func testLevelLayersByType() {
    let entityLayers = level.layers(ofType: .entities)
    let tileLayers = level.layers(ofType: .tiles)
    let intGridLayers = level.layers(ofType: .intGrid)
    let autoLayers = level.layers(ofType: .autoLayer)

    // At least one of these should have layers
    let totalLayers = entityLayers.count + tileLayers.count + intGridLayers.count + autoLayers.count
    XCTAssertGreaterThan(totalLayers, 0)
  }

  func testLevelEntityLayers() {
    let entityLayers = level.entityLayers
    XCTAssertFalse(entityLayers.isEmpty, "Should have at least one entity layer")

    for layer in entityLayers {
      XCTAssertEqual(layer.type, .entities)
    }
  }

  func testLevelTileLayers() {
    let tileLayers = level.tileLayers

    for layer in tileLayers {
      XCTAssertEqual(layer.type, .tiles)
    }
  }

  func testLevelIntGridLayers() {
    let intGridLayers = level.intGridLayers

    for layer in intGridLayers {
      XCTAssertEqual(layer.type, .intGrid)
    }
  }

  func testLevelAutoLayers() {
    let autoLayers = level.autoLayers

    for layer in autoLayers {
      XCTAssertEqual(layer.type, .autoLayer)
    }
  }

  // MARK: - IntGrid Value Definitions

  func testIntGridValueDefinition() {
    let intGridLayerDef = project.defs.layers.first(where: { $0.type == .intGrid })

    guard let layerDef = intGridLayerDef, !layerDef.intGridValues.isEmpty else {
      return
    }

    for valueDef in layerDef.intGridValues {
      XCTAssertGreaterThanOrEqual(valueDef.value, 0)
      XCTAssertFalse(valueDef.color.isEmpty)
    }
  }
}
