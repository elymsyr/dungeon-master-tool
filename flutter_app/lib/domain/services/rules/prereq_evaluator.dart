import '../../entities/entity.dart';
import '../entity_ref.dart';

/// Shared prerequisite-clause interpreter (roadmap 1.1 + 1.2).
///
/// One clause vocabulary, two consumers with different policies:
///   - the pending-choice picker dialog FILTERS candidates (hide when unmet),
///   - `CharacterResolver` WARN-KEEPs (typed [UnmetPrerequisite]-style warning
///     on the resolved character; mechanics still apply).
///
/// Clause wire shapes mirror what the Open5e importer emits
/// (`tool/open5e_import/mappers/chargen.dart` `_parseFeatPrereq`) plus the
/// lowered flat `prereq_*` fields:
///   {type: 'character_level', min_level: int}
///   {type: 'ability_min', ability_options: [ref...], min_score: int}  // OR
///   {type: 'spellcasting'}
///   {type: 'armor_proficiency', category: 'Heavy'? , category_ref: ref?}
///   {type: 'weapon_proficiency', weapon_class: 'simple'|'martial'|'any'}
///   {type: 'skill_proficiency', skill_options: [ref...]}              // OR
///   {type: 'class_ref', class_options: [ref...], min_level: int?}     // OR
///   {type: 'species_ref', species_options: [ref...]}                  // OR
///   {type: 'alignment_ref', alignment_options: [ref...]}              // OR
///   {type: 'other', ...}                                              // never blocks
///
/// Semantics: ALL-of across clauses, OR within an option list, unknown /
/// `other` clause types never block (display-only) — byte-compatible with
/// the picker dialog's historical `_passesPrereqClauses`.

/// Character-state snapshot a clause list is evaluated against. Callers build
/// it from whatever surface they have (mid-resolve accumulators in the
/// resolver, widget params in the picker dialog).
class PrereqContext {
  /// Total character level (sum of class levels) — `character_level` clauses.
  final int characterLevel;

  /// Ability scores keyed by abbreviation (`STR`..`CHA`). Missing = 10.
  final Map<String, int> abilityScores;

  final bool hasSpellcasting;

  /// Proficient armor-category names, lowercased ('light', 'medium', ...).
  final Set<String> proficientArmorCategoriesLower;

  /// Proficient weapon classes, lowercased ('simple', 'martial').
  final Set<String> proficientWeaponClassesLower;

  /// Proficient skill names (exact entity names — the dialog historically
  /// compares names, not ids).
  final Set<String> proficientSkillNames;

  /// Class levels keyed by class entity id — `class_ref` clauses. Null =
  /// unknown context (never blocks); empty map = known to have no classes.
  final Map<String, int>? classLevelsById;

  /// Species entity id — `species_ref` clauses. Null = unknown (never blocks).
  final String? speciesId;

  /// Alignment entity id — `alignment_ref` clauses. Null = unknown
  /// (never blocks — most PCs simply don't author one).
  final String? alignmentId;

  const PrereqContext({
    this.characterLevel = 0,
    this.abilityScores = const {},
    this.hasSpellcasting = false,
    this.proficientArmorCategoriesLower = const {},
    this.proficientWeaponClassesLower = const {},
    this.proficientSkillNames = const {},
    this.classLevelsById,
    this.speciesId,
    this.alignmentId,
  });
}

/// One evaluated clause: outcome + a human-readable requirement description
/// ("Strength 13", "Character level 4") for warning banners.
class ClauseResult {
  final bool passed;
  final String description;
  const ClauseResult({required this.passed, required this.description});
}

class PrereqResult {
  final List<ClauseResult> clauses;
  const PrereqResult(this.clauses);

  bool get passed => clauses.every((c) => c.passed);

  List<String> get failedDescriptions => [
        for (final c in clauses)
          if (!c.passed) c.description,
      ];

  static const PrereqResult empty = PrereqResult([]);
}

