import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/application/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/wizard/character_creation_wizard_screen.dart';

EntityCategorySchema _loadPlayerCat() {
  final build = generateBuiltinDnd5eV2Schema();
  final cat = findPlayerCategory(build.schema);
  if (cat == null) {
    throw StateError('builtin v2 template must expose a Player category');
  }
  return cat;
}

Entity _mk({
  required String id,
  required String slug,
  String name = 'X',
  Map<String, dynamic> fields = const {},
}) =>
    Entity(id: id, name: name, categorySlug: slug, fields: fields);

void main() {
  final playerCat = _loadPlayerCat();

  // A level-1 subclass (Aegis "İrade Yemini") picked in the wizard has to land
  // on the schema's own `subclass_refs` relation, not only on the resolver-side
  // `subclass_id`: `subclass_refs` defaults to `[]`, and the sheet + level-up
  // planner read it first, so leaving it empty hid the subclass and re-asked
  // for one at L3.
  test('wizard writes the picked subclass onto subclass_refs', () {
    final klass = _mk(
      id: 'class-paladin',
      slug: 'class',
      name: 'Paladin',
      fields: const {'hit_die': 'd10'},
    );
    final subclass = _mk(
      id: 'subclass-oath',
      slug: 'subclass',
      name: 'Oath',
      fields: const {
        'granted_at_level': 1,
        'parent_class_ref': 'class-paladin',
      },
    );
    const draft = CharacterDraft(
      level: 1,
      classId: 'class-paladin',
      subclassId: 'subclass-oath',
    );

    final out = buildSeedFields(
      draft: draft,
      playerCat: playerCat,
      race: null,
      characterClass: klass,
      background: null,
      entities: {klass.id: klass, subclass.id: subclass},
    );

    expect(out['subclass_refs'], const ['subclass-oath']);
    expect(out['subclass_id'], 'subclass-oath');
  });
}
