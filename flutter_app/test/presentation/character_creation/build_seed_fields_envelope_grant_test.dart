import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/application/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/wizard/character_creation_wizard_screen.dart';

/// Blueprint-authored worlds (`assets/worlds/**`) never bake entity ids into
/// their grant cells — a subclass `features` row names its trait/action as a
/// `{_ref: <slug>, name: <name>}` envelope. The absorb path used to accept
/// only bare `String` ids, so every packaged subclass granted nothing.
void main() {
  final playerCat = findPlayerCategory(generateBuiltinDnd5eV2Schema().schema)!;

  Entity mk(String id, String slug, String name,
          [Map<String, dynamic> fields = const {}]) =>
      Entity(id: id, name: name, categorySlug: slug, fields: fields);

  test('subclass feature-row grants authored as {_ref, name} land on the PC',
      () {
    final trait = mk('t1', 'trait', 'Bağıt Yoldaşı');
    final action = mk('a1', 'creature-action', 'Salgı Püskürtmesi');
    final klass = mk('c1', 'class', 'Ranger', const {'hit_die': 'd10'});
    final subclass = mk('s1', 'subclass', 'Pul Bağıtlısı', const {
      'parent_class_ref': {'_ref': 'class', 'name': 'Ranger'},
      'granted_at_level': 3,
      'features': [
        {
          'level': 3,
          'name': 'Bağıt Yoldaşı',
          'granted_trait_refs': [
            {'_ref': 'trait', 'name': 'Bağıt Yoldaşı'}
          ],
        },
        {
          'level': 11,
          'name': 'Salgı Püskürtmesi',
          'granted_action_refs': [
            {'_ref': 'creature-action', 'name': 'Salgı Püskürtmesi'}
          ],
        },
      ],
    });

    final entities = {
      for (final e in [trait, action, klass, subclass]) e.id: e
    };

    final out = buildSeedFields(
      draft: const CharacterDraft(
          level: 11, classId: 'c1', subclassId: 's1'),
      playerCat: playerCat,
      race: null,
      characterClass: klass,
      background: null,
      entities: entities,
    );

    expect(out['trait_refs'], contains('t1'));
    expect(out['action_refs'], contains('a1'));

    // Level gate still holds: an L11 row must not arrive at L3.
    final low = buildSeedFields(
      draft: const CharacterDraft(level: 3, classId: 'c1', subclassId: 's1'),
      playerCat: playerCat,
      race: null,
      characterClass: klass,
      background: null,
      entities: entities,
    );
    expect(low['trait_refs'], contains('t1'));
    expect((low['action_refs'] as List?) ?? const [], isNot(contains('a1')));
  });
}
