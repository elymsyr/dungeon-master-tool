import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/projection/battle_map_snapshot.dart';
import '../../domain/entities/projection/projection_item.dart';
import '../../domain/entities/projection/projection_output_mode.dart';
import '../../domain/entities/projection/projection_state.dart';
import '../../domain/entities/session.dart';
import '../../presentation/screens/battle_map/battle_map_notifier.dart';
import '../services/world_sync_service.dart';
import 'auth_provider.dart';
import 'character_provider.dart';
import 'combat_provider.dart';
import 'projection_provider.dart';
import 'role_provider.dart';
import 'world_sync_provider.dart';

/// A player's permission to move their own token for one turn — the single
/// `world_turn_control` row of a world (migration 105).
///
/// The DM writes it when the turn of the encounter being broadcast online
/// reaches a character owned by a player; the player moves the token only
/// through `move_turn_token`, which the server checks against this row. The
/// DM applies the moves to the encounter and the regular broadcast carries
/// them to everyone.
class TurnGrant {
  final String worldId;
  final String encounterId;
  final String combatantId;
  final String ownerId;

  /// Where the token stood when the turn began — the player's undo target.
  final Offset origin;

  /// `round/turnIndex` — a new turn of the same combatant is a new grant.
  final String turn;

  const TurnGrant({
    required this.worldId,
    required this.encounterId,
    required this.combatantId,
    required this.ownerId,
    required this.origin,
    this.turn = '',
  });

  String get key => '$encounterId|$combatantId|$ownerId|$turn';

  Map<String, dynamic> toRow() => {
        'world_id': worldId,
        'encounter_id': encounterId,
        'combatant_id': combatantId,
        'owner_id': ownerId,
        'origin_x': origin.dx,
        'origin_y': origin.dy,
        'x': origin.dx,
        'y': origin.dy,
      };

  static TurnGrant? fromRow(Map<String, dynamic> row) {
    final ox = row['origin_x'], oy = row['origin_y'];
    final world = row['world_id'], enc = row['encounter_id'];
    final comb = row['combatant_id'], owner = row['owner_id'];
    if (ox is! num || oy is! num || world is! String || enc is! String ||
        comb is! String || owner is! String) {
      return null;
    }
    return TurnGrant(
      worldId: world,
      encounterId: enc,
      combatantId: comb,
      ownerId: owner,
      origin: Offset(ox.toDouble(), oy.toDouble()),
    );
  }
}

/// Player side: the grant for the open world while it is this user's turn,
/// else null. Fed by `WorldMirrorApplier` — the world-open seed and the
/// `world_turn_control` CDC (RLS shows a player only their own row).
final myTurnGrantProvider = StateProvider<TurnGrant?>((_) => null);

/// Player side: sends this turn's token position through `move_turn_token`.
final turnMoveSenderProvider = Provider<TurnMoveSender?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  final client = Supabase.instance.client;
  return TurnMoveSender(
    (params) => client.rpc('move_turn_token', params: params),
    onRejected: (g) {
      final n = ref.read(myTurnGrantProvider.notifier);
      if (identical(n.state, g)) n.state = null;
    },
  );
});

/// What a `move_turn_token` call means to the DM (migration 107 `p_kind`).
enum TurnMoveKind {
  /// The drag goes on.
  move,

  /// A new drag starts here — the DM's undo stops at its start.
  leg,

  /// Take back the last drag.
  undo,
}

class _TurnOp {
  _TurnOp(this.grant, this.pos, this.via, this.kind, this.seq);
  final TurnGrant grant;
  Offset pos;
  List<Offset> via;
  final TurnMoveKind kind;
  int seq;
}

/// One call in flight; moves arriving meanwhile collapse into the latest —
/// their paths joined, so the DM still gets every point walked — so a drag
/// never builds a queue: at most one write per round-trip, and no closer
/// than [_minGap]. A new drag or an undo is never folded into another call.
///
/// Every call carries an increasing `p_seq` (migration 108); the DM
/// acknowledges the last one it applied in `BattleMapSnapshot.moveAck`, which
/// tells the player when its optimistic state can give way to the DM's.
class TurnMoveSender {
  TurnMoveSender(this._rpc, {required this.onRejected});

