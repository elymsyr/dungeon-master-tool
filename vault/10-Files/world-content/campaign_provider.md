---
type: file-note
domain: world-content
path: flutter_app/lib/application/providers/campaign_provider.dart
layer: application
language: dart
status: stable
updated: 2026-09-24
tags: [file]
---

# `campaign_provider.dart`

> [!abstract] Primary Purpose
> Riverpod orchestration layer for "worlds" (campaigns). Owns the `activeCampaignProvider` StateNotifier that holds the currently-open world's full in-memory data map, plus the hub-list / metadata / trash providers. Drives world open/swap, create, delete, purge, template-update, and CDC-driven world removal — wiring the row-level repository to cloud sync, role gating, media cleanup, and marketplace listings.

## Inputs / Outputs
**Inputs**
- Providers watched / deps: `campaignRepositoryProvider` (-> `WorldRepositoryImpl`), `appDatabaseProvider`, `authProvider`, `onlineWorldIdsProvider`, `worldRoleProvider(worldId)`, `currentWorldRoleProvider`, `syncEngineProvider`, `worldMirrorApplierProvider`, `worldMirrorServiceProvider`, `worldMembershipServiceProvider`, `pendingWriteBufferProvider`, `preWarmOrchestratorProvider`, `cloudBackupRepositoryProvider`, `entityMediaCleanupServiceProvider`, `marketplaceCleanupServiceProvider`, `marketplaceCoverSyncServiceProvider`, `characterListProvider`.
- Reads (DAOs): `worldsDao`, `worldSettingsDao`, `worldPackagesDao`, `trashDao`, `worldMembersDao`, `worldInvitesDao`.
- Supabase / CDC: direct `worlds` table `select` (cloud-has-world check); CDC removal entry points (`purgeWorldById`/`trashWorldById`) invoked by `WorldMirrorApplier`.
- Triggers: world open (`beginLoad`/`completeLoad`), metadata edit, CDC world-removal.

**Outputs**
- Providers exposed: `campaignRepositoryProvider`, `campaignInfoListProvider`, `activeCampaignProvider` (`ActiveCampaignNotifier`), `activeWorldNameProvider`, `activeCampaignLoadingProvider`, `campaignRevisionProvider`, `campaignMetadataProvider(worldId)`, `worldPackageNamesProvider`, `trashListProvider`, plus top-level helpers `ensureWorldLocalById`, `updateCampaignMetadata`.
  - **`campaignListProvider` kalktı** (Faz 2.5) — isim listesi aynı adı taşıyan iki dünyada belirsiz. Çağıranlar `campaignInfoListProvider`'a ((id, name, templateName)) geçti.
- Writes (Drift): via repo — `worlds`, `world_settings`, `world_entities`; reads `world_packages`, `trash_items`.
- Supabase pushed: `enqueueWorldSettings` (full settings blob) + `forceTick`; `unpublishWorld` on delete/purge.
- Events: bumps `campaignRevisionProvider` (in-place data mutation signal).

## Dependencies & Links
- Depends on: [[world_repository_impl]], [[worlds_dao]], [[world_schema]], `sync_engine.dart` (kaldırıldı), [[world_mirror_applier]], [[world_mirror_service]], [[world_membership_service]], [[pending_write_buffer]], [[auth_provider]], [[entity_media_cleanup_service]], [[marketplace_cover_sync_service]], [[world_role]]
- Used by: hub UI, world screen, [[entity]] notifier, [[character_resolver]] (orphan-on-delete via `characterListProvider`)
- Domain map: [[World-and-Content]]
- System flow: [[Share-Broadcast-Flow]]
- Spec / reference: [[Sync-and-Realtime]]

