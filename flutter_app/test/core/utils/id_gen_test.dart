import 'package:dungeon_master_tool/core/utils/id_gen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('newId', () {
    test('produces a v4 UUID string', () {
      final id = newId();
      // UUID v4 canonical form: 8-4-4-4-12 hex with version nibble = 4.
      expect(id, hasLength(36));
      expect(id[14], '4');
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue,
      );
    });

    test('generates unique ids across calls', () {
      final ids = List.generate(64, (_) => newId()).toSet();
      expect(ids.length, 64);
    });
  });
}
