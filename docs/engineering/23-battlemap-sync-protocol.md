# 23 — Battlemap Sync Protocol

> **For Claude.** DM↔player fog/draw/token sync. DM = source of truth. Players draw + view.
> **Source:** [21-realtime-protocol](./21-realtime-protocol.md)
> **Target:** `flutter_app/lib/application/online/battlemap/`

## Authority Model

```
Resource             | DM writes | Player writes | Player reads
─────────────────────┼───────────┼───────────────┼────────────
Map image            | yes       | no            | yes
Grid settings        | yes       | no            | yes
Fog of War           | yes       | no            | yes
Tokens (creation)    | yes       | no            | yes
Tokens (movement)    | yes       | own*          | yes
DM strokes           | yes       | no            | yes (if not DM-only flagged)
Player strokes       | erase any | own           | yes
Measurements         | yes       | yes (visible to all) | yes
Viewport             | own       | own           | n/a
```

*Player token movement only on their own turn (per [24](./24-player-action-protocol.md)). MVP: visual only — DM can override / undo.

## DM Broadcast Pipeline

DM is the canonical source. Every change locally → applied → broadcast.

```dart
// flutter_app/lib/application/online/battlemap/battlemap_dm_publisher.dart

class BattleMapDmPublisher {
  final SupabaseClient supabase;
  final String sessionId;
  String? _currentEncounterId;

  Stream<BattleMapState>? _localStateStream;
  StreamSubscription? _sub;

  void start(String encounterId, Stream<BattleMapState> localStream) {
    _currentEncounterId = encounterId;
    _sub = localStream.debounceTime(const Duration(milliseconds: 100)).listen(_publish);
  }

  Future<void> _publish(BattleMapState state) async {
    final snapshot = BattleMapSnapshot.fromState(state);
    final json = snapshot.toJson();
    await supabase.from('shared_battle_maps').upsert({
      'session_id': sessionId,
      'encounter_id': _currentEncounterId,
      'snapshot_json': json,
      // sequence_number assigned by trigger
    });
  }

  void stop() {
    _sub?.cancel();
  }
}
```

**Debounce** prevents flooding (e.g., during fast brush strokes). 100ms debounce gives ~10 updates/sec max.

**Snapshot strategy** (MVP): full snapshot per change. Per [21](./21-realtime-protocol.md), defer delta compression until bandwidth-bound.

## Player Receive

Player subscribes via `BattleMapSyncNotifier` (see [21](./21-realtime-protocol.md)). On each snapshot:
1. Replace local read-only `BattleMapState`.
2. Trigger UI rebuild.

## Player Drawings (Append Stream)

Player drawings are out-of-band from snapshot to avoid round-trip latency.

```dart
// flutter_app/lib/application/online/battlemap/player_drawing_publisher.dart

class PlayerDrawingPublisher {
  Future<void> addStroke(Stroke s) async {
    await supabase.from('player_drawings').insert({
      'session_id': sessionId,
      'author_user_id': supabase.auth.currentUser!.id,
      'encounter_id': encounterId,
      'stroke_json': s.toJson(),
    });
  }
}

// flutter_app/lib/application/online/battlemap/player_drawing_subscriber.dart

class PlayerDrawingSubscriber extends StateNotifier<List<Stroke>> {
  // see 21 — subscribes to inserts and deletes
}
```

DM erase: delete row → realtime broadcast removes from all clients.

## Token Movement (Player-Initiated)

```dart
class TokenMoveRequest {
  final String tokenId;
  final TokenPosition fromPos;
  final TokenPosition toPos;
  final double distanceFt;
  final String declaringUserId;
}
```

Flow:
1. Player drags own token.
2. Local UI shows preview path with distance counter.
3. On release: client validates `distanceFt ≤ remainingMovementThisTurn` (computed from `Speed - movementUsedFt`).
4. If valid: insert `player_actions` row of type `'movement_declared'` with payload `{tokenId, toPos, distanceFt}`.
5. DM sees notification + badge on token: "Player moves 25 ft".
6. DM accepts → updates token position in canonical state → broadcast snapshot updates token for everyone.
7. DM rejects → toast for player: "DM rejected movement".

MVP: no auto-apply. DM always confirms. Future: auto-apply for trusted sessions.

## Fog of War Sync

DM brushes fog → local `BattleMapState.fogData` updates → `BattleMapDmPublisher` debounce-publishes snapshot.

