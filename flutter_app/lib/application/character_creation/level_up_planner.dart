import '../../domain/entities/entity.dart';
import 'caster_progression.dart';
import 'extra_attack_resolver.dart';
import 'resource_pool_resolver.dart';
import 'weapon_mastery_resolver.dart';

/// One feature granted at [level] by [source] (class or subclass name).
class LevelGain {
  final int level;
  final String source;
  final String name;
  final String description;

  /// Ability names (e.g. `Wisdom`, `Charisma`) for which this feature
  /// grants a saving-throw proficiency. Sourced from the feature row's
  /// `effects` entries with `kind: proficiency_grant` and
  /// `target_kind: saving_throw` (or `ability`). Empty when the feature
  /// has no save grant — dialog uses this to render a dedicated notice.
  final List<String> grantedSaveProficiencyNames;

  const LevelGain({
    required this.level,
    required this.source,
    required this.name,
    required this.description,
    this.grantedSaveProficiencyNames = const [],
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

  /// Set when the (clampedFrom, clampedTo] window contains the level where
  /// the class grants a subclass selection. Detected by feature-name match
  /// (SRD class features named `<Class> Subclass` or `Subclass feature`).
  /// The editor uses this to queue a `PendingChoiceKind.subclass` when no
  /// subclass is selected yet.
  final bool isSubclassLevel;

  /// Set when (clampedFrom, clampedTo] window includes the level a Cleric
  /// gains Divine Order (L1). Detected by feature-name match ("Divine Order").
  /// Editor queues a `PendingChoiceKind.divineOrder` pending pick.
  final bool isDivineOrderLevel;

  /// Feature names crossed in (clampedFrom, clampedTo] that present a 1-of-N
  /// option pick to the player (e.g. Hunter's Prey, Defensive Tactics). Each
  /// name produces a `PendingChoiceKind.featureOption` badge; option feats
  /// live under category `Feature Option: <name>`.
  final List<String> featureOptionPicks;
  final CasterKind casterKind;
  final int? cantripsKnownAtNewLevel;
  final int? cantripsKnownAtPrevLevel;
  final int? preparedSpellsAtNewLevel;
  final int? preparedSpellsAtPrevLevel;
  final int? maxSpellLevelAtNewLevel;

  /// Slot maps keyed by spell level (1..9) with slot counts. `null` for
  /// non-casters; empty map for caster classes whose progression hasn't
  /// kicked in yet (e.g. Paladin L1). Pact casters produce a single-entry
  /// map keyed by their current pact-slot level.
  final Map<int, int>? prevSpellSlots;
  final Map<int, int>? newSpellSlots;

  /// Class resource pool max values (Rage uses, Ki, Sorcery Points, Lay
  /// on Hands, etc.) keyed by `pool_ref.name`. Resolved from auto-granted
  /// class feats — empty when no entity map was passed in.
  final Map<String, int> prevResourcePools;
  final Map<String, int> newResourcePools;

  /// Number of attacks granted by the Extra Attack feature at each level.
  /// Zero before L5 for martial classes, 2 from L5 onward, scaling to 3 at
  /// L11 and 4 at L20 for Fighter (other classes cap at 2). Resolved from
  /// auto-granted feats — 0 when no entity map was passed in.
  final int prevExtraAttackCount;
  final int newExtraAttackCount;

  /// Weapon Mastery count cap (SRD §1.7) at each level — sum of
  /// `weapon_mastery_count_bonus` effects on auto-granted class feats. The
  /// editor uses the delta to queue a `PendingChoiceKind.weaponMastery`.
  final int prevWeaponMasteryCount;
  final int newWeaponMasteryCount;

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
    required this.isSubclassLevel,
    required this.isDivineOrderLevel,
    required this.featureOptionPicks,
    required this.casterKind,
    required this.cantripsKnownAtNewLevel,
    required this.cantripsKnownAtPrevLevel,
    required this.preparedSpellsAtNewLevel,
    required this.preparedSpellsAtPrevLevel,
    required this.maxSpellLevelAtNewLevel,
    required this.prevSpellSlots,
    required this.newSpellSlots,
    required this.prevResourcePools,
    required this.newResourcePools,
    required this.prevExtraAttackCount,
    required this.newExtraAttackCount,
    required this.prevWeaponMasteryCount,
    required this.newWeaponMasteryCount,
  });

