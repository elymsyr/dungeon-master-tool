# Online İkinci Ekran (Second Screen) — Mimari

Tarih: 2026-05-21
Durum: implementasyon — **Faz A+B+C tamam** (manifest + AssetRef köprüsü +
player render, 2026-05-22)
İlgili: `second_screen_dm_player_view_spec_may21.md` (view/UX spec),
medya redesign planı `~/.claude/plans/online-backup-zelli-ini-de-i-tirece-iz-hidden-puzzle.md`

## 1. Bağlam — bugün ne var

Offline ikinci ekran çalışıyor:

- DM `desktop_multi_window` ile ikinci pencere açar — `projection_output_window.dart:28`.
- `ProjectionController` (`StateNotifier<ProjectionState>`) DM tarafında — `projection_provider.dart:32`.
- `ProjectionState` = `ProjectionItem` listesi: `ImageProjection`, `EntityCardProjection`,
  `BattleMapProjection`, `PdfProjection` (stub), `BlackScreenProjection` — `projection_item.dart:11`.
- Transport: JSON over MethodChannel IPC — `projection_ipc.dart` (`projection.apply`
  full/patch, `projection.battleMapPatch`).
- Oyuncu penceresi ayrı isolate: `PlayerProjectionStateNotifier` salt-okunur render —
  `player_window_state_provider.dart:12`.
- Snapshot'lar push anında serialize edilir: `EntitySnapshot`, `BattleMapSnapshot`.

`ProjectionOutput` soyutlaması zaten var — `activate/deactivate/pushFull/pushPatch/
pushBattleMapPatch`. İki implementasyon: `ProjectionOutputWindow` (IPC),
`ProjectionOutputScreencast` (platform Presentation). Factory `projection_output_provider.dart:34`.

Eksik:

- Online oyuncu hiçbir projeksiyon görmüyor. `PlayerSecondScreenTab` placeholder —
  `player_second_screen_tab.dart:5` ("PR-O9+ ile doldurulacak").
- Snapshot'lar ham `File(path)` taşıyor — uzak oyuncu çözemez (`image_projection_view.dart`
  raw `Image.file`).
- Geri kanal yok — oyuncu DM'e bir şey gönderemez.

## 2. Hedef

DM'in paylaştığı içerik (entity card, resim, battle map) uzak oyunculara Supabase
realtime üzerinden ulaşsın; oyuncu `PlayerSecondScreenTab` içinde render etsin. Battle
map'te oyuncular çizim yapsın + kendi token'ını oynatsın.

## 3. Tasarım ilkeleri (kilitli)

1. **Tek state modeli, iki transport.** `ProjectionState`/`ProjectionItem` JSON modeli
   aynen kullanılır. IPC çıkışı (offline pencere) ile online çıkış aynı snapshot'ı yer.
2. **Online = 4. `ProjectionOutput`.** Yeni `ProjectionOutputMode.online` +
   `ProjectionOutputOnline`. `pushFull/pushPatch/pushBattleMapPatch` Supabase'e yazar.
   Mevcut `ProjectionController` mantığı değişmez — sadece yeni bir çıkış.
3. **Çoklu çıkış fan-out.** DM aynı anda offline pencere + online oyuncular isteyebilir.
   `ProjectionController` tek `ProjectionOutput?` yerine liste tutar; push'lar hepsine
   yayılır.
4. **View state ASLA senkronize edilmez.** Zoom/pan/drag her client'ta yerel. Offline'daki
   `viewportLocked` (BattleMapProjection) kavramı online'da yok — online viewport daima
   per-client. (`battle_map_notifier.dart` `ViewTransform` zaten local-only + `_viewMemory`.)
5. **DM paylaşmak için upload yapamaz.** Projeksiyon kaynakları sınırlı: entity kart
   resimleri, medya galerisi (zaten yüklü medya), battle map. Ad-hoc dosya seçici yok →
   projekte edilen her medyanın bir `AssetRef`'i zaten var.
6. **Tüm medya `AssetRef`.** Snapshot'lardaki ham `File(path)` → `AssetRef` string. Uzak
   oyuncu counted (R2) / free (Supabase) / transient ref'i kendi resolver'ı ile çözer.
   Bu, medya redesign'ın projeksiyon köprüsü.
7. **DB-backed manifest, late-joiner dayanıklı.** "Ekranda ne var" efemeral broadcast
   değil, CDC mirror tablosu. Geç katılan / yeniden bağlanan oyuncu subscribe anında
   satırı okur. (Transient tasarımındaki aynı ders: realtime byte-stream değil.)

## 4. Transport mimarisi

İki katman:

### 4a. Projeksiyon manifesti — DB tablo, CDC (düşük frekans)

