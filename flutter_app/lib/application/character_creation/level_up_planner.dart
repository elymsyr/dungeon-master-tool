import '../../domain/entities/entity.dart';
import 'caster_progression.dart';

/// One feature granted at [level] by [source] (class or subclass name).
class LevelGain {
  final int level;
  final String source;
  final String name;
  final String description;
  const LevelGain({
    required this.level,
    required this.source,
    required this.name,
    required this.description,
  });
}

/// Deltas the editor should apply when a character moves from [fromLevel]
/// to [toLevel]. All fields are derived deterministically from the class +
/// subclass entities — the dialog just renders them.
///
/// MVP scope:
///   - HP: fixed bump per SRD §1 ("after first level, take the average
///     rounded up"), one bump per level crossed.
///   - Proficiency Bonus: read from the SRD table at the new level.
///   - Features: union of class + subclass features whose `level` falls in
///     (fromLevel, toLevel].
///   - Caster notice: cantrips_known and prepared_spells caps at toLevel.
///   - ASI/feat & Extra Attack flags so the dialog can prompt the user.
class LevelUpPlan {
  final int fromLevel;
  final int toLevel;
  final int hpDelta;
  final String? hitDie; // 'd6'..'d12' — display + future roll mode
  final int prevProfBonus;
  final int newProfBonus;
  final List<LevelGain> newFeatures;
  final bool isAsiOrFeatLevel;
  final bool isExtraAttackLevel;
  final bool isFightingStyleLevel;
  final CasterKind casterKind;
  final int? cantripsKnownAtNewLevel;
  final int? preparedSpellsAtNewLevel;
  final int? maxSpellLevelAtNewLevel;

  const LevelUpPlan({
    required this.fromLevel,
    required this.toLevel,
    required this.hpDelta,
    required this.hitDie,
    required this.prevProfBonus,
    required this.newProfBonus,
    required this.newFeatures,
    required this.isAsiOrFeatLevel,
    required this.isExtraAttackLevel,
    required this.isFightingStyleLevel,
    required this.casterKind,
    required this.cantripsKnownAtNewLevel,
    required this.preparedSpellsAtNewLevel,
    required this.maxSpellLevelAtNewLevel,
  });

  bool get isLevelUp => toLevel > fromLevel;
  int get pbDelta => newProfBonus - prevProfBonus;

  /// Faces of the hit die ('d8' → 8). 0 when missing / malformed; dialog
  /// uses this to gate the manual-roll mode.
  int get hitDieFaces {
    if (hitDie == null) return 0;
    final m = RegExp(r'd(\d+)').firstMatch(hitDie!.toLowerCase());
    if (m == null) return 0;
    return int.tryParse(m.group(1) ?? '') ?? 0;
  }

  /// Levels gained in this transition (clamped to [0, 20]). Used by the
  /// dialog's roll-mode to know how many dice to roll.
  int get levelsGained => (toLevel - fromLevel).clamp(0, 20);
}

/// SRD §1.5 HP-on-level-up rule: each level gains (hit-die average OR
/// rolled die) **plus the Constitution modifier**. The planner stays
/// CON-agnostic because CON can change *during* the same level-up via
/// ASI; the caller (dialog) reads the live, post-bump CON mod and folds
/// it in here so the HP applied to the character matches what the player
/// sees on screen.
///
/// [rolledTotal] is the sum of the player's manual hit-die rolls when in
/// roll mode; pass `null` to use the planner's fixed average. CON mod is
/// added once per level gained — multi-level jumps compound it.
int effectiveHpDelta({
  required LevelUpPlan plan,
  required int conModifier,
  int? rolledTotal,
}) {
  final raw = rolledTotal ?? plan.hpDelta;
  return raw + plan.levelsGained * conModifier;
}

/// SRD §1 proficiency bonus by level. Matches `ClassLevelUpTable.profBonusFor`
/// — kept here so the planner has no UI import.
int proficiencyBonusFor(int level) {
  if (level >= 17) return 6;
  if (level >= 13) return 5;
  if (level >= 9) return 4;
  if (level >= 5) return 3;
  return 2;
}

/// Fixed HP gained per level after L1: average of the die rounded up
/// (d6→4, d8→5, d10→6, d12→7). Returns 0 for unknown / malformed input
/// — the dialog renders "—" so the user can still apply other deltas.
int fixedHpFor(String? hitDie) {
  switch (hitDie) {
    case 'd6':
      return 4;
    case 'd8':
      return 5;
    case 'd10':
      return 6;
    case 'd12':
      return 7;
    default:
      return 0;
  }
}

/// SRD §1: Ability Score Improvement (or feat) is granted at the listed
/// levels for nearly every class. Captured here rather than scanning the
/// class's `features` text so the dialog flag works even when the schema
/// row omits the ASI feature entry.
const _asiOrFeatLevels = {4, 8, 12, 16, 19};

