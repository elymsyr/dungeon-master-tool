import 'dart:math' as math;

/// Zar atma abstraksiyonu — rule engine ve d20 test service bu interface
/// üstünden kullanır. Test'te [SeededDiceRoller] ile deterministik.
abstract class DiceRoller {
  /// "2d6+3", "1d20", "3d8-1" gibi standart notation'ı çöz + rastgele sonuç.
  int roll(String notation);

  /// Notation'ın ortalama (average) sonucu — rastgelelik gerekmiyorsa.
  /// Örn "2d6+3" → 2*3.5 + 3 = 10.
  double average(String notation);
}

/// Cryptographically-insecure default — `dart:math.Random`.
class DefaultDiceRoller implements DiceRoller {
  DefaultDiceRoller([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;

  @override
  int roll(String notation) {
    final parsed = _parseNotation(notation);
    var total = 0;
    for (var i = 0; i < parsed.count; i++) {
      total += _random.nextInt(parsed.sides) + 1;
    }
    return total + parsed.bonus;
  }

  @override
  double average(String notation) {
    final parsed = _parseNotation(notation);
    return parsed.count * (parsed.sides + 1) / 2.0 + parsed.bonus;
  }
}

/// Deterministik roller — test'te kullanım: `SeededDiceRoller(42)`.
class SeededDiceRoller extends DefaultDiceRoller {
  SeededDiceRoller(int seed) : super(math.Random(seed));
}

/// Sabit değer dönen roller — "1d20 = 15" senaryoları için.
/// `average()` gerçek matematiksel ortalamayı döner (notation-bazlı);
/// yalnız `roll()` sabit.
class FixedDiceRoller implements DiceRoller {
  FixedDiceRoller(this._fixed);

  final int _fixed;

  @override
  int roll(String notation) => _fixed;

  @override
  double average(String notation) {
    final parsed = _parseNotation(notation);
    return parsed.count * (parsed.sides + 1) / 2.0 + parsed.bonus;
  }
}

class _ParsedDice {
  const _ParsedDice({
    required this.count,
    required this.sides,
    required this.bonus,
  });

  final int count;
  final int sides;
  final int bonus;
}

/// "NdM+K" veya "NdM-K" ya da sadece "NdM" parse eder.
/// Boşluklar tolere edilir. Geçersizlik → FormatException.
_ParsedDice _parseNotation(String notation) {
  final clean = notation.replaceAll(' ', '').toLowerCase();
  final match = RegExp(r'^(\d+)d(\d+)([+-]\d+)?$').firstMatch(clean);
  if (match == null) {
    throw FormatException('Invalid dice notation: $notation');
  }
  return _ParsedDice(
    count: int.parse(match.group(1)!),
    sides: int.parse(match.group(2)!),
    bonus: match.group(3) == null ? 0 : int.parse(match.group(3)!),
  );
}
