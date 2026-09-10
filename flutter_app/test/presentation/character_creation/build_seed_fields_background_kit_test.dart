import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/application/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/wizard/character_creation_wizard_screen.dart';

void main() {
  final playerCat = findPlayerCategory(generateBuiltinDnd5eV2Schema().schema)!;

  Entity mk(String id, String slug, String name, [Map<String, dynamic> f = const {}]) =>
      Entity(id: id, name: name, categorySlug: slug, fields: f);

  final tool = mk('tool-callig', 'tool', "Calligrapher's Supplies");
  final book = mk('gear-book', 'adventuring-gear', 'Book');
  final robe = mk('gear-robe', 'adventuring-gear', 'Robe');
  final thieves = mk('tool-thieves', 'tool', "Thieves' Tools");
  final klass = mk('class-rogue', 'class', 'Rogue', {
    'hit_die': 'd8',
    // softRef shape — used to be dropped by a `v is String` filter.
    'granted_tool_refs': [
      {'slug': 'tool', 'name': "Thieves' Tools"},
    ],
  });
  final bg = mk('bg-acolyte', 'background', 'Acolyte', {
    'granted_tool_refs': ['tool-callig'],
    'default_inventory_refs': ['gear-robe'],
    'equipment_choice_groups': [
      {
        'group_id': 'starting_kit',
        'options': [
          {
            'option_id': 'A',
            'items': [
              {'ref': 'gear-book', 'quantity': 1},
            ],
            'gold_gp': 8,
          },
          {'option_id': 'B', 'gold_gp': 50},
        ],
      },
    ],
  });
  final entities = {for (final e in [tool, book, robe, thieves, klass, bg]) e.id: e};

  Map<String, dynamic> build(CharacterDraft draft) => buildSeedFields(
        draft: draft,
        playerCat: playerCat,
        race: null,
        characterClass: klass,
        background: bg,
        entities: entities,
      );

  test('background + class granted tools land on tool_proficiencies', () {
    final out = build(const CharacterDraft(classId: 'class-rogue', backgroundId: 'bg-acolyte'));
    expect(out['tool_proficiencies'], containsAll(['tool-callig', 'tool-thieves']));
  });

  test('default inventory + unpicked group defaults to first option', () {
    final out = build(const CharacterDraft(classId: 'class-rogue', backgroundId: 'bg-acolyte'));
    expect(out['inventory'], containsAll(['gear-robe', 'gear-book']));
    expect(out['equipment_choices'], {'bg-acolyte:starting_kit': 'A'});
  });

  test('explicit pick is respected', () {
    final out = build(const CharacterDraft(
      classId: 'class-rogue',
      backgroundId: 'bg-acolyte',
      equipmentChoices: {'bg-acolyte:starting_kit': 'B'},
    ));
    expect(out['inventory'], ['gear-robe']);
  });
}
