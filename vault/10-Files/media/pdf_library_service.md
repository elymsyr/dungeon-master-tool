---
type: file-note
domain: media
path: flutter_app/lib/application/services/pdf_library_service.dart
layer: application
language: dart
status: active
updated: 2026-08-20
tags: [file]
---

# `pdf_library_service.dart`

> [!abstract] Primary Purpose
> Bir dünyanın PDF kütüphanesini yönetir: açılan her PDF `{worldsDir}/{worldName}/pdfs/` altına kopyalanır (liste kaynağı **klasörün kendisi** — ayrı tablo yok), dünya online yapıldığında dosyalar R2'ye yüklenir ve `world_settings.settings_json['pdf_library']` manifest'i üzerinden oyunculara duyurulur. Oyuncu manifest satırını **talep üzerine** indirir.

## Inputs / Outputs
**Inputs**
- Providers: `assetServiceProvider`, `activeCampaignProvider`, `campaignRepositoryProvider`, `appDatabaseProvider`, `syncEngineProvider`
- Filesystem: `{AppPaths.worldsDir}/{worldName}/pdfs/`
- Reads: `world_settings.settings_json` (`worldSettingsDao.get`)

**Outputs**
- Provider: `pdfLibraryServiceProvider`
- R2 upload: `AssetService.uploadAsset(kind: MediaKind.worldPdf)` → `dmt-asset://…`
- Writes: `world_settings.settings_json['pdf_library']`; online dünyada `sync_outbox` (`enqueueWorldSettings`)

## Dependencies & Links
- Depends on: [[asset_importer]], [[asset_service]], [[sync_engine]], [[world_repository_impl]]
- Used by: `pdf_sidebar.dart` (`PdfLibraryPanel`), `main_screen.dart`, `player_main_screen.dart`, `save_sync_indicator.dart`, `online_world_section.dart`
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]], [[CDC-Sync-Flow]]

## Key Logic / Variables
- `manifestKey = 'pdf_library'`. **`world_mirror_applier` bu anahtarı fetch-queue'dan hariç tutar** — aksi hâlde inbound settings'teki her PDF (50MB'a kadar) her oyuncuda eager indirilirdi. `scheduleReindex` tam blob'la çalışır, yani `asset_refs` grafiği eksiksiz kalır.
- `import()` → `AssetImporter.importOne`; idempotent (aynı ad + aynı boyut = aynı dosya, yeniden kullanılır).
- `_writeManifest` iki yollu: dünya **açıksa** `activeCampaignProvider.notifier.saveSettingsPatch` (in-memory `_data` + DM gate + outbox); dünya açık **değilse** (hub'dan Make Online) repo'ya doğrudan yazıp merge sonrası **tam blob**'u enqueue eder — cloud satırı full overwrite olduğu için yalnız patch göndermek diğer ayarları silerdi.
- Silme R2 nesnesini bilerek silmez: manifest'ten düşen ref `asset_refs`'ten çıkar, orphan'ı [[eviction_sweeper]] toplar.
- `MediaKind.worldPdf` 50MB — Worker `MAX_UPLOAD_BYTES` ceiling'inin (20MB) üstünde; Worker artık per-kind limiti yetkili sayıyor (`KIND_MAX_BYTES[kind] ?? ceiling`, `Math.min` kaldırıldı).
