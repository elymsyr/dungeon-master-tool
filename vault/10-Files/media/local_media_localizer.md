---
type: file-note
domain: media
path: flutter_app/lib/application/services/local_media_localizer.dart
layer: application
language: dart
status: active
updated: 2026-08-21
tags: [file]
---

# `local_media_localizer.dart`

> [!abstract] Primary Purpose
> Statik yardımcı sınıf: seçicinin verdiği **ham dosya yollarını veri kökünün içine** kopyalar. `RawPathMigrator`'ın çevrimdışı karşılığı — bulut servisi gerektirmez, ref'e çevirmez, sadece dosyayı içeriğin kendi klasörüne (`{worldsDir}/{ad}/media/`, `{packagesDir}/{ad}/media/`, `{charactersDir}/{id}_*`) alır ve kopyanın yolunu döndürür. Ham yol ne LAN eşlemesinde taşınır (`LanSyncSession._mediaFor` yalnız içeriğin kendi klasörünü tarar) ne de kullanıcı orijinali taşıdığında açılır.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: **yok** — hepsi `static`, yalnız `AppPaths` + `AssetImporter` okur.
- Reads: dosya sistemi (`File.exists`, kopyalama `AssetImporter` üzerinden).
- Triggers: her medya seçimi (bkz. *Used by*) ve `LanSyncSession.loadItem` onarım geçişi.

**Outputs**
- Public API: `localize(path, {ownerDir, subDir, imagesOnly})`, `localizeAll(...)`, `localizeCharacterImage(path, {characterId})`, `localizeWorldPayload(payload, worldName)`, `localizePackagePayload(payload, packageName)`, `worldDir(name)`, `packageDir(name)`, sabitler `mediaSubDir = 'media'` / `filesSubDir = 'files'`.
- Writes: `{ownerDir}/{subDir}/` altına dosya kopyası; payload varyantları ağacı **yerinde** günceller ve değişiklik olduysa `true` döner (çağıran kaydeder).

## Dependencies & Links
- Depends on: [[asset_importer]], `core/config/app_paths.dart`, `domain/value_objects/asset_ref.dart`
- Used by: [[entity_image_upload]], `map_image_upload.dart`, [[lan_sync_session]], `data/repositories/character_repository.dart`, `presentation/widgets/metadata_editor_section.dart`, `field_widget_factory.dart` (`file`/`pdf` alanları)
- Domain map: [[Media-and-Assets]]
- System flow: [[LAN-Sync-Flow]], [[Media-Storage-Tiers]]

## Key Logic / Variables
- **Kural: seçilen her dosya kopyalanır.** Bulut yüklemesi başarılı olsun ya da olmasın; yükleme de kopyadan yapılır. Eskiden kopya yalnız yükleme atlandığında/başarısız olduğunda alınıyordu, bu da ham yolun sızabildiği bir sürü yol bırakıyordu.
- **`_isLocalizable` süzgeci** (hepsi geçmeli): boş değil, `AssetRef.isLocal` (şema'lı ref değil), `imagesOnly` ise `png|jpe?g|webp|gif|bmp` uzantısı, mutlak yol, `ownerDir` altında **değil**, `AppPaths.cacheDir` altında **değil**, dosya diskte var.
  - "Veri kökünün altında olmak" **yetmez** — `cache/tmp/` gibi bir klasör hiçbir item taramasına girmiyor. Ölçüt `ownerDir`.
- **Karakterler ayrı:** medya `{charactersDir}` altında **düz** duruyor ve `_mediaFor` dosyaları `{id}_` önekiyle süzüyor. `localizeCharacterImage` bu yüzden hem klasörü hem adı kontrol eder — doğru klasörde ama öneksiz duran bir dosya da kopyalanır (`AssetImporter.importAll`'un `namePrefix` parametresi).
- **Idempotent:** `AssetImporter` aynı ad + aynı boyut için yeniden kopyalamaz, kaynak zaten hedef klasördeyse aynen döner. Her seçimde ve her eşlemede güvenle çağrılabilir; payload geçişi ikinci çalıştırmada `false` döner.
- **Orijinal silinmez** — kullanıcının kendi dosyasına dokunulmuyor.
- **Kopyanın ömrü:** kaldırma yolları yerel kopyayı silmez; sahipsiz kalanları dünya açılış/kapanışında [[unused_media_sweeper]] temizler.

## Notes
- Bedeli: bulut yüklemesi başarılıyken aynı baytlar hem `media/` altında hem `cache/content/{sha}.bin` içinde duruyor; disk ve LAN transferi bir miktar yineleniyor. Bilinçli takas — resmin kaybolmaması önceliği.
- `_walk` payload taraması **yalnız resim uzantıları** için çalışır; rastgele string'leri dosya sanıp kopyalamamak için.
