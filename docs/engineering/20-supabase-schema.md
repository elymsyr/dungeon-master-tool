# 20 — Supabase Schema

> **For Claude.** Tables, RLS, indexes for online multiplayer game sessions.
> **Target:** Supabase project (separate SQL migration files in `supabase/migrations/`)

## Tables

### `game_sessions`

```sql
CREATE TABLE game_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT UNIQUE NOT NULL CHECK (char_length(code) BETWEEN 6 AND 8),
  dm_user_id      UUID NOT NULL REFERENCES auth.users(id),
  campaign_name   TEXT NOT NULL,
  game_system_id  TEXT NOT NULL DEFAULT 'dnd5e',
  status          TEXT NOT NULL DEFAULT 'open',          -- open | active | closed
  max_players     INT  NOT NULL DEFAULT 8,
  auto_combat_enabled BOOLEAN NOT NULL DEFAULT FALSE,    -- MVP: always FALSE
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at       TIMESTAMPTZ
);
CREATE INDEX idx_game_sessions_code ON game_sessions(code);
CREATE INDEX idx_game_sessions_dm ON game_sessions(dm_user_id);
```

### `session_participants`

```sql
CREATE TABLE session_participants (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id),
  role            TEXT NOT NULL CHECK (role IN ('dm','player')),
  display_name    TEXT NOT NULL,
  character_id    TEXT,                                  -- local Character UUID; broadcast key only
  joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  status          TEXT NOT NULL DEFAULT 'active',        -- active | disconnected | kicked
  UNIQUE(session_id, user_id)
);
CREATE INDEX idx_session_participants_session ON session_participants(session_id);
```

### `shared_battle_maps`

Latest broadcast snapshot per session. DM is source of truth; this is a cache for late-joiners.

