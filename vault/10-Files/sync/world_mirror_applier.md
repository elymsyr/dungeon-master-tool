---
type: file-note
domain: sync
path: flutter_app/lib/application/services/world_mirror_applier.dart
layer: application
language: dart
status: stable
updated: 2026-09-23
tags: [file]
---

# `world_mirror_applier.dart`

> [!abstract] Primary Purpose
> The inbound consumer of the **DM's share channel** — the counterpart to `[[world_mirror_service]]`'s push side. Subscribes to `WorldSyncService.events`, batches them in a 16 ms window, and applies each event to local state. Five tables only: the projection manifest, shared cards (writing their `payload_json` bodies straight into the campaign blob), player characters, DM-shared packages, and membership — plus `worlds` meta for delete → trash/purge.

> [!warning] Tam dünya aynası kaldırıldı (2026-08-24)
> Dosya ~1540 satırdan ~900'e indi. `world_entities`, `world_map_data`, `world_sessions`, `world_settings`, `world_mind_map_*` handler'ları ve `applyInitialState`'in tam-dünya çekimi silindi. Paylaşılan kartın gövdesi artık `entity_shares.payload_json`'dan geliyor — `fetchEntity` round-trip'i yok. Bkz. [[Share-Broadcast-Flow]].

## Inputs / Outputs
**Inputs**
- Constructor: `Ref ref`, `WorldMirrorService mirror`, `WorldSyncService sync`.
- Subscribed: `sync.events` (`WorldSyncEvent` stream) → `_EventBatcher.add`.
- Reads: `mirror.isEchoOf*` / `isExpectedUnpublish` / `isExpectedCharDelete`, `pendingWriteBufferProvider.isPending`, `authProvider`.
- `applyInitialState(worldId)` pulls `mirror.fetchInitialState` → `(characters, shares, projection)`; CDC only carries changes made after the subscription, so this seed is load-bearing. The DM passes `withShares: false` (Faz 5f): it never applies share payloads, so they aren't fetched.

**Outputs**
- Mutates active campaign blob via `activeCampaignProvider.notifier` (captured at construction as `_campaign`, a stable `ActiveCampaignNotifier`).
- Bumps `campaignRevisionProvider` (`_bumpRevision` → triggers UI rebuilds, coalesced per batch).
- Applies to `worldCharactersProvider(worldId)` and `characterListProvider` (`applyMirror`/`removeMirror`/`dropMirror`).
- Writes Drift: `worldMindMapDao` (nodes/edges), `worldPackagesDao`, plus repo persistence (`saveSettingsPatch`, `saveMapData`, `saveSessions`, `saveSession`, `deleteSession`).
- Sets `worldInitialSyncSettledProvider`, `onlineProjectionProvider`, `worldMembersProvider`.
- Schedules `referenceIndexerProvider` reindex, `fetchQueueProvider` prefetch, `evictionSweeperProvider` sweep.

## Dependencies & Links
- Depends on: [[world_meta_sync]], [[world_mirror_service]], [[pending_write_buffer]], [[world_sync_service]], [[package_sync_service]], [[package_import_service]], [[campaign_provider]], `world_characters_provider`, [[projection_state]]
- Used by: world-open wiring (the host provider that watches `currentWorldRoleProvider`), per-user (personal) sync applier (calls `applyCharacterCdc` / `purgeLocalWorld`)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[Share-Broadcast-Flow]]
- Spec / reference: [[migrations-online-worlds]]

