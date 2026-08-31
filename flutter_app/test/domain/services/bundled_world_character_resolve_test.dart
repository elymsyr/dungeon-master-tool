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

/// Ships-broken guard for the *character* half of a bundled world.
///
/// `bundled_worlds_blueprint_test` only proves the blueprint converts. That is
/// not enough: a PC whose refs all resolve can still land on the sheet with no
/// class, no species and no background, because [CharacterResolver] reads the
/// wizard's id-keyed choice fields (`class_levels` keyed by class **id**,
/// `race_id`, `background_id`) and a blueprint can only author the schema's
/// relation fields. That mismatch showed up as `Missing class entity Fighter`.
void main() {
  final root = Directory('assets/worlds');
  final manifest = File('${root.path}/manifest.json');
  if (!manifest.existsSync()) return;

  final worlds = (jsonDecode(manifest.readAsStringSync())
      as Map<String, dynamic>)['worlds'] as List;

  for (final w in worlds.cast<Map<String, dynamic>>()) {
    final dir = '${root.path}/${w['dir']}';

    test('bundled world "${w['title']}" PCs resolve against the SRD', () {
      final meta = jsonDecode(File('$dir/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

      Map<String, dynamic>? read(String name) {
        final f = File('$dir/$name');
        return f.existsSync()
            ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
            : null;
      }

      final result = WorldBlueprintConverter(
        packageName: meta['slug'] as String,
        sourceTitle: '${meta['title']}, ${meta['system']}',
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
      if (result.characters.isEmpty) return;

      // What an installed world actually hands the resolver: the built-in
      // SRD pack (installer writes the built-in template, so it is always
      // linked) plus this world's own entities.
      final entities = <String, Entity>{
        ...buildBuiltinSrdEntities(),
        for (final e in result.entities.entries) e.key: entityFromRaw(e.key, e.value),
      };

      for (final json in result.characters) {
        final name = json['name'];
        final pc = Character(
          id: json['id'] as String,
          templateId: 't',
          templateName: 't',
          entity: Entity.fromJson(json),
          createdAt: '',
          updatedAt: '',
        );
        final eff = CharacterResolver.resolve(pc, entities);

        expect(eff.warnings, isEmpty, reason: '$name');
        // Class levels must be keyed by a real class entity, or nothing the
        // class grants (features, proficiencies, hit die) ever applies.
        expect(eff.classLevels, isNotEmpty, reason: '$name has no class level');
        for (final id in eff.classLevels.keys) {
          expect(entities[id]?.categorySlug, 'class', reason: '$name → $id');
        }
      }
    });
  }
}