  /// New cantrips the player must pick on this level-up. Zero for
  /// non-casters and for transitions that don't bump cantrip count.
  int get cantripsKnownDelta {
    final p = cantripsKnownAtPrevLevel ?? 0;
    final n = cantripsKnownAtNewLevel ?? 0;
    return n > p ? n - p : 0;
  }

  /// New known/prepared spells the player must pick on this level-up.
  /// Uses the prepared-spell count as the proxy for "how many new ones
  /// you learn" — covers Wizard spellbook adds, Sorcerer known list, etc.
  int get preparedSpellsDelta {
    final p = preparedSpellsAtPrevLevel ?? 0;
    final n = preparedSpellsAtNewLevel ?? 0;
    return n > p ? n - p : 0;
  }

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

  /// Increase in Extra Attack count this level-up (clamped ≥ 0). Used by
  /// the dialog to render the dynamic notice ("Your attacks now strike
  /// three times").
  int get extraAttackCountDelta {
    final diff = newExtraAttackCount - prevExtraAttackCount;
    return diff > 0 ? diff : 0;
  }

  /// Increase in Weapon Mastery picks unlocked this level-up (clamped ≥ 0).
  /// Editor uses this to queue a `PendingChoiceKind.weaponMastery`.
  int get weaponMasteryCountDelta {
    final diff = newWeaponMasteryCount - prevWeaponMasteryCount;
    return diff > 0 ? diff : 0;
  }

  /// Pool size increases (`newMax - prevMax`) for entries that grew.
  /// Excludes shrinkage / removal so the dialog can present additive
  /// notices only. Empty when no class entities or no entity map were
  /// supplied.
  Map<String, int> get resourcePoolDeltas {
    final out = <String, int>{};
    for (final e in newResourcePools.entries) {
      final diff = e.value - (prevResourcePools[e.key] ?? 0);
      if (diff > 0) out[e.key] = diff;
    }
    return out;
  }

  /// Per-spell-level slot increases (`newCount - prevCount`) for entries
  /// where the count actually grew. Empty for non-casters and for
  /// level transitions that don't unlock new slots.
  Map<int, int> get spellSlotsDelta {
    final prev = prevSpellSlots;
    final now = newSpellSlots;
    if (prev == null || now == null) return const {};
    final out = <int, int>{};
    for (final e in now.entries) {
      final diff = e.value - (prev[e.key] ?? 0);
      if (diff > 0) out[e.key] = diff;
    }
    return out;
  }
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

/// Cumulative feature-option pickers. Each (class, feature) maps level →
/// number of picks gained at that level. Drives Sorcerer Metamagic and
/// Warlock Eldritch Invocations: multiple `featureOption` pendings emit on
/// the same level-up. Option feats live under `feat-category: Feature
/// Option: <featureName>`; the dialog filters by category and excludes
/// already-picked option feats so each pending picks a distinct option.
const _cumulativePickProgression = <String, Map<String, Map<int, int>>>{
  'Sorcerer': {
    'Metamagic': {2: 2, 10: 1, 17: 1},
  },
  'Warlock': {
    'Eldritch Invocations': {1: 2, 5: 1, 7: 1, 9: 1, 12: 1, 15: 1, 18: 1},
  },
};

/// SRD §1: Extra Attack lands at L5 for most martials, with Fighter
/// scaling to 3 at L11 and 4 at L20. The planner derives the count
/// dynamically from the `extra_attack_count` effect on auto-granted feats
/// (see [resolveExtraAttackCountAt]); this constant is the fallback used
/// when no entity map is available so the dialog still flags L5.
const _extraAttackFallbackLevels = {5};

/// Slot map at [level] for [classEntity]. Delegates to the shared
/// `spellSlotsForClass` helper, which checks the entity's authored
/// `spell_slots_by_level` override first and falls back to the SRD
/// preset keyed off the class's `caster_kind` when none is present.
/// Returns the empty map for level 0 so the planner can distinguish
/// "below progression" from "no slots this tier".
Map<int, int>? _slotsAt(Entity? classEntity, int level) {
  if (level < 1) return const {};
  return spellSlotsForClass(classEntity, level);
}

List<String> _saveGrantsFromEffects(Object? effects) {
  if (effects is! List) return const [];
  final out = <String>[];
  for (final eff in effects) {
    if (eff is! Map) continue;
    if (eff['kind'] != 'proficiency_grant') continue;
    final tk = eff['target_kind'];
    if (tk != 'saving_throw' && tk != 'ability') continue;
    final ref = eff['target_ref'];
    if (ref is! Map) continue;
    final name = ref['name']?.toString();
    if (name == null || name.isEmpty) continue;
    if (!out.contains(name)) out.add(name);
  }
  return out;
}

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
      grantedSaveProficiencyNames: _saveGrantsFromEffects(row['effects']),
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
  Map<String, Entity> entities = const {},
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
  for (var l = clampedFrom + 1; l <= clampedTo; l++) {
    if (_asiOrFeatLevels.contains(l)) asi = true;
  }

