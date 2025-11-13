@testable import SwiftGodotPatterns
import XCTest

final class LDEntityMappingTests: XCTestCase {
  var project: LDProject!
  var registry: LDEntityMapperRegistry!

  override func setUp() {
    super.setUp()

    // Load test project
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

    // Create fresh registry for each test
    registry = LDEntityMapperRegistry()
  }

  override func tearDown() {
    registry = nil
    super.tearDown()
  }

  // MARK: - Registry Tests

  func testRegistryInitialization() {
    XCTAssertNotNil(registry, "Registry should initialize")
  }

  func testRegisterClosureMapper() {
    // Register a mapper
    registry.register(identifier: "Player") { _, _ in
      nil // Mock implementation
    }

    XCTAssertTrue(registry.hasMapper(for: "Player"), "Should have registered mapper")
    XCTAssertNotNil(registry.mapper(for: "Player"), "Should return registered mapper")
  }

  func testUnregisterMapper() {
    // Register and then unregister
    registry.register(identifier: "Enemy") { _, _ in
      nil
    }

    XCTAssertTrue(registry.hasMapper(for: "Enemy"))

    registry.unregister("Enemy")

    XCTAssertFalse(registry.hasMapper(for: "Enemy"), "Should have unregistered mapper")
    XCTAssertNil(registry.mapper(for: "Enemy"), "Should return nil after unregister")
  }

  func testClearAllMappers() {
    // Register multiple mappers
    registry.register(identifier: "Player") { _, _ in nil }
    registry.register(identifier: "Enemy") { _, _ in nil }
    registry.register(identifier: "Item") { _, _ in nil }

    XCTAssertTrue(registry.hasMapper(for: "Player"))
    XCTAssertTrue(registry.hasMapper(for: "Enemy"))
    XCTAssertTrue(registry.hasMapper(for: "Item"))

    registry.clearAll()

    XCTAssertFalse(registry.hasMapper(for: "Player"), "All mappers should be cleared")
    XCTAssertFalse(registry.hasMapper(for: "Enemy"), "All mappers should be cleared")
    XCTAssertFalse(registry.hasMapper(for: "Item"), "All mappers should be cleared")
  }

  func testDefaultMapper() {
    // Set a default mapper
    let defaultMapper = LDDefaultEntityMapper()
    registry.defaultMapper = defaultMapper

    // Should return default mapper for unmapped entity
    let mapper = registry.mapper(for: "UnmappedEntity")
    XCTAssertNotNil(mapper, "Should return default mapper")
    XCTAssertEqual(mapper?.entityIdentifier, "*", "Should be default mapper")
  }

  func testSpecificMapperOverridesDefault() {
    // Set default mapper
    registry.defaultMapper = LDDefaultEntityMapper()

    // Register specific mapper
    registry.register(identifier: "Player") { _, _ in nil }

    // Should return specific mapper, not default
    let mapper = registry.mapper(for: "Player")
    XCTAssertNotNil(mapper)
    XCTAssertEqual(mapper?.entityIdentifier, "Player", "Should return specific mapper")
  }

  // MARK: - Closure Mapper Tests

  func testClosureMapperIdentifier() {
    let mapper = LDClosureEntityMapper(identifier: "TestEntity") { _, _ in nil }

    XCTAssertEqual(mapper.entityIdentifier, "TestEntity", "Should store correct identifier")
  }

  // MARK: - Entity Build Configuration Tests

  func testEntityBuildConfigDefaults() {
    let config = LDEntityBuildConfig()

    XCTAssertTrue(config.createMarkersForUnmapped, "Should create markers by default")
    XCTAssertEqual(config.zIndexOffset, 11, "Z-index offset should be 11 by default")
    XCTAssertNil(config.entityFilter, "Should have no filter by default")
    XCTAssertNil(config.onSpawned, "Should have no post-processor by default")
  }

  func testEntityBuildConfigCustomization() {
    var config = LDEntityBuildConfig()

    config.createMarkersForUnmapped = false
    config.zIndexOffset = 10

    var filterCallCount = 0
    config.entityFilter = { _ in
      filterCallCount += 1
      return true
    }

    var processorCallCount = 0
    config.onSpawned = { _, _ in
      processorCallCount += 1
    }

    XCTAssertFalse(config.createMarkersForUnmapped)
    XCTAssertEqual(config.zIndexOffset, 10)
    XCTAssertNotNil(config.entityFilter)
    XCTAssertNotNil(config.onSpawned)

    // Test that closures can be called (though they won't be invoked by the test itself)
    // In real usage, these would be called by the entity builder
  }

  // MARK: - Entity Filtering Tests

  func testEntityFilteringLogic() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    let allEntities = level.allEntities

    // Test filter that accepts all
    let acceptAll = allEntities.filter { _ in true }
    XCTAssertEqual(acceptAll.count, allEntities.count, "Should accept all entities")

    // Test filter that rejects all
    let rejectAll = allEntities.filter { _ in false }
    XCTAssertEqual(rejectAll.count, 0, "Should reject all entities")