"Şu an ne paylaşılıyor." `world_projection` tablosu, dünya başına tek satır,
`state_json` = `ProjectionState.toJson()`. `world_sync_service.dart` `_mirrorTables`
listesine eklenir → mevcut `dmt:world:$worldId` kanalı CDC'siyle replike olur.
`ProjectionOutputOnline.pushFull/pushPatch` bu satırı upsert eder. Oyuncu
`world_mirror_applier.dart`'a yeni `case 'world_projection'` ile alır.

### 4b. Canlı etkileşim katmanı — battle map collab

Çizim ve token hareketi iki yönlü + sık. Commit edilmiş veriler DB tablo + CDC
(late-joiner dayanıklı). İsteğe bağlı in-progress preview (parmak basılıyken)
Supabase Realtime **Broadcast** ile efemeral — Faz F cilası.

| Veri | Transport | Kalıcılık |
|---|---|---|
| Manifest (ne paylaşılıyor) | `world_projection` tablo + CDC | kalıcı |
| Commit çizim / ölçüm | `world_battlemap_marks` tablo + CDC | kalıcı |
| Token pozisyonu | `move_own_token` RPC → `world_map_data` CDC | kalıcı |
| In-progress stroke / drag preview | Realtime Broadcast (efemeral) | yok (Faz F) |

## 5. Veri modeli — yeni migration'lar

Migration 053-058 kullanımda (medya redesign + diğer iş); yeni tablolar
append-only sonrası: **059 → 060**.

### Migration 059 `online_projection_manifest.sql`

```sql
create table public.world_projection (
  world_id    text primary key references public.worlds(id) on delete cascade,
  state_json  text not null default '{}',
  updated_by  uuid references auth.users(id),
  updated_at  timestamptz not null default now()
);
-- RLS: SELECT = world member (is_world_member); INSERT/UPDATE/DELETE = world DM (is_world_dm).
-- supabase_realtime publication + REPLICA IDENTITY FULL (DELETE/blackout iletimi için).
-- NOTIFY pgrst, 'reload schema';
```

`world_settings` ile aynı şekil — combat_state blob'una coupling olmasın diye ayrı tablo.

### Migration 060 `online_battlemap_collab.sql`

```sql
create table public.world_battlemap_marks (
  id           uuid primary key default gen_random_uuid(),
  world_id     text not null references public.worlds(id) on delete cascade,
  encounter_id text not null,
  author_id    uuid not null references auth.users(id) on delete cascade,
  kind         text not null check (kind in ('stroke','ruler','circle')),
  color_hex    text not null,
  payload_json text not null,        -- nokta listesi / uçlar
  created_at   timestamptz not null default now()
);
-- RLS: SELECT = world member; INSERT = world member AND author_id = auth.uid();
--      DELETE = author_id = auth.uid() OR is_world_dm(world_id).
-- → oyuncu yalnız kendi çizimini siler; DM hepsini siler.
-- supabase_realtime publication + REPLICA IDENTITY FULL.

-- RPC move_own_token(p_world, p_encounter, p_combatant, p_x, p_y) SECURITY DEFINER:
--   çağıran combatant'ın sahibi mi + turnIndex o combatant'ta mı doğrula
--   → world_map_data tokenPositions günceller. Aksi halde RAISE.
-- RPC clear_battlemap_marks(p_world, p_encounter) — DM-only, encounter mark'larını siler.
```

İkisi de `world_sync_service.dart` `_mirrorTables`'a eklenir; CDC filtresi `world_id`.

## 6. Akış — paylaşılabilir içerik

### Entity card

DM "Project" → `addEntityCard` (`entity_card.dart:431`) → `EntityCardProjection` +
`EntitySnapshot`. Online çıkış manifest'i upsert eder. `EntitySnapshot.imagePaths` →
`AssetRef` string'leri (portre `dmt-public://`, ek resim `dmt-asset://`). Oyuncu
`EntitySnapshot.fromJson` + `AssetRefImage` ile render — `entity_card_projection_view.dart`
ham `Image.file` → `AssetRefImage` refactor gerekir.

### Sadece entity resmi

DM entity kartının yalnız resmini paylaşır → `ImageProjection` (filePaths yerine
`AssetRef` listesi). Entity'nin mevcut resim ref'i kullanılır; yeni upload yok.

### Medya galerisi fotoğrafı

Medya redesign Faz 5 galerisinin "ikinci ekrana paylaş" aksiyonu → galerideki asset'in
`AssetRef`'i ile `ImageProjection`. Free veya counted, ikisi de ref taşır.

### Battle map

DM "Project" battle map → `addBattleMap` (`projection_provider.dart:227`) →
`BattleMapProjection` + `BattleMapSnapshot`. Token resimleri `AssetRef`. Manifest'e
yazılır. Oyuncu `battle_map_projection_view.dart` ile render (AssetRef-aware refactor
gerekir). Üstüne collab katmanı (`world_battlemap_marks` CDC) bindirilir.

## 7. Battle map collab katmanı