  // Extra Attack: prefer the resolver (SRD class feats declare the count
  // via auto-granted `extra_attack_count` effects). When the entity map is
  // missing — e.g. legacy callers — fall back to the L5 heuristic so
  // martial classes still get a notice.
  final prevExtra = resolveExtraAttackCountAt(
    classEntity: classEntity,
    subclassEntity: subclassEntity,
    level: clampedFrom,
    entities: entities,
  );
  final newExtra = resolveExtraAttackCountAt(
    classEntity: classEntity,
    subclassEntity: subclassEntity,
    level: clampedTo,
    entities: entities,
  );
  var extra = newExtra > prevExtra;
  if (!extra && entities.isEmpty) {
    for (var l = clampedFrom + 1; l <= clampedTo; l++) {
      if (_extraAttackFallbackLevels.contains(l)) {
        extra = true;
        break;
      }
    }
  }

  // Subclass: SRD 2024 grants every class its subclass at L3. Detect by
  // feature-name "Subclass" so authored content driving its own naming
  // still triggers (e.g. "<Class> Subclass" or "Subclass feature").
  var subclass = false;
  for (final f in newFeatures) {
    if (f.source == (classEntity?.name ?? '') &&
        f.name.toLowerCase().contains('subclass')) {
      subclass = true;
      break;
    }
  }

  // Divine Order (Cleric L1) — feature-name match against the Cleric's L1
  // feature row. Triggers a `PendingChoiceKind.divineOrder` pick.
  var divineOrder = false;
  for (final f in newFeatures) {
    if (f.name == 'Divine Order') {
      divineOrder = true;
      break;
    }
  }

  // Feature-option pickers — generic 1-of-N subclass-feature picks (Hunter
  // Ranger Hunter's Prey, Defensive Tactics, Multiattack, Superior Hunter's
  // Defense; Fiend Warlock Fiendish Resilience; Warlock Pact Boon; Draconic
  // Sorcerer Draconic Spells). Adding a feature name here also requires
  // authoring the option feats under `feat-category: Feature Option: <name>`
  // in feats_class.dart.
  const featureOptionTriggers = <String>{
    "Hunter's Prey",
    'Defensive Tactics',
    'Multiattack',
    "Superior Hunter's Defense",
    'Pact Boon',
    'Draconic Spells',
    'Fiendish Resilience',
  };
  final featureOptionPicks = <String>[];
  for (final f in newFeatures) {
    if (featureOptionTriggers.contains(f.name) &&
        !featureOptionPicks.contains(f.name)) {
      featureOptionPicks.add(f.name);
    }
  }

