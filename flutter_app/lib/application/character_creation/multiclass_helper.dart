import '../../domain/entities/entity.dart';
import 'caster_progression.dart';

/// Result of checking whether a character can multiclass into a new class.
/// SRD §1.10: must meet the prereq ability score (usually 13) in **all**
/// abilities the class lists, AND meet it in **at least one** of the abilities
/// the *primary* class lists (entry from the side you're leaving). For
/// simplicity this helper only enforces the *entry* prereq (the class being
/// added) — leaving-class prereqs are author-data-driven and rarely checked
/// at table play. Returns a struct with a boolean and the human-readable
/// reason, so the editor can show a confirmation banner instead of blocking.
class MulticlassPrereq {
  final bool met;
  final String reason;
  const MulticlassPrereq({required this.met, required this.reason});
}

/// Read the `multiclass_prereq_ability_refs` (ability entity ids) and
/// `multiclass_prereq_min_score` (int, default 13) off [classEntity] and
/// check them against [abilityScores]. Treats the ability-ref list as
/// **AND** when [classEntity] declares more than one slot (Paladin/Ranger
/// pattern), **OR** only when the class explicitly declares
/// `multiclass_prereq_any_of: true` (Fighter STR or DEX, Monk DEX or WIS).
///
/// [abilityScores] keys may be uppercase ('STR') or class-entity-name
/// ('Strength') — both forms are checked.
MulticlassPrereq checkMulticlassPrereq({
  required Entity classEntity,
  required Map<String, Entity> entities,
  required Map<String, int> abilityScores,
}) {
  final raw = classEntity.fields['multiclass_prereq_ability_refs'];
  if (raw is! List || raw.isEmpty) {
    return const MulticlassPrereq(met: true, reason: '');
  }
  final minScore = classEntity.fields['multiclass_prereq_min_score'];
  final min = (minScore is int)
      ? minScore
      : int.tryParse('${minScore ?? 13}') ?? 13;
  final anyOf = classEntity.fields['multiclass_prereq_any_of'] == true;

  final abilityNames = <String>[];
  for (final ref in raw) {
    if (ref is! Map) continue;
    final inline = ref['name'];
    if (inline is String && inline.isNotEmpty) {
      abilityNames.add(inline);
      continue;
    }
    final id = ref['id'];
    if (id is String && entities[id] != null) {
      abilityNames.add(entities[id]!.name);
    }
  }
  if (abilityNames.isEmpty) {
    return const MulticlassPrereq(met: true, reason: '');
  }

  int scoreFor(String ability) {
    final upper = _abbrevFor(ability);
    return abilityScores[ability] ?? abilityScores[upper] ?? 0;
  }

  final missing = <String>[];
  final passing = <String>[];
  for (final name in abilityNames) {
    if (scoreFor(name) >= min) {
      passing.add(name);
    } else {
      missing.add(name);
    }
  }

  if (anyOf) {
    if (passing.isNotEmpty) {
      return MulticlassPrereq(
        met: true,
        reason: 'Prerequisite met via $passing.',
      );
    }
    return MulticlassPrereq(
      met: false,
      reason:
          'Need $min in one of ${abilityNames.join(" / ")} to multiclass into ${classEntity.name}.',
    );
  }

  if (missing.isEmpty) {
    return MulticlassPrereq(
      met: true,
      reason: 'Prerequisite met.',
    );
  }
  return MulticlassPrereq(
    met: false,
    reason:
        'Need $min in ${missing.join(" and ")} to multiclass into ${classEntity.name}.',
  );
}

String _abbrevFor(String ability) {
  switch (ability.toLowerCase()) {
    case 'strength':
      return 'STR';
    case 'dexterity':
      return 'DEX';
    case 'constitution':
      return 'CON';
    case 'intelligence':
      return 'INT';
    case 'wisdom':
      return 'WIS';
    case 'charisma':
      return 'CHA';
    default:
      return ability.toUpperCase();
  }
}

/// Sum of every class level in [classLevels]. SRD §1.10: character level =
/// total class levels. Proficiency bonus, ASIs, feats by total — but spell
/// slots use a separate blended table (see [combinedCasterLevel]).
int totalCharacterLevel(Map<String, int> classLevels) {
  var sum = 0;
  for (final v in classLevels.values) {
    sum += v;
  }
  return sum;
}

/// True when [classLevels] holds two or more entries whose `caster_kind` is
/// full / half / third. Pact (Warlock) doesn't contribute to the combined
/// table — it's evaluated separately.
bool isMulticlassCaster({
  required Map<String, int> classLevels,
  required Map<String, Entity> entities,
}) {
  var casterCount = 0;
  for (final entry in classLevels.entries) {
    if (entry.value <= 0) continue;
    final cls = entities[entry.key];
    if (cls == null) continue;
    final kind = cls.fields['caster_kind']?.toString().toLowerCase();
    if (kind == 'full' || kind == 'half' || kind == 'third') {
      casterCount += 1;
      if (casterCount >= 2) return true;
    }
  }
  return false;
}

/// SRD §1.10 Multiclass Spellcaster table output. Returns the combined slot
/// map (`{spellLevel: count}`) using the full-caster table at the
/// [combinedCasterLevel]. Returns `null` when the character has zero or one
/// caster classes — the single-class progression in the planner is correct
/// in that case.
Map<int, int>? multiclassSpellSlotsFor({
  required Map<String, int> classLevels,
  required Map<String, Entity> entities,
}) {
  if (!isMulticlassCaster(classLevels: classLevels, entities: entities)) {
    return null;
  }
  final lvl = combinedCasterLevel(
      classLevels: classLevels, entities: entities);
  if (lvl <= 0) return const {};
  return defaultSpellSlotsByLevel(CasterKind.full, lvl);
}

/// SRD §1.10 Multiclass Spellcaster table input — sum of class levels
/// weighted by their `caster_kind`:
///   - full caster (Bard/Cleric/Druid/Sorcerer/Wizard): full level
///   - half caster (Paladin/Ranger): floor(level/2), with the exception
///     that the Ranger/Paladin contribute starting at L2 (level 1 gives 0)
///   - third caster (Arcane Trickster, Eldritch Knight): floor(level/3),
///     starting at L3
///   - pact (Warlock): not folded in — Warlock keeps its own pact slots.
/// Returns the integer "spellcaster level" to look up in the combined
/// slot table. Returns 0 when no caster classes contribute.
int combinedCasterLevel({
  required Map<String, int> classLevels,
  required Map<String, Entity> entities,
}) {
  var total = 0;
  for (final entry in classLevels.entries) {
    final cls = entities[entry.key];
    if (cls == null) continue;
    final kind = cls.fields['caster_kind']?.toString().toLowerCase();
    final lvl = entry.value;
    if (lvl <= 0) continue;
    switch (kind) {
      case 'full':
        total += lvl;
      case 'half':
        if (lvl >= 2) total += lvl ~/ 2;
      case 'third':
        if (lvl >= 3) total += lvl ~/ 3;
    }
  }
  return total;
}
