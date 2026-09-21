---
type: file-note
domain: sync
path: flutter_app/lib/application/services/content_transfer/content_item.dart
layer: application
language: dart
status: active
updated: 2026-09-21
tags: [file]
---

# `content_item.dart`

> [!abstract] Primary Purpose
> İçerik aktarımının veri sözleşmesi — saf Dart, hiçbir taşıma katmanına bağlı değil. Aynı üç tip hem LAN telinde hem `.dmtz` zip'inde geçiyor.

## Inputs / Outputs
**Inputs** — JSON map'ler (`fromJson`), DB satırlarından kurulan nesneler.
**Outputs** — `toJson()` map'leri; `ContentItemType` ↔ wire string çevirisi.

Tipler:
- `ContentItemType { world, package, character }` + `contentItemTypeFromWire/ToWire`.
- `ContentItemRef` — kimlik satırı: `type, id, name, updatedAt, viewUpdatedAt?, renamedAt?`. `updatedAt` **milisaniyeye yuvarlanır** (JSON round-trip'te mikrosaniye farkı iki tarafın aynı içeriği farklı sanmasına yol açıyordu). `effectiveUpdatedAt` = içerik ve görünümün yenisi; LWW karşılaştırması bunu kullanır.
- `ContentMediaEntry` — `path` (veri köküne göreli, POSIX ayırıcı) + `sha256` + `size`.
- `ContentItemPayload` — `ref` + `payload` (repository blob'u) + `dataRoot` (**gönderenin** kökü) + `media` + `extras`.

## Dependencies & Links
- Depends on: — (saf Dart)
- Used by: [[content_codec]], [[content_archive]], [[lan_sync_protocol]], [[lan_sync_server]], [[lan_sync_client]]
- Domain map: [[Sync-and-Realtime]]
- System flow: [[LAN-Sync-Flow]]

## Key Logic / Variables
- `extras` yalnız dünya için dolu: `installed_packages`, `ui_view`, `section_stamps`. Blob cloud-backup kontratı olduğu için genişletilmedi, bunlar yanına ayrı bölüm olarak takıldı. `dataRoot` yeniden yazımı payload ile aynı şekilde `extras`'a da uygulanır.
- `dataRoot` alıcı tarafta prefix takasının girdisi — `ContentCodec.rewriteRoots(payload, item.dataRoot, userBase)`.

## Notes
- 2026-09-21'de `lan_sync_protocol.dart`'tan çıkarıldı (`Lan*` → `Content*`). LAN Faz 6'da silinirken codec'in sözleşmesi kalmalı; `lan_sync_protocol.dart` bu dosyayı `export` ederek eski import'ları bozmadan sürdürüyor. Bkz. `docs/online-sync-redesign.md` §4.2.
- Test: `test/application/services/lan_sync/lan_sync_protocol_test.dart` (JSON round-trip + `diffManifests`).
