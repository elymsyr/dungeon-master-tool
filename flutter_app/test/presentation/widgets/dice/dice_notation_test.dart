import 'package:dungeon_master_tool/presentation/widgets/dice/dice_fab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseDiceNotation', () {
    final a = parseDiceNotation('2d6+3')!;
    expect(a.counts, {'d6': 2});
    expect(a.modifier, 3);
    final b = parseDiceNotation(' 1d8 + d6 - 1 ')!;
    expect(b.counts, {'d8': 1, 'd6': 1});
    expect(b.modifier, -1);
    expect(parseDiceNotation('D20')!.counts, {'d20': 1});
    for (final bad in ['', '+5', '1d3', '2d6-1d4', 'abc', '2d', '100d6']) {
      expect(parseDiceNotation(bad), isNull, reason: bad);
    }
  });
}
