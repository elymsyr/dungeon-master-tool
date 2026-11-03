---
type: file-note
domain: content-pipeline
path: flutter_app/tool/srd_l10n/bin/suggest.dart
layer: tool
language: dart
status: active
updated: 2026-10-28
tags: [file]
---

# `suggest.dart` (srd_l10n)

> [!abstract] Primary Purpose
> Free SRD'nin Türkçe öneri aracı (`docs/free-template/SRD-FREE-ALANLAR.md` §8): [[free_srd_pack]]'in parçalardan kurduğu İngilizce satırların Türkçesini, aynı kartın parçalarının mevcut çevirisinden kurar ve `assets/srd_l10n/tr/` tablolarında boş (`""`) kalan anahtara yazar. Dolu çeviriye dokunmaz; öneriler gözden geçirilir, sonra [[check_pairs]].

## Inputs / Outputs
**Inputs**
- `dart run tool/srd_l10n/bin/suggest.dart` (`flutter_app/`'tan), [[extract]]'tan sonra (yeni anahtarlar `""` ile eklenmiş olmalı).
- Okur: `buildSrdCorePack()` ([[srd_core_pack]]), `freeSrdFields` ([[free_srd_pack]], İngilizce satır = anahtar), `spell.json` (malzeme ve tepki tetikleyicisi çevirileri), `_schema.json` (Self / Touch / Sight / Unlimited / Special).

**Outputs**
- `spell.json`'daki boş anahtarlar; stdout'ta her öneri ve sayısı.

## Dependencies & Links
- Depends on: [[free_srd_pack]], [[srd_core_pack]], [[entity_ref]]
- Önce: [[extract]] · sonra: [[check_pairs]] · okuyan: [[content_translator]]
- Domain map: [[Content-Pipeline]]
- Spec / reference: `docs/free-template/SRD-FREE-ALANLAR.md` §7, §8; `docs/srd-tr/GLOSSARY.md` (§2 üslup, §4.18 birimler, §4.27 S/B/M)

## Key Logic / Variables
- **Büyü (A2):** Casting Time — Eylem / Bonus Eylem / Reaksiyon ya da "N dakika|saat", tepkide "Reaksiyon, <tetikleyicinin çevirisi, küçük harf, noktasız> alırsın", ritüelde "… ya da Ritüel". Range — "N fit", gerisi `_schema`. Components — V/S/M → S/B/M (rehber), malzemenin çevirisi küçük harfle; dönüştürücü "which the spell consumes" eklediyse "büyünün tükettiği, …" (mevcut çevirilerin kalıbı), eklenmiş maliyet ", N+ GP değerinde". Duration — Anlık, "Defedilene kadar", Özel, "N dakika|saat|gün|raunt" (sayıdan sonra çoğul yok), "Konsantrasyon, N dakikaya|saate|güne|raunda kadar".
- Türkçe küçük harf: `I → ı`, `İ → i`.
- Kurucu dönüştürücünün yapısını izler ama ayrı yazılmıştır: dönüştürücüde bir satır biçimi değişirse burası da değişmeli (öneri yanlış çıkar, gözden geçirmede yakalanır).

## Notes
- 2026-10-28 ilk koşu (A2): 236 büyü satırı; check_pairs 0 FAIL, yeni anahtarlardan 2 UYARI (mevcut malzeme çevirisinden).
