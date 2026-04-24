import '../catalog/content_reference.dart';
import '../catalog/damage_type.dart';
import '../catalog/language.dart';
import '../catalog/size.dart';
import '../catalog/skill.dart';
import '../core/ability.dart';
import '../effect/effect_descriptor.dart';

/// Tier 1: species (Dragonborn, Elf, Human, ...). [sizeId] references the
/// catalog Size; [baseSpeedFt] is the walking speed granted at level 1.
///
/// [effects] cover dynamic/conditional mechanics (darkvision range, save
/// advantages, resistance rules). First-class grant fields cover static
/// references that the effect DSL cannot represent cleanly:
/// - [innateSpellIds]: spells a species always knows (Drow's Dancing Lights).
/// - [abilityIncreases]: pre-2024 +N/+N bonuses still used by some homebrew.
/// - [damageResistanceIds]: lineage resistances that feed the applier
///   directly (also expressible via `ModifyResistances` effects for the
///   combat resolver).
class Species {
  final String id;
  final String name;
  final ContentReference<Size> sizeId;
  final int baseSpeedFt;
  final List<EffectDescriptor> effects;
  final Map<Ability, int> abilityIncreases;
  final List<ContentReference> innateSpellIds;
  final List<ContentReference<DamageType>> damageResistanceIds;
  final String description;

  Species._(
      this.id,
      this.name,
      this.sizeId,
      this.baseSpeedFt,
      this.effects,
      this.abilityIncreases,
      this.innateSpellIds,
      this.damageResistanceIds,
      this.description);

  factory Species({
    required String id,
    required String name,
    required ContentReference<Size> sizeId,
    required int baseSpeedFt,
    List<EffectDescriptor> effects = const [],
    Map<Ability, int> abilityIncreases = const {},
    List<ContentReference> innateSpellIds = const [],
    List<ContentReference<DamageType>> damageResistanceIds = const [],
    String description = '',
  }) {
    validateContentId(id);
    validateContentId(sizeId);
    if (name.isEmpty) throw ArgumentError('Species.name must not be empty');
    if (baseSpeedFt < 0) {
      throw ArgumentError('Species.baseSpeedFt must be >= 0');
    }
    for (final spellId in innateSpellIds) {
      validateContentId(spellId);
    }
    for (final dtId in damageResistanceIds) {
      validateContentId(dtId);
    }
    return Species._(
      id,
      name,
      sizeId,
      baseSpeedFt,
      List.unmodifiable(effects),
      Map.unmodifiable(abilityIncreases),
      List.unmodifiable(innateSpellIds),
      List.unmodifiable(damageResistanceIds),
      description,
    );
  }

  /// Skill proficiency ids derived from [effects]. Mirrors [Background].
  List<ContentReference<Skill>> get skillProficiencyIds =>
      _proficiencyIdsOfKind(ProficiencyKind.skill);

  List<String> get toolProficiencyIds =>
      _proficiencyIdsOfKind(ProficiencyKind.tool);

  List<ContentReference<Language>> get grantedLanguageIds =>
      _proficiencyIdsOfKind(ProficiencyKind.language);

  List<String> _proficiencyIdsOfKind(ProficiencyKind kind) {
    final ids = <String>[];
    for (final e in effects) {
      if (e is GrantProficiency && e.kind == kind) {
        ids.add(e.targetId);
      }
    }
    return List.unmodifiable(ids);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Species && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Species($id)';
}
