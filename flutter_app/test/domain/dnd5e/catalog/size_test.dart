import 'package:dungeon_master_tool/domain/dnd5e/catalog/size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Size', () {
    test('happy path', () {
      final s = Size(
          id: 'srd:medium', name: 'Medium', spaceFt: 5, tokenScale: 1);
      expect(s.spaceFt, 5);
      expect(s.tokenScale, 1);
    });

    test('rejects non-positive spaceFt', () {
      expect(
          () => Size(
              id: 'srd:x', name: 'X', spaceFt: 0, tokenScale: 1),
          throwsArgumentError);
    });

    test('rejects non-positive tokenScale', () {
      expect(
          () => Size(
              id: 'srd:x', name: 'X', spaceFt: 5, tokenScale: 0),
          throwsArgumentError);
    });
  });
}
