---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/content_translator.dart
layer: domain
language: dart
status: stable
updated: 2026-10-08
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
  - `entity_sidebar.dart` — kategori adları (filtre, yeni kart diyaloğu, satır etiketi); slug aynı kalır. Faz 6: kart adları da (sıralama gösterilen ada göre, arama iki dilde).
  - **Faz 6 — diğer yüzeyler** `presentation/widgets/srd_text.dart` üzerinden: `srdText(context, scope, en)`, `srdName(context, entity)`, `srdRefName(context, refMap)` (zarfın `slug`/`_lookup`'ı kapsam), `srdDescription`, `srdCombatantName` (savaşçı adı kartın adıysa çevrilir, DM'in verdiği ad aynen), `srdConditionName`. Kapsam yoksa (yalın test) metin aynen. Bağlananlar: ilişki alanları ve çipleri (`field_widget_factory`, `structured_list_field_widgets`), önizleme diyaloğu (kart okuma moduyla aynı), kart seçici (ad + sıralama + arama), açık kart sekmeleri, savaş takibi + token + durum rozetleri, karakter sayfası (başlık çipleri, kazanımlar kartı, sınıf/çoklu sınıf, alt tür), karakter oluşturucu adımları, bekleyen seçim diyaloğu, zihin haritası düğümü, harita pin filtresi. Ad eşleştiren mantık (beceri satırları, ref çözümü) İngilizce adla kalır.
  - **Karakter sayfası (Faz 7 öncesi ek):** alan etiketleri `field()` ile, grup adları `_schema`'dan; kabiliyet bloğu kısaltmaları (`STR` → `KUV`) ve kurtarma/yetenek tablosu satırları (`ability` / `skill` kapsamı) yalnızca görüntüde — zar günlüğü ve kayıt İngilizce adla. Karakter listesi çipleri (`characterStatLines(tx:)`) tür/sınıf adını çevirir; sınıf kaynakları kartı ve seviye atlama havuz satırları `resource-pool` kapsamından (`kResourcePoolLabels` görünen adı). Bekleyen seçim etiketi (`pendingChoiceLabel(context, p)`, `pending_choices_badge.dart`) kalıbı arayüz L10n'inden, sınıf/hüner/özellik adını SRD tablosundan alır. Türkçe büyük harfli başlıklar `i → İ` ile (`entity_card.dart` `_headingUpper`).
  - **Her cihaz kendi dili:** dil `contentLanguageProvider`'dan gelir = Ayarlar → SRD İçerik Dili (`UiState.srdLanguage`, varsayılan `en`; arayüz dilinden bağımsız). Projeksiyon İngilizce gider (`EntitySnapshot.parts`, `TokenSnapshot.nameScope`), alıcı görünüm (`entity_card_projection_view`, `battle_map_projection_view`) kendi dilinde çevirir; çevrimiçi oyuncu aynı görünümü kendi uygulamasında çizdiği için DM'in değil kendi dilini görür. Ayrı motordaki yerel pencereler (ikinci pencere, yansıtma) DM'in dilini IPC ile alır (`projectionLanguageOverrides`).
- **Metin anahtarlı olmasının sonucu:** kullanıcı bir alanı düzenlerse metin tabloyla eşleşmez, yazdığı görünür; düzenlenmemiş alanlar çevrili kalır. SRD kartını düzenlemek homebrew kopya üretir (fork-on-edit, `linked == false`). **Yalnızca asıl SRD kartı çevrilir** (2026-10-08): `isSrdCard(linked, source)` = `linked && source == srdSourceTag`; homebrew ve başka kaynaklı paket kartları (Open5e, marketplace) yazıldığı gibi. `forCard(srd)` SRD olmayan kart için yalnızca `_schema` tablosunu tutan çevirmen döner — ad, açıklama, metin/satır alanları SRD dilinden bağımsız, yazıldığı gibi; alan etiketleri, enum değerleri, kategori adları çevrili kalır. Projeksiyonda `EntitySnapshot.srd = false` (ad/açıklama), metin parçası yok, homebrew ilişki parçası boş kapsamla; token `nameScope` yalnızca SRD kartta.

## Notes
- 2026-10-07 pilot: `ability`, `skill`, `condition`, `damage-type` tam çevrili (95 metin, `check_pairs` FAIL 0 · UYARI 0). Dalga 5.1: kalan 34 Tier-0 scope (288 metin) — toplam 383 / 6404. Dalga 5.2: `_schema` (597 metin — alan etiketleri, kategori/grup adları, enum seçenekleri) → 980 / 6404. Dalga 5.3–5.5: ekipman, tür/geçmiş/sınıf/alt sınıf/nitelik, hüner → 3167 / 6404. Dalga 5.6: `spell` (960 metin, adlar `docs/srd-tr/BUYU-ADLARI.md`) → 4127 / 6404. Dalga 5.7: `magic-item` (600 metin, adlar `docs/srd-tr/ESYA-ADLARI.md`, onaylandı 2026-10-08) → 4727 / 6404. Dalga 5.8: `monster`, `animal`, `creature-action` (1677 metin, adlar `docs/srd-tr/CANAVAR-ADLARI.md`, onay bekliyor) → 6404 / 6404, boş scope kalmadı.
- Faz 7 (2026-10-08): `test/tool/srd_l10n_coverage_test.dart` — kaynaktaki her metnin çevirisi var (7.1) ve tabloda kaynakta olmayan anahtar yok (7.2); kaynak kümesi [[extract]]'in `collectSrdTexts()`'i.
- Faz 6 (2026-10-08): yukarıdaki yüzeyler bağlandı; test `test/presentation/srd_tr_surfaces_test.dart`. Bilerek çevrilmeyen: harita pin etiketleri (oluşturulurken veriye yazılır, DM düzenler), savaş günlüğü (İngilizce sabit arayüz metni — ayrı arayüz yerelleştirme işi).
