import '../catalog/content_reference.dart';
import '../core/ability_scores.dart';
import '../core/death_saves.dart';
import '../core/exhaustion.dart';
import '../core/hit_points.dart';
import '../core/proficiency_bonus.dart';
import 'character_class_level.dart';
import 'hit_dice_pool.dart';
import 'inventory.dart';
import 'pact_magic_slots.dart';
import 'prepared_spells.dart';
import 'proficiency_set.dart';
import 'spell_slots.dart';

/// Tier 1 root entity: player character. Holds the full runtime picture —
/// definitional refs (species, classes, background), state (hp, exhaustion,
/// spell slots), and bookkeeping (XP, inspiration). Derived values
/// ([totalLevel], [proficiencyBonus]) are pure getters.
class Character {
  final String id;
  final String name;
  final List<CharacterClassLevel> classLevels;
  final String speciesId;
  final String? lineageId;
  final String backgroundId;
  final String alignmentId;
  final AbilityScores abilities;
  final ProficiencySet proficiencies;
  final HitPoints hp;
  final HitDicePool hitDice;
  final SpellSlots spellSlots;
  final PactMagicSlots? pactSlots;
  final PreparedSpells preparedSpells;
  final Inventory inventory;
  final List<String> featIds;
  final Set<String> activeConditionIds;
  final Map<String, int> conditionDurationsRounds;
  final Exhaustion exhaustion;
  final DeathSaves deathSaves;
  final bool hasInspiration;
  final int experiencePoints;
  final Set<String> languageIds;

  Character._({
    required this.id,
    required this.name,
    required this.classLevels,
    required this.speciesId,
    required this.lineageId,
    required this.backgroundId,
    required this.alignmentId,
    required this.abilities,
    required this.proficiencies,
    required this.hp,
    required this.hitDice,
    required this.spellSlots,
    required this.pactSlots,
    required this.preparedSpells,
    required this.inventory,
    required this.featIds,
    required this.activeConditionIds,
    required this.conditionDurationsRounds,
    required this.exhaustion,
    required this.deathSaves,
    required this.hasInspiration,
    required this.experiencePoints,
    required this.languageIds,
  });

  factory Character({
    required String id,
    required String name,
    required List<CharacterClassLevel> classLevels,
    required ContentReference speciesId,
    ContentReference? lineageId,
    required ContentReference backgroundId,
    required ContentReference alignmentId,
    required AbilityScores abilities,
    ProficiencySet? proficiencies,
    required HitPoints hp,
    HitDicePool? hitDice,
    SpellSlots? spellSlots,
    PactMagicSlots? pactSlots,
    PreparedSpells? preparedSpells,
    Inventory? inventory,
    List<ContentReference> featIds = const [],
    Set<ContentReference> activeConditionIds = const {},
    Map<ContentReference, int> conditionDurationsRounds = const {},
    Exhaustion? exhaustion,
    DeathSaves? deathSaves,
    bool hasInspiration = false,
    int experiencePoints = 0,
    Set<ContentReference> languageIds = const {},
  }) {
    if (id.isEmpty) throw ArgumentError('Character.id must not be empty');
    if (name.isEmpty) throw ArgumentError('Character.name must not be empty');
    if (classLevels.isEmpty) {
      throw ArgumentError('Character.classLevels must have at least one entry');
    }
    final total = classLevels.fold<int>(0, (s, c) => s + c.level);
    if (total > 20) {
      throw ArgumentError('Character total level $total exceeds SRD cap of 20');
    }
    validateContentId(speciesId);
    if (lineageId != null) validateContentId(lineageId);
    validateContentId(backgroundId);
    validateContentId(alignmentId);
    for (final id in featIds) {
      validateContentId(id);
    }
    for (final id in activeConditionIds) {
      validateContentId(id);
    }
    for (final id in conditionDurationsRounds.keys) {
      validateContentId(id);
    }
    for (final id in languageIds) {
      validateContentId(id);
    }
    if (experiencePoints < 0) {
      throw ArgumentError('Character.experiencePoints must be >= 0');
    }

    return Character._(
      id: id,
      name: name,
      classLevels: List.unmodifiable(classLevels),
      speciesId: speciesId,
      lineageId: lineageId,
      backgroundId: backgroundId,
      alignmentId: alignmentId,
      abilities: abilities,
      proficiencies: proficiencies ?? ProficiencySet.empty(),
      hp: hp,
      hitDice: hitDice ?? HitDicePool.empty(),
      spellSlots: spellSlots ?? SpellSlots.empty(),
      pactSlots: pactSlots,
      preparedSpells: preparedSpells ?? PreparedSpells.empty(),
      inventory: inventory ?? Inventory.empty(),
      featIds: List.unmodifiable(featIds),
      activeConditionIds: Set.unmodifiable(activeConditionIds),
      conditionDurationsRounds: Map.unmodifiable(conditionDurationsRounds),
      exhaustion: exhaustion ?? Exhaustion(0),
      deathSaves: deathSaves ?? DeathSaves.zero,
      hasInspiration: hasInspiration,
      experiencePoints: experiencePoints,
      languageIds: Set.unmodifiable(languageIds),
    );
  }

