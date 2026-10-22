import 'package:dungeon_master_tool/application/providers/combat_provider.dart';
import 'package:dungeon_master_tool/application/services/event_bus.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-22T00:00:00Z';

/// ROADMAP Faz 9: a free world's encounter (DESIGN §14.3–§14.5).
void main() {
  final srd = copyAsFreeTemplate(
    generateBuiltinDnd5eV2Schema().schema,
    id: 'copy',
    name: 'SRD',
    now: _now,
  );

  const goblin = Entity(
    id: 'goblin',
    name: 'Goblin',
    categorySlug: 'monster',
    // `1d1+N` rolls N + 1: the test knows the result.
    fields: {
      'hp_average': 7,
      'ac': 15,
      'combat_stats': {'initiative': '1d1+1'},
    },
  );
  const prone = Entity(id: 'prone', name: 'Prone', categorySlug: 'condition');
  const aria = Character(
    id: 'c1',
    templateId: 'copy',
    templateName: 'SRD',
    entity: Entity(
      id: 'aria',
      name: 'Aria',
      categorySlug: 'player-character',
      fields: {
        'combat_stats': {'hp': 38, 'max_hp': 38, 'ac': 16, 'initiative': '1d1+3'},
      },
    ),
    createdAt: _now,
    updatedAt: _now,
  );

  late WorldSchema schema;
  late List<Character> saved;
  late Map<String, Entity> entities;

  CombatNotifier make() {
    final n = CombatNotifier(
      () => entities,
      () => schema,
      () => [aria],
      () => <String, dynamic>{},
      AppEventBus(),
      (_) async {},
      (c) async => saved.add(c),
      () => true,
    );
    n.createEncounter('E');
    return n;
  }

  // ignore: invalid_use_of_protected_member
  List<dynamic> rows(CombatNotifier n) => n.state.activeEncounter!.combatants;

  setUp(() {
    schema = srd;
    saved = [];
    entities = {'goblin': goblin, 'prone': prone, 'aria': aria.entity};
  });

  test('each Goblin keeps its own HP', () {
    final n = make();
    for (var i = 0; i < 3; i++) {
      n.addCombatantFromEntity('goblin');
    }
    final ids = [for (final c in rows(n)) c.id as String];
    expect(rows(n).map((c) => c.hp), [7, 7, 7]);
    n.modifyHp(ids[1], -3);
    expect(rows(n).map((c) => c.hp), [7, 4, 7]);
    expect(rows(n)[1].stats['ac'], 15);
  });

  test("a player's HP and numbers go back to the sheet's block", () {
    final n = make();
    n.addCombatantFromEntity('aria');
    final id = rows(n).single.id as String;
    n.modifyHp(id, -7);
    expect(saved.last.entity.fields['combat_stats'],
        containsPair('hp', 31));
    n.setStat(id, 'ac', '18');
    final block = saved.last.entity.fields['combat_stats'] as Map;
    expect(block['ac'], 18);
    // Only the block: no flat built-in keys.
    expect(saved.last.entity.fields.containsKey('hp'), isFalse);
  });

  test('roll initiative throws the Dice value as it is, sorts high first', () {
    final n = make();
    n.addCombatantFromEntity('goblin');
    n.addCombatantFromEntity('aria');
    n.rollInitiatives();
    expect(rows(n).map((c) => c.name), ['Aria', 'Goblin']);
    expect(rows(n).map((c) => c.init), [4, 2]);
  });

  test('low to high when the template says so', () {
    schema = srd.copyWith(
      encounterConfig: srd.encounterConfig.copyWith(sortDirection: 'asc'),
    );
    final n = make();
    n.addCombatantFromEntity('aria');
    n.addCombatantFromEntity('goblin');
    expect(rows(n).map((c) => c.name), ['Goblin', 'Aria']);
  });

  test('a dragged row moves; the turn stays with its combatant', () {
    final n = make();
    n.addCombatantFromEntity('aria');
    n.addCombatantFromEntity('goblin');
    n.nextTurn(); // Aria's turn
    n.reorderCombatant(0, 1);
    expect(rows(n).map((c) => c.name), ['Goblin', 'Aria']);
    // ignore: invalid_use_of_protected_member
    expect(n.state.activeEncounter!.turnIndex, 1);
  });

  test("the card's Conditions come along", () {
    entities['goblin'] = goblin.copyWith(fields: {
      ...goblin.fields,
      'combat_stats': {
        'initiative': '1d1+1',
        'conditions': ['prone'],
      },
    });
    final n = make();
    n.addCombatantFromEntity('goblin');
    expect(rows(n).single.conditions.single.name, 'Prone');
  });
}
