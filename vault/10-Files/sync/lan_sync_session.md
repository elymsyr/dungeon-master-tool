---
type: file-note
domain: sync
path: flutter_app/lib/application/services/lan_sync/lan_sync_session.dart
layer: application
language: dart
status: active
updated: 2026-08-21
tags: [file]
---

# `lan_sync_session.dart`

> [!abstract] Primary Purpose
> LAN eşlemesinin yerel yarısı: manifest üretimi, item okuma, item uygulama, medya listeleme/yazma ve yol yeniden yazımı. Taşıma katmanından bağımsız — host da peer de aynı oturumu kullanır. Yazımlar repository'ler üzerinden gittiği ve `lib/data/repositories/` içinde hiç `enqueue`/`syncEngine` çağrısı olmadığı için LAN'dan gelen içerik **Supabase outbox'ına düşmez**.

## Inputs / Outputs
**Inputs**
- Constructor: `Ref _ref` (→ `lanSyncSessionProvider`).
- Reads: `worldsDao.getAll/getById/getByName`, `packagesDao.getAll/getById/getByName`, `worldCharactersDao.getAllChars/getById`, `campaignRepository.load`, `packageRepository.load`.
- Dosya sistemi: `AppPaths.worldsDir / packagesDir / charactersDir`.

**Outputs**
- Public API: `buildManifest()`, `loadItem(ref)`, `applyItem(item)`, `openMedia`, `resolveMedia`, `hasMedia`, `writeMedia`, `fileSha256`, `rewriteRoots`, `userBase`.
- Writes: `campaignRepository.save`, `packageRepository.save`, `characterRepository.save`, `worldsDao.setUpdatedAt`, `packagesDao.setUpdatedAt`; medya dosyaları.
- Invalidations: `campaignListProvider`, `campaignInfoListProvider`, `packageListProvider`, `characterListProvider.refresh()`.

## Dependencies & Links
- Depends on: [[lan_sync_protocol]], [[worlds_dao]], [[packages_dao]], `ui_state_provider.dart` (`exportWorldUiView` / `importWorldUiView`)
- Used by: [[lan_sync_server]], `lan_sync_provider.dart`
- Domain map: [[Sync-and-Realtime]]
- System flow: [[LAN-Sync-Flow]]

## Key Logic / Variables
- `userBase = dirname(AppPaths.worldsDir)` — `{dataRoot}` ya da `{dataRoot}/users/{uid}`. Medya yolları buna relatif taşınır, böylece iki cihazın profil klasörleri farklı olsa da eşleşir.
- `buildManifest()` built-in SRD paketini atlar (`srdCorePackageName`); world/paket `updatedAt` Drift kolonundan, karakter `WorldCharacterRow.updatedAt`'ten.
- **id-anahtarlı apply** — repository'ler ada göre arıyor (`_findByName`), LAN kimliği id. `getById` ile yerel ad bulunur; id yoksa ama aynı adda başka kayıt varsa `Ad (2)` ile ayrıştırılır.
- **Restamp:** `repository.save` her yazımda `DateTime.now()` basar; `setUpdatedAt(id, ref.updatedAt)` olmasa çekilen içerik anında "biz daha yeniyiz" görünüp geri push edilirdi. Karakterlerde gerekmez — `updatedAt` payload'ın içinde taşınır.
- `rewriteRoots(node, fromBase, toBase)` recursive, **alan adı bilmez**: gönderenin kökü altındaki her string yeniden yazılır, `dmt-asset://` / `dmt-public://` ref'lerine dokunulmaz. `\` ve `/` normalize edilir (Windows ↔ POSIX).
- `_worldExtras / _applyWorldExtras` — blob'da olmayan dünya parçaları: `installed_packages` bağlantıları ve `ui_view` (açık kartlar, filtreler, açık PDF sekmeleri, sağ sidebar, session sekmesi). `extras` da `rewriteRoots`'tan geçer. Apply tarafında da yalnız ekleme/güncelleme — peer'da olmayan paket bağlantısı yerelde kalır.
- `buildManifest()` world satırına `viewUpdatedAt` ekler (`UiState.viewTouchedByWorld[worldName]`) — içerik değişmeden sadece görünüm değiştiğinde de eşleme tetiklensin diye. Alıcı bunu world satırının içerik `updatedAt`'ine yazmaz, UI state'e stamp'ler.
- Uygulanan dünya **açık dünyaysa** `activeCampaignProvider.reload()` çağrılır — `_data` bayat kalırsa bir sonraki otomatik kayıt senkronize edilen içeriği geri eziyordu (cloud restore'un "açık dünyanın içine geri yükle" yolunun aynısı).
- `resolveMedia` `p.isWithin` ile veri kökü dışına çıkan yolu **null** döndürür — yol geçişi savunması.
- **`_flushPending()`** — `buildManifest` / `loadItem` / `applyItem` girişinde `PendingWriteBuffer.flush()`. `combat_state` 500 ms, `mind_maps` 1000 ms, viewport 2000 ms gecikmeyle yazılıyor; eşleme o pencerede başlarsa payload da `worlds.updatedAt` de bayat okunuyor ve karşı cihaz taze veriyi eziyordu. Apply tarafında da gerekli — bekleyen yerel yazım apply'dan sonra fire edip geleni geri yazardı.
- **Bölüm bazlı birleştirme** — dünya alıcıda da varsa `mergeWorldPayloads` (`world_merge.dart`) çağrılır; entity/session/`map_data` damgaları granüler tabloların `updated_at` sütunlarından, settings anahtarları blob içindeki `_section_updated_at`'ten (`_sectionStamps`). Damgalar `extras.section_stamps` ile taşınır. Birleşim sonrası `_restoreSectionStamps` satır damgalarını geri yazar — bulk `save()` hepsini `now()` yapıyor.
- **`LocalMediaLocalizer.localizeWorldPayload`** — `loadItem` içinde, `_mediaFor`'dan önce. Veri kökü dışındaki ham yollar (`.../Downloads/map.png`) dünyanın `media/` klasörüne kopyalanır ve payload yeniden yazılır; değişiklik olduysa dünya kaydedilir. Bu olmadan battle map / mindmap resimleri taşınmıyordu, çünkü `_mediaFor` yalnız veri kökü altını tarıyor. Bu yalnız **onarım** geçişi: yeni seçimler zaten seçim anında koşulsuz kopyalanıyor (bkz. [[local_media_localizer]]).
- `_collectContentBlobs` payload'daki `dmt-asset://` / `dmt-public://` / `dmt-transient://` ref'lerinin sha'sını çıkarıp (`AssetRef.contentSha`) `cache/content/{sha}.bin` blob'unu da medya listesine ekler. Online dünyada resim baytları dünya klasöründe değil bu önbellekte durduğu için, bunlar olmadan karşı cihazda görsel boş kalıyordu.
- `fileSha256` akış üzerinden (`sha256.bind(file.openRead())`), dosya belleğe alınmaz.

## Notes
- ponytail: yeniden adlandırma taşınmaz. Silme birleştirmede de yayılmaz — tombstone yok, A'da silinen bir entity B'de duruyorsa geri gelir; veri kaybetmemeyi hayalet satıra tercih ediyoruz.
- Test: `test/application/services/lan_sync/lan_sync_loopback_test.dart` — iki in-memory Drift DB, gerçek soket.