  int get totalLevel =>
      classLevels.fold<int>(0, (s, c) => s + c.level);

  int get proficiencyBonus => ProficiencyBonus.forLevel(totalLevel);

  int get initiativeMod =>
      abilities.dex.modifier + (proficiencies.alertFeat ? proficiencyBonus : 0);

  /// Placeholder base-AC derivation: 10 + Dex modifier. Full armor/shield/
  /// effect-aware computation lives in the combat engine (Doc 11); callers
  /// that need accurate AC should use the engine, not this shortcut.
  int armorClassBase() => 10 + abilities.dex.modifier;

  int get passivePerception {
    // 10 + Wisdom mod + (skill prof contribution) per SRD
    // Skill id assumed to be 'srd:perception' when SRD package present;
    // when absent, passive = 10 + WIS mod.
    final wis = abilities.wis.modifier;
    const perceptionId = 'srd:perception';
    final level = proficiencies.skillLevel(perceptionId);
    return 10 + wis + level.applyTo(proficiencyBonus);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Character && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Character($id, $name, L$totalLevel)';

  Character copyWith({
    String? name,
    List<CharacterClassLevel>? classLevels,
    AbilityScores? abilities,
    ProficiencySet? proficiencies,
    HitPoints? hp,
    HitDicePool? hitDice,
    SpellSlots? spellSlots,
    PactMagicSlots? pactSlots,
    PreparedSpells? preparedSpells,
    Inventory? inventory,
    List<String>? featIds,
    Set<String>? activeConditionIds,
    Map<String, int>? conditionDurationsRounds,
    Exhaustion? exhaustion,
    DeathSaves? deathSaves,
    bool? hasInspiration,
    int? experiencePoints,
    Set<String>? languageIds,
  }) =>
      Character(
        id: id,
        name: name ?? this.name,
        classLevels: classLevels ?? this.classLevels,
        speciesId: speciesId,
        lineageId: lineageId,
        backgroundId: backgroundId,
        alignmentId: alignmentId,
        abilities: abilities ?? this.abilities,
        proficiencies: proficiencies ?? this.proficiencies,
        hp: hp ?? this.hp,
        hitDice: hitDice ?? this.hitDice,
        spellSlots: spellSlots ?? this.spellSlots,
        pactSlots: pactSlots ?? this.pactSlots,
        preparedSpells: preparedSpells ?? this.preparedSpells,
        inventory: inventory ?? this.inventory,
        featIds: featIds ?? this.featIds,
        activeConditionIds: activeConditionIds ?? this.activeConditionIds,
        conditionDurationsRounds:
            conditionDurationsRounds ?? this.conditionDurationsRounds,
        exhaustion: exhaustion ?? this.exhaustion,
        deathSaves: deathSaves ?? this.deathSaves,
        hasInspiration: hasInspiration ?? this.hasInspiration,
        experiencePoints: experiencePoints ?? this.experiencePoints,
        languageIds: languageIds ?? this.languageIds,
      );
}