  /// `move_turn_token` with the given params; resolves to its boolean.
  final Future<Object?> Function(Map<String, dynamic> params) _rpc;

  /// The server said the grant no longer holds (turn passed, DM revoked) —
  /// faster than waiting for the DELETE event.
  final void Function(TurnGrant grant) onRejected;

  static const _minGap = Duration(milliseconds: 100);

  /// Server cap on `p_path` points (migration 107).
  static const maxPathPoints = 400;

  final List<_TurnOp> _queue = [];
  bool _busy = false;

  /// What the server takes: 2 = migration 108 (`p_seq`), 1 = 107 (`p_path`,
  /// `p_kind`), 0 = 105 (position only). Lowered on a PGRST202.
  int _level = 2;

  /// Microseconds at start, so numbers keep growing across app restarts —
  /// the DM's ack of an earlier session never covers a new move.
  int _seq = DateTime.now().microsecondsSinceEpoch;

  /// [pos] is where the token is now; [via] the points walked since the last
  /// call, in order. Returns the move's number — acknowledged once
  /// `moveAck.seq` reaches it.
  int send(
    TurnGrant grant,
    Offset pos, {
    List<Offset> via = const [],
    bool newLeg = false,
  }) {
    final seq = ++_seq;
    final last = _queue.lastOrNull;
    if (!newLeg &&
        last != null &&
        last.kind != TurnMoveKind.undo &&
        identical(last.grant, grant)) {
      last
        ..pos = pos
        ..via = _cap([...last.via, ...via])
        ..seq = seq;
    } else {
      _queue.add(_TurnOp(grant, pos, _cap(via),
          newLeg ? TurnMoveKind.leg : TurnMoveKind.move, seq));
    }
    if (!_busy) unawaited(_pump());
    return seq;
  }

  /// Takes back the last drag; [target] is where it began. Returns the
  /// undo's number, like [send].
  int undo(TurnGrant grant, Offset target) {
    final seq = ++_seq;
    _queue.add(_TurnOp(grant, target, const [], TurnMoveKind.undo, seq));
    if (!_busy) unawaited(_pump());
    return seq;
  }

  /// Every other point until it fits — the shape survives, the payload stays
  /// under the server's cap.
  static List<Offset> _cap(List<Offset> via) {
    var out = via;
    while (out.length > maxPathPoints) {
      out = [for (var i = 0; i < out.length; i += 2) out[i]];
    }
    return out;
  }

  Map<String, dynamic> _params(_TurnOp op) => {
        'p_world_id': op.grant.worldId,
        'p_combatant_id': op.grant.combatantId,
        'p_x': op.pos.dx,
        'p_y': op.pos.dy,
        if (_level >= 1 && op.via.isNotEmpty)
          'p_path': [for (final p in op.via) ...[p.dx, p.dy]],
        if (_level >= 1 && op.kind != TurnMoveKind.move)
          'p_kind': op.kind.index,
        if (_level >= 2) 'p_seq': op.seq,
      };

  Future<void> _pump() async {
    _busy = true;
    try {
      while (_queue.isNotEmpty) {
        final op = _queue.removeAt(0);
        final sent = DateTime.now();
        try {
          Object? ok;
          while (true) {
            try {
              ok = await _rpc(_params(op));
              break;
            } on PostgrestException catch (e) {
              // PGRST202: no function with these params — the server lacks
              // migration 108 (or 107). Step down and retry.
              if (e.code != 'PGRST202' || _level == 0) rethrow;
              _level--;
            }
          }
          if (ok == false) {
            _queue.removeWhere((o) => identical(o.grant, op.grant));
            onRejected(op.grant);
          }
        } catch (e) {
          debugPrint('TurnMoveSender: $e');
        }
        final wait = _minGap - DateTime.now().difference(sent);
        if (_queue.isNotEmpty && wait > Duration.zero) {
          await Future.delayed(wait);
        }
      }
    } finally {
      _busy = false;
    }
  }
}

