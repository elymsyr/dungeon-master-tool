---
type: file-note
domain: media
path: flutter_app/lib/application/services/pdf_library_service.dart
layer: application
language: dart
status: active
updated: 2026-09-24
tags: [file]
---

# `pdf_library_service.dart`

> [!abstract] Primary Purpose
> Bir dünyanın PDF kütüphanesi: açılan her PDF `{worldsDir}/{worldId}/pdfs/` altına kopyalanır ve liste kaynağı **klasörün kendisi**dir. Klasör Faz 2.5'ten beri dünya **id**'si ile anahtarlı, yani yeniden adlandırma kütüphaneyi taşımıyor. **Tamamen yerel** — Phase D'de bulut paylaşımı (R2 upload + `settings_json['pdf_library']` manifest'i + oyuncu indirmesi) kaldırıldı. PDF'ler `.dmtz` ile taşınır; veri kökü altında oldukları için `ContentCodec._mediaFor` onları zaten kapsıyor.

## Inputs / Outputs
**Inputs**
- Filesystem: `{AppPaths.worldsDir}/{worldId}/pdfs/`
- Providers: yok (servis `const`).

**Outputs**
- Provider: `pdfLibraryServiceProvider`
- Public API: `libraryDir(worldName)`, `localFiles(worldName)`, `import(worldName, sourcePath)`, `remove(worldName, fileName)`
- Writes: yalnızca dosya sistemi. Bulut yazımı yok.

## Dependencies & Links
- Depends on: [[asset_importer]], `core/config/app_paths.dart`
- Used by: `pdf_sidebar.dart` (`PdfLibraryPanel`), `main_screen.dart`, `player_main_screen.dart`, [[bundled_worlds_installer]]
- Domain map: [[Media-and-Assets]]
- System flow: `docs/media-storage-redesign.md` (Phase D — "Göç"), [[content_codec]]

## Key Logic / Variables
- **Klasör adı [[local_media_localizer]]'ın `worldDir`'ünden geliyor.** Önce `p.join(worldsDir, worldName, 'pdfs')` ham adla kuruluyordu: adında `:` olan bir dünyada Windows'ta liste okuması patlıyor, medya ise sanitize edilmiş klasöre yazıldığı için iki taraf ayrışıyordu.
- `localFiles()` klasörü tarar, `.pdf` uzantılıları son değişme tarihine göre sıralar.
- `import()` → `AssetImporter.importOne`; idempotent (aynı ad + aynı boyut = aynı dosya, yeniden kullanılır).
- `remove()` yalnızca yerel dosyayı siler.

## Notes
- Kaldırılanlar (Phase D): `share`, `shareAll`, `download`, `manifest`/`manifestOf`/`_writeManifest`, `manifestKey`, `PdfLibraryEntry`, `PdfShareFailure`. `world_pdf` buluttaki en büyük counted kalemdi (50 MB/dosya).
- **Davranış değişikliği:** online oyuncu artık DM'in PDF'ini uygulama içinden indiremez. Eski dünyaların `settings_json['pdf_library']` girdileri zararsız artık veridir — okuyucusu kalmadı.
