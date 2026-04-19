import '../core/die.dart';

/// Remaining and max hit dice per die type (one bucket per distinct class die).
class HitDicePool {
  final Map<Die, _HDBucket> _buckets;

  HitDicePool._(Map<Die, _HDBucket> buckets)
      : _buckets = Map.unmodifiable(buckets);

  factory HitDicePool(Map<Die, ({int remaining, int max})> buckets) {
    final normalised = <Die, _HDBucket>{};
    buckets.forEach((die, v) {
      if (v.max < 0) {
        throw ArgumentError('HitDicePool[$die].max must be >= 0');
      }
      if (v.remaining < 0 || v.remaining > v.max) {
        throw ArgumentError(
            'HitDicePool[$die].remaining must be in [0, ${v.max}]');
      }
      normalised[die] = _HDBucket(v.remaining, v.max);
    });
    return HitDicePool._(normalised);
  }

  factory HitDicePool.empty() => HitDicePool._(const {});

  int remainingOf(Die die) => _buckets[die]?.remaining ?? 0;
  int maxOf(Die die) => _buckets[die]?.max ?? 0;
  Iterable<Die> get dieTypes => _buckets.keys;

  /// Spend one die of [die]; throws if none remain.
  HitDicePool spend(Die die) {
    final b = _buckets[die];
    if (b == null || b.remaining == 0) {
      throw StateError('No $die hit dice remaining');
    }
    return _with(die, b.remaining - 1, b.max);
  }

  /// Long-rest recovery: half of total HD (rounded down, min 1 per die type
  /// with max > 0). Per SRD, player chooses which dice to recover; here we
  /// recover proportionally per bucket.
  HitDicePool recoverLongRest() {
    final totalMax = _buckets.values.fold<int>(0, (s, b) => s + b.max);
    if (totalMax == 0) return this;
    final toRecover = (totalMax ~/ 2).clamp(1, totalMax);
    final updated = <Die, _HDBucket>{};
    var left = toRecover;
    for (final entry in _buckets.entries) {
      final b = entry.value;
      final missing = b.max - b.remaining;
      final take = left < missing ? left : missing;
      updated[entry.key] = _HDBucket(b.remaining + take, b.max);
      left -= take;
    }
    return HitDicePool._(updated);
  }

  HitDicePool _with(Die die, int remaining, int max) {
    final updated = Map<Die, _HDBucket>.from(_buckets);
    updated[die] = _HDBucket(remaining, max);
    return HitDicePool._(updated);
  }

  @override
  bool operator ==(Object other) =>
      other is HitDicePool && _mapEq(other._buckets, _buckets);

  @override
  int get hashCode =>
      Object.hashAll(_buckets.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() {
    final parts = _buckets.entries
        .map((e) => '${e.key.notation}:${e.value.remaining}/${e.value.max}');
    return 'HitDicePool(${parts.join(', ')})';
  }
}

class _HDBucket {
  final int remaining;
  final int max;
  const _HDBucket(this.remaining, this.max);

  @override
  bool operator ==(Object other) =>
      other is _HDBucket && other.remaining == remaining && other.max == max;

  @override
  int get hashCode => Object.hash(remaining, max);
}

bool _mapEq(Map<Die, _HDBucket> a, Map<Die, _HDBucket> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