## Key Logic / Variables
- **`ActiveCampaignNotifier.state` dünya İD'sidir** (Faz 2.5; eskiden addı). Görünen ad `activeWorldNameProvider`'dan okunur — başlık/menü oradan besleniyor. `ui_state` dünya görünümleri, `dbRecentEntitiesProvider` ve marketplace `localId` de artık bu id'yi anahtar alıyor. **İstisna:** paket ekranı bu provider'ı kendi ProviderScope'unda paket ADIYLA override ediyor; orada değer "açık içeriğin anahtarı" demek ve adapter repo onu paket adı olarak okuyor.
- `_data` (the full world blob) mutating in-place does NOT fire Riverpod listeners. Mutating `_data` in-place does NOT fire Riverpod listeners, so it bumps `campaignRevisionProvider` (monotonic int) to make `worldSchemaProvider`/`entityProvider` re-read without a full notifier-recreation cascade.
- **Open is two-phase**: `beginLoad(worldId)` synchronously flips `state` + clears `_data` + sets `activeCampaignLoadingProvider=true` (optimistic, same frame as tap; downstream falls back to default schema/empty entities). `completeLoad()` flushes the prior world's `pendingWriteBufferProvider`, loads new `_data`, bumps revision, then for ONLINE worlds AWAITs `_awaitCloudHydrate` with an **8s timeout** (prevents Device-B opening on stale local snapshot) then bumps revision again. Pre-warms critical media fire-and-forget.
- **`sweepUnusedMedia()`** — dünyanın `media/` + `files/` klasöründeki referanssız dosyaları siler ([[unused_media_sweeper]]). `completeLoad` sonunda fire-and-forget, kapanışta `main_screen._exitToHub` içinde pending flush'tan **sonra** await'li. Seçilen her dosya artık dünya klasörüne kopyalandığı ([[local_media_localizer]]) ama kaldırma yolları yalnız bulut nesnesini sildiği için gerekli.
- **`saveSettingsPatchLocalOnly` → `touchWorld: false`** — viewport pan/zoom `worlds.updated_at`'i bump etmez; etseydi birleştirmede (o zaman LAN, şimdi `.dmtz`) hiç içerik düzenlemeyen cihaz LWW'yi kazanıp karşı tarafın işini ezerdi.
- **`_settingsTopKeyBlocklist`** (also `WorldRepositoryImpl._typedTopKeys`): `world_id, world_name, created_at, entities, sessions, world_schema, template_id, template_hash, template_original_hash` — everything else rides in `world_settings.settings_json`.
- **DM gate**: cloud `enqueueWorldSettings` only fires for `WorldRole.dm` (prefers cached sync role `valueOrNull` to avoid suspending combat/settings on a network round-trip; falls back to async). Non-DM degrades to local-only write (pre-empts RLS 42501 spam).
- **Row-level API**: `saveEntity`/`deleteEntity` (single `world_entities` row + touch), `saveSettingsPatch` (read-merge-write JSON + cloud enqueue), `saveSettingsPatchLocalOnly` (motion-class: viewport/pan/zoom — local Drift only, no outbox).
- **Template hash bookkeeping** (`applyTemplateUpdate`): `template_hash` <- current content hash; `template_original_hash` backfilled to lineage hash; clears `template_dismissed_hash`/`template_updates_muted`. Hash gate skips the expensive `deepCopyJson(toJson())` on a no-op match.
- **CDC removal**: `purgeWorldById`/`trashWorldById` artık doğrudan `purge`/`delete`'e id geçiyor — isim çözümü (`resolveWorldName`) kalktı. Must route cache invalidation through `_worldCacheInvalidatorProvider` (a no-watch Provider) — invalidating role/list providers via the notifier's own ref throws `CircularDependencyError` because `currentWorldRoleProvider` transitively depends on `activeCampaignProvider`.
- **delete vs purge**: `delete` snapshots to trash then cascades; `purge` is hard-delete bypassing trash (online leave/kick). Both orphan bound characters first (re-anchoring SRD refs to bundled stable UUIDs) via `orphanForWorld(worldId, entities)` — **world id, ad değil**: ad geçilirse `c.worldId == worldId` hiçbir zaman tutmaz ve fonksiyon sessizce hiçbir şey yapmaz; 2026-09-02'ye kadar öyleydi. Tuzağın kaynağı `WorldRepositoryImpl.create`'in **ad** döndürmesiydi; Faz 2.5'te id döndürmeye başladı ve `delete`/`purge` zaten id alıyor, then cloud-delete (rethrows on failure so UI cancels the local delete), then best-effort cloud media + marketplace cleanup, and finally `UiStateNotifier.forgetWorld(campaignName)`.
- **Görünüm izleri silinmeli** (2026-09-12): açık kartlar, panel filtreleri/sıralaması/araması ve `WorldViewState` (aktif sekme + **açık PDF yolları**) SharedPreferences'ta duruyor ve `_purgeWorld` onlara dokunmuyor; `delete` ve `purge` ikisi de `forgetWorld` çağırır. **Faz 2.5'ten beri anahtar dünya id'si** — eskiden addı, yani aynı adla oluşturulan bir sonraki dünya silinenin açık kartlarını miras alabiliyordu. Eski ad anahtarlı kayıtlar artık eşleşmiyor: panel filtresi/açık kart gibi tercihler bir kez sıfırlanır, veri kaybı değil.
- **`handleExpectedUnpublish`**: "make offline" — keeps ALL local Drift data, only drops online artifacts (members, invites).

## Notes
- `campaignInfoListProvider` has a known N+1 (per-world `worldSettingsDao.get`) — accepted because world count is small (<20).
- Interface still `Map<String,dynamic>`-based and named `CampaignRepository`; rename to `WorldRepository` deferred (PR-D6).
