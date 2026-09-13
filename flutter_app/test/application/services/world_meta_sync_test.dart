import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/services/world_meta_sync.dart';

void main() {
  group('decodeWorldMeta', () {
    test('whitelists the card keys and drops everything else', () {
      final meta = decodeWorldMeta(jsonEncode({
        'description': 'A drowned city',
        'tags': ['horror'],
        'cover_image_path': 'dmt-public://u1/abc.png',
        'combat_state': {'secret': true},
      }));
      expect(meta, {
        'description': 'A drowned city',
        'tags': ['horror'],
        'cover_image_path': 'dmt-public://u1/abc.png',
      });
    });

    test('accepts an already-decoded map', () {
      expect(decodeWorldMeta({'description': 'x'}), {'description': 'x'});
    });

    test('null on empty, malformed or irrelevant payloads', () {
      expect(decodeWorldMeta(null), isNull);
      expect(decodeWorldMeta(''), isNull);
      expect(decodeWorldMeta('{not json'), isNull);
      expect(decodeWorldMeta(jsonEncode({'combat_state': 1})), isNull);
    });
  });
}
