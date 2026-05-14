# Sistem Optimizasyon Yol Haritası

**Tarih**: 2026-05-14
**Kapsam**: `flutter_app/` — 445 Dart dosyası, ~158 kLOC
**Amaç**: Hız, frame-budget, soğuk başlangıç, bellek, ağ trafiği. Üç eksen: **hız, hafiflik, performans**.
**Önceki turlar**: [performance_optimization_roadmap.md](performance_optimization_roadmap.md), [performance_hotspots_wizard_editor_hub.md](performance_hotspots_wizard_editor_hub.md). Bu döküman onların üstüne — yeni bulgular + hâlâ açık olanlar.

---

## TL;DR

Önceki F1–F13 ve W/E/L/H serileri büyük ölçüde kapandı. Ama 2026-05-14 sweep'i **31 yeni/açık finding** ortaya koydu. Ağır olanlar:

| # | Bulgu | Etki | Çaba |
|---|-------|------|------|
| **S1** | **DB index yok** — 10+ FK kolonu indexsiz, her query tam tarama | ÇOK YÜKSEK | XS (migration) |
| **S2** | **`campaign_repository._loadFromDb` 4× jsonDecode/satır** | YÜKSEK | S |
| **S3** | **SRD core seed ana izolatta** kampanya yaratırken 2–5 sn donar | YÜKSEK | M |
| **S4** | **`world_entities` bootstrap `.select()` tüm kolonlar** — payload 60-70% şişkin | YÜKSEK | XS |
| **S5** | **Structured-list satır geri çağrısı O(N²)** — uzun listede tuş başına tüm satır rebuild | YÜKSEK | M |
| **S6** | **`Image.file()` build path'inde cacheWidth yok** — full-res decode her rebuild | YÜKSEK | XS |
| **S7** | **Combat eventLog sınırsız büyüme** — uzun seans = sürekli artan bellek | ORTA | XS |
| **S8** | **`world_mirror_applier` non-self CDC roster invalidate** — 10 oyunculu seansta gereksiz fanout | ORTA | XS |

Phase 1 (S1+S4+S6+S7+S8) ≈ **3-4 saat**; soğuk başlangıçta ~%30, mobilde realtime bant genişliğinde ~%60 kazanım. Phase 2 (S2+S3+S5) yapısal, ~1 gün.

---

## 1. Veri Katmanı (DB)

### S1 — Index Eksikliği (KRİTİK)

Drift tablolarında **tek bir CREATE INDEX yok**. Tüm `WHERE campaignId = ?` ve cascade DELETE'ler tam tablo taraması.

Eksik index'ler:

| Tablo | Kolon | Kullanım |
|-------|-------|----------|
| `Entities` | `campaignId` | `EntityDao.getAllForCampaign()`, cascade delete |
| `Sessions` | `campaignId` | `SessionDao.getAllForCampaign()`, cascade |
| `Encounters` | `campaignId`, `sessionId` | session+campaign filtreleri |
| `Combatants` | `encounterId` | `getCombatantsForEncounter`, `tickConditions` |
| `CombatConditions` | `combatantId` | tick + cascade |
| `MapPins` | `campaignId` | watch stream |
| `MindMapNodes` | `(campaignId, mapId)` composite | `getNodesForMap` |
| `MindMapEdges` | `(campaignId, mapId)`, `sourceId`, `targetId` | cascade + filtre |
| `WorldSchemas` | `campaignId` | `getCampaignInfoList` LEFT JOIN |
| `TimelinePins` | `campaignId` | watch stream |

**Fix**: Schema migration v9 — `app_database.dart` `onCreate`/`onUpgrade` içinde:

```dart
await customStatement('CREATE INDEX IF NOT EXISTS idx_entities_campaign ON entities(campaign_id);');
await customStatement('CREATE INDEX IF NOT EXISTS idx_sessions_campaign ON sessions(campaign_id);');
// ... her FK için
```

Ek olarak **SQLite tuning** (aynı migration):
```dart
await customStatement('PRAGMA journal_mode = WAL;');
await customStatement('PRAGMA cache_size = -64000;');   // 64 MB
await customStatement('PRAGMA synchronous = NORMAL;');
await customStatement('PRAGMA foreign_keys = ON;');
```

