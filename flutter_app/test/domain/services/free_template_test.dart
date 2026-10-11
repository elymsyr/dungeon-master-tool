import 'dart:convert';

import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema_hash.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-11T00:00:00.000Z';

void main() {
  final builtin = generateBuiltinDnd5eV2Schema().schema;
  final srd = copyAsFreeTemplate(builtin, id: 'copy-1', name: 'SRD copy', now: _now);

  test('built-in template is not free', () {
    expect(isFreeTemplate(builtin), isFalse);
    expect(builtin.categories.every((c) => c.isPlayerCard == null), isTrue);
  });

  group('SRD copy', () {
    test('is a new free template in the SRD lineage', () {
      expect(srd.schemaId, 'copy-1');
      expect(srd.name, 'SRD copy');
      expect(isFreeTemplate(srd), isTrue);
      expect(isSrdLineage(srd), isTrue);
      expect(srd.freeRootId, builtinDnd5eV2SchemaId);
      expect(srd.createdAt, _now);
      expect(srd.categories.every((c) => c.schemaId == 'copy-1'), isTrue);
      expect(srd.originalHash, computeWorldSchemaContentHash(srd));
    });

    test('marks only player-character as the player card', () {
      final marked = srd.categories.where((c) => c.isPlayerCard != null);
      expect(marked.map((c) => (c.slug, c.isPlayerCard)),
          [('player-character', true)]);
    });

    test('drops the CR calculator and keeps everything else as is', () {
      expect(srd.categories, hasLength(builtin.categories.length));
      for (var i = 0; i < builtin.categories.length; i++) {
        final from = builtin.categories[i];
        final to = srd.categories[i];
        expect(to.slug, from.slug);
        expect(to.fieldGroups, from.fieldGroups);
        expect(to.fields.any((f) => f.fieldType == FieldType.crCalculator),
            isFalse);
        expect(
          to.fields,
          [
            for (final f in from.fields)
              if (f.fieldType != FieldType.crCalculator) f,
          ],
          reason: from.slug,
        );
      }
      expect(srd.encounterConfig, builtin.encounterConfig);
    });

    test('keeps the codex tier the sidebar gives each slug', () {
      final tier = {for (final c in srd.categories) c.slug: c.tier};
      expect(tier['skill'], 0);
      expect(tier['condition'], 2); // DM-authored lookup
      expect(tier['class'], 1);
      expect(tier['npc'], 2);
      expect(srd.categories.every((c) => c.tier == builtinTier(c.slug)),
          isTrue);
    });

    test('survives a JSON round trip', () {
      final back = WorldSchema.fromJson(
          jsonDecode(jsonEncode(srd.toJson())) as Map<String, dynamic>);
      expect(back, srd);
    });
  });

  test('a copy of a free template keeps the lineage root', () {
    final again =
        copyAsFreeTemplate(srd, id: 'copy-2', name: 'Low magic', now: _now);
    expect(again.freeRootId, builtinDnd5eV2SchemaId);
    expect(isSrdLineage(again), isTrue);
    expect(again.categories.where((c) => c.isPlayerCard == true), hasLength(1));
    expect(again.categories.every((c) => c.schemaId == 'copy-2'), isTrue);
  });

  test('an empty template holds only the player card', () {
    final empty = emptyFreeTemplate(
        id: 'e1', name: 'Mine', playerCardName: 'Player', now: _now);
    expect(isFreeTemplate(empty), isTrue);
    expect(isSrdLineage(empty), isFalse);
    expect(empty.freeRootId, 'e1');
    expect(empty.categories, hasLength(1));
    expect(empty.categories.single.isPlayerCard, isTrue);
    expect(empty.categories.single.name, 'Player');
    expect(empty.originalHash, computeWorldSchemaContentHash(empty));

    final child =
        copyAsFreeTemplate(empty, id: 'e2', name: 'Mine 2', now: _now);
    expect(child.freeRootId, 'e1');
  });

  group('template update check (Faz 3)', () {
    // The world holds its own copy of the template (same schemaId).
    final world = srd;
    final noSpell = srd.copyWith(categories: [
      for (final c in srd.categories)
        if (c.slug != 'spell') c,
    ]);

    test('same content: nothing to offer', () {
      expect(pendingTemplateUpdate(world, [srd]), isNull);
    });

    test('changed template is offered', () {
      expect(pendingTemplateUpdate(world, [noSpell]), noSpell);
    });

    test('a new cover or tags alone is not a change', () {
      final dressed = srd.copyWith(metadata: {
        ...srd.metadata,
        'tags': ['homebrew'],
        'cover_image_path': '/covers/a.png',
      });
      expect(pendingTemplateUpdate(world, [dressed]), isNull);
    });

    test('ignored version stays quiet until the next change', () {
      final ignored = freeTemplateContentHash(noSpell);
      expect(
          pendingTemplateUpdate(world, [noSpell], dismissedHash: ignored),
          isNull);
      final noFeat = noSpell.copyWith(categories: [
        for (final c in noSpell.categories)
          if (c.slug != 'feat') c,
      ]);
      expect(
          pendingTemplateUpdate(world, [noFeat], dismissedHash: ignored),
          noFeat);
    });

    test('muted world, deleted template (V2), built-in world: never', () {
      expect(pendingTemplateUpdate(world, [noSpell], muted: true), isNull);
      expect(pendingTemplateUpdate(world, const []), isNull);
      expect(
          pendingTemplateUpdate(
              builtin, [noSpell.copyWith(schemaId: builtin.schemaId)]),
          isNull);
    });
  });

  test('a deleted category hides its cards only in a free world (V5)', () {
    final cards = {
      'a': const Entity(id: 'a', name: 'Fireball', categorySlug: 'spell'),
      'b': const Entity(id: 'b', name: 'Goblin', categorySlug: 'monster'),
    };
    final noSpell = srd.copyWith(categories: [
      for (final c in srd.categories)
        if (c.slug != 'spell') c,
    ]);
    expect(withoutDeletedCategories(cards, noSpell).keys, ['b']);
    expect(withoutDeletedCategories(cards, srd).keys, ['a', 'b']);
    expect(identical(withoutDeletedCategories(cards, builtin), cards), isTrue);
  });
}
