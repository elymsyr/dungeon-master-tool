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

  /// Idempotent union of two proficiency sets. Shared keys resolve to the
  /// higher [Proficiency] level (expertise beats full, full beats half, etc.).
  /// [alertFeat] OR-merges. Used by the character builder to aggregate
  /// grants from species + background + class + feat + equipped items.
  ProficiencySet merge(ProficiencySet other) {
    Map<K, Proficiency> mergeMap<K>(
            Map<K, Proficiency> a, Map<K, Proficiency> b) =>
        {
          for (final k in {...a.keys, ...b.keys})
            k: _maxProficiency(a[k] ?? Proficiency.none, b[k] ?? Proficiency.none),
        };
    return ProficiencySet(
      saves: mergeMap(saves, other.saves),
      skills: mergeMap(skills, other.skills),
      tools: mergeMap(tools, other.tools),
      weapons: mergeMap(weapons, other.weapons),
      armor: mergeMap(armor, other.armor),
      languages: {...languages, ...other.languages},
      alertFeat: alertFeat || other.alertFeat,
    );
  }

  static Proficiency _maxProficiency(Proficiency a, Proficiency b) =>
      a.index >= b.index ? a : b;

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
