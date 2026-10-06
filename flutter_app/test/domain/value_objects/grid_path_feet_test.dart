import 'package:dungeon_master_tool/domain/value_objects/grid_distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Three diagonal steps, one cell each, on a 50px / 5ft grid.
  const path = [Offset(0, 0), Offset(50, 50), Offset(100, 100), Offset(150, 150)];

  double feet(DiagonalRule rule) =>
      gridPathFeet(path, gridSize: 50, feetPerCell: 5, rule: rule);

  test('5-10-5 counts diagonals across segments', () {
    expect(feet(DiagonalRule.fiveTenFive), 20); // 5 + 10 + 5
    expect(feet(DiagonalRule.fiveFiveFive), 15);
  });

  test('two-point path matches gridDistanceFeet', () {
    for (final rule in DiagonalRule.values) {
      expect(
        gridPathFeet([path.first, const Offset(150, 50)],
            gridSize: 50, feetPerCell: 5, rule: rule),
        gridDistanceFeet(path.first, const Offset(150, 50),
            gridSize: 50, feetPerCell: 5, rule: rule),
      );
    }
  });
}
