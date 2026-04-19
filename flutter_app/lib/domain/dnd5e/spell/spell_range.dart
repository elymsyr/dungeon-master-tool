/// Sealed spell range variants.
sealed class SpellRange {
  const SpellRange();
}

class SelfRange extends SpellRange {
  const SelfRange();
  @override
  bool operator ==(Object other) => other is SelfRange;
  @override
  int get hashCode => (SelfRange).hashCode;
  @override
  String toString() => 'Self';
}

class TouchRange extends SpellRange {
  const TouchRange();
  @override
  bool operator ==(Object other) => other is TouchRange;
  @override
  int get hashCode => (TouchRange).hashCode;
  @override
  String toString() => 'Touch';
}

class FeetRange extends SpellRange {
  final double feet;
  const FeetRange._(this.feet);
  factory FeetRange(double feet) {
    if (feet <= 0) throw ArgumentError('FeetRange.feet must be > 0');
    return FeetRange._(feet);
  }
  @override
  bool operator ==(Object other) =>
      other is FeetRange && other.feet == feet;
  @override
  int get hashCode => Object.hash('FeetRange', feet);
  @override
  String toString() => '$feet ft';
}

class MilesRange extends SpellRange {
  final double miles;
  const MilesRange._(this.miles);
  factory MilesRange(double miles) {
    if (miles <= 0) throw ArgumentError('MilesRange.miles must be > 0');
    return MilesRange._(miles);
  }
  @override
  bool operator ==(Object other) =>
      other is MilesRange && other.miles == miles;
  @override
  int get hashCode => Object.hash('MilesRange', miles);
  @override
  String toString() => '$miles mi';
}

class SightRange extends SpellRange {
  const SightRange();
  @override
  bool operator ==(Object other) => other is SightRange;
  @override
  int get hashCode => (SightRange).hashCode;
  @override
  String toString() => 'Sight';
}

class UnlimitedRange extends SpellRange {
  const UnlimitedRange();
  @override
  bool operator ==(Object other) => other is UnlimitedRange;
  @override
  int get hashCode => (UnlimitedRange).hashCode;
  @override
  String toString() => 'Unlimited';
}
