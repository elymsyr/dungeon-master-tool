# 21 — Realtime Protocol

> **For Claude.** Channel naming, event envelope, delta vs snapshot, reconnection.
> **Target:** `flutter_app/lib/data/online/realtime/`

## Channel Naming

One channel per concern per session. Format:

```
session:{sessionId}:battlemap        # BattleMapSnapshot updates
session:{sessionId}:combat           # CombatStateBroadcast updates
session:{sessionId}:drawings         # incremental player_drawings
session:{sessionId}:actions          # player_actions
session:{sessionId}:projection       # ProjectionState
session:{sessionId}:soundboard       # SoundboardState
session:{sessionId}:presence         # who's online (Supabase presence feature)
session:{sessionId}:chat             # optional text chat (future)
```

Use Supabase's Postgres Changes channel filtered by `session_id`. Presence uses Supabase Realtime presence API.

## Event Envelope

Every broadcast event wraps payload in a uniform envelope:

```dart
// flutter_app/lib/data/online/realtime/event_envelope.dart

class EventEnvelope<T> {
  final String eventId;          // UUID
  final String sessionId;
  final String channelName;
  final String eventType;        // 'battlemap.snapshot' | 'battlemap.delta' | 'drawing.add' | ...
  final int sequenceNumber;      // monotonic per channel
  final DateTime timestamp;
  final String authorUserId;
  final T payload;
}
```

Stored as `payload_json` JSONB in DB tables; ID/sequence/timestamp from row metadata.

## Delta vs Snapshot Heuristic

Battlemap is large (fog bitmap, all strokes, all tokens). Sending full snapshot per change wastes bandwidth.

Strategy:

```
Snapshot:  sent on session start, late-join, every N (=20) deltas as keyframe.
Delta:     sent for each individual change (add stroke, move token, fog brush stroke).
```

```dart
sealed class BattleMapEvent {}

class BattleMapSnapshot extends BattleMapEvent {
  final String encounterId;
  final BattleMapSnapshotData data;       // existing entity from offline mode
  final int sequenceNumber;
}

class BattleMapDelta extends BattleMapEvent {
  final int basedOnSequence;              // last snapshot's seq
  final int sequenceNumber;
  final BattleMapChange change;           // sealed: AddStroke|RemoveStroke|MoveToken|FogBrush|...
}

sealed class BattleMapChange {}
class AddStrokeChange extends BattleMapChange { final Stroke stroke; }
class RemoveStrokeChange extends BattleMapChange { final String strokeId; }
class MoveTokenChange extends BattleMapChange { final String tokenId; final TokenPosition newPos; }
class FogBrushChange extends BattleMapChange { final String operation; /* paint|erase */ final List<Point> path; final double radius; }
class ViewportChange extends BattleMapChange { final ViewportRect rect; }
```

Client maintains local state by:
1. On snapshot: replace state.
2. On delta with `basedOnSequence == localSequence`: apply.
3. On delta with `basedOnSequence > localSequence`: out-of-order; buffer.
4. On delta with `basedOnSequence < localSequence`: stale; discard.
5. On gap > 5 seconds with no progress: request snapshot.

## Sequence Number

Per channel, monotonic, server-assigned via DB column `sequence_number`. Allocated by:

```sql
-- Function to increment per session+channel.
CREATE TABLE channel_sequences (
  session_id UUID,
  channel TEXT,
  next_seq BIGINT DEFAULT 0,
  PRIMARY KEY (session_id, channel)
);

CREATE FUNCTION next_channel_seq(s UUID, c TEXT) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE n BIGINT;
BEGIN
  INSERT INTO channel_sequences (session_id, channel) VALUES (s, c)
    ON CONFLICT DO NOTHING;
  UPDATE channel_sequences SET next_seq = next_seq + 1
    WHERE session_id = s AND channel = c
    RETURNING next_seq INTO n;
  RETURN n;
END;
$$;
```

Triggers on insert into `shared_battle_maps`, `player_drawings`, etc., assign sequence:

```sql
CREATE TRIGGER set_seq_battlemap
BEFORE INSERT OR UPDATE ON shared_battle_maps
FOR EACH ROW EXECUTE FUNCTION assign_battlemap_seq();
```

## Client Subscription

