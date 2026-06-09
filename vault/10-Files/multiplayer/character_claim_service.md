---
type: file-note
domain: multiplayer
path: flutter_app/lib/data/network/character_claim_service.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `character_claim_service.dart`

> [!abstract] Primary Purpose
> Thin Supabase transport for character ownership + world-membership transitions on `world_characters`. Wraps five centralized RPCs (claim/release/remove/delete/assign, migration 039) plus one direct UPDATE (`attachToWorld`), and provides single-row + per-world `world_characters` fetch helpers.

## Inputs / Outputs
**Inputs**
- Constructor deps: `SupabaseClient client`.
- Supabase reads: `world_characters` (`fetchWorldCharacter`, `listWorldCharacters`).

**Outputs**
- RPCs called: `claim_character`, `release_character`, `remove_from_world`, `delete_character`, `assign_character`.
- Direct table writes: `world_characters` UPDATE (`attachToWorld`).
- Returns: `WorldCharacterRow` objects and various result records.

## Dependencies & Links
- Depends on: `world_characters_provider` (`WorldCharacterRow` type — not a tracked note)
- Used by: character ownership UI; world character sync bootstrap; editor-open freshness hook
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[CDC-Sync-Flow]], [[Sync-and-Realtime]]
- Spec / reference: [[migrations-online-worlds]], [[rpc-reference]]

## Key Logic / Variables
State machine over `world_characters` rows `(owner_id, world_id)`; all mutations go through SECURITY DEFINER RPCs with `FOR UPDATE` locking (no direct ownership UPDATE — bypass risk):
- **claim**: `(NULL, W) → (auth.uid, W)`, atomic. Losing concurrent claimer gets `P0003`. Returns `(characterId, worldId)`.
- **release**: `(me, W) → (NULL, W)` UPDATE, or `(me, NULL) → DELETE`. Also the DM force-release path (RPC applies owner-or-DM gate). Idempotent if already free. `P0002`/`PGRST116` (server row absent — local-only char) swallowed → `(worldId:null, deleted:false)`.
- **removeFromWorld**: `(owner, W) → (owner, NULL)` (orphans it) or `(NULL, W) → DELETE` (unclaimed deleted). Auth: owner = `auth.uid` OR `is_world_dm(world_id)`. Absent row → `deleted:true`.
- **deleteCharacter**: hard delete, only valid for `(owner, NULL)` orphans. World-bound rows raise `P0005` (caller should use removeFromWorld/release). Absent row (`P0002`/`PGRST116`) swallowed.
- **assignToPlayer** (DM): `(NULL|other, W) → (userId, W)`. Target must be a `world_members` member (else `P0006`); non-DM caller → `42501`.
- **attachToWorld**: `(me, NULL) → (me, W)` direct UPDATE (no RPC needed — single transition, no server-side decision); gated by RLS UPDATE policy `owner_id = auth.uid OR is_world_dm`.
- **fetchWorldCharacter(id)**: single-row lookup used by the editor-open freshness hook (reflects edits made on another device when there is no active realtime sub on that world). Returns null if no row or null `world_id`.
- **listWorldCharacters(worldId)**: bootstrap fetch of all rows in a world (RLS lets members see all chars in their worlds); subsequent updates arrive via CDC granular patch.

## Notes
- Postgres error-code contract is load-bearing: `P0002`/`PGRST116` = "row absent = desired post-state" (swallow); `P0003` claim conflict; `P0005` wrong-RPC for world-bound; `P0006` target not a member; `42501` not-DM.
