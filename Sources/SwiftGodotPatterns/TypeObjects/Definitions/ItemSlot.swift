import Foundation

/// Equipment or consumable definition authored as data.
///
/// Items specify their slot (if any), stackability, value/rarity for loot
/// tables, passive equip bonuses, and an optional on-use ability.
///
/// - Note: `slot == .none` is allowed for generic loot or crafting items.
public enum ItemSlot: String, Codable, Sendable {
  case none
  case head
  case chest
  case legs
  case mainHand
  case offHand
  case ring
  case amulet
  case consumable
}
