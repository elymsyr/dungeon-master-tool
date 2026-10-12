import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-11T00:00:00.000Z';

void main() {
  final srd = copyAsFreeTemplate(
    generateBuiltinDnd5eV2Schema().schema,
    id: 'copy-1',
    name: 'SRD copy',
    now: _now,
  );
  EntityCategorySchema cat(String slug) =>
      srd.categories.firstWhere((c) => c.slug == slug);
  FieldSchema field(String slug, String key) =>
      cat(slug).fields.firstWhere((f) => f.fieldKey == key);
  Map<String, dynamic> srdCard(String slug, String name) =>
      (srdRawRowsBySlug()[slug]!.firstWhere((r) => r['name'] == name)
              as Map)['attributes']
          as Map<String, dynamic>;

  group('stat modifier (DESIGN §8.2)', () {
    const values = [7, 8, 9, 10, 11, 12, 15, 20];
    test('D&D: base 10, step 2, rounded down', () {
      expect(
        [for (final v in values) statModifier(v)],
        [
          -2, -1, -1, 0, 0, 1, 2, 5, //
        ],
      );
    });
    test('another system: base 0, step 3', () {
      expect(
        [for (final v in values) statModifier(v, base: 0, step: 3)],
        [
          2, 2, 3, 3, 3, 4, 5, 6, //
        ],
      );
    });
    test('a step below 1 reads as 1', () {
      expect(statModifier(12, step: 0), 2);
    });
  });

  group('table rows', () {
    const spec = TableSpec(
      fixedRows: true,
      columns: [
        TableColumn(key: 'name', label: 'Skill', locked: true),
        TableColumn(key: 'ability', label: 'Ability'),
        TableColumn(key: 'proficient', label: 'P', type: TableColumnType.check),
      ],
      rows: [
        {'_id': 'a', 'name': 'Athletics', 'ability': 'STR'},
        {'_id': 's', 'name': 'Stealth', 'ability': 'DEX'},
      ],
    );

    test('fixed rows: the template rows, overlaid by id or locked cells', () {
      final rows = tableRows(spec, {
        'rows': [
          // SRD shape: no id, matched by its locked name.
          {'name': 'Stealth', 'ability': 'DEX', 'proficient': true},
        ],
      });
      expect(rows, [
        {'_id': 'a', 'name': 'Athletics', 'ability': 'STR'},
        {'_id': 's', 'name': 'Stealth', 'ability': 'DEX', 'proficient': true},
      ]);
      // A card cannot change a locked cell.
      expect(
        tableRows(spec, [
          {'_id': 'a', 'name': 'Hacked', 'ability': 'DEX'},
        ]).first,
        {'_id': 'a', 'name': 'Athletics', 'ability': 'DEX'},
      );
    });

    test('an SRD row renamed in the template finds its data by id', () {
      final renamed = spec.copyWith(
        rows: [
          {'_id': 'Stealth', 'name': 'Sneaking', 'ability': 'DEX'},
        ],
      );
      final rows = tableRows(renamed, {
        'rows': [
          {'name': 'Stealth', 'proficient': true},
        ],
      });
      expect(rows.single['name'], 'Sneaking');
      expect(rows.single['proficient'], isTrue);
    });

    test('a fixed row stores only what differs from the template', () {
      final rows = tableRows(spec, null);
      rows[0] = {...rows[0], 'ability': 'DEX', 'proficient': false};
      rows[1] = {...rows[1], 'proficient': true};
      expect(tableValue(spec, rows), [
        {'_id': 'a', 'ability': 'DEX'},
        {'_id': 's', 'proficient': true},
      ]);
    });

    test('values of a template row that is gone stay in the card', () {
      final shorter = spec.copyWith(rows: [spec.rows.first]);
      final previous = [
        {'_id': 's', 'proficient': true},
      ];
      final rows = tableRows(shorter, previous);
      expect(rows, hasLength(1));
      expect(tableValue(shorter, rows, previous: previous), previous);
      // …and come back with the row.
      expect(tableRows(spec, previous)[1]['proficient'], isTrue);
    });

    test('free rows read the SRD list and level-table shapes', () {
      const free = TableSpec();
      expect(
        tableRows(free, [
          {'sense_ref': 'x', 'range_ft': 60},
        ]),
        [
          {'sense_ref': 'x', 'range_ft': 60},
        ],
      );
      expect(tableRows(free, {'5': 3, '1': 2, '11': 4}), [
        {'level': 1, 'value': 2},
        {'level': 5, 'value': 3},
        {'level': 11, 'value': 4},
      ]);
      expect(
        tableValue(free, [
          {'level': 1},
        ]),
        [
          {'level': 1},
        ],
      );
      expect(tableRows(free, null), isEmpty);
    });

    test('row ids skip the ones in use', () {
      expect(nextTableRowId(const []), 'r1');
      expect(
        nextTableRowId(const [
          {'_id': 'r2'},
        ]),
        'r3',
      );
      expect(
        nextTableRowId(const [
          {'_id': 'r2'},
          {'_id': 'r3'},
        ]),
        'r4',
      );
    });
  });

  group('SRD copy reads SRD data (DESIGN §16.3)', () {
    test('Goblin Warrior: stats, skill totals, senses', () {
      final goblin = srdCard('monster', 'Goblin Warrior');
      final monster = cat('monster');

      final stats = StatTableSpec.of(field('monster', 'stat_block'));
      expect(stats.showModifier, isTrue);
      final scores = goblin['stat_block'] as Map;
      expect(
        [for (final s in stats.stats) stats.modifier(scores[s.key])],
        [
          -1, 2, 0, 0, -1, -1, //
        ],
      );

      final skills = SkillTableSpec.of(field('monster', 'skill_bonuses'));
      final rows = tableRows(skills.table, goblin['skill_bonuses']);
      expect(rows, hasLength(18));
      int totalOf(String name) => skillTotal(
        skills,
        rows.firstWhere((r) => r['name'] == name),
        card: goblin,
        fields: monster.fields,
      );
      expect(totalOf('Stealth'), 6); // DEX +2, proficient + expertise × PB 2
      expect(totalOf('Athletics'), -1); // STR 8, not proficient
      expect(totalOf('Perception'), -1);

      final senses = TableSpec.of(field('monster', 'senses'));
      final sense = tableRows(senses, goblin['senses']).single;
      expect(sense['range_ft'], 60);
      expect((sense['sense_ref'] as Map)['name'], 'Darkvision');
    });

    test('a row may pick another stat; a missing score adds 0', () {
      final skills = SkillTableSpec.of(field('monster', 'skill_bonuses'));
      final row = tableRows(skills.table, null).first; // Acrobatics, DEX
      final card = {
        'stat_block': {'STR': 16},
        'proficiency_bonus': 3,
      };
      int total(Map<String, dynamic> r) =>
          skillTotal(skills, r, card: card, fields: cat('monster').fields);
      expect(total(row), 0);
      expect(total({...row, 'ability': null, 'proficient': true}), 3);
      expect(
        total({...row, 'ability': 'STR', 'proficient': true, 'misc': 1}),
        3 + 3 + 1,
      );
      // Expertise adds the bonus once more; the stat table's own base and
      // step make the modifier.
      final other = [
        field('monster', 'stat_block').copyWith(
          styleConfig: const StatTableSpec(
            stats: [(key: 'STR', label: 'STR')],
            base: 0,
            step: 3,
          ).toConfig(),
        ),
      ];
      expect(
        skillTotal(
          skills,
          {...row, 'ability': 'STR', 'proficient': true, 'expertise': true},
          card: card,
          fields: other,
        ),
        5 + 3 + 3,
      );
      // The card stores only what it changed.
      expect(
        tableValue(skills.table, [
          {...row, 'ability': 'STR'},
        ]),
        [
          {'_id': 'Acrobatics', 'ability': 'STR'},
        ],
      );
    });

    test('the player card reads its stat table and proficiency bonus', () {
      final saves = SkillTableSpec.of(
        field('player-character', 'saving_throws'),
      );
      expect(saves.bonus, 'proficiency_bonus');
      expect(saves.stat, 'stat_block');
      expect(skillBonus(saves, const {'proficiency_bonus': 4}), 4);
      expect(skillBonus(saves, const {}), 0);
      expect(
        [for (final r in saves.rows) r['ability']],
        [
          'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA', //
        ],
      );
    });

    test('species / feat ability bonuses keep values only', () {
      final bonus = StatTableSpec.of(field('feat', 'ability_bonuses'));
      expect(bonus.showModifier, isFalse);
      expect(bonus.stats.map((s) => s.key), [
        'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA', //
      ]);
    });

    test('class level tables and spell upcasting read as rows', () {
      final bard = srdCard('class', 'Bard');
      final cantrips = TableSpec.of(field('class', 'cantrips_known_by_level'));
      final rows = tableRows(cantrips, bard['cantrips_known_by_level']);
      expect(rows.first, {'level': 1, 'value': 2});
      expect(rows, hasLength(20));

      final fireball = srdCard('spell', 'Fireball');
      final upcast = TableSpec.of(field('spell', 'at_higher_levels_text'));
      final row = tableRows(upcast, fireball['at_higher_levels_text']).single;
      expect(row['level'], 4);
      expect(row['value'], contains('1d6'));
    });

    test('Fighter starting equipment reads as markdown', () {
      final fighter = srdCard('class', 'Fighter');
      final md = structuredListAsMarkdown(
        fighter['equipment_choice_groups'] as List,
        (r) => '$r',
      );
      expect(md, startsWith('**Starting Equipment** — Choose one\n- **A:** '));
      expect(md, contains('- **B:** Studded Leather'));
    });

    test('player choices and unlabelled options read as markdown', () {
      expect(
        structuredListAsMarkdown([
          {
            'label': 'Spell List',
            'prompt': 'Choose one.',
            'options': [
              {'id': 'Cleric', 'label': 'Cleric'},
            ],
          },
          {
            'options': [
              {
                'option_id': 'A',
                'items': [
                  {'ref': 'h', 'quantity': 4},
                  {'ref': 'p', 'quantity': 1},
                ],
                'gold_gp': 15,
              },
            ],
          },
          {'name': 'Drow', 'description': 'Darkvision 120 ft.'},
        ], (r) => r == 'h' ? 'Handaxe' : 'Pack'),
        '**Spell List** — Choose one.\n- Cleric\n\n'
        '- **A:** 4× Handaxe, Pack, 15 GP\n\n'
        '**Drow**\n\nDarkvision 120 ft.',
      );
    });
  });
}
