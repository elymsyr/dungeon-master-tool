/// Current/max spell slots per spell level 1..9 (cantrips have no slots).
class SpellSlots {
  final List<_Slot> _byLevel; // index 0 = level 1

  SpellSlots._(List<_Slot> byLevel) : _byLevel = List.unmodifiable(byLevel);

  factory SpellSlots(Map<int, ({int current, int max})> slots) {
    final levels = List<_Slot>.filled(9, const _Slot(0, 0));
    slots.forEach((level, v) {
      if (level < 1 || level > 9) {
        throw ArgumentError('SpellSlots: level $level not in [1, 9]');
      }
      if (v.max < 0) throw ArgumentError('SpellSlots[$level].max must be >= 0');
      if (v.current < 0 || v.current > v.max) {
        throw ArgumentError(
            'SpellSlots[$level].current must be in [0, ${v.max}]');
      }
      levels[level - 1] = _Slot(v.current, v.max);
    });
    return SpellSlots._(levels);
  }

  factory SpellSlots.empty() =>
      SpellSlots._(List.filled(9, const _Slot(0, 0)));

  int currentOf(int level) => _at(level).current;
  int maxOf(int level) => _at(level).max;
  bool hasAvailable(int level) => currentOf(level) > 0;

  _Slot _at(int level) {
    if (level < 1 || level > 9) {
      throw ArgumentError('SpellSlots level $level not in [1, 9]');
    }
    return _byLevel[level - 1];
  }

  /// Consume one slot at [level]; throws if none remaining.
  SpellSlots spend(int level) {
    final s = _at(level);
    if (s.current == 0) {
      throw StateError('No level-$level spell slot remaining');
    }
    final updated = List<_Slot>.from(_byLevel);
    updated[level - 1] = _Slot(s.current - 1, s.max);
    return SpellSlots._(updated);
  }

  /// Restore all slots to max (long rest).
  SpellSlots restoreAll() =>
      SpellSlots._([for (final s in _byLevel) _Slot(s.max, s.max)]);

  @override
  bool operator ==(Object other) {
    if (other is! SpellSlots) return false;
    for (var i = 0; i < 9; i++) {
      if (_byLevel[i] != other._byLevel[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_byLevel);

  @override
  String toString() {
    final parts = <String>[];
    for (var i = 0; i < 9; i++) {
      final s = _byLevel[i];
      if (s.max > 0) parts.add('L${i + 1}:${s.current}/${s.max}');
    }
    return 'SpellSlots(${parts.join(', ')})';
  }
}

class _Slot {
  final int current;
  final int max;
  const _Slot(this.current, this.max);

  @override
  bool operator ==(Object other) =>
      other is _Slot && other.current == current && other.max == max;
  @override
  int get hashCode => Object.hash(current, max);
}
