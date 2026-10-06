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
  });
}
