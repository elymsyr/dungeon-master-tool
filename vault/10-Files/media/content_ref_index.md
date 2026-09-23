---
type: file-note
domain: media
path: flutter_app/lib/application/services/content_ref_index.dart
layer: application
language: dart
status: active
updated: 2026-09-23
tags: [file]
---

# `content_ref_index.dart`

> [!abstract] Primary Purpose
> `dmt-content://{sha}{ext}` ile **bu cihazdaki** özgün dosya arasındaki köprü. Ref hiçbir depolama katmanı adlandırmadığı için ("şu baytlar, her neredeyse") onu çözmek her cihazda başka bir iş: baytları üreten cihaz dosyayı diskinde bulmalı, olmayan indirmeli. Bu modül birinci yolu kurar — `content_paths` yan tablosu sha ↔ yol eşlemesini oturumdan uzun tutar. Faz 3.5'in çekirdeği (bkz. `docs/online-sync-redesign.md` §4.5).

## Inputs / Outputs
**Inputs**
- Constructor dep: `AppDatabase Function()` — **tembel** thunk.
- Reads: `content_paths` yan tablosu; dosya sistemi (`stat`, akış hash'i).
- Triggers: [[cloud_push_service]] ve `entity_share_prepare` (`refFor` — giden kopyada yol → ref), [[world_media_sync]] (yüklenecek sha'nın kaynak dosyası), [[asset_ref_resolver]] content dalı.

**Outputs**
- Public API: `refFor(path)`, `shaFor(path)`, `fileForSha(sha)`, `remember(sha, path)`, top-level `shaOfFile(path)`, `contentRefIndexProvider`.
- Writes (Drift): `content_paths` — `(sha, path, size, mtime, updated_at)`, PK `(sha, path)`.
- Ağ: **yok**. Bu sınıf hiçbir zaman buluta çıkmaz.

## Dependencies & Links
- Depends on: [[drift_database]]
- Used by: [[cloud_push_service]], [[world_media_sync]], [[asset_ref_resolver]], [[cloud_pull_service]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]], [[Share-Broadcast-Flow]]
- Spec: `docs/online-sync-redesign.md` §2.7 + §4.5

## Key Logic / Variables
- **`shaFor(path)`** — önce `stat`; tabloda aynı `path` için `size`+`mtime`'ı tutan satır varsa sha oradan döner ve **dosya yeniden hash'lenmez**. Tutmuyorsa o yolun satırları atılır, dosya akış üzerinden hash'lenir (`sha256.bind(openRead())` — 100 MB'lık handout belleğe alınmaz), yeni satır yazılır.
- **`fileForSha(sha)`** — her okumada `size`+`mtime` yeniden doğrulanır. **Bu doğrulama load-bearing:** aynı yola farklı baytlar yazıldığında eski satır hâlâ "bu sha şu dosyada" der ve oyuncuya **yanlış resim** servis edilirdi. Doğrulamayan satır silinir, sonraki sha varsa ona bakılır.
- **PK `(sha, path)`** — aynı baytlar iki yolda durabilir (biri silinirse öteki çözer), aynı yol zamanla farklı baytlar taşıyabilir.
- **DB thunk tembeldir.** Provider gövdesinde veritabanı açmak, DB'si hiç kurulmayan alt-izolatta (player sub-window, `main()` `multi_window` dalı) çözücüyü patlatırdı. Tüm sorgular ayrıca `try/catch` → boş sonuç.
- Tablo **cihaz-yereldir ve senkronlanmaz** — aynı sha her cihazda başka yolda. Silinse maliyet bir kerelik yeniden hash'leme.

## Notes
- `asset_refs` ([[reference_graph]]) bu işi **yapamaz**: `ReferenceIndexer._isAssetRef` ham yolları kasten indekslemiyor (silinen yollar false-orphan üretirdi), orada yerel dosya diye satır yok. Belgedeki "DM `asset_refs`'ten çözer" cümlesi bu yüzden düzeltildi.
- Yeni bir ref şeması eklerken gezilecek liste: [[asset_ref_resolver]], `reference_indexer.dart`, [[publish_media_pinner]], `eviction_sweeper.dart`, [[cloud_push_service]] `mediaRefsOf`.
- Faz 5d: `SharedMediaCourier.refFor` bu sınıfın `refFor`'unu sarmalamaktan ibaretti; courier silindi, çağıranlar doğrudan buraya geliyor.
- Regresyon testi: `test/application/services/content_ref_index_test.dart` (bayat satır + silinen dosya + aynı baytlar iki yolda).