const Map<String, String> _abbrevByAbilityName = {
  'Strength': 'STR',
  'Dexterity': 'DEX',
  'Constitution': 'CON',
  'Intelligence': 'INT',
  'Wisdom': 'WIS',
  'Charisma': 'CHA',
};

String? _abbrevForAbility(String? name) {
  if (name == null) return null;
  final direct = _abbrevByAbilityName[name];
  if (direct != null) return direct;
  final upper = name.toUpperCase();
  return _abbrevByAbilityName.containsValue(upper) ? upper : null;
}

/// Effective prerequisite clauses for an entity's fields map: typed
/// `prereq_clauses` when present, otherwise the flat `prereq_*` fields
/// lowered into the same clause shapes. Mirrors the picker dialog's
/// precedence (clauses win; flat fields are the legacy fallback) and extends
/// it with the flat fields the dialog never read (`prereq_class_refs`,
/// `prereq_species_refs`, `prereq_requires_spellcasting`) — an intended
/// correctness tightening, not a regression.
List<Map<String, dynamic>> effectivePrereqClauses(Map<String, dynamic> fields) {
  final typed = fields['prereq_clauses'];
  if (typed is List && typed.isNotEmpty) {
    return [
      for (final c in typed)
        if (c is Map) Map<String, dynamic>.from(c),
    ];
  }

  final lowered = <Map<String, dynamic>>[];
  final minLvl = fields['prereq_min_character_level'];
  if (minLvl is int && minLvl > 0) {
    lowered.add({'type': 'character_level', 'min_level': minLvl});
  }
  final minScore = fields['prereq_min_score'];
  final abilityRef = fields['prereq_ability_ref'];
  if (minScore is int && abilityRef != null) {
    lowered.add({
      'type': 'ability_min',
      'ability_options': [abilityRef],
      'min_score': minScore,
    });
  }
  if (fields['prereq_requires_spellcasting'] == true) {
    lowered.add({'type': 'spellcasting'});
  }
  final classRefs = fields['prereq_class_refs'];
  if (classRefs is List && classRefs.isNotEmpty) {
    lowered.add({'type': 'class_ref', 'class_options': classRefs});
  }
  final speciesRefs = fields['prereq_species_refs'];
  if (speciesRefs is List && speciesRefs.isNotEmpty) {
    lowered.add({'type': 'species_ref', 'species_options': speciesRefs});
  }
  return lowered;
}

