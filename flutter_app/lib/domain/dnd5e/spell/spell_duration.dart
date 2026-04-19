/// Sealed spell duration — distinct from EffectDuration because spell durations
/// include Concentration as a top-level sibling and instantaneous/permanent
/// distinctions matter for dispels and antimagic.
sealed class SpellDuration {
  const SpellDuration();
}

class SpellInstantaneous extends SpellDuration {
  const SpellInstantaneous();
  @override
  bool operator ==(Object other) => other is SpellInstantaneous;
  @override
  int get hashCode => (SpellInstantaneous).hashCode;
  @override
  String toString() => 'Instantaneous';
}

class SpellRounds extends SpellDuration {
  final int rounds;
  final bool concentration;
  const SpellRounds._(this.rounds, this.concentration);
  factory SpellRounds({required int rounds, bool concentration = false}) {
    if (rounds <= 0) throw ArgumentError('SpellRounds.rounds must be > 0');
    return SpellRounds._(rounds, concentration);
  }
  @override
  bool operator ==(Object other) =>
      other is SpellRounds &&
      other.rounds == rounds &&
      other.concentration == concentration;
  @override
  int get hashCode => Object.hash(rounds, concentration);
}

class SpellMinutes extends SpellDuration {
  final int minutes;
  final bool concentration;
  const SpellMinutes._(this.minutes, this.concentration);
  factory SpellMinutes({required int minutes, bool concentration = false}) {
    if (minutes <= 0) throw ArgumentError('SpellMinutes.minutes must be > 0');
    return SpellMinutes._(minutes, concentration);
  }
  @override
  bool operator ==(Object other) =>
      other is SpellMinutes &&
      other.minutes == minutes &&
      other.concentration == concentration;
  @override
  int get hashCode => Object.hash(minutes, concentration);
}

class SpellHours extends SpellDuration {
  final int hours;
  final bool concentration;
  const SpellHours._(this.hours, this.concentration);
  factory SpellHours({required int hours, bool concentration = false}) {
    if (hours <= 0) throw ArgumentError('SpellHours.hours must be > 0');
    return SpellHours._(hours, concentration);
  }
  @override
  bool operator ==(Object other) =>
      other is SpellHours &&
      other.hours == hours &&
      other.concentration == concentration;
  @override
  int get hashCode => Object.hash(hours, concentration);
}

class SpellDays extends SpellDuration {
  final int days;
  const SpellDays._(this.days);
  factory SpellDays(int days) {
    if (days <= 0) throw ArgumentError('SpellDays.days must be > 0');
    return SpellDays._(days);
  }
  @override
  bool operator ==(Object other) => other is SpellDays && other.days == days;
  @override
  int get hashCode => days.hashCode;
}

class SpellUntilDispelled extends SpellDuration {
  const SpellUntilDispelled();
  @override
  bool operator ==(Object other) => other is SpellUntilDispelled;
  @override
  int get hashCode => (SpellUntilDispelled).hashCode;
  @override
  String toString() => 'Until Dispelled';
}

class SpellSpecial extends SpellDuration {
  final String description;
  const SpellSpecial(this.description);
  @override
  bool operator ==(Object other) =>
      other is SpellSpecial && other.description == description;
  @override
  int get hashCode => Object.hash('SpellSpecial', description);
}
