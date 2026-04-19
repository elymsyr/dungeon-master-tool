import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_event.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/recording_encounter_hook.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordingEncounterHook', () {
    test('records events in emission order', () {
      final h = RecordingEncounterHook();
      h.on(const StartOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'a'));
      h.on(const EndOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'a'));
      expect(h.events.map((e) => e.runtimeType),
          [StartOfTurnEvent, EndOfTurnEvent]);
    });

    test('events list is unmodifiable', () {
      final h = RecordingEncounterHook();
      h.on(const StartOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'a'));
      expect(
        () => h.events.add(const EndOfTurnEvent(
            encounterId: 'e', round: 1, combatantId: 'a')),
        throwsUnsupportedError,
      );
    });

    test('of<T>() filters by event subtype', () {
      final h = RecordingEncounterHook();
      h.on(const StartOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'a'));
      h.on(const RoundAdvancedEvent(
          encounterId: 'e', round: 2, previousRound: 1));
      h.on(const StartOfTurnEvent(
          encounterId: 'e', round: 2, combatantId: 'b'));
      expect(h.of<StartOfTurnEvent>().map((e) => e.combatantId),
          ['a', 'b']);
      expect(h.of<RoundAdvancedEvent>(), hasLength(1));
    });

    test('clear empties the journal', () {
      final h = RecordingEncounterHook();
      h.on(const StartOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'a'));
      h.clear();
      expect(h.events, isEmpty);
    });
  });
}
