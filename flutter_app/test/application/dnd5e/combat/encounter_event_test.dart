import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncounterEvent variants', () {
    test('StartOfTurnEvent stores combatantId/round/encounterId', () {
      final e = StartOfTurnEvent(
        encounterId: 'e1',
        round: 2,
        combatantId: 'a',
      );
      expect(e.encounterId, 'e1');
      expect(e.round, 2);
      expect(e.combatantId, 'a');
      expect(e, isA<EncounterEvent>());
    });

    test('EndOfTurnEvent stores combatantId', () {
      final e = EndOfTurnEvent(
        encounterId: 'e1',
        round: 1,
        combatantId: 'b',
      );
      expect(e.combatantId, 'b');
    });

    test('RoundAdvancedEvent carries previousRound', () {
      final e = RoundAdvancedEvent(
        encounterId: 'e1',
        round: 3,
        previousRound: 2,
      );
      expect(e.previousRound, 2);
      expect(e.round, 3);
    });

    test('DamageDealtEvent carries pre/post HP snapshot', () {
      final e = DamageDealtEvent(
        encounterId: 'e1',
        round: 1,
        attackerId: 'a',
        targetId: 'b',
        damageTypeId: 'srd:slashing',
        amountAfterMitigation: 4,
        previousCurrentHp: 10,
        newCurrentHp: 6,
        dropsToZero: false,
        instantDeath: false,
      );
      expect(e.previousCurrentHp - e.newCurrentHp, 4);
      expect(e.dropsToZero, isFalse);
    });

    test('CombatantDroppedEvent flags instantDeath', () {
      final e = CombatantDroppedEvent(
        encounterId: 'e1',
        round: 1,
        combatantId: 'b',
        instantDeath: true,
      );
      expect(e.instantDeath, isTrue);
    });

    test('ConcentrationBrokenEvent allows null spellId', () {
      final e = ConcentrationBrokenEvent(
        encounterId: 'e1',
        round: 1,
        combatantId: 'a',
        spellId: null,
        dc: 12,
      );
      expect(e.spellId, isNull);
      expect(e.dc, 12);
    });

    test('ConditionAddedEvent allows null durationRounds (open-ended)', () {
      final e = ConditionAddedEvent(
        encounterId: 'e1',
        round: 1,
        combatantId: 'a',
        conditionId: 'srd:bless',
        durationRounds: null,
      );
      expect(e.durationRounds, isNull);
    });

    test('ConditionRemovedEvent / ConditionExpiredEvent are distinct types',
        () {
      const r = ConditionRemovedEvent(
        encounterId: 'e1',
        round: 1,
        combatantId: 'a',
        conditionId: 'srd:bless',
      );
      const x = ConditionExpiredEvent(
        encounterId: 'e1',
        round: 1,
        combatantId: 'a',
        conditionId: 'srd:bless',
      );
      expect(r, isA<EncounterEvent>());
      expect(x, isA<EncounterEvent>());
      expect(r.runtimeType == x.runtimeType, isFalse);
    });

    test('exhaustive switch covers all variants', () {
      String label(EncounterEvent e) => switch (e) {
            StartOfTurnEvent _ => 'start',
            EndOfTurnEvent _ => 'end',
            RoundAdvancedEvent _ => 'round',
            DamageDealtEvent _ => 'dmg',
            CombatantDroppedEvent _ => 'drop',
            ConcentrationBrokenEvent _ => 'conc',
            ConditionAddedEvent _ => 'cond+',
            ConditionRemovedEvent _ => 'cond-',
            ConditionExpiredEvent _ => 'cond_x',
          };
      expect(
        label(const StartOfTurnEvent(
            encounterId: 'e', round: 1, combatantId: 'a')),
        'start',
      );
    });
  });
}
