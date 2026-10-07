import 'package:dungeon_master_tool/application/providers/combat_provider.dart';
import 'package:dungeon_master_tool/application/providers/projection_provider.dart';
import 'package:dungeon_master_tool/domain/entities/projection/battle_map_snapshot.dart';
import 'package:dungeon_master_tool/domain/entities/projection/projection_item.dart';
import 'package:dungeon_master_tool/application/services/event_bus.dart';
import 'package:dungeon_master_tool/domain/entities/session.dart';
import 'package:dungeon_master_tool/presentation/screens/battle_map/battle_map_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Undo persists token positions; there is no encounter here to save into.
class _NoSaveCombat extends CombatNotifier {
  _NoSaveCombat()
    : super(
        () => {},
        () => throw UnimplementedError(),
        () => [],
        () => null,
        AppEventBus(),
        (_) async {},
        (_) async {},
        () => true,
      );

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
  test('re-dragging the same token continues the trail; undo steps back', () {
    final container = ProviderContainer(
      overrides: [combatProvider.overrideWith((_) => _NoSaveCombat())],
    );
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
    expect(n.lastMove!.stops, [0, 2]);
    expect(n.lastMove!.points.last, const Offset(100, 100));

    // A tap (no movement) on the same token leaves no stop.
    n.dragTokenMove(
      'a',
      const Offset(100, 100),
      from: const Offset(100, 100),
      radius: 25,
      color: Colors.red,
    );
    n.endTokenMove('a', const Offset(100, 100));
    expect(n.lastMove!.stops, [0, 2]);

    n.undoTokenMove();
    expect(n.state.tokenPositions['a'], const Offset(100, 0));
    expect(n.lastMove!.stops, [0]);
    n.undoTokenMove();
    expect(n.state.tokenPositions['a'], Offset.zero);
    expect(n.lastMove, isNull);
  });

  test('every moved token keeps its trail; undo takes back the most recent',
      () {
    final container = ProviderContainer(
      overrides: [combatProvider.overrideWith((_) => _NoSaveCombat())],
    );
    addTearDown(container.dispose);
    final sub = container.listen(battleMapProvider('e1'), (_, _) {});
    addTearDown(sub.close);
    final n = container.read(battleMapProvider('e1').notifier);

    void drag(String id, Offset from, Offset to) {
      n.dragTokenMove(id, to, from: from, radius: 25, color: Colors.red);
      n.moveToken(id, to);
      n.endTokenMove(id, to);
    }

    drag('a', Offset.zero, const Offset(100, 0));
    drag('b', const Offset(0, 50), const Offset(100, 50));
    drag('a', const Offset(100, 0), const Offset(200, 0));
    expect(n.tokenMoves.value.keys, ['b', 'a']);
    expect(n.tokenMoves.value['a']!.stops, [0, 2]);

    n.undoTokenMove();
    n.undoTokenMove();
    expect(n.state.tokenPositions['a'], Offset.zero);
    expect(n.tokenMoves.value.keys, ['b']);
    n.undoTokenMove();
    expect(n.state.tokenPositions['b'], const Offset(0, 50));
    expect(n.tokenMoves.value, isEmpty);
  });

  test(
    'a position-only encounter change moves just the tokens that moved',
    () async {
      final container = ProviderContainer(
        overrides: [combatProvider.overrideWith((_) => _NoSaveCombat())],
      );
      addTearDown(container.dispose);
      final sub = container.listen(battleMapProvider('e1'), (_, _) {});
      addTearDown(sub.close);
      final n = container.read(battleMapProvider('e1').notifier)
        ..trailStyle = (_) => (radius: 25, color: Colors.green);

      const enc = Encounter(
        id: 'e1',
        tokenPositions: {
          'a': {'x': 0.0, 'y': 0.0},
          'b': {'x': 50.0, 'y': 50.0},
        },
      );
      await n.syncFromEncounter(enc);
      // The DM is mid-drag on `a` while a player's move of `b` arrives.
      n.moveToken('a', const Offset(10, 10));
      await n.syncFromEncounter(
        enc.copyWith(
          tokenPositions: {
            'a': {'x': 0.0, 'y': 0.0},
            'b': {'x': 200.0, 'y': 50.0},
          },
        ),
      );
      expect(n.state.tokenPositions['b'], const Offset(200, 50));
      expect(n.state.tokenPositions['a'], const Offset(10, 10));
      // The player's move leaves a trail; undo takes it back to the start.
      expect(n.lastMove!.id, 'b');
      expect(n.lastMove!.points, const [
        Offset(50, 50),
        Offset(200, 50),
        Offset(200, 50),
      ]);

      // The DM's own move echoing back is no remote move.
      n.moveToken('a', const Offset(300, 300));
      await n.syncFromEncounter(
        enc.copyWith(
          tokenPositions: {
            'a': {'x': 300.0, 'y': 300.0},
            'b': {'x': 200.0, 'y': 50.0},
          },
        ),
      );
      expect(n.lastMove!.id, 'b');

      n.undoTokenMove();
      expect(n.state.tokenPositions['b'], const Offset(50, 50));
      expect(n.lastMove, isNull);
    },
  );

