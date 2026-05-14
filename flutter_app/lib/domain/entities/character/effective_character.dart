import 'package:freezed_annotation/freezed_annotation.dart';

part 'effective_character.freezed.dart';
part 'effective_character.g.dart';

/// One resolved item line on the effective inventory.
/// `source` is a free-form tag like `class:Fighter:option:A`,
/// `background:Soldier`, `feat:Magic Initiate`.
@freezed
abstract class ResolvedInventoryItem with _$ResolvedInventoryItem {
  const factory ResolvedInventoryItem({
    required String entityId,
    @Default(1) int quantity,
    @Default('') String source,
  }) = _ResolvedInventoryItem;

  factory ResolvedInventoryItem.fromJson(Map<String, dynamic> json) =>
      _$ResolvedInventoryItemFromJson(json);
}

/// One resolved class/subclass level upgrade row — narrative summary line.
/// Mechanics are applied via auto-grant on the Feat/Trait entity, not via
/// this row.
@freezed
abstract class ResolvedFeatureRow with _$ResolvedFeatureRow {
  const factory ResolvedFeatureRow({
    required int level,
    @Default('') String description,
    @Default('') String sourceEntityId,
  }) = _ResolvedFeatureRow;

  factory ResolvedFeatureRow.fromJson(Map<String, dynamic> json) =>
      _$ResolvedFeatureRowFromJson(json);
}

/// Aggregated proficiency set after applying class/background/species/feat grants.
@freezed
abstract class ResolvedProficiencies with _$ResolvedProficiencies {
  const factory ResolvedProficiencies({
    @Default([]) List<String> skillIds,
    @Default([]) List<String> toolIds,
    @Default([]) List<String> savingThrowAbilityIds,
    @Default([]) List<String> languageIds,
    @Default([]) List<String> weaponCategoryIds,
    @Default([]) List<String> armorCategoryIds,
  }) = _ResolvedProficiencies;

  factory ResolvedProficiencies.fromJson(Map<String, dynamic> json) =>
      _$ResolvedProficienciesFromJson(json);
}

