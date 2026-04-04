import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/session.dart';

void main() {
  group('Encounter', () {
    test('creates with defaults', () {
      final enc = Encounter(id: 'enc-1', name: 'Test Encounter');
      expect(enc.id, 'enc-1');
      expect(enc.name, 'Test Encounter');
      expect(enc.combatants, isEmpty);
      expect(enc.round, 1);
      expect(enc.turnIndex, -1);
    });

    test('toJson / fromJson roundtrip', () {
      final enc = Encounter(
        id: 'enc-1',
        name: 'Boss Fight',
        round: 3,
        turnIndex: 2,
        combatants: [
          Combatant(
            id: 'c-1',
            name: 'Hero',
            init: 18,
            hp: 30,
            maxHp: 45,
            ac: 16,
          ),
        ],
      );
      // Use jsonEncode/jsonDecode for a true roundtrip (toJson nests Freezed objects)
      final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(enc.toJson())) as Map,
      );
      final restored = Encounter.fromJson(json);
      expect(restored.id, enc.id);
      expect(restored.name, enc.name);
      expect(restored.round, 3);
      expect(restored.turnIndex, 2);
      expect(restored.combatants.length, 1);
      expect(restored.combatants.first.name, 'Hero');
      expect(restored.combatants.first.init, 18);
    });
  });

  group('Combatant', () {
    test('creates with defaults', () {
      final c = Combatant(id: 'c-1', name: 'Fighter');
      expect(c.id, 'c-1');
      expect(c.name, 'Fighter');
      expect(c.hp, 10);
      expect(c.maxHp, 10);
      expect(c.ac, 10);
      expect(c.init, 0);
      expect(c.conditions, isEmpty);
    });

    test('copyWith modifies specific fields', () {
      final c = Combatant(id: 'c-1', name: 'Fighter', hp: 40, maxHp: 40);
      final damaged = c.copyWith(hp: 25);
      expect(damaged.hp, 25);
      expect(damaged.maxHp, 40);
      expect(damaged.name, 'Fighter');
    });

    test('conditions can be added', () {
      final c = Combatant(
        id: 'c-1',
        name: 'Fighter',
        conditions: [
          CombatCondition(name: 'Stunned', duration: 2),
          CombatCondition(name: 'Poisoned'),
        ],
      );
      expect(c.conditions.length, 2);
      expect(c.conditions.first.name, 'Stunned');
      expect(c.conditions.first.duration, 2);
      expect(c.conditions.last.name, 'Poisoned');
      expect(c.conditions.last.duration, isNull);
    });
  });

  group('CombatCondition', () {
    test('creates with defaults', () {
      final cond = CombatCondition(name: 'Blinded');
      expect(cond.name, 'Blinded');
      expect(cond.duration, isNull);
    });

    test('toJson / fromJson roundtrip', () {
      final cond = CombatCondition(name: 'Frightened', duration: 3);
      final json = cond.toJson();
      final restored = CombatCondition.fromJson(json);
      expect(restored.name, 'Frightened');
      expect(restored.duration, 3);
    });
  });

  group('Session', () {
    test('creates with defaults', () {
      final session = Session(id: 's-1', name: 'Session 1');
      expect(session.id, 's-1');
      expect(session.name, 'Session 1');
    });

    test('toJson / fromJson roundtrip', () {
      final session = Session(
        id: 's-1',
        name: 'Epic Battle',
        notes: 'The party entered the dungeon',
      );
      final json = session.toJson();
      final restored = Session.fromJson(json);
      expect(restored.id, session.id);
      expect(restored.name, session.name);
      expect(restored.notes, session.notes);
    });
  });
}
