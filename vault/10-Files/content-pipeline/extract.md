---
type: file-note
domain: content-pipeline
path: flutter_app/tool/srd_l10n/bin/extract.dart
layer: tool
language: dart
status: stable
updated: 2026-10-07
tags: [file]
---

# `extract.dart` (srd_l10n)

> [!abstract] Primary Purpose
> SRD Türkçeleştirmenin (`docs/srd-tr/ROADMAP.md` Faz 2) çıkarma aracı: yerleşik şemada ve SRD 5.2.1 paketinde **ekranda görünen** İngilizce metinleri scope başına toplar, `assets/srd_l10n/tr/<scope>.json` iskeletine (`{"<İngilizce>": "<Türkçe>"}`) yazar. Kaynağa dokunmaz — veri İngilizce kalır, çeviri yalnızca ekranda uygulanacak (Yaklaşım A).

## Inputs / Outputs
**Inputs**
- `dart run tool/srd_l10n/bin/extract.dart [--out assets/srd_l10n/tr]` (`flutter_app/`'tan).
- Okur: `generateBuiltinDnd5eV2Schema()` (75 kategori + Tier-0 seed'leri, [[builtin_schema]]) ve `buildSrdCorePack()` (DB'ye giden haliyle Tier-1, [[srd_core_pack]]).

**Outputs**
- `assets/srd_l10n/tr/_schema.json` + kategori slug'ı başına bir dosya. Anahtar = birebir İngilizce metin, değer `""` = çevrilmedi.
- stdout: scope başına metin / kelime / çevrili / bayat tablosu.

## Dependencies & Links
- Kaynak: [[builtin_schema]] · [[srd_core_pack]] · [[srd-pack-content]]
- Kardeşi: [[dump_srd]] (aynı paketi `.pkg.json`'a döker).
- Çıktısını denetleyen: [[check_pairs]].
- Domain map: [[Content-Pipeline]]

## Key Logic / Variables
- **Scope:** `_schema` = kategori adları, alan grubu adları, alan etiketleri, `placeholder`, `helpText`, `subFields` etiketleri, enum seçenekleri. Diğerleri = kategori slug'ı: satır adı, `description`, `text`/`textarea`/`markdown` alanları, `levelTextTable` değerleri, `classFeatures`/`subspeciesOptions` `name`+`description`, `equipmentChoiceGroups`/`playerChoices` `label`+`prompt`+`options[].label`.
- **Makine değeri, çıkarılmaz (K10):** relation/sayı/zar alanları, `tags`, `_machineTextKeys` (`source`, `icon_name`, `color`, `legacy_subspecies_key`, `weapon_mastery_filter`, `granted_tool_variant_group`), `resource-pool` satır adları (`pool:…`; görünen ad `display_name`), `_isProse`'tan geçmeyen değerler (snake_case anahtar, zar/sayı, harfsiz). `proficiencyTable` satır adları ayrıca çıkarılmaz — ability/skill scope'larında zaten var.
- **Mevcut çeviri korunur:** yeniden koşunca var olan değer aynen kalır, yeni anahtar `""` alır, kaynakta artık olmayan anahtar silinmez, "bayat" sütununda sayılır. Sıra kaynak sırasıdır (ad, ardından açıklaması — çevirmene bağlam).

## Notes
- 2026-10-07 ilk koşu: 61 scope, 6433 metin, ~89.000 kelime. En büyükleri `spell` (28k kelime), `magic-item` (17k), `creature-action` (12k), `feat` (11k).
- Tier-0 `condition` satırları sadece ad taşır (kural metni seed'de yok) — dosyada 15 ad var.