/// Read-time computed view of a [Character]. Produced by [CharacterResolver].
/// Never persisted — recompute on every read.
@freezed
abstract class EffectiveCharacter with _$EffectiveCharacter {
  const factory EffectiveCharacter({
    required String characterId,
    @Default({}) Map<String, int> classLevels,
    String? subclassId,
    @Default([]) List<String> featIds,
    @Default({'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10})
    Map<String, int> effectiveAbilities,
    @Default(ResolvedProficiencies()) ResolvedProficiencies proficiencies,
    @Default(0) int acBonus,
    @Default(0) int speedBonus,
    /// Non-walking speeds in feet, keyed by mode (`fly`, `swim`, `climb`,
    /// `burrow`). Populated by effects like `climb_speed_equals_speed`
    /// (Spider Climb, Second-Story Work) and explicit `fly_speed` payloads
    /// (Dragon Wings). The sheet renders one row per mode. A `0` value is a
    /// no-op — the resolver only writes positive entries. When two sources
    /// supply the same mode, the larger value wins.
    @Default({}) Map<String, int> extraSpeeds,
    @Default(0) int hpBonusFlat,
    @Default(0) int hpBonusPerLevel,
    @Default(0) int initiativeBonus,
    @Default([]) List<String> grantedSpellIds,
    @Default([]) List<String> grantedCantripIds,
    @Default([]) List<ResolvedFeatureRow> activeFeatures,
    @Default([]) List<ResolvedInventoryItem> inventory,
    @Default([]) List<String> senseEntityIds,
    /// Per-sense range overrides in feet, keyed by sense entity id. Populated
    /// by `sense_grant` / `truesight_grant` / `blindsight_grant` effects that
    /// carry a `range_ft` payload (Drow Superior Darkvision 120ft, Boon of
    /// Truesight 60ft). When two sources grant the same sense the larger
    /// range wins. Senses without an explicit range stay out of this map —
    /// the sheet falls back to the sense entity's intrinsic default.
    @Default({}) Map<String, int> senseRanges,
    @Default([]) List<String> damageResistanceIds,
    @Default([]) List<String> damageImmunityIds,
    @Default([]) List<String> damageVulnerabilityIds,
    @Default([]) List<String> conditionImmunityIds,
    /// Grants that only apply while the character is in a runtime state
    /// (Raging, Wild Shape, Aura active, etc.). Resolver routes effect rows
    /// here when the `has_state` predicate is the only failing predicate.
    /// Each entry: `{state: String, kind: String, ids: [String], source:
    /// String}` — `kind` matches the original effect kind (`damage_resistance`,
    /// `condition_immunity_grant`, ...). Sheet renders these as gated chips
    /// alongside the always-on lists; combat tracker flips them on/off when
    /// the state engages.
    @Default([]) List<Map<String, dynamic>> conditionalGrants,
    /// Sources that grant temp HP via a trigger (rest, attack hit, kill,
    /// etc.). Resolver collects every `temp_hp_grant` effect row that passes
    /// non-state predicates and stores the source + raw effect map for the
    /// sheet to render as text. The actual write to `temp_hp` happens
    /// runtime — combat tracker / button press — not here.
    @Default([]) List<Map<String, dynamic>> tempHpGrants,
    @Default([]) List<String> expertiseSkillIds,
    @Default([]) List<String> alwaysPreparedSpellIds,
    /// Feat IDs auto-granted by class level / species / background that the
    /// character did NOT explicitly pick. Resolver applies their effects but
    /// surfaces them separately so the UI can render them under "Class
    /// Features" rather than "Chosen Feats".
    @Default([]) List<String> autoGrantedFeatIds,
    /// Trait IDs auto-granted by class level / species / background via
    /// `auto_granted_by`. Traits carry no mechanical effects; this list
    /// drives display of narrative class/species/background features (e.g.
    /// Druidic, Thieves' Cant, Fey Ancestry) on the character sheet.
    @Default([]) List<String> autoGrantedTraitIds,
    /// Creature-action IDs auto-granted by species / subspecies via
    /// `granted_action_refs`. Surfaced to the sheet under the Actions
    /// section so racial actions (e.g. Dragonborn Breath Weapon) render
    /// alongside class actions.
    @Default([]) List<String> grantedActionIds,
    /// Creature-action IDs granted as bonus actions (e.g. Orc Adrenaline
    /// Rush, Wood Elf bonus speeds). Sourced from
    /// `granted_bonus_action_refs` on species + subspecies rows.
    @Default([]) List<String> grantedBonusActionIds,
    /// Creature-action IDs granted as reactions (e.g. Orc Relentless
    /// Endurance, Goliath Stone's Endurance). Sourced from
    /// `granted_reaction_refs` on species + subspecies rows.
    @Default([]) List<String> grantedReactionIds,
    /// Unarmored AC formulas registered by feats with `unarmored_ac_formula`
    /// effects whose predicates are satisfied. Each entry is the raw effect
    /// row preserved as-is so downstream UI can read `payload.base`,
    /// `payload.ability_mods`, `payload.shield_allowed`. Final AC composition
    /// (max of armored AC vs each formula) is the consumer's job.
    @Default([]) List<Map<String, dynamic>> unarmoredFormulas,
    /// Max extra-attack count (e.g. 2 / 3 / 4). Multiclass takes the max,
    /// not the sum (Fighter L11 + Barbarian L5 = 3 attacks, not 5).
    @Default(0) int extraAttackCount,
    /// Crit threshold floor. Default 20; Champion-style features lower this.
    @Default(20) int critRangeMin,
    /// Resource pools whose max was computed at resolve time. Runtime tracks
    /// `current` separately on the character. Each entry: `{pool_ref, max,
    /// recharge}`.
    @Default([]) List<Map<String, dynamic>> resourcePools,
    /// For each granted entity id (sense / damage_res / immunity / vuln /
    /// condition_immunity), the list of human-readable source names that
    /// produced it. Used by the sheet's `ResolvedGrantsCard` to render
    /// chips like "Poison Resistance — Dwarf". Same id appearing from
    /// multiple sources lists each source once, in apply order.
    @Default({}) Map<String, List<String>> grantSources,
    @Default([]) List<String> warnings,
  }) = _EffectiveCharacter;

  factory EffectiveCharacter.fromJson(Map<String, dynamic> json) =>
      _$EffectiveCharacterFromJson(json);
}
