# 25 — Second Screen Integration (Online + Offline)

> **For Claude.** Extend existing `ProjectionOutput` abstraction so DM's projected content fans out to BOTH local screens (window/screencast) AND remote players via Supabase.
> **Existing infra:** [projection_provider.dart](../../flutter_app/lib/application/providers/projection_provider.dart), [battle_map_snapshot.dart](../../flutter_app/lib/domain/entities/projection/battle_map_snapshot.dart)
> **Target:** `flutter_app/lib/application/online/projection/`

## Existing Architecture

```
ProjectionController (StateNotifier<ProjectionState>)
   ↓
ProjectionOutput (abstract)
   ├── ProjectionOutputWindow      (desktop_multi_window)
   ├── ProjectionOutputScreencast  (Platform Presentation API)
```

Each `ProjectionOutput` is a sink that receives state mutations.

## Add New Output: ProjectionOutputSupabase

```dart
// flutter_app/lib/application/online/projection/projection_output_supabase.dart

class ProjectionOutputSupabase implements ProjectionOutput {
  final SupabaseClient supabase;
  final String sessionId;

  @override
  Future<void> push(ProjectionState state) async {
    await supabase.from('projection_state').upsert({
      'session_id': sessionId,
      'projection_type': _typeOf(state.currentItem),
      'payload_json': _serialize(state.currentItem),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> close() async {
    // Optionally clear projection_state row.
    await supabase.from('projection_state').delete().eq('session_id', sessionId);
  }
}
```

## Multi-Output Composition

Existing `ProjectionController` already supports multiple outputs (List<ProjectionOutput>). When in online session:

```dart
final projectionOutputsProvider = Provider<List<ProjectionOutput>>((ref) {
  final outputs = <ProjectionOutput>[];

  // Local outputs (existing).
  if (ref.watch(secondWindowEnabledProvider)) {
    outputs.add(ProjectionOutputWindow());
  }
  if (ref.watch(screencastEnabledProvider)) {
    outputs.add(ProjectionOutputScreencast());
  }

  // Online output (new).
  final session = ref.watch(activeOnlineSessionProvider);
  if (session != null && session.role == ViewerRole.dm) {
    outputs.add(ProjectionOutputSupabase(
      supabase: ref.watch(supabaseClientProvider),
      sessionId: session.id,
    ));
  }

  return outputs;
});
```

## Player-Side Reception

```dart
// flutter_app/lib/application/online/projection/projection_subscriber.dart

class ProjectionSubscriber extends StateNotifier<ProjectionState> {
  final SupabaseClient supabase;
  final String sessionId;
  RealtimeChannel? _channel;

  Future<void> connect() async {
    // Initial fetch.
    final row = await supabase.from('projection_state').select().eq('session_id', sessionId).maybeSingle();
    if (row != null) state = _decode(row);

    // Subscribe.
    _channel = supabase.channel('session:$sessionId:projection')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public', table: 'projection_state',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'session_id', value: sessionId),
        callback: (p) {
          if (p.eventType == PostgresChangeEvent.delete) {
            state = ProjectionState.empty();
          } else {
            state = _decode(p.newRecord);
          }
        },
      )
      .subscribe();
  }
}

final projectionStateProvider = StateNotifierProvider<ProjectionSubscriber, ProjectionState>((ref) {
  final session = ref.watch(activeOnlineSessionProvider);
  if (session == null || session.role != ViewerRole.player) {
    // Not in player session: use local empty state.
    return _NullSubscriber();
  }
  return ProjectionSubscriber(supabase: ref.watch(supabaseClientProvider), sessionId: session.id)..connect();
});
```

## Player Screen Tab

`presentation/screens/dnd5e/player/player_screen_tab.dart`

```dart
class PlayerScreenTab extends ConsumerWidget {
  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final state = ref.watch(projectionStateProvider);
    return switch (state.currentItem) {
      null => const _EmptyState(message: 'DM has not shared anything yet.'),
      ImageProjection(:final url) => _ImageView(url: url),
      EntityCardProjection(:final entitySnapshot) => _EntityCardView(snapshot: entitySnapshot),
      BattleMapProjection() => const _BattleMapPlaceholder(),  // see Battlemap Tab
      PdfProjection(:final url, :final page) => _PdfView(url: url, page: page),
      BlackScreenProjection() => const ColoredBox(color: Colors.black),
    };
  }
}
```

