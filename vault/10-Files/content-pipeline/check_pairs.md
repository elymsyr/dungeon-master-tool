---
type: file-note
domain: content-pipeline
path: flutter_app/tool/srd_l10n/bin/check_pairs.dart
layer: tool
language: dart
status: stable
updated: 2026-10-07
tags: [file]
---

# `check_pairs.dart` (srd_l10n)

> [!abstract] Primary Purpose
> SRD Türkçeleştirmenin (`docs/srd-tr/ROADMAP.md` Faz 3) çift denetimi: `assets/srd_l10n/tr/<scope>.json` içindeki her `İngilizce → Türkçe` çiftinin içeriği değiştirmediğini (sayı, zar, DC, birim, markdown) makineyle denetler; sözlük uyumunu ve şüpheli uzunluk/cümle farkını insana uyarı olarak çıkarır. Her çeviri dalgası bu araçtan FAIL 0 ile geçer (kapı G2).

## Inputs / Outputs
**Inputs**
- `dart run tool/srd_l10n/bin/check_pairs.dart [--dir assets/srd_l10n/tr] [--glossary ../docs/srd-tr/GLOSSARY.md] [scope ...]` (`flutter_app/`'tan).
- Çeviri tabloları ([[extract]]'in yazdığı iskeletler) + `docs/srd-tr/GLOSSARY.md`.

**Outputs**
- stdout: sorunlu çiftler (`[scope] "<İngilizce>"` + `FAIL|UYARI Nx …`), ardından scope başına `çevrili / toplam | kapsam | FAIL | UYARI` tablosu.
- Çıkış kodu 1 = en az bir FAIL.

## Dependencies & Links
- Denetlediği çıktı: [[extract]]
- Domain map: [[Content-Pipeline]]
- Test: `test/tool/srd_l10n_check_pairs_test.dart`

## Key Logic / Variables
- **`checkPair(en, tr, glossary)`** — tek çift için bulgular. Değeri `""` olan çift çağrılmaz (çevrilmemiş, sadece kapsamda sayılır).
- **FAIL:** N1 sayılar (işaret dahil, `−` = `-`, çoklu küme) · N2 zar ifadeleri · N3 `DC <n>` · N4 sayıya bağlı birimler (`feet`↔`fit`, `mile`↔`mil`, `lb.`/`pound`, `gallon`↔`galon`, `ounce`↔`ons`, `inch`↔`inç`, para aynen) · N5 markdown (`**`, `*`, `_`, satır sonu, madde, `|`) · N6 sadece boşluk ya da İngilizceyle aynı (metin yalnızca "aynen kalır" terimleri, sayı ve noktalamadan oluşuyorsa geçer — `NPC`, `cp 0.01, sp 0.1, …`) · N7 parantez.
- **UYARI:** N8 uzunluk oranı 0,7–1,6 dışı (yalnızca 5+ kelimelik metin) · N9 cümle sayısı farkı > 1 (kısaltma ve Türkçe sıra sayısı `3.` sayılmaz) · N10 İngilizcede geçen sözlük terimi Türkçede onaylı karşılığıyla yok.
- **`parseGlossary`** — GLOSSARY.md §3'ten itibaren her `| İngilizce | Türkçe | … |` satırı; `A / B` hücreleri ayrılır, `Cloud / … / Storm Giant` gibi ortak son kelime tek kelimelik parçalara eklenir; parantez içleri ve `<Sınıf>` kalıpları atlanır. "Aynen kalır" = sözlükteki her `… aynen kalır: A · B · C` paragrafı (§0 listesi, §4.26 dış düzlem adları; tablo satırları hariç) + İngilizceyle aynı satırlar.
- **N10 eşleşmesi:** uzun terim önce, eşleşen yer maskelenir; çok kelimeli İngilizce terim büyük/küçük harf duyarsız, tek kelimelik duyarlı. Türkçe tarafta son kelimenin tamlama eki atılır, sondaki ünsüzün yumuşamış hali kabul edilir (`Güç` → `gücü`), son kelime isim-fiilse fiil kökü aranır (`Tırmanma` → `tırman`), sondaki çoğul eki atılır (sayıdan sonra tekil: `Sihirbazlık Puanları` → `3 Sihirbazlık Puanı`); kelimeler önek olarak aranır (`Kurtarma Zarı` → `kurtarma zarlarına`) — bazı yanlış eşleşmelere göz yumar, kural sadece uyarı.

## Notes
- 2026-10-07 dalga 5.2: `_schema` 597 metin, FAIL 0 · UYARI 6; 55 "aynen kalır" (`NPC`); N6 terim+sayı istisnası. 980 / 6404 çevrili.
- 2026-10-07 dalga 5.3–5.5: ekipman (337), tür/geçmiş/sınıf/alt sınıf/nitelik (1101), hüner (749) — FAIL 0 · UYARI 65 (yanlış eşleşmeler); 56 "aynen kalır" (`GP`); N10 çoğul toleransı. 3167 / 6404 çevrili.
- 2026-10-07 dalga 5.6: `spell` (960) — FAIL 0 · UYARI 41 (yanlış eşleşmeler); "aynen kalır"a `Alarm`, `Tsunami` (58). N4 tuzağı: `10 additional gallons` birim sayılmaz → TR'de de rakam birimin hemen önünde olmamalı (`10 ek galon`, `40,000 kare fit`). 4127 / 6404 çevrili.
- 2026-10-07 dalga 5.1: 54 "aynen kalır" (§4.26 listesi eklendi); 383 / 6404 çevrili, FAIL 0 · UYARI 0.
- 2026-10-07 ilk koşu: 768 sözlük terimi, 38 "aynen kalır"; 6433 çiftin 0'ı çevrili, FAIL 0.
- Bilerek bozulmuş çiftlerin (sayı/işaret, zar, DC, birim, kalın, satır sonu, çevrilmemiş, parantez, kısaltılmış, cümle eklenmiş, yanlış terim) her biri testte kendi kuralına takılıyor.
