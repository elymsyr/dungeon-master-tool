import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every tagged SRD card exists, 2–5 lowercase tags, reaches the pack', () {
    final rows = srdRawRowsBySlug();
    var count = 0;
    for (final MapEntry(key: slug, value: cards) in srdTags.entries) {
      final names = {for (final r in rows[slug]!) r['name']};
      for (final MapEntry(key: name, value: tags) in cards.entries) {
        count++;
        expect(names, contains(name), reason: '$slug:$name');
        expect(tags.length, inInclusiveRange(2, 5), reason: '$slug:$name');
        expect(tags.toSet().length, tags.length, reason: '$slug:$name');
        for (final t in tags) {
          expect(t, t.toLowerCase(), reason: '$slug:$name');
        }
      }
    }
    expect(count, greaterThanOrEqualTo(1000));
    final pack = buildSrdCorePack().entities;
    List tagsOf(String slug, String name) =>
        (pack[srdStableEntityId(slug, name)] as Map)['tags'] as List;
    expect(tagsOf('adventuring-gear', 'Robe'), contains('wizard'));
    expect(tagsOf('spell', 'Fireball'), containsAll(['fire', 'evocation']));
    expect(tagsOf('animal', 'Wolf'), containsAll(['beast', 'wild shape']));
  });
}
