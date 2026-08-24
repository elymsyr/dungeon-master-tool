---
type: file-note
domain: data-layer
path: flutter_app/lib/data/database/app_database.dart
layer: data
language: dart
status: stable
updated: 2026-08-24
tags: [file]
---

# `app_database.dart`

> [!abstract] Primary Purpose
> The `@DriftDatabase` core — `AppDatabase`, a per-user SQLite (Drift) database and **the source of truth for everything the app owns**. Schema version is **12** ("fresh-cut": all v1–v11 migration steps were deleted; any pre-v12 file is renamed to a forensic backup and a fresh v12 DB is created). It registers the Drift tables + DAOs, applies hot-path indexes, tunes PRAGMAs, idempotently creates the raw side tables that codegen deliberately avoids, and drops the tables retired with cloud sync.

> [!warning] Artık Postgres'in aynası DEĞİL (2026-08-24)
> Tablo adları Supabase'deki karşılıklarıyla aynı kalsa da ilişki tersine döndü: yerel Drift kaynak-doğru, buluta giden tek şey DM'in paylaşımları ([[Share-Broadcast-Flow]]). `SyncOutbox` ve `PersonalPackages` kaydı kaldırıldı; `_retiredTablesDDL` eski dosyalardaki `sync_outbox` / `sync_telemetry` / `bm_mark_ops_local` / `personal_packages` tablolarını `beforeOpen`'da düşürür. **`schemaVersion` 12'de kalır** — bump etmek her kullanıcının DB'sini sıfırlardı.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none directly. Opened via `_openConnectionForUser(userId)` using `AppPaths.dataRoot`; `userId` from `activeUserIdProvider` (in `database_provider.dart`).
- Reads (DAOs / Drift tables): all registered tables (see list below) + raw side tables `asset_refs`, `migration_progress`, `lan_paired_devices`.
- Supabase / CDC subscribed: none (this is the local store; the share channel's inbound apply targets a handful of these tables — see [[world_mirror_applier]]).
- Events consumed: none.
- Triggers (timers, connectivity, lifecycle): `beforeOpen` runs on every open; `onCreate`/`onUpgrade` on schema (re)create.

**Outputs**
- Providers / public API exposed: `AppDatabase` (default + `.forUser(userId)` + `.forTesting(e)` ctors); all DAO getters (`worldsDao`, `worldEntitiesDao`, `combatDao`, `trashDao`, …). Exposed via `appDatabaseProvider` (`database_provider.dart`).
- Writes (Drift tables): all.
- Supabase pushed / RPC called: none.
- Events emitted: none.

## Dependencies & Links
- Depends on: `app_database.g.dart` (codegen), `AppPaths`, the `tables/` family ([[tables-worlds]], [[tables-combat]], [[tables-packages]], [[tables-sync]]), and all DAOs ([[daos-index]], plus standalone [[worlds_dao]], [[world_entities_dao]], [[combat_dao]], [[world_members_dao]], [[world_invites_dao]], [[world_map_data_dao]], [[map_pins_dao]]).
- Used by: [[world_repository_impl]], [[character_resolver]] (read-time via `world_characters`), [[repositories-index]], DAO consumers across all domains.
- Domain map: [[Data-Layer]]
- System flow: [[Share-Broadcast-Flow]]
- Spec / reference: `docs/full_drift_migration_plan.md` (PR-D0 fresh-cut)

## Key Logic / Variables
- **Schema v12**, tables registered in `@DriftDatabase`:
  - World group: `Worlds, WorldMembers, WorldInvites, WorldEntities, WorldCharacters, WorldMindMapNodes, WorldMindMapEdges, WorldSessions, WorldMapData, WorldSettings, WorldPackages` ([[tables-worlds]]).
  - Sharing/packages: `EntityShares, CharacterClaimPool, Packages, PackageSchemas, PackageEntities, InstalledPackages` ([[tables-packages]]).
  - Trash: `TrashItems` ([[tables-sync]]).
  - Combat/map (local-only): `Encounters, Combatants, CombatConditions, MapPins, TimelinePins` ([[tables-combat]]).
- **DAOs** registered: Worlds, WorldMembers, WorldInvites, WorldEntities, WorldCharacters, WorldMindMap, WorldSessions, WorldMapData, WorldSettings, WorldPackages, EntityShares, CharacterClaimPool, Packages, InstalledPackages, Trash, Combat, MapPins, TimelinePins.
- **Side tables** (`_sideTablesDDL`, raw SQL, `CREATE TABLE IF NOT EXISTS`, run in `beforeOpen`, no schema bump): `asset_refs` (AssetRef→owner-row graph for eviction sweeper), `migration_progress` (F11 raw-path migrator resume state, also gates one-time repairs), `lan_paired_devices` (kalıcı LAN cihaz eşleşmeleri).
- **Retired tables** (`_retiredTablesDDL`, `DROP TABLE IF EXISTS`, same `beforeOpen` pass): `sync_outbox`, `sync_telemetry`, `bm_mark_ops_local`, `personal_packages` — bulut sync ile birlikte gittiler. Listeye eklemek serbest; bir satır ÇIKARMAK eski kurulumlarda tabloyu geri getirmez, sadece temizliği durdurur.
- **PRAGMA tuning** (every open): `journal_mode=WAL`, `synchronous=NORMAL`, `temp_store=MEMORY`, `mmap_size=64MB`, **`foreign_keys=OFF`** — lets CDC apply land out-of-order events without parent-first ordering; parent-exists checks are done at app level on apply.
- **Index block** `_v12Indexes` (S1 perf): hot-path indexes incl. `idx_world_entities_world`, `idx_world_entities_category (world_id, category_slug)`, `idx_world_characters_owner/updated`, `idx_outbox_next_attempt (next_attempt_at, created_at)`, `idx_outbox_table_pk (target_table, target_pk, op_type)` for outbox coalescing, `idx_trash_kind_deleted`.
- **`beforeOpen` one-time repairs** (gated via `migration_progress`): `subspecies_reclassify_v1` promotes legacy `species` rows whose description starts `*Subspecies of X.*` to `category_slug='subspecies'` + injects `parent_species_ref` softRef via `json_set`; plus best-effort `trashDao.purgeOlderThan(now-30d)`.
- **DB file path / fresh-cut** (`_openConnectionForUser`): `AppPaths.dataRoot/db/dmt.sqlite` (or `.../users/{userId}/db/dmt.sqlite`). Legacy `getApplicationSupportDirectory/DungeonMasterTool/...` file copied once (marked `.moved_to_dataroot`). Any pre-v12 file is renamed to `dmt.sqlite.legacy.<unix-ms>` (marker `.v12_cut_applied`), kept 30 days then purged. Uses `NativeDatabase.createInBackground`.
- **⚠️ Fresh-cut kesİmİ (O4, 2026-08-15 düzeltildi) — veri kaybettiriyordu.** İşaretçi (`.v12_cut_applied`) yalnızca *kesim sırasında* yazılıyordu; sıfırdan yaratılan bir DB için hiç yazılmıyordu. Sonuç: yeni dosya bir sonraki açılışta "işaretsiz" görünüyor ve kesim **onun üstünde** çalışıyordu. Ölçüm: `AppDatabase.forUser('u1')` — ilk oturum **1 satır**, ikinci oturum **0 satır**. Aynı tuzak [[guest_promotion_service]]'in terfisini de yiyordu (kopyalanan DB işaretçisiz geliyor). Düzeltme: dosya yokken de (yani Drift'in birazdan yaratacağı dosya tanım gereği v12 iken) işaretçi hemen yazılıyor; gerçekten pre-v12 olan dosyalar için kesim aynen duruyor. Test: `test/application/services/guest_account_switch_test.dart` — iki vaka doğrudan bunu tutuyor ve **gerçek açılış yolundan** (`AppDatabase.forUser`) geçiyor; `forTesting` bu fonksiyonu atladığı için O3'ün testleri hatayı göremiyordu.

## Notes
- Companion `database_provider.dart`: `activeUserIdProvider` (StateProvider) + `appDatabaseProvider` (Provider) — changing the active user opens a new user-scoped DB and disposes the old one, cascade-invalidating all downstream DAO/repo providers.
- Generated `app_database.g.dart` is ~872 KB — do not read directly; rely on this note + table notes.
- `foreign_keys=OFF` is intentional and load-bearing for CDC; manual cascades live in DAOs (e.g. `CombatDao.deleteEncounter`).