- **Çizim:** oyuncu stroke / ruler / circle çizer → pointer-up'ta `world_battlemap_marks`
  insert (kendi `author_id`, kendi rengi). CDC tüm üyelere yayar. In-progress preview
  Faz F broadcast.
- **Silme:** oyuncu kendi mark'ını siler (RLS `author_id` gate). DM `clear_battlemap_marks`
  ile encounter'ın hepsini.
- **Renk:** her üyeye membership sırası (`world_members.joined_at`) veya uid hash ile palet
  renk atanır; DM ayrılmış renk. `color_hex` mark'ta saklı — renk geçmişe sabit.
- **Token hareketi:** oyuncu kendi karakterinin token'ını sürükler → release'te
  `move_own_token` RPC. Server turnIndex + sahiplik doğrular. Reddederse token snap-back.
  DM her token'ı serbest oynatır (mevcut yetki).
- **Tur tespiti:** `Encounter.turnIndex` → `combatants[turnIndex].entityId` ↔ oyuncunun
  sahip olduğu `world_characters` satırı. Karakter↔combatant eşlemesi netleştirilmeli
  (§10 açık nokta).

## 8. AssetRef uyumu — projeksiyon köprüsü

Tüm snapshot image alanları `AssetRef` string olmalı. Refactor:

- `image_projection_view.dart` — `Image.file(File(path))` → `AssetRefImage`.
- `entity_card_projection_view.dart` — portre `Image.file` → `AssetRefImage`.
- `battle_map_projection_view.dart` — token resim decode → resolver üzerinden.
- Snapshot builder'lar (`EntitySnapshotBuilder`, `BattleMapSnapshotBuilder`) ham path
  yerine `AssetRef` string yazar.

Offline pencere de `AssetRefImage` resolver'ı kullanır (local ref → dosya). Yani refactor
offline'ı bozmaz, online'ı açar. Medya redesign Faz 6 zaten bu refactoru risk olarak
listeliyor — ortak iş.

## 9. Faz planı

- **Faz A ✓ — manifest altyapısı:** migration 059, `ProjectionOutputMode.online`,
  `ProjectionOutputOnline`, çıkış fan-out, `world_projection` CDC handler.
  *(tamamlandı 2026-05-22 — UI tetikleyici yok, Faz C ekler.)*
- **Faz B ✓ — AssetRef köprüsü:** 3 projection view (`image_projection_view`,
  `entity_card_projection_view`, `battle_map_projection_view`) ham `File(path)` →
  `AssetRefImage` / `AssetRefResolver`. Snapshot builder'lar DEĞİŞMEDİ — `Entity` /
  `Encounter` zaten karma path/ref tutuyor; view katmanı çözüyor.
  *(tamamlandı 2026-05-22)*
- **Faz C ✓ — player tab + DM tetikleyici:** `PlayerSecondScreenTab` →
  `ConsumerWidget`, `onlineProjectionProvider` null → "Waiting for DM",
  non-null → `PlayerWindowRoot(onlineProjectionStateProvider)`. `ProjectionPanel`'de
  DM-only online broadcast toggle (online dünya + DM iken görünür, fan-out).
  *(tamamlandı 2026-05-22)*
- **Faz D — battle map collab:** migration 060, `world_battlemap_marks` CDC, çizim
  araçları player tarafı, renk atama.
- **Faz E — token hareketi:** `move_own_token` RPC + turn-gate UI.
- **Faz F (cila):** in-progress broadcast preview (canlı stroke / drag).

Bağımlılık: A → C; B → C; A+B+C → D → E → F. B medya redesign Faz 5/6'ya değer.

## 10. Riskler / açık noktalar

- **Karakter↔combatant eşlemesi:** "kendi token'ım" için `world_characters.owner_id` ↔
  `Combatant.entityId` net link gerekir. `entityId` karakterin entity id'si mi? Doğrula.
- **Çoklu çıkış fan-out:** `ProjectionController` bugün tek output varsayıyor; liste /
  fan-out refactoru patch yollarını etkiler.
- **Geri kanal asimetrisi:** `ProjectionOutput` push-only; `ProjectionOutputOnline`
  ayrıca inbound subscription (çizim/token CDC) sahibi — interface'i kirletmeden ek
  sorumluluk.
- **Manifest yazma frekansı:** battle map patch'leri sık; `world_projection` her patch'te
  upsert ederse CDC gürültüsü. Battle map canlı verisi §4b collab tablosuna ayrıldı;
  manifest yalnız "hangi item aktif" için → düşük frekans korunur.
- **RLS — token yazımı:** token pozisyonları combat_state blob'unda; oyuncu blob'u
  granular patch'leyemez → `move_own_token` RPC zorunlu.
- **Çizim hacmi:** uzun oturumda `world_battlemap_marks` birikir; encounter bitince /
  DM clear-all temizler. Auto-purge kuralı düşünülebilir.
