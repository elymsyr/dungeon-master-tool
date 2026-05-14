// Pure helpers for D&D 5e caster progression — derives spell-related
// caps when the class entity's level tables aren't populated. Wired into
// the character-creation wizard's Spells step. Kept dependency-free so
// it can be unit-tested without Flutter/Riverpod.

import '../../domain/entities/entity.dart';

/// Caster classification per the class schema's `caster_kind` enum.
/// Treats unknown / 'None' / 'Ritual' inputs as non-casters.
enum CasterKind { none, full, half, third, pact }

CasterKind parseCasterKind(Object? raw) {
  final s = raw?.toString() ?? '';
  return switch (s) {
    'Full' => CasterKind.full,
    'Half' => CasterKind.half,
    'Third' => CasterKind.third,
    'Pact' => CasterKind.pact,
    _ => CasterKind.none,
  };
}

/// Looks up a per-level integer in a `Map<int,int>`-shaped levelTable
/// value pulled out of an entity. Empty / null / wrong-shape maps return
/// null so callers can fall back to a generated default.
int? levelTableValue(Object? raw, int level) {
  if (raw is! Map) return null;
  for (final entry in raw.entries) {
    final k = entry.key;
    final kInt = k is int ? k : int.tryParse(k.toString());
    if (kInt == level) {
      final v = entry.value;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }
  }
  return null;
}

/// SRD-default cantrip count at character level [level] when the class
/// entity hasn't populated `cantrips_known_by_level`. Returns 0 for
/// non-cantrip classes (Half/Third generally don't have cantrips at L1).
int defaultCantripsKnown(CasterKind kind, int level) {
  if (level < 1) return 0;
  // Full caster cantrip table is class-specific (Bard=2/3/4, Wizard=3/4/5,
  // etc.). Pick a reasonable middle so users see a sane cap when the
  // entity has nothing populated — caller surfaces a "populate the
  // class table for exact counts" hint to the user.
  return switch (kind) {
    CasterKind.full => level < 4
        ? 3
        : level < 10
            ? 4
            : 5,
    CasterKind.pact => level < 4
        ? 2
        : level < 10
            ? 3
            : 4,
    CasterKind.half ||
    CasterKind.third ||
    CasterKind.none =>
      0,
  };
}

/// SRD-default prepared/known spell count at character level [level].
/// Pure fallback when the class entity's `prepared_spells_by_level`
/// is empty. Numbers approximate the canonical Wizard/Cleric prepared
/// progression (Spellcasting Ability mod + Class level / 2 etc.) but
/// use a flat curve for legibility.
int defaultPreparedSpells(CasterKind kind, int level) {
  if (level < 1) return 0;
  return switch (kind) {
    CasterKind.full => level + 3, // L1=4, L5=8 — Wizard-ish curve
    CasterKind.half => level < 2 ? 0 : ((level / 2).floor() + 1),
    CasterKind.third => level < 3 ? 0 : ((level - 2) ~/ 2 + 1),
    CasterKind.pact => (level + 1) ~/ 2 + 1, // L1=2 known
    CasterKind.none => 0,
  };
}

/// Highest spell level the character can prepare/know at [level]. Drives
/// the spell-picker's level filter. Returns 0 for non-casters.
int maxPreparableSpellLevel(CasterKind kind, int level) {
  if (level < 1) return 0;
  return switch (kind) {
    CasterKind.full => ((level + 1) / 2).floor().clamp(1, 9),
    CasterKind.half =>
      level < 2 ? 0 : (((level - 1) / 4).floor() + 1).clamp(1, 5),
    CasterKind.third =>
      level < 3 ? 0 : (((level - 3) / 4).floor() + 1).clamp(1, 4),
    CasterKind.pact => ((level + 1) / 2).floor().clamp(1, 5),
    CasterKind.none => 0,
  };
}

// SRD §1.5 spell-slot tables, indexed by character level - 1.
// Each row is `[slots at L1, L2, ..., LMax]`; zeros are sparse-encoded
// (omitted) in the public map.

const _fullCasterSlots = <List<int>>[
  [2, 0, 0, 0, 0, 0, 0, 0, 0],
  [3, 0, 0, 0, 0, 0, 0, 0, 0],
  [4, 2, 0, 0, 0, 0, 0, 0, 0],
  [4, 3, 0, 0, 0, 0, 0, 0, 0],
  [4, 3, 2, 0, 0, 0, 0, 0, 0],
  [4, 3, 3, 0, 0, 0, 0, 0, 0],
  [4, 3, 3, 1, 0, 0, 0, 0, 0],
  [4, 3, 3, 2, 0, 0, 0, 0, 0],
  [4, 3, 3, 3, 1, 0, 0, 0, 0],
  [4, 3, 3, 3, 2, 0, 0, 0, 0],
  [4, 3, 3, 3, 2, 1, 0, 0, 0],
  [4, 3, 3, 3, 2, 1, 0, 0, 0],
  [4, 3, 3, 3, 2, 1, 1, 0, 0],
  [4, 3, 3, 3, 2, 1, 1, 0, 0],
  [4, 3, 3, 3, 2, 1, 1, 1, 0],
  [4, 3, 3, 3, 2, 1, 1, 1, 0],
  [4, 3, 3, 3, 2, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 2, 1, 1],
];

