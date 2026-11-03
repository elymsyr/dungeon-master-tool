---
type: file-note
domain: content-pipeline
path: flutter_app/tool/srd_l10n/bin/suggest.dart
layer: tool
language: dart
status: active
updated: 2026-11-03
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
- `spell.json`, `class.json`, `subclass.json`, `species.json`, `background.json`'daki boş anahtarlar; stdout'ta her öneri ve sayısı.

## Dependencies & Links
- Depends on: [[free_srd_pack]], [[srd_core_pack]], [[entity_ref]]
- Önce: [[extract]] · sonra: [[check_pairs]] · okuyan: [[content_translator]]
- Domain map: [[Content-Pipeline]]
- Spec / reference: `docs/free-template/SRD-FREE-ALANLAR.md` §7, §8; `docs/srd-tr/GLOSSARY.md` (§2 üslup, §4.18 birimler, §4.27 S/B/M)

## Key Logic / Variables
- **Büyü (A2):** Casting Time — Eylem / Bonus Eylem / Reaksiyon ya da "N dakika|saat", tepkide "Reaksiyon, <tetikleyicinin çevirisi, küçük harf, noktasız> alırsın", ritüelde "… ya da Ritüel". Range — "N fit", gerisi `_schema`. Components — V/S/M → S/B/M (rehber), malzemenin çevirisi küçük harfle; dönüştürücü "which the spell consumes" eklediyse "büyünün tükettiği, …" (mevcut çevirilerin kalıbı), eklenmiş maliyet ", N+ GP değerinde". Duration — Anlık, "Defedilene kadar", Özel, "N dakika|saat|gün|raunt" (sayıdan sonra çoğul yok), "Konsantrasyon, N dakikaya|saate|güne|raunda kadar".
- **Seviye tablosu satırları (A4):** `class` / `subclass`'ta boş kalan `**Ad.** metin` anahtarı, adın ve metnin aynı tablodaki çevirisinden (`_rowTr`).
- **Türün Traits yazısı (A4):** açılış cümlesi `_intros`'tan, paragraflar `trait` / `creature-action` / `sense` tablolarından; duyu paragrafı "N fit menzilli <duyu>n vardır." (`_traitsTr`).
- **Sınıf ve geçmiş (A5):** Primary Ability (kabiliyet adları, ve / ya da), "Şunlardan N tanesini seç: a, b ya da c", "Basit ve Askeri silahlar", araç adları; Starting Equipment / Equipment "A'yı ya da B'yi seç: (A) …; ya da (B) …", şıklar seçenek etiketinin mevcut çevirisinden, sınıfta son parçadan önce "ve" (`_equipmentTr`). Becoming a… kutusu sınıf adı, -ın hali ve elle çevrilmiş çok sınıf satırıyla (`_classes`); PDF'ten gelen sabit satırlar `_ownLines`'ta.
- **Canavar ve eylem (A6):** Speed satırı sözcük sözcük (`_speedTr`: Kazma, Tırmanma, Uçma, Yüzme, süzülme). Eylem metni (`_actionTr`) asıl metnin mevcut çevirisine aynı eklerle: başa "(Yenilenme 5–6). " / "(Günde 3). " / "(Kısa ya da Uzun Dinlenmeden sonra yenilenir). ", eksik DC kurtarma satırına ("*Çeviklik Kurtarma Zarı:* DC 14, …") ya da başa (`ability.json`'dan yetenek adıyla).
- Türkçe küçük harf: `I → ı`, `İ → i`.
- Kurucu dönüştürücünün yapısını izler ama ayrı yazılmıştır: dönüştürücüde bir satır biçimi değişirse burası da değişmeli (öneri yanlış çıkar, gözden geçirmede yakalanır).

## Notes
- 2026-10-28 ilk koşu (A2): 236 büyü satırı; check_pairs 0 FAIL, yeni anahtarlardan 2 UYARI (mevcut malzeme çevirisinden).
- 2026-11-03 A4: 162 sınıf + 63 alt sınıf satırı, 10 Traits yazısı. A5: 50 sınıf + 27 geçmiş anahtarı; check_pairs 0 FAIL. A6: 67 canavar + 31 hayvan Speed satırı, 31 eylem metni.