    // Test filter based on identifier
    if !allEntities.isEmpty {
      let firstIdentifier = allEntities[0].identifier
      let filtered = allEntities.filter { $0.identifier == firstIdentifier }
      XCTAssertGreaterThan(filtered.count, 0, "Should find at least one matching entity")
    }
  }

  // MARK: - Level Build Configuration Tests

  func testLevelConfigEntitySpawning() {
    var config = LDLevelBuildConfig()

    XCTAssertTrue(config.spawnEntities, "Should spawn entities by default")

    config.spawnEntities = true
    XCTAssertTrue(config.spawnEntities, "Should enable entity spawning")
  }

  func testLevelConfigEntityConfiguration() {
    var config = LDLevelBuildConfig()

    config.entityConfig.createMarkersForUnmapped = false
    config.entityConfig.zIndexOffset = 5

    XCTAssertFalse(config.entityConfig.createMarkersForUnmapped)
    XCTAssertEqual(config.entityConfig.zIndexOffset, 5)
  }

  // MARK: - Entity Instance Tests

  func testEntityInstanceData() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    let entities = level.allEntities

    for entity in entities {
      // All entities should have an identifier
      XCTAssertFalse(entity.identifier.isEmpty, "Entity should have identifier")

      // All entities should have an iid
      XCTAssertFalse(entity.iid.isEmpty, "Entity should have iid")

      // Position should be accessible
      let pos = entity.position
      XCTAssertNotNil(pos, "Entity should have position")

      // Field instances should be accessible
      XCTAssertNotNil(entity.fieldInstances, "Entity should have field instances array")
    }
  }

  func testEntityFieldAccess() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    let entities = level.allEntities

    for entity in entities {
      // Test that field accessors don't crash for non-existent fields
      _ = entity.field("nonexistent")?.asInt()
      _ = entity.field("nonexistent")?.asFloat()
      _ = entity.field("nonexistent")?.asBool()
      _ = entity.field("nonexistent")?.asString()
      // Skip color and vector2 for non-existent fields - they may crash without Godot runtime

      // If entity has fields, test accessing them
      for field in entity.fieldInstances {
        // Field identifier should not be empty
        XCTAssertFalse(field.identifier.isEmpty, "Field should have identifier")

        // Try accessing field by identifier (skip color/vector types due to Godot runtime requirement)
        switch field.value {
        case .int:
          XCTAssertNotNil(entity.field(field.identifier)?.asInt())
        case .float:
          XCTAssertNotNil(entity.field(field.identifier)?.asFloat())
        case .bool:
          XCTAssertNotNil(entity.field(field.identifier)?.asBool())
        case .string:
          XCTAssertNotNil(entity.field(field.identifier)?.asString())
        case .color:
          // Skip - requires Godot runtime
          break
        case .point:
          // Skip - requires Godot runtime
          break
        default:
          break
        }
      }
    }
  }

  // MARK: - Entity Layer Analysis Tests

  func testEntityLayerDetection() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    guard let layers = level.layerInstances else {
      XCTFail("No layer instances")
      return
    }

    let entityLayers = layers.filter { $0.type == .entities }

    for layer in entityLayers {
      XCTAssertEqual(layer.type, .entities, "Should be entity layer")
      XCTAssertNotNil(layer.entityInstances, "Entity layer should have entity instances array")
    }
  }

  func testEntityCountByLayer() {
    guard let level = project.levels.first else {
      XCTFail("No levels in project")
      return
    }

    let entityLayers = level.entityLayers

    var totalFromLayers = 0
    for layer in entityLayers {
      totalFromLayers += layer.entityInstances.count
    }

    let totalFromLevel = level.allEntities.count

    XCTAssertEqual(totalFromLayers, totalFromLevel,
                   "Total entities from layers should match level.allEntities")
  }

  // MARK: - Registry Thread Safety Tests

  func testSharedRegistryAccess() {
    let sharedRegistry = LDEntityMapperRegistry.shared

    XCTAssertNotNil(sharedRegistry, "Shared registry should be accessible")

    // Register a mapper
    sharedRegistry.register(identifier: "TestEntity") { _, _ in nil }

    XCTAssertTrue(sharedRegistry.hasMapper(for: "TestEntity"))

    // Clean up
    sharedRegistry.unregister("TestEntity")
  }

  // MARK: - Integration Test Markers

  func testIntegrationTestsRequireGodotRuntime() {
    // The following operations require Godot runtime and cannot be tested in unit tests:
    // - Creating actual Node2D instances from entity mappers
    // - Testing node hierarchy with spawned entities
    // - Verifying entity node positions in scene tree
    // - Testing entity metadata storage and retrieval
    // - Verifying post-processor node modifications
    // - Testing entity filtering with spawned nodes

    // For integration testing, these should be tested in a Godot project with:
    // 1. Register entity mappers
    // 2. Build level with spawnEntities = true
    // 3. Verify entities are spawned correctly
    // 4. Check entity positions and properties
    // 5. Test entity filtering and post-processing

    XCTAssertTrue(true, "Integration tests documented")
  }
}
