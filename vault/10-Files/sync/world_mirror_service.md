---
type: file-note
domain: sync
path: flutter_app/lib/application/services/world_mirror_service.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_mirror_service.dart`

> [!abstract] Primary Purpose
> The outbound Supabase push layer plus the self-echo / unpublish-guard bookkeeping. Wraps the `SupabaseClient`: `push*` methods write to the cloud mirror tables (some via direct `.upsert`, some via SECURITY-DEFINER RPCs), `fetchInitialState` / `fetchEntity` pull on subscribe, and a family of `_stamp` / `_isEcho` / `registerExpected*` helpers let `[[world_mirror_applier]]` decide whether an inbound CDC event is our own echo or a destructive event that should be suppressed.

## Inputs / Outputs
**Inputs**
- Constructor: `SupabaseClient client`.
- `fetchInitialState(worldId)` / `fetchEntity(worldId, entityId)` reads.
- Echo/guard queries called by the applier: `isEchoOf(event)`, `isEchoOfId/MapData/Session/Settings/Package/WorldPackage/PersonalPackageEntity`, `isExpectedUnpublish`, `isExpectedCharDelete`.

**Outputs**
- Direct `.upsert` / `.delete` on tables: `world_entities`, `world_characters`, `world_map_data`, `world_sessions`, `world_settings`.
- RPCs called: `publish_world`, `publish_personal_character`, `unpublish_personal_character`, `publish_personal_package`, `unpublish_personal_package`, `publish_personal_package_entity`, `delete_personal_package_entity`, `share_package_to_world`, `unshare_world_package`.
- Errors `rethrow`n on the world push paths (so `SyncEngine` retries); personal-character pushes swallow errors.

## Dependencies & Links
- Depends on: `SupabaseClient`, [[world_sync_service]] (`WorldSyncEvent` type)
- Used by: [[sync_engine]] (all push handlers), [[world_mirror_applier]] (echo/guard checks + `fetchEntity`/`fetchInitialState`), [[world_reconciler]] (`pushWorldState`)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[rpc-reference]], [[migrations-online-worlds]]

## Key Logic / Variables
- **Echo suppression:** `_lastPushedAt[id] = now` on every push (`_stamp`). `_isEcho(id)` returns true if a stamp exists within `_pushSuppressionMs = 3000ms` (else evicts). Prevents the write→broadcast→re-apply loop from overwriting live user input. Echo keys are namespaced to avoid UUID collisions: `mapdata:$worldId`, `session:$id`, `settings:$worldId`, `pkg:$name`, `ppe:$pkg:$id`, `wpkg:$packageId`.
- **Unpublish guard (Make Offline):** `registerExpectedUnpublish(worldId)` stamps `_expectedUnpublish` for `_unpublishGuardMs = 60000ms`. While set, the applier SKIPS local purge/trash on `worlds`/`world_members` DELETE — Make Offline must keep all local Drift data. Self-expiring; `clearExpectedUnpublish` clears early.
- **Char-delete guard (leave_beta orphans):** `_expectedCharDelete` mirror of the above for `world_characters` DELETE — keeps the local copy when the server deletes an orphan online character.
- **`_entityRow`:** maps a blob entity to the wide `world_entities` columns (`category_slug` via `_categoryFor` = lowercased hyphenated `type`, defaults `npc`; jsonEncodes images/tags/pdfs/attributes; preserves `package_id`/`package_entity_id`/`linked`).
- **`pushWorldState`** goes through the `publish_world` RPC (SECURITY DEFINER, owner_id from `auth.uid()`) — avoids RLS/upsert noise; player blocked by RLS.
- **`fetchInitialState`** returns a record of `entities`, `characters`, `mapData`, `sessions`, `settings`, `worldRow` (worlds.state_json), `mindMapNodes`, `mindMapEdges` — pulls all tables in one go to seed Drift on world open (cross-device empty-snapshot fix).
- **`fetchEntity`** single row — used after an `entity_shares` INSERT CDC (the share doesn't mutate `world_entities`, so no CDC fires for the now-visible row).

## Notes
- F4 retired the bulk `pushEntities` path — every entity edit flows per-row through the outbox.
- Granular tables (`world_map_data`/`world_sessions`/`world_settings`) split out of the monolithic `worlds.state_json` blob (migration 042 / PR-SYNC-3); DM still dual-writes `worlds.state_json` for now.
