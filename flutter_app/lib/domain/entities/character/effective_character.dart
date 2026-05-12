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
    @Default(0) int hpBonusFlat,
    @Default(0) int hpBonusPerLevel,
    @Default(0) int initiativeBonus,
    @Default([]) List<String> grantedSpellIds,
    @Default([]) List<String> grantedCantripIds,
    @Default([]) List<ResolvedFeatureRow> activeFeatures,
    @Default([]) List<ResolvedInventoryItem> inventory,
    @Default([]) List<String> senseEntityIds,
    @Default([]) List<String> damageResistanceIds,
    @Default([]) List<String> damageImmunityIds,
    @Default([]) List<String> damageVulnerabilityIds,
    @Default([]) List<String> conditionImmunityIds,
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
    @Default([]) List<String> warnings,
  }) = _EffectiveCharacter;

  factory EffectiveCharacter.fromJson(Map<String, dynamic> json) =>
      _$EffectiveCharacterFromJson(json);
}
