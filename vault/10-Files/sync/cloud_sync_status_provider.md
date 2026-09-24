---
type: file-note
domain: sync
path: flutter_app/lib/application/providers/cloud_sync_status_provider.dart
layer: application
language: dart
status: active
updated: 2026-09-24
tags: [file]
---

# `cloud_sync_status_provider.dart`

> [!abstract] Primary Purpose
> Bulut aynasının kullanıcıya görünen hali (Faz 9, `docs/online-sync-redesign.md` §4.8.5). Senkron arka planda ve sürekli; bu dosyadan önce başarısızlık yalnız `debugPrint`'ti. Online dünya ya da paket başına: kaç tur koşuyor, son deneme ağa çıkabildi mi, hangi türde sorun var, son başarılı push ne zaman.

## Inputs / Outputs
**Inputs**
- [[cloud_push_provider]] (`CloudPushPump`) — push / pull / medya turlarının başı (`started`), sonu (`ended`) ve sonucu (`report`); online olmayan öğede `remove`, rol çözülemeyen online dünyada `markOffline`.
- `entity_provider._pushIfShared` — paylaşılan kartın otomatik yeniden gönderimi (`share` türü).

**Outputs**
- `cloudSyncStatusProvider` → `Map<String, CloudSyncStatus>`; anahtar dünyada id, pakette **paket adı** (paket ekranı `activeCampaignProvider`'ı adla override ettiği için gösterge tek okumayla ikisini de bulur).
- `CloudSyncStatus`: `running` / `syncing`, `offline`, `problems` (`CloudSyncIssue` → `CloudSyncProblem(count, error?)`), `syncedAt`, `problemCount`.

## Dependencies & Links
- Depends on: `core/utils/error_format.dart` (`isOfflineError`, `formatError`).
- Used by: `save_sync_indicator.dart` (araç çubuğu simgesi + diyalogdaki "Bulut" bölümü ve Yeniden dene), [[cloud_push_provider]], `entity_provider.dart`.
- Domain map: [[Sync-and-Realtime]]

## Key Logic / Variables
- **Türler birbirini temizlemez** (`push`, `pull`, `media`, `quota`, `share`): her tür kendi son sonucuyla değişir — pull'un başarısı push'un reddettiği satırları silmez.
- **Ağ hatası sorun değil:** öğe `offline`'a düşer, eski sorun yerinde kalır; bağlantı gelince ilk tur ikisini de temizler. Başka hata `problems[kind]`'a `formatError` metniyle; hatasız ama reddedilen satır/dosya `CloudSyncProblem(count)` (error null).
- `syncedAt` yalnız temiz bir **push** turunda ilerler.
- **Kayıt yalnız online öğe için:** pompa online olmayan öğede turu başlatmadan `remove` çağırıyor; `ended` olmayan kaydı geri açmıyor. Yoksa yerel dünyada gösterge her 3 sn'de "eşitleniyor"a dönerdi. Multiplayer / paket online kapatma UI'ı da (`save_sync_indicator`, `online_world_section`) kaydı hemen siliyor — yoksa kapatılan öğe bir sonraki tura kadar "eşit" ya da sorun rozetiyle görünürdü.
- Göstergenin önceliği (`SaveSyncIndicator._look`): sorun > çevrimdışı > yerel kayıt > eşitleniyor > eşit > (kayıt yok) yalnız yerel.

## Notes
- Test: `test/application/providers/cloud_sync_status_test.dart`.
- Bilinçli dışarıda: taslaktaki "etkinlik listesi" yerine diyalogda tek satır durum + sorun listesi; "Online yap" tam push'unda satır ilerlemesi yok (düğme etiketi meşgul hali taşıyor).