/// SRD §1: Extra Attack lands at level 5 for the martial classes that get
/// it. The dialog uses this as a contextual reminder ("Your attacks now
/// strike twice"); the actual feature row, if present in the class data,
/// is already rendered via [LevelUpPlan.newFeatures].
const _extraAttackLevels = {5};

List<LevelGain> _featuresInRange({
  required Entity? entity,
  required String source,
  required int afterLevel,
  required int throughLevel,
}) {
  if (entity == null) return const [];
  final raw = entity.fields['features'];
  if (raw is! List) return const [];
  final out = <LevelGain>[];
  for (final row in raw) {
    if (row is! Map) continue;
    final lvl = row['level'];
    if (lvl is! int) continue;
    if (lvl <= afterLevel || lvl > throughLevel) continue;
    out.add(LevelGain(
      level: lvl,
      source: source,
      name: (row['name'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
    ));
  }
  out.sort((a, b) {
    final byLevel = a.level.compareTo(b.level);
    if (byLevel != 0) return byLevel;
    return a.source.compareTo(b.source);
  });
  return out;
}

/// Build a plan describing every delta between [fromLevel] and [toLevel].
/// When [toLevel] <= [fromLevel] the plan is still returned so the caller
/// can decide what to do (the editor uses [LevelUpPlan.isLevelUp] to gate
/// the dialog).
LevelUpPlan planLevelUp({
  required int fromLevel,
  required int toLevel,
  required Entity? classEntity,
  required Entity? subclassEntity,
}) {
  final clampedFrom = fromLevel.clamp(0, 20);
  final clampedTo = toLevel.clamp(0, 20);
  final hitDie = classEntity?.fields['hit_die'] as String?;

  final levelsGained = (clampedTo - clampedFrom).clamp(0, 20);
  final hpDelta = levelsGained * fixedHpFor(hitDie);

  final newFeatures = <LevelGain>[
    ..._featuresInRange(
      entity: classEntity,
      source: classEntity?.name ?? 'Class',
      afterLevel: clampedFrom,
      throughLevel: clampedTo,
    ),
    ..._featuresInRange(
      entity: subclassEntity,
      source: subclassEntity?.name ?? 'Subclass',
      afterLevel: clampedFrom,
      throughLevel: clampedTo,
    ),
  ]..sort((a, b) {
      final byLevel = a.level.compareTo(b.level);
      if (byLevel != 0) return byLevel;
      return a.source.compareTo(b.source);
    });

  var asi = false;
  var extra = false;
  for (var l = clampedFrom + 1; l <= clampedTo; l++) {
    if (_asiOrFeatLevels.contains(l)) asi = true;
    if (_extraAttackLevels.contains(l)) extra = true;
  }

  // Fighting Style grant is class-driven. Detect either:
  //   - any new feature whose name mentions "Fighting Style", OR
  //   - the class entity's `grants_fighting_style_at_levels` table contains
  //     any level in the (clampedFrom, clampedTo] window. Authored content
  //     may use either path; check both so the dialog flag fires.
  var fightingStyle = false;
  for (final f in newFeatures) {
    if (f.name.toLowerCase().contains('fighting style')) {
      fightingStyle = true;
      break;
    }
  }
  if (!fightingStyle) {
    final levels = classEntity?.fields['grants_fighting_style_at_levels'];
    if (levels is List) {
      for (final raw in levels) {
        final l = raw is int ? raw : int.tryParse('$raw');
        if (l == null) continue;
        if (l > clampedFrom && l <= clampedTo) {
          fightingStyle = true;
          break;
        }
      }
    }
  }

  final kind = parseCasterKind(classEntity?.fields['caster_kind']);
  int? cantripCap;
  int? preparedCap;
  int? maxSpell;
  if (kind != CasterKind.none && clampedTo > 0) {
    cantripCap = levelTableValue(
            classEntity?.fields['cantrips_known_by_level'], clampedTo) ??
        defaultCantripsKnown(kind, clampedTo);
    preparedCap = levelTableValue(
            classEntity?.fields['prepared_spells_by_level'], clampedTo) ??
        defaultPreparedSpells(kind, clampedTo);
    maxSpell = maxPreparableSpellLevel(kind, clampedTo);
  }

  return LevelUpPlan(
    fromLevel: clampedFrom,
    toLevel: clampedTo,
    hpDelta: hpDelta,
    hitDie: hitDie,
    prevProfBonus: proficiencyBonusFor(clampedFrom < 1 ? 1 : clampedFrom),
    newProfBonus: proficiencyBonusFor(clampedTo < 1 ? 1 : clampedTo),
    newFeatures: newFeatures,
    isAsiOrFeatLevel: asi,
    isExtraAttackLevel: extra,
    isFightingStyleLevel: fightingStyle,
    casterKind: kind,
    cantripsKnownAtNewLevel: cantripCap,
    preparedSpellsAtNewLevel: preparedCap,
    maxSpellLevelAtNewLevel: maxSpell,
  );
}
