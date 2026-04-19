import 'dart:math' as math;

import 'die.dart';

/// Parsed dice notation: "2d6+3", "d20", "1d8-1". Tier 0.
///
/// Grammar (whitespace insignificant):
///   expression  := term ( ('+'|'-') term )*
///   term        := [count]? 'd' sides | int
///   sides       := 4 | 6 | 8 | 10 | 12 | 20 | 100
///
/// Terms with a die component carry a signed count; flat integer terms
/// roll into [flatBonus]. Produced by [DiceExpression.parse] and rendered
/// canonically by [toString].
class DiceExpression {
  final List<DiceTerm> terms;
  final int flatBonus;

  const DiceExpression({required this.terms, required this.flatBonus});

  /// Pure flat amount — no dice.
  factory DiceExpression.flat(int amount) =>
      DiceExpression(terms: const [], flatBonus: amount);

  /// Single die group (e.g. `1d6`).
  factory DiceExpression.single(int count, Die die, {int flatBonus = 0}) =>
      DiceExpression(
        terms: [DiceTerm(count: count, die: die)],
        flatBonus: flatBonus,
      );

  static final _termRe = RegExp(r'([+-]?)\s*(\d*)d(\d+)', caseSensitive: false);
  static final _flatRe = RegExp(r'([+-]?)\s*(\d+)(?!\s*d)', caseSensitive: false);

  /// Parses a notation string. Throws [FormatException] on malformed input.
  /// Accepts standalone `d20` (count defaults to 1) and negative terms.
  static DiceExpression parse(String raw) {
    final input = raw.replaceAll(' ', '');
    if (input.isEmpty) {
      throw const FormatException('Empty dice expression');
    }

    final terms = <DiceTerm>[];
    var flat = 0;
    var cursor = 0;
    var matched = false;

    while (cursor < input.length) {
      final diceMatch = _termRe.matchAsPrefix(input, cursor);
      if (diceMatch != null) {
        final sign = diceMatch.group(1) == '-' ? -1 : 1;
        final countText = diceMatch.group(2) ?? '';
        final count = countText.isEmpty ? 1 : int.parse(countText);
        final sides = int.parse(diceMatch.group(3)!);
        terms.add(DiceTerm(count: sign * count, die: Die.fromSides(sides)));
        cursor = diceMatch.end;
        matched = true;
        continue;
      }
      final flatMatch = _flatRe.matchAsPrefix(input, cursor);
      if (flatMatch != null) {
        final sign = flatMatch.group(1) == '-' ? -1 : 1;
        flat += sign * int.parse(flatMatch.group(2)!);
        cursor = flatMatch.end;
        matched = true;
        continue;
      }
      throw FormatException('Cannot parse dice expression "$raw" at offset $cursor');
    }

    if (!matched) {
      throw FormatException('Cannot parse dice expression "$raw"');
    }
    return DiceExpression(terms: terms, flatBonus: flat);
  }

  /// Maximum possible total.
  int get maxTotal =>
      terms.fold<int>(flatBonus, (sum, t) => sum + t.count * t.die.sides);

  /// Minimum possible total (negative counts flip the direction).
  int get minTotal =>
      terms.fold<int>(flatBonus, (sum, t) => sum + t.count * (t.count >= 0 ? 1 : t.die.sides));

  /// Average damage (floor) — SRD fixed-damage convention.
  int get averageFloor {
    var avg = flatBonus;
    for (final t in terms) {
      avg += t.count * t.die.averageFloor;
    }
    return avg;
  }

  /// Rolls the expression using [rng]. Each die is rolled independently.
  /// Returns the summed result.
  int roll(math.Random rng) {
    var total = flatBonus;
    for (final t in terms) {
      final sign = t.count >= 0 ? 1 : -1;
      final rolls = t.count.abs();
      for (var i = 0; i < rolls; i++) {
        total += sign * (rng.nextInt(t.die.sides) + 1);
      }
    }
    return total;
  }

  @override
  String toString() {
    if (terms.isEmpty) return flatBonus.toString();
    final buf = StringBuffer();
    for (var i = 0; i < terms.length; i++) {
      final t = terms[i];
      if (i == 0) {
        if (t.count < 0) buf.write('-');
      } else {
        buf.write(t.count < 0 ? '-' : '+');
      }
      final c = t.count.abs();
      if (c != 1) buf.write(c);
      buf.write(t.die.notation);
    }
    if (flatBonus > 0) buf.write('+$flatBonus');
    if (flatBonus < 0) buf.write(flatBonus);
    return buf.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiceExpression) return false;
    if (other.flatBonus != flatBonus) return false;
    if (other.terms.length != terms.length) return false;
    for (var i = 0; i < terms.length; i++) {
      if (other.terms[i] != terms[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(flatBonus, Object.hashAll(terms));
}

/// One `NdS` group inside a [DiceExpression].
class DiceTerm {
  final int count;
  final Die die;

  const DiceTerm({required this.count, required this.die});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiceTerm && other.count == count && other.die == die;

  @override
  int get hashCode => Object.hash(count, die);
}
