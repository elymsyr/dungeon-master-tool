import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/providers/entity_provider.dart'
    show entityFromRaw;
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/builtin_content_names.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:dungeon_master_tool/domain/services/world_blueprint_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diag', () {
    const dir = 'assets/worlds/99_devils_of_uzrahs_palace_shadowdark';
    final meta = jsonDecode(File('$dir/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    Map<String, dynamic>? read(String n) {
      final f = File('$dir/$n');
      return f.existsSync()
          ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
          : null;
    }

    final r = WorldBlueprintConverter(
      packageName: meta['slug'] as String,
      sourceTitle: 'x',
      tier0Slugs: blueprintTier0Slugs(),
      contentSlugs: blueprintContentSlugs(),
      knownNames: builtinContentNames(),
      fieldKeys: blueprintFieldKeys(),
      relationTargets: blueprintRelationTargets(),
      mediaResolver: (rel) => File('$dir/$rel').existsSync() ? rel : null,
    ).convert(
      worldBlueprint: read('world-blueprint.json'),
      characterBlueprint: read('blueprint.json'),
    );
    final entities = <String, Entity>{
      ...buildBuiltinSrdEntities(),
      for (final e in r.entities.entries) e.key: entityFromRaw(e.key, e.value),
    };
    for (var j in r.characters) {
      final seeded = Map<String, dynamic>.from(j);
      final sb = seeded['fields'] is Map ? (seeded['fields'] as Map)['stat_block'] : null;
      if (sb is Map) {
        (seeded['fields'] as Map)['base_abilities'] = Map<String, dynamic>.from(sb);
      }
      j = seeded;
      final pc = Character(
        id: j['id'] as String,
        templateId: 't',
        templateName: 't',
        entity: Entity.fromJson(j),
        createdAt: '',
        updatedAt: '',
      );
      final e = CharacterResolver.resolve(pc, entities);
      final f = pc.entity.fields;
      print('── ${j['name']}');
      print('   class_levels(raw)=${f['class_levels']}');
      print('   classLevels=${e.classLevels.map((k, v) => MapEntry(entities[k]?.name ?? k, v))}');
      print('   species_ref=${f['species_ref']} background_ref=${f['background_ref']}');
      print('   features=${e.activeFeatures.length} feats=${e.featIds.length} '
          'traits=${(f['trait_refs'] as List?)?.length} inv=${e.inventory.length}');
      print('   abilities=${e.effectiveAbilities} stat_block=${f['stat_block']}');
      print('   AC=${e.armorClass} combat=${f['combat_stats']}');
      print('   prof skills=${e.proficiencies.skillIds.length}');
      print('   warnings=${e.warnings}');
    }
  });
}
