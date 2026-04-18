# 22 — Online Game Flow

> **For Claude.** Game code generation, DM/player join, role assignment, disconnect/reconnect.
> **Target:** `flutter_app/lib/application/online/`, `flutter_app/lib/presentation/screens/online/`

## Game Code

### Format

- 6 characters, alphanumeric uppercase.
- Excluded: `0 O 1 I L` (visual ambiguity).
- Allowed alphabet: `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (32 chars).
- Total combinations: 32^6 ≈ 1.07 billion → collision-resistant for thousands of concurrent sessions.

### Generation

```dart
// flutter_app/lib/application/online/game_code_generator.dart

class GameCodeGenerator {
  static const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static final _rng = Random.secure();

  String generate() {
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return buf.toString();
  }

  Future<String> generateUnique(SupabaseClient supabase, {int maxAttempts = 5}) async {
    for (var i = 0; i < maxAttempts; i++) {
      final code = generate();
      final exists = await supabase.from('game_sessions')
        .select('id').eq('code', code).eq('status', 'open').maybeSingle();
      if (exists == null) return code;
    }
    throw StateError('Failed to generate unique game code after $maxAttempts attempts');
  }
}
```

### Display

DM screen shows code prominently with "Tap to copy" + QR code. Players type into a 6-cell code input (auto-uppercase, auto-advance).

## Session Lifecycle

```
state machine:
  NotStarted ─DM creates─> Open ─player joins─> Open ─DM starts─> Active ─DM ends─> Closed
                                       │                                             ↑
                                       └─DM cancels─────────────────────────────────┘
```

### DM Creates Session

```dart
class GameSessionService {
  Future<GameSession> createAsDm({
    required String campaignId,
    required String campaignName,
  }) async {
    final code = await codeGenerator.generateUnique(supabase);
    final inserted = await supabase.from('game_sessions').insert({
      'code': code,
      'dm_user_id': supabase.auth.currentUser!.id,
      'campaign_name': campaignName,
      'game_system_id': 'dnd5e',
      'status': 'open',
    }).select().single();
    final session = GameSession.fromJson(inserted);

    // Auto-add DM as participant.
    await supabase.from('session_participants').insert({
      'session_id': session.id,
      'user_id': supabase.auth.currentUser!.id,
      'role': 'dm',
      'display_name': supabase.auth.currentUser!.userMetadata?['display_name'] ?? 'DM',
    });

    return session;
  }
}
```

### Player Joins

```dart
Future<GameSession> joinByCode({
  required String code,
  required String displayName,
  String? characterId,        // local Character UUID if joining with own character
}) async {
  final row = await supabase.from('game_sessions')
    .select().eq('code', code.toUpperCase()).eq('status', 'open').maybeSingle();
  if (row == null) throw GameJoinException('Game code not found or session not open');

  final session = GameSession.fromJson(row);

  // Check if already a participant.
  final existing = await supabase.from('session_participants')
    .select().eq('session_id', session.id).eq('user_id', supabase.auth.currentUser!.id).maybeSingle();
  if (existing != null) {
    // Re-joining — update status to active.
    await supabase.from('session_participants')
      .update({'status': 'active', 'last_seen_at': DateTime.now().toIso8601String()})
      .eq('id', existing['id']);
    return session;
  }

  // Check capacity.
  final count = await supabase.from('session_participants')
    .select('id').eq('session_id', session.id).eq('status', 'active').count();
  if (count.count >= session.maxPlayers) {
    throw GameJoinException('Session is full');
  }

  await supabase.from('session_participants').insert({
    'session_id': session.id,
    'user_id': supabase.auth.currentUser!.id,
    'role': 'player',
    'display_name': displayName,
    'character_id': characterId,
  });

  return session;
}
```

### DM Starts Session

UI button: "Start Play". Updates status to `active`. Players already in lobby auto-transition to in-game UI.

### DM Ends Session

UI button: "End Session". Updates status to `closed`, sets `closed_at`. Players see "Session ended by DM" screen and return to home.

### Auto-Cleanup

Closed sessions older than 7 days deleted nightly via Supabase scheduled function. Storage (session-images, etc.) cleaned same time.

## Lobby Screen

`presentation/screens/online/lobby_screen.dart`

DM view:
```
┌────────────────────────────────────────┐
│  Campaign: Lost Mines                   │
│  Game Code: A4F2K7         [QR] [Copy] │
├────────────────────────────────────────┤
│  Participants (3/8):                    │
│   • You (DM)                            │
│   • Aragorn — Eren                      │
│   • Legolas — Ahmet (joining...)        │
├────────────────────────────────────────┤
│  Settings:                              │
│   Auto-combat:  [ off ]                 │
│   Max players:  8                       │
├────────────────────────────────────────┤
│  [ Start Play ]   [ Cancel Session ]    │
└────────────────────────────────────────┘
```

Player view:
```
┌────────────────────────────────────────┐
│  Joining: Lost Mines                    │
│                                         │
│  Your character: [ Pick or Create ]     │
│   ▸ Aragorn (Ranger 5)                 │
│   ▸ Create new character                │
│   ▸ Use DM-provided pre-gen             │
│                                         │
│  Display name: [ Eren            ]      │
│                                         │
│  Waiting for DM to start...             │
│                                         │
│  Other players in lobby:                │
│   • DM                                  │
│   • Ahmet                               │
└────────────────────────────────────────┘
```

## Disconnect Handling

- Heartbeat: every 30 seconds, update `session_participants.last_seen_at`.
- A participant's `status` flips to `disconnected` if `last_seen_at` is older than 90 seconds (server-side scheduled function or check on next event).
- Disconnected participants stay in session; can rejoin without code (already a participant, just relaunch app).
- If DM disconnects: session continues; players see banner "DM disconnected — waiting for reconnect" but state persists.
- DM reconnect: state resumes from Drift local DB (ground truth) + Supabase broadcast catch-up.

## Auth

Uses existing Supabase Auth. Anonymous auth allowed for players who don't want an account:

```dart
await supabase.auth.signInAnonymously();
```

Anonymous users can join games but cannot host (DM requires registered account so sessions persist past app uninstall).

## Routes

```dart
// presentation/router/app_router.dart additions:

GoRoute(
  path: '/online',
  builder: (_, __) => const OnlineHubScreen(),
  routes: [
    GoRoute(path: 'host', builder: (_, __) => const HostSessionScreen()),
    GoRoute(path: 'join', builder: (_, __) => const JoinByCodeScreen()),
    GoRoute(path: 'lobby/:sessionId', builder: (_, s) => LobbyScreen(sessionId: s.pathParameters['sessionId']!)),
    GoRoute(path: 'play/:sessionId', builder: (_, s) => OnlinePlayScreen(sessionId: s.pathParameters['sessionId']!)),
  ],
),
```

## Player UI vs DM UI After "Start Play"

- **DM** → existing MainScreen with all tabs (Database, Session, Mind Map, Map). Online sync overlays added (presence indicators, "X is drawing" hints).
- **Player** → restricted MainScreen variant: only Character / Battlemap / Mind Map / Player Screen tabs visible. Soundmap + PDF sidebars present in read-only mode.

Implemented as a `ViewerRole` provider:

```dart
enum ViewerRole { dm, player, observer }

final viewerRoleProvider = StateProvider<ViewerRole>((_) => ViewerRole.dm);
```

Tab list rendered conditionally on `viewerRoleProvider`.

## Acceptance

- DM creates session → unique code generated, displayed.
- Player enters code → joins lobby → sees DM + others.
- DM clicks "Start Play" → all clients transition to play UI.
- Player who closes app and reopens → auto-rejoins same session.
- DM closes session → all players ejected to home with notice.
- Player without account can `signInAnonymously()` and join.

## Open Questions

1. Should DM be able to kick players? → Yes; UI button. Updates `session_participants.status` to `kicked`.
2. Code reuse: when session closes, can code be reissued? → Codes unique only among `status='open'` sessions; closed sessions don't block. Index permits.
3. DM transfer (DM hands off mid-session)? → Out of MVP scope. Future feature.
