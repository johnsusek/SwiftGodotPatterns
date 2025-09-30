import Foundation

/// Data-driven definition for an ability (spell/skill/action).
///
/// Abilities declare their presentation, costs, targeting, and a sequence of
/// effects to apply when executed. Runtime systems interpret these effects and
/// drive visuals, audio, and gameplay changes.
public struct AbilityType: GameTypeSpec {
  public var id: String
  public var name: String
  public var summary: String?
  public var tags: Set<String>
  /// Icon identifier or path. Interpretation is engine-specific.
  public var icon: String?
  /// Cooldown in seconds after a successful cast/activation.
  public var cooldown: Double
  /// Resource costs that must be paid to activate the ability.
  public var costs: [ResourceCost]
  /// Targeting constraints/mode for this ability.
  public var targeting: TargetingSpec
  /// Ordered list of effects the runtime will apply when the ability resolves.
  public var effects: [AbilityEffect]

  /// Creates a new ability definition.
  public init(id: String,
              name: String,
              summary: String? = nil,
              tags: Set<String> = [],
              icon: String? = nil,
              cooldown: Double = 0,
              costs: [ResourceCost] = [],
              targeting: TargetingSpec,
              effects: [AbilityEffect])
  {
    self.id = id
    self.name = name
    self.summary = summary
    self.tags = tags
    self.icon = icon
    self.cooldown = cooldown
    self.costs = costs
    self.targeting = targeting
    self.effects = effects
  }
}
