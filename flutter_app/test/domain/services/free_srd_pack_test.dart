import 'package:collection/collection.dart';
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/application/services/package_import_service.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:dungeon_master_tool/domain/services/free_encounter.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart';
import 'package:dungeon_master_tool/domain/services/free_grants.dart';
import 'package:dungeon_master_tool/domain/services/free_srd_levels.dart' show srdFeatureTargets;
import 'package:dungeon_master_tool/domain/services/free_srd_pack.dart';
import 'package:dungeon_master_tool/domain/services/free_srd_texts.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// The free SRD package's converter, on the real SRD 5.2.1 cards
/// (docs/free-template/SRD-FREE-ALANLAR.md §8, §11).
void main() {
  final build = generateBuiltinDnd5eV2Schema();
  // The pack as the package rows hold it: `_lookup` placeholders unresolved.
  final raw = <String, Entity>{
    for (final MapEntry(key: slug, value: rows) in build.seedRows.entries)
      for (final r in rows)
        if (r['name'] case final String name when name.isNotEmpty)
          srdStableEntityId(slug, name): Entity(
            id: srdStableEntityId(slug, name),
            name: name,
            categorySlug: slug,
            description: (r['description'] as String?) ?? '',
            fields: Map<String, dynamic>.from(
              (r['fields'] as Map?) ?? const {},
            ),
          ),
    for (final MapEntry(:key, :value) in buildSrdCorePack().entities.entries)
      key: Entity(
        id: key,
        name: (value as Map)['name'] as String,
        categorySlug: value['type'] as String,
        description: (value['description'] as String?) ?? '',
        fields: Map<String, dynamic>.from(
          (value['attributes'] as Map?) ?? const {},
        ),
      ),
  };
  // The same cards as a world reads them (placeholders resolved).
  final world = buildBuiltinSrdEntities();
  final tier0 = <String, Map<String, String>>{
    for (final MapEntry(key: slug, value: rows) in build.seedRows.entries)
      slug: {
        for (final r in rows)
          if (r['name'] case final String name when name.isNotEmpty)
            name: srdStableEntityId(slug, name),
      },
  };
  final converted = {
    for (final c in raw.values)
      if (inFreeSrd(c.categorySlug)) c.id: freeSrdFields(c, raw),
  };
  // A card's fields as a world holds them: synthesis resolves every row's
  // placeholders (`buildBuiltinSrdEntities` leaves the Tier-0 rows' own).
  Map<String, dynamic> resolved(Map<String, dynamic> fields) =>
      PackageImportService.resolveLookupPlaceholder(fields, tier0)
          as Map<String, dynamic>;
  Map<String, dynamic> stored(String id) => resolved(converted[id]!);
  final cats = {for (final c in srdFreeTemplate.categories) c.slug: c};
  final builtin = {for (final c in build.schema.categories) c.slug: c};
  String id(String slug, String name) => raw.values
      .firstWhere((e) => e.categorySlug == slug && e.name == name)
      .id;

  const eq = DeepCollectionEquality();
  bool blank(Object? v) =>
      v == null ||
      v == '' ||
      v == false ||
      (v is List && v.isEmpty) ||
      (v is Map && v.isEmpty);
  bool same(Object? a, Object? b) => (blank(a) && blank(b)) || eq.equals(a, b);

  /// What a free card shows for [f]: the read, and a list the way the
  /// markdown field shows it.
  Object? shown(FieldSchema f, Map<String, dynamic> fields) {
    final v = freeFieldValue(f, fields, byId: world);
    return f.fieldType == FieldType.markdown && v is List
        ? structuredListAsMarkdown(v, (r) => entityRefName(r, world))
        : v;
  }

  group('A1', () {
    test('the stored free data shows what the SRD read showed', () {
      final diffs = <String>[];
      for (final c in raw.values) {
        final cat = cats[c.categorySlug];
        if (cat == null) continue;
        final s = stored(c.id);
        final today = resolved(world[c.id]!.fields);
        final ids = {for (final f in builtin[cat.slug]!.fields) f.fieldId};
        for (final f in cat.fields) {
          // A closed category's new lines (A2+) were never read from the SRD.
          if (freeSrdClosed.contains(cat.slug) && !ids.contains(f.fieldId)) {
            continue;
          }
          // The Armor table's don / doff times (A7) were in no card.
          if (cat.slug == 'armor-category' && f.fieldKey == 'effects') continue;
          if (!same(shown(f, s), shown(f, today))) {
            diffs.add('${c.categorySlug} / ${c.name} / ${f.fieldKey}');
          }
        }
      }
      expect(diffs, isEmpty);
    });

    test('the stored data needs no read: a field shows what it holds', () {
      final diffs = <String>[];
      for (final c in raw.values) {
        final cat = cats[c.categorySlug];
        if (cat == null) continue;
        final s = stored(c.id);
        for (final f in cat.fields) {
          if (!same(shown(f, s), s[f.fieldKey])) {
            diffs.add('${c.categorySlug} / ${c.name} / ${f.fieldKey}');
          }
        }
      }
      expect(diffs, isEmpty);
    });

    test('class rows, a pool and a monster block, written as free values', () {
      final fighter = converted[id('class', 'Fighter')]!;
      expect((fighter['features'] as List).first, containsPair('_id', 'srd0'));
      final pools = converted[id('feat', 'Wild Shape')]!['resource_pool_grants'];
      expect((pools as List).first, containsPair('kind', 'resource'));
      final goblin = converted[id('monster', 'Goblin Warrior')]!;
      expect(goblin['combat_stats'], {
        'xp': 50,
        'hp': 7,
        'max_hp': 7,
        'ac': 12,
        'initiative': '1d20+2',
      });
      final acolyte = converted[id('background', 'Acolyte')]!;
      expect(acolyte['equipment_choice_groups'], isA<String>());
    });
  });

  group('guard (G7)', () {
    test('every filled field is declared in the copy', () {
      final found = <String, Set<String>>{};
      for (final c in raw.values.where((c) => converted.containsKey(c.id))) {
        final cat = cats[c.categorySlug];
        expect(cat, isNotNull, reason: c.categorySlug);
        final keys = {for (final f in cat!.fields) f.fieldKey};
        converted[c.id]!.forEach((k, v) {
          if (!blank(v) && !keys.contains(k)) {
            (found[c.categorySlug] ??= {}).add(k);
          }
        });
      }
      expect(found, isEmpty);
    });

    test('no card links a category the copy lacks', () {
      final missing = <String>{};
      void walk(Object? v, String at) {
        if (v is Map) {
          final slug = v['_lookup'];
          if (slug is String && !cats.containsKey(slug)) missing.add('$at → $slug');
          for (final x in v.values) {
            walk(x, at);
          }
        } else if (v is List) {
          for (final x in v) {
            walk(x, at);
          }
        } else if (v is String) {
          final target = raw[v];
          if (target != null && !cats.containsKey(target.categorySlug)) {
            missing.add('$at → ${target.categorySlug}');
          }
        }
      }

      for (final c in raw.values.where((c) => converted.containsKey(c.id))) {
        walk(converted[c.id], '${c.categorySlug} / ${c.name}');
      }
      expect(missing, isEmpty);
    });

    test('a closed category has the field count of §5', () {
      const targets = {
        'spell': 10,
        'feat': 5,
        'trait': 3,
        'species': 5,
        'subspecies': 3,
        'class': 14,
        'subclass': 4,
        'background': 6,
        'monster': 27,
        'animal': 27,
        'creature-action': 3,
        'magic-item': 10,
        'weapon': 11,
        'armor': 6,
        'tool': 7,
        'adventuring-gear': 4,
        'pack': 3,
        'ammunition': 4,
        'mount': 4,
        'vehicle': 9,
      };
      expect(freeSrdClosed, targets.keys.toSet());
      expect({for (final s in targets.keys) s: cats[s]!.fields.length}, targets);
    });

    test('every field the copy adds is filled in some card', () {
      final withCards = {for (final c in raw.values) c.categorySlug};
      final empty = <String>[];
      for (final cat in srdFreeTemplate.categories) {
        if (!withCards.contains(cat.slug)) continue;
        final had = {for (final f in builtin[cat.slug]!.fields) f.fieldKey};
        for (final f in cat.fields) {
          if (had.contains(f.fieldKey)) continue;
          final filled = raw.values.any(
            (c) =>
                c.categorySlug == cat.slug &&
                !blank(converted[c.id]![f.fieldKey]),
          );
          if (!filled) empty.add('${cat.slug} / ${f.fieldKey}');
        }
      }
      expect(empty, isEmpty);
    });
  });

  group('A2 spell', () {
    // §5.1; the PDF's lines, but where the pack deviates (K13): Counterspell's
    // trigger is shorter, Bless's material is the 2014 one.
    const lines = {
      'Fireball': [
        'Action',
        '150 feet',
        'V, S, M (a ball of bat guano and sulfur)',
        'Instantaneous',
      ],
      'Counterspell': [
        'Reaction, which you take when you see a creature within 60 feet of '
            'yourself casting a spell',
        '60 feet',
        'S',
        'Instantaneous',
      ],
      'Shield': [
        'Reaction, which you take when you are hit by an attack roll or '
            'targeted by the Magic Missile spell',
        'Self',
        'V, S',
        '1 round',
      ],
      'Identify': [
        '1 minute or Ritual',
        'Touch',
        'V, S, M (a pearl worth 100+ GP)',
        'Instantaneous',
      ],
      'Raise Dead': [
        '1 hour',
        'Touch',
        'V, S, M (a diamond worth 500+ GP, which the spell consumes)',
        'Instantaneous',
      ],
      'Bless': [
        'Action',
        '30 feet',
        'V, S, M (a sprinkling of holy water)',
        'Concentration, up to 1 minute',
      ],
      'Sequester': [
        'Action',
        'Touch',
        'V, S, M (gem dust worth 5,000+ GP, which the spell consumes)',
        'Until dispelled',
      ],
      'Wish': ['Action', 'Self', 'V', 'Instantaneous'],
      'Fire Bolt': ['Action', '120 feet', 'V, S', 'Instantaneous'],
      // The cost is in no text (R4); the range was "Special".
      'Find Familiar': [
        '1 hour or Ritual',
        '10 feet',
        'V, S, M (charcoal, incense, and herbs that must be consumed by fire '
            'in a brass brazier, worth 10+ GP)',
        'Instantaneous',
      ],
      'Dream': [
        '1 minute',
        'Special',
        'V, S, M (a handful of sand, a dab of ink, and a writing quill '
            'plucked from a sleeping bird)',
        '8 hours',
      ],
    };
    const keys = ['casting_time', 'range', 'components', 'duration'];

    test('the header lines read as the SRD writes them', () {
      for (final MapEntry(key: name, value: want) in lines.entries) {
        final s = converted[id('spell', name)]!;
        expect([for (final k in keys) s[k]], want, reason: name);
      }
    });

    test('every spell has its four lines and only the copy\'s fields', () {
      final fields = [for (final f in cats['spell']!.fields) f.fieldKey];
      expect(fields, [
        'level',
        'school_ref',
        'class_refs',
        ...keys,
        'is_ritual',
        'requires_concentration',
        'description',
      ]);
      final spells = raw.values.where((c) => c.categorySlug == 'spell');
      expect(spells, hasLength(341));
      for (final c in spells) {
        final s = converted[c.id]!;
        for (final k in keys) {
          expect(s[k], isA<String>().having((v) => v.isEmpty, 'empty', false),
              reason: '${c.name} / $k');
        }
        expect(s.keys.toSet().difference(fields.toSet()), isEmpty,
            reason: c.name);
      }
    });

    test('the description goes, and it was only the rules text again (S1)',
        () {
      for (final c in raw.values.where((c) => c.categorySlug == 'spell')) {
        expect(c.description, c.fields['description'], reason: c.name);
        expect(freeSrdDescription(c), '');
      }
    });

    test('the unit and component lookups leave the copy and the package', () {
      for (final slug in ['duration-unit', 'casting-time-unit',
          'casting-component']) {
        expect(cats.containsKey(slug), isFalse, reason: slug);
        expect(inFreeSrd(slug), isFalse);
      }
      expect(build.seedRows.keys, contains('duration-unit'));
    });
  });

  group('A3 grants, feat and trait', () {
    // §4: the grant block's card lists and the player card list each goes to.
    const targets = {
      'granted_damage_resistances': 'resistance_refs',
      'granted_damage_immunities': 'damage_immunity_refs',
      'granted_damage_vulnerabilities': 'vulnerability_refs',
      'granted_condition_immunities': 'condition_immunity_refs',
      'granted_senses': 'senses',
      'granted_languages': 'languages',
      'granted_tool_proficiencies': 'tool_proficiencies',
      'granted_weapon_proficiencies': 'weapon_proficiency_categories',
      'granted_armor_proficiencies': 'armor_trainings',
      'granted_spell_refs': 'spells_known',
      'granted_cantrip_refs': 'spells_known',
      'always_prepared_spell_refs': 'spells_known',
      'granted_action_refs': 'action_refs',
      'granted_bonus_action_refs': 'bonus_action_refs',
      'granted_reaction_refs': 'reaction_refs',
      'trait_refs': 'trait_refs',
    };
    final cards = raw.values.where(
      (c) => c.categorySlug == 'feat' || c.categorySlug == 'trait',
    );
    List<Map> cardItems(Map<String, dynamic> fields) => [
      for (final i in (fields['resource_pool_grants'] as List?) ?? const [])
        if (i is Map && i['kind'] == 'card') i,
    ];

    test('the copy keeps the SRD headings', () {
      String fields(String slug) => [
        for (final f in cats[slug]!.fields) '${f.fieldKey}:${f.label}',
      ].join(', ');
      expect(
        fields('feat'),
        'category_ref:Category, prerequisite:Prerequisite, '
        'benefits:Benefits, granted_spells_at_level:Spells by Level, '
        'resource_pool_grants:Grants',
      );
      expect(
        fields('trait'),
        'trait_kind:Trait Kind, description:Description, '
        'resource_pool_grants:Grants',
      );
      expect(cats['trait']!.filterFieldKeys, ['trait_kind']);
    });

    test('every unconditional granted card is a Grants item (R5)', () {
      var n = 0;
      for (final c in cards) {
        final want = [
          if (blank(c.fields['active_while_state_ref']))
            for (final MapEntry(:key, :value) in targets.entries)
              for (final r in (c.fields[key] as List?) ?? const [])
                {
                  'card': r is Map && r.containsKey('sense_ref')
                      ? r['sense_ref']
                      : r,
                  'to': value,
                },
        ];
        final got = [
          for (final i in cardItems(converted[c.id]!))
            // A class row's other cards (S3, A5) are not the block's.
            if (!'${i['_id']}'.startsWith('srd-r'))
              {
                'card': i['card'],
                'to': (i['targets'] as Map)['player-character'],
              },
        ];
        expect(got, unorderedEquals(want), reason: c.name);
        n += got.length;
      }
      expect(n, 36);
    });

    test('a Grants card fits the player card list it goes to', () {
      final player = {
        for (final f in cats['player-character']!.fields) f.fieldKey: f,
      };
      for (final c in cards) {
        for (final i in cardItems(stored(c.id))) {
          final list = player[(i['targets'] as Map)['player-character']];
          expect(
            list?.validation.allowedTypes,
            contains(raw[i['card']]?.categorySlug),
            reason: '${c.name} → ${i['card']}',
          );
        }
      }
    });

    test("Rage's resistances hold only while raging: not in Grants (R6)", () {
      for (final name in ['Rage', 'Mindless Rage']) {
        final c = raw[id('feat', name)]!;
        expect(c.fields['active_while_state_ref'], isNotNull);
        // The Rage action is the class row's (S3, A5), for good.
        expect(
          [for (final i in cardItems(converted[c.id]!)) i['_id']],
          name == 'Rage' ? ['srd-r1'] : isEmpty,
          reason: name,
        );
      }
    });

    test("Lucky's points follow the level in its Level table", () {
      final rows = converted[id('feat', 'Lucky')]!['granted_spells_at_level'];
      expect({
        for (final r in rows as List)
          for (final i in r['items'] as List) r['level']: '${i['name']} ${i['max']}',
      }, {
        1: 'Luck Points 2',
        5: 'Luck Points 3',
        9: 'Luck Points 4',
        13: 'Luck Points 5',
        17: 'Luck Points 6',
      });
    });

    test('what a dropped field says is in the card text (R3)', () {
      // Carried elsewhere: the copy's fields, Grants (R5), our summary of
      // the benefits (§4) and the editor flags. A Shield allowed with
      // Unarmored Defense is the lack of a rule, not a line.
      final skip = {
        ...{for (final f in cats['feat']!.fields) f.fieldKey},
        ...{for (final f in cats['trait']!.fields) f.fieldKey},
        ...targets.keys,
        'mechanical_notes',
        'chooseable',
        'active_while_state_ref',
        'unarmored_ac_shield_allowed',
        'source', // the card's own source, 'SRD 5.2.1' (§5.8)
      };
      const flags = {
        'repeatable': 'repeatable',
        'prereq_requires_spellcasting': 'spellcasting',
        'grants_save_prof_from_asi': 'saving throw',
      };
      const words = ['one', 'two', 'three', 'four', 'five', 'six'];
      const known = {
        // §5.7: Skill Expert is not in SRD 5.2.1 (§9).
        'Skill Expert / repeatable',
        // The ref names no card; "Dexterity 13+" / "Charisma 13+" is there.
        'Crossbow Expert / prereq_ability_ref',
        'Defensive Duelist / prereq_ability_ref',
        'Inspiring Leader / prereq_ability_ref',
        // "proficiency in another skill"
        'Primal Knowledge / bonus_skill_pick_count',
      };
      final missing = <String>[];
      for (final c in cards) {
        final text = [
          c.fields['prerequisite'],
          c.fields['benefits'],
          c.fields['description'],
        ].whereType<String>().join(' ').toLowerCase();
        bool has(Object? s) => text.contains('$s'.toLowerCase());
        bool count(num n) =>
            has(n) || (n > 0 && n <= 6 && has(words[n.toInt() - 1])) ||
            (n == 2 && has('twice'));
        bool name(Object? ref) {
          final e = raw[resolveEntityRef(ref, raw)];
          final n = entityRefName(ref, raw);
          // "Dex mod"
          return has(n) || (e?.categorySlug == 'ability' && has(n.substring(0, 3)));
        }

        for (final MapEntry(:key, :value) in c.fields.entries) {
          if (skip.contains(key) || blank(value)) continue;
          final ok = switch ((key, value)) {
            (_, true) => has(flags[key] ?? '\u0000'),
            ('asi_ability_options', List l) when l.length == 6 =>
              has('ability score'),
            (_, -1) => has(key.split('_')[1]), // "Climb Speed"
            (_, num n) => count(n),
            ('player_choices', List l) => l.every(
              (g) => count(g['pick'] as num) &&
                  ((g['options'] as List?) ?? const []).every(
                    (o) => has(o['label']),
                  ),
            ),
            (_, List l) => l.every(name),
            (_, Map m) => m.entries.every((e) => has(e.key) && count(e.value)),
            _ => name(value),
          };
          if (!ok && !known.contains('${c.name} / $key')) {
            missing.add('${c.name} / $key');
          }
        }
      }
      expect(missing, isEmpty);
    });

    test('the description above goes (S1): a trait\'s was its text again', () {
      for (final c in cards) {
        expect(freeSrdDescription(c), '', reason: c.name);
        if (c.categorySlug == 'trait') {
          expect(c.description, c.fields['description'], reason: c.name);
        }
      }
    });
  });

  group('A4 species and subspecies', () {
    Map<String, dynamic> of(String slug, String name) =>
        converted[id(slug, name)]!;
    List<String> grants(Map<String, dynamic> fields) => [
      for (final i in (fields['resource_pool_grants'] as List?) ?? const [])
        '${entityRefName(i['card'], raw)} → '
            '${(i['targets'] as Map)['player-character']}',
    ];
    Map<int, String> rows(String name) => {
      for (final r
          in (of('subspecies', name)['granted_spells_at_level'] as List?) ??
              const [])
        r['level'] as int: [
          if (r['text'] != null) r['text'],
          for (final i in (r['items'] as List?) ?? const [])
            i['kind'] == 'card'
                ? entityRefName(i['card'], raw)
                : '${i['name']} ×${i['max']}',
        ].join(' | '),
    };

    test('the copy reads as the SRD: Creature Type · Size · Speed · Traits',
        () {
      String fields(String slug) => [
        for (final f in cats[slug]!.fields)
          '${f.fieldKey}:${f.label}:${f.fieldType.name}',
      ].join(', ');
      expect(
        fields('species'),
        'creature_type_ref:Creature Type:relation, size:Size:text, '
        'speed_ft:Speed:integer, traits:Traits:markdown, '
        'resource_pool_grants:Grants:grantHolder',
      );
      expect(
        fields('subspecies'),
        'parent_species_ref:Parent Species:relation, '
        'granted_spells_at_level:Spells by Level:progressionTable, '
        'resource_pool_grants:Grants:grantHolder',
      );
    });

    test("Dwarf: the SRD's traits paragraphs and its cards in Grants", () {
      final dwarf = of('species', 'Dwarf');
      // K13: the pack's Darkvision is 60 ft (SRD: 120) and it has Forge Wise.
      expect(
        (dwarf['traits'] as String).split('\n\n').map(
          (p) => p.split('.**').first,
        ),
        [
          'As a Dwarf, you have these special traits.',
          '**Darkvision',
          '**Dwarven Resilience',
          '**Dwarven Toughness',
          '**Forge Wise',
          '**Stonecunning',
        ],
      );
      expect(
        dwarf['traits'],
        contains(
          '\n\n**Darkvision.** You have Darkvision with a range of 60 feet.\n\n',
        ),
      );
      expect(grants(dwarf), [
        'Darkvision → senses',
        'Poison → resistance_refs',
        'Dwarven Resilience → trait_refs',
        'Dwarven Toughness → trait_refs',
        'Stonecunning → trait_refs',
        'Forge Wise → trait_refs',
      ]);
      expect(of('species', 'Elf')['traits'], contains('**Keen Senses.** '));
      expect(of('species', 'Orc')['traits'], startsWith('As an Orc, '));
    });

    test("Human's Size is the SRD's line, with the choice", () {
      expect(
        of('species', 'Human')['size'],
        'Medium (about 4–7 feet tall) or Small (about 2–4 feet tall), '
        'chosen when you select this species',
      );
      expect(of('species', 'Dwarf')['size'], 'Medium (about 4–5 feet tall)');
      // Not in SRD 5.2.1: the size card's name.
      expect(of('species', 'Half-Elf')['size'], 'Medium');
    });

    test("Drow's rows are the Elven Lineages table's", () {
      expect(rows('Drow'), {
        1:
            'The range of your Darkvision increases to 120 feet. You also '
            'know the Dancing Lights cantrip. | Dancing Lights',
        3: 'Faerie Fire | Faerie Fire ×1',
        5: 'Darkness | Darkness ×1',
      });
      // The species gives the Darkvision card; the row says how far.
      expect(grants(of('subspecies', 'Drow')), isEmpty);
    });

    test("a Dragonborn lineage's resistance, a Giant's boon in Grants", () {
      expect(rows('Red Dragonborn'), {
        1: 'You have Resistance to Fire damage.',
      });
      expect(grants(of('subspecies', 'Red Dragonborn')), [
        'Fire → resistance_refs',
      ]);
      expect(grants(of('subspecies', 'Cloud Giant')), [
        "Cloud's Jaunt → bonus_action_refs",
      ]);
      expect(of('subspecies', 'Cloud Giant')['granted_spells_at_level'], isNull);
      expect(rows('Hill Dwarf'), {
        1:
            'You gain proficiency in the Insight skill. Your Hit Point '
            'maximum increases by 1, and it increases by 1 again whenever '
            'you gain a level.',
      });
    });

    test('what a dropped field gives is in the text, a row or Grants', () {
      for (final c in raw.values) {
        final f = c.fields;
        if (c.categorySlug == 'species') {
          final traits = of('species', c.name)['traits'] as String;
          for (final key in const [
            'trait_refs',
            'granted_action_refs',
            'granted_bonus_action_refs',
            'granted_reaction_refs',
          ]) {
            for (final r in (f[key] as List?) ?? const []) {
              final n = entityRefName(r, raw).split(' (').first;
              expect(traits, contains('**$n.** '), reason: '${c.name} $n');
            }
          }
          for (final s in (f['granted_senses'] as List?) ?? const []) {
            expect(traits, contains('range of ${s['range_ft']} feet'));
          }
        }
        if (c.categorySlug != 'subspecies') continue;
        final shown = [
          ...rows(c.name).values,
          ...grants(of('subspecies', c.name)),
        ].join(' ');
        for (final key in const [
          'granted_damage_resistances',
          'granted_skill_proficiencies',
          'granted_cantrip_refs',
          'granted_action_refs',
          'granted_bonus_action_refs',
          'granted_reaction_refs',
        ]) {
          for (final r in (f[key] as List?) ?? const []) {
            expect(shown, contains(entityRefName(r, raw)), reason: c.name);
          }
        }
        for (final key in const ['hp_bonus_flat', 'hp_bonus_per_level']) {
          if (f[key] case final num n) expect(shown, contains('by $n'));
        }
        if (f['speed_bonus_ft'] case final num n) {
          final parent = raw[resolveEntityRef(f['parent_species_ref'], raw)]!;
          expect(shown, contains('${parent.fields['speed_ft'] + n} feet'));
        }
        if (!blank(f['ability_bonuses'])) {
          expect(shown, contains('increase by 1'), reason: c.name);
        }
      }
    });

    test('the description above goes (S1)', () {
      for (final c in raw.values) {
        if (c.categorySlug == 'species' || c.categorySlug == 'subspecies') {
          expect(freeSrdDescription(c), '', reason: c.name);
        }
      }
    });
  });

  group('A5 class, subclass and background', () {
    Map<String, dynamic> of(String slug, String name) =>
        converted[id(slug, name)]!;
    String to(Object? i) => '${((i as Map)['targets'] as Map)['player-character']}';
    List<String> items(Object? list) => [
      for (final i in (list as List?) ?? const [])
        if (i['kind'] == 'card') '${entityRefName(i['card'], raw)} → ${to(i)}',
    ];
    // Free package cards as a world reads them, for the sheet scenarios.
    final free = {
      for (final c in raw.values)
        if (converted.containsKey(c.id))
          c.id: Entity(
            id: c.id,
            name: c.name,
            categorySlug: c.categorySlug,
            fields: stored(c.id),
          ),
    };
    final ctx = GrantContext(
      carrier: cats['player-character']!,
      categories: srdFreeTemplate.categories,
      entities: free,
    );

    test('the copy reads as the SRD: Core Traits, Becoming a …, Features', () {
      String fields(String slug) => [
        for (final f in cats[slug]!.fields)
          '${f.fieldKey}:${f.label}:${f.fieldType.name}',
      ].join(', ');
      expect(
        fields('class'),
        'complexity:Complexity:enum_, '
        'primary_ability:Primary Ability:text, '
        'hit_die:Hit Point Die:enum_, '
        'saving_throw_refs:Saving Throw Proficiencies:relation, '
        'skill_proficiencies:Skill Proficiencies:text, '
        'weapon_proficiencies:Weapon Proficiencies:text, '
        'tool_proficiencies:Tool Proficiencies:text, '
        'armor_training_refs:Armor Training:relation, '
        'casting_ability_ref:Spellcasting Ability:relation, '
        'equipment_choice_groups:Starting Equipment:markdown, '
        'becoming:Becoming a …:markdown, '
        'features:Features:progressionTable, '
        'cantrips_known_by_level:Cantrips:table, '
        'prepared_spells_by_level:Prepared Spells:table',
      );
      expect(
        fields('subclass'),
        'parent_class_ref:Parent Class:relation, '
        'granted_at_level:Granted at Level:integer, '
        'flavor_description:Flavor:markdown, '
        'features:Features:progressionTable',
      );
      expect(
        fields('background'),
        'ability_score_options:Ability Scores:relation, '
        'origin_feat_ref:Feat:relation, '
        'granted_skill_refs:Skill Proficiencies:relation, '
        'tool_proficiency:Tool Proficiency:text, '
        'equipment_choice_groups:Equipment:markdown, '
        'grants:Grants:grantHolder',
      );
      expect(cats['class']!.filterFieldKeys, isEmpty);
    });

    test("Barbarian's Core Traits lines and Becoming box are the SRD's", () {
      final b = of('class', 'Barbarian');
      expect(b['primary_ability'], 'Strength');
      expect(
        b['skill_proficiencies'],
        'Choose 2: Animal Handling, Athletics, Intimidation, Nature, '
        'Perception, or Survival',
      );
      expect(b['weapon_proficiencies'], 'Simple and Martial weapons');
      expect(b['tool_proficiencies'], isNull);
      expect(
        b['equipment_choice_groups'],
        "Choose A or B: (A) Greataxe, 4 Handaxes, Explorer's Pack, and 15 "
        'GP; or (B) 75 GP',
      );
      expect(
        b['becoming'],
        '**As a Level 1 Character**\n\n'
        '- Gain all the traits in the Core Barbarian Traits table.\n'
        '- Gain the Barbarian’s level 1 features, which are listed in the '
        'Barbarian Features table.\n\n'
        '**As a Multiclass Character**\n\n'
        '- Gain the following traits from the Core Barbarian Traits table: '
        'Hit Point Die, proficiency with Martial weapons, and training with '
        'Shields.\n'
        '- Gain the Barbarian’s level 1 features, which are listed in the '
        'Barbarian Features table.',
      );
      expect(of('class', 'Fighter')['primary_ability'], 'Strength or Dexterity');
      expect(of('class', 'Monk')['primary_ability'], 'Dexterity and Wisdom');
      expect(of('class', 'Druid')['tool_proficiencies'], 'Herbalism Kit');
      expect(
        of('class', 'Wizard')['becoming'],
        endsWith(' See the multiclassing rules in “Character Creation” to '
            'determine your available spell slots.'),
      );
    });

    test("Fighter's Starting Equipment: three options", () {
      // K13: the pack's option B says Studded Leather (SRD: … Armor).
      expect(
        of('class', 'Fighter')['equipment_choice_groups'],
        "Choose A, B, or C: (A) Chain Mail, Greatsword, Flail, 8 Javelins, "
        "Dungeoneer's Pack, and 4 GP; (B) Studded Leather, Scimitar, "
        "Shortsword, Longbow, 20 Arrows, Quiver, Dungeoneer's Pack, and 11 "
        'GP; or (C) 155 GP',
      );
    });

    test('S3: a row grants only its feat; its other cards are the feat\'s',
        () {
      final rage = (of('class', 'Barbarian')['features'] as List).first;
      expect(items(rage['items']), ['Rage → feats']);
      expect(items(of('feat', 'Rage')['resource_pool_grants']), [
        'Rage → bonus_action_refs',
      ]);
      expect(items(of('feat', 'Weapon Mastery (Barbarian)')['resource_pool_grants']), isEmpty);
      expect(items(of('feat', 'Flurry of Blows')['resource_pool_grants']), [
        'Flurry of Blows → bonus_action_refs',
      ]);
      expect(items(of('feat', "Monk's Focus")['resource_pool_grants']), isEmpty);
      // Its own block already gives the action: once.
      expect(items(of('feat', 'Fast Hands')['resource_pool_grants']), [
        'Fast Hands → bonus_action_refs',
      ]);

      String key(String n) =>
          n.replaceFirst(RegExp(r' \(.*\)$'), '').toLowerCase();
      var moved = 0, dropped = 0;
      for (final c in raw.values) {
        if (c.categorySlug != 'class' && c.categorySlug != 'subclass') continue;
        final rows = (of(c.categorySlug, c.name)['features'] as List).cast<Map>();
        for (final (i, r) in ((c.fields['features'] as List?) ?? const []).indexed) {
          final feats = [
            for (final f in (r['granted_feat_refs'] as List?) ?? const [])
              raw[resolveEntityRef(f, raw)]!,
          ];
          final row = rows.firstWhere((x) => x['_id'] == 'srd$i');
          if (feats.isEmpty) continue;
          expect(
            {for (final x in (row['items'] as List?) ?? const []) to(x)},
            {'feats'},
            reason: '${c.name} ${r['name']}',
          );
          final given = [
            for (final f in feats) ...items(of('feat', f.name)['resource_pool_grants']),
          ];
          for (final MapEntry(key: from, value: list) in srdFeatureTargets.entries) {
            if (from == 'granted_feat_refs') continue;
            for (final ref in (r[from] as List?) ?? const []) {
              final n = entityRefName(ref, raw);
              if (from == 'granted_trait_refs' &&
                  feats.any((f) => key(f.name) == key(n))) {
                dropped++;
              } else {
                expect(given, contains('$n → $list'), reason: '${c.name} $n');
                moved++;
              }
            }
          }
        }
      }
      expect((moved, dropped), (39, 61));
    });

    test("Druidic and Thieves' Cant are cards in their rows", () {
      String row(String cls, String name) => items(
        (of('class', cls)['features'] as List).firstWhere(
          (r) => '${r['text']}'.startsWith('**$name.**'),
        )['items'],
      ).join(', ');
      expect(row('Druid', 'Druidic'), 'Druidic → trait_refs, Druidic → languages');
      expect(row('Rogue', "Thieves' Cant"), "Thieves' Cant → languages");
    });

    test("a background's lines and Grants: its feat and tool", () {
      final a = of('background', 'Acolyte');
      expect(a['tool_proficiency'], "Calligrapher's Supplies");
      expect(
        a['equipment_choice_groups'],
        "Choose A or B: (A) Calligrapher's Supplies, Book, Holy Symbol, "
        'Parchment, Robe, 8 GP; or (B) 50 GP',
      );
      expect(items(a['grants']), [
        'Magic Initiate → feats',
        "Calligrapher's Supplies → tool_proficiencies",
      ]);
      final soldier = of('background', 'Soldier');
      expect(
        soldier['tool_proficiency'],
        'Choose one kind of Gaming Set (see “Equipment”)',
      );
      expect(items(soldier['grants']), ['Savage Attacker → feats']);
    });

    test('what a dropped field says is in a line, a row or Grants (R3)', () {
      String names(Object? refs) => [
        for (final r in (refs as List?) ?? const []) entityRefName(r, raw),
      ].join(' ');
      for (final c in raw.values) {
        final f = c.fields, out = converted[c.id];
        final text = '$out';
        switch (c.categorySlug) {
          case 'class':
            for (final key in const [
              'primary_ability_ref',
              'secondary_ability_ref',
              'weapon_proficiency_categories',
              'granted_tool_refs',
              'granted_languages',
            ]) {
              final v = f[key] is List ? names(f[key]) : entityRefName(f[key], raw);
              for (final n in v.split(' ').where((n) => n.isNotEmpty)) {
                expect(text, contains(n), reason: '${c.name} $key');
              }
            }
            if (!srdClassLines.containsKey(c.name) ||
                !srdClassLines[c.name]!.containsKey('skill_proficiencies')) {
              expect(
                out!['skill_proficiencies'],
                allOf(
                  startsWith('Choose ${f['skill_proficiency_choice_count']}: '),
                  contains(entityRefName((f['skill_proficiency_options'] as List).last, raw)),
                ),
              );
            }
            for (final o in f['equipment_choice_groups'][0]['options'] as List) {
              expect(out!['equipment_choice_groups'], contains('${o['gold_gp']} GP'));
            }
            expect(out!['becoming'], isNotEmpty, reason: c.name);
          case 'subclass' when f['bonus_skill_pick_count'] == 3:
            expect(text, contains('three skills'), reason: c.name);
          case 'background':
            expect(
              out!['equipment_choice_groups'],
              allOf(
                contains('${f['starting_gold_gp']} GP'),
                contains('(B) ${f['gold_alternative_gp']} GP'),
              ),
            );
        }
      }
    });

    test('the description above: a subclass\'s SRD line, else none (S1)', () {
      for (final c in raw.values) {
        if (c.categorySlug == 'class' || c.categorySlug == 'background') {
          expect(freeSrdDescription(c), '', reason: c.name);
        }
        if (c.categorySlug == 'subclass') {
          expect(freeSrdDescription(c), isNotEmpty, reason: c.name);
        }
      }
      expect(
        freeSrdDescription(raw[id('subclass', 'Path of the Berserker')]!),
        'Channel Rage into Violent Fury',
      );
    });

    // free_srd_levels_test's Aria, on the free package's own data.
    GrantChange take(Map<String, dynamic> fields, String list, String card) =>
        settleGrants(fields, {
          ...fields,
          list: [...((fields[list] as List?) ?? const []), card],
        }, ctx);
    int? poolMax(GrantResult r, String name) =>
        r.resources.where((x) => x.name == name).firstOrNull?.max;
    List<String> names(Object? ids) => [
      for (final i in (ids as List?) ?? const []) free[i]!.name,
    ];

    test('Aria: Fighter 1 → 2, then Wizard, with no card twice', () {
      final fighter = id('class', 'Fighter');
      final l1 = take({'level': 1}, 'class_refs', fighter);
      expect(names(l1.fields['feats']), contains('Second Wind'));
      expect(names(l1.fields['bonus_action_refs']), contains('Second Wind'));
      // The Weapon Mastery trait was the feat again.
      expect(names(l1.fields['trait_refs']), isNot(contains('Weapon Mastery')));
      expect(poolMax(l1.after, 'Second Wind'), 2);

      final l2 = settleGrants(
        l1.fields,
        levelUp(l1.fields, ctx, picked: {'class': fighter}),
        ctx,
      );
      expect(names(l2.fields['feats']), contains('Action Surge'));
      expect(poolMax(l2.after, 'Action Surge'), 1);

      final wizard = id('class', 'Wizard');
      final l3 = settleGrants(
        l2.fields,
        levelUp(l2.fields, ctx, added: {'class': wizard}),
        ctx,
      );
      expect(poolMax(l3.after, 'Level 1 Slots'), 2);
      expect(poolMax(l3.after, 'Arcane Recovery'), 1);
      expect(names(l3.fields['trait_refs']), contains('Spellcasting Focus'));
      for (final list in const ['feats', 'trait_refs', 'action_refs', 'bonus_action_refs']) {
        final n = names(l3.fields[list]);
        expect(n.toSet().length, n.length, reason: list);
      }
    });

    test('Barbarian 1 and 8: Rage feat and action; Rage 4', () {
      final b = id('class', 'Barbarian');
      final l1 = take({'level': 1}, 'class_refs', b);
      expect(names(l1.fields['feats']), contains('Rage'));
      expect(names(l1.fields['bonus_action_refs']), ['Rage']);
      expect(l1.fields['resistance_refs'], anyOf(isNull, isEmpty));
      final l8 = computeGrants({
        'level': 8,
        'class_refs': [b],
        cardLevelsKey: {b: 8},
      }, ctx);
      expect(poolMax(l8, 'Rage'), 4);
    });

    test('Acolyte: Magic Initiate and the tool; the feat\'s Grants chain', () {
      final c = take({'level': 1}, 'background_ref', id('background', 'Acolyte'));
      expect(names(c.fields['feats']), ['Magic Initiate']);
      expect(names(c.fields['tool_proficiencies']), ["Calligrapher's Supplies"]);
    });
  });

  group('A6 monster, animal and action', () {
    Map<String, dynamic> of(String slug, String name) =>
        converted[id(slug, name)]!;
    String text(String name) =>
        of('creature-action', name)['description'] as String;

    test('the copy reads as the SRD stat block', () {
      String fields(String slug) => [
        for (final f in cats[slug]!.fields) '${f.fieldKey}:${f.label}',
      ].join(', ');
      const block =
          'size_ref:Size, creature_type_ref:Creature Type, '
          'tags_line:Tags (e.g. "(goblinoid)"), alignment_ref:Alignment, '
          'combat_stats:Combat Stats, hp_dice:HP Dice, speed:Speed, '
          'stat_block:Ability Scores, save_bonuses:Saving Throws, '
          'skill_bonuses:Skills, resistance_refs:Resistances, '
          'vulnerability_refs:Vulnerabilities, '
          'damage_immunity_refs:Damage Immunities, '
          'condition_immunity_refs:Condition Immunities, senses:Senses, '
          'passive_perception:Passive Perception, language_refs:Languages, '
          'telepathy_ft:Telepathy (ft), cr:Challenge Rating, '
          'proficiency_bonus:Proficiency Bonus, trait_refs:Traits, '
          'action_refs:Actions, bonus_action_refs:Bonus Actions, '
          'reaction_refs:Reactions, '
          'legendary_action_uses:Legendary Action Uses, '
          'legendary_action_refs:Legendary Actions, gear_refs:Gear';
      expect(fields('monster'), block);
      expect(fields('animal'), block);
      expect(
        fields('creature-action'),
        'action_type:Action Type, damage_dice:Damage Dice, '
        'description:Description',
      );
      expect(cats['creature-action']!.filterFieldKeys, ['action_type']);

      // The card's groups in the SRD's order: Speed with AC and HP, the
      // saves and skills with the ability scores.
      final m = cats['monster']!;
      final groups = [...m.fieldGroups]
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      final shown = [
        for (final g in groups)
          for (final f in m.fields.where((f) => f.groupId == g.groupId))
            f.fieldKey,
      ];
      expect(shown, [for (final f in m.fields) f.fieldKey]);
      expect(m.fields.where((f) => f.groupId == null), isEmpty);
    });

    test('Adult Red Dragon: Speed, the block, the legendary actions', () {
      final d = of('monster', 'Adult Red Dragon');
      expect(d['speed'], '40 ft., Climb 40 ft., Fly 80 ft.');
      expect(d['combat_stats'], {
        'xp': 18000,
        'hp': 256,
        'max_hp': 256,
        'ac': 19,
        'initiative': '1d20+12',
      });
      expect(d['legendary_action_uses'], 3);
      expect(
        [for (final r in d['legendary_action_refs'] as List) entityRefName(r, raw)],
        ['Commanding Presence', 'Frightful Presence', 'Tail Attack'],
      );
      // Its own text had the recharge already, at the end.
      expect(text('Fire Breath'), endsWith('*Success:* Half damage. (Recharge 5–6).'));
      expect(text('Fire Breath'), isNot(startsWith('(')));
      // The DC is its Spellcasting's (§5.11).
      expect(text('Commanding Presence'), startsWith('The dragon uses Spellcasting'));
    });

    test('Speed lines: hover, burrow, swim; a creature with no walk', () {
      expect(of('monster', 'Goblin Warrior')['speed'], '30 ft.');
      expect(of('monster', 'Banshee')['speed'], '5 ft., Fly 40 ft. (hover)');
      expect(of('monster', 'Adult White Dragon')['speed'],
          '40 ft., Burrow 30 ft., Fly 80 ft., Swim 40 ft.');
      expect(of('monster', 'Specter')['speed'], '0 ft., Fly 50 ft.');
      expect(of('animal', 'Wolf')['speed'], '40 ft.');
    });

    test('the heading limits and missing DCs go at the text start (R4)', () {
      expect(
        text('Acid Breath'),
        '(Recharge 5–6). *Dexterity Saving Throw:* DC 18, each creature in a '
        '60-foot-long, 5-foot-wide Line. *Failure:* 67 (15d8) Acid damage. '
        '*Success:* Half damage.',
      );
      expect(
        text('Repulsion Breath'),
        '(Recharge 5–6). *Strength Saving Throw:* DC 14, each creature in a '
        'Cone. *Failure:* Pushed 60 feet and knocked Prone.',
      );
      expect(text('Lightning Strike (Storm Giant)'), startsWith('(3/Day). *Dexterity'));
      expect(text('Acid Spray (Ankheg)'), startsWith('(1/Day). '));
      expect(
        text('Touch (Sprite)'),
        '*Charisma Saving Throw:* DC 10. The sprite touches a creature; on a '
        'failed save, the creature has Charmed or Frightened condition.',
      );
      expect(text('Relentless Endurance'), isNot(startsWith('(')));
    });

    test('what a dropped action field says is in its text (R3, R4)', () {
      final missing = <String>[];
      for (final a in raw.values.where((c) => c.categorySlug == 'creature-action')) {
        final f = a.fields;
        final t = text(a.name);
        void need(bool ok, String what) {
          if (!ok) missing.add('${a.name}: $what');
        }

        if (f['attack_bonus'] case final num b) {
          need(t.contains(b < 0 ? '$b' : '+$b'), 'attack $b');
        }
        if (f['reach_ft'] case final num r) need(t.contains('reach $r ft'), 'reach');
        if (f['range_normal_ft'] case final num r) need(t.contains('$r'), 'range');
        if (f['save_dc'] case final num dc
            when !t.contains('Spellcasting')) {
          need(t.contains('DC $dc'), 'DC $dc');
        }
        if (f['recharge_min_roll'] case final num n) {
          need(t.contains('Recharge $n–6'), 'recharge');
        }
        if (f['uses_per_day'] case final num n) {
          need(t.contains('$n/Day') || t.contains('Once per'), '$n/Day');
        }
      }
      expect(missing, isEmpty);
    });

    test('the encounter reads the block as before', () {
      final world = srdFreeTemplate;
      Entity card(String slug, String name) => Entity(
        id: id(slug, name),
        name: name,
        categorySlug: slug,
        fields: stored(id(slug, name)),
      );
      final g = freeCombatantValues(world, card('monster', 'Goblin Warrior'));
      expect((g.hp, g.maxHp), (7, 7));
      expect(g.stats['ac'], 12);
      expect(freeSortSpec(world, g.stats), '1d20+2');
      expect(freeCombatantValues(world, card('animal', 'Wolf')).maxHp, 11);
    });

    test('the description above goes (S1)', () {
      for (final slug in const ['monster', 'animal', 'creature-action']) {
        for (final c in raw.values.where((c) => c.categorySlug == slug)) {
          expect(freeSrdDescription(c), '', reason: c.name);
        }
      }
    });
  });

  group('A7 magic item and equipment', () {
    Map<String, dynamic> of(String slug, String name) =>
        converted[id(slug, name)]!;
    String fields(String slug) =>
        [for (final f in cats[slug]!.fields) f.fieldKey].join(', ');

    test('the copy reads as the SRD tables', () {
      expect(
        fields('magic-item'),
        'magic_category_ref, rarity_ref, requires_attunement, '
        'attunement_prereq, base_item_ref, charges_max, charge_regain, '
        'effects, cost_gp, weight_lb',
      );
      expect(fields('armor'),
          'category_ref, armor_class, strength_requirement, '
          'stealth_disadvantage, cost_gp, weight_lb');
      expect(fields('tool'),
          'category_ref, variant_of_ref, ability_ref, utilize_description, '
          'craft, cost_gp, weight_lb');
      expect(fields('adventuring-gear'),
          'cost_cp, weight_lb, utilize_description, focus_kind_ref');
      expect(fields('pack'), 'cost_gp, weight_lb, contents');
      expect(fields('weapon'), isNot(contains('is_melee')));
    });

    test("every armor's AC is the Armor table's (PDF)", () {
      const table = {
        'Padded Armor': '11 + Dex modifier',
        'Leather Armor': '11 + Dex modifier',
        'Studded Leather Armor': '12 + Dex modifier',
        'Hide Armor': '12 + Dex modifier (max 2)',
        'Chain Shirt': '13 + Dex modifier (max 2)',
        'Scale Mail': '14 + Dex modifier (max 2)',
        'Breastplate': '14 + Dex modifier (max 2)',
        'Half Plate Armor': '15 + Dex modifier (max 2)',
        'Ring Mail': '14',
        'Chain Mail': '16',
        'Splint Armor': '17',
        'Plate Armor': '18',
        'Shield': '+2',
      };
      expect({
        for (final c in raw.values.where((c) => c.categorySlug == 'armor'))
          c.name: converted[c.id]!['armor_class'],
      }, table);
    });

    test('the don / doff times are on the armor category cards', () {
      expect(of('armor-category', 'Heavy')['effects'],
          '10 Minutes to Don and 5 Minutes to Doff');
      expect(of('armor-category', 'Shield')['effects'],
          'Utilize Action to Don or Doff');
    });

    test("a tool's Craft line is the SRD's; some craft nothing", () {
      expect(of('tool', "Alchemist's Supplies")['craft'],
          'Acid, Alchemist’s Fire, Component Pouch, Oil, Paper, Perfume');
      expect(of('tool', "Alchemist's Supplies")['utilize_description'],
          'Identify a substance (DC 15), or start a fire (DC 15)');
      expect(of('tool', "Thieves' Tools")['craft'], isNull);
      expect(of('tool', "Navigator's Tools")['craft'], isNull);
      final tools = {
        for (final c in raw.values.where((c) => c.categorySlug == 'tool'))
          c.name,
      };
      expect(tools.containsAll(srdToolCrafts.keys), isTrue);
    });

    test('Wand of Magic Missiles: its charges stay data (S4)', () {
      final w = of('magic-item', 'Wand of Magic Missiles');
      expect((w['charges_max'], w['charge_regain']), (7, '1d6+1 daily at dawn'));
      expect(w['effects'], startsWith('This wand has 7 charges.'));
      expect(w.keys, isNot(contains('activation')));
    });

    test('what a dropped field says is in a line or the text (R3)', () {
      final missing = <String>[];
      for (final c in raw.values) {
        final dc = c.fields['utilize_check_dc'];
        if (dc is num &&
            !'${converted[c.id]!['utilize_description']}'.contains('DC $dc')) {
          missing.add(c.name);
        }
        if (c.categorySlug == 'pack') {
          final n = (c.fields['content_refs'] as List).length;
          final contents = converted[c.id]!['contents'] as String;
          if (contents.split(', ').length != n) missing.add(c.name);
        }
      }
      expect(missing, isEmpty);
    });

    test('the description above goes (S1): an item\'s was its text again', () {
      for (final c in raw.values.where(
        (c) => c.categorySlug == 'magic-item',
      )) {
        expect(c.description, c.fields['effects'], reason: c.name);
        expect(freeSrdDescription(c), '', reason: c.name);
      }
    });
  });
}
