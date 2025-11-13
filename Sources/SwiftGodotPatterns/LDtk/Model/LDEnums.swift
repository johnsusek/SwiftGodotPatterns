import Foundation
import SwiftGodot

// MARK: - Layer Types

/// Type of layer in LD
public enum LDLayerType: String, Codable {
  case intGrid = "IntGrid"
  case entities = "Entities"
  case tiles = "Tiles"
  case autoLayer = "AutoLayer"
}

// MARK: - World Layout

/// How levels are organized in the world
public enum LDWorldLayout: String, Codable {
  case free = "Free"
  case gridVania = "GridVania"
  case linearHorizontal = "LinearHorizontal"
  case linearVertical = "LinearVertical"
}

// MARK: - Entity Render Mode

/// How entity tiles are rendered
public enum LDEntityRenderMode: String, Codable {
  case rectangle = "Rectangle"
  case ellipse = "Ellipse"
  case tile = "Tile"
  case cross = "Cross"
}

/// How entity tiles are rendered within bounds
public enum LDTileRenderMode: String, Codable {
  case cover = "Cover"
  case fitInside = "FitInside"
  case `repeat` = "Repeat"
  case stretch = "Stretch"
  case fullSizeCropped = "FullSizeCropped"
  case fullSizeUncropped = "FullSizeUncropped"
  case nineSlice = "NineSlice"
}

// MARK: - Background Position

/// How level background is positioned
public enum LDBgPos: String, Codable {
  case unscaled = "Unscaled"
  case contain = "Contain"
  case cover = "Cover"
  case coverDirty = "CoverDirty"
  case `repeat` = "Repeat"
}

// MARK: - Image Export Mode

/// Image export settings
public enum LDImageExportMode: String, Codable {
  case none = "None"
  case oneImagePerLayer = "OneImagePerLayer"
  case oneImagePerLevel = "OneImagePerLevel"
  case layersAndLevels = "LayersAndLevels"
}

// MARK: - Identifier Style

/// Naming convention for identifiers
public enum LDIdentifierStyle: String, Codable {
  case capitalize = "Capitalize"
  case uppercase = "Uppercase"
  case lowercase = "Lowercase"
  case free = "Free"
}

// MARK: - Limit Scope

/// Scope for entity count limits
public enum LDLimitScope: String, Codable {
  case perLayer = "PerLayer"
  case perLevel = "PerLevel"
  case perWorld = "PerWorld"
}

// MARK: - Limit Behavior

/// Behavior when entity limit is reached
public enum LDLimitBehavior: String, Codable {
  case discardOldOnes = "DiscardOldOnes"
  case preventAdding = "PreventAdding"
  case moveLastOne = "MoveLastOne"
}
