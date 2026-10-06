import 'dart:async';
import 'dart:ui' show Offset;

import 'package:dungeon_master_tool/application/providers/turn_control_provider.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/projection/battle_map_snapshot.dart';
import 'package:dungeon_master_tool/domain/entities/projection/projection_item.dart';
import 'package:dungeon_master_tool/domain/entities/projection/projection_output_mode.dart';
import 'package:dungeon_master_tool/domain/entities/projection/projection_state.dart';
import 'package:dungeon_master_tool/domain/entities/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

Character _char(String entityId, String? owner) => Character(
      id: 'ch-$entityId',
      templateId: 't',
      templateName: 't',
      entity: Entity(id: entityId, categorySlug: 'player'),
      ownerId: owner,
      createdAt: '',
      updatedAt: '',
    );

void main() {
  group('wantedTurnGrant', () {
    // Turn is on c2 (PC owned by "pl"); c1 is a monster.
    const enc = Encounter(
      id: 'enc',
      turnIndex: 1,
      round: 3,
      combatants: [
        Combatant(id: 'c1', name: 'Goblin', entityId: 'gob'),
        Combatant(id: 'c2', name: 'Aria', entityId: 'aria'),
      ],
    );
    const snap = BattleMapSnapshot(tokens: [
      TokenSnapshot(id: 'c1', name: 'Goblin', x: 10, y: 10),
      TokenSnapshot(id: 'c2', name: 'Aria', x: 100, y: 150),
    ]);
    ProjectionState proj({
      Set<ProjectionOutputMode> modes = const {ProjectionOutputMode.online},
      BattleMapSnapshot snapshot = snap,
    }) =>
        ProjectionState(
          items: [
            BattleMapProjection(
                id: 'p', label: 'm', encounterId: 'enc', snapshot: snapshot),
          ],
          activeItemId: 'p',
          outputModes: modes,
        );
    TurnGrant? want({
      ProjectionState? projection,
      Encounter encounter = enc,
      String? owner = 'pl',
    }) =>
        wantedTurnGrant(
          projection: projection ?? proj(),
          encounters: [encounter],
          characters: [_char('aria', owner)],
          worldId: 'w',
          dmUid: 'dm',
        );

    test('grants the owner of the active visible token, origin = token pos',
        () {
      final g = want()!;
      expect(g.combatantId, 'c2');
      expect(g.ownerId, 'pl');
      expect(g.origin, const Offset(100, 150));
    });

    test('nothing unless broadcast online', () {
      expect(
          want(projection: proj(modes: {ProjectionOutputMode.secondWindow})),
          isNull);
    });

    test('hidden token (absent from the snapshot) gets no grant', () {
      expect(
          want(
              projection: proj(
                  snapshot: const BattleMapSnapshot(tokens: [
            TokenSnapshot(id: 'c1', name: 'Goblin', x: 10, y: 10),
          ]))),
          isNull);
    });

    test('unclaimed or DM-owned character gets no grant', () {
      expect(want(owner: null), isNull);
      expect(want(owner: 'dm'), isNull);
    });

    test('monster turn gets no grant', () {
      expect(want(encounter: enc.copyWith(turnIndex: 0)), isNull);
    });

    test('a later turn of the same token is a new grant', () {
      expect(want(encounter: enc.copyWith(round: 4))!.key,
          isNot(want()!.key));
    });
  });

  group('TurnMoveSender', () {
    const grant = TurnGrant(
      worldId: 'w',
      encounterId: 'enc',
      combatantId: 'c2',
      ownerId: 'pl',
      origin: Offset.zero,
    );

    test('one call in flight; moves meanwhile collapse into the latest',
        () async {
      final calls = <Map<String, dynamic>>[];
      final pending = <Completer<Object?>>[];
      final sender = TurnMoveSender((p) {
        calls.add(p);
        final c = Completer<Object?>();
        pending.add(c);
        return c.future;
      }, onRejected: (_) {});

      sender.send(grant, const Offset(1, 1));
      sender.send(grant, const Offset(2, 2));
      sender.send(grant, const Offset(3, 3));
      expect(calls, hasLength(1));

      pending.first.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(calls, hasLength(2));
      expect(calls.last['p_x'], 3);
      pending.last.complete(true);
    });

    test('a rejected move reports the grant and drops queued moves',
        () async {
      final calls = <Map<String, dynamic>>[];
      TurnGrant? rejected;
      final first = Completer<Object?>();
      final sender = TurnMoveSender((p) {
        calls.add(p);
        return calls.length == 1 ? first.future : Future.value(true);
      }, onRejected: (g) => rejected = g);

      sender.send(grant, const Offset(1, 1));
      sender.send(grant, const Offset(2, 2));
      first.complete(false);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(rejected, same(grant));
      expect(calls, hasLength(1));
    });

    test('collapsed moves keep every point walked; a new drag and an undo '
        'go out on their own', () async {
      final calls = <Map<String, dynamic>>[];
      final pending = <Completer<Object?>>[];
      final sender = TurnMoveSender((p) {
        calls.add(p);
        final c = Completer<Object?>();
        pending.add(c);
        return c.future;
      }, onRejected: (_) {});

      sender.send(grant, const Offset(1, 1), newLeg: true);
      sender.send(grant, const Offset(2, 2), via: const [Offset(2, 2)]);
      sender.send(grant, const Offset(3, 3), via: const [Offset(3, 3)]);
      sender.send(grant, const Offset(9, 9), newLeg: true);
      sender.undo(grant, const Offset(3, 3));
      expect(calls, hasLength(1));
      expect(calls.first['p_kind'], TurnMoveKind.leg.index);
      expect(calls.first.containsKey('p_path'), isFalse);

      Future<void> next() async {
        pending.last.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      await next();
      expect(calls[1]['p_path'], [2.0, 2.0, 3.0, 3.0]);
      expect(calls[1]['p_x'], 3);
      expect(calls[1].containsKey('p_kind'), isFalse);
      await next();
      expect(calls[2]['p_kind'], TurnMoveKind.leg.index);
      expect(calls[2]['p_x'], 9);
      await next();
      expect(calls[3]['p_kind'], TurnMoveKind.undo.index);
      expect(calls[3]['p_x'], 3);
      pending.last.complete(true);
    });

    test('a server without migration 107 gets position-only calls', () async {
      final calls = <Map<String, dynamic>>[];
      final sender = TurnMoveSender((p) async {
        calls.add(p);
        if (p.containsKey('p_path') || p.containsKey('p_kind')) {
          throw const PostgrestException(message: 'no fn', code: 'PGRST202');
        }
        return true;
      }, onRejected: (_) {});

      sender.send(grant, const Offset(5, 5),
          via: const [Offset(4, 4)], newLeg: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, hasLength(2));
      expect(calls.last.keys,
          unorderedEquals(['p_world_id', 'p_combatant_id', 'p_x', 'p_y']));

      sender.send(grant, const Offset(6, 6), via: const [Offset(6, 6)]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(calls, hasLength(3));
      expect(calls.last.containsKey('p_path'), isFalse);
    });

    test('a path longer than the server cap is thinned, not cut', () async {
      final calls = <Map<String, dynamic>>[];
      final sender = TurnMoveSender((p) async {
        calls.add(p);
        return true;
      }, onRejected: (_) {});
      final via = [
        for (var i = 0; i < 1000; i++) Offset(i.toDouble(), 0),
      ];
      sender.send(grant, const Offset(999, 0), via: via);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final path = calls.single['p_path'] as List;
      expect(path.length ~/ 2, lessThanOrEqualTo(TurnMoveSender.maxPathPoints));
      expect(path.first, 0);
      expect(path[path.length - 2], greaterThan(900));
    });
  });

  group('parseTurnPath', () {
    test('flat pairs → points; anything malformed → none', () {
      expect(parseTurnPath([1, 2, 3.5, 4]),
          const [Offset(1, 2), Offset(3.5, 4)]);
      expect(parseTurnPath(null), isEmpty);
      expect(parseTurnPath([1, 2, 3]), isEmpty);
      expect(parseTurnPath([1, 'x']), isEmpty);
      expect(parseTurnPath('[1,2]'), isEmpty);
    });
  });
}
