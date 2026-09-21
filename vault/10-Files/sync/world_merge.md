---
type: file-note
domain: sync
path: flutter_app/lib/application/services/content_transfer/world_merge.dart
layer: application
language: dart
status: active
updated: 2026-09-21
tags: [file]
---

# `world_merge.dart`

> [!abstract] Primary Purpose
> Bir dünyanın iki kopyasını **bölüm bazında** birleştirir. Saf fonksiyon: I/O yok, girdileri mutate etmez, aynı girdi hep aynı çıktı — determinizm gereklilik, iki cihaz da birleştirmeyi bağımsız çalıştırıp aynı sonuca yakınsıyor.

## Inputs / Outputs
**Inputs** — `mergeWorldPayloads({local, remote, localStamps, remoteStamps, localFallback, remoteFallback})`; `mergeSectionStamps({local, remote})`.
**Outputs** — birleşmiş payload map'i / birleşmiş `WorldSectionStamps`.

## Dependencies & Links
- Depends on: `core/utils/deep_copy.dart`, `domain/value_objects/world_section_stamps.dart`
- Used by: [[content_codec]] (`_applyWorld`)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[LAN-Sync-Flow]]

## Key Logic / Variables
- Taban kopya item seviyesinde LWW (`remoteFallback > localFallback` ise remote), üstüne bölüm bazlı kararlar yazılır. Şema/template gibi damgası olmayan alanlar tabandan gelir.
- Her bölüm (entities, sessions, map_data, settings anahtarları) kendi damgasıyla ayrı yarışır. Damgası olmayan taraf `*Fallback`'e düşer — o durumda davranış eski tam-değiştirme mantığıdır.
- Neden gerekli: eşleme eskiden item seviyesinde LWW'ydi; A'da savaş notu, B'de mindmap düzenlendiyse yalnız biri hayatta kalıyordu.

## Notes
- **Bilinçli sınır:** tombstone yok, silmeler yayılmaz. A'da silinmiş bir entity B'de duruyorsa birleşimde geri gelir — veri kaybetmemeyi hayalet satıra tercih ediyoruz.
- 2026-09-21'de `lan_sync/`'ten `content_transfer/`'e taşındı; LAN silinince de zip import'un çakışma çözümü olarak kalıyor.
- Test: `test/application/services/content_transfer/world_merge_test.dart` (taşıma sırasında **değiştirilmedi**).
