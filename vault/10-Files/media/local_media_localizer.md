---
type: file-note
domain: media
path: flutter_app/lib/application/services/local_media_localizer.dart
layer: application
language: dart
status: active
updated: 2026-09-21
tags: [file]
---

# `local_media_localizer.dart`

> [!abstract] Primary Purpose
> Statik yardımcı sınıf: seçicinin verdiği **ham dosya yollarını veri kökünün içine** kopyalar. `RawPathMigrator`'ın çevrimdışı karşılığı — bulut servisi gerektirmez, ref'e çevirmez, sadece dosyayı içeriğin kendi klasörüne (`{worldsDir}/{worldId}/media/`, `{packagesDir}/{ad}/media/`, `{charactersDir}/{id}_*`) alır ve kopyanın yolunu döndürür. Ham yol ne LAN eşlemesinde taşınır (`ContentCodec._mediaFor` yalnız içeriğin kendi klasörünü tarar) ne de kullanıcı orijinali taşıdığında açılır.

> [!important] Dünya klasörü **id** ile anahtarlı (Faz 2.5, 2026-09-21)
> `worldDir(worldId)` — isimle değil. İsimle anahtarlıyken iki dünya aynı adı taşıyamıyordu: taşısalardı aynı klasörü paylaşır, birini açıp kapatmak [[unused_media_sweeper]] üzerinden ötekinin dosyalarını referanssız sayıp silerdi. Yeniden adlandırma da artık klasöre dokunmuyor — eskiden klasörü taşıyıp gövdedeki **mutlak** yolları olduğu gibi bıraktığı için her yeniden adlandırma resimleri kırıyordu. Mevcut kurulumları taşıyan tek seferlik geçiş [[drift_database]] `beforeOpen`'ında: `world_media_dir_by_id_v1`. **Paket klasörü hâlâ adla** — paketler bu fazın kapsamında değil.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: **yok** — hepsi `static`, yalnız `AppPaths` + `AssetImporter` okur.
- Reads: dosya sistemi (`File.exists`, kopyalama `AssetImporter` üzerinden).
- Triggers: her medya seçimi (bkz. *Used by*) ve `ContentCodec.loadItem` onarım geçişi.

**Outputs**
- Public API: `localize(path, {ownerDir, subDir, imagesOnly})`, `localizeAll(...)`, `localizeCharacterImage(path, {characterId})`, `localizeWorldPayload(payload, worldId)`, `localizePackagePayload(payload, packageName)`, `worldDir(worldId)`, `packageDir(name)`, sabitler `mediaSubDir = 'media'` / `filesSubDir = 'files'`.
- Writes: `{ownerDir}/{subDir}/` altına dosya kopyası; payload varyantları ağacı **yerinde** günceller ve değişiklik olduysa `true` döner (çağıran kaydeder).

## Dependencies & Links
- Depends on: [[asset_importer]], `core/config/app_paths.dart`, `domain/value_objects/asset_ref.dart`
- Used by: [[entity_image_upload]], `map_image_upload.dart`, [[content_codec]], [[content_archive]], `data/repositories/character_repository.dart`, `presentation/widgets/metadata_editor_section.dart`, `field_widget_factory.dart` (`file`/`pdf` alanları)
- Domain map: [[Media-and-Assets]]
- System flow: [[LAN-Sync-Flow]], [[Media-Storage-Tiers]]

## Key Logic / Variables
- **`dirSafe` Windows'ta tek kapı.** Yasak karakter sınıfı (`\ / : * ? " < > |`), kontrol karakterleri, sondaki nokta/boşluk, boş ad ve MS-DOS aygıt adları (`CON`, `NUL`, `COM1`…, uzantılıları dahil) `_` ile karşılanır. Linux/Android bunları kabul ettiği için hata yalnız Windows'ta çıkıyordu: `Aegis — Meridia: Birinci Perde` gibi bir başlıkta `Directory.exists` bile `ERROR_INVALID_NAME (123)` fırlatıyor. Temiz adlarda birim fonksiyon — var olan klasörler yerinde kalır. `packageDir` hâlâ ada bakıyor, dolayısıyla paketlerde bu kapı duruyor; `worldDir`'e gelen uuid zaten temiz olduğu için orada birim fonksiyon.
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
