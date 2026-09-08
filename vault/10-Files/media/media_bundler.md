---
type: file-note
domain: media
path: flutter_app/lib/application/services/media_bundler.dart
layer: application
language: dart
status: stable
updated: 2026-09-08
tags: [file]
---

# `media_bundler.dart`

> [!abstract] Primary Purpose
> Bir karakter JSON map'inin medyasını `world_characters` satırı yazılmadan hemen önce buluta taşır: portre → ücretsiz Supabase Storage (`dmt-public://`), ek resimler → **pinned** R2 havuzu (`pub/{sha}{ext}`). Map deep-clone edilir, orijinal graf değişmez.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AssetService` (pinned upload), opsiyonel [[free_media_service]] (portre).
- Reads: `characterMap['entity'].imagePath` / `.images[]` içindeki yerel yollar.
- Triggers: `character_provider._pushCharacterToMirror` (her karakter kaydı).

**Outputs**
- Public API: `bundleCharacterMedia({scopeId, characterMap})`; static `characterPinKey(characterId)`.
- Supabase/RPC: `pub_asset_reserve` (AssetService.uploadPub üzerinden), `FreeMediaService.uploadFreeMedia`.

## Dependencies & Links
- Depends on: [[free_media_service]], [[asset_service]], `domain/value_objects/asset_ref.dart`, `domain/value_objects/media_kind.dart`, `core/utils/deep_copy.dart`
- Used by: [[character_provider]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Share-Broadcast-Flow]], `docs/media-storage-redesign.md`

## Key Logic / Variables
- **Neden karakter istisna:** `world_characters` beş abone tablodan biri, karakter her zaman sync'tir; medyası oturum ortasında LRU'ya yem olmamalı. Bu yüzden ek resimler transient değil `pinned`.
- **Refcount sahibi** `char:{characterId}` (`characterPinKey`). Karakter silinince `character_provider.delete` → `AssetService.releasePub(refKey)`; son ref gidince obje havuzdan düşer.
- `ponytail:` aynı ref_key altında eski sha bırakılmıyor — kullanıcı resmini değiştirirse eskisi karakter silinene kadar refcount'ta kalır.
- Zaten bulutta olan (local olmayan) ref'lere dokunulmaz; tek dosya hatası akışı kesmez (null → yerel yol korunur).

## Notes
- Phase D'de silinenler: `bundleWorldMedia`, `bundleEntityMedia`, `bundleMapMedia`, `bundleSettingsMedia`, `MediaBundleResult`/`MediaBundleFailure`, `sha256Of`. Hepsi sayılan (`uploadAsset`) katmana bağlıydı ve tek çağıranı kalmıştı.
