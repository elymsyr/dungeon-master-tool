---
type: file-note
domain: media
path: flutter_app/lib/application/services/unused_media_sweeper.dart
layer: application
language: dart
status: active
updated: 2026-08-21
tags: [file]
---

# `unused_media_sweeper.dart`

> [!abstract] Primary Purpose
> Dünyanın `media/` ve `files/` klasörlerinde **hiçbir yerden referans verilmeyen** dosyaları siler. [[local_media_localizer]] seçilen her dosyayı dünyanın kendi klasörüne kopyaladığı için, resmi kaldırma yolları (`cleanupMapImageRef`, `cleanupRemovedEntityImageRef` — ikisi de yalnız **bulut** nesnesini siler) yerel kopyayı sahipsiz bırakıyordu. LAN eşlemesi dünya klasörünün tamamını taşıdığı için o çöp her cihaza gidip orada da kalıyordu.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase` (yalnız `trashDao` okunur).
- Reads: dünya payload'ı (çağırandan gelir), `trash_items.payload_json`, dosya sistemi listelemesi.
- Triggers: dünya **açılışı** (`ActiveCampaignNotifier.completeLoad`, fire-and-forget) ve **kapanışı** (`main_screen._exitToHub`, pending flush'tan sonra await'li).

**Outputs**
- Public API: `sweepWorld({worldName, payload})` → silinen dosya sayısı; `unusedMediaSweeperProvider`; `UnusedMediaSweeper.graceWindow`.
- Writes: `{worldsDir}/{ad}/media/` ve `{worldsDir}/{ad}/files/` altında dosya **silme**. Başka hiçbir yere dokunmaz.

## Dependencies & Links
- Depends on: [[local_media_localizer]] (klasör adları), `trash_dao.dart`
- Used by: [[campaign_provider]] (`sweepUnusedMedia`), `main_screen.dart`
- Domain map: [[Media-and-Assets]]
- System flow: [[LAN-Sync-Flow]]

## Key Logic / Variables
- **Neden silme anında değil süpürge:** `AssetImporter` ad + boyut ile dedupe ediyor, yani aynı dosyayı iki yere koyunca **tek kopya** paylaşılıyor. Kaldırma anında silmek diğer referansı kırardı. Süpürge bütün ağacı gördüğü için bu sorunu yaşamıyor ve daha önce birikmiş çöpü de temizliyor.
- **Üç güvenlik katmanı:**
  1. Yalnız `media/` + `files/` süpürülür — ikisi de tamamen `LocalMediaLocalizer` üretimi. Kullanıcının orijinal dosyasına ve `pdfs/` kütüphanesine asla dokunulmaz.
  2. `trash_items` payload'ları (entity / character / world / package) da referans sayılır → çöpten geri alınan bir entity'nin resmi yerinde durur. JSON decode edilmez; `\\` kaçışları düzeltilip ham metin taranır — false positive zararsız (dosya korunur), false negative tehlikeli olurdu.
  3. **`graceWindow = 10 dk`** — bu süre içinde değiştirilmiş dosyalar atlanır. LAN eşlemesi dosyayı payload'dan önce yazabiliyor; bekleyen debounce yazımı da henüz diske inmemiş olabilir.
- **Sıralama invariantı:** çağırmadan önce `PendingWriteBuffer.flush()` çalışmalı. Kapanış kancası flush'tan sonra, açılış kancası `completeLoad`'un kendi flush'ından sonra.
- Yol karşılaştırması `p.canonicalize` ile (Windows'ta büyük/küçük harf duyarsız).
- Best-effort: hiçbir hata dünya açılışını/kapanışını bozmaz, `debugPrint` ile yutulur.

## Notes
- Karakter medyası (`{charactersDir}/{id}_*`) ve paket klasörleri **süpürülmüyor** — süpürge dünya kapsamında çalışıyor.
- Dünya silindiğinde klasörün tamamı zaten silinmiyor (eskiden beri böyle); bu ayrı bir konu.
