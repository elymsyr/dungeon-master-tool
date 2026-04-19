import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_event.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_hook.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingHook extends EncounterHook {
  int calls = 0;
  @override
  void on(EncounterEvent event) => calls++;
}

class _TurnOnlyHook extends EncounterHook {
  final starts = <String>[];
  @override
  void on(EncounterEvent event) {
    if (event is StartOfTurnEvent) starts.add(event.combatantId);
  }
}

void main() {
  group('EncounterHook / CompositeEncounterHook', () {
    test('base class on() is a no-op and can be instantiated via subclass',
        () {
      final h = _CountingHook();
      h.on(const StartOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'a'));
      expect(h.calls, 1);
    });

    test('empty composite drops events silently', () {
      const c = CompositeEncounterHook.empty();
      expect(
        () => c.on(const StartOfTurnEvent(
            encounterId: 'e', round: 1, combatantId: 'a')),
        returnsNormally,
      );
    });

    test('composite fans out to every delegate in order', () {
      final a = _CountingHook();
      final b = _CountingHook();
      final c = CompositeEncounterHook([a, b]);
      c.on(const StartOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'x'));
      c.on(const EndOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'y'));
      expect(a.calls, 2);
      expect(b.calls, 2);
    });

    test('subclass-filtered hook ignores non-matching events', () {
      final t = _TurnOnlyHook();
      t.on(const StartOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'a'));
      t.on(const EndOfTurnEvent(
          encounterId: 'e', round: 1, combatantId: 'a'));
      expect(t.starts, ['a']);
    });

    test('composite.hooks list is unmodifiable', () {
      final c = CompositeEncounterHook([_CountingHook()]);
      expect(() => c.hooks.add(_CountingHook()), throwsUnsupportedError);
    });
  });
}
