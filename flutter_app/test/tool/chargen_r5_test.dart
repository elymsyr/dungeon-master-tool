import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/mappers/chargen.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Roadmap phase R5 — four chargen mechanics get a home.**
///
/// R4 stopped the mapper guessing; R5 gives it somewhere to put what it reads.
/// Every case here is a value the source always carried and the pack could not
/// hold:
///
///   * F-pass0-03 — "+1 Charisma **and** one other ability score": the
///     mandatory half now lands in `asi_fixed_ability_ref`, so
///     `ability_score_options` can go back to being the free pick's menu.
///   * F-pass0-09 — a named language (`Thieves’ Cant`, curly apostrophe and
///     all) instead of a count.
///   * F-pass0-10 — a third-caster archetype on a non-caster class.
///   * F-pass0-08 — a domain / circle spell table, one row per tier.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  Iterable<Map<String, dynamic>> rows() =>
      pack.entities.values.cast<Map<String, dynamic>>();

  Map<String, dynamic> attrs(String type, String name) =>
      rows().firstWhere((e) => e['type'] == type && e['name'] == name)['attributes']
          as Map<String, dynamic>;

  void background(String name, String type, String desc) {
    mapBackgrounds(
      pack: pack,
      norm: norm,
      source: 'Test Doc',
      backgrounds: [
        <String, dynamic>{'_pk': 'b1', 'name': name, 'desc': 'Prose.'},
      ],
      benefits: [
        <String, dynamic>{'_pk': 'x1', 'parent': 'b1', 'type': type, 'desc': desc},
      ],
    );
  }

  /// One base class + one subclass, with the subclass's features supplied.
  Map<String, dynamic> subclass({
    required String parentCasterType,
    required List<({String name, String desc, int level})> features,
  }) {
    pack = PackBuilder('test-pack');
    mapClasses(
      pack: pack,
      norm: norm,
      source: 'Test Doc',
      classes: [
        <String, dynamic>{
          '_pk': 'base',
          'name': 'Rogue',
          'desc': 'A base class.',
          'caster_type': parentCasterType,
        },
        <String, dynamic>{
          '_pk': 'sc',
          'name': 'Trickster',
          'desc': 'An archetype.',
          'subclass_of': 'base',
        },
      ],
      features: [
        for (var i = 0; i < features.length; i++)
          <String, dynamic>{
            '_pk': 'f$i',
            'parent': 'sc',
            'name': features[i].name,
            'desc': features[i].desc,
          },
      ],
      featureItems: [
        for (var i = 0; i < features.length; i++)
          <String, dynamic>{'parent': 'f$i', 'level': features[i].level},
      ],
    );
    return attrs('subclass', 'Trickster');
  }

  group('F-pass0-03 — the mandatory ability is not an option', () {
    test('the named +1 leaves the options list and gets its own field', () {
      background('Cursed', 'ability_score',
          '+1 Charisma and one other ability score.');
      final a = attrs('background', 'Cursed');
      expect((a['asi_fixed_ability_ref'] as Map)['name'], 'Charisma');
      expect(a['asi_free_bonus_count'], 1);
      final options = [
        for (final o in a['ability_score_options'] as List) (o as Map)['name'],
      ];
      // "one **other** ability score" — five, and Charisma is not among them.
      expect(options, hasLength(5));
      expect(options, isNot(contains('Charisma')));
    });

    test('A5E\'s other phrasing lands the same way', () {
      background('Wanderer', 'ability_score',
          '+1 to Wisdom and one other ability score.');
      expect((attrs('background', 'Wanderer')['asi_fixed_ability_ref'] as Map)['name'],
          'Wisdom');
    });

    test('the SRD-2024 three-ability list is untouched', () {
      background('Acolyte', 'ability_score', 'Intelligence, Wisdom, Charisma');
      final a = attrs('background', 'Acolyte');
      expect(a['asi_fixed_ability_ref'], isNull);
      expect((a['ability_score_options'] as List), hasLength(3));
      expect(a['asi_distribution_options'], ['+2/+1', '+1/+1/+1']);
    });
  });

  group('F-pass0-09 — a named language is a grant, not a slot', () {
    test('the curly apostrophe no longer hides the match', () {
      // tdcs Crime Syndicate Member, verbatim from the source.
      background('Crime Syndicate Member', 'language', 'Thieves’ Cant');
      final a = attrs('background', 'Crime Syndicate Member');
      expect([for (final l in a['granted_languages'] as List) (l as Map)['name']],
          ["Thieves' Cant"]);
      // A named grant is not also a free pick.
      expect(a['granted_language_count'], isNull);
    });

    test('a choice line stays a count', () {
      background('Sage', 'language', 'Two of your choice.');
      final a = attrs('background', 'Sage');
      expect(a['granted_language_count'], 2);
      expect(a['granted_languages'], isNull);
    });

    test('"no additional languages" is still zero, not a grant', () {
      background('Local', 'language', 'No additional languages.');
      final a = attrs('background', 'Local');
      expect(a['granted_language_count'], 0);
      expect(a['granted_languages'], isNull);
    });
  });

  group('F-pass0-10 — the archetype that casts', () {
    test('a spellcasting archetype on a non-caster class is a third caster', () {
      final a = subclass(parentCasterType: 'NONE', features: [
        (
          name: 'Spellcasting',
          desc: 'Beginning at 3rd level, you can cast spells from the wizard '
              'spell list.',
          level: 3,
        ),
      ]);
      expect(a['caster_kind'], 'Third');
    });

    test('the same words on a caster class claim nothing', () {
      // `toh`'s five "Potent Spellcasting" rows all sit on classes that
      // already cast; the parent's own kind is the guard.
      final a = subclass(parentCasterType: 'FULL', features: [
        (
          name: 'Potent Spellcasting',
          desc: 'You can cast spells from the wizard spell list.',
          level: 8,
        ),
      ]);
      expect(a['caster_kind'], isNull);
    });

    test('an ordinary archetype declares no caster kind at all', () {
      final a = subclass(parentCasterType: 'NONE', features: [
        (name: 'Sneak Attack', desc: 'You deal extra damage.', level: 3),
      ]);
      expect(a['caster_kind'], isNull);
    });
  });

  group('F-pass0-08 — the spell table becomes refs', () {
    Map<String, dynamic> domain(String table) => subclass(
          parentCasterType: 'NONE',
          features: [(name: 'Death Domain Spells (table)', desc: table, level: 1)],
        );

    const realTable = 'Cleric Level | Spells |\n'
        '|--------------|------------------|\n'
        '| 1st          | *false life*, *ray of sickness* |\n'
        '| 5th          | *cloudkill* |\n';

    test('each tier becomes its own level-gated row', () {
      final feats = (domain(realTable)['features'] as List).cast<Map>();
      final made = feats.where((f) => f['always_prepared_spell_refs'] != null);
      expect(made.map((f) => f['level']), [1, 5]);
      expect(made.first['name'], 'Death Domain Spells (1st)');
      // The prose row is left where it was — the parsed rows are an addition.
      final prose = feats.firstWhere(
          (f) => f['name'] == 'Death Domain Spells (table)');
      expect(prose['always_prepared_spell_refs'], isNull);
      expect(prose['description'], contains('false life'));
    });

    test('only spellings that exist become refs', () {
      final feats = (domain(realTable)['features'] as List).cast<Map>();
      final names = [
        for (final f in feats)
          for (final r in (f['always_prepared_spell_refs'] as List? ?? const []))
            (r as Map)['name'],
      ];
      // Every cell here is a spelling SRD 5.2.1 really prints. A cell that
      // resolves nowhere is dropped instead of shipped as a dangling ref —
      // measured on the corpus: 149 of 170 cells land, 21 are 2014-only
      // spells no installed package holds.
      expect(names, ['False Life', 'Ray of Sickness', 'Cloudkill']);
    });

    test('a slot table is not a spell table', () {
      // "| 3rd | 2 | — |" has numbers where the spell names would be, and the
      // header does not say "Spells" on its own.
      const slots = 'Level | Cantrips Known | 1st | 2nd |\n'
          '|---|---|---|---|\n'
          '| 3rd | 2 | 2 | — |\n';
      final feats = (domain(slots)['features'] as List).cast<Map>();
      expect(feats.where((f) => f['always_prepared_spell_refs'] != null), isEmpty);
    });

    test('a parsed tier never lowers the level the subclass is taken at', () {
      final a = subclass(parentCasterType: 'NONE', features: [
        (name: 'Circle Spells', desc: realTable, level: 3),
      ]);
      expect(a['granted_at_level'], 3);
    });
  });
}