Players see fog reveal areas. Hidden areas appear to players as solid black overlay.

**Fog representation:** existing `fogDataBase64` (PNG bitmap). For 2000×2000 px map, ~50 KB compressed. Acceptable in snapshot.

## Measurement Tools

Either DM or player can place measurement markers (ruler, circle).

```dart
class Measurement {
  final String id;
  final String authorUserId;
  final MeasurementType type;     // ruler | circle
  final List<Point> points;
  final double valueFt;            // displayed value
  final DateTime expiresAt;        // measurements auto-expire (5 min)
}
```

Stored in `player_drawings` with `stroke_json.kind = 'measurement'`. Auto-cleaned via TTL on client side (and nightly purge on server).

## Viewport Independence

Each client manages own viewport (pan/zoom). Not synced. Per-client preference (e.g., DM zoomed in on enemy, player zoomed out for tactics).

**Optional follow-DM mode** (future): player toggles "Follow DM viewport" → subscribes to DM's viewport via separate channel.

## Visibility Filtering

Some battlemap content is DM-only:
- Hidden monster tokens (not yet revealed).
- DM-only annotations (notes, plot reminders).

Implementation:

```dart
class BattleMapSnapshot {
  /// Returns DM view (full).
  BattleMapSnapshotData asDmView() => data;

  /// Returns player view (filtered).
  BattleMapSnapshotData asPlayerView() => data.copyWith(
    tokens: data.tokens.where((t) => t.visibility != Visibility.dmOnly).toList(),
    strokes: data.strokes.where((s) => !s.isDmOnly).toList(),
    notes: data.notes.where((n) => !n.isDmOnly).toList(),
  );
}
```

Pre-filter on DM side before publish:

```dart
Future<void> _publish(BattleMapState state) async {
  final playerView = BattleMapSnapshot.fromState(state).asPlayerView();
  await supabase.from('shared_battle_maps').upsert({
    'snapshot_json': playerView.toJson(),
    // ...
  });
}
```

DM-only content stays local (offline DB). Players never see it via Supabase.

## Bandwidth Optimization (MVP-Acceptable)

| Action | Snapshot size | Updates/sec peak | Bandwidth |
|---|---|---|---|
| Fog brush stroke | ~50 KB | 10 (debounced) | 500 KB/s burst |
| Token move | ~20 KB | 5 | 100 KB/s |
| DM draws | ~20 KB | 10 | 200 KB/s |
| Idle | ~20 KB | 0 | 0 |

Burst 500 KB/s during fog painting acceptable on modern broadband. If bottleneck → switch to delta protocol (per [21](./21-realtime-protocol.md) future).

## Data Flow Diagram

```
DM device:
  battle_map_notifier (local state)
    → debounce(100ms)
    → battlemap_dm_publisher
    → supabase.upsert(shared_battle_maps)
    → trigger sets sequence_number
    → realtime broadcast

Player device:
  realtime channel
    → battlemap_sync_provider
    → state.copyWith(snapshot)
    → BattleMapPainter rebuild

Player draws stroke:
  player_drawing_publisher
    → supabase.insert(player_drawings)
    → realtime broadcast
    → all clients (incl. DM) subscribers
    → state.append(stroke)
    → BattleMapPainter rebuild
```

## Fault Tolerance

- **Snapshot dropped (network blip):** next snapshot supersedes. Clients see brief stale frame.
- **Drawing insert fails:** client retries 3× then surfaces error to user.
- **Player offline drawing:** queued locally, flushed on reconnect.

## Acceptance

- DM brushes fog → 8 players see fog reveal within 500 ms.
- Player draws line → all 7 other players + DM see it within 500 ms.
- DM erases player line → vanishes for all.
- Player moves token → DM sees notification, accepts → token position broadcasts to all.
- DM-only token never appears in player view (Supabase row inspection confirms filtered).
- Bandwidth measurement: under 200 KB/s avg per client during 10-min combat session.

## Open Questions

1. Should fog be transmitted as path-of-strokes (compact) instead of bitmap? → Future. MVP: keep bitmap (matches existing offline impl).
2. Conflict on simultaneous DM edits across two devices (e.g., DM uses iPad + laptop)? → Last-write-wins by sequence number. Discourage multi-device DM via UI hint.
3. End-of-encounter cleanup of `shared_battle_maps` row? → Keep until session closed (history may be useful). Cleanup on session close.
