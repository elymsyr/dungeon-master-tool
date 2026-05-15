# Real-time Local-save + Cloud-sync Sistem Tasarımı

## Context

Kullanıcı `packages` / `characters` / `worlds` için **fully real-time** bir local save + cloud sync sistemi istiyor:

- Her mutation **anında lokal kaydedilmeli** (UI hızı için)
- Diğer cihazlarda **<2s** içinde görünmeli (aksiyon istemeden)
- Dünyada DM bir entity değiştirirse **tüm oyuncular <1s** içinde görmeli
- Sistem **UI thread'i bloklamayacak**, ağ I/O serileştirme her zaman arka planda olacak

### Mevcut durumdaki sorunlar

1. **Cloud sync debounce 120s/600s** — bir cihazdaki değişiklik diğerine 2+ dakika sonra gidiyor (`cloud_sync_provider.dart:74-118`).
2. **In-memory dirty tracking** — app crash'inde kuyruk kaybolur, sync olmaz (`cloud_sync_provider.dart`).
3. **worlds.state_json monolitik** — map sürükle, oturum notları gibi her small edit 1+ MB blob upload (`worlds.state_json` blob).
4. **`cloud_backups` full snapshot per world** — her change tüm world gzip JSON upload.
5. **CDC payload UI thread'de decode** (M7 finding) — char payload ~30KB jsonDecode = ~15ms frame block (`world_mirror_applier.dart`).
6. **Karakter JSON dosyalarda** — transactional değil, outbox ile atomic enqueue mümkün değil (`character_repository.dart`).
7. **DB index yok** (S1 finding) — outbox scan, entity list query slow olur.
8. **`world_packages` tablosu yok** — DM kendi homebrew paketini world'a paylaşamıyor.

### Hedef mimari

```
UI mutation
  ↓
Notifier.update (Riverpod)
  ↓
Drift TX: { local write + sync_outbox INSERT }   ← atomic
  ↓ commit
SyncEngine wakes (Drift watchPending stream)
  ↓
compute() isolate: serialize / hash
  ↓
Supabase RPC / upsert (granular table)
  ↓
Postgres trigger bumps updated_at
  ↓
Realtime CDC
  ↓
Other devices: WorldSyncService
  ↓
compute() isolate: decode payload
  ↓
WorldMirrorApplier: echo-check + patch local Drift + bumpRevision
```

---

## Plan (7 PR)

