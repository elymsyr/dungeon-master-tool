import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/gate.dart';

/// **Audit phase T3 — the relational gate.**
///
/// This tool is the one that can *block a build*, so each rule gets a case that
/// provokes it and a companion case proving the healthy shape stays green. The
/// failure that matters is a rule that never fires: a gate everything passes
/// looks exactly like a corpus with no defects, and §3.5's 396 actionless
/// statblocks are what that looked like for a month.
void main() {
  Map<String, dynamic> monster(
    String name, {
    List<String> actions = const [],
    List<String> bonus = const [],
    List<String> traits = const [],
  }) =>
      {
        'name': name,
        'type': 'monster',
        'attributes': {
          'action_refs': actions,
          'bonus_action_refs': bonus,
          'trait_refs': traits,
        },
      };

  Map<String, dynamic> child(String name, [String type = 'creature-action']) =>
      {'name': name, 'type': type, 'attributes': <String, dynamic>{}};

  GateReport gate(Map<String, dynamic> entities, {Set<String>? builtin}) =>
      gatePacks({'test-pack': entities}, builtin ?? {nameKey('class', 'Fighter')});

  Set<String> rules(GateReport r) => r.violations.map((v) => v.rule).toSet();

  test('a statblock with children and resolving refs is green', () {
    final report = gate({
      'm1': monster('Aboleth', actions: ['a1'], traits: ['t1']),
      'a1': child('Tentacle'),
      't1': child('Amphibious', 'trait'),
    });
    expect(report.violations, isEmpty, reason: report.violations.join('\n'));
  });

  test('a monster with every action bucket empty fails', () {
    final report = gate({'m1': monster('Ahu-Nixta Mechanon')});
    expect(rules(report), contains('monster-actionless'));
  });

  test('a child row no statblock points at fails', () {
    final report = gate({
      'm1': monster('Aboleth', actions: ['a1']),
      'a1': child('Tentacle'),
      'a2': child('Enslave'),
    });
    final orphans =
        report.violations.where((v) => v.rule == 'orphan-child').toList();
    expect(orphans, hasLength(1));
    expect(orphans.single.subject, 'Enslave');
  });

  test('a uuid ref with no entity behind it fails', () {
    final report = gate({
      'm1': monster('Aboleth', actions: ['nope']),
    });
    expect(rules(report), contains('dangling-hard-ref'));
  });

  test('a soft ref resolves against the built-in index, or fails', () {
    final subclass = {
      'name': 'Arcane Warrior',
      'type': 'subclass',
      'attributes': {
        'parent_class_ref': {'slug': 'class', 'name': 'Fighter'},
      },
    };
    expect(gate({'s1': subclass}).violations, isEmpty);

    final missing = {
      'name': 'Ancient Dragons',
      'type': 'subclass',
      'attributes': {
        'parent_class_ref': {'slug': 'class', 'name': 'Warlock'},
      },
    };
    expect(rules(gate({'s1': missing})), contains('dangling-soft-ref'));
  });

  // The L0 hazard: `_ensureChild` mints "Scimitar (Firetamer)" and the runtime
  // strips exactly that qualifier on a miss, so a ref naming the qualified row
  // would land on the generic built-in card. Latent today — this is the alarm.
  test('a soft ref that only resolves after the qualifier strip fails', () {
    final report = gate({
      'm1': {
        'name': 'Firetamer',
        'type': 'monster',
        'attributes': {
          'action_refs': ['a1'],
          'granted_cantrip_refs': [
            {'slug': 'spell', 'name': 'Fire Bolt (Firetamer)'},
          ],
        },
      },
      'a1': child('Scimitar'),
    }, builtin: {nameKey('spell', 'Fire Bolt')});
    final hits =
        report.violations.where((v) => v.rule == 'qualifier-strip').toList();
    expect(hits, hasLength(1));
    expect(hits.single.detail, contains('"Fire Bolt"'));
  });

  test('an equipment option with no resolvable item fails', () {
    Map<String, dynamic> background(List<Map<String, dynamic>> items) => {
          'name': 'Charlatan',
          'type': 'background',
          'attributes': {
            'equipment_choice_groups': [
              {
                'group_id': 'bg-equipment',
                'options': [
                  {'option_id': 'A', 'items': items},
                ],
              },
            ],
          },
        };

    expect(
      gate({
        'b1': background([
          {'ref': 'i1', 'quantity': 1},
        ]),
        'i1': {'name': 'Fine Clothes', 'type': 'adventuring-gear'},
      }).violations,
      isEmpty,
    );

    expect(rules(gate({'b1': background(const [])})),
        contains('empty-equipment-option'));
  });

  test('a pack whose base action bucket is outnumbered fails', () {
    // tob3's shape: plenty of bonus actions, almost no plain ones.
    final entities = <String, dynamic>{};
    for (var i = 0; i < 25; i++) {
      entities['m$i'] = monster('Creature $i', bonus: ['b$i']);
      entities['b$i'] = child('Frightful Presence $i');
    }
    entities['m0'] = monster('Creature 0', actions: ['b0']);
    expect(rules(gate(entities)), contains('bucket-skew'));

    // The same pack with one plain action per monster is a normal distribution.
    final healthy = <String, dynamic>{};
    for (var i = 0; i < 25; i++) {
      healthy['m$i'] = monster('Creature $i', actions: ['a$i'], bonus: ['b$i']);
      healthy['a$i'] = child('Claw $i');
      healthy['b$i'] = child('Frightful Presence $i');
    }
    expect(rules(gate(healthy)), isNot(contains('bucket-skew')));
  });

  test('under the sample floor a lopsided bucket mix is not a finding', () {
    // `tdcs` ships 4 creatures; "the base bucket lost" means nothing there.
    final entities = <String, dynamic>{
      'm0': monster('Ashari', bonus: ['b0']),
      'b0': child('Windswept'),
    };
    expect(rules(gate(entities)), isNot(contains('bucket-skew')));
  });
}
