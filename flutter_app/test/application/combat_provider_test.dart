import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/providers/combat_provider.dart';
import 'package:dungeon_master_tool/application/services/event_bus.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/session.dart';
import 'package:dungeon_master_tool/domain/entities/schema/default_dnd5e_schema.dart';

CombatNotifier _createNotifier({
  Map<String, Entity> Function()? getEntities,
  Map<String, dynamic>? Function()? getCampaignData,
  AppEventBus? eventBus,
}) {
  return CombatNotifier(
    getEntities ?? () => <String, Entity>{},
    () => generateDefaultDnd5eSchema(),
    () {},
    getCampaignData ?? () => null,
    eventBus ?? AppEventBus(),
  );
}

/// Helper: access the notifier's current state.
// ignore: invalid_use_of_protected_member
CombatState _state(CombatNotifier n) => n.state;

/// Converts a session snapshot to pure JSON primitives, matching the
/// production path (`jsonDecode(jsonEncode(...))` in `_saveAndNotify`).
Map<String, dynamic> _toJsonPrimitives(Map<String, dynamic> snapshot) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(snapshot)) as Map);

void main() {
  // -----------------------------------------------------------------------
  // 1. CombatState defaults & activeEncounter getter
  // -----------------------------------------------------------------------
  group('CombatState', () {
    test('default values', () {
      const s = CombatState();
      expect(s.encounters, isEmpty);
      expect(s.activeEncounterId, isNull);
      expect(s.eventLog, isEmpty);
    });

    test('activeEncounter returns null when no activeEncounterId', () {
      const s = CombatState();
      expect(s.activeEncounter, isNull);
    });

    test('activeEncounter returns null when id does not match', () {
      final s = CombatState(
        encounters: const [Encounter(id: 'e1', name: 'Enc 1')],
        activeEncounterId: 'non-existent',
      );
      expect(s.activeEncounter, isNull);
    });

    test('activeEncounter returns the correct encounter', () {
      const enc1 = Encounter(id: 'e1', name: 'Enc 1');
      const enc2 = Encounter(id: 'e2', name: 'Enc 2');
      final s = CombatState(
        encounters: const [enc1, enc2],
        activeEncounterId: 'e2',
      );
      expect(s.activeEncounter, enc2);
    });

    test('copyWith replaces fields correctly', () {
      const s = CombatState();
      final s2 = s.copyWith(
        encounters: const [Encounter(id: 'e1', name: 'A')],
        activeEncounterId: 'e1',
        eventLog: const ['hello'],
      );
      expect(s2.encounters.length, 1);
      expect(s2.activeEncounterId, 'e1');
      expect(s2.eventLog, ['hello']);
    });
  });

  // -----------------------------------------------------------------------
  // 2. Encounter management
  // -----------------------------------------------------------------------
  group('Encounter management', () {
    test('createEncounter adds encounter and sets it active', () {
      final n = _createNotifier();
      n.createEncounter('Battle 1');

      final s = _state(n);
      expect(s.encounters, hasLength(1));
      expect(s.encounters.first.name, 'Battle 1');
      expect(s.activeEncounterId, s.encounters.first.id);
    });

    test('createEncounter multiple times keeps latest active', () {
      final n = _createNotifier();
      n.createEncounter('Enc A');
      n.createEncounter('Enc B');

      final s = _state(n);
      expect(s.encounters, hasLength(2));
      // The second encounter should be active.
      expect(s.activeEncounter!.name, 'Enc B');
    });

    test('renameEncounter updates the encounter name', () {
      final n = _createNotifier();
      n.createEncounter('Old Name');
      final id = _state(n).activeEncounter!.id;

      n.renameEncounter(id, 'Shiny New Name');

      expect(_state(n).activeEncounter!.name, 'Shiny New Name');
    });

    test('renameEncounter throws for unknown id', () {
      final n = _createNotifier();
      n.createEncounter('Existing');

      expect(
        () => n.renameEncounter('non-existent-id', 'Ghost'),
        throwsStateError,
      );
    });

    test('switchEncounter changes activeEncounterId', () {
      final n = _createNotifier();
      n.createEncounter('Enc A');
      n.createEncounter('Enc B');

      final idA = _state(n).encounters.first.id;
      n.switchEncounter(idA);
      expect(_state(n).activeEncounterId, idA);
    });

    test('deleteEncounter removes the encounter', () {
      final n = _createNotifier();
      n.createEncounter('Enc A');
      n.createEncounter('Enc B');

      final idA = _state(n).encounters[0].id;
      final idB = _state(n).encounters[1].id;

      n.deleteEncounter(idA);
      expect(_state(n).encounters, hasLength(1));
      expect(_state(n).encounters.first.id, idB);
    });

    test('deleteEncounter cannot delete the last encounter', () {
      final n = _createNotifier();
      n.createEncounter('Only');

      final id = _state(n).encounters.first.id;
      n.deleteEncounter(id);

      // Should still have the encounter.
      expect(_state(n).encounters, hasLength(1));
    });

    test('deleteEncounter switches active if deleted was active', () {
      final n = _createNotifier();
      n.createEncounter('Enc A');
      n.createEncounter('Enc B');

      final idB = _state(n).encounters[1].id;
      // B is active.
      expect(_state(n).activeEncounterId, idB);

      n.deleteEncounter(idB);
      // Should switch to remaining encounter.
      expect(_state(n).activeEncounterId, _state(n).encounters.first.id);
    });

    test('renameEncounter changes the encounter name', () {
      final n = _createNotifier();
      n.createEncounter('Old Name');

      final id = _state(n).encounters.first.id;
      n.renameEncounter(id, 'New Name');

      expect(_state(n).encounters.first.name, 'New Name');
    });
  });

  // -----------------------------------------------------------------------
  // 3. Combatant management
  // -----------------------------------------------------------------------
  group('Combatant management', () {
    test('addDirectRow adds a combatant with default stats', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Goblin');

      final enc = _state(n).activeEncounter!;
      expect(enc.combatants, hasLength(1));

      final c = enc.combatants.first;
      expect(c.name, 'Goblin');
      expect(c.init, 0); // default when no initiative given
      expect(c.hp, 10); // default hp
      expect(c.maxHp, 10);
      expect(c.ac, 10); // default ac
    });

    test('addDirectRow with custom stats', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Dragon', stats: {
        'initiative': '15',
        'hp': '200',
        'max_hp': '200',
        'ac': '21',
      });

      final c = _state(n).activeEncounter!.combatants.first;
      expect(c.name, 'Dragon');
      expect(c.init, 15);
      expect(c.hp, 200);
      expect(c.maxHp, 200);
      expect(c.ac, 21);
    });

    test('addDirectRow does nothing when no active encounter', () {
      final n = _createNotifier();
      // No encounter created.
      n.addDirectRow('Ghost');
      expect(_state(n).encounters, isEmpty);
    });

    test('addDirectRow max_hp defaults to hp when not provided', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Orc', stats: {'hp': '30'});

      final c = _state(n).activeEncounter!.combatants.first;
      expect(c.hp, 30);
      expect(c.maxHp, 30);
    });

    test('addDirectRow sorts combatants by initiative descending', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Slow', stats: {'initiative': '5'});
      n.addDirectRow('Fast', stats: {'initiative': '20'});
      n.addDirectRow('Mid', stats: {'initiative': '12'});

      final combatants = _state(n).activeEncounter!.combatants;
      expect(combatants[0].name, 'Fast');
      expect(combatants[1].name, 'Mid');
      expect(combatants[2].name, 'Slow');
    });

    test('deleteCombatant removes a combatant by id', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Goblin A');
      n.addDirectRow('Goblin B');

      final combatants = _state(n).activeEncounter!.combatants;
      expect(combatants, hasLength(2));

      n.deleteCombatant(combatants.first.id);
      expect(_state(n).activeEncounter!.combatants, hasLength(1));
      expect(_state(n).activeEncounter!.combatants.first.id, combatants.last.id);
    });

    test('clearAll removes all combatants and resets turn state', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Goblin');
      n.addDirectRow('Orc');

      n.clearAll();

      final enc = _state(n).activeEncounter!;
      expect(enc.combatants, isEmpty);
      expect(enc.turnIndex, -1);
      expect(enc.round, 1);
    });
  });

  // -----------------------------------------------------------------------
  // 4. Turn management
  // -----------------------------------------------------------------------
  group('Turn management', () {
    test('nextTurn advances turn index', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('A', stats: {'initiative': '20'});
      n.addDirectRow('B', stats: {'initiative': '10'});

      // Initial turnIndex is -1.
      expect(_state(n).activeEncounter!.turnIndex, -1);

      n.nextTurn();
      expect(_state(n).activeEncounter!.turnIndex, 0);
      expect(_state(n).activeEncounter!.round, 1);

      n.nextTurn();
      expect(_state(n).activeEncounter!.turnIndex, 1);
      expect(_state(n).activeEncounter!.round, 1);
    });

    test('nextTurn wraps around and increments round', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('A', stats: {'initiative': '20'});
      n.addDirectRow('B', stats: {'initiative': '10'});

      n.nextTurn(); // index 0, round 1
      n.nextTurn(); // index 1, round 1
      n.nextTurn(); // wraps -> index 0, round 2

      final enc = _state(n).activeEncounter!;
      expect(enc.turnIndex, 0);
      expect(enc.round, 2);
    });

    test('nextTurn does nothing when no combatants', () {
      final n = _createNotifier();
      n.createEncounter('Empty');

      n.nextTurn();
      expect(_state(n).activeEncounter!.turnIndex, -1);
    });

    test('nextTurn decrements condition durations at round start', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Warrior', stats: {'initiative': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Poisoned', 3);

      // Conditions decrement at round boundary, not per-turn: with 1
      // combatant two nextTurn calls are needed to cross into round 2.
      n.nextTurn(); // -1 -> 0, still round 1, no decrement
      n.nextTurn(); // wraps to round 2, decrement 3 -> 2

      final conditions = _state(n).activeEncounter!.combatants.first.conditions;
      expect(conditions, hasLength(1));
      expect(conditions.first.duration, 2);
    });

    test('nextTurn removes expired conditions (duration reaches 0)', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Warrior', stats: {'initiative': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Stunned', 1);

      // Two nextTurn calls needed to cross round boundary with 1 combatant.
      n.nextTurn();
      n.nextTurn(); // 1 -> 0 -> removed

      final conditions = _state(n).activeEncounter!.combatants.first.conditions;
      expect(conditions, isEmpty);
    });

    test('nextTurn keeps conditions with null duration (permanent)', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Warrior', stats: {'initiative': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Charmed', null);

      n.nextTurn();
      n.nextTurn();
      n.nextTurn();

      final conditions = _state(n).activeEncounter!.combatants.first.conditions;
      expect(conditions, hasLength(1));
      expect(conditions.first.name, 'Charmed');
      expect(conditions.first.duration, isNull);
    });
  });

  // -----------------------------------------------------------------------
  // 5. HP modification
  // -----------------------------------------------------------------------
  group('HP modification', () {
    test('modifyHp applies damage (negative delta)', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Tank', stats: {'hp': '50', 'max_hp': '50'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.modifyHp(cId, -15);

      expect(_state(n).activeEncounter!.combatants.first.hp, 35);
    });

    test('modifyHp applies healing (positive delta)', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Tank', stats: {'hp': '30', 'max_hp': '50'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.modifyHp(cId, 10);

      expect(_state(n).activeEncounter!.combatants.first.hp, 40);
    });

    test('modifyHp clamps to 0 (no negative hp)', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Fragile', stats: {'hp': '5', 'max_hp': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.modifyHp(cId, -100);

      expect(_state(n).activeEncounter!.combatants.first.hp, 0);
    });

    test('modifyHp clamps to maxHp (no overheal)', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Cleric', stats: {'hp': '40', 'max_hp': '50'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.modifyHp(cId, 100);

      expect(_state(n).activeEncounter!.combatants.first.hp, 50);
    });

    test('modifyHp with zero delta leaves hp unchanged', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Bard', stats: {'hp': '25', 'max_hp': '30'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.modifyHp(cId, 0);

      expect(_state(n).activeEncounter!.combatants.first.hp, 25);
    });
  });

  // -----------------------------------------------------------------------
  // 6. Conditions
  // -----------------------------------------------------------------------
  group('Conditions', () {
    test('addCondition with duration', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Fighter', stats: {'initiative': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Paralyzed', 5);

      final conds = _state(n).activeEncounter!.combatants.first.conditions;
      expect(conds, hasLength(1));
      expect(conds.first.name, 'Paralyzed');
      expect(conds.first.duration, 5);
    });

    test('addCondition without duration (permanent)', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Fighter', stats: {'initiative': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Frightened', null);

      final conds = _state(n).activeEncounter!.combatants.first.conditions;
      expect(conds, hasLength(1));
      expect(conds.first.name, 'Frightened');
      expect(conds.first.duration, isNull);
    });

    test('addCondition accumulates multiple conditions', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Fighter', stats: {'initiative': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Poisoned', 3);
      n.addCondition(cId, 'Blinded', 2);

      final conds = _state(n).activeEncounter!.combatants.first.conditions;
      expect(conds, hasLength(2));
      expect(conds.map((c) => c.name), containsAll(['Poisoned', 'Blinded']));
    });

    test('removeCondition removes a condition by name', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Fighter', stats: {'initiative': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Poisoned', 3);
      n.addCondition(cId, 'Blinded', 2);

      n.removeCondition(cId, 'Poisoned');

      final conds = _state(n).activeEncounter!.combatants.first.conditions;
      expect(conds, hasLength(1));
      expect(conds.first.name, 'Blinded');
    });

    test('removeCondition is no-op when condition not present', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Fighter', stats: {'initiative': '10'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Poisoned', 3);

      n.removeCondition(cId, 'Stunned'); // not present

      final conds = _state(n).activeEncounter!.combatants.first.conditions;
      expect(conds, hasLength(1));
      expect(conds.first.name, 'Poisoned');
    });
  });

  // -----------------------------------------------------------------------
  // 7. Serialization (getSessionState / loadSessionState roundtrip)
  // -----------------------------------------------------------------------
  group('Serialization', () {
    test('getSessionState returns expected structure', () {
      final n = _createNotifier();
      n.createEncounter('Roundtrip');
      n.addDirectRow('Orc', stats: {'initiative': '12', 'hp': '45', 'max_hp': '45', 'ac': '13'});

      final json = n.getSessionState();
      expect(json, containsPair('encounters', isA<List>()));
      expect(json, containsPair('active_encounter_id', isA<String>()));
      expect(json, containsPair('event_log', isA<List>()));

      final encList = json['encounters'] as List;
      expect(encList, hasLength(1));
    });

    test('loadSessionState / getSessionState roundtrip', () {
      final n1 = _createNotifier();
      n1.createEncounter('Battle 1');
      n1.addDirectRow('Hero', stats: {'initiative': '18', 'hp': '100', 'max_hp': '100', 'ac': '16'});
      n1.addDirectRow('Villain', stats: {'initiative': '14', 'hp': '80', 'max_hp': '80', 'ac': '15'});

      final cId = _state(n1).activeEncounter!.combatants.first.id;
      n1.addCondition(cId, 'Poisoned', 3);
      n1.modifyHp(cId, -20);
      // With 2 combatants, three nextTurn calls are needed to advance from
      // round 1 into round 2 (where conditions decrement).
      n1.nextTurn();
      n1.nextTurn();
      n1.nextTurn();

      final snapshot = _toJsonPrimitives(n1.getSessionState());

      // Load into a fresh notifier.
      final n2 = _createNotifier();
      n2.loadSessionState(snapshot);

      final s2 = _state(n2);
      expect(s2.encounters, hasLength(1));
      expect(s2.activeEncounter, isNotNull);
      expect(s2.activeEncounter!.name, 'Battle 1');
      expect(s2.activeEncounter!.combatants, hasLength(2));

      // Verify combatant details survived roundtrip.
      final hero = s2.activeEncounter!.combatants.firstWhere((c) => c.name == 'Hero');
      expect(hero.hp, 80); // 100 - 20
      expect(hero.maxHp, 100);
      expect(hero.conditions, hasLength(1));
      // After nextTurn, duration was decremented from 3 to 2.
      expect(hero.conditions.first.duration, 2);

      // Verify turn state.
      expect(s2.activeEncounter!.turnIndex, 0);
    });

    test('loadSessionState with empty data produces empty state', () {
      final n = _createNotifier();
      n.loadSessionState({});

      final s = _state(n);
      expect(s.encounters, isEmpty);
      expect(s.activeEncounterId, isNull);
      expect(s.eventLog, isEmpty);
    });

    test('loadSessionState restores event log', () {
      final n1 = _createNotifier();
      n1.createEncounter('Log Test');
      n1.addDirectRow('Goblin');

      final snapshot = _toJsonPrimitives(n1.getSessionState());

      final n2 = _createNotifier();
      n2.loadSessionState(snapshot);

      // Event log from n1 should be preserved.
      expect(_state(n2).eventLog, isNotEmpty);
      expect(_state(n2).eventLog, _state(n1).eventLog);
    });

    test('loadSessionState sets activeEncounterId to first if missing', () {
      final n1 = _createNotifier();
      n1.createEncounter('E1');
      n1.createEncounter('E2');

      final snapshot = _toJsonPrimitives(n1.getSessionState());
      // Remove the active_encounter_id to test fallback.
      snapshot.remove('active_encounter_id');

      final n2 = _createNotifier();
      n2.loadSessionState(snapshot);

      // Should default to the first encounter's id.
      expect(
        _state(n2).activeEncounterId,
        _state(n2).encounters.first.id,
      );
    });
  });

  // -----------------------------------------------------------------------
  // 8. Event log
  // -----------------------------------------------------------------------
  group('Event log', () {
    test('createEncounter logs a message', () {
      final n = _createNotifier();
      n.createEncounter('Ambush');

      expect(_state(n).eventLog, isNotEmpty);
      expect(_state(n).eventLog.last, contains('Ambush'));
    });

    test('addDirectRow logs a message with stats', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Goblin', stats: {'initiative': '5', 'hp': '7', 'ac': '13'});

      final log = _state(n).eventLog;
      expect(log.any((m) => m.contains('Goblin')), isTrue);
      expect(log.any((m) => m.contains('Init: 5')), isTrue);
    });

    test('modifyHp logs damage/heal', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Tank', stats: {'hp': '50', 'max_hp': '50'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.modifyHp(cId, -10);

      final log = _state(n).eventLog;
      expect(log.any((m) => m.contains('Tank') && m.contains('-10')), isTrue);
    });

    test('nextTurn logs turn info', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Alice', stats: {'initiative': '20'});
      n.addDirectRow('Bob', stats: {'initiative': '10'});

      n.nextTurn();

      final log = _state(n).eventLog;
      expect(log.any((m) => m.contains('Alice') && m.contains('turn')), isTrue);
    });

    test('nextTurn logs round change', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Solo', stats: {'initiative': '10'});

      n.nextTurn(); // index 0, round 1
      n.nextTurn(); // wraps -> index 0, round 2

      final log = _state(n).eventLog;
      expect(log.any((m) => m.contains('Round 2')), isTrue);
    });

    test('addCondition logs condition gain', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Rogue', stats: {'initiative': '15'});

      final cId = _state(n).activeEncounter!.combatants.first.id;
      n.addCondition(cId, 'Poisoned', 3);

      final log = _state(n).eventLog;
      expect(log.any((m) => m.contains('Rogue') && m.contains('Poisoned')), isTrue);
      expect(log.any((m) => m.contains('3 rounds')), isTrue);
    });

    test('clearAll logs a message', () {
      final n = _createNotifier();
      n.createEncounter('Fight');
      n.addDirectRow('Goblin');
      n.clearAll();

      final log = _state(n).eventLog;
      expect(log.any((m) => m.contains('cleared')), isTrue);
    });

    test('addLog appends custom message', () {
      final n = _createNotifier();
      n.addLog('Custom event happened');

      expect(_state(n).eventLog, contains('Custom event happened'));
    });
  });

  // -----------------------------------------------------------------------
  // Constructor / campaign data loading
  // -----------------------------------------------------------------------
  group('Constructor', () {
    test('loads combat state from campaign data on creation', () {
      // Prepare a snapshot to embed in campaign data.
      final seed = _createNotifier();
      seed.createEncounter('Preloaded');
      seed.addDirectRow('Troll', stats: {'initiative': '8', 'hp': '84', 'max_hp': '84', 'ac': '15'});
      final snapshot = _toJsonPrimitives(seed.getSessionState());

      final campaignData = <String, dynamic>{
        'combat_state': snapshot,
      };

      final n = _createNotifier(getCampaignData: () => campaignData);
      final s = _state(n);

      expect(s.encounters, hasLength(1));
      expect(s.activeEncounter!.name, 'Preloaded');
      expect(s.activeEncounter!.combatants, hasLength(1));
      expect(s.activeEncounter!.combatants.first.name, 'Troll');
    });

    test('handles null campaign data gracefully', () {
      final n = _createNotifier(getCampaignData: () => null);
      expect(_state(n).encounters, isEmpty);
    });

    test('handles campaign data without combat_state key', () {
      final n = _createNotifier(getCampaignData: () => <String, dynamic>{'other': 123});
      expect(_state(n).encounters, isEmpty);
    });
  });
}
