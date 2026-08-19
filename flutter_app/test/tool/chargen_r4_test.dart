import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/mappers/chargen.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Roadmap phase R4 — the chargen mapper stops guessing.**
///
/// Seven findings, none of which needed a new schema field: every one of them
/// was the mapper answering a question the source had already answered, or
/// answering one the source never asked.
///
///   * F-pass0-02 — a "pick one of these" skill line was granted in full.
///   * F-pass0-04 — upstream's `[No description provided]` shipped as prose.
///   * F-pass0-05 — the number-word table stopped at five and `no` matched
///     inside "no longer spoken".
///   * F-pass0-06 — a catalog item behind a qualifier or inside a parenthetical
///     never reached the inventory.
///   * F-toh-01 — a spell-slot table row dragged `granted_at_level` to 1.
///   * F-a5e-ag-01 — `grants_save_prof_from_asi` had a field and two readers but
///     no writer.
///   * F-bfrd-01 — a clashing class-table column was numbered although the
///     source's own `pk` names it.
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

  /// One background with a single benefit row of [type].
  void background(String name, String type, String desc, {String? bgDesc}) {
    mapBackgrounds(
      pack: pack,
      norm: norm,
      source: 'Test Doc',
      backgrounds: [
        <String, dynamic>{'_pk': 'b1', 'name': name, 'desc': bgDesc ?? 'Prose.'},
      ],
      benefits: [
        <String, dynamic>{'_pk': 'x1', 'parent': 'b1', 'type': type, 'desc': desc},
      ],
    );
  }

  List<String> skills(String name) => [
        for (final r in (attrs('background', name)['granted_skill_refs']
                as List? ??
            const []))
          (r as Map)['name'] as String,
      ];

  group('F-pass0-02 — a choice is not a grant', () {
    test('the fixed half is granted, the alternatives are not', () {
      // a5e-ag Sage, verbatim.
      background('Sage', 'skill_proficiency',
          'History, and either Arcana, Culture, Engineering, or Religion.');
      expect(skills('Sage'), ['History']);
    });

    test('a line that is all choice grants nothing rather than everything', () {
      // tdcs Lyceum Student. Under-granting is A3's rule; the choice field is R5.
      background('Lyceum Student', 'skill_proficiency',
          'Your choice of two from among Arcana, History, and Persuasion.');
      expect(attrs('background', 'Lyceum Student')['granted_skill_refs'], isNull);
    });

    test('a plain list is still granted in full', () {
      background('Acolyte', 'skill_proficiency', 'Insight, Religion.');
      expect(skills('Acolyte'), ['Insight', 'Religion']);
    });

    test('"any one skill of your choice" leaves the named grant intact', () {
      // a5e-gpg Haunted — the free pick already fell through before R4; what
      // must not happen is the named half falling with it.
      background('Haunted', 'skill_proficiency',
          'Religion, and any one skill of your choice.');
      expect(skills('Haunted'), ['Religion']);
    });
  });

  group('F-pass0-04 — upstream placeholder prose', () {
    test('"[No description provided]" never reaches the card', () {
      background('Cursed', 'ability_score', '+1 Charisma and one other ability score.',
          bgDesc: '[No description provided]');
      final d = attrs('background', 'Cursed')['description'] as String;
      expect(d, isNot(contains('No description provided')));
      expect(d, startsWith('+1 Charisma'));
    });

    test('a benefit row carrying the placeholder is skipped, not folded', () {
      background('Deep Hunter', 'equipment', '[No description provided]',
          bgDesc: 'A hunter from below.');
      expect(attrs('background', 'Deep Hunter')['description'], 'A hunter from below.');
    });

    test('real prose is untouched', () {
      background('Sage', 'skill_proficiency', 'History.', bgDesc: 'A scholar.');
      expect(attrs('background', 'Sage')['description'], startsWith('A scholar.'));
    });
  });

  group('F-pass0-05 — the language count', () {
    int? count(String desc) {
      pack = PackBuilder('test-pack');
      background('BG', 'language', desc);
      return attrs('background', 'BG')['granted_language_count'] as int?;
    }

    test('"Any six" is six, not zero', () {
      // a5e-ddg Dungeon Robber: `six` was off the end of the table and the `no`
      // of "no longer spoken" won instead.
      expect(count('Any six (three of them no longer spoken).'), 6);
    });

    test('the first number word in text order wins', () {
      // a5e-gpg Haunted — `one` came first in the map, `two` comes first in the
      // sentence, and the sentence is the source.
      expect(
          count("Two of your choice, one of which is the spirit's native language."),
          2);
    });

    test('a real "no languages" line is still zero', () {
      expect(count('No additional languages.'), 0);
      expect(count('None.'), 0);
    });

    test('the plain cases are unchanged', () {
      expect(count('One of your choice.'), 1);
      expect(count('Two of your choice.'), 2);
    });
  });

  group('F-pass0-06 — named gear reaches the inventory', () {
    test('a qualifier in front of a catalog name still lands on the card', () {
      expect(builtinItem('Belt Pouch')?.name, 'Pouch');
      expect(builtinItem('Prayer Book')?.name, 'Book');
      expect(builtinItem('Bag Of 1000 Ball Bearings')?.name, 'Ball Bearings');
    });

    test('a suffix that is not a card is still a miss', () {
      // The rule may only ever *land* on a real name — otherwise it is a guess.
      for (final t in const [
        'Memento Of Your Destiny',
        'Pet Monkey Wearing A Tiny Fez',
        'Collection Of Bones',
        // SRD 5.2.1 dropped "common clothes"; inventing a card for the 20 kits
        // that name it would be worse than the empty row (R4's written `N`).
        'Common Clothes',
      ]) {
        expect(builtinItem(t), isNull, reason: t);
      }
    });

    test('a parenthetical is tokenised, not deleted', () {
      background('Acolyte', 'equipment',
          'A holy symbol (amulet or reliquary), a prayer book, 15 gp.');
      final groups = attrs('background', 'Acolyte')['equipment_choice_groups'] as List;
      final items = [
        for (final o in (groups.single as Map)['options'] as List)
          for (final i in (o as Map)['items'] as List)
            ((i as Map)['ref'] as Map)['name'] as String,
      ];
      expect(items, containsAll(['Amulet (Holy Symbol)', 'Reliquary', 'Book']));
    });

    test('the gold inside a parenthetical is still not an item', () {
      background('Urchin', 'equipment', 'A belt pouch (containing 10 gp).');
      final groups = attrs('background', 'Urchin')['equipment_choice_groups'] as List;
      final opt = ((groups.single as Map)['options'] as List).single as Map;
      final items = [
        for (final i in opt['items'] as List) ((i as Map)['ref'] as Map)['name'],
      ];
      expect(items, ['Pouch']);
      expect(opt['gold_gp'], 10);
    });
  });

  group('F-toh-01 — a slot table is not the level a subclass is taken at', () {
    Map<String, dynamic> subclass(List<({String name, int level})> features) {
      pack = PackBuilder('test-pack');
      mapClasses(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        classes: [
          <String, dynamic>{
            '_pk': 'sc',
            'name': 'Underfoot',
            'desc': 'A rogue archetype.',
            'subclass_of': 'toh_rogue',
          },
        ],
        features: [
          for (var i = 0; i < features.length; i++)
            <String, dynamic>{
              '_pk': 'f$i',
              'parent': 'sc',
              'name': features[i].name,
              'desc': 'Prose.',
            },
        ],
        featureItems: [
          for (var i = 0; i < features.length; i++)
            <String, dynamic>{'parent': 'f$i', 'level': features[i].level},
        ],
      );
      return attrs('subclass', 'Underfoot');
    }

    test('a prose spell-slot row no longer drags the minimum to 1', () {
      final a = subclass([
        (name: 'Spell Slots', level: 1),
        (name: 'Spells Known of 1st-Level and Higher', level: 1),
        (name: 'Spellcasting', level: 3),
      ]);
      expect(a['granted_at_level'], 3);
      // The rows themselves still ship — only the minimum ignores them.
      expect((a['features'] as List).length, 3);
    });

    test('a real level-1 feature still opens the subclass at 1', () {
      expect(
          subclass([
            (name: 'Divine Domain', level: 1),
            (name: 'Spell Slots', level: 1),
          ])['granted_at_level'],
          1);
    });

    test('a subclass that is nothing but table rows keeps its own minimum', () {
      // Never leave the field absent because everything got excluded.
      expect(subclass([(name: 'Spell Slots', level: 2)])['granted_at_level'], 2);
    });
  });

  group('F-a5e-ag-01 — the save proficiency that rides on the ASI', () {
    bool? saveProf(String desc) {
      pack = PackBuilder('test-pack');
      mapFeats(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        feats: [
          <String, dynamic>{'_pk': 'f1', 'name': 'Tenacious', 'desc': desc},
        ],
        benefits: const [],
      );
      return attrs('feat', 'Tenacious')['grants_save_prof_from_asi'] as bool?;
    }

    test('Tenacious claims it — same mechanic as built-in Resilient', () {
      expect(
          saveProf('Choose one ability score. The chosen ability score increases '
              'by 1, to a maximum of 20, and you gain proficiency in saving '
              'throws using it.'),
          isTrue);
    });

    test('an ASI with no save clause does not', () {
      expect(
          saveProf('Choose one ability score. The chosen ability score increases '
              'by 1, to a maximum of 20.'),
          isNull);
    });

    test('a named save proficiency is not this field', () {
      // "proficiency in Wisdom saving throws" is a fixed grant, not the
      // "whichever you raised" shape the readers expect.
      expect(
          saveProf('Choose one ability score. The chosen ability score increases '
              'by 1, to a maximum of 20. You gain proficiency in Wisdom saving '
              'throws.'),
          isNull);
    });
  });
}
