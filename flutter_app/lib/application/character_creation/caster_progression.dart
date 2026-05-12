// Pure helpers for D&D 5e caster progression — derives spell-related
// caps when the class entity's level tables aren't populated. Wired into
// the character-creation wizard's Spells step. Kept dependency-free so
// it can be unit-tested without Flutter/Riverpod.

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
