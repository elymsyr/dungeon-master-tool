import 'dart:math' as math;

import '../../../domain/dnd5e/core/dice_expression.dart';
import '../../../domain/dnd5e/core/die.dart';

/// Convenience roller for single-die and expression rolls. Wraps a
/// `Random` so callers (tests, deterministic replays) can inject a seed.
///
/// For non-trivial notation (`2d6+3`) callers should construct a
/// [DiceExpression] and call [rollExpression]; single-die shortcuts are
/// provided for common combat paths (init, death saves).
class Dice {
  final math.Random _rng;

  Dice([math.Random? rng]) : _rng = rng ?? math.Random();

  int d4() => _rng.nextInt(Die.d4.sides) + 1;
  int d6() => _rng.nextInt(Die.d6.sides) + 1;
  int d8() => _rng.nextInt(Die.d8.sides) + 1;
  int d10() => _rng.nextInt(Die.d10.sides) + 1;
  int d12() => _rng.nextInt(Die.d12.sides) + 1;
  int d20() => _rng.nextInt(Die.d20.sides) + 1;
  int d100() => _rng.nextInt(Die.d100.sides) + 1;

  int rollExpression(DiceExpression expr) => expr.roll(_rng);
  int roll(String notation) => DiceExpression.parse(notation).roll(_rng);
}