/// DM side, installed by the main screen: keeps the world's
/// `world_turn_control` row in step with the encounter being broadcast
/// online, and applies the owner's moves to it.
final dmTurnControlProvider = Provider<void>((ref) {
  if (!SupabaseConfig.isConfigured) return;
  final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
  final isDm = ref.watch(currentWorldRoleProvider).valueOrNull == WorldRole.dm;
  final uid = ref.watch(authProvider.select((a) => a?.uid));
  final sync = ref.watch(worldSyncServiceProvider);
  if (worldId == null || !isDm || uid == null || sync == null) return;

  final ctl = _DmTurnControl(Supabase.instance.client, worldId);

  void refresh() => ctl.update(wantedTurnGrant(
        projection: ref.read(projectionControllerProvider),
        encounters: ref.read(combatProvider).encounters,
        characters: ref.read(combatCharactersProvider),
        worldId: worldId,
        dmUid: uid,
      ));

  ref.listen(projectionControllerProvider, (_, _) => refresh());
  ref.listen(combatProvider, (_, _) => refresh());
  ref.listen(combatCharactersProvider, (_, _) => refresh());

  final sub = sync.events
      .where((e) => e.worldId == worldId && e.table == 'world_turn_control')
      .listen((e) => _applyMove(ref, ctl.granted, e));

  ref.onDispose(() {
    unawaited(sub.cancel());
    ctl.update(null);
  });
  refresh();
});

/// The grant the DM's current state calls for, or null: the battle map is
/// being broadcast online, and its encounter's turn is on a visible token
/// whose character a player (not the DM) owns.
TurnGrant? wantedTurnGrant({
  required ProjectionState projection,
  required List<Encounter> encounters,
  required List<Character> characters,
  required String worldId,
  required String dmUid,
}) {
  if (!projection.outputModes.contains(ProjectionOutputMode.online)) {
    return null;
  }
  final item = projection.activeItem;
  if (item is! BattleMapProjection) return null;
  final enc = encounters.where((e) => e.id == item.encounterId).firstOrNull;
  if (enc == null ||
      enc.turnIndex < 0 ||
      enc.turnIndex >= enc.combatants.length) {
    return null;
  }
  final c = enc.combatants[enc.turnIndex];
  // The snapshot leaves hidden tokens out — a token the players can't see
  // gets no grant.
  final token =
      item.snapshot.tokens.where((t) => t.id == c.id).firstOrNull;
  if (token == null || c.entityId == null) return null;
  final owner = characters
      .where((ch) => ch.entity.id == c.entityId)
      .firstOrNull
      ?.ownerId;
  if (owner == null || owner == dmUid) return null;
  return TurnGrant(
    worldId: worldId,
    encounterId: enc.id,
    combatantId: c.id,
    ownerId: owner,
    origin: Offset(token.x, token.y),
    turn: '${enc.round}/${enc.turnIndex}',
  );
}

