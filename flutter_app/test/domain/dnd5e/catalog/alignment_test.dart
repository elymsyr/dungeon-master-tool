import 'package:dungeon_master_tool/domain/dnd5e/catalog/alignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Alignment', () {
    test('constructs with axes', () {
      final a = Alignment(
        id: 'srd:lg',
        name: 'Lawful Good',
        lawChaos: LawChaosAxis.lawful,
        goodEvil: GoodEvilAxis.good,
      );
      expect(a.lawChaos, LawChaosAxis.lawful);
      expect(a.goodEvil, GoodEvilAxis.good);
    });

    test('rejects empty name', () {
      expect(
          () => Alignment(
                id: 'srd:x',
                name: '',
                lawChaos: LawChaosAxis.neutral,
                goodEvil: GoodEvilAxis.neutral,
              ),
          throwsArgumentError);
    });

    test('unaligned axis allowed (e.g. oozes)', () {
      final a = Alignment(
        id: 'srd:unaligned',
        name: 'Unaligned',
        lawChaos: LawChaosAxis.unaligned,
        goodEvil: GoodEvilAxis.unaligned,
      );
      expect(a.lawChaos, LawChaosAxis.unaligned);
    });
  });
}
