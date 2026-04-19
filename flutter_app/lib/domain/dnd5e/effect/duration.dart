/// D&D 5e rest kinds — relevant for UntilRest durations.
enum RestKind { shortRest, longRest }

/// Tier 2: how long an effect lasts.
///
/// Named [EffectDuration] (not `Duration`) to avoid shadowing `dart:core`'s
/// [Duration]. Doc 01 uses the bare name; the domain rename is mechanical.
sealed class EffectDuration {
  const EffectDuration();
}

class Instantaneous extends EffectDuration {
  const Instantaneous();

  @override
  bool operator ==(Object other) => other is Instantaneous;
  @override
  int get hashCode => (Instantaneous).hashCode;
  @override
  String toString() => 'Instantaneous';
}

class RoundsDuration extends EffectDuration {
  final int rounds;
  const RoundsDuration._(this.rounds);
  factory RoundsDuration(int rounds) {
    if (rounds <= 0) throw ArgumentError('RoundsDuration.rounds must be > 0');
    return RoundsDuration._(rounds);
  }

  @override
  bool operator ==(Object other) =>
      other is RoundsDuration && other.rounds == rounds;
  @override
  int get hashCode => Object.hash('RoundsDuration', rounds);
  @override
  String toString() => 'RoundsDuration($rounds)';
}

class MinutesDuration extends EffectDuration {
  final int minutes;
  const MinutesDuration._(this.minutes);
  factory MinutesDuration(int minutes) {
    if (minutes <= 0) throw ArgumentError('MinutesDuration.minutes must be > 0');
    return MinutesDuration._(minutes);
  }

  @override
  bool operator ==(Object other) =>
      other is MinutesDuration && other.minutes == minutes;
  @override
  int get hashCode => Object.hash('MinutesDuration', minutes);
  @override
  String toString() => 'MinutesDuration($minutes)';
}

class UntilRest extends EffectDuration {
  final RestKind kind;
  const UntilRest(this.kind);

  @override
  bool operator ==(Object other) => other is UntilRest && other.kind == kind;
  @override
  int get hashCode => Object.hash('UntilRest', kind);
  @override
  String toString() => 'UntilRest($kind)';
}

/// Wraps another duration to also end on loss of concentration.
class ConcentrationDuration extends EffectDuration {
  final EffectDuration max;
  const ConcentrationDuration(this.max);

  @override
  bool operator ==(Object other) =>
      other is ConcentrationDuration && other.max == max;
  @override
  int get hashCode => Object.hash('ConcentrationDuration', max);
  @override
  String toString() => 'ConcentrationDuration($max)';
}

class UntilRemoved extends EffectDuration {
  const UntilRemoved();

  @override
  bool operator ==(Object other) => other is UntilRemoved;
  @override
  int get hashCode => (UntilRemoved).hashCode;
  @override
  String toString() => 'UntilRemoved';
}
