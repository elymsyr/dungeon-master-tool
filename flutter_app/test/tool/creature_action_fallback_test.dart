import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/loaders.dart';
import '../../tool/open5e_import/mappers/monster.dart';
import '../../tool/open5e_import/normalize.dart';
import '../../tool/open5e_import/refgraph.dart';

/// **Audit phase B8 — the ACTION bucket upstream's v2 conversion dropped.**
///
/// Tome of Beasts 3 ships 309 `CreatureAction` rows for 397 creatures and
/// exactly **two** of them are `ACTION`, so 396 monsters render with an empty
/// Actions block. The audit's hypothesis was a mis-set enum; the snapshot says
/// otherwise — the BONUS_ACTION / REACTION / LEGENDARY_ACTION rows match v1's
/// `Monster.*_json` columns row for row (136 / 96 / 75), while v1 holds 1,373
/// actions v2 never converted. `mapCreatures` therefore backfills from v1.
///
/// **R2 / F-pass0-24 narrowed the test from the bucket to the row.** B8 only
/// filled a bucket v2 had left *entirely* empty, and that clause was the whole
/// safety argument — but it also silently dropped v1's extra rows wherever the
/// conversion was half-finished (11 actions on 10 creatures, Abaasy's three
/// among them). The safety argument survives because the discriminator is the
/// row's **text**: a name-union rule (add any v1 row whose name is absent)
/// would add ~2,000 rows, since v1 and v2 disagree about action *names* far
/// more than about which actions exist.
///
/// Fixture shapes below are the real ones from the pinned snapshot (`d4276c58`),
/// trimmed to the fields the mapper reads.
void main() {
  late PackBuilder pack;
  late Normalizer norm;

  setUp(() {
    pack = PackBuilder('test-pack');
    norm = Normalizer();
  });

  Fixture creature(String pk, String name) => <String, dynamic>{
        '_pk': pk,
        'name': name,
        'armor_class': 12,
        'hit_points': 10,
        'hit_dice': '2d8',
        'challenge_rating': 1.0,
      };

  Fixture action(String pk, String parent, String name, String type,
          {String desc = 'It hits the target for some damage.'}) =>
      <String, dynamic>{
        '_pk': pk,
        'parent': parent,
        'name': name,
        'desc': desc,
        'action_type': type,
      };

  Map<String, String> v1Row(String name, String desc) =>
      {'name': name, 'desc': desc};

  void run({
    required List<Fixture> creatures,
    List<Fixture> actions = const [],
    V1ActionIndex v1Actions = const {},
  }) =>
      mapCreatures(
        pack: pack,
        norm: norm,
        source: 'Test Doc',
        creatures: creatures,
        actions: actions,
        attacks: const [],
        traits: const [],
        v1Actions: v1Actions,
      );

  /// `PackBuilder.entities` is keyed by uuid; the tests read it as a list.
  Iterable<Map<String, dynamic>> rows() =>
      pack.entities.values.cast<Map<String, dynamic>>();

  Map<String, dynamic> monster(String name) => rows()
      .firstWhere((e) => e['type'] == 'monster' && e['name'] == name);

  List<String> refNames(Map<String, dynamic> m, String key) => [
        for (final r in (m['attributes'][key] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          r['name'] as String,
      ];

  Map<String, dynamic> child(String name) => rows().firstWhere(
      (e) => e['type'] == 'creature-action' && e['name'] == name);

  test('an empty ACTION bucket is filled from v1', () {
    run(
      creatures: [creature('tob3_abaasy', 'Ahu-Nixta Mechanon')],
      actions: [
        action('a1', 'tob3_abaasy', 'Whirling Blades', 'BONUS_ACTION'),
      ],
      v1Actions: {
        'ahu-nixta mechanon': {
          'ACTION': [
            v1Row('Multiattack', 'Makes two Slam attacks.'),
            v1Row('Slam',
                'Melee Weapon Attack: +8 to hit, 5 ft., one target, 15 (2d10+4) bludgeoning damage.'),
          ],
        },
      },
    );

    final m = monster('Ahu-Nixta Mechanon');
    expect(refNames(m, 'action_refs'), ['Multiattack', 'Slam']);
    expect(refNames(m, 'bonus_action_refs'), ['Whirling Blades']);

    final slam = child('Slam');
    expect(slam['attributes']['action_type'], 'Action');
    expect(slam['attributes']['source'], 'Test Doc');
    // v1 has no CreatureActionAttack equivalent, so the structured attack
    // fields stay absent rather than being parsed back out of the prose — but
    // the row's own text says it is an attack, and since **R2 / F-pass0-25**
    // that is what `is_attack` reports.
    expect(slam['attributes']['is_attack'], true);
    expect(child('Multiattack')['attributes']['is_attack'], false);
    expect(slam['attributes'].containsKey('damage_dice'), isFalse);
    expect(slam['attributes'].containsKey('attack_bonus'), isFalse);
  });

  test('a half-converted bucket keeps v2 and gains v1\'s extra rows', () {
    // **R2 / F-pass0-24.** B8 tested the whole bucket: a creature with *any*
    // v2 action kept none of v1's. That measured the cost wrong — 11 actions on
    // 10 creatures across three documents were silently dropped, Abaasy's three
    // among them. The test is now per row and by text, so a v1 row the card
    // already carries is still not re-authored.
    run(
      creatures: [creature('tob3_abaasy', 'Abaasy')],
      actions: [
        action('a1', 'tob3_abaasy', 'Multiattack', 'ACTION',
            desc: 'The abaasy makes three melee attacks, only one of which '
                'can be a Shield Shove.'),
        action('a2', 'tob3_abaasy', 'Iron Axe', 'ACTION',
            desc: 'Melee Weapon Attack: +8 to hit, reach 10 ft., one target. '
                'Hit: 16 (2d10 + 5) slashing damage.'),
      ],
      v1Actions: {
        'abaasy': {
          'ACTION': [
            v1Row(
                'Multiattack',
                'The abaasy makes three melee attacks, only one of which '
                    'can be a Shield Shove.'),
            v1Row(
                'Iron Axe',
                'Melee Weapon Attack: +8 to hit, reach 10 ft., one target. '
                    'Hit: 16 (2d10 + 5) slashing damage.'),
            v1Row(
                'Spear',
                'Melee Weapon Attack: +8 to hit, reach 5 ft. or range 20/60 '
                    'ft., one target. Hit: 12 (2d6 + 5) piercing damage.'),
            v1Row(
                'Shield Shove',
                'The abaasy shoves its shield at one creature it can see '
                    'within 5 feet of it, pushing the target 10 feet away.'),
          ],
        },
      },
    );

    expect(refNames(monster('Abaasy'), 'action_refs'),
        ['Multiattack', 'Iron Axe', 'Spear', 'Shield Shove']);
    expect(
      rows().where((e) => e['type'] == 'creature-action').length,
      4,
      reason: "v1's copies of the two rows v2 did convert are not re-authored",
    );
  });

  test('a v1 row whose text the card already carries is not re-authored', () {
    // Same rule seen from the other side: matching is by text, not by name,
    // because v1 and v2 disagree about action *names* far more often than
    // about which actions exist (a name union would add ~2,000 rows).
    const shared =
        'The equitox moves up to its walking speed without provoking '
        'opportunity attacks.';
    run(
      creatures: [creature('c1', 'Equitox')],
      actions: [
        action('a1', 'c1', 'Prideful Prowl', 'LEGENDARY_ACTION', desc: shared),
      ],
      v1Actions: {
        'equitox': {
          'LEGENDARY_ACTION': [
            v1Row('Prowl', shared),
            v1Row('Trunk',
                'The equitox makes one trunk attack against a creature it '
                    'can see within 10 feet of it.'),
          ],
        },
      },
    );

    expect(
      refNames(monster('Equitox'), 'legendary_action_refs'),
      ['Prideful Prowl', 'Trunk'],
      reason: 'the row v2 already carries is matched by its text, under a '
          'different name; the row v2 never converted is recovered',
    );
  });

  test('the v1 join uses the raw upstream name, not the cleaned one', () {
    // The pack ships "Apostle"; v1 keys the same monster "Npc: Apostle". 15 of
    // tob3's monsters are only reachable this way.
    run(
      creatures: [creature('c1', 'Npc: Apostle')],
      v1Actions: {
        'npc: apostle': {
          'ACTION': [v1Row('Sacred Flame', 'The target must make a save.')],
        },
      },
    );

    final m = monster('Apostle');
    expect(refNames(m, 'action_refs'), ['Sacred Flame']);
  });

  test('recovered rows share the content dedup and the name-slot rules', () {
    run(
      creatures: [
        creature('c1', 'Brownie Beastrider'),
        creature('c2', 'Dokkaebi'),
        creature('c3', 'Peri'),
      ],
      v1Actions: {
        'brownie beastrider': {
          'ACTION': [v1Row('Invisibility', 'Magically turns invisible.')],
        },
        'dokkaebi': {
          // Identical content → same entity, authored once.
          'ACTION': [v1Row('Invisibility', 'Magically turns invisible.')],
        },
        'peri': {
          // Same name, different content → disambiguated with the creature.
          'ACTION': [v1Row('Invisibility', 'Turns invisible until it attacks.')],
        },
      },
    );

    expect(refNames(monster('Brownie Beastrider'), 'action_refs'),
        ['Invisibility']);
    expect(refNames(monster('Dokkaebi'), 'action_refs'), ['Invisibility']);
    expect(refNames(monster('Peri'), 'action_refs'), ['Invisibility (Peri)']);
    expect(
      rows().where((e) => e['type'] == 'creature-action').length,
      2,
    );
  });

  test('a junk v1 row is dropped by the same sanitizer, leaving no orphan ref',
      () {
    run(
      creatures: [creature('c1', 'Berberoka')],
      v1Actions: {
        'berberoka': {
          'ACTION': [
            v1Row('Slam', 'Melee Weapon Attack: +6 to hit.'),
            v1Row('The berberoka can take 3 legendary actions', 'Preamble.'),
          ],
        },
      },
    );

    expect(refNames(monster('Berberoka'), 'action_refs'), ['Slam']);
    expect(rows().where((e) => e['type'] == 'creature-action').length, 1);
  });

  test('with no v1 index the mapper behaves exactly as before', () {
    run(
      creatures: [creature('c1', 'Frog')],
      actions: const [],
    );

    final m = monster('Frog');
    expect(m['attributes']['action_refs'], isEmpty);
    expect(rows().where((e) => e['type'] == 'creature-action'), isEmpty);
  });

  test('every recovered ref resolves — nothing dangles', () {
    run(
      creatures: [creature('c1', 'Equitox')],
      v1Actions: {
        'equitox': {
          'ACTION': [v1Row('Hooves', 'Melee Weapon Attack: +7 to hit.')],
          'BONUS_ACTION': [v1Row('Surging Sands', 'Takes the Dash action.')],
          'REACTION': [v1Row('Parry', 'Adds 3 to its AC.')],
          'LEGENDARY_ACTION': [v1Row('Trunk', 'Makes one Trunk attack.')],
        },
      },
    );

    expect(pack.resolveRefs(), isEmpty);
    final m = monster('Equitox');
    expect(child('Surging Sands')['attributes']['action_type'], 'Bonus Action');
    expect(child('Parry')['attributes']['action_type'], 'Reaction');
    expect(child('Trunk')['attributes']['action_type'], 'Legendary Action');
    expect(m['attributes']['legendary_action_uses'], 3);
  });
}
