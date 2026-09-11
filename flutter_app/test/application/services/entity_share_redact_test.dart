import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/services/entity_share_prepare.dart';

void main() {
  test('redactDmOnly strips dm-only fields and dm_notes from the share body', () {
    final raw = <String, dynamic>{
      'name': 'Fat Farlsbag',
      'type': 'npc',
      'dm_notes': 'XP budget: 6 henchmen at 200 XP each.',
      'attributes': {
        'backstory': 'A hobgoblin warlord.',
        'secrets': 'He will use an elven hostage as a shield.',
        'tactics': 'Two hobgoblins carry crossbows.',
      },
    };

    final out = redactDmOnly(raw, const ['secrets', 'tactics']);

    expect(out['dm_notes'], '');
    expect(out['attributes'], {'backstory': 'A hobgoblin warlord.'});
    expect(out['name'], 'Fat Farlsbag');
    // Kaynak gövde bozulmamalı — DM'in kendi satırı tam kalır.
    expect(raw['dm_notes'], isNotEmpty);
    expect((raw['attributes'] as Map).containsKey('secrets'), isTrue);
  });
}
