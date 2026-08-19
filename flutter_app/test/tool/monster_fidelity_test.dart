import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/monster.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Stage R phase R2 — the monster mapper stops speaking for the source.**
///
/// Eleven findings, one file. Each group below is one of them, and every
/// fixture string is a real value from the pinned snapshot (`d4276c58`): the
/// half-resolved escape, the 333-character truncation, the "chaotic evil"
/// column that never varies, the attack text with no attack row behind it.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  Fixture creature(String pk, String name, {String? alignment}) =>
      <String, dynamic>{
        '_pk': pk,
        'name': name,
        'armor_class': 12,
        'hit_points': 10,
        'challenge_rating': 1.0,
        ?'alignment': alignment,
      };

  Fixture action(String pk, String parent, String name,
          {String type = 'ACTION',
          String desc = 'It hits the target for some damage.',
          String? form}) =>
      <String, dynamic>{
        '_pk': pk,
        'parent': parent,
        'name': name,
        'desc': desc,
        'action_type': type,
        ?'limited_to_form': form,
      };

  Fixture attack(String parent,
          {String? damageType, String? extraType, String? extraDie}) =>
      <String, dynamic>{
        '_pk': '${parent}_atk',
        'parent': parent,
        'attack_type': 'WEAPON',
        'to_hit_mod': 5,
        'reach': 5,
        'damage_die_count': 2,
        'damage_die_type': 'D6',
        'damage_bonus': 3,
        ?'damage_type': damageType,
        ?'extra_damage_type': extraType,
        ?'extra_damage_die_type': extraDie,
      };

  void run({
    required List<Fixture> creatures,
    List<Fixture> actions = const [],
    List<Fixture> attacks = const [],
    List<Fixture> traits = const [],
    V1ActionIndex v1Actions = const {},
    Map<String, int> v1LegendaryUses = const {},
  }) =>
      mapCreatures(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        creatures: creatures,
        actions: actions,
        attacks: attacks,
        traits: traits,
        v1Actions: v1Actions,
        v1LegendaryUses: v1LegendaryUses,
      );

  Iterable<Map<String, dynamic>> rows() =>
      pack.entities.values.cast<Map<String, dynamic>>();

  Map<String, dynamic> named(String type, String name) =>
      rows().firstWhere((e) => e['type'] == type && e['name'] == name);

  List<String> refNames(Map<String, dynamic> m, String key) =>
      ((m['attributes'][key] as List?) ?? const [])
          .map((r) => (r as Map)['name'].toString())
          .toList();

  group('F-pass0-17 — the name is part of a child\'s identity', () {
    // Statblock attack text is formulaic: two different weapons with the same
    // to-hit and damage carry byte-identical prose. Merging on text alone made
    // one creature's "Mining Pick" render as another's "Bite".
    const shared = 'Melee Weapon Attack: +5 to hit, reach 5 ft., one target. '
        'Hit: 6 (1d6 + 3) piercing damage.';

    test('same text under different names stays two entities', () {
      run(
        creatures: [creature('c1', 'Elite Kobold'), creature('c2', 'Ahuizotl')],
        actions: [
          action('a1', 'c1', 'Mining Pick', desc: shared),
          action('a2', 'c2', 'Bite', desc: shared),
        ],
      );

      expect(refNames(named('monster', 'Elite Kobold'), 'action_refs'),
          ['Mining Pick']);
      expect(refNames(named('monster', 'Ahuizotl'), 'action_refs'), ['Bite']);
    });

    test('same text under the same name still merges', () {
      run(
        creatures: [creature('c1', 'Kobold A'), creature('c2', 'Kobold B')],
        actions: [
          action('a1', 'c1', 'Bite', desc: shared),
          action('a2', 'c2', 'Bite', desc: shared),
        ],
      );

      expect(rows().where((e) => e['type'] == 'creature-action').length, 1);
    });

    test('a use count that lives only in the name is not overwritten', () {
      // "Shadow Traveler" is worded identically at every frequency, so the
      // merge used to hand a once-a-day creature three uses.
      const traveler = 'The shadow fey magically teleports up to 30 feet to an '
          'unoccupied space it can see.';
      run(
        creatures: [creature('c1', 'Pattern Dancer'), creature('c2', 'Poisoner')],
        traits: [
          {'_pk': 't1', 'parent': 'c1', 'name': 'Shadow Traveler (1/Day)', 'desc': traveler},
          {'_pk': 't2', 'parent': 'c2', 'name': 'Shadow Traveler (4/Day)', 'desc': traveler},
        ],
      );

      expect(refNames(named('monster', 'Pattern Dancer'), 'trait_refs'),
          ['Shadow Traveler (1/Day)']);
      expect(refNames(named('monster', 'Poisoner'), 'trait_refs'),
          ['Shadow Traveler (4/Day)']);
    });
  });

  group('F-pass0-25 — is_attack reads the text, not the fixture layout', () {
    test('an attack row with no CreatureActionAttack is still an attack', () {
      run(
        creatures: [creature('c1', 'Ahu-Nixta')],
        actions: [
          action('a1', 'c1', 'Slam',
              desc: 'Melee Weapon Attack: +8 to hit, reach 5 ft., one target. '
                  'Hit: 15 (2d10 + 4) bludgeoning damage.'),
          action('a2', 'c1', 'Multiattack',
              desc: 'The mechanon makes two Slam attacks.'),
        ],
      );

      expect(named('creature-action', 'Slam')['attributes']['is_attack'], true);
      expect(named('creature-action', 'Multiattack')['attributes']['is_attack'],
          false);
    });

    test('a spell attack and a bolded opener both count', () {
      run(
        creatures: [creature('c1', 'Lich')],
        actions: [
          action('a1', 'c1', 'Artistic Flourish',
              desc: 'Melee Spell Attack: +9 to hit, reach 5 ft., one target.'),
          action('a2', 'c1', 'Bolt',
              desc: '**Ranged Weapon Attack:** +7 to hit, range 60 ft.'),
        ],
      );

      expect(named('creature-action', 'Artistic Flourish')['attributes']
          ['is_attack'], true);
      expect(named('creature-action', 'Bolt')['attributes']['is_attack'], true);
    });
  });

  group('F-pass0-18 — the primary damage type in the extra column', () {
    test('an empty extra die means the extra type is the primary one', () {
      run(
        creatures: [creature('c1', 'Aatxe')],
        actions: [action('a1', 'c1', 'Gore')],
        attacks: [attack('a1', extraType: 'piercing')],
      );

      expect(named('creature-action', 'Gore')['attributes']['damage_type_ref'],
          isNotNull);
    });

    test('a filled extra die means it is genuine second damage, not the type',
        () {
      run(
        creatures: [creature('c1', 'Serpent')],
        actions: [action('a1', 'c1', 'Bite')],
        attacks: [attack('a1', extraType: 'acid', extraDie: 'D4')],
      );

      expect(
          named('creature-action', 'Bite')['attributes']
              .containsKey('damage_type_ref'),
          isFalse);
    });

    test('the real damage_type column still wins', () {
      run(
        creatures: [creature('c1', 'Guard')],
        actions: [action('a1', 'c1', 'Spear')],
        attacks: [attack('a1', damageType: 'slashing', extraType: 'acid')],
      );

      expect(
          (named('creature-action', 'Spear')['attributes']['damage_type_ref']
              as Map)['name'],
          'Slashing');
    });
  });

  group('F-pass0-21 — the form qualifier reaches the card', () {
    test('the column becomes the prefix upstream itself uses', () {
      run(
        creatures: [creature('c1', 'Aniwye')],
        actions: [
          action('a1', 'c1', 'Rock',
              desc: 'Ranged Weapon Attack: +7 to hit, range 60/240 ft.',
              form: 'Giant Form Only'),
        ],
      );

      expect(named('creature-action', 'Rock')['description'],
          startsWith('(Giant Form Only) Ranged Weapon Attack'));
    });

    test('a qualifier already written into the prose is not doubled', () {
      run(
        creatures: [creature('c1', 'Aniwye')],
        actions: [
          action('a1', 'c1', 'Deadly Musk',
              desc: '(Skunk Form Only) The aniwye releases a cloud of musk.',
              form: 'Skunk Form Only'),
        ],
      );

      expect(named('creature-action', 'Deadly Musk')['description'],
          startsWith('(Skunk Form Only) The aniwye'));
    });
  });

  group('F-pass0-22 — a legendary action is not also an at-will action', () {
    const drain = 'The aboleth drains the mind of one creature it can see '
        'within 30 feet of it.';

    test('the "(Costs N Actions)" copy is dropped', () {
      run(
        creatures: [creature('c1', 'Aboleth, Nihilith')],
        actions: [
          action('a1', 'c1', 'Psychic Drain', type: 'LEGENDARY_ACTION',
              desc: drain),
          action('a2', 'c1', 'Psychic Drain (Costs 2 Actions)', desc: drain),
          action('a3', 'c1', 'Tentacle',
              desc: 'Melee Weapon Attack: +9 to hit, reach 10 ft.'),
        ],
      );

      final m = named('monster', 'Aboleth, Nihilith');
      expect(refNames(m, 'action_refs'), ['Tentacle']);
      expect(refNames(m, 'legendary_action_refs'), ['Psychic Drain']);
    });

    test('a costed action with no legendary twin is kept', () {
      run(
        creatures: [creature('c1', 'Aboleth')],
        actions: [
          action('a1', 'c1', 'Sweep (Costs 2 Actions)',
              desc: 'The aboleth sweeps its tail through the water.'),
        ],
      );

      expect(refNames(named('monster', 'Aboleth'), 'action_refs'),
          ['Sweep (Costs 2 Actions)']);
    });
  });

  group('F-pass0-26 — a column collapsed to one value states nothing', () {
    List<Fixture> herd(String alignment, int n) => [
          for (var i = 0; i < n; i++)
            creature('c$i', 'Creature $i', alignment: alignment),
        ];

    test('one value across a whole document is not written', () {
      run(creatures: herd('chaotic evil', 25));
      expect(named('monster', 'Creature 0')['attributes']
          .containsKey('alignment_ref'), isFalse);
    });

    test('a document that varies is written as before', () {
      run(creatures: [
        ...herd('chaotic evil', 24),
        creature('cx', 'Unicorn', alignment: 'lawful good'),
      ]);
      expect(
          (named('monster', 'Unicorn')['attributes']['alignment_ref']
              as Map)['name'],
          'Lawful Good');
    });

    test('a small document is not judged collapsed', () {
      run(creatures: herd('chaotic evil', 5));
      expect(named('monster', 'Creature 0')['attributes']['alignment_ref'],
          isNotNull);
    });
  });

  group('F-tob-01 — the legendary action count comes from v1 prose', () {
    void jotun({Map<String, int> uses = const {}}) => run(
          creatures: [creature('c1', 'Jotun Giant')],
          actions: [
            action('a1', 'c1', 'Stomp', type: 'LEGENDARY_ACTION'),
          ],
          v1LegendaryUses: uses,
        );

    test('"can take 1 legendary action" is 1, not the SRD default', () {
      jotun(uses: {'jotun giant': 1});
      expect(named('monster', 'Jotun Giant')['attributes']
          ['legendary_action_uses'], 1);
    });

    test('a source that states no count keeps the SRD default of 3', () {
      jotun();
      expect(named('monster', 'Jotun Giant')['attributes']
          ['legendary_action_uses'], 3);
    });
  });

  group('F-tob-2023-01 — a truncated row is repaired from v1', () {
    const head = 'The hag targets one creature she can see within 60 feet of '
        'her. The target must succeed on a DC 17 Charisma saving throw or be '
        'cursed with one of the following effects of the hag\'s choice:';
    const full = '$head Disfigured. The target has disadvantage on Charisma '
        'checks. Sickly. The target has disadvantage on Constitution saving '
        'throws and regains only half the normal hit points from a long rest.';

    test('v1\'s longer copy of a truncated row wins', () {
      run(
        creatures: [creature('c1', 'Mirror Hag')],
        actions: [action('a1', 'c1', 'Reconfiguring Curse', desc: head)],
        v1Actions: {
          'mirror hag': {
            'ACTION': [
              {'name': 'Reconfiguring Curse', 'desc': full}
            ],
          },
        },
      );

      expect(named('creature-action', 'Reconfiguring Curse')['description'],
          full);
      expect(rows().where((e) => e['type'] == 'creature-action').length, 1,
          reason: 'the repair replaces the row, it does not add a second one');
    });

    test('a v1 row that is merely different never overwrites v2', () {
      run(
        creatures: [creature('c1', 'Mirror Hag')],
        actions: [action('a1', 'c1', 'Reconfiguring Curse', desc: full)],
        v1Actions: {
          'mirror hag': {
            'ACTION': [
              {'name': 'Reconfiguring Curse', 'desc': 'A wholly different and '
                  'much longer retelling of the curse that is not a prefix of '
                  'what version 2 of the source shipped for this same row.'}
            ],
          },
        },
      );

      expect(named('creature-action', 'Reconfiguring Curse')['description'],
          full);
    });
  });

  group('F-pass0-27 — the half-resolved unicode escape is repaired', () {
    test('the character the hex names is restored, in text and in the name',
        () {
      run(
        creatures: [creature('c1', 'Vættir')],
        actions: [
          {
            '_pk': 'a1',
            'parent': 'c1',
            'name': 'Væ00e6ttir\'s Greataxe',
            'desc': 'The væ00e6ttir swings, dealing 2æ00d7 damage to a '
                'collæ00e1is within reach of the attack it just made.',
            'action_type': 'ACTION',
          },
        ],
      );

      final axe = named('creature-action', 'Vættir\'s Greataxe');
      expect(axe['description'], contains('The vættir swings'));
      expect(axe['description'], contains('2× damage'));
      expect(axe['description'], contains('colláis'));
    });

    test('an ordinary number that happens to read like the residue is left be',
        () {
      run(
        creatures: [creature('c1', 'Giant')],
        actions: [
          action('a1', 'c1', 'Hurl',
              desc: 'The giant hurls a boulder 10000 feet.'),
        ],
      );

      expect(named('creature-action', 'Hurl')['description'],
          'The giant hurls a boulder 10000 feet.');
    });
  });

  group('F-a5e-mm-01 — a rule written into the name still reaches a card', () {
    test('an empty desc takes the sentence out of the name', () {
      run(
        creatures: [creature('c1', 'Behir')],
        actions: [
          action('a1', 'c1',
              'If a swallowed creature deals 30 or more damage to the behir '
                  'in a single turn, the behir vomits up the creature.',
              desc: ''),
        ],
      );

      final e = rows().firstWhere((r) => r['type'] == 'creature-action');
      expect(e['description'], startsWith('If a swallowed creature deals 30'));
      expect((e['name'] as String).length, lessThanOrEqualTo(49));
    });

    test('the "Label: rule" form keeps its label and gains its text', () {
      run(
        creatures: [creature('c1', 'Pixie')],
        actions: [
          action('a1', 'c1',
              'Luck: During the next 24 hours, the creature can reroll one '
                  'ability check, attack roll, or saving throw.',
              desc: ''),
        ],
      );

      expect(named('creature-action', 'Luck')['description'],
          startsWith('Luck: During the next 24 hours'));
    });

    test('a short title with no text is still dropped as spurious', () {
      run(
        creatures: [creature('c1', 'Ghost')],
        actions: [action('a1', 'c1', '1', desc: '')],
      );

      expect(rows().where((e) => e['type'] == 'creature-action'), isEmpty);
    });
  });
}
