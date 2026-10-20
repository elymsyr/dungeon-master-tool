import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:dungeon_master_tool/domain/services/template_edit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 6 (docs/free-template/ROADMAP.md): Resource, Combat stats, rests,
/// the player card's own fields and the SRD copy converter v3.
const _now = '2026-10-12T00:00:00.000Z';

FieldSchema _field(
  String key,
  FieldType type, {
  Map<String, dynamic>? config,
}) => FieldSchema(
  fieldId: key,
  categoryId: 'c',
  fieldKey: key,
  label: key,
  fieldType: type,
  styleConfig: config,
  createdAt: _now,
  updatedAt: _now,
);

FieldSchema _resource(RestEffect short, RestEffect long) => _field(
  'r',
  FieldType.resource,
  config: ResourceSpec(short: short, long: long).toConfig(),
);

FieldSchema _block(RestEffect short, RestEffect long) => CombatStatsSpec(
  short: short,
  long: long,
).applyTo(_field('combat_stats', FieldType.combatStats));

void main() {
  group('rest (DESIGN §12.3)', () {
    for (final kind in RestKind.values) {
      for (final (effect, want) in [
        (RestEffect.fill, 5),
        (RestEffect.empty, 0),
        (RestEffect.keep, 2),
      ]) {
        const other = RestEffect.keep;
        final (short, long) = kind == RestKind.short
            ? (effect, other)
            : (other, effect);
        test('${kind.name} rest, ${effect.name}: resource and HP', () {
          final fields = [_resource(short, long), _block(short, long)];
          final card = {
            'r': {'current': 2, 'max': 5},
            'combat_stats': {'hp': 2, 'max_hp': 5, 'ac': 14},
            'other': 'x',
          };
          final patch = restPatch(fields, card, kind);
          if (want == 2) {
            expect(patch, isEmpty);
            return;
          }
          expect(patch['r'], {'current': want, 'max': 5});
          // HP changes; the block's other values stay.
          expect(patch['combat_stats'], {'hp': want, 'max_hp': 5, 'ac': 14});
          expect(patch.containsKey('other'), isFalse);
        });
      }
    }

    test('fill without a max leaves the counter', () {
      final f = _resource(RestEffect.fill, RestEffect.fill);
      expect(
        restPatch(
          [f],
          {
            'r': {'current': 1},
          },
          RestKind.long,
        ),
        isEmpty,
      );
    });

    test('HP written back by the encounter as text still rests', () {
      final patch = restPatch(
        [_block(RestEffect.keep, RestEffect.fill)],
        {
          'combat_stats': {'hp': '31', 'max_hp': '38'},
        },
        RestKind.long,
      );
      expect((patch['combat_stats'] as Map)['hp'], 38);
    });
  });

  group('resource', () {
    test('value shape and the SRD slot shape', () {
      expect(resourceValue({'current': 2, 'max': 4}), (current: 2, max: 4));
      expect(
        resourceValue({
          'count': 3,
          'states': [true, false, true],
        }),
        (current: 2, max: 3),
      );
      expect(resourceValue({'count': 3, 'filled': 1}), (current: 1, max: 3));
      expect(resourceValue(null), (current: null, max: null));
      expect(resourceJson((current: 1, max: null)), {'current': 1});
    });

    test('settings round trip; defaults keep / fill, numbers', () {
      final f = _field('r', FieldType.resource);
      final spec = ResourceSpec.of(f);
      expect(spec.boxes, isFalse);
      expect(spec.short, RestEffect.keep);
      expect(spec.long, RestEffect.fill);
      final boxes = const ResourceSpec(
        boxes: true,
        short: RestEffect.empty,
      ).toConfig();
      final back = ResourceSpec.of(f.copyWith(styleConfig: boxes));
      expect(back.boxes, isTrue);
      expect(back.short, RestEffect.empty);
    });
  });

  group('combat stats (DESIGN §8.6, D36)', () {
    test('a value key is never HP\'s or a taken one', () {
      const spec = CombatStatsSpec(
        values: [CombatValue(key: 'ac', label: 'AC')],
      );
      expect(spec.keyFor('HP'), 'hp_2');
      expect(spec.keyFor('Max HP'), 'max_hp_2');
      expect(spec.keyFor('AC'), 'ac_2');
      expect(spec.keyFor('Speed'), 'speed');
    });

    test('settings round trip and the subFields the encounter reads', () {
      const spec = CombatStatsSpec(
        hpLabel: 'Hit points',
        values: [
          CombatValue(key: 'ac', label: 'AC'),
          CombatValue(
            key: 'init',
            label: 'Init',
            type: CombatValueType.dice,
            width: 60,
          ),
          CombatValue(
            key: 'conditions',
            label: 'Conditions',
            type: CombatValueType.cards,
            targets: ['condition'],
            encounter: false,
          ),
        ],
      );
      final f = spec.applyTo(_field('combat_stats', FieldType.combatStats));
      expect(isCombatBlock(f), isTrue);
      final back = CombatStatsSpec.of(f);
      expect(back.toConfig(), spec.toConfig());
      expect(back.hasCards, isTrue);
      expect(f.subFields.map((s) => s['key']), [
        'hp',
        'max_hp',
        'ac',
        'init',
        'conditions',
      ]);
      expect(f.subFields.map((s) => s['type']), [
        'integer',
        'integer',
        'integer',
        'dice',
        'cards',
      ]);
      // The built-in block has no settings: not a free block.
      expect(
        isCombatBlock(_field('combat_stats', FieldType.combatStats)),
        isFalse,
      );
    });

    test('an SRD monster\'s flat fields fill an empty block (§16.3)', () {
      final goblin = {'ac': 12, 'hp_average': 7, 'initiative_modifier': 2};
      expect(combatStatsValue(null, goblin), {
        'hp': 7,
        'max_hp': 7,
        'ac': 12,
        'initiative': '1d20+2',
      });
      expect(
        combatStatsValue(null, {'initiative_modifier': -1})['initiative'],
        '1d20-1',
      );
      // What the block holds wins.
      expect(combatStatsValue({'hp': 3, 'ac': ''}, goblin), {
        'hp': 3,
        'max_hp': 7,
        'ac': 12,
        'initiative': '1d20+2',
      });
    });

    test('Speed and CR read the built-in combat_stats text', () {
      final speed = _field(
        'speed',
        FieldType.integer,
        config: const {srdReadKey: 'speed'},
      );
      final cr = _field(
        'cr',
        FieldType.float_,
        config: const {srdReadKey: 'cr'},
      );
      final card = {
        'combat_stats': {'speed': '30 ft.', 'cr': '1/2'},
      };
      expect(freeFieldValue(speed, card), 30);
      expect(freeFieldValue(cr, card), 0.5);
      expect(freeFieldValue(speed, {...card, 'speed': 25}), 25);
      expect(
        freeFieldValue(speed, {
          'combat_stats': {'speed': 'fast'},
        }),
        isNull,
      );
      // A field without settings reads as stored.
      expect(freeFieldValue(_field('x', FieldType.integer), {'x': 4}), 4);
    });
  });

  group('player card fields (D34, D35)', () {
    final empty = emptyFreeTemplate(
      id: 't',
      name: 'T',
      playerCardName: 'PC',
      now: _now,
    );
    final card = freePlayerCard(empty)!;

    test('a new template has Level and Automatic resources', () {
      expect(card.fields.map((f) => (f.fieldKey, f.fieldType)), [
        ('level', FieldType.characterLevel),
        ('auto_resources', FieldType.autoResources),
      ]);
      expect(canAddFieldType(card, FieldType.characterLevel), isFalse);
    });

    test('deleted, they come back once; any category may take one', () {
      final level = card.fields.first;
      var c = removeField(card, level.fieldId);
      expect(canAddFieldType(c, FieldType.characterLevel), isTrue);
      c = addField(
        c,
        id: 'l2',
        label: 'Level',
        type: FieldType.characterLevel,
        key: playerCardFieldKey(FieldType.characterLevel),
        now: _now,
      );
      expect(c.fields.last.fieldKey, 'level');
      expect(canAddFieldType(c, FieldType.characterLevel), isFalse);
      final npc = card.copyWith(isPlayerCard: null, fields: const []);
      expect(canAddFieldType(npc, FieldType.characterLevel), isTrue);
      expect(paletteFieldTypes, contains(FieldType.characterLevel));
    });

    test('their style is fixed; Combat stats too', () {
      expect(hasFixedStyle(FieldType.characterLevel), isTrue);
      expect(hasFixedStyle(FieldType.combatStats), isTrue);
      expect(switchableFieldTypes, isNot(contains(FieldType.combatStats)));
      expect(switchableFieldTypes, contains(FieldType.resource));
    });

    test('one Combat stats block per category, as a field or a preset', () {
      var c = addField(
        card,
        id: 'cb',
        label: 'Combat',
        type: FieldType.combatStats,
        now: _now,
      );
      expect(isCombatBlock(c.fields.last), isTrue);
      expect(canAddFieldType(c, FieldType.combatStats), isFalse);
      final preset = const CombatStatsSpec().applyTo(
        _field('combat_2', FieldType.combatStats),
      );
      expect(canAddPreset(c, preset), isFalse);
      expect(canAddPreset(card, preset), isTrue);
    });

    test('a new character starts at level 1 (D35)', () {
      final c = addField(
        card,
        id: 'cb',
        label: 'Combat',
        type: FieldType.combatStats,
        now: _now,
      );
      final seed = freeCharacterSeed(c);
      expect(seed, {'level': 1, 'combat': <String, dynamic>{}});
      final hero = Entity(
        id: 'h',
        name: 'Aria',
        categorySlug: 'player-character',
        fields: seed,
      );
      expect(characterLevelOf(c, hero), 1);
      final noLevel = removeField(c, card.fields.first.fieldId);
      expect(characterLevelOf(noLevel, hero), isNull);
    });
  });

  group('SRD copy v3 (ROADMAP §6, Faz 6)', () {
    final srd = copyAsFreeTemplate(
      generateBuiltinDnd5eV2Schema().schema,
      id: 'copy',
      name: 'SRD',
      now: _now,
    );
    EntityCategorySchema cat(String slug) =>
        srd.categories.firstWhere((c) => c.slug == slug);
    FieldSchema? field(String slug, String key) =>
        cat(slug).fields.where((f) => f.fieldKey == key).firstOrNull;

    test('combat_stats → a bound block with the SRD keys', () {
      final preset = srd.presets!.firstWhere(
        (p) => p.fieldType == FieldType.combatStats,
      );
      for (final slug in ['player-character', 'npc', 'monster', 'animal']) {
        final f = field(slug, 'combat_stats')!;
        expect(isCombatBlock(f), isTrue, reason: slug);
        expect(f.presetId, preset.fieldId, reason: slug);
        final spec = CombatStatsSpec.of(f);
        expect(spec.values.map((v) => (v.key, v.type)), [
          ('ac', CombatValueType.number),
          ('initiative', CombatValueType.dice),
          ('xp', CombatValueType.number),
          ('conditions', CombatValueType.cards),
        ]);
        expect(spec.short, RestEffect.keep);
        expect(spec.long, RestEffect.fill);
        expect(spec.values.firstWhere((v) => v.key == 'xp').encounter, isFalse);
      }
    });

    test('Speed (and the NPC\'s CR) leave the block as numbers', () {
      expect(field('player-character', 'speed')!.fieldType, FieldType.integer);
      expect(field('npc', 'speed')!.fieldType, FieldType.integer);
      expect(field('npc', 'cr')!.fieldType, FieldType.float_);
      expect(field('player-character', 'cr'), isNull);
      final npc = cat('npc').fields;
      final block = npc.indexWhere((f) => f.fieldKey == 'combat_stats');
      expect(npc[block + 1].fieldKey, 'speed');
      expect(npc[block + 1].groupId, npc[block].groupId);
    });

    test('a monster\'s flat AC / HP / initiative give way to the block', () {
      for (final key in ['ac', 'hp_average', 'initiative_modifier']) {
        expect(field('monster', key), isNull, reason: key);
      }
      for (final key in ['hp_dice', 'initiative_score', 'ac_note', 'xp']) {
        expect(field('monster', key), isNotNull, reason: key);
      }
      final goblin = {'ac': 12, 'hp_average': 7, 'initiative_modifier': 2};
      final v = freeFieldValue(field('monster', 'combat_stats')!, goblin);
      expect(v, {'hp': 7, 'max_hp': 7, 'ac': 12, 'initiative': '1d20+2'});
    });

    test('the player card: Level and Automatic resources, no class levels '
        'or slot grid', () {
      final pc = cat('player-character');
      expect(
        field('player-character', 'level')!.fieldType,
        FieldType.characterLevel,
      );
      expect(
        field('player-character', 'auto_resources')!.fieldType,
        FieldType.autoResources,
      );
      expect(field('player-character', 'class_levels'), isNull);
      expect(
        pc.fields.where((f) => f.fieldType == FieldType.spellSlotGrid),
        isEmpty,
      );
      expect(canAddFieldType(pc, FieldType.characterLevel), isFalse);
      // Keys stay unique and the order is clean.
      final keys = pc.fields.map((f) => f.fieldKey).toList();
      expect(keys.toSet(), hasLength(keys.length));
      expect(
        pc.fields.map((f) => f.orderIndex),
        List.generate(pc.fields.length, (i) => i),
      );
    });
  });
}
