/// Initiative order snapshot. Higher roll acts first; ties broken by
/// [tieBreaker] (higher dex mod wins, then stable id order). Once built,
/// the order is immutable for the encounter round.
class InitiativeOrder {
  final List<String> combatantIds;
  final int currentIndex;

  InitiativeOrder._(this.combatantIds, this.currentIndex);

  factory InitiativeOrder({
    required List<String> combatantIds,
    int currentIndex = 0,
  }) {
    if (combatantIds.isEmpty) {
      throw ArgumentError(
          'InitiativeOrder.combatantIds must have at least one entry');
    }
    if (currentIndex < 0 || currentIndex >= combatantIds.length) {
      throw ArgumentError(
          'InitiativeOrder.currentIndex out of range [0, ${combatantIds.length - 1}]');
    }
    return InitiativeOrder._(List.unmodifiable(combatantIds), currentIndex);
  }

  String get currentId => combatantIds[currentIndex];

  InitiativeOrder advance() {
    final next = (currentIndex + 1) % combatantIds.length;
    return InitiativeOrder._(combatantIds, next);
  }

  /// Sort helper: `(roll, tieBreaker, id)` descending on first two, ascending
  /// on id for stable determinism.
  static List<String> sortIds(
      Map<String, ({int roll, int tieBreaker})> rolls) {
    final entries = rolls.entries.toList()
      ..sort((a, b) {
        final r = b.value.roll.compareTo(a.value.roll);
        if (r != 0) return r;
        final t = b.value.tieBreaker.compareTo(a.value.tieBreaker);
        if (t != 0) return t;
        return a.key.compareTo(b.key);
      });
    return [for (final e in entries) e.key];
  }
}
