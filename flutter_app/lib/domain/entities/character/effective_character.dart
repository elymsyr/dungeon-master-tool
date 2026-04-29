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

/// One resolved class/subclass feature row, attached to a specific source
/// entity at a specific level threshold.
@freezed
abstract class ResolvedFeatureRow with _$ResolvedFeatureRow {
  const factory ResolvedFeatureRow({
    required int level,
    required String name,
    @Default('') String kind,
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
    @Default([]) List<String> warnings,
  }) = _EffectiveCharacter;

  factory EffectiveCharacter.fromJson(Map<String, dynamic> json) =>
      _$EffectiveCharacterFromJson(json);
}
