---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/content_translator.dart
layer: domain
language: dart
status: stable
updated: 2026-10-07
tags: [file]
---

# `content_translator.dart`

> [!abstract] Primary Purpose
> SRD içerik çevirisinin çalışma zamanı (`docs/srd-tr/ROADMAP.md` §3, Faz 4): ekrana basılan İngilizce içerik metnini seçili dildeki karşılığıyla değiştirir. Anahtar birebir İngilizce kaynak metin; eşleşmeyen ya da çevrilmemiş (`""`) metin aynen döner. **Veri hep İngilizce kalır** (K3) — kural motoru, ref çözümü ve kayıt yolu çeviriyi hiç görmez.

## Inputs / Outputs
**Inputs**
- Tablolar: scope (kategori slug'ı ya da `_schema`) → İngilizce → çeviri. Yükleyici `lib/application/providers/content_translator_provider.dart`: `contentTranslatorProvider` `localeProvider`'ı izler; `assets/srd_l10n/<dil>/*.json`'ı `AssetManifest` ile bulur, boş değerleri atar. Tablosu olmayan dil (ve yüklenene kadar) → `ContentTranslator.identity`.

**Outputs**
- `tr(scope, en)` → çeviri ya da `en`.
- `field(FieldSchema)` → etiket / placeholder / helpText / `subFields` etiketi `_schema`'dan çevrilmiş kopya; değişiklik yoksa aynı nesne.
- `value(scope, field, v)` → gösterilecek değer; girdi asla değişmez, koleksiyonlar kopyalanır.

## Dependencies & Links
- Tabloları üreten / denetleyen: [[extract]] · [[check_pairs]] (makine anahtarları listesi `srdL10nMachineTextKeys` buradan, çıkarma aracıyla ortak).
- Şema modeli: [[field_schema]]
- Domain map: [[World-and-Content]]
- Testler: `test/domain/services/content_translator_test.dart` (birim) · `test/presentation/srd_tr_entity_card_test.dart` (gerçek dünya + gerçek tablolar + gerçek `EntityCard`).

## Key Logic / Variables
- **`value` hangi alanları çevirir** (çıkarma aracıyla aynı kural): `text`/`textarea`/`markdown` metni (kategori scope'u), `enum_` değerleri (`_schema`), `levelTextTable` değerleri, `classFeatures`/`subspeciesOptions` satırlarının `name`+`description`'ı, `equipmentChoiceGroups`/`playerChoices`'ın `label`+`prompt`+`options[].label`'ı. Relation, sayı, zar, ref zarfları ve `srdL10nMachineTextKeys` (`source`, `icon_name`, `color`, …) dokunulmaz.
- **Ekrandaki bağlantı noktaları:**
  - `entity_card.dart` — okuma modunda ad + açıklama + alan değerleri; alan etiketleri, grup adları ve kategori adı alt başlığı her modda. Düzenleme modunda değerler İngilizce. Açıklama okuma modunda ayrı `_descViewController`'da durur; kayıt yolu yalnızca `_descController`'ı okur. Değer çevrildiyse `onChanged` boşa düşer — çevrilmiş değer asla geri yazılmaz.
  - `entity_sidebar.dart` — kategori adları (filtre, yeni kart diyaloğu, satır etiketi); slug aynı kalır.
- **Metin anahtarlı olmasının sonucu:** kullanıcı bir alanı düzenlerse metin tabloyla eşleşmez, yazdığı görünür; düzenlenmemiş alanlar çevrili kalır. SRD kartını düzenlemek kopya üretir (fork-on-edit) — kopya aynı İngilizce metni taşıdığı için çevrili görünür.

## Notes
- 2026-10-07 pilot: `ability`, `skill`, `condition`, `damage-type` tam çevrili (95 metin, `check_pairs` FAIL 0 · UYARI 0). Diğer scope'lar boş → İngilizce.
- Kenar listesindeki kart adları, ref çipleri, arama, projeksiyon penceresi henüz çevrilmiyor (ROADMAP Faz 6).
