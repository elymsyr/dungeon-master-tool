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

    test('drops the CR calculator, converts Faz 4 and 6 types, keeps the rest',
        () {
      // ROADMAP §6, Faz 4 and Faz 6 rows.
      const converted = {
        FieldType.statBlock: FieldType.statTable,
        FieldType.proficiencyTable: FieldType.skillTable,
        FieldType.levelTable: FieldType.table,
        FieldType.levelTextTable: FieldType.table,
        FieldType.rangedSenseList: FieldType.table,
        FieldType.spellEffectList: FieldType.table,
        FieldType.equipmentChoiceGroups: FieldType.markdown,
        FieldType.playerChoices: FieldType.markdown,
        FieldType.subspeciesOptions: FieldType.markdown,
        FieldType.slot: FieldType.resource,
        FieldType.combatStats: FieldType.combatStats,
        FieldType.spellSlotGrid: FieldType.autoResources,
      };
      // Keys the copy renames (the player card's own fields, §16.1).
      const renamed = {'class_levels': 'level', 'spell_slots': 'auto_resources'};
      const flatCombat = {'ac', 'hp_average', 'initiative_modifier'};
      expect(srd.categories, hasLength(builtin.categories.length));
      for (var i = 0; i < builtin.categories.length; i++) {
        final from = builtin.categories[i];
        final to = srd.categories[i];
        expect(to.slug, from.slug);
        expect(to.fieldGroups, from.fieldGroups);
        final flat = {'monster', 'animal'}.contains(from.slug);
        final kept = [
          for (final f in from.fields)
            if (f.fieldType != FieldType.crCalculator &&
                !(flat && flatCombat.contains(f.fieldKey)))
              f,
        ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        // Fields the copy adds: Speed / CR beside a block, a monster's block.
        final added = {
          for (final f in to.fields)
            if (f.fieldId.endsWith('-speed') ||
                f.fieldId.endsWith('-cr') ||
                f.fieldId == '${from.categoryId}-combat')
              f.fieldId,
        };
        final mine = [
          for (final f in to.fields)
            if (!added.contains(f.fieldId)) f,
        ];
        expect(mine.map((f) => f.fieldKey),
            kept.map((f) => renamed[f.fieldKey] ?? f.fieldKey),
            reason: from.slug);
        for (final (j, f) in kept.indexed) {
          final c = mine[j].copyWith(orderIndex: f.orderIndex);
          final target = f.fieldKey == 'class_levels'
              ? FieldType.characterLevel
              : converted[f.fieldType];
          if (target == null) {
            expect(c, f, reason: '${from.slug}.${f.fieldKey}');
          } else {
            expect(c.fieldType, target, reason: '${from.slug}.${f.fieldKey}');
            // A field bound to an SRD preset also takes its label.
            expect(
              c.copyWith(
                fieldType: f.fieldType,
                fieldKey: f.fieldKey,
                styleConfig: null,
                subFields: f.subFields,
                defaultValue: f.defaultValue,
                presetId: null,
                label: f.label,
                gridColumnSpan: f.gridColumnSpan,
              ),
              f,
              reason: '${from.slug}.${f.fieldKey}: only the style changes',
            );
          }
        }
      }
      expect(srd.encounterConfig, builtin.encounterConfig);
    });

    test('skills, saves and ability scores come as bound presets', () {
      final presets = {for (final p in srd.presets!) p.fieldKey: p};
      expect(presets.keys,
          {'skills', 'saving_throws', 'stat_block', 'combat_stats'});
      expect(presets['skills']!.fieldType, FieldType.skillTable);
      expect(presets['stat_block']!.fieldType, FieldType.statTable);
      String? bound(String slug, String key) => srd.categories
          .firstWhere((c) => c.slug == slug)
          .fields
          .firstWhere((f) => f.fieldKey == key)
          .presetId;
      final skills = presets['skills']!.fieldId;
      final saves = presets['saving_throws']!.fieldId;
      // The fields keep their SRD keys, so SRD cards read as they are.
      expect(bound('player-character', 'skills'), skills);
      expect(bound('npc', 'skills'), skills);
      expect(bound('monster', 'skill_bonuses'), skills);
      expect(bound('monster', 'save_bonuses'), saves);
      expect(bound('npc', 'saving_throws'), saves);
      expect(bound('monster', 'stat_block'), presets['stat_block']!.fieldId);
      // Species bonuses have no modifier: not the stat preset.
      expect(bound('feat', 'ability_bonuses'), isNull);
      // Copying a free template keeps its presets.
      final again = copyAsFreeTemplate(srd, id: 'c2', name: 'n', now: _now);
      expect(again.presets, srd.presets);
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

  group('summary chips', () {
    final card = freePlayerCard(srd)!;
    String? name(Object? ref) => {'human': 'Human', 'fighter': 'Fighter'}[ref];
    String? shown(SheetChip c, Map<String, dynamic> fields) =>
        sheetChipValue(card, c, fields, name)?.value;

    test('the SRD copy shows the built-in card\'s; a new template its Level',
        () {
      expect(
        sheetChipsOf(card).map((c) => (c.field, c.sub, c.icon)),
        [
          ('combat_stats', null, 'favorite'),
          ('species_ref', null, 'pets'),
          ('class_refs', null, 'shield_moon_outlined'),
          ('level', null, 'trending_up'),
          ('combat_stats', 'ac', 'security'),
          (ownerChipField, null, 'person_outline'),
        ],
      );
      final empty = emptyFreeTemplate(
        id: 'e',
        name: 'E',
        playerCardName: 'Hero',
        now: _now,
      );
      expect(sheetChipsOf(freePlayerCard(empty)!).map((c) => c.field), [
        'level',
        ownerChipField,
      ]);
      expect(builtin.categories.every((c) => c.summaryChips == null), isTrue);
    });

    test('values: HP of max, a block value, cards by name, the level', () {
      final chips = sheetChipsOf(card);
      final fields = {
        'combat_stats': {'hp': 31, 'max_hp': 38, 'ac': 16},
        'species_ref': 'human',
        'class_refs': ['fighter', 'unknown'],
        'level': 3,
      };
      expect([for (final c in chips.take(5)) shown(c, fields)], [
        '31 / 38',
        'Human',
        'Fighter',
        '3',
        '16',
      ]);
      expect(sheetChipValue(card, chips[4], fields, name)?.label, 'AC');
      // Nothing yet: a dash.
      expect([for (final c in chips.take(5)) shown(c, const {})], [
        '—',
        '—',
        '—',
        '—',
        '—',
      ]);
    });

    test('a chip whose field is gone is dropped; choices list each value', () {
      final noSpecies = card.copyWith(
        fields: [
          for (final f in card.fields)
            if (f.fieldKey != 'species_ref') f,
        ],
      );
      expect(
        sheetChipsOf(noSpecies).map((c) => c.field),
        isNot(contains('species_ref')),
      );
      final labels = sheetChipChoices(card).map((c) => c.label).toList();
      expect(labels, containsAll(['Combat Stats › HP', 'Combat Stats › AC']));
      // Long text and tables are not offered.
      expect(
        sheetChipChoices(card).map((c) => c.chip.field),
        isNot(contains('backstory')),
      );
    });
  });
}
