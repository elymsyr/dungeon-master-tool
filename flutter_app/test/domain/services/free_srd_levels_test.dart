import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart';
import 'package:dungeon_master_tool/domain/services/free_grants.dart';
import 'package:dungeon_master_tool/domain/services/free_srd_levels.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 7b: the SRD copy's level system read from the real SRD 5.2.1 cards
/// (docs/free-template/DESIGN.md §16.3).
void main() {
  final srd = copyAsFreeTemplate(
    generateBuiltinDnd5eV2Schema().schema,
    id: 'copy',
    name: 'SRD copy',
    now: '2026-10-12T00:00:00.000Z',
  );
  final entities = buildBuiltinSrdEntities();
  final player = srd.categories.firstWhere((c) => c.isPlayerCard == true);
  final ctx = GrantContext(
    carrier: player,
    categories: srd.categories,
    entities: entities,
  );

  String id(String slug, String name) => entities.values
      .firstWhere((e) => e.categorySlug == slug && e.name == name)
      .id;
  String nameOf(String id) => entities[id]!.name;
  FieldSchema field(String slug, String key) => srd.categories
      .firstWhere((c) => c.slug == slug)
      .fields
      .firstWhere((f) => f.fieldKey == key);

  /// [fields] after adding [card] to [list] (the sheet's path).
  GrantChange take(Map<String, dynamic> fields, String list, String card) =>
      settleGrants(fields, {
        ...fields,
        list: [...((fields[list] as List?) ?? const []), card],
      }, ctx);

  int? poolMax(GrantResult r, String name) =>
      r.resources.where((x) => x.name == name).firstOrNull?.max;

  group('SRD copy v4', () {
    test('class and subclass features, spells and pools become the level '
        'system; the slot override goes; Class is separate', () {
      expect(field('class', 'features').fieldType, FieldType.progressionTable);
      expect(field('subclass', 'features').fieldType, FieldType.progressionTable);
      expect(
        field('feat', 'granted_spells_at_level').fieldType,
        FieldType.progressionTable,
      );
      expect(field('feat', 'resource_pool_grants').fieldType, FieldType.grantHolder);
      final cls = srd.categories.firstWhere((c) => c.slug == 'class');
      expect(
        cls.fields.any((f) => f.fieldKey == 'spell_slots_by_level'),
        isFalse,
      );
      expect(levelModeOf(cls), LevelMode.separate);
      expect(
        levelModeOf(srd.categories.firstWhere((c) => c.slug == 'subclass')),
        LevelMode.together,
      );
    });

    test('a stored free value wins over the SRD read', () {
      final f = field('class', 'features');
      const own = [
        {'_id': 'r1', 'level': 1, 'text': 'mine'},
      ];
      expect(freeFieldValue(f, {'features': own}, byId: entities), own);
      expect(isSrdLevelShape(null), isTrue);
      expect(isSrdLevelShape(own), isFalse);
    });
  });

  group('Fighter (Aria, DESIGN §11.9)', () {
    final fighter = id('class', 'Fighter');

    test('taking Fighter at level 1 grants its level 1 cards', () {
      final c = take({'level': 1}, 'class_refs', fighter);
      final added = {for (final g in c.added) nameOf(g.cardId): g.listKey};
      expect(added['Second Wind'], isNotNull);
      expect(added['Weapon Mastery'], isNotNull);
      expect(added, isNot(contains('Action Surge')));
      expect(
        c.fields['bonus_action_refs'],
        contains(id('creature-action', 'Second Wind')),
      );
      expect(c.fields['feats'], contains(id('feat', 'Second Wind')));
      // Second Wind's uses follow the Fighter rows: 2 at level 1.
      expect(poolMax(c.after, 'Second Wind'), 2);
      expect(
        summarize(c).reads.map((r) => r.text),
        contains(startsWith('**Fighting Style.**')),
      );
    });

    test('level 2 adds Action Surge; a Wizard joins at 1 with its slots', () {
      final l1 = take({'level': 1}, 'class_refs', fighter).fields;
      final up = levelUp(l1, ctx, picked: {'class': fighter});
      final l2 = settleGrants(l1, up, ctx);
      expect(l2.added.map((g) => nameOf(g.cardId)), contains('Action Surge'));
      expect(poolMax(l2.after, 'Action Surge'), 1);

      final wizard = id('class', 'Wizard');
      final up3 = levelUp(l2.fields, ctx, added: {'class': wizard});
      final l3 = settleGrants(l2.fields, up3, ctx);
      expect(cardLevelsOf(l3.fields)[wizard], 1);
      expect(poolMax(l3.after, 'Level 1 Slots'), 2);
      expect(poolMax(l3.after, 'Level 2 Slots'), isNull);
      // Arcane Recovery: the granted feat's own fixed pool.
      expect(poolMax(l3.after, 'Arcane Recovery'), 1);
      // The Fighter stays at 2: Indomitable (Fighter 9) is not reached.
      expect(poolMax(l3.after, 'Indomitable'), isNull);
    });

    test('Champion added at level 4 reads rows 1–4 (together)', () {
      final c = take({'level': 4}, 'subclass_refs', id('subclass', 'Champion'));
      expect(c.after.reached[id('subclass', 'Champion')], 4);
      expect(
        c.added.map((g) => nameOf(g.cardId)),
        contains(startsWith('Improved Critical')),
      );
    });
  });

  group('pools (D39)', () {
    Map<String, dynamic> classAt(String cls, int level) => {
      'level': level,
      'class_refs': [id('class', cls)],
      cardLevelsKey: {id('class', cls): level},
    };

    test('Barbarian 8: Rage from the class rows, the same name replaced', () {
      final r = computeGrants(classAt('Barbarian', 8), ctx);
      expect(poolMax(r, 'Rage'), 4);
      final rage = r.resources.firstWhere((x) => x.name == 'Rage');
      expect(rage.fromId, id('class', 'Barbarian'));
      expect(rage.short, RestEffect.keep);
      expect(rage.long, RestEffect.fill);
      // Unlimited at 20 cannot be boxes: the last count stays.
      expect(poolMax(computeGrants(classAt('Barbarian', 20), ctx), 'Rage'), 6);
    });

    test('level formulas follow the class level', () {
      expect(poolMax(computeGrants(classAt('Monk', 5), ctx), 'Focus Points'), 5);
      expect(
        poolMax(
          computeGrants(classAt('Paladin', 3), ctx),
          'Lay on Hands (HP Pool)',
        ),
        15,
      );
    });

    test('a stat formula leaves the max empty, with a text saying how', () {
      // The feat's own Grants count once it is in the Feats list.
      final r = settleGrants(const {}, classAt('Bard', 1), ctx).after;
      final bi = r.resources.firstWhere((x) => x.name == 'Bardic Inspiration');
      expect(bi.max, isNull);
      expect(
        r.entries.map((e) => '${e.item.value}'),
        contains('Max = CHA modifier (min. 1)'),
      );
    });

    test('slots: half casters from the override, a Warlock\'s pact slots', () {
      expect(
        poolMax(computeGrants(classAt('Paladin', 1), ctx), 'Level 1 Slots'),
        2,
      );
      final warlock = computeGrants(classAt('Warlock', 2), ctx);
      final pact = warlock.resources.firstWhere((x) => x.name == 'Pact Slots');
      expect(pact.max, 2);
      expect(pact.short, RestEffect.fill);
      expect(
        poolMax(computeGrants(classAt('Wizard', 5), ctx), 'Level 3 Slots'),
        2,
      );
    });

    test('Drow as Subspecies: Faerie Fire at 3, once a day (V24)', () {
      expect(field('player-character', 'subspecies_ref').isList, isFalse);
      final faerie = id('spell', 'Faerie Fire');
      final at1 = settleGrants(const {}, {
        'level': 1,
        'subspecies_ref': id('subspecies', 'Drow'),
      }, ctx);
      List<String> spells(GrantChange c) =>
          listedIds(c.fields['spells_known'], entities);
      expect(spells(at1), isNot(contains(faerie)));
      final at3 = settleGrants(at1.fields, {...at1.fields, 'level': 3}, ctx);
      expect(spells(at3), contains(faerie));
      expect(poolMax(at3.after, 'Faerie Fire'), 1);
      expect(poolMax(at3.after, 'Darkness'), isNull);

      // Drow → High Elf: Faerie Fire is offered for removal, its uses go.
      final high = settleGrants(at3.fields, {
        ...at3.fields,
        'subspecies_ref': id('subspecies', 'High Elf'),
      }, ctx);
      expect(high.stale, [faerie]);
      expect(poolMax(high.after, 'Faerie Fire'), isNull);
    });

    test('Lucky: proficiency-bonus uses follow the main level', () {
      final lucky = id('feat', 'Lucky');
      final r = computeGrants({
        'level': 5,
        'feats': [lucky],
      }, ctx);
      expect(poolMax(r, 'Luck Points'), 3);
    });
  });
}