> Beta gate `isBetaActiveProvider` korunur. Yeni runtime flag `useOutboxSyncEngine` (default true beta'da) rollback için.

### PR-SYNC-0 — Karakterleri Drift'e taşı (foundation)

**Goal**: Karakterleri JSON dosyalardan Drift `characters` tablosuna geçir. Outbox + transactional enqueue için ön koşul.

**Drift schema (v8 → v9)** — yeni tablo:

```dart
// lib/data/database/tables/characters_table.dart
class Characters extends Table {
  TextColumn      get id            => text()();                    // UUID v4 PK
  TextColumn      get templateId    => text()();
  TextColumn      get templateName  => text()();
  TextColumn      get entityJson    => text()();                    // serialized Entity blob
  TextColumn      get worldId       => text().nullable()();         // null = hub-only
  TextColumn      get ownerId       => text().nullable()();         // null = unclaimed
  DateTimeColumn  get createdAt     => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn  get updatedAt     => dateTime().withDefault(currentDateAndTime)();
  @override Set<Column> get primaryKey => {id};
}
```

**Indexes**:
```sql
CREATE INDEX idx_characters_world  ON characters (world_id);
CREATE INDEX idx_characters_owner  ON characters (owner_id);
CREATE INDEX idx_characters_updated ON characters (updated_at DESC);
```

**Migration v8 → v9 bootstrap**:
1. Schema v9 — `characters` tablo create + index.
2. App startup'ta `CharacterMigrationService.migrateFromJsonIfNeeded()`:
   - `AppPaths.charactersDir` altındaki tüm `.json` dosyaları tara
   - Batch insert (chunk 100) Drift'e
   - Migration başarı flag'i SharedPreferences'a yaz: `characters_drift_migrated_v1 = true`
   - **Dosyalar silinmez** — 2 hafta rollback penceresi; PR-SYNC-6'da silinir
3. Hata kurtarma: corrupt JSON dosya logla, skip.

**Files touched / created**:
- [flutter_app/lib/data/database/tables/characters_table.dart](flutter_app/lib/data/database/tables/characters_table.dart) (new)
- [flutter_app/lib/data/database/daos/character_dao.dart](flutter_app/lib/data/database/daos/character_dao.dart) (new) + `.g.dart`
- [flutter_app/lib/data/database/app_database.dart](flutter_app/lib/data/database/app_database.dart) — schemaVersion 9, migration
- [flutter_app/lib/data/repositories/character_repository.dart](flutter_app/lib/data/repositories/character_repository.dart) — JSON file → Drift backend
- [flutter_app/lib/application/services/character_migration_service.dart](flutter_app/lib/application/services/character_migration_service.dart) (new)
- [flutter_app/lib/main.dart](flutter_app/lib/main.dart) — startup hook
- [flutter_app/lib/application/providers/character_provider.dart](flutter_app/lib/application/providers/character_provider.dart) — repo API uyumu

**Risk**:
- **High**: Migration crash → karakter erişilemez. Mitigation: JSON dosyalar silinmez; failure'da JSON path'e fallback.
- **Med**: Dosya I/O patterns değişti — performans regression riski. DevTools ile ölçüm.

**Verification**:
- Mevcut JSON karakterler app açıldığında Drift'e migrate olur.
- Karakter editor → save → Drift'te güncel row.
- Migration flag kontrolü: ikinci açılışta migrate skip.
- 50+ karakter migration <3s.

---

### PR-SYNC-1 — Outbox foundation + persistent dirty tracking

**Goal**: Persistent `sync_outbox` + `SyncEngine` worker. Eski `cloud_sync_provider` paralel çalışmaya devam eder (rollback emniyeti).

**Drift schema (v9 → v10)** — yeni tablo:

```dart
// lib/data/database/tables/sync_outbox_table.dart
class SyncOutbox extends Table {
  TextColumn      get opId           => text()();              // UUID v4 PK
  TextColumn      get entityKind     => text()();              // 'world_entity'|'world_character'|'world_state'|'world_map_data'|'world_session'|'world_settings'|'world_package'|'personal_package'|'cloud_backup_world'|'cloud_backup_package'
  TextColumn      get entityId       => text()();              // domain id
  TextColumn      get scopeId        => text().nullable()();   // world_id veya null
  TextColumn      get opType         => text()();              // 'upsert'|'delete'
  TextColumn      get payloadJson    => text()();
  IntColumn       get payloadBytes   => integer().withDefault(const Constant(0))();
  IntColumn       get attempts       => integer().withDefault(const Constant(0))();
  DateTimeColumn  get createdAt      => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn  get lastAttemptAt  => dateTime().nullable()();
  DateTimeColumn  get nextAttemptAt  => dateTime().withDefault(currentDateAndTime)();
  TextColumn      get lastError      => text().nullable()();
  @override Set<Column> get primaryKey => {opId};
}
```

**Indexes**:
```sql
CREATE INDEX idx_outbox_next_attempt ON sync_outbox (next_attempt_at, created_at);
CREATE INDEX idx_outbox_kind_id      ON sync_outbox (entity_kind, entity_id);
```

**Coalescing semantik** (`SyncOutboxDao.enqueue`):
- Aynı `(entityKind, entityId)` için bekleyen `upsert` varsa → eski satırı UPDATE, payload swap, `attempts=0`, `nextAttemptAt=now()`. Aynı opId korunur.
- Yeni `delete` gelirse → bekleyen `upsert` silinir, `delete` satırı eklenir.

**Mevcut tablolara kolon ekle** (`campaigns`, `packages`):
```dart
DateTimeColumn  get lastCloudPushAt => dateTime().nullable()();
TextColumn      get lastPushedHash  => text().nullable()();   // SHA-256 over payload
```

`lastPushedHash` ile sync engine "içerik gerçekten değişti mi" gate'i yapar — aynı state üst üste 3 kez save edilirse cloud'a sadece 1 kez gider.

**S1 indexes** — `entities`, `mind_map_nodes`, `mind_map_edges`, `sessions`, `encounters`, `combatants`, `map_pins`, `world_schemas`, `package_entities` tablolarına bu PR ile birlikte indexler eklenir (S1 finding):
```sql
CREATE INDEX idx_entities_campaign        ON entities (campaign_id);
CREATE INDEX idx_entities_category        ON entities (campaign_id, category_slug);
CREATE INDEX idx_entities_package_linked  ON entities (package_id) WHERE package_id IS NOT NULL;
CREATE INDEX idx_map_pins_campaign        ON map_pins (campaign_id);
CREATE INDEX idx_mm_nodes_campaign_map    ON mind_map_nodes (campaign_id, map_id);
CREATE INDEX idx_mm_edges_campaign_map    ON mind_map_edges (campaign_id, map_id);
CREATE INDEX idx_sessions_campaign        ON sessions (campaign_id);
CREATE INDEX idx_encounters_session       ON encounters (session_id);
CREATE INDEX idx_combatants_encounter     ON combatants (encounter_id);
CREATE INDEX idx_package_entities_package ON package_entities (package_id);
CREATE INDEX idx_world_schemas_campaign   ON world_schemas (campaign_id);
```
Tüm `CREATE INDEX IF NOT EXISTS` ile idempotent.

**SyncEngine** (`lib/application/services/sync_engine.dart`):
- Long-lived consumer; Drift `syncOutboxDao.watchPending(limit:1)` stream'i dinler.
- `_tick()` serial worker; `_running` flag ile reentrancy guard.
- Batch boyutu 20; `WHERE nextAttemptAt <= now() ORDER BY createdAt ASC LIMIT 20`.
- Her op type için handler:
  - `world_entity` → `WorldMirrorService.pushEntity`
  - `world_character` → `WorldMirrorService.pushCharacter`
  - `personal_package` → `WorldMirrorService.pushPersonalPackage`
  - `cloud_backup_*` → `CloudBackupRepository.uploadBackup`
- Retry: exponential backoff `min(300, 2^attempts)` sec.
- `attempts >= 50` → DLQ flag, UI notify.

**Connectivity**: `connectivity_plus` paketi, `ConnectivityProvider`. `online` event'inde `_tick()` tetiklenir.

**Lifecycle**: app pause → `engine.pause()`; resume → `engine.resume() + _tick()`.

**Echo suppression**: `WorldMirrorService._lastPushedAt` mevcut, korunur.

**Files touched / created**:
- [flutter_app/lib/data/database/tables/sync_outbox_table.dart](flutter_app/lib/data/database/tables/sync_outbox_table.dart) (new)
- [flutter_app/lib/data/database/daos/sync_outbox_dao.dart](flutter_app/lib/data/database/daos/sync_outbox_dao.dart) (new) + `.g.dart`
- [flutter_app/lib/data/database/app_database.dart](flutter_app/lib/data/database/app_database.dart) — v10, register, index migration
- [flutter_app/lib/data/database/tables/campaigns_table.dart](flutter_app/lib/data/database/tables/campaigns_table.dart) — lastCloudPushAt/Hash kolonlar
- [flutter_app/lib/data/database/tables/packages_table.dart](flutter_app/lib/data/database/tables/packages_table.dart) — aynı
- [flutter_app/lib/application/services/sync_engine.dart](flutter_app/lib/application/services/sync_engine.dart) (new)
- [flutter_app/lib/application/providers/sync_engine_provider.dart](flutter_app/lib/application/providers/sync_engine_provider.dart) (new)
- [flutter_app/lib/application/providers/entity_provider.dart](flutter_app/lib/application/providers/entity_provider.dart) — `update/create/delete/addEntities` Drift TX içinde outbox enqueue
- [flutter_app/lib/application/providers/character_provider.dart](flutter_app/lib/application/providers/character_provider.dart) — `_mirrorPush/_cloudBackupPush/_mirrorDelete` → outbox
- [flutter_app/lib/application/providers/save_state_provider.dart](flutter_app/lib/application/providers/save_state_provider.dart) — dynamic debounce (online: 800ms/3s, offline: 3s/10s)
- [flutter_app/lib/main.dart](flutter_app/lib/main.dart) — `ref.read(syncEngineProvider)` eager init
- `pubspec.yaml` — `connectivity_plus`

**Risk**:
- **High**: Outbox enqueue race. Mitigation: tüm enqueue `_db.transaction { mutation + outbox_insert }`. Drift TX atomic.
- **Med**: Network drain çok hızlı → Supabase rate-limit. Test zayıf bağlantıda.
- **Med**: Crash sırası TX commit boundary. Test force-kill.

**Verification**:
- Tek cihaz online world: 1 entity edit → 1s içinde Supabase `world_entities` row güncel.
- Offline 5 edit → outbox 5 row.
- Online'a dön → 5 row drain.
- App force-kill sırasında edit → restart → outbox satırı duruyor, push edilir.

---

### PR-SYNC-2 — Cloud_backups outbox + debounce tightening

**Goal**: `cloud_sync_provider`'in worldless char/package için kullandığı `cloud_backups` yolunu outbox'a taşı. Tek pipeline.

**Supabase migration**: **041_cloud_backup_idempotency.sql**
```sql
ALTER TABLE public.cloud_backups ADD COLUMN IF NOT EXISTS payload_hash TEXT;
CREATE INDEX IF NOT EXISTS idx_cloud_backups_item_hash
  ON public.cloud_backups (user_id, item_id, type, payload_hash);
```

SyncEngine upload öncesi hash check → aynı hash zaten yüklüyse upload skip.

**Files touched**:
- [flutter_app/lib/application/services/sync_engine.dart](flutter_app/lib/application/services/sync_engine.dart) — `cloud_backup_world/_package` handler + hash gate
- [flutter_app/lib/application/providers/character_provider.dart](flutter_app/lib/application/providers/character_provider.dart) — `_cloudBackupPush/_cloudBackupDelete/_flushCloudBackup` → outbox
- [flutter_app/lib/application/providers/cloud_sync_provider.dart](flutter_app/lib/application/providers/cloud_sync_provider.dart) — `_dirtyItems` + `_performSync` deprecate path, debounce 120s→5s/15s (transition kalanları için)
- [flutter_app/lib/data/repositories/cloud_backup_repository.dart](flutter_app/lib/data/repositories/cloud_backup_repository.dart) — `payload_hash` parametre

**Verification**:
- Worldless karakter edit → 2s içinde Supabase `cloud_backups` row güncel.
- Aynı edit 3 kez → upload 1 kez (hash gate).

---

### PR-SYNC-3 — worlds.state_json granular split

**Goal**: `worlds.state_json` monolitik blob'unu `world_map_data` + `world_sessions` + `world_settings` tablolarına böl. Player tarafı yeni tabloları okur; DM dual-write yapar.

**Supabase migration**: **042_world_subtables.sql**
```sql
CREATE TABLE IF NOT EXISTS public.world_map_data (
  world_id   TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  data_json  TEXT NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.world_sessions (
  id         TEXT PRIMARY KEY,
  world_id   TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  name       TEXT NOT NULL DEFAULT '',
  data_json  TEXT NOT NULL DEFAULT '{}',   -- encounters/combatants nested
  is_active  BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_world_sessions_world ON public.world_sessions (world_id);

CREATE TABLE IF NOT EXISTS public.world_settings (
  world_id      TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  settings_json TEXT NOT NULL DEFAULT '{}',
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- updated_at trigger her üçü için
CREATE TRIGGER trg_world_map_data_bump  BEFORE UPDATE ON public.world_map_data
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();
CREATE TRIGGER trg_world_sessions_bump  BEFORE UPDATE ON public.world_sessions
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();
CREATE TRIGGER trg_world_settings_bump  BEFORE UPDATE ON public.world_settings
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

ALTER TABLE public.world_map_data  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_settings  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "WMD: member read" ON public.world_map_data FOR SELECT
  USING (public.is_world_member(world_id));
CREATE POLICY "WMD: dm write" ON public.world_map_data FOR ALL
  USING (public.is_world_dm(world_id)) WITH CHECK (public.is_world_dm(world_id));
-- world_sessions / world_settings: aynı kalıp

-- Realtime publication
DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['world_map_data','world_sessions','world_settings'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
      WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
```

**Mirror + applier**:
- [flutter_app/lib/application/services/world_mirror_service.dart](flutter_app/lib/application/services/world_mirror_service.dart) — `pushMapData`, `pushSession`, `pushSettings` metodları + `fetchInitialState` genişlet
- [flutter_app/lib/application/services/world_sync_service.dart](flutter_app/lib/application/services/world_sync_service.dart) — `_mirrorTables`'a `'world_map_data', 'world_sessions', 'world_settings'` ekle
- [flutter_app/lib/application/services/world_mirror_applier.dart](flutter_app/lib/application/services/world_mirror_applier.dart) — `_applyMapData`, `_applySessionRow`, `_applySettings` event handler'ları
- [flutter_app/lib/application/services/sync_engine.dart](flutter_app/lib/application/services/sync_engine.dart) — 3 yeni op kind
- [flutter_app/lib/application/providers/campaign_provider.dart](flutter_app/lib/application/providers/campaign_provider.dart) — `_bundleAndPush` content split; mapData/sessions/settings ayrı outbox enqueue
- Map editor / combat / settings notifier'ları — mutation sonrası outbox enqueue

**Dual-write transition**: PR-SYNC-3 ilk sürümünde DM iki yere yazar (`worlds.state_json` + `world_*` tablolar). Player yeni tabloları okur (önceliklidir); `worlds` event'inden gelen `state_json`'ın mapData/sessions/settings alanları **strip edilir**. 2 hafta sonra (SYNC-6) eski path drop.

**Runtime flag**: `useGranularWorldState` (default true) — sorun çıkarsa state_json yoluna geri dön.

**Risk**:
- **High**: Applier sıralama yarışı (`worlds` + `world_map_data` aynı anda CDC). Mitigation: applier `world_map_data` her zaman wins; `worlds` state_json'dan stripped fields okur.
- **Med**: Legacy client'lar yeni tablolara yazmıyor → beta-only.

**Verification**:
- DM battle map'te token sürükle → <1s player görür.
- Session oluştur → player görür.
- Eski client (state_json) + yeni client (granular) — aynı veri.

---

### PR-SYNC-4 — Performance fixes (CDC isolate, tab switch unblock, char editor)

**Goal**: M7 + F-T1 + F-T3 finding'leri land et.

**Compute() offload** ([flutter_app/lib/application/services/world_mirror_applier.dart](flutter_app/lib/application/services/world_mirror_applier.dart)):
```dart
// top-level
String _decodeJson(String s) => jsonDecode(s);   // bu compute arg

// _charRowFromCdc + _applyWorldsEvent
final payload = await compute(_decodeJson, row['payload_json'] as String);
```
Char payload ~30KB JSON → main thread ~15ms → isolate ~3ms (M7 fix).

**Tab switch unblock** (F-T1):
- [flutter_app/lib/presentation/screens/main_screen.dart](flutter_app/lib/presentation/screens/main_screen.dart) — `ref.watch(activeCampaignSyncProvider)` → `ref.listen` (side-effect only), fast-path guard.

**Char editor field debounce** (F-T3):
- [flutter_app/lib/presentation/screens/characters/character_editor_screen.dart](flutter_app/lib/presentation/screens/characters/character_editor_screen.dart) — `entityProvider.select((m) => m.length)` instead of full watch
- [flutter_app/lib/application/providers/entity_sidebar_provider.dart](flutter_app/lib/application/providers/entity_sidebar_provider.dart) (new, F-T2.a) — top-level entity summary

**Granular providers**:
- `worldCharactersProvider(worldId).select((m) => m.length)` listener pattern
- [flutter_app/lib/presentation/widgets/entity_sidebar.dart](flutter_app/lib/presentation/widgets/entity_sidebar.dart) — filter cache (F-T2.b)

**Risk**: Low-med. F-T1/F-T3 daha önce planlanmıştı.

**Verification**:
- DevTools Timeline: tab switch build+layout <50ms.
- 50 karakter list açma >16ms frame yok.
- CDC event geldiğinde frame skip yok (`compute()` doğrulaması).
- `EXPLAIN ANALYZE` ile index scan görünmeli.

---

### PR-SYNC-5 — world_packages + share-to-world flow

**Goal**: DM kişisel paketini dünyaya paylaşır; tüm üyeler görür.

**Supabase migration**: **043_world_packages.sql**
```sql
CREATE TABLE IF NOT EXISTS public.world_packages (
  package_id    TEXT PRIMARY KEY,
  world_id      TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  package_name  TEXT NOT NULL,
  shared_by     UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  state_json    TEXT NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_world_packages_world ON public.world_packages (world_id);
CREATE UNIQUE INDEX uq_world_packages_world_name ON public.world_packages (world_id, package_name);

ALTER TABLE public.world_packages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "WP: members read" ON public.world_packages FOR SELECT
  USING (public.is_world_member(world_id));
CREATE POLICY "WP: dm writes" ON public.world_packages FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id) AND shared_by = auth.uid());

CREATE TRIGGER trg_world_packages_bump BEFORE UPDATE ON public.world_packages
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

-- Realtime publication add
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND tablename='world_packages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.world_packages;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.share_package_to_world(
  p_world_id     TEXT,
  p_package_name TEXT,
  p_state_json   TEXT
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, row_security = off
AS $$
DECLARE v_id TEXT;
BEGIN
  IF NOT public.is_world_dm(p_world_id) THEN
    RAISE EXCEPTION 'dm only' USING ERRCODE='42501';
  END IF;
  v_id := gen_random_uuid()::TEXT;
  INSERT INTO public.world_packages
    (package_id, world_id, package_name, shared_by, state_json)
  VALUES (v_id, p_world_id, p_package_name, auth.uid(), p_state_json)
  ON CONFLICT (world_id, package_name) DO UPDATE
    SET state_json = EXCLUDED.state_json, updated_at = now()
  RETURNING package_id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.share_package_to_world(TEXT,TEXT,TEXT) TO authenticated;
```

**Drift schema (v10 → v11)** — yeni local mirror tablo:
```dart
class WorldPackages extends Table {
  TextColumn      get worldId     => text().references(Campaigns, #id)();
  TextColumn      get packageId   => text()();
  TextColumn      get packageName => text()();
  TextColumn      get stateJson   => text().withDefault(const Constant('{}'))();
  DateTimeColumn  get updatedAt   => dateTime().withDefault(currentDateAndTime)();
  @override Set<Column> get primaryKey => {worldId, packageId};
}
```

**Files touched / created**:
- [flutter_app/lib/data/database/tables/world_packages_table.dart](flutter_app/lib/data/database/tables/world_packages_table.dart) (new)
- [flutter_app/lib/data/database/daos/world_package_dao.dart](flutter_app/lib/data/database/daos/world_package_dao.dart) (new) + `.g.dart`
- [flutter_app/lib/data/database/app_database.dart](flutter_app/lib/data/database/app_database.dart) — v11
- [flutter_app/lib/application/services/world_mirror_service.dart](flutter_app/lib/application/services/world_mirror_service.dart) — `shareWorldPackage`, `deleteWorldPackage`
- [flutter_app/lib/application/services/world_mirror_applier.dart](flutter_app/lib/application/services/world_mirror_applier.dart) — `world_packages` case
- [flutter_app/lib/application/services/world_sync_service.dart](flutter_app/lib/application/services/world_sync_service.dart) — `_mirrorTables.add('world_packages')`
- [flutter_app/lib/application/services/sync_engine.dart](flutter_app/lib/application/services/sync_engine.dart) — `world_package` op kind
- [flutter_app/lib/application/providers/world_packages_provider.dart](flutter_app/lib/application/providers/world_packages_provider.dart) (new)
- [flutter_app/lib/presentation/screens/packages/package_share_dialog.dart](flutter_app/lib/presentation/screens/packages/package_share_dialog.dart) (new) — DM UI

**Risk**:
- **Med**: `personal_packages` + `world_packages` duplicate görünüm. Dedupe by `package_name` + "world-shared" badge.

**Verification**:
- DM A `Goblin Pack` World X'e paylaşır → Player B `World X` paket sekmesinde görür.
- DM paketten entity siler → Player B CDC ile görür.

---

### PR-SYNC-6 — Reconcile-on-reconnect + cloud_sync_provider retire + JSON char cleanup

**Goal**: Network drop edge case polish. `cloud_sync_provider` retire. PR-SYNC-0 JSON dosyaları sil (2 hafta sonra).

**Files touched**:
- [flutter_app/lib/application/services/sync_engine.dart](flutter_app/lib/application/services/sync_engine.dart) — Connectivity reconnect → manual `_tick`, opsiyonel `client_op_id` deterministic echo
- [flutter_app/lib/application/services/world_mirror_applier.dart](flutter_app/lib/application/services/world_mirror_applier.dart) — `applyInitialState` resume sonrası `last_synced_at` kıyasla, eksik CDC için defensive fetch
- [flutter_app/lib/application/providers/cloud_sync_provider.dart](flutter_app/lib/application/providers/cloud_sync_provider.dart) — DELETE (tüm import temizle)
- [flutter_app/lib/application/providers/save_state_provider.dart](flutter_app/lib/application/providers/save_state_provider.dart) — `cloudSyncProvider.markDirty` referansları sil
- [flutter_app/lib/presentation/widgets/save_sync_indicator.dart](flutter_app/lib/presentation/widgets/save_sync_indicator.dart) — outbox-based status: row count > 0 → "syncing", attempts > 3 → "issue"
- [flutter_app/lib/application/services/character_migration_service.dart](flutter_app/lib/application/services/character_migration_service.dart) — eski JSON dosyaları sil (`charactersDir` cleanup), `_jsonCleanupVersion = 1` flag
- `worlds.state_json` dual-write disable: PR-SYNC-3 path retire — sadece granular tablolara yaz

**Risk**:
- **Med**: `save_sync_indicator` UX değişir; manual sync butonu olmalı (`syncEngine.forceTick()`).
- **Low**: cloud_sync_provider'a bağlı testler kırılır → güncelle.

**Verification**:
- 30s offline + 20 mutation → online → tümü sırayla push.
- Network drop mid-sync → outbox attempts artar, sonraki tick'te tekrar.
- JSON dosyalar silinmiş (`charactersDir` boş).

---

## Sync engine debounce stratejisi (özet)

| Bağlam | Local save trigger | Cloud push |
|--------|--------------------|------------|
| Online world (player/DM) | 800ms / 3s max | SyncEngine derhal (outbox boyunca) |
| Offline world | 3s / 10s max | SyncEngine derhal (online'a dönünce) |
| Tab close / app pause | `saveNow()` derhal | SyncEngine drain |

**Önemli**: lokal save (Drift TX) **anında**. Sadece "full campaign serialize + state_json yazımı" full-`save()` trigger geciktirilir. Outbox enqueue ise mutation'la birlikte aynı TX'te.

## Per-mutation push vs coalesced batch

| Entity kind | Strateji |
|-------------|----------|
| `world_entity` | per-mutation push |
| `world_character` (own) | per-mutation push (hot — combat HP) |
| `world_character` (DM mass edit) | coalesced bulk upsert |
| `world_state` (worlds.state_json) | coalesced; SYNC-3 sonrası çoğu mutation buraya gitmez |
| `world_map_data` | coalesced 800ms |
| `world_session` | per-session row, 800ms coalesce |
| `personal_package` | full state push |
| `world_package` | full state push |

## Conflict resolution

**Pure LWW** — server-bumped `updated_at` trigger (`tg_bump_updated_at`) karar verir. İki cihaz aynı anda HP değiştirirse son yazan kazanır. Per-field merge bu sürümde yok (kullanıcı tercihi).

---

## Critical Files

- [flutter_app/lib/data/database/app_database.dart](flutter_app/lib/data/database/app_database.dart) — schema v8 → v11 migrations
- [flutter_app/lib/application/services/sync_engine.dart](flutter_app/lib/application/services/sync_engine.dart) — yeni worker
- [flutter_app/lib/application/services/world_mirror_service.dart](flutter_app/lib/application/services/world_mirror_service.dart) — push endpoints
- [flutter_app/lib/application/services/world_mirror_applier.dart](flutter_app/lib/application/services/world_mirror_applier.dart) — CDC apply + compute() offload
- [flutter_app/lib/application/services/world_sync_service.dart](flutter_app/lib/application/services/world_sync_service.dart) — realtime subscribe + new tables
- [flutter_app/lib/application/providers/save_state_provider.dart](flutter_app/lib/application/providers/save_state_provider.dart) — dynamic debounce
- [flutter_app/lib/application/providers/entity_provider.dart](flutter_app/lib/application/providers/entity_provider.dart) — outbox enqueue hook
- [flutter_app/lib/application/providers/character_provider.dart](flutter_app/lib/application/providers/character_provider.dart) — outbox enqueue + Drift repo
- [flutter_app/lib/application/providers/cloud_sync_provider.dart](flutter_app/lib/application/providers/cloud_sync_provider.dart) — retire (SYNC-6)
- [flutter_app/lib/data/repositories/character_repository.dart](flutter_app/lib/data/repositories/character_repository.dart) — Drift backend (SYNC-0)
- `supabase/migrations/041_cloud_backup_idempotency.sql` (new, SYNC-2)
- `supabase/migrations/042_world_subtables.sql` (new, SYNC-3)
- `supabase/migrations/043_world_packages.sql` (new, SYNC-5)

## Reuse Mevcut Yapılar

- `WorldMirrorService.pushEntity/pushCharacter/pushPersonalPackage/pushWorldState` — outbox handler bunları çağırır
- `WorldMirrorService._lastPushedAt` echo suppression — korunur
- `WorldSyncService._channels` map — yeni tablolar `_mirrorTables` listesine eklenince otomatik subscribe
- `WorldMirrorApplier._onEvent` switch — yeni case'ler buraya
- `tg_bump_updated_at` Postgres trigger — yeni tablolarda da kullanılır
- `is_world_dm`, `is_world_member` RLS helper — yeni policies kullanır
- `cloud_backup_repository.uploadBackup` — outbox handler kullanır
- `connectivity_plus` (yeni pakete eklenir) — `online/offline` event'leri SyncEngine'i pingler

---

## Verification Plan (E2E)

| Senaryo | Hedef | Nasıl |
|---------|-------|-------|
| Two devices same user, char edit A → B | <2s | Stopwatch + log timestamp |
| Two players same world, DM entity edit → all | <1s | 3+ cihaz manuel test |
| Offline edit → reconnect → convergence | %100 sağkalım | Airplane mode toggle + outbox count assert |
| Network drop mid-sync | No data loss | DevTools network throttle + restart |
| 10 entity edit in 5s | No UI jank | DevTools Performance, dropped frames = 0 |
| 50-char roster open | >16ms frame yok | DevTools Frame timing |
| Two devices same char HP simultan | LWW son edit kazanır | Manuel race, server updated_at karşılaştır |
| world_packages share | DM paylaş → player saniye | Manuel integration |
| App force-kill mid-edit | Outbox restart sonrası drain | Logcat |
| Beta toggle off | Outbox dolar, push edilmez | UI toggle + outbox count |
| Tab switch under sync load | <50ms build | DevTools Timeline |
| Index gain | Char list query <5ms | `EXPLAIN ANALYZE` Drift |
| PR-SYNC-0 char migration | 50+ char <3s | Stopwatch |

**Otomatize test dosyaları**:
- `test/data/database/sync_outbox_dao_test.dart` — coalescing + ready ordering
- `test/application/services/sync_engine_test.dart` — retry/backoff, offline replay
- `test/data/database/migration_v8_to_v11_test.dart` — Drift migration smoke
- `test/data/repositories/character_repository_drift_test.dart` — SYNC-0 backend

---

## Risks & Rollback

| Risk | Etki | Azaltma |
|------|------|---------|
| Outbox enqueue race (TX commit, outbox INSERT olmadı) | Veri kaybı | Tüm enqueue `_db.transaction { mutation + outbox_insert }` |
| RLS bug (DM kontrolü yanlış SQL) | Player veri bozar | Mevcut `is_world_dm` helper kullan, 4-göz review |
| Schema split data drift (PR-SYNC-3) | mapData iki yere yazılır → race | Applier `world_map_data` her zaman wins; `worlds` event state_json strip eder |
| Outbox flood (1000 mutation cycle) | DB büyür | Coalescing + payload_hash gate, DLQ limit 50 |
| Engine deadlock | Push durur | Serial worker, `_running` flag |
| connectivity_plus crash | Push boşa gider | Exception wrap, fallback `_paused=true` |
| Beta flag karışıklığı | Non-beta accidentally cloud yazar | Enqueue'da `authProvider == null OR !isBetaActive` check |
| Drift v8→v9/v10/v11 migration | "no such column" runtime | `addColumn` step + `customStatement IF NOT EXISTS` |
| PR-SYNC-0 char migration crash | Karakter erişilemez | JSON dosyalar silinmez (2 hafta), failure → JSON fallback |

### Feature flag / rollout

1. **Beta gate korunur** (`isBetaActiveProvider`).
2. **`useOutboxSyncEngine`** (default true beta'da) — issue çıkarsa false → eski path canlı (SYNC-1+2 paralel faz).
3. **`useGranularWorldState`** (PR-SYNC-3) — dual-write toggle, sorunlu çıkarsa state_json yoluna geri dön.
4. Her PR landed → 1 hafta beta test → bug fix → next PR. Toplam ~10 hafta.

### Rollback (PR bazlı)

| PR | Rollback |
|----|----------|
| SYNC-0 | Drift v9 → v8 değil — char migration flag false; JSON fallback aktif; characters table dururu (boş) |
| SYNC-1 | `useOutboxSyncEngine=false`; eski mirror.pushX yine aktif (paralel) |
| SYNC-2 | `cloud_backup_*` op kind handler kaldır → eski 120s/600s path |
| SYNC-3 | `useGranularWorldState=false` → state_json path aktif |
| SYNC-4 | Index drop kolay; perf fix revert |
| SYNC-5 | `useWorldPackages=false` — share dialog gizle |
| SYNC-6 | `cloud_sync_provider` git revert; JSON char cleanup revert (dosyalar zaten silinmedi flag false ise) |
