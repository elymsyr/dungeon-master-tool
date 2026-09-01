import 'dart:convert';

import 'package:dungeon_master_tool/application/providers/pinned_entity_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsePinnedEntities survives a settings-blob JSON round trip', () {
    const ids = {'a', 'b'};
    final blob = jsonDecode(jsonEncode({kPinnedEntitiesKey: ids.toList()}));
    expect(parsePinnedEntities(blob[kPinnedEntitiesKey]), ids);
    // Missing / junk values degrade to "nothing pinned", never throw.
    expect(parsePinnedEntities(null), isEmpty);
    expect(parsePinnedEntities([1, 'a']), {'a'});
  });
}
