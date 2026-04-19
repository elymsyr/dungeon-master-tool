/// Running tally of death save successes and failures. Tier 0.
///
/// SRD rules:
/// - Natural 1 on death save = 2 failures.
/// - Natural 20 = recover 1 HP (caller clears state).
/// - 3 successes → stable (unconscious, not dying).
/// - 3 failures → dead.
class DeathSaves {
  final int successes;
  final int failures;

  const DeathSaves._(this.successes, this.failures);

  factory DeathSaves({int successes = 0, int failures = 0}) {
    if (successes < 0 || successes > 3) {
      throw ArgumentError('successes $successes outside [0, 3]');
    }
    if (failures < 0 || failures > 3) {
      throw ArgumentError('failures $failures outside [0, 3]');
    }
    return DeathSaves._(successes, failures);
  }

  static const zero = DeathSaves._(0, 0);

  bool get isStable => successes >= 3;
  bool get isDead => failures >= 3;
  bool get isActive => !isStable && !isDead;

  DeathSaves addSuccess() =>
      DeathSaves._((successes + 1).clamp(0, 3), failures);

  DeathSaves addFailure() =>
      DeathSaves._(successes, (failures + 1).clamp(0, 3));

  /// Critical failure (natural 1) counts as two failures.
  DeathSaves addCriticalFailure() =>
      DeathSaves._(successes, (failures + 2).clamp(0, 3));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeathSaves &&
          other.successes == successes &&
          other.failures == failures;

  @override
  int get hashCode => Object.hash(successes, failures);

  @override
  String toString() => 'DeathSaves($successes✓/$failures✗)';
}
