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
- **FAIL:** N1 sayılar (işaret dahil, `−` = `-`, çoklu küme) · N2 zar ifadeleri · N3 `DC <n>` · N4 sayıya bağlı birimler (`feet`↔`fit`, `mile`↔`mil`, `lb.`/`pound`, `gallon`↔`galon`, `ounce`↔`ons`, `inch`↔`inç`, para aynen) · N5 markdown (`**`, `*`, `_`, satır sonu, madde, `|`) · N6 sadece boşluk ya da İngilizceyle aynı ("aynen kalır" değilse) · N7 parantez.
- **UYARI:** N8 uzunluk oranı 0,7–1,6 dışı (yalnızca 5+ kelimelik metin) · N9 cümle sayısı farkı > 1 (kısaltma ve Türkçe sıra sayısı `3.` sayılmaz) · N10 İngilizcede geçen sözlük terimi Türkçede onaylı karşılığıyla yok.
- **`parseGlossary`** — GLOSSARY.md §3'ten itibaren her `| İngilizce | Türkçe | … |` satırı; `A / B` hücreleri ayrılır, `Cloud / … / Storm Giant` gibi ortak son kelime tek kelimelik parçalara eklenir; parantez içleri ve `<Sınıf>` kalıpları atlanır. "Aynen kalır" = §0'daki liste + İngilizceyle aynı satırlar.
- **N10 eşleşmesi:** uzun terim önce, eşleşen yer maskelenir; çok kelimeli İngilizce terim büyük/küçük harf duyarsız, tek kelimelik duyarlı. Türkçe tarafta son kelimenin tamlama eki atılır, sondaki ünsüzün yumuşamış hali kabul edilir (`Güç` → `gücü`), son kelime isim-fiilse fiil kökü aranır (`Tırmanma` → `tırman`); kelimeler önek olarak aranır (`Kurtarma Zarı` → `kurtarma zarlarına`) — bazı yanlış eşleşmelere göz yumar, kural sadece uyarı.

## Notes
- 2026-10-07 ilk koşu: 768 sözlük terimi, 38 "aynen kalır"; 6433 çiftin 0'ı çevrili, FAIL 0.
- Bilerek bozulmuş çiftlerin (sayı/işaret, zar, DC, birim, kalın, satır sonu, çevrilmemiş, parantez, kısaltılmış, cümle eklenmiş, yanlış terim) her biri testte kendi kuralına takılıyor.
