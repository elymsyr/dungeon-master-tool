/// D&D 5e Challenge Rating. Stored as canonical fraction string per spec
/// §Open Questions to avoid float equality. Tier 0.
class ChallengeRating {
  /// Canonical representation: '0', '1/8', '1/4', '1/2', '1', '2', ..., '30'.
  final String canonical;

  const ChallengeRating._(this.canonical);

  factory ChallengeRating.parse(String s) {
    final trimmed = s.trim();
    if (!_validCanonical.contains(trimmed)) {
      throw ArgumentError('Invalid CR "$s"');
    }
    return ChallengeRating._(trimmed);
  }

  factory ChallengeRating.fromDouble(double v) {
    if (v == 0) return const ChallengeRating._('0');
    if (v == 0.125) return const ChallengeRating._('1/8');
    if (v == 0.25) return const ChallengeRating._('1/4');
    if (v == 0.5) return const ChallengeRating._('1/2');
    final i = v.truncate();
    if (i.toDouble() == v && i >= 1 && i <= 30) {
      return ChallengeRating._(i.toString());
    }
    throw ArgumentError('Invalid CR double $v');
  }

  double toDouble() => switch (canonical) {
        '0' => 0,
        '1/8' => 0.125,
        '1/4' => 0.25,
        '1/2' => 0.5,
        _ => double.parse(canonical),
      };

  /// XP reward per SRD 5.2.1 Monsters by CR table.
  int get xp => _xpTable[canonical]!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeRating && other.canonical == canonical;

  @override
  int get hashCode => canonical.hashCode;

  @override
  String toString() => 'CR $canonical';

  static const _validCanonical = {
    '0', '1/8', '1/4', '1/2',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
    '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
    '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
  };

  static const Map<String, int> _xpTable = {
    '0': 10,
    '1/8': 25,
    '1/4': 50,
    '1/2': 100,
    '1': 200,
    '2': 450,
    '3': 700,
    '4': 1100,
    '5': 1800,
    '6': 2300,
    '7': 2900,
    '8': 3900,
    '9': 5000,
    '10': 5900,
    '11': 7200,
    '12': 8400,
    '13': 10000,
    '14': 11500,
    '15': 13000,
    '16': 15000,
    '17': 18000,
    '18': 20000,
    '19': 22000,
    '20': 25000,
    '21': 33000,
    '22': 41000,
    '23': 50000,
    '24': 62000,
    '25': 75000,
    '26': 90000,
    '27': 105000,
    '28': 120000,
    '29': 135000,
    '30': 155000,
  };
}
