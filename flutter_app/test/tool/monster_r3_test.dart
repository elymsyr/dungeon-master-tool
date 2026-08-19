import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/monster.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';
import '../../tool/open5e_import/vocab.dart';

/// **Stage R phase R3 — the four mechanics that had nowhere to live.**
///
/// F-pass0-19 (`resistance_note` / `immunity_note`), F-pass0-20
/// (`language_note`), F-pass0-28 (`creature-action.legendary_action_cost`) and
/// F-pass0-23 (a sense the SRD has no row for). Every fixture string below is a
/// real value from the pinned snapshot (`d4276c58`).
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer()
      // What `build_packs` wires per pack: third-party vocabulary is seeded
      // into the pack that needs it, never into the built-in schema (§2).
      ..tier0Seeder = ((slug, name) => seedTier0Row(pack, const Vocabulary.empty(),
          slug: slug, name: name, source: 'Test Doc'));
  });

  Fixture creature(String pk, String name, Map<String, dynamic> extra) =>
      <String, dynamic>{
        '_pk': pk,
        'name': name,
        'armor_class': 12,
        'hit_points': 10,
        'challenge_rating': 1.0,
        ...extra,
      };

  void run(List<Fixture> creatures,
          {List<Fixture> actions = const [],
          Map<String, String> v1Senses = const {}}) =>
      mapCreatures(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        creatures: creatures,
        actions: actions,
        attacks: const [],
        traits: const [],
        v1Senses: v1Senses,
      );

  Iterable<Map<String, dynamic>> rows() =>
      pack.entities.values.cast<Map<String, dynamic>>();

  Map<String, dynamic> attrs(String type, String name) => rows()
      .firstWhere((e) => e['type'] == type && e['name'] == name)['attributes']
          as Map<String, dynamic>;

  group('F-pass0-19 — the "nonmagical attacks" qualifier reaches the card', () {
    test('the source display sentence becomes the note', () {
      run([
        creature('c1', 'Adult Light Dragon', {
          'damage_resistances': ['bludgeoning', 'fire', 'piercing', 'slashing'],
          'damage_resistances_display':
              'fire; bludgeoning, piercing, and slashing from nonmagical attacks',
          'nonmagical_attack_resistance': true,
        }),
      ]);

      expect(attrs('monster', 'Adult Light Dragon')['resistance_note'],
          'fire; bludgeoning, piercing, and slashing from nonmagical attacks');
      // The typed list is untouched — the note qualifies it, it does not
      // replace it.
      expect(
          (attrs('monster', 'Adult Light Dragon')['resistance_refs'] as List)
              .length,
          4);
    });

    test('an unqualified resistance list writes no note', () {
      run([
        creature('c1', 'Acid Ant', {
          'damage_resistances': ['acid'],
          'damage_resistances_display': 'acid',
          'nonmagical_attack_resistance': false,
        }),
      ]);

      expect(attrs('monster', 'Acid Ant').containsKey('resistance_note'), isFalse);
    });

    test('the flag alone invents nothing when the sentence is empty', () {
      // 3 of the corpus's 514 flagged rows ship an empty display column.
      run([
        creature('c1', 'Alnaar', {
          'damage_resistances': ['bludgeoning'],
          'damage_resistances_display': '   ',
          'nonmagical_attack_resistance': true,
        }),
      ]);

      expect(attrs('monster', 'Alnaar').containsKey('resistance_note'), isFalse);
    });

    test('immunity uses its own flag and its own sentence', () {
      run([
        creature('c1', 'Alabaster Tree', {
          'damage_immunities': ['bludgeoning', 'piercing', 'slashing'],
          'damage_immunities_display':
              'bludgeoning, piercing, and slashing from nonmagical attacks',
          'nonmagical_attack_immunity': true,
          'damage_resistances': ['fire'],
          'damage_resistances_display': 'fire',
          'nonmagical_attack_resistance': false,
        }),
      ]);

      final a = attrs('monster', 'Alabaster Tree');
      expect(a['immunity_note'],
          'bludgeoning, piercing, and slashing from nonmagical attacks');
      expect(a.containsKey('resistance_note'), isFalse);
    });
  });

  group('F-pass0-20 — the language sentence reaches the card', () {
    test('an empty list and a full sentence gives the note', () {
      run([
        creature('c1', 'Boneless', {
          'languages': const [],
          'languages_desc': "understands Common but can't speak",
        }),
      ]);

      expect(attrs('monster', 'Boneless')['language_note'],
          "understands Common but can't speak");
    });

    test('prose the typed list already states writes nothing', () {
      run([
        creature('c1', 'Aquatic Ape', {
          'languages': const ['common', 'sylvan'],
          'languages_desc': 'Common, Sylvan',
        }),
      ]);

      expect(attrs('monster', 'Aquatic Ape').containsKey('language_note'),
          isFalse);
    });

    test('a language the list is missing brings the whole sentence', () {
      // Devil Shark's list is `[deep-speech]` while the prose names Aquan too.
      run([
        creature('c1', 'Devil Shark', {
          'languages': const ['deep speech'],
          'languages_desc': 'Aquan, Deep Speech, telepathy 120 ft.',
        }),
      ]);

      expect(attrs('monster', 'Devil Shark')['language_note'],
          'Aquan, Deep Speech, telepathy 120 ft.');
    });

    test('telepathy-only prose writes nothing — `telepathy_ft` carries it', () {
      run([
        creature('c1', 'Fate Eater', {
          'languages': const [],
          'languages_desc': 'telepathy 100 ft.',
          'telepathy_range': 100,
        }),
      ]);

      final a = attrs('monster', 'Fate Eater');
      expect(a.containsKey('language_note'), isFalse);
      expect(a['telepathy_ft'], 100);
    });

    test('the "-" placeholder is an absence, not a sentence', () {
      run([
        creature('c1', 'Acid Ant', {
          'languages': const [],
          'languages_desc': '-',
        }),
      ]);

      expect(attrs('monster', 'Acid Ant').containsKey('language_note'), isFalse);
    });
  });

  group('F-pass0-28 — a legendary action states what it costs', () {
    Fixture legendary(String pk, String parent, String name, {int? cost}) =>
        <String, dynamic>{
          '_pk': pk,
          'parent': parent,
          'name': name,
          'desc': 'The dragon makes one attack with its tail.',
          'action_type': 'LEGENDARY_ACTION',
          if (cost != null) 'legendary_action_cost': cost,
        };

    test('a cost above the default lands on the action card', () {
      run([
        creature('c1', 'Fallen Solar', const {})
      ], actions: [
        legendary('a1', 'c1', 'Tail Attack', cost: 2),
      ]);

      expect(attrs('creature-action', 'Tail Attack')['legendary_action_cost'], 2);
    });

    test('the default cost of 1 needs no field', () {
      run([
        creature('c1', 'Fallen Solar', const {})
      ], actions: [
        legendary('a1', 'c1', 'Detect', cost: 1),
        legendary('a2', 'c1', 'Wing Buffet'),
      ]);

      expect(attrs('creature-action', 'Detect')
          .containsKey('legendary_action_cost'), isFalse);
      expect(attrs('creature-action', 'Wing Buffet')
          .containsKey('legendary_action_cost'), isFalse);
    });

    test('a cost past the schema ceiling is clamped, not dropped', () {
      run([
        creature('c1', 'Jotun Giant', const {})
      ], actions: [
        legendary('a1', 'c1', 'Doom', cost: 9),
      ]);

      expect(attrs('creature-action', 'Doom')['legendary_action_cost'], 5);
    });
  });

  group('F-pass0-23 — a sense the SRD has no row for', () {
    String? senseName(Map<String, dynamic> a, int index) =>
        ((a['senses'] as List)[index] as Map)['sense_ref']?['name'] as String?;

    test('v2 sense columns ship a `sense_ref`, not a bare string', () {
      // The `rangedSenseList` widget reads `sense_ref`; a bare `sense` string
      // rendered as an empty picker on every monster card.
      run([
        creature('c1', 'Acid Ant', {'blindsight_range': 60}),
      ]);

      final a = attrs('monster', 'Acid Ant');
      expect(senseName(a, 0), 'Blindsight');
      expect(((a['senses'] as List)[0] as Map)['range_ft'], 60);
    });

    test('keensense becomes a pack-local sense entity, never a canon row', () {
      run([
        creature('c1', 'Ghoul', const {})
      ], v1Senses: {
        'ghoul': "keensense 60 ft. (can't sense beyond this radius)",
      });

      expect(senseName(attrs('monster', 'Ghoul'), 0), 'Keensense');
      // Seeded into the pack — the SRD vocabulary does not grow a keensense.
      expect(rows().where((e) => e['type'] == 'sense').single['name'],
          'Keensense');
    });

    test('a sense v2 already gave is not doubled by the prose', () {
      run([
        creature('c1', 'Blood Hag', {'blindsight_range': 30})
      ], v1Senses: {
        'blood hag': 'blindsight 30 ft., blood sense 90 ft., '
            'passive Perception 14',
      });

      final senses = attrs('monster', 'Blood Hag')['senses'] as List;
      expect(senses.length, 2);
      expect(senseName(attrs('monster', 'Blood Hag'), 1), 'Blood Sense');
      // Blindsight is canon, so only the third-party sense is seeded.
      expect(rows().where((e) => e['type'] == 'sense').single['name'],
          'Blood Sense');
    });

    test('an "or …" clause is a continuation, not a sense', () {
      run([
        creature('c1', 'Grimlock', const {})
      ], v1Senses: {
        'grimlock': 'blindsight 30 ft., or 10 ft. while deafened '
            '(blind beyond this radius), passive Perception 14',
      });

      expect(attrs('monster', 'Grimlock').containsKey('senses'), isFalse);
      expect(rows().where((e) => e['type'] == 'sense'), isEmpty);
    });

    test('a sense with no range is not published — a range is not guessable',
        () {
      run([
        creature('c1', 'Living Wick', const {})
      ], v1Senses: {
        'living wick': 'echolocation, passive Perception 10',
      });

      expect(attrs('monster', 'Living Wick').containsKey('senses'), isFalse);
    });
  });
}