const _halfCasterSlots = <List<int>>[
  [0, 0, 0, 0, 0],
  [2, 0, 0, 0, 0],
  [3, 0, 0, 0, 0],
  [3, 0, 0, 0, 0],
  [4, 2, 0, 0, 0],
  [4, 2, 0, 0, 0],
  [4, 3, 0, 0, 0],
  [4, 3, 0, 0, 0],
  [4, 3, 2, 0, 0],
  [4, 3, 2, 0, 0],
  [4, 3, 3, 0, 0],
  [4, 3, 3, 0, 0],
  [4, 3, 3, 1, 0],
  [4, 3, 3, 1, 0],
  [4, 3, 3, 2, 0],
  [4, 3, 3, 2, 0],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 2],
  [4, 3, 3, 3, 2],
];

const _thirdCasterSlots = <List<int>>[
  [0, 0, 0, 0],
  [0, 0, 0, 0],
  [2, 0, 0, 0],
  [3, 0, 0, 0],
  [3, 0, 0, 0],
  [3, 0, 0, 0],
  [4, 2, 0, 0],
  [4, 2, 0, 0],
  [4, 2, 0, 0],
  [4, 3, 0, 0],
  [4, 3, 0, 0],
  [4, 3, 0, 0],
  [4, 3, 2, 0],
  [4, 3, 2, 0],
  [4, 3, 2, 0],
  [4, 3, 3, 0],
  [4, 3, 3, 0],
  [4, 3, 3, 0],
  [4, 3, 3, 1],
  [4, 3, 3, 1],
];

// Pact (Warlock): `[count, slotLevel]` — all slots are at the same level
// and recharge on a short rest, not a long one.
const _pactSlots = <List<int>>[
  [1, 1],
  [2, 1],
  [2, 2],
  [2, 2],
  [2, 3],
  [2, 3],
  [2, 4],
  [2, 4],
  [2, 5],
  [2, 5],
  [3, 5],
  [3, 5],
  [3, 5],
  [3, 5],
  [3, 5],
  [3, 5],
  [4, 5],
  [4, 5],
  [4, 5],
  [4, 5],
];

/// Read an author-supplied override `spell_slots_by_level` map at character
/// level [level]. Shape: `Map<level, Map<spellLevel, count>>` with keys
/// stringified for JSON. Returns null when the override is absent, malformed,
/// or doesn't carry a row for [level]. Empty rows return an empty map so
/// callers distinguish "override says zero" from "no override".
Map<int, int>? slotsByLevelOverride(Object? raw, int level) {
  if (raw is! Map) return null;
  for (final entry in raw.entries) {
    final k = entry.key;
    final kInt = k is int ? k : int.tryParse(k.toString());
    if (kInt != level) continue;
    final row = entry.value;
    if (row is! Map) return null;
    final out = <int, int>{};
    for (final cell in row.entries) {
      final sl = cell.key is int
          ? cell.key as int
          : int.tryParse(cell.key.toString());
      if (sl == null) continue;
      final n = cell.value;
      final count = n is int
          ? n
          : (n is num ? n.toInt() : int.tryParse(n.toString()));
      if (count == null || count <= 0) continue;
      out[sl] = count;
    }
    return out;
  }
  return null;
}

/// Class-aware slot lookup. Returns the author's `spell_slots_by_level`
/// override when present; otherwise falls back to the SRD preset keyed off
/// the class's `caster_kind`. Returns empty map for non-casters.
Map<int, int> spellSlotsForClass(Entity? cls, int level) {
  if (cls == null) return const {};
  final override = slotsByLevelOverride(cls.fields['spell_slots_by_level'], level);
  if (override != null) return override;
  return defaultSpellSlotsByLevel(parseCasterKind(cls.fields['caster_kind']), level);
}

/// SRD §1.5 default spell-slot map at character level [level]. The result
/// keys are spell levels (1..9), values are slot counts. Empty map for
/// non-casters or sub-progression levels (Half before L2, Third before
/// L3). Pact returns a single entry `{slotLevel: count}` because Warlock
/// slots all share one level and recharge on a short rest — the caller
/// must use the `spell_slots.remaining` map *and* know the recharge
/// cadence.
Map<int, int> defaultSpellSlotsByLevel(CasterKind kind, int level) {
  if (level < 1) return const {};
  final lvl = level.clamp(1, 20);
  final out = <int, int>{};
  switch (kind) {
    case CasterKind.full:
      final row = _fullCasterSlots[lvl - 1];
      for (var i = 0; i < row.length; i++) {
        if (row[i] > 0) out[i + 1] = row[i];
      }
    case CasterKind.half:
      final row = _halfCasterSlots[lvl - 1];
      for (var i = 0; i < row.length; i++) {
        if (row[i] > 0) out[i + 1] = row[i];
      }
    case CasterKind.third:
      final row = _thirdCasterSlots[lvl - 1];
      for (var i = 0; i < row.length; i++) {
        if (row[i] > 0) out[i + 1] = row[i];
      }
    case CasterKind.pact:
      final p = _pactSlots[lvl - 1];
      if (p[0] > 0) out[p[1]] = p[0];
    case CasterKind.none:
      break;
  }
  return out;
}
