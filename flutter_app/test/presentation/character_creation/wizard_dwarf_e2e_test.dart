import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/application/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/wizard/character_creation_wizard_screen.dart';

void main() {
  test(
    'Dwarf Barbarian seed populates resistance_refs + senses via builtin SRD',
    () {
      final entities = buildBuiltinSrdEntities();
      Entity findBySlugName(String slug, String name) =>
          entities.values.firstWhere(
            (e) => e.categorySlug == slug && e.name == name,
            orElse: () =>
                throw StateError('Missing SRD entity $slug/$name'),
          );

      final dwarf = findBySlugName('species', 'Dwarf');
      final barb = findBySlugName('class', 'Barbarian');

      // Sanity: SRD Dwarf must actually carry the resistance ref list.
      final dwarfRes = dwarf.fields['granted_damage_resistances'];
      expect(dwarfRes, isA<List>());
      final dwarfResIds = (dwarfRes as List).whereType<String>().toList();
      expect(dwarfResIds.isNotEmpty, isTrue);
      // Every id should be a non-empty string that resolves to a real entity.
      for (final id in dwarfResIds) {
        expect(id, isNotEmpty,
            reason: 'damage-type lookup placeholder failed to resolve');
        expect(entities[id], isNotNull,
            reason: 'damage-type id $id missing from entity map');
      }

      final build = generateBuiltinDnd5eV2Schema();
      final cat = findPlayerCategory(build.schema);
      expect(cat, isNotNull);

      final draft = CharacterDraft(
        level: 1,
        raceId: dwarf.id,
        classId: barb.id,
      );

      final out = buildSeedFields(
        draft: draft,
        playerCat: cat!,
        race: dwarf,
        characterClass: barb,
        background: null,
        entities: entities,
      );

      expect(out['resistance_refs'], isNotEmpty,
          reason: 'PR-A1 wizard must seed poison resistance onto PC');
      expect(out['senses'], isNotEmpty,
          reason: 'PR-A1 wizard must seed darkvision onto PC');
    },
  );
}