/// An owner's move → the encounter. The server already checked who sent it;
/// this only drops moves of a grant the DM has since replaced. With the DM's
/// battle map open the move goes through its notifier, so the trail gets
/// every point the player walked and their undo takes back a whole drag.
void _applyMove(Ref ref, TurnGrant? granted, WorldSyncEvent e) {
  if (granted == null || e.eventType != PostgresChangeEvent.update) return;
  final r = e.newRecord;
  if (r['moved_at'] == null ||
      r['combatant_id'] != granted.combatantId ||
      r['encounter_id'] != granted.encounterId) {
    return;
  }
  final x = r['x'], y = r['y'];
  if (x is! num || y is! num) return;
  final enc = ref
      .read(combatProvider)
      .encounters
      .where((en) => en.id == granted.encounterId)
      .firstOrNull;
  if (enc == null) return;
  final pos = Offset(x.toDouble(), y.toDouble());
  final kindIx = r['kind'];
  final kind = kindIx is int && kindIx >= 0 && kindIx < TurnMoveKind.values.length
      ? TurnMoveKind.values[kindIx]
      : TurnMoveKind.move;
  final via = parseTurnPath(r['path']);
  final seqRaw = r['seq'];
  final ack = seqRaw is num
      ? MoveAck(id: granted.combatantId, seq: seqRaw.toInt())
      : null;

  final map = battleMapProvider(enc.id);
  if (ref.exists(map)) {
    // The notifier sends the ack with the trail it produces.
    final n = ref.read(map.notifier);
    if (kind == TurnMoveKind.undo) {
      n.undoRemoteMove(granted.combatantId, pos, ack: ack);
    } else {
      n.applyRemoteMove(granted.combatantId, pos,
          via: via, newLeg: kind == TurnMoveKind.leg, ack: ack);
    }
    return;
  }

  var to = pos;
  if (enc.gridSnap) {
    // Same rule as the DM's own drop (`BattleMapNotifier.snapTokenToGrid`).
    final gs = enc.gridSize.toDouble();
    to = Offset((to.dx / gs).round() * gs, (to.dy / gs).round() * gs);
  }
  ref.read(combatProvider.notifier).saveMapData(
    encounterId: enc.id,
    tokenPositions: {
      ...enc.tokenPositions,
      granted.combatantId: {'x': to.dx, 'y': to.dy},
    },
  );
  // The position patch above is already out; the ack follows it.
  if (ack != null) {
    final proj = ref
        .read(projectionControllerProvider)
        .items
        .whereType<BattleMapProjection>()
        .where((p) => p.encounterId == enc.id)
        .firstOrNull;
    if (proj != null) {
      ref
          .read(projectionControllerProvider.notifier)
          .updateBattleMapTrail(proj.id, null, ack: ack, keepTrail: true);
    }
  }
}

/// `world_turn_control.path` (flat `[x0, y0, ...]`, migration 107) → points.
/// Anything malformed is no path.
@visibleForTesting
List<Offset> parseTurnPath(Object? raw) {
  if (raw is! List || raw.length.isOdd) return const [];
  final out = <Offset>[];
  for (var i = 0; i + 1 < raw.length; i += 2) {
    final a = raw[i], b = raw[i + 1];
    if (a is! num || b is! num) return const [];
    out.add(Offset(a.toDouble(), b.toDouble()));
  }
  return out;
}

class _DmTurnControl {
  _DmTurnControl(this._client, this._worldId);

  final SupabaseClient _client;
  final String _worldId;

  /// What the row holds once the queued writes land.
  TurnGrant? granted;

  /// False until the first write: a row left behind by a crashed session is
  /// cleared even when no turn is granted now.
  bool _synced = false;

  /// After a failed write the same grant is retried no sooner than this —
  /// [update] runs on every projection change (viewport: 30 Hz), and an
  /// offline DM must not turn that into a stream of failing requests.
  DateTime? _retryAfter;

  Future<void> _writes = Future.value();

  /// Delete, then insert: the previous owner can't see the new row (RLS), so
  /// only a DELETE event tells them their turn is over.
  void update(TurnGrant? want) {
    if (_synced &&
        want?.key == granted?.key &&
        (_retryAfter == null || DateTime.now().isBefore(_retryAfter!))) {
      return;
    }
    _retryAfter = null;
    _synced = true;
    granted = want;
    _writes = _writes.then((_) async {
      try {
        await _client
            .from('world_turn_control')
            .delete()
            .eq('world_id', _worldId);
        if (want != null) {
          await _client.from('world_turn_control').insert(want.toRow());
        }
      } catch (e) {
        debugPrint('DmTurnControl: $e');
        if (identical(granted, want)) {
          _retryAfter = DateTime.now().add(const Duration(seconds: 5));
        }
      }
    });
  }
}