  // Cumulative pickers — features that grant N picks per level (Sorcerer
  // Metamagic 2/1/1, Warlock Eldritch Invocations 2/1/1/1/1/1/1). Driven
  // directly off class name + level (the feature row may be named
  // "Metamagic (extra)" at L10, so name-matching is unreliable). Each pick
  // emits one PendingChoiceKind.featureOption; dialog filters feats by
  // `Feature Option: <name>` and excludes already-picked option feats.
  final cumulativeProg = _cumulativePickProgression[classEntity?.name];
  if (cumulativeProg != null) {
    for (final entry in cumulativeProg.entries) {
      for (var l = clampedFrom + 1; l <= clampedTo; l++) {
        final n = entry.value[l] ?? 0;
        for (var i = 0; i < n; i++) {
          featureOptionPicks.add(entry.key);
        }
      }
    }
  }

  // Weapon Mastery cap shifts when a new auto-granted class feat's
  // `weapon_mastery_count_bonus` value exceeds the prior level's max.
  final prevMastery = resolveWeaponMasteryCountAt(
    classEntity: classEntity,
    subclassEntity: subclassEntity,
    level: clampedFrom,
    entities: entities,
  );
  final newMastery = resolveWeaponMasteryCountAt(
    classEntity: classEntity,
    subclassEntity: subclassEntity,
    level: clampedTo,
    entities: entities,
  );

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
  int? cantripPrev;
  int? preparedCap;
  int? preparedPrev;
  int? maxSpell;
  Map<int, int>? prevSlots;
  Map<int, int>? newSlots;
  if (kind != CasterKind.none && clampedTo > 0) {
    cantripCap = levelTableValue(
            classEntity?.fields['cantrips_known_by_level'], clampedTo) ??
        defaultCantripsKnown(kind, clampedTo);
    preparedCap = levelTableValue(
            classEntity?.fields['prepared_spells_by_level'], clampedTo) ??
        defaultPreparedSpells(kind, clampedTo);
    if (clampedFrom >= 1) {
      cantripPrev = levelTableValue(
              classEntity?.fields['cantrips_known_by_level'], clampedFrom) ??
          defaultCantripsKnown(kind, clampedFrom);
      preparedPrev = levelTableValue(
              classEntity?.fields['prepared_spells_by_level'], clampedFrom) ??
          defaultPreparedSpells(kind, clampedFrom);
    } else {
      cantripPrev = 0;
      preparedPrev = 0;
    }
    maxSpell = maxPreparableSpellLevel(kind, clampedTo);
    // Authored class data takes precedence over the SRD default tables
    // so a homebrew class can ship its own slot progression.
    prevSlots = _slotsAt(classEntity, clampedFrom);
    newSlots = _slotsAt(classEntity, clampedTo);
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
    isSubclassLevel: subclass,
    isDivineOrderLevel: divineOrder,
    featureOptionPicks: featureOptionPicks,
    casterKind: kind,
    cantripsKnownAtNewLevel: cantripCap,
    cantripsKnownAtPrevLevel: cantripPrev,
    preparedSpellsAtNewLevel: preparedCap,
    preparedSpellsAtPrevLevel: preparedPrev,
    maxSpellLevelAtNewLevel: maxSpell,
    prevSpellSlots: prevSlots,
    newSpellSlots: newSlots,
    prevResourcePools: resolveResourcePoolsAt(
      classEntity: classEntity,
      subclassEntity: subclassEntity,
      level: clampedFrom,
      entities: entities,
    ),
    newResourcePools: resolveResourcePoolsAt(
      classEntity: classEntity,
      subclassEntity: subclassEntity,
      level: clampedTo,
      entities: entities,
    ),
    prevExtraAttackCount: prevExtra,
    newExtraAttackCount: newExtra,
    prevWeaponMasteryCount: prevMastery,
    newWeaponMasteryCount: newMastery,
  );
}
