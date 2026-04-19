/// Structural D&D 5e spell-slot table. Identical for all full casters; half
/// and third casters index via their combined caster level which has already
/// had the fraction applied. Warlock (Pact) uses [PactMagicTable] instead.
///
/// `slotsForCasterLevel[cl - 1]` is a 9-element list indexed by `spellLevel - 1`
/// (level 1..9). Cantrip slot count is progression-free; not tracked here.
class SpellSlotProgression {
  static const List<List<int>> _table = [
    [2, 0, 0, 0, 0, 0, 0, 0, 0], //  1
    [3, 0, 0, 0, 0, 0, 0, 0, 0],
    [4, 2, 0, 0, 0, 0, 0, 0, 0],
    [4, 3, 0, 0, 0, 0, 0, 0, 0],
    [4, 3, 2, 0, 0, 0, 0, 0, 0],
    [4, 3, 3, 0, 0, 0, 0, 0, 0],
    [4, 3, 3, 1, 0, 0, 0, 0, 0],
    [4, 3, 3, 2, 0, 0, 0, 0, 0],
    [4, 3, 3, 3, 1, 0, 0, 0, 0],
    [4, 3, 3, 3, 2, 0, 0, 0, 0], // 10
    [4, 3, 3, 3, 2, 1, 0, 0, 0],
    [4, 3, 3, 3, 2, 1, 0, 0, 0],
    [4, 3, 3, 3, 2, 1, 1, 0, 0],
    [4, 3, 3, 3, 2, 1, 1, 0, 0],
    [4, 3, 3, 3, 2, 1, 1, 1, 0],
    [4, 3, 3, 3, 2, 1, 1, 1, 0],
    [4, 3, 3, 3, 2, 1, 1, 1, 1],
    [4, 3, 3, 3, 3, 1, 1, 1, 1],
    [4, 3, 3, 3, 3, 2, 1, 1, 1],
    [4, 3, 3, 3, 3, 2, 2, 1, 1], // 20
  ];

  /// Returns a 9-element list of slot counts (spell level 1..9).
  /// `casterLevel == 0` → all zeros.
  static List<int> slotsForCasterLevel(int casterLevel) {
    if (casterLevel < 0) {
      throw ArgumentError('casterLevel must be >= 0, got $casterLevel');
    }
    if (casterLevel > 20) {
      throw ArgumentError('casterLevel must be <= 20, got $casterLevel');
    }
    if (casterLevel == 0) return List.unmodifiable(List.filled(9, 0));
    return List.unmodifiable(_table[casterLevel - 1]);
  }
}
