import '../catalog/content_reference.dart';
import '../core/ability.dart';
import '../core/proficiency.dart';

/// Complete proficiency picture for a character. Saves key off [Ability] enum;
/// everything else is a namespaced id (skill, tool, weapon kind, armor category,
/// language). [alertFeat] is a dedicated boolean because the Alert feat's
/// initiative-bonus interaction is referenced directly by `Character`.
class ProficiencySet {
  final Map<Ability, Proficiency> saves;
  final Map<String, Proficiency> skills;
  final Map<String, Proficiency> tools;
  final Map<String, Proficiency> weapons;
  final Map<String, Proficiency> armor;
  final Set<String> languages;
  final bool alertFeat;

  ProficiencySet._(
    this.saves,
    this.skills,
    this.tools,
    this.weapons,
    this.armor,
    this.languages,
    this.alertFeat,
  );

  factory ProficiencySet({
    Map<Ability, Proficiency> saves = const {},
    Map<String, Proficiency> skills = const {},
    Map<String, Proficiency> tools = const {},
    Map<String, Proficiency> weapons = const {},
    Map<String, Proficiency> armor = const {},
    Set<String> languages = const {},
    bool alertFeat = false,
  }) {
    for (final id in skills.keys) {
      validateContentId(id);
    }
    for (final id in tools.keys) {
      validateContentId(id);
    }
    for (final id in weapons.keys) {
      validateContentId(id);
    }
    for (final id in armor.keys) {
      validateContentId(id);
    }
    for (final id in languages) {
      validateContentId(id);
    }
    return ProficiencySet._(
      Map.unmodifiable(saves),
      Map.unmodifiable(skills),
      Map.unmodifiable(tools),
      Map.unmodifiable(weapons),
      Map.unmodifiable(armor),
      Set.unmodifiable(languages),
      alertFeat,
    );
  }

  factory ProficiencySet.empty() => ProficiencySet();

  Proficiency saveLevel(Ability a) => saves[a] ?? Proficiency.none;
  Proficiency skillLevel(String id) => skills[id] ?? Proficiency.none;

  ProficiencySet copyWith({
    Map<Ability, Proficiency>? saves,
    Map<String, Proficiency>? skills,
    Map<String, Proficiency>? tools,
    Map<String, Proficiency>? weapons,
    Map<String, Proficiency>? armor,
    Set<String>? languages,
    bool? alertFeat,
  }) =>
      ProficiencySet(
        saves: saves ?? this.saves,
        skills: skills ?? this.skills,
        tools: tools ?? this.tools,
        weapons: weapons ?? this.weapons,
        armor: armor ?? this.armor,
        languages: languages ?? this.languages,
        alertFeat: alertFeat ?? this.alertFeat,
      );
}
