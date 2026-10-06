import 'package:dungeon_master_tool/application/providers/combat_provider.dart';
import 'package:dungeon_master_tool/application/services/event_bus.dart';
import 'package:dungeon_master_tool/domain/entities/session.dart';
import 'package:dungeon_master_tool/presentation/screens/battle_map/battle_map_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Undo persists token positions; there is no encounter here to save into.
class _NoSaveCombat extends CombatNotifier {
  _NoSaveCombat()
      : super(() => {}, () => throw UnimplementedError(), () => [],
            () => null, AppEventBus(), (_) async {}, (_) async {}, () => true);

  @override
  void saveMapData({
    required String encounterId,
    String? mapPath,
    Map<String, dynamic>? tokenPositions,
    Map<String, double>? tokenSizeMultipliers,
    int? tokenSize,
    List<String>? hiddenTokenIds,
  }) {}
}

void main() {
  test('re-dragging the same token continues the trail; undo steps back',
      () {
    final container = ProviderContainer(
        overrides: [combatProvider.overrideWith((_) => _NoSaveCombat())]);
    addTearDown(container.dispose);
    final sub = container.listen(battleMapProvider('e1'), (_, _) {});
    addTearDown(sub.close);
    final n = container.read(battleMapProvider('e1').notifier);

    void drag(Offset from, Offset to) {
      n.dragTokenMove('a', to, from: from, radius: 25, color: Colors.red);
      n.moveToken('a', to);
      n.endTokenMove('a', to);
    }

    drag(const Offset(0, 0), const Offset(100, 0));
    drag(const Offset(100, 0), const Offset(100, 100));
    expect(n.tokenMove.value!.stops, [0, 2]);
    expect(n.tokenMove.value!.points.last, const Offset(100, 100));

    // A tap (no movement) on the same token leaves no stop.
    n.dragTokenMove('a', const Offset(100, 100),
        from: const Offset(100, 100), radius: 25, color: Colors.red);
    n.endTokenMove('a', const Offset(100, 100));
    expect(n.tokenMove.value!.stops, [0, 2]);

    n.undoTokenMove();
    expect(n.state.tokenPositions['a'], const Offset(100, 0));
    expect(n.tokenMove.value!.stops, [0]);
    n.undoTokenMove();
    expect(n.state.tokenPositions['a'], Offset.zero);
    expect(n.tokenMove.value, isNull);
  });

  test('a position-only encounter change moves just the tokens that moved',
      () async {
    final container = ProviderContainer(
        overrides: [combatProvider.overrideWith((_) => _NoSaveCombat())]);
    addTearDown(container.dispose);
    final sub = container.listen(battleMapProvider('e1'), (_, _) {});
    addTearDown(sub.close);
    final n = container.read(battleMapProvider('e1').notifier);

    const enc = Encounter(id: 'e1', tokenPositions: {
      'a': {'x': 0.0, 'y': 0.0},
      'b': {'x': 50.0, 'y': 50.0},
    });
    await n.syncFromEncounter(enc);
    // The DM is mid-drag on `a` while a player's move of `b` arrives.
    n.moveToken('a', const Offset(10, 10));
    await n.syncFromEncounter(enc.copyWith(tokenPositions: {
      'a': {'x': 0.0, 'y': 0.0},
      'b': {'x': 200.0, 'y': 50.0},
    }));
    expect(n.state.tokenPositions['b'], const Offset(200, 50));
    expect(n.state.tokenPositions['a'], const Offset(10, 10));
  });
}