/// Evaluate [clauses] (ALL-of) against [ctx]. Unknown / `other` clauses never
/// block but still surface as passed [ClauseResult]s with their text when
/// one is present, so banners can show the narrative requirement.
PrereqResult evaluatePrereqClauses(
  List<dynamic> clauses,
  PrereqContext ctx,
  Map<String, Entity> entitiesById,
) {
  final results = <ClauseResult>[];

  String? nameOf(Object? refOrId) {
    final id = resolveEntityRef(refOrId, entitiesById);
    final fromEntity = id == null ? null : entitiesById[id]?.name;
    if (fromEntity != null) return fromEntity;
    if (refOrId is Map) {
      final n = refOrId['name'];
      if (n is String) return n;
    }
    return null;
  }

  for (final raw in clauses) {
    if (raw is! Map) continue;
    switch (raw['type']) {
      case 'character_level':
        final min = raw['min_level'];
        if (min is! int) break;
        results.add(ClauseResult(
          passed: ctx.characterLevel >= min,
          description: 'Character level $min',
        ));
      case 'ability_min':
        final min = raw['min_score'];
        final opts = raw['ability_options'];
        if (min is! int || opts is! List || opts.isEmpty) break;
        final names = <String>[];
        var anyMet = false;
        for (final o in opts) {
          final name = nameOf(o);
          final abbrev = _abbrevForAbility(name);
          if (name != null) names.add(name);
          if (abbrev != null && (ctx.abilityScores[abbrev] ?? 10) >= min) {
            anyMet = true;
          }
        }
        results.add(ClauseResult(
          passed: anyMet,
          description: '${names.isEmpty ? 'Ability' : names.join(' or ')} $min',
        ));
      case 'spellcasting':
        results.add(ClauseResult(
          passed: ctx.hasSpellcasting,
          description: 'Spellcasting or Pact Magic feature',
        ));
      case 'armor_proficiency':
        var name = (raw['category'] as String?)?.toLowerCase();
        name ??= nameOf(raw['category_ref'])?.toLowerCase();
        if (name == null) break; // unresolvable → never blocks (dialog parity)
        results.add(ClauseResult(
          passed: ctx.proficientArmorCategoriesLower.contains(name),
          description: 'Proficiency with ${name[0].toUpperCase()}${name.substring(1)} armor',
        ));
      case 'weapon_proficiency':
        final wc = (raw['weapon_class'] as String?)?.toLowerCase();
        if (wc == null) break;
        final passed = wc == 'any'
            ? ctx.proficientWeaponClassesLower.isNotEmpty
            : ctx.proficientWeaponClassesLower.contains(wc);
        results.add(ClauseResult(
          passed: passed,
          description: wc == 'any'
              ? 'Proficiency with a weapon'
              : 'Proficiency with $wc weapons',
        ));
      case 'skill_proficiency':
        final opts = raw['skill_options'];
        if (opts is! List || opts.isEmpty) break;
        final names = <String>[];
        var anyMet = false;
        for (final o in opts) {
          final name = nameOf(o);
          if (name == null) continue;
          names.add(name);
          if (ctx.proficientSkillNames.contains(name)) anyMet = true;
        }
        if (names.isEmpty) break;
        results.add(ClauseResult(
          passed: anyMet,
          description: 'Proficiency in ${names.join(' or ')}',
        ));
      case 'class_ref':
        final opts = raw['class_options'];
        if (opts is! List || opts.isEmpty) break;
        final classLevels = ctx.classLevelsById;
        if (classLevels == null) break; // unknown context → never blocks
        final minLevel = raw['min_level'] is int ? raw['min_level'] as int : 1;
        final names = <String>[];
        var anyMet = false;
        for (final o in opts) {
          final id = resolveEntityRef(o, entitiesById);
          final name = nameOf(o);
          if (name != null) names.add(name);
          if (id != null && (classLevels[id] ?? 0) >= minLevel) {
            anyMet = true;
          }
        }
        if (names.isEmpty && !anyMet) break;
        results.add(ClauseResult(
          passed: anyMet,
          description:
              '${names.isEmpty ? 'Class' : names.join(' or ')}${minLevel > 1 ? ' level $minLevel' : ''}',
        ));
      case 'species_ref':
        final opts = raw['species_options'];
        if (opts is! List || opts.isEmpty) break;
        if (ctx.speciesId == null) break; // unknown → never blocks
        final names = <String>[];
        var anyMet = false;
        for (final o in opts) {
          final id = resolveEntityRef(o, entitiesById);
          final name = nameOf(o);
          if (name != null) names.add(name);
          if (id != null && id == ctx.speciesId) anyMet = true;
        }
        if (names.isEmpty && !anyMet) break;
        results.add(ClauseResult(
          passed: anyMet,
          description: '${names.isEmpty ? 'Species' : names.join(' or ')} species',
        ));
      case 'alignment_ref':
        final opts = raw['alignment_options'];
        if (opts is! List || opts.isEmpty) break;
        if (ctx.alignmentId == null) break; // unknown → never blocks
        final names = <String>[];
        var anyMet = false;
        for (final o in opts) {
          final id = resolveEntityRef(o, entitiesById);
          final name = nameOf(o);
          if (name != null) names.add(name);
          if (id != null && id == ctx.alignmentId) anyMet = true;
        }
        if (names.isEmpty && !anyMet) break;
        results.add(ClauseResult(
          passed: anyMet,
          description: '${names.isEmpty ? 'Alignment' : names.join(' or ')} alignment',
        ));
      default:
        break; // 'other' / unknown → never blocks
    }
  }
  return PrereqResult(results);
}
