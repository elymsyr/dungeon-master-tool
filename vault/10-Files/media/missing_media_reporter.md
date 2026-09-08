---
type: file-note
domain: media
path: flutter_app/lib/application/services/missing_media_reporter.dart
layer: application
language: dart
status: active
updated: 2026-09-08
tags: [file]
---

# `missing_media_reporter.dart`

> [!abstract] Primary Purpose
> Oyuncu tarafı, talep-üzerine medya akışının isteyen ucu. Paylaşılan kart gövdelerindeki `dmt-transient://` ref'lerini tarar, çözülemeyenleri `report_missing_shas` RPC'si ile `world_members.missing_shas`'e yazar ve DM yükledikçe indirir. Karşı ucu [[shared_media_courier]].

## Inputs / Outputs
**Inputs**
- Constructor dep: Riverpod `Ref`, `onResolved` callback ([[world_mirror_applier]] `_bumpRevision`).
- Reads: `activeCampaignProvider.notifier.data['entities']`, `contentStoreProvider`, `assetRefResolverProvider`.
- Triggers: `schedule(worldId)` — `applyInitialState` ve `_applyEntityShareEvent` sonrası (2 sn debounce); eksik varken 15 sn'lik periyodik süpürme.

**Outputs**
- Public API: `schedule`, `dispose`; top-level `collectTransientRefs`.
- Supabase RPC: `report_missing_shas(_world, _shas)` (migration 092).
- Yan etki: çözülen sha'lar [[content_store]]'a iner, `onResolved()` revision bump'ı tetikler.

## Dependencies & Links
- Depends on: [[asset_ref_resolver]], [[content_store]], [[campaign_provider]]
- Used by: [[world_mirror_applier]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Share-Broadcast-Flow]], [[Media-Storage-Tiers]]
- Spec: `docs/media-storage-redesign.md` → "Phase C nasıl uygulandı"

## Key Logic / Variables
- `collectTransientRefs` gövdeyi **şemadan bağımsız** gezer: her string'e bakar, `dmt-transient://` ise `sha → ref` haritasına yazar. Yeni bir medya alanı eklendiğinde burada değişiklik gerekmez.
- Süpürme sırası: `ContentStore.read(sha, touch:false)` → varsa atla; yoksa `AssetRefResolver.resolve` dene; hâlâ yoksa eksik listesine koy.
- Liste **tümüyle** yeniden yazılır (RPC replace semantiği) — çözülen sha kendiliğinden düşer, ayrı temizleme yolu yok.
- RPC başarısızsa `_reported` güncellenmez → aynı liste bir sonraki süpürmede yeniden denenir.
- Debounce 2 sn, retry 15 sn; liste boşalınca periyodik timer durur.
- DM'de hiç tetiklenmez: [[world_mirror_applier]] gövde enjeksiyonunu rol DM ise atlıyor.

## Notes
- `ponytail:` tavan — 15 sn'lik timer, "baytlar geldi" sinyali olmadığı için var. `transient_shares` abone tablolardan biri değil ve olmamalı; doğru yükseltme DM'in yükleme sonrası oyuncunun zaten dinlediği bir satıra dokunması.
- Regresyon testi: `test/application/services/shared_media_on_demand_test.dart`.
