/// Structural Pact Magic progression — the per-warlock-level `(slots, slotLevel)`
/// pair. A content package decides which class (`casterKind == pact`) reads
/// this table; SRD assigns it to `srd:warlock`. Refresh cadence (short rest)
/// is enforced by the rest service, not here.
class PactMagicEntry {
  final int slots;
  final int slotLevel;
  const PactMagicEntry({required this.slots, required this.slotLevel});

  @override
  bool operator ==(Object other) =>
      other is PactMagicEntry &&
      other.slots == slots &&
      other.slotLevel == slotLevel;
  @override
  int get hashCode => Object.hash(slots, slotLevel);
  @override
  String toString() => 'PactMagicEntry(slots: $slots, slotLevel: $slotLevel)';
}

class PactMagicTable {
  static const List<PactMagicEntry> _table = [
    PactMagicEntry(slots: 1, slotLevel: 1), // L1
    PactMagicEntry(slots: 2, slotLevel: 1),
    PactMagicEntry(slots: 2, slotLevel: 2),
    PactMagicEntry(slots: 2, slotLevel: 2),
    PactMagicEntry(slots: 2, slotLevel: 3),
    PactMagicEntry(slots: 2, slotLevel: 3),
    PactMagicEntry(slots: 2, slotLevel: 4),
    PactMagicEntry(slots: 2, slotLevel: 4),
    PactMagicEntry(slots: 2, slotLevel: 5),
    PactMagicEntry(slots: 2, slotLevel: 5), // L10
    PactMagicEntry(slots: 3, slotLevel: 5),
    PactMagicEntry(slots: 3, slotLevel: 5),
    PactMagicEntry(slots: 3, slotLevel: 5),
    PactMagicEntry(slots: 3, slotLevel: 5),
    PactMagicEntry(slots: 3, slotLevel: 5),
    PactMagicEntry(slots: 3, slotLevel: 5),
    PactMagicEntry(slots: 4, slotLevel: 5),
    PactMagicEntry(slots: 4, slotLevel: 5),
    PactMagicEntry(slots: 4, slotLevel: 5),
    PactMagicEntry(slots: 4, slotLevel: 5), // L20
  ];

  static PactMagicEntry forLevel(int pactClassLevel) {
    if (pactClassLevel < 1 || pactClassLevel > 20) {
      throw ArgumentError(
          'PactMagicTable.forLevel requires 1..20, got $pactClassLevel');
    }
    return _table[pactClassLevel - 1];
  }
}