## Key Logic / Variables
- **`_EventBatcher`** (window `_kBatchWindow = 16ms`): coalesces idempotent last-writer-wins rows by PK into a `LinkedHashMap` (recency-ordered) — keys: `world_entities/world_sessions/world_characters` by `id`, `world_map_data/world_settings` by `worldId`, `world_packages` by `package_id`. `world_members`/`worlds`/`entity_shares` are NOT coalesced (order matters) → `_ordered` list. On `_fire`, drains coalesced-then-ordered, calls `onFlush`; re-arms a new window if events arrived mid-flush.
- **`_flushBatch`:** applies events sequentially (shared `data` Map — parallel would corrupt), suppresses per-event `_bumpRevision` (`_suppressRevisionBump`), emits one `_doBumpRevision` at window end if `_revisionDirty`.
- **Dispatch `_onEvent`:** first `if (mirror.isEchoOf(e)) return` (self-echo skip), then switch on `e.table` → 12 cases: `world_entities`, `world_characters`, `worlds`, `entity_shares`, `world_members`, `world_map_data`, `world_sessions`, `world_settings`, `world_packages`, `world_projection`, `world_mind_map_nodes`, `world_mind_map_edges`.
- **CDC race guard:** every applier checks `_buffer.isPending(key)` (`entity:$worldId:$id`, `character:$id`, `settings:$worldId:map_data`, `settings:$worldId:$subkey`) and bails if the user has an un-flushed local edit.
- **Entity events:** maintain `data['entities']` map via `_entityRowToBlob` (decodes images/tags/pdfs/attributes columns back to blob). Delete → `referenceIndexer.scheduleRemove` + `evictionSweeper.requestSweep` (30s debounce). Upsert → reindex + `fetchQueue.scheduleAll(refs)` prefetch.
- **Character events (`applyCharacterCdc`):** used by both world and per-user channels. Unchanged-TOAST guard: metadata-only UPDATEs send `payload_json=null` in WAL, so `_resolveFallbackPayload` recovers the existing payload (world row → hub char → never `{}`). Ownership transitions: `world_id==null` → orphan (remove from world view, patch hub to `worldId:null`); `owner_id==self` → full payload into hub char tab; otherwise `dropMirror`.
- **Member/world DELETE → trash vs purge:** guards in order — `isExpectedUnpublish` (Make Offline, keep local), `_ownsWorldAndLostBeta`/`_ownsAndLostBeta` (involuntary beta loss, preserve), prior role == DM → `_trashLocalWorld` (soft), else recheck role == none → `purgeLocalWorld`. All routed through stable `_campaign` because invalidating `currentWorldRoleProvider` tears down this applier's host.
- **`applyInitialState`:** invalidates shares cache, `_applyWorldMeta(worldId)` (oyuncu tarafı: `mirror.fetchWorldMeta` → `metadata` yaması — DM dünya kapalıyken açıklamayı değiştirdiyse CDC bunu hiç taşımazdı), fetches snapshot; if all 8 buckets empty → mark settled + bump + return; else seed entities/characters/map_data/sessions/settings, `_seedWorldStateJson` (hydrate only keys not already present, skipping `_settingsApplyBlocklist`), `_seedMindMap` (replaceMap per map_id), mark `worldInitialSyncSettledProvider` (sticky — unblocks combat/mind-map write paths).
- **Worlds event (UPDATE/INSERT):** artık yalnız kartın görünen yüzünü taşır — `meta_json` → `decodeWorldMeta` → aktif blob'un `metadata`'sı + `_persistSettingsToDrift` (hub listesi Drift'ten okuyor, dünya kapalı olsa da yazılır). DM'de bail: kendi push'unun echo'su, kapağı yerel yoldan `dmt-public://` ref'e çevirip DM'i kendi dosyasından koparırdı. `state_json` dalı 093 ile düştü (kolon zaten 077'de silinmişti).
- **JSON offload:** `_decodeJsonMaybeOffload` runs `compute()` for payloads >= `_kDecodeOffloadBytes = 4096`.

## Notes
- `_disposed` flag set on `stop()` so in-flight async events bail with a stale ref.
- Shared-package materialization (`_materializeSharedPackageLocally`) re-runs `PackageSyncService.sync` with Tier-0 lookup resolution; retries once on a one-off error.

## Medya (2026-09-08 → Faz 5d, 2026-09-23)
- **Rol DM ise gövde enjeksiyonu tümüyle atlanır** (`_isDm`). Payload `dmt-content://` ref taşıyor; DM'e geri yazmak onun **yerel dosya yollarını ezerdi**.
- Talep-üzerine medya **kalktı (Faz 5d)**: applier artık ne eksik sha bildiriyor (`MissingMediaReporter`) ne de DM tarafında `missing_shas` → `serve` çağırıyor; oturum kapısı (`isSessionOpen`) da gitti. Baytlar multiplayer açılınca zaten dünyanın bulut medyasında ([[world_media_sync]]); oyuncu görseli çizerken [[asset_ref_resolver]] imzalı URL'le çeker. Bkz. [[Media-Storage-Tiers]].
