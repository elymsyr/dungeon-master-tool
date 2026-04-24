import '../catalog/content_reference.dart';
import '../catalog/skill.dart';
import '../core/ability.dart';
import '../effect/effect_descriptor.dart';
import 'feat_prerequisite.dart';

/// 2024 SRD feat category.
enum FeatCategory { origin, general, fightingStyle, epicBoon }

/// Tier 1: feat. [repeatable] matches the SRD "Repeatable: Yes" clause.
///
/// [prerequisite] keeps a human-readable display string (e.g. "Strength 13
/// or higher"). [prerequisites] is the machine-checked list the applier
/// evaluates — every entry must pass for the feat to be grantable.
///
/// [grantedSpellIds] / [grantedSkillChoiceCount] / [grantedSkillOptions] /
/// [abilityIncreases] cover grants the effect DSL cannot represent as a
/// clean, stateful addition to the character sheet.
class Feat {
  final String id;
  final String name;
  final FeatCategory category;
  final bool repeatable;
  final String? prerequisite;
  final List<FeatPrerequisite> prerequisites;
  final List<EffectDescriptor> effects;
  final List<ContentReference> grantedSpellIds;
  final int grantedSkillChoiceCount;
  final List<ContentReference<Skill>> grantedSkillOptions;
  final Map<Ability, int> abilityIncreases;
  final String description;

  Feat._(
    this.id,
    this.name,
    this.category,
    this.repeatable,
    this.prerequisite,
    this.prerequisites,
    this.effects,
    this.grantedSpellIds,
    this.grantedSkillChoiceCount,
    this.grantedSkillOptions,
    this.abilityIncreases,
    this.description,
  );

  factory Feat({
    required String id,
    required String name,
    required FeatCategory category,
    bool repeatable = false,
    String? prerequisite,
    List<FeatPrerequisite> prerequisites = const [],
    List<EffectDescriptor> effects = const [],
    List<ContentReference> grantedSpellIds = const [],
    int grantedSkillChoiceCount = 0,
    List<ContentReference<Skill>> grantedSkillOptions = const [],
    Map<Ability, int> abilityIncreases = const {},
    String description = '',
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Feat.name must not be empty');
    for (final spellId in grantedSpellIds) {
      validateContentId(spellId);
    }
    for (final skillId in grantedSkillOptions) {
      validateContentId(skillId);
    }
    if (grantedSkillChoiceCount < 0) {
      throw ArgumentError('Feat.grantedSkillChoiceCount must be >= 0');
    }
    if (grantedSkillChoiceCount > grantedSkillOptions.length) {
      throw ArgumentError(
          'Feat.grantedSkillChoiceCount ($grantedSkillChoiceCount) exceeds '
          'option count (${grantedSkillOptions.length})');
    }
    return Feat._(
      id,
      name,
      category,
      repeatable,
      prerequisite,
      List.unmodifiable(prerequisites),
      List.unmodifiable(effects),
      List.unmodifiable(grantedSpellIds),
      grantedSkillChoiceCount,
      List.unmodifiable(grantedSkillOptions),
      Map.unmodifiable(abilityIncreases),
      description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Feat && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Feat($id)';
}
