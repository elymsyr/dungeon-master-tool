---
type: file-note
domain: backend
path: supabase/migrations/026_online_worlds.sql, 034_open_world_chars.sql, 051_world_members_replica_full.sql, 052_entity_shares_replica_full.sql
layer: backend
language: sql
status: stable
updated: 2026-06-09
tags: [file]
---

# `Migrations — Online Worlds, Members, Invites & Realtime`

> [!abstract] Primary Purpose
> The online-multiplayer foundation: shared world ownership, membership (DM/player roles), base32 invite codes, and the Postgres mirror of local Drift content (entities, mind-map nodes/edges, characters) plus per-entity share records. Wires the `supabase_realtime` publication so the Flutter mirror services receive CDC, and fixes UPDATE/DELETE CDC fidelity via `REPLICA IDENTITY FULL`.

## Inputs / Outputs
**Inputs**
- Run in Supabase SQL Editor. References `auth.users` + buckets from 001–004.

**Outputs**
- Tables (026): `worlds`, `world_members`, `world_invites`, `world_entities`, `world_mind_map_nodes`, `world_mind_map_edges`, `world_characters`, `entity_shares`, `character_claim_pool`.
- RPCs (see [[rpc-reference]]): `is_world_member`, `is_world_dm`, `can_access_map`, `create_world_invite`, `redeem_world_invite`, `claim_character`.
- Realtime: all 8 world tables added to `supabase_realtime` publication.

## Dependencies & Links
- Depends on: [[migrations-auth-social]]
- Used by: [[world_mirror_service]], [[world_mirror_applier]], [[supabase_world_membership_service]], [[world_join_service]], [[character_claim_service]], [[rpc-reference]], [[migrations-media-storage]], [[migrations-security]]
- Domain map: [[Backend-Infra]]
- System flow: [[Sync-and-Realtime]]
- Spec / reference: [[Multiplayer-and-Online]]

## Key Logic / Variables — per migration
- **026_online_worlds** — Built in two phases (all tables, then all RLS/triggers/RPCs) to avoid forward-reference errors.
  - `worlds` (TEXT PK = local campaign id, `owner_id`, `state_json` mirror of `campaigns.stateJson`). `world_members` PK `(world_id, user_id)`, `role CHECK ('dm','player')`. `world_invites` PK = 8-char base32 `code`, `uses_left`, `expires_at`. `world_entities` mirrors the Drift Entities table column-for-column. `world_mind_map_nodes/_edges` keyed by `map_id` convention: `'default'` = DM map (player-hidden), `'player_<uid>'` = that player's map. `world_characters` (TEXT PK, nullable `owner_id`, `payload_json`, GIN-indexed `referenced_entity_ids` JSONB for implicit visibility). `entity_shares` (synthetic UUID PK + two partial unique indexes; `shared_with NULL` = whole world). `character_claim_pool` (legacy, see 034).
  - Helper RPCs: `is_world_member(world)`, `is_world_dm(world)`, `can_access_map(world,map)` (DM sees all; player only `player_<uid>`). Invite alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, `p_uses` 1–100, 10 collision retries. Trigger `tg_world_insert_dm_member` auto-adds owner as DM; `tg_bump_updated_at` on the mirror tables.
  - Realtime: idempotent `DO` block `ALTER PUBLICATION supabase_realtime ADD TABLE` for all 8 tables; ends with `NOTIFY pgrst, 'reload schema'`.
- **034_open_world_chars** — SELECT policy → "members read all" (was owner-only). `claim_character` RPC becomes pool-free: canon is `world_characters.owner_id IS NULL` = claimable; pool table kept best-effort-synced for old clients, slated for drop.
- **051_world_members_replica_full** — `ALTER TABLE world_members REPLICA IDENTITY FULL`. Default identity only carries PK in UPDATE/DELETE CDC; PK is `(world_id,user_id)` so role-change/kick events reached the DM with truncated records. Metadata-only fix.
- **052_entity_shares_replica_full** — `ALTER TABLE entity_shares REPLICA IDENTITY FULL`. The realtime subscription filters `entity_shares` by `world_id`, but `entity_shares` PK is `id` only → un-share DELETE `oldRecord` lacked `world_id` and was silently dropped (player never saw the un-share). Same class of bug as 051.

## Notes
- `transient_shares` (054) follows the same REPLICA IDENTITY FULL pattern so un-share/projection-drop DELETEs propagate.
- Member CDC and granular per-row mirroring are detailed in [[Sync-and-Realtime]] / [[CDC-Sync-Flow]].