```sql
CREATE TABLE shared_battle_maps (
  session_id      UUID PRIMARY KEY REFERENCES game_sessions(id) ON DELETE CASCADE,
  encounter_id    TEXT NOT NULL,
  snapshot_json   JSONB NOT NULL,                        -- BattleMapSnapshot
  sequence_number BIGINT NOT NULL,                       -- monotonic
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `player_drawings`

Player-authored drawings on the shared battlemap. DM can erase any.

```sql
CREATE TABLE player_drawings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
  author_user_id  UUID NOT NULL REFERENCES auth.users(id),
  encounter_id    TEXT NOT NULL,
  stroke_json     JSONB NOT NULL,                        -- {points, color, width, tool}
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_player_drawings_session ON player_drawings(session_id, encounter_id);
```

### `player_actions`

Visual AoE markers + action commits from players. DM resolves manually (MVP).

```sql
CREATE TABLE player_actions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
  author_user_id  UUID NOT NULL REFERENCES auth.users(id),
  encounter_id    TEXT NOT NULL,
  action_type     TEXT NOT NULL,                         -- 'aoe_marker' | 'spell_cast' | 'attack_declared' | 'movement_declared'
  payload_json    JSONB NOT NULL,                        -- type-specific
  status          TEXT NOT NULL DEFAULT 'pending',       -- pending | acknowledged | resolved | rejected
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at     TIMESTAMPTZ
);
CREATE INDEX idx_player_actions_session ON player_actions(session_id, status);
```

### `combat_state_broadcasts`

DM broadcasts current encounter state for late-joiners (live updates via realtime channel).

```sql
CREATE TABLE combat_state_broadcasts (
  session_id      UUID PRIMARY KEY REFERENCES game_sessions(id) ON DELETE CASCADE,
  encounter_id    TEXT NOT NULL,
  state_json      JSONB NOT NULL,                        -- redacted view (no DM-private fields)
  sequence_number BIGINT NOT NULL,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `projection_state`

DM's currently-projected content (image, entity card, PDF, etc.).

```sql
CREATE TABLE projection_state (
  session_id      UUID PRIMARY KEY REFERENCES game_sessions(id) ON DELETE CASCADE,
  projection_type TEXT NOT NULL,                         -- 'image' | 'entity_card' | 'pdf' | 'battlemap' | 'black'
  payload_json    JSONB NOT NULL,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `soundboard_state`

Currently-playing tracks broadcast to players (read-only view + volume control on player side).

```sql
CREATE TABLE soundboard_state (
  session_id      UUID PRIMARY KEY REFERENCES game_sessions(id) ON DELETE CASCADE,
  state_json      JSONB NOT NULL,                        -- {music: {...}, ambience: [...], sfx: [...]}
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## Row-Level Security (RLS)

All tables: `ALTER TABLE x ENABLE ROW LEVEL SECURITY;`

### Helper Functions

```sql
-- Returns true if auth.uid() is a participant in given session.
CREATE OR REPLACE FUNCTION is_session_participant(session UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM session_participants
    WHERE session_id = session AND user_id = auth.uid() AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION is_session_dm(session UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM game_sessions WHERE id = session AND dm_user_id = auth.uid()
  );
$$;
```

### Policies

```sql
-- game_sessions
CREATE POLICY "session_select_participants" ON game_sessions FOR SELECT
  USING (is_session_participant(id) OR dm_user_id = auth.uid());
CREATE POLICY "session_insert_self_dm" ON game_sessions FOR INSERT
  WITH CHECK (dm_user_id = auth.uid());
CREATE POLICY "session_update_dm" ON game_sessions FOR UPDATE
  USING (dm_user_id = auth.uid());
CREATE POLICY "session_delete_dm" ON game_sessions FOR DELETE
  USING (dm_user_id = auth.uid());

-- session_participants
CREATE POLICY "participant_select_in_session" ON session_participants FOR SELECT
  USING (is_session_participant(session_id) OR is_session_dm(session_id));
CREATE POLICY "participant_insert_join" ON session_participants FOR INSERT
  WITH CHECK (user_id = auth.uid());                     -- you can only join as yourself
CREATE POLICY "participant_update_self_or_dm" ON session_participants FOR UPDATE
  USING (user_id = auth.uid() OR is_session_dm(session_id));
CREATE POLICY "participant_delete_self_or_dm" ON session_participants FOR DELETE
  USING (user_id = auth.uid() OR is_session_dm(session_id));

-- shared_battle_maps
CREATE POLICY "battlemap_select_participants" ON shared_battle_maps FOR SELECT
  USING (is_session_participant(session_id));
CREATE POLICY "battlemap_upsert_dm" ON shared_battle_maps FOR ALL
  USING (is_session_dm(session_id))
  WITH CHECK (is_session_dm(session_id));

-- player_drawings
CREATE POLICY "drawing_select_participants" ON player_drawings FOR SELECT
  USING (is_session_participant(session_id));
CREATE POLICY "drawing_insert_self_participant" ON player_drawings FOR INSERT
  WITH CHECK (is_session_participant(session_id) AND author_user_id = auth.uid());
CREATE POLICY "drawing_delete_dm_or_author" ON player_drawings FOR DELETE
  USING (is_session_dm(session_id) OR author_user_id = auth.uid());

-- player_actions
CREATE POLICY "action_select_participants" ON player_actions FOR SELECT
  USING (is_session_participant(session_id));
CREATE POLICY "action_insert_self_participant" ON player_actions FOR INSERT
  WITH CHECK (is_session_participant(session_id) AND author_user_id = auth.uid());
CREATE POLICY "action_update_dm" ON player_actions FOR UPDATE
  USING (is_session_dm(session_id));
CREATE POLICY "action_delete_dm_or_author" ON player_actions FOR DELETE
  USING (is_session_dm(session_id) OR author_user_id = auth.uid());

-- combat_state_broadcasts, projection_state, soundboard_state
CREATE POLICY "state_select_participants" ON combat_state_broadcasts FOR SELECT
  USING (is_session_participant(session_id));
CREATE POLICY "state_upsert_dm" ON combat_state_broadcasts FOR ALL
  USING (is_session_dm(session_id))
  WITH CHECK (is_session_dm(session_id));

-- Repeat same shape for projection_state and soundboard_state.
```

## Realtime

Enable Supabase Realtime on these tables (so changes broadcast automatically):

- `shared_battle_maps`
- `player_drawings`
- `player_actions`
- `combat_state_broadcasts`
- `projection_state`
- `soundboard_state`
- `session_participants` (presence updates)

In Supabase dashboard → Database → Replication → enable for these tables.

Realtime broadcast channels (Postgres Changes) are subscribed per-session-id with filter:

```dart
supabase
  .channel('public:shared_battle_maps:session_id=eq.$sessionId')
  .onPostgresChanges(...)
  .subscribe();
```

See [21](./21-realtime-protocol.md) for protocol envelope.

## Storage Buckets

```
package-files          -- DnD 5e package uploads (.dnd5e-pkg.json), max 10 MB per file
session-images         -- DM-shared images during play (per-session, deleted after session closed N days)
character-portraits    -- user-uploaded portraits, max 1 MB
```

Bucket policies: same RLS pattern (only session participants can read session-images, etc.).

## Migration Files

```
supabase/migrations/
  20260101000000_initial_schema.sql        # if not exists yet
  20260420000000_game_sessions.sql         # tables above
  20260420000100_rls_policies.sql
  20260420000200_realtime_enable.sql
  20260420000300_storage_buckets.sql
```

## Acceptance

- All 7 tables created in Supabase.
- All RLS policies pass:
  - Anon user cannot SELECT any.
  - Authenticated non-participant cannot SELECT session content.
  - Player can SELECT but not modify combat state.
  - DM can do everything within their sessions.
- Realtime broadcasts arrive client-side within 500 ms (LAN test).

## Open Questions

1. Should `code` be human-readable (e.g., `bear-tower-3`)? → **No.** 6-char alphanumeric (avoid 0/O/1/I). Discuss in [22](./22-online-game-flow.md).
2. Hard quota on player_drawings per session (storage)? → MVP: soft 10,000 strokes/session, then DM prompted to clear.
3. Encrypt `state_json` blobs? → No. RLS is the security boundary.
