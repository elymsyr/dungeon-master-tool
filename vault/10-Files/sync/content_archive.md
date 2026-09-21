---
type: file-note
domain: sync
path: flutter_app/lib/application/services/content_transfer/content_archive.dart
layer: application
language: dart
status: active
updated: 2026-09-21
tags: [file]
---

# `content_archive.dart`

> [!abstract] Primary Purpose
> `.dmtz` — hesapsız, internetsiz içerik aktarımı. Bir dünya / paket / karakter tek bir zip'e girer, başka bir kurulumda geri açılır. Yedek alma, cihaz değiştirme, DM'in dünyasını oyuncuya dosya olarak verme.

## Inputs / Outputs
**Inputs**
- `exportContentArchive(codec, type, path, {id, name})` — seçili item'ı bulup yazar; `id` yoksa `name` ile eşleşir (`PackageInfo` id taşımıyor).
- `ContentArchive.open(path)` — zip'in JSON girdilerini okur; medya baytları zip'te kalır.

**Outputs**
- Diskte `.dmtz` dosyası; `ContentArchive.item` ([[content_item]]'daki `ContentItemPayload`); `ContentArchiveImportResult(ref, mediaWritten, mediaSkipped)`.
- Hata: `ContentArchiveException(ContentArchiveError.unreadable | unsupportedFormat)`.

Zip düzeni:
```
manifest.json   ref alanları + format / data_root / app_version / media
payload.json    repository.load() blob'u
extras.json     yalnız dünya — installed_packages, ui_view, section_stamps
media/<yol>     baytlar; manifest.data_root'a göreli
```

## Dependencies & Links
- Depends on: [[content_codec]], [[content_item]], `archive: ^4.0.9` (zaten bağımlılık), [[local_media_localizer]] (`dirSafe` → dosya adı)
- Used by: `lib/presentation/widgets/content_archive_menu.dart` — hub Dünyalar/Paketler sekmeleri ve karakter düzenleyici
- Domain map: [[Sync-and-Realtime]]
- System flow: [[LAN-Sync-Flow]] (aynı codec)

## Key Logic / Variables
- **Yol taşınabilirliği için yeni kod yok.** Manifest export eden makinenin `dataRoot`'unu yazıyor, import `ContentCodec.rewriteRoots` ile kendi köküne çeviriyor — LAN'ın iki cihaz arasında yaptığının aynısı, arada zip var.
- Export medyayı **diskten akıtır** (`ZipFileEncoder.addFile`), belleğe almaz. Manifest yalnız gerçekten pakete giren dosyaları listeler; kaybolmuş bir dosya import tarafında "eksik" sayılmasın.
- `manifest.format` bilinmiyorsa **sessiz kabul yok** — `unsupportedFormat` atar. `kContentArchiveFormat = 1`.
- Import her medya için: veri kökü dışıysa atla (yol geçişi savunması) → aynı içerik zaten varsa atla → yazıp **sha doğrula**, tutmazsa dosyayı sil ve atlananlara say.
- Çakışma çözümü ayrı kod değil: `ContentCodec.applyItem` yerelde aynı id varsa `mergeWorldPayloads` ile **bölüm bazlı birleştiriyor** (silme yaymıyor), aynı isimde başka içerik varsa `(2)` ekliyor. Yani import yıkıcı değil ve import diyaloğu gerekmiyor.

## Notes
- **ponytail:** aynı yolda farklı içerikli yerel bir dosya varsa üzerine yazılmıyor. Yol `worlds/<isim>/media/...` olduğu için, isim çakışmasından `(2)` olarak açılan bir import yerel dünyanın resmini ezerdi. Tavan: o durumda import edilen kopya yereldeki resmi gösterir. Gerçek çözüm import sırasında dünya klasörünü de yeniden adlandırmak — dünya kimliği işiyle (Faz 2.5) ucuzluyor.
- **ponytail:** mobilde kaydetme diyaloğu yok — `FilePicker.saveFile` orada baytları istiyor, biz diske akıtıyoruz. Dosya Documents'a yazılıp yolu snackbar'da gösterilir; paylaşım sayfası (`share_plus`) istenirse eklenir.
- "Kopya olarak içe aktar" **yok**: `world_entities` birincil anahtarı global `{id}` olduğu için yeni id'li bir kopya, upsert sırasında var olan dünyanın entity satırlarını kendine çekerdi. Aynı gizli hata `WorldRepositoryImpl.copy`'de de duruyor.
- Test: `test/application/services/content_transfer/content_archive_test.dart` — export/import **iki farklı `AppPaths.dataRoot`** arasında; resmin baytları ve yeniden yazılan yol doğrulanıyor.
