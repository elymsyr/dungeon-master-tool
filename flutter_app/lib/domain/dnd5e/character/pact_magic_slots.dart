/// Warlock Pact Magic: a small number of slots, all of the same level, that
/// refresh on a short rest. Distinct from [SpellSlots] because the resolver
/// spends pact slots first for Warlocks per SRD.
class PactMagicSlots {
  final int slotLevel;
  final int current;
  final int max;

  const PactMagicSlots._(this.slotLevel, this.current, this.max);

  factory PactMagicSlots({
    required int slotLevel,
    required int current,
    required int max,
  }) {
    if (slotLevel < 1 || slotLevel > 5) {
      throw ArgumentError('PactMagicSlots.slotLevel must be in [1, 5]');
    }
    if (max < 0) throw ArgumentError('PactMagicSlots.max must be >= 0');
    if (current < 0 || current > max) {
      throw ArgumentError('PactMagicSlots.current must be in [0, $max]');
    }
    return PactMagicSlots._(slotLevel, current, max);
  }

  PactMagicSlots spend() {
    if (current == 0) throw StateError('No pact slots remaining');
    return PactMagicSlots._(slotLevel, current - 1, max);
  }

  PactMagicSlots restore() => PactMagicSlots._(slotLevel, max, max);

  @override
  bool operator ==(Object other) =>
      other is PactMagicSlots &&
      other.slotLevel == slotLevel &&
      other.current == current &&
      other.max == max;

  @override
  int get hashCode => Object.hash(slotLevel, current, max);

  @override
  String toString() => 'PactMagicSlots(L$slotLevel $current/$max)';
}