Etki: hot path query'ler 10-100× hızlanır, hub list yükleme ~10×, kampanya açılışı ~3×.

---

### S2 — Per-row JSON Decode (YÜKSEK)

[campaign_repository_impl.dart:218-239](../lib/data/repositories/campaign_repository_impl.dart#L218-L239) ve [package_repository_impl.dart:183-196](../lib/data/repositories/package_repository_impl.dart#L183-L196) her entity satırı için **4× `jsonDecode`** (`images`, `tags`, `pdfs`, `fields`). 100 entity = 400 JSON parse, ana izolat, ilk frame'i blokluyor.

**Fix sıra (önem sırasına göre)**:
1. **Lazy decode**: blob'u string sakla, ilk erişimde decode + cache.
2. **Batched single-pass**: tüm satırları aynı `compute()` izolat çağrısında parse.
3. **Drift JSON codec**: `TextColumn().map(JsonTypeConverter)` ile bir kez parse.

Etki: 50+ entityli kampanyada ilk açılış 200-500 ms düşer.

---

### S3 — SRD Core Seed Bloke (YÜKSEK)

[srd_core_bootstrap.dart:53-94](../lib/application/services/srd_core_bootstrap.dart#L53-L94) → yeni D&D 5e kampanya yaratırken Tier-0 seed + 2000+ SRD entity insert ana izolatta. Donma süresi 2-5 sn.

**Fix**:
- `compute()` ile background isolate'a taşı; UI'da progress göster.
- Veya kampanya yaratımını **early-return** + arka planda seed (concurrent read guard).
- Tier-0 (abilities/skills/conditions) sync kalabilir — küçük; SRD entity insert async.

---

### S4 — Bootstrap `.select()` Projeksiyon Yok (YÜKSEK)

[world_mirror_service.dart:194-198](../lib/application/services/world_mirror_service.dart#L194-L198):
```dart
await client.from('world_entities').select().eq('world_id', worldId);
await client.from('world_characters').select().eq('world_id', worldId);
```

Tüm kolonlar — `images_json`, `tags_json`, `pdfs_json`, `fields_json`, `payload_json`. 50 entity × 3 KB = ~150 KB her dünya bootstrap'inde. Mobil veriyle her uygulama açılışında ödenir.

**Fix**: kolon projeksiyonu —
```dart
.select('id,name,category_slug,image_path,updated_at')
```
Detay alanlar görüntülemeye girince lazy fetch. Tahmin %60-70 trafik azalır.

Aynı pattern [personal_mirror_applier.dart:70-84](../lib/application/services/personal_mirror_applier.dart#L70-L84) — kişisel karakter bootstrap'i de full payload çekiyor; sadece online-marked olanlara WHERE eklenmeli.

---

### S5 — `_entityRow` Çift/Üçlü JSON Encode (ORTA)

[world_mirror_service.dart:100-120](../lib/application/services/world_mirror_service.dart#L100-L120) — `jsonEncode` her `images/tags/pdfs/fields` için. Sonra Supabase RPC parametre encoding bir kat daha ekler. Karakter publish'inde `pushPersonalCharacter` → `jsonEncode(character.toJson())` payload üzerinde 4. kat.

**Fix**: Postgres JSONB kolonlara native pass — manuel `jsonEncode` kaldır.

---

### S6 — N+1 Package Sayım (ORTA)

[package_dao.dart:65-86](../lib/data/database/daos/package_dao.dart#L65-L86) — her package için ayrı `SELECT COUNT(*)`. 10 package = 10 query.

**Fix**: tek `GROUP BY` query —
```sql
SELECT pkg.*, COUNT(pe.id) AS entity_count
FROM packages pkg
LEFT JOIN package_entities pe ON pe.package_id = pkg.id
GROUP BY pkg.id;
```

---

## 2. Online Sync Katmanı

### S7 — Non-self CDC Roster Invalidate (ORTA-YÜKSEK)

[world_mirror_applier.dart:151-164](../lib/application/services/world_mirror_applier.dart#L151-L164) — başka oyuncuların `world_members` CDC eventi her seferinde `worldMembersProvider` invalidate eder. 10 oyunculu seansta yoğun aktivitede dakikada onlarca gereksiz roster fetch.

**Fix**: roster invalidate sadece self event'lerinde fire. Diğer durumlarda granular member-list patch (mirror tarzı).

---

### S8 — Karakter CDC Hub List Fanout (ORTA)

[world_mirror_applier.dart:138-142](../lib/application/services/world_mirror_applier.dart#L138-L142) — her `world_characters` CDC eventi global `characterListProvider` invalidate eder. DM canavar düzenlerken tüm dünyaların karakter listesi yeniden okunur.

**Fix**: sadece `owner_id == auth.uid` ise invalidate. Dünya karakterleri zaten ayrı mirror akışında.

---

### S9 — Push Debounce Eksik (ORTA)

[campaign_provider.dart:228-235](../lib/application/providers/campaign_provider.dart#L228-L235) — `_bundleAndPush` 2s/10s kaydet debounce'una bağlı ama içeride `WorldMirrorService.pushEntities()` request-seviyesi debounce yok. Hızlı map edit'lerinde her tetik anında Supabase'e gider.

**Fix**: `WorldMirrorService.pushEntities()` içine 500 ms coalescing timer.

---

### S10 — Realtime Reconnect Backoff (DÜŞÜK-ORTA)

[personal_sync_service.dart](../lib/application/services/personal_sync_service.dart), [world_sync_service.dart](../lib/application/services/world_sync_service.dart) — `channel.onError` ve exponential backoff yok. Supabase outage'da sessiz başarısızlık veya reconnect storm riski.

**Fix**: `channel.onError` → exponential backoff (1s, 2s, 4s, max 30s) + UI "sync offline" göstergesi.

---

## 3. Soğuk Başlangıç

### S11 — Bootstrap Sequential I/O (YÜKSEK)

[main.dart:144-174](../lib/main.dart#L144-L174) — `Future.wait` ile paralelleştirme var ama `AppPaths.initialize()` sequential. 6× `Directory.create(recursive: true)` + trash cleanup ana izolat.

Maliyetler:
- AppPaths dir I/O: ~200-500 ms
- Supabase init + heartbeat RPC: ~800-1500 ms (3 sn timeout)
- windowManager (desktop): ~300-600 ms
- UiState load: ~200-500 ms

**Fix**:
- `AppPaths.initialize()` post-frame'e taşı (soundpad path yalnız ihtiyaç anında).
- Trash cleanup background isolate.
- Drift DB connection'ı eager open (post-frame), migration üst tarafa.

---

### S12 — Personal Sync Hub Mount'ta Subscribe (ORTA)

[hub_screen.dart:244](../lib/presentation/screens/hub/hub_screen.dart) `ref.watch(personalSyncAutoSubscribeProvider)` her hub mount'unda channel kurar. Hub→campaign→hub navigasyonunda tekrarlanır.

**Fix**: kanal `keepAlive: true` global scope provider — sadece logout'ta öl. Bootstrap-complete sinyalini `.select()` ile filtrele.

---

### S13 — Profile Fetch Hub Mount'ta (DÜŞÜK)

[profile_provider.dart:20-39](../lib/application/providers/profile_provider.dart) — `currentProfileProvider` hub girişinde fetch. Yavaş şebekede 500-1500 ms layout blok.

**Fix**: login akışında prefetch (auth_provider içinde).

---

## 4. Widget Rebuild

### S14 — `Image.file()` cacheWidth Yok (YÜKSEK)

[field_widget_factory.dart:3042](../lib/presentation/widgets/field_widgets/field_widget_factory.dart#L3042) viewer dialog **cacheWidth/cacheHeight yok** — büyük image full-res decode. Aynı dosyanın 3089-3093 kullanımı doğru. 15+ benzer site var.

**Fix**:
```dart
Image.file(File(path), cacheWidth: 800, fit: BoxFit.contain, errorBuilder: ...)
```
Tüm `Image.file` çağrılarını tara, `cacheWidth`/`cacheHeight` ekle, `errorBuilder` ekle, dosya `existsSync` çağrısı kaldır.

---

### S15 — Structured List Satır Callback O(N²) (YÜKSEK)

[structured_list_field_widgets.dart:51-154](../lib/presentation/widgets/field_widgets/structured_list_field_widgets.dart#L51-L154) — `_StructuredListShell._updateRow` `onChanged([...rows])` ile tüm listeyi yayınlar → ebeveyn tüm satırları rebuild eder. 10 satır × 5 relation-picker = tuş başına 50 widget rebuild.

**Fix**: `_RowEditor` stateful widget — kendi draftını sahiplenir, sadece diff emit eder. Ebeveyn `Listenable` veya `family` provider ile satır-bazlı izole olur.

Aynı widget'ta `ReorderableListView` + `shrinkWrap` + `NeverScrollable` (105-107) → tüm satırlar layout. Sliver kapsama gerekli.

---

### S16 — Character Editor `setState` Skopu Geniş (YÜKSEK)

[character_editor_screen.dart:286, 874, 2530, 2883](../lib/presentation/screens/characters/character_editor_screen.dart#L286) — read-only toggle, undo/redo, HP/Grant pool, level-up → tüm `setState` editör tamamını (600+ satır build) rebuild eder.

**Fix**:
- Read-only, undo/redo, grant pool → ayrı `ValueNotifier`-backed widget.
- Portrait, AppBar, header → kendi `RepaintBoundary`.
- `_StatChipsHeader` doğru kullanıyor (`.select`), benzer pattern diğerlerine.

---

### S17 — Field Tile Callback Allocation (ORTA-YÜKSEK)

[character_editor_screen.dart:1407-1413](../lib/presentation/screens/characters/character_editor_screen.dart#L1407-L1413) — `_fieldTile()` `onChanged` her tuşta yeni `Map<String, dynamic>` spread + `copyWith()` allocate. 100-karakter isim yazımı = 100+ map allocation.

**Fix**: callback memoize (field key başına 1 closure) veya auto-save timer içinde toplu spread.

---

### S18 — Sidebar Drag ValueListenableBuilder Skopu (ORTA)

[main_screen.dart:724-732](../lib/presentation/screens/main_screen.dart#L724-L732) — sidebar width drag her 1px değişimde Tab bar + tab butonları + overflow menüsü rebuild. 50+ descendant.

**Fix**: `ValueListenableBuilder` sadece `padding` property'sini sar, container'ı değil. `RepaintBoundary` ile tab bar'ı izole et.

---

### S19 — Battle Map Token Repaint (ORTA)

[battle_map](../lib/presentation/screens/battle_map/) `TokenWidget` 60fps pan/zoom sırasında her viewTransform tick'inde rebuild. Token bağımsız paint subtree değil.

**Fix**: `RepaintBoundary` token başına; `ValueListenableBuilder` skoplu pan/zoom.

---

### S20 — Mind Map Drag Map Identity (ORTA)

[mind_map_canvas.dart:237-271](../lib/presentation/screens/mind_map/mind_map_canvas.dart) `dragOverrides: Map<String, Offset>` her drag frame'de yeni map → identity değişir → tüm `Positioned` rebuild.

**Fix**: `ValueNotifier<Map>` deep-eq guard, sadece sürüklenen node'un Positioned'ı update.

---

### S21 — Hub Tabları shrinkWrap (ORTA)

[characters_tab.dart:139](../lib/presentation/screens/hub/characters_tab.dart#L139), [worlds_tab.dart:108](../lib/presentation/screens/hub/worlds_tab.dart#L108), [packages_tab.dart:128](../lib/presentation/screens/hub/packages_tab.dart#L128) — `ListView.builder` `shrinkWrap: true` + `NeverScrollable` `SingleChildScrollView` içinde. Lazy build çalışmıyor — tüm itemler build edilir.

**Fix**: Sliver migration. `SliverList` + `SliverCrossAxisGroup` + `SliverConstrainedCrossAxis` ile max-width: 500 centering korunur.

---

### S22 — LazyIndexedStack Tab Abonelik (ORTA)

`LazyIndexedStack` ziyaret edilen her tab'ı subscribe halinde tutar — offscreen rebuild'ler.

**Fix**: per-tab `Offstage` + provider scope dispose; veya `IndexedStack` yerine route-based.

---

### S23 — Database Screen IndexedStack (ORTA)

Database screen tüm açık `EntityCard`'ları mount tutar; `Offstage` olanlar `entityProvider` watch ediyor.

**Fix**: visible-only watch (provider family ile veya AutomaticKeepAlive false).

---

## 5. Bellek / Sızıntı / Asset

### S24 — Combat eventLog Sınırsız Büyüme (YÜKSEK)

[combat_provider.dart:540](../lib/application/providers/combat_provider.dart#L540) `eventLog: [...state.eventLog, message]` — append-only. Uzun seans = sürekli artan bellek + her save'de tüm log serialize.

**Fix**: cap 1000 satır —
```dart
final next = [...state.eventLog, message];
final pruned = next.length > 1000 ? next.sublist(next.length - 1000) : next;
state = state.copyWith(eventLog: pruned);
```

---

### S25 — Token Image Cache Kapsız (ORTA)

[battle_map_projection_view.dart:38, 134-153](../lib/presentation/screens/player_window/views/battle_map_projection_view.dart) `_tokenImageCache: Map<String, ui.Image>` — LRU yok, boyut limiti yok. Çok farklı token sprite'lı bir map'te GPU bellek şişer.

**Fix**: 50 entry cap + LRU eviction.

---

### S26 — playerWindowClosedSignal Listener (DÜŞÜK)

[main.dart:29](../lib/main.dart#L29) top-level `ValueNotifier`. Listener kayıt/temizleme `ProjectionOutputWindow` deactivate/dispose'a bağlı — edge case'lerde listener sızabilir.

**Fix**: assertion + WeakReference değerlendir.

---

### S27 — SRD Pack Bellek Footprint (DÜŞÜK)

[builtin_srd_entities.dart](../lib/application/services/builtin_srd_entities.dart) ~7K entity tek seferde materialize — tahmini 40-60 MB runtime. Provider memoize edilmiş (uygulama yaşam süresince). Cache invalidate edilirse yeniden yapılır.

**Fix**: provider'ın asla invalidate olmadığını doğrula. Low-end cihazlarda kategori-bazlı lazy load değerlendir.

---

### S28 — Sync Timer Leak Riski (DÜŞÜK)

[cloud_sync_provider.dart](../lib/application/providers/cloud_sync_provider.dart) — `Timer.periodic` ref.onDispose'da cancel doğrula. Hızlı `markDirty` tetik altında timer çoğalma riski.

---

## 6. Önceki Audit'lerden Hâlâ Açık

- **F5/F10**: Sliver migration (cross-axis center korunma maliyeti) — S21 ile birleşik.
- **L2**: HP roller isolation — L1 sonrası düşük öncelik.
- **H2**: Per-tab subscription gating — S22.
- **W (window glitch)**: hub_screen `getScreenType` MediaQuery.sizeOf full rebuild — boundary-cross detection.
- **O1**: `_entityRowToBlob` 4× jsonDecode/CDC event — S2'nin online ikizi.
- **O4**: `visibleEntityProvider.select(map.values...)` identity bazlı — deep-eq projection.

---

## 7. Önceliklendirilmiş Yol Haritası

### Phase 1 — Hızlı Kazanımlar (1 gün)

| ID | İş | Etki | Süre |
|----|-----|------|------|
| S1 | DB index migration v9 (10 index + 4 PRAGMA) | Çok yüksek | 45 dk |
| S4 | `world_entities`/`world_characters` `.select()` projeksiyon | Yüksek | 30 dk |
| S6 | `Image.file()` cacheWidth tüm site'larda | Yüksek | 1 saat |
| S7 | Non-self roster CDC skip | Orta | 20 dk |
| S8 | `owner_id` filtreli karakter CDC | Orta | 30 dk |
| S24 | eventLog cap 1000 | Yüksek | 10 dk |
| S25 | Token cache LRU 50 | Orta | 30 dk |
| S11a | AppPaths post-frame taşıma | Yüksek | 1 saat |

**Beklenti**: soğuk başlangıç -300/500 ms, online bandwidth -%50, uzun seans bellek stabil.

### Phase 2 — Yapısal (2-3 gün)

| ID | İş | Etki | Süre |
|----|-----|------|------|
| S2 | `_loadFromDb` lazy/batch JSON decode | Yüksek | 4 saat |
| S3 | SRD seed background isolate | Yüksek | 4 saat |
| S5 | Structured-list satır izolasyonu | Yüksek | 6 saat |
| S15-S16-S17 | Editor `setState` skop daralt + field callback memoize | Orta-Yüksek | 1 gün |
| S21 | Hub tabları Sliver migration | Orta | 4 saat |

### Phase 3 — İnce Ayar + DevX (sonraki sprint)

S9 (push debounce), S10 (reconnect backoff), S12-S13 (sync/profile prefetch), S18-S20 (battle/mind map repaint), S22-S23 (tab abonelik).

---

## 8. KPI Hedefleri

| Metrik | Şimdiki tahmini | Hedef (Phase 1) | Hedef (Phase 2) |
|--------|----------------|-----------------|-----------------|
| Soğuk başlangıç (desktop) | 1.2-1.5 sn | 0.8-1.0 sn | 0.5-0.7 sn |
| Soğuk başlangıç (mobil orta seg.) | 2.5-3.5 sn | 1.8-2.5 sn | 1.2-1.8 sn |
| Karakter editör tuş başı frame | 12-18 ms | 8-12 ms | 5-8 ms |
| 50 entity'li dünya bootstrap (online) | ~150 KB | ~50 KB | ~30 KB |
| Combat 1 saat sonra bellek artışı | +N MB | sabit | sabit |
| Hub açılış (200 karakter) | ? | ölç → -%50 | -%80 |

**Önemli**: bir sonraki tur öncesi **DevTools Performance overlay** ile gerçek sayılar yakala. Yukarıdaki tahmin, profil değil. Phase 1 ship sonrası ölçüm Phase 2'nin hedeflerini netleştirir.

---

## 9. Invariant'lar (uygulama sırasında bozma)

Önceki tur'lardan miras:
- **F13**: `_syncToCampaign` sadece undo/redo için. Create/update/delete `_writeEntityToCampaign` ile O(1).
- **Mirror appliers**: granular `applyMirror`/`removeMirror`, asla `ref.invalidate` hot CDC path.
- **Wizard `.select`**: `wizardEntitiesProvider` sadece `worldName` izler. `CombinedMapView` lazy.
- **`_DebouncedTextField` / `_Field`**: wizard text input'ları, 250 ms debounce. Raw `onChanged: notifier.setX` yok.
- **`_mapEquals`**: `DeepCollectionEquality`, `jsonEncode` geri getirme.
- **`sortedCharactersProvider`**: kanonik karakter sıralama; view'da `sort()` yapma.

Yeni invariant adayları (Phase 1 sonrası):
- `Image.file` her zaman `cacheWidth` + `errorBuilder` ile.
- `eventLog` append wrapper kullan (`appendEventLog(state, msg)`).
- Supabase remote read'ler her zaman `.select('col1,col2,...')` projeksiyonlu.
- DB cascade ve filtre kullanan her yeni FK kolon → index'siz commit yok.

---

## 10. Test ve Riskler

- **Test suite**: tüm değişiklikler 533 mevcut test üzerinde çalıştırılmalı. DB migration test'i `app_database_test.dart` içine eklenmeli (v8→v9 transition).
- **Schema migration**: index ekleme additive, geri uyumlu. Mevcut DB upgrade'i için `customStatement` `IF NOT EXISTS` kullan.
- **CDC scope değişiklikleri**: integration test multiplayer akış üzerinde — roster join/leave/edit, karakter publish, world_entities push.
- **SRD seed isolate**: cold-start sırası, kampanya yaratım UX'i — progress callback gerekli, kullanıcı seed bitmeden entity ekleyemez.
- **Image cacheWidth**: aspect ratio koruma için sadece `cacheWidth` (height auto) — `cacheHeight` ekleme dikey crop riski.

---

## 11. Sonraki Adım

1. Bu döküman onaylanırsa **Phase 1** PR'lar — S1 (migration), S4 (projeksiyon), S6 (image cache), S7+S8 (CDC scope), S24-S25 (memory cap), S11a (boot defer).
2. Phase 1 ship sonrası DevTools profile capture.
3. Profile'a göre Phase 2 önceliği netleştir.