```dart
// flutter_app/lib/application/online/realtime/battlemap_sync_provider.dart

class BattleMapSyncNotifier extends StateNotifier<BattleMapState> {
  final SupabaseClient supabase;
  final String sessionId;
  RealtimeChannel? _channel;
  int _localSequence = 0;
  Timer? _gapWatchdog;

  Future<void> connect() async {
    // 1. Fetch latest snapshot from shared_battle_maps.
    final row = await supabase.from('shared_battle_maps')
      .select().eq('session_id', sessionId).maybeSingle();
    if (row != null) {
      state = _decodeSnapshot(row['snapshot_json']);
      _localSequence = row['sequence_number'] as int;
    }

    // 2. Subscribe to changes.
    _channel = supabase.channel('session:$sessionId:battlemap')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'shared_battle_maps',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'session_id', value: sessionId),
        callback: (payload) => _handleSnapshotUpdate(payload),
      )
      .subscribe();

    // 3. Watchdog: if no event in 5s and we suspect a gap, refetch.
    _gapWatchdog = Timer.periodic(const Duration(seconds: 5), (_) => _checkForGap());
  }

  void _handleSnapshotUpdate(PostgresChangePayload payload) {
    final newSnapshot = _decodeSnapshot(payload.newRecord['snapshot_json']);
    final newSeq = payload.newRecord['sequence_number'] as int;
    if (newSeq <= _localSequence) return;   // stale or duplicate
    state = newSnapshot;
    _localSequence = newSeq;
  }

  Future<void> _checkForGap() async {
    final row = await supabase.from('shared_battle_maps')
      .select('sequence_number').eq('session_id', sessionId).maybeSingle();
    if (row != null && (row['sequence_number'] as int) > _localSequence) {
      await connect();   // refetch
    }
  }

  Future<void> disconnect() async {
    _gapWatchdog?.cancel();
    await _channel?.unsubscribe();
  }
}
```

**MVP simplification:** use full snapshot per update (no deltas). Easier to implement; ~5-50 KB per change is acceptable for 2-8 player groups. Add deltas in a follow-up sprint when bandwidth becomes the bottleneck.

## Drawings (Append-Only Stream)

Drawings are pure additive; deltas always.

```dart
class DrawingsSyncNotifier extends StateNotifier<List<Stroke>> {
  RealtimeChannel? _channel;

  Future<void> connect(String sessionId, String encounterId) async {
    // 1. Fetch all existing.
    final rows = await supabase.from('player_drawings')
      .select().eq('session_id', sessionId).eq('encounter_id', encounterId)
      .order('created_at');
    state = rows.map((r) => _decodeStroke(r['stroke_json'])).toList();

    // 2. Subscribe to inserts.
    _channel = supabase.channel('session:$sessionId:drawings')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public', table: 'player_drawings',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'session_id', value: sessionId),
        callback: (p) => state = [...state, _decodeStroke(p.newRecord['stroke_json'])],
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public', table: 'player_drawings',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'session_id', value: sessionId),
        callback: (p) => state = state.where((s) => s.id != p.oldRecord['id']).toList(),
      )
      .subscribe();
  }
}
```

## Player Actions

Pending player actions (AoE markers etc.) flow same way; status updates via realtime.

## Presence

```dart
class PresenceNotifier extends StateNotifier<Set<String>> {
  // state = set of online userIds

  Future<void> connect(String sessionId, String userId, String displayName) async {
    final ch = supabase.channel('session:$sessionId:presence', opts: RealtimeChannelConfig(presence: PresenceOpts(key: userId)));
    ch.onPresenceSync((_) {
      final state = ch.presenceState();
      // ... update local state
    });
    await ch.subscribe();
    await ch.track({'userId': userId, 'displayName': displayName, 'role': /* dm|player */});
  }
}
```

## Reconnection Strategy

- On WebSocket disconnect, Supabase auto-reconnects with backoff.
- On reconnect: client re-runs initial fetch (snapshot + drawings) to catch missed events.
- UI shows transient banner: "Reconnecting...".

## Conflict Strategy

- DM is source of truth for battlemap/combat/projection/soundboard. Conflict impossible (DM-only writers).
- Player-authored drawings: last-write-wins per stroke (no edits, only add/delete).
- Player actions: only author can update author-side; DM can update status. No cross-edit.

## Bandwidth Budget (Rough)

| Channel | Avg event size | Avg events/sec | Bandwidth |
|---|---|---|---|
| battlemap (snapshot) | ~20 KB (fog PNG) | 0.5 | ~10 KB/s per client |
| drawings | ~1 KB | 5 | ~5 KB/s per client |
| combat state | ~5 KB | 0.5 | ~2.5 KB/s |
| presence | ~0.2 KB | 0.5 | ~0.1 KB/s |
| **Total per client** | | | ~20 KB/s ≈ 160 kbps |

Acceptable for any modern home internet. Stress test target: 8 players + DM = 9 connected clients.

## Acceptance

- DM updates battlemap → all 8 players see change within 500 ms (local network).
- Player draws stroke → DM + 7 other players see it within 500 ms.
- DM erases player stroke → vanishes for everyone.
- Player joins mid-session → snapshot + drawings + presence loaded within 2 sec.
- Network drop → auto-reconnect within 10 sec; UI banner shown.

## Open Questions

1. Should we use Supabase Broadcast (ephemeral, faster) instead of Postgres Changes for transient stuff (cursor positions)? → Yes, **future improvement**. MVP: all via Postgres Changes for simplicity.
2. Compression on snapshot JSON? → MVP: none. Add gzip if bandwidth becomes issue.
3. Per-channel rate limit? → Supabase has built-in (100 events/sec/channel default). Sufficient for MVP.