## DM Projection Controls — Same as Offline

DM uses existing UI: from any entity card, tap "Project to Players" → `ProjectionController.show(EntityCardProjection(entity))` → fans out to all configured outputs (local windows + Supabase).

No new UI for DM. The Supabase output is transparent.

## Privacy: Hidden Fields

`EntitySnapshot.fromEntity(entity, role: ViewerRole.player)` filters DM-only fields. Existing implementation re-used. The Supabase output uses player-view snapshots (DM-only fields stripped before upload).

```dart
class ProjectionOutputSupabase implements ProjectionOutput {
  @override
  Future<void> push(ProjectionState state) async {
    final filteredItem = _filterForPlayer(state.currentItem);
    await supabase.from('projection_state').upsert({
      'payload_json': _serialize(filteredItem),
      // ...
    });
  }
}
```

## Battlemap Sharing — Special Case

Battlemap projection is NOT pushed via `projection_state`. Instead, DM's battlemap tab is the always-on shared canvas (per [23](./23-battlemap-sync-protocol.md)).

`ProjectionState` battlemap entry serves only DM's secondary local screen. For online, players already have their own Battlemap tab subscribed to `shared_battle_maps`.

To project an arbitrary battlemap to player screen tab (not the active one) — out of MVP. Edge case.

## Image Sharing

When DM "Projects" an image:
1. Image must be accessible by players.
2. If image is local file → upload to `session-images` Supabase Storage bucket.
3. Get signed URL.
4. Push `ImageProjection(url: signedUrl)` to `projection_state`.

```dart
Future<String> _uploadIfLocal(File img) async {
  final path = '${sessionId}/${img.uri.pathSegments.last}';
  await supabase.storage.from('session-images').upload(path, img);
  final signed = await supabase.storage.from('session-images').createSignedUrl(path, 3600 * 24);
  return signed;
}
```

## PDF Sharing

DM opens PDF in sidebar → "Project Page" button → uploads PDF (if not already in shared bucket) → broadcasts `PdfProjection(url, page)`.

Player view: read-only PDF viewer scrolled to specified page. Cannot navigate freely.

## Soundboard

DM plays a track via existing soundboard → `ProjectionOutputSupabase` is NOT involved (separate channel — see soundboard table in [20](./20-supabase-schema.md)).

`SoundboardSubscriber` separately syncs `soundboard_state` to player. Player hears audio + sees track name + has volume slider (independent local volume).

## Sound Sync

Naive approach: include audio file URL + start timestamp in `soundboard_state`. Player computes offset = `(now - startTimestamp)` and seeks accordingly. Best-effort sync (no sample-accurate sync).

```dart
class SoundboardState {
  final List<TrackPlayback> playing;
}
class TrackPlayback {
  final String trackId;
  final String url;
  final TrackType type;            // music | ambience | sfx
  final DateTime startedAt;
  final bool looping;
  final double serverVolume;       // DM's set volume; player has own multiplier
}
```

## Acceptance

- DM in online session pushes "Project Image of Goblin Boss" → all 8 player Player Screen tabs show image within 1 sec.
- DM projects entity card → players see redacted entity card (DM-private fields hidden).
- DM stops projection → player tabs show "DM has not shared anything yet."
- Battlemap projection NOT routed via `projection_state` (uses dedicated channel).
- DM in offline mode: works exactly as before (no Supabase output added).
- DM connects mid-session → existing `projection_state` row fetched on subscribe → state populated immediately.

## Open Questions

1. Local-file images: upload on every projection or cache by hash? → Cache by SHA-256; reuse signed URL if already uploaded.
2. PDF player-side navigation: allow "swipe through" or strictly DM-controlled? → **Strictly DM-controlled.** Players see what DM sees.
3. Per-player projection (whisper)? → Out of MVP. Future feature.
