/// Sealed casting time. Action/Bonus/Reaction are the three combat-action
/// kinds; Minutes/Hours cover ritual and long-cast spells.
sealed class CastingTime {
  const CastingTime();
}

class ActionCast extends CastingTime {
  const ActionCast();
  @override
  bool operator ==(Object other) => other is ActionCast;
  @override
  int get hashCode => (ActionCast).hashCode;
  @override
  String toString() => '1 action';
}

class BonusActionCast extends CastingTime {
  const BonusActionCast();
  @override
  bool operator ==(Object other) => other is BonusActionCast;
  @override
  int get hashCode => (BonusActionCast).hashCode;
  @override
  String toString() => '1 bonus action';
}

class ReactionCast extends CastingTime {
  final String trigger;
  const ReactionCast(this.trigger);
  @override
  bool operator ==(Object other) =>
      other is ReactionCast && other.trigger == trigger;
  @override
  int get hashCode => Object.hash('ReactionCast', trigger);
  @override
  String toString() => 'Reaction: $trigger';
}

class MinutesCast extends CastingTime {
  final int minutes;
  const MinutesCast._(this.minutes);
  factory MinutesCast(int minutes) {
    if (minutes <= 0) throw ArgumentError('MinutesCast.minutes must be > 0');
    return MinutesCast._(minutes);
  }
  @override
  bool operator ==(Object other) =>
      other is MinutesCast && other.minutes == minutes;
  @override
  int get hashCode => Object.hash('MinutesCast', minutes);
  @override
  String toString() => '$minutes minute(s)';
}

class HoursCast extends CastingTime {
  final int hours;
  const HoursCast._(this.hours);
  factory HoursCast(int hours) {
    if (hours <= 0) throw ArgumentError('HoursCast.hours must be > 0');
    return HoursCast._(hours);
  }
  @override
  bool operator ==(Object other) =>
      other is HoursCast && other.hours == hours;
  @override
  int get hashCode => Object.hash('HoursCast', hours);
  @override
  String toString() => '$hours hour(s)';
}
