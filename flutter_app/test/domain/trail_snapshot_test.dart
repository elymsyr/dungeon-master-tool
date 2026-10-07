import 'package:dungeon_master_tool/domain/entities/projection/battle_map_snapshot.dart';
import 'package:dungeon_master_tool/presentation/screens/player_window/player_window_state_provider.dart';
import 'package:dungeon_master_tool/domain/entities/projection/projection_item.dart';
import 'package:dungeon_master_tool/domain/entities/projection/projection_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trail = TrailSnapshot(
    id: 'c2',
    points: [0, 0, 50, 0, 50, 50],
    stops: [0, 1],
    colorHex: '#4caf50',
  );

  test('trails survive the snapshot JSON round trip', () {
    const snap = BattleMapSnapshot(trails: [trail]);
    final back = BattleMapSnapshot.fromJson(snap.toJson());
    expect(back.trails, [trail]);
    expect(
        BattleMapSnapshot.fromJson(const BattleMapSnapshot().toJson()).trails,
        isEmpty);
  });

  test('a malformed trail is dropped, bad stops filtered', () {
    expect(TrailSnapshot.tryParse({'i': 'a', 'p': [1, 2, 3]}), isNull);
    expect(TrailSnapshot.tryParse({'i': 'a', 'p': [1, 2]}), isNull);
    expect(TrailSnapshot.tryParse({'p': [1, 2, 3, 4]}), isNull);
    expect(TrailSnapshot.tryParse('x'), isNull);
    final t = TrailSnapshot.tryParse({
      'i': 'a',
      'p': [1, 2, 3, 4],
      's': [0, 5, -1, 1],
    })!;
    expect(t.stops, [0, 1]);
    expect(TrailSnapshot.parseList([trail.toJson(), 'x', null]), [trail]);
    expect(TrailSnapshot.parseList('x'), isEmpty);
  });

  test('player window patch sets and clears the trails', () {
    final n = PlayerProjectionStateNotifier()
      ..state = const ProjectionState(items: [
        BattleMapProjection(id: 'p', label: 'm', encounterId: 'e'),
      ]);
    BattleMapSnapshot snap() =>
        (n.state.items.single as BattleMapProjection).snapshot;

    n.applyBattleMapPatch('p', {
      'trails': [trail.toJson()],
    });
    expect(snap().trails, [trail]);
    n.applyBattleMapPatch('p', {'turnIndex': 2});
    expect(snap().trails, [trail]);
    n.applyBattleMapPatch('p', {'trails': []});
    expect(snap().trails, isEmpty);
  });

  test('move ack survives JSON and patches; malformed is none', () {
    const ack = MoveAck(id: 'c2', seq: 1759750000000123);
    expect(
        BattleMapSnapshot.fromJson(const BattleMapSnapshot(moveAck: ack).toJson())
            .moveAck,
        ack);
    expect(MoveAck.tryParse({'i': 'c2'}), isNull);
    expect(MoveAck.tryParse({'s': 3}), isNull);

    final n = PlayerProjectionStateNotifier()
      ..state = const ProjectionState(items: [
        BattleMapProjection(id: 'p', label: 'm', encounterId: 'e'),
      ]);
    n.applyBattleMapPatch('p', {'moveAck': ack.toJson()});
    n.applyBattleMapPatch('p', {'trails': []});
    expect((n.state.items.single as BattleMapProjection).snapshot.moveAck, ack);
  });
}
