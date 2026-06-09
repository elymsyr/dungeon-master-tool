---
type: file-note
domain: sync
path: flutter_app/lib/application/services/world_mirror_applier.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_mirror_applier.dart`

> [!abstract] Primary Purpose
> The inbound CDC consumer — the counterpart to `[[world_mirror_service]]`'s push side. Subscribes to `WorldSyncService.events`, batches them in a 16ms window, and applies each event to local state: patches the active campaign blob (`entities`, `map_data`, `sessions`, settings spread), invalidates/applies character providers, materializes DM-shared packages, seeds mind-map Drift tables, updates the online projection state, and handles world/member delete → trash/purge. Heavy file (~1540 lines) but the core is one dispatch switch plus per-table appliers.

## Inputs / Outputs
**Inputs**
- Constructor: `Ref ref`, `WorldMirrorService mirror`, `WorldSyncService sync`.
- Subscribed: `sync.events` (`WorldSyncEvent` stream) → `_EventBatcher.add`.
- Reads: `mirror.isEchoOf*` / `isExpectedUnpublish` / `isExpectedCharDelete`, `pendingWriteBufferProvider.isPending`, `authProvider`, `betaLossGateProvider`.
- `applyInitialState(worldId)` pulls `mirror.fetchInitialState`.

**Outputs**
- Mutates active campaign blob via `activeCampaignProvider.notifier` (captured at construction as `_campaign`, a stable `ActiveCampaignNotifier`).
- Bumps `campaignRevisionProvider` (`_bumpRevision` → triggers UI rebuilds, coalesced per batch).
- Applies to `worldCharactersProvider(worldId)` and `characterListProvider` (`applyMirror`/`removeMirror`/`dropMirror`).
- Writes Drift: `worldMindMapDao` (nodes/edges), `worldPackagesDao`, plus repo persistence (`saveSettingsPatch`, `saveMapData`, `saveSessions`, `saveSession`, `deleteSession`).
- Sets `worldInitialSyncSettledProvider`, `onlineProjectionProvider`, `worldMembersProvider`.
- Schedules `referenceIndexerProvider` reindex, `fetchQueueProvider` prefetch, `evictionSweeperProvider` sweep.

## Dependencies & Links
- Depends on: [[world_mirror_service]], [[pending_write_buffer]], [[world_sync_service]], [[package_sync_service]], [[package_import_service]], [[campaign_provider]], `world_characters_provider`, [[projection_state]]
- Used by: world-open wiring (the host provider that watches `currentWorldRoleProvider`), per-user (personal) sync applier (calls `applyCharacterCdc` / `purgeLocalWorld`)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[migrations-online-worlds]]

## Key Logic / Variables
- **`_EventBatcher`** (window `_kBatchWindow = 16ms`): coalesces idempotent last-writer-wins rows by PK into a `LinkedHashMap` (recency-ordered) — keys: `world_entities/world_sessions/world_characters` by `id`, `world_map_data/world_settings` by `worldId`, `world_packages` by `package_id`. `world_members`/`worlds`/`entity_shares` are NOT coalesced (order matters) → `_ordered` list. On `_fire`, drains coalesced-then-ordered, calls `onFlush`; re-arms a new window if events arrived mid-flush.
- **`_flushBatch`:** applies events sequentially (shared `data` Map — parallel would corrupt), suppresses per-event `_bumpRevision` (`_suppressRevisionBump`), emits one `_doBumpRevision` at window end if `_revisionDirty`.
- **Dispatch `_onEvent`:** first `if (mirror.isEchoOf(e)) return` (self-echo skip), then switch on `e.table` → 12 cases: `world_entities`, `world_characters`, `worlds`, `entity_shares`, `world_members`, `world_map_data`, `world_sessions`, `world_settings`, `world_packages`, `world_projection`, `world_mind_map_nodes`, `world_mind_map_edges`.
- **CDC race guard:** every applier checks `_buffer.isPending(key)` (`entity:$worldId:$id`, `character:$id`, `settings:$worldId:map_data`, `settings:$worldId:$subkey`) and bails if the user has an un-flushed local edit.
- **Entity events:** maintain `data['entities']` map via `_entityRowToBlob` (decodes images/tags/pdfs/attributes columns back to blob). Delete → `referenceIndexer.scheduleRemove` + `evictionSweeper.requestSweep` (30s debounce). Upsert → reindex + `fetchQueue.scheduleAll(refs)` prefetch.
- **Character events (`applyCharacterCdc`):** used by both world and per-user channels. Unchanged-TOAST guard: metadata-only UPDATEs send `payload_json=null` in WAL, so `_resolveFallbackPayload` recovers the existing payload (world row → hub char → never `{}`). Ownership transitions: `world_id==null` → orphan (remove from world view, patch hub to `worldId:null`); `owner_id==self` → full payload into hub char tab; otherwise `dropMirror`.
- **Member/world DELETE → trash vs purge:** guards in order — `isExpectedUnpublish` (Make Offline, keep local), `_ownsWorldAndLostBeta`/`_ownsAndLostBeta` (involuntary beta loss, preserve), prior role == DM → `_trashLocalWorld` (soft), else recheck role == none → `purgeLocalWorld`. All routed through stable `_campaign` because invalidating `currentWorldRoleProvider` tears down this applier's host.
- **`applyInitialState`:** invalidates shares cache, fetches snapshot; if all 8 buckets empty → mark settled + bump + return; else seed entities/characters/map_data/sessions/settings, `_seedWorldStateJson` (hydrate only keys not already present, skipping `_settingsApplyBlocklist`), `_seedMindMap` (replaceMap per map_id), mark `worldInitialSyncSettledProvider` (sticky — unblocks combat/mind-map write paths).
- **`_settingsApplyBlocklist`:** keys NOT spread from `settings_json` to top-level `data` (granular-table owners + identity/template fields): `world_id`, `world_name`, `created_at`, `entities`, `sessions`, `map_data`, `world_schema`, `template_id`, `template_hash`, `template_original_hash`, `_world_schema`.
- **Worlds event:** decodes `state_json`, but PRESERVES live granular values (`entities`, `map_data`, `sessions`, top-level settings keys, local-only `map_view`/`mind_map_views`) so a newer-but-incomplete state_json can't overwrite them.
- **JSON offload:** `_decodeJsonMaybeOffload` runs `compute()` for payloads >= `_kDecodeOffloadBytes = 4096`.

## Notes
- `_disposed` flag set on `stop()` so in-flight async events bail with a stale ref.
- Shared-package materialization (`_materializeSharedPackageLocally`) re-runs `PackageSyncService.sync` with Tier-0 lookup resolution; retries once on transient error.
