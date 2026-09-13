import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/providers/entity_provider.dart'
    show entityFromRaw;
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/builtin_content_names.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:dungeon_master_tool/domain/services/world_blueprint_converter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ships-broken guard for **bundled subclasses**.
///
/// `bundled_worlds_blueprint_test` only proves the refs resolve at convert
/// time. A subclass whose refs are all fine can still arrive on the sheet with
/// nothing on it: the feature rows are narrative only, so every mechanic has to
/// come through a trait/action/cantrip/language ref the resolver actually
/// applies. A prose-only feature converts clean and grants nothing — that is
/// exactly how "Yeminin Ağırlığı" shipped without its STR/CON and skills.
void main() {
  final root = Directory('assets/worlds');
  if (!root.existsSync()) return;

  // Every authoring source under `assets/worlds/`, manifest-listed or not —
  // `aegis/` and `cairn/` ship as importable packages, not bundled worlds, and
  // a subclass that grants nothing breaks the same way in both.
  final dirs = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('world-blueprint.json'))
      .map((f) => f.parent);

  for (final dir in dirs) {
    final slug = dir.path.split(RegExp(r'[\/]')).last;

    test('world "$slug" subclasses resolve at their own level', () {
      final blueprint =
          jsonDecode(
                File('${dir.path}/world-blueprint.json').readAsStringSync(),
              )
              as Map<String, dynamic>;

      final result = WorldBlueprintConverter(
        packageName: slug,
        sourceTitle: slug,
        tier0Slugs: blueprintTier0Slugs(),
        contentSlugs: blueprintContentSlugs(),
        knownNames: builtinContentNames(),
        fieldKeys: blueprintFieldKeys(),
        relationTargets: blueprintRelationTargets(),
        mediaResolver: (rel) =>
            File('${dir.path}/$rel').existsSync() ? rel : null,
      ).convert(worldBlueprint: blueprint);

      final entities = <String, Entity>{
        ...buildBuiltinSrdEntities(),
        for (final e in result.entities.entries)
          e.key: entityFromRaw(e.key, e.value),
      };

      final subclasses = entities.values.where(
        (e) => e.categorySlug == 'subclass',
      );
      if (subclasses.isEmpty) return;

      for (final sub in subclasses) {
        final parentId = resolveEntityRef(
          sub.fields['parent_class_ref'],
          entities,
        );
        expect(parentId, isNotNull, reason: '${sub.name} has no parent class');
        final grantedAt = sub.fields['granted_at_level'] as int? ?? 1;
        // Its own level opens the subclass; L20 exercises every later row.
        for (final level in {grantedAt, 20}) {
          final pc = Character(
            id: 'pc-${sub.id}',
            templateId: 't',
            templateName: 't',
            entity: Entity(
              id: 'pc-${sub.id}',
              categorySlug: 'player-character',
              name: 'probe',
              fields: {
                'class_levels': {parentId!: level},
                'subclass_refs': [sub.id],
                'stat_block': const {
                  'STR': 14,
                  'DEX': 12,
                  'CON': 14,
                  'INT': 10,
                  'WIS': 12,
                  'CHA': 14,
                },
              },
            ),
            createdAt: '',
            updatedAt: '',
          );
          final eff = CharacterResolver.resolve(pc, entities);
          final why = '$slug · ${sub.name} @L$level';

          expect(eff.warnings, isEmpty, reason: why);
          // The subclass must actually open at its own granted level — the
          // level-1 case is the one that silently didn't.
          expect(
            eff.activeFeatures.any((f) => f.sourceEntityId == sub.id),
            isTrue,
            reason: '$why granted no feature',
          );

          // Every ref a live feature row carries has to land somewhere in the
          // resolved sheet; a dropped one is an invisible feature.
          for (final f in (sub.fields['features'] as List? ?? const [])) {
            final row = f as Map<String, dynamic>;
            if ((row['level'] as int? ?? 1) > level) continue;
            final rowWhy = '$why → ${row['name']}';
            for (final id in resolveEntityRefList(
              row['granted_trait_refs'],
              entities,
            )) {
              expect(eff.autoGrantedTraitIds, contains(id), reason: rowWhy);
            }
            for (final id in resolveEntityRefList(
              row['always_prepared_spell_refs'],
              entities,
            )) {
              expect(eff.alwaysPreparedSpellIds, contains(id), reason: rowWhy);
            }
          }
        }
      }
    });
  }
}
