import Foundation

/// Data-driven description of an item.
///
/// - SeeAlso: ``ItemSlot``, ``AbilityType``
public struct ItemType: GameTypeSpec {
  public var id: String
  public var name: String
  public var summary: String?
  public var tags: Set<String>
  /// Icon identifier or path. Interpretation is engine-specific.
  public var icon: String?
  /// Equipment slot this item occupies (or `.none`).
  public var slot: ItemSlot
  /// Maximum stack size when in inventory (min 1).
  public var stackMax: Int
  /// Vendor or drop value (economy scale is game-specific).
  public var value: Int
  /// Optional rarity string (e.g. `"common"`, `"legendary"`).
  public var rarity: String?
  /// Passive stat bonuses granted while equipped.
  public var equipBonuses: [StatMod]
  /// If set, using the item triggers this ability.
  public var onUseAbilityId: String?

  /// Creates a new item definition.
  public init(id: String,
              name: String,
              summary: String? = nil,
              tags: Set<String> = [],
              icon: String? = nil,
              slot: ItemSlot = .none,
              stackMax: Int = 1,
              value: Int = 0,
              rarity: String? = nil,
              equipBonuses: [StatMod] = [],
              onUseAbilityId: String? = nil)
  {
    self.id = id
    self.name = name
    self.summary = summary
    self.tags = tags
    self.icon = icon
    self.slot = slot
    self.stackMax = max(1, stackMax)
    self.value = value
    self.rarity = rarity
    self.equipBonuses = equipBonuses
    self.onUseAbilityId = onUseAbilityId
  }
}