  test("a player's move follows every point they walked; their undo takes "
      'back one drag', () async {
    final container = ProviderContainer(
      overrides: [combatProvider.overrideWith((_) => _NoSaveCombat())],
    );
    addTearDown(container.dispose);
    final sub = container.listen(battleMapProvider('e1'), (_, _) {});
    addTearDown(sub.close);
    final n = container.read(battleMapProvider('e1').notifier)
      ..trailStyle = (_) => (radius: 25, color: Colors.green);
    await n.syncFromEncounter(
      const Encounter(
        id: 'e1',
        tokenPositions: {
          'b': {'x': 0.0, 'y': 0.0},
        },
      ),
    );

    // A quick circle-ish drag arriving as two calls.
    n.applyRemoteMove(
      'b',
      const Offset(40, 40),
      via: const [Offset(30, 0), Offset(40, 20), Offset(40, 40)],
      newLeg: true,
    );
    n.applyRemoteMove(
      'b',
      const Offset(0, 40),
      via: const [Offset(20, 45), Offset(0, 40)],
    );
    expect(n.lastMove!.points, const [
      Offset(0, 0),
      Offset(30, 0),
      Offset(40, 20),
      Offset(40, 40),
      Offset(20, 45),
      Offset(0, 40),
      Offset(0, 40),
    ]);
    expect(n.state.tokenPositions['b'], const Offset(0, 40));

    // Second drag.
    n.applyRemoteMove(
      'b',
      const Offset(0, 100),
      via: const [Offset(0, 100)],
      newLeg: true,
    );
    expect(n.lastMove!.stops, [0, 6]);

    n.undoRemoteMove('b', const Offset(-1, -1));
    expect(n.state.tokenPositions['b'], const Offset(0, 40));
    expect(n.lastMove!.stops, [0]);
    n.undoRemoteMove('b', const Offset(-1, -1));
    expect(n.state.tokenPositions['b'], Offset.zero);
    expect(n.lastMove, isNull);

    // No trail left: the player's own idea of the target is used.
    n.undoRemoteMove('b', const Offset(5, 5));
    expect(n.state.tokenPositions['b'], const Offset(5, 5));
  });

  test('the broadcast trail is simplified per drag; stops stay exact', () {
    // Drag 1: a straight line sampled 8 times, then drag 2: an L.
    final m = TokenMove(
      id: 'a',
      path: [
        for (var i = 0; i <= 8; i++) Offset(i * 12.5, 0), // 0..8
        const Offset(100, 0), // 9: drag 2 starts here
        const Offset(100, 50),
        const Offset(100, 100),
        const Offset(150, 100),
      ],
      stops: const [0, 9],
      current: const Offset(160.04, 100),
      radius: 25,
      color: const Color(0xFF4CAF50),
    );
    final t = trailSnapshotOf(m, gridSize: 50);
    expect(t.points, [0, 0, 100, 0, 100, 100, 150, 100, 160, 100]);
    expect(t.stops, [0, 1]);
    expect(t.colorHex, '#4caf50');
  });

  test("an owner's move reaches the players as trail + ack; while the DM "
      'drags, the ack still goes out', () async {
    final container = ProviderContainer(
      overrides: [combatProvider.overrideWith((_) => _NoSaveCombat())],
    );
    addTearDown(container.dispose);
    final sub = container.listen(battleMapProvider('e1'), (_, _) {});
    addTearDown(sub.close);
    container
        .read(projectionControllerProvider.notifier)
        .addItem(
          const BattleMapProjection(
            id: 'p',
            label: 'm',
            encounterId: 'e1',
            snapshot: BattleMapSnapshot(
              tokens: [
                TokenSnapshot(id: 'a', name: 'A', x: 300, y: 300),
                TokenSnapshot(id: 'b', name: 'B', x: 0, y: 0),
              ],
            ),
          ),
        );
    BattleMapSnapshot snap() =>
        (container.read(projectionControllerProvider).items.single
                as BattleMapProjection)
            .snapshot;
    final n = container.read(battleMapProvider('e1').notifier)
      ..trailStyle = (_) => (radius: 25, color: Colors.green);
    // Positions set directly: `init` would push the drawings, which read the
    // database-backed entity list.
    n
      ..moveToken('a', const Offset(300, 300))
      ..moveToken('b', Offset.zero);

    n.applyRemoteMove(
      'b',
      const Offset(50, 0),
      via: const [Offset(25, 0), Offset(50, 0)],
      newLeg: true,
      ack: const MoveAck(id: 'b', seq: 7),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(snap().trails.single.id, 'b');
    expect(snap().moveAck, const MoveAck(id: 'b', seq: 7));

    // The DM grabs another token; the owner's next move is still acked and
    // the trail on the players' screens is left as it was.
    n.dragTokenMove(
      'a',
      const Offset(320, 300),
      from: const Offset(300, 300),
      radius: 25,
      color: Colors.red,
    );
    final before = snap().trails;
    n.undoRemoteMove('b', Offset.zero, ack: const MoveAck(id: 'b', seq: 8));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(snap().moveAck!.seq, 8);
    expect(snap().trails, before);
  });
}
