# SRD 5.2.1 Türkçeleştirme — Yol Haritası

> **Tek cümlelik hedef:** Uygulama Türkçe kullanılırken yerleşik SRD 5.2.1 paketinin kartları,
> alan etiketleri ve metin alanları otomatik olarak Türkçe görünsün — **içerik hiçbir şekilde
> değişmeden, sadece çevrilerek.**

- Başlangıç noktası (base): `22b05a39` (main) — 2026-10-07
- Branch: `feature/srd-tr` (main'deki başka yarım işlere dokunmadan)
- Seçilen mimari: **Yaklaşım A — görüntülemede çeviri** (aşağıda)
- Terim kaynağı: **BG3 > BG:EE Türkçe Terim Belgesi > rehber** (K7, D11). Üslup kaynağı:
  `flutter_app/assets/dnd_5e_tr_rehber.pdf` (repoda, uygulamaya paketlenmez — bkz. K9)
- **Durum:** Faz 0 ✅ (`0902879f`) · Faz 1 ✅ sözlük onaylandı ([GLOSSARY.md](GLOSSARY.md), 2026-10-07) · Faz 2 ✅ çıkarma (6433 metin, `17138714`) · Faz 3 ✅ `check_pairs` (`a5cf390c`) · Faz 4 ✅ altyapı + pilot · Faz 5 ⏳ dalga 5.1 ✅ · 5.2 ✅ · 5.3 ✅ · 5.4 ✅ · 5.5 ✅ · 5.6 ✅ · 5.7 ✅ · 5.8 ✅ (6404 / 6404; canavar adları onay bekliyor) · Faz 6 ✅ (2026-10-08) · Faz 7 ✅ (2026-10-08) — commit / PR kullanıcı onayında

---

## 1. Kesin Kurallar

Bu kurallar pazarlığa açık değildir. Biri ihlal ediliyorsa iş durur, kullanıcıya sorulur.

| # | Kural | Neden |
|---|---|---|
| **K1** | **İçerik asla değişmez, sadece çevrilir.** Anlam, kural, kapsam, ton aynı kalır. Cümle eklenmez, çıkarılmaz, birleştirilip anlam kaydırılmaz, açıklama/yorum eklenmez. | Kullanıcının ana şartı. |
| **K2** | `flutter_app/lib/domain/entities/schema/builtin/` altında **hiçbir dosya değişmez** (`srd_core/*`, `lookups.dart`, `content.dart`, şema dosyaları). | Kaynak İngilizce veri dokunulmazdır. |
| **K3** | **Veritabanına asla Türkçe yazılmaz.** Çeviri yalnızca ekrana basılırken uygulanır; kaydetme yolu her zaman orijinal (İngilizce) değeri görür. | Kural motoru İngilizce isimlere bakıyor (`'Rogue'`, `'Divine Order'`, `'Fighting Style'`, zırh kategorisinde `shield`, `{slug, name}` soft ref'ler). Veriye Türkçe yazmak mekaniği sessizce bozar. |
| **K4** | Kural motoruna (`character_resolver.dart`, chargen, level-up, grant çözümü) dokunulmaz. | Çeviri işi mekanik değiştirmez. |
| **K5** | Sayılar, zar ifadeleri (`1d8`, `2d6 + 3`), DC değerleri, bonuslar (`+5`), mesafeler, süreler, para (gp/sp/cp/ep/pp), ağırlık (lb) **birebir** aynı kalır. Birim dönüştürülmez: `30 feet` → `30 fit` (metre değil). | Sayısal içerik = içerik. |
| **K6** | Markdown yapısı aynı kalır: kalın/italik işaretleri, satır sonları, madde işaretleri, tablo satırları aynı sayıda. | Biçim de içeriktir. |
| **K7** | Terim önce **sözlükten** (`GLOSSARY.md`) gelir. Sözlükte yoksa öncelik sırası: **BG3 resmî Türkçesi > BG:EE Türkçe Terim Belgesi > rehber**; hiçbirinde yoksa yeni terim **önerilir ve kullanıcı onayı beklenir** — onaysız terim uydurulmaz. | Tutarlılık + Türk oyuncuların bildiği terimler (kullanıcı kararı D11). |
| **K8** | Rehber **birebir kopyalanmaz.** Rehber 2014 kurallarının çevirisi, bizim paket 5.2.1 (2024). Rehber terim ve üslup kaynağıdır; metin daima bizim İngilizce kaynağımızdan çevrilir. | 2014 metni ≠ 5.2.1 metni; kopyalamak içeriği değiştirir (K1). |
| **K9** | PDF repoda tutulur (kullanıcı kararı, 2026-10-07) ama **uygulamaya paketlenmez**: `pubspec.yaml`'a `assets/` kökü ya da PDF eklenmez. Metni scratchpad'e çıkarılır (`pdftotext -layout`). | 81 MB; build'e girerse uygulama boyutu patlar. |
| **K10** | Slug, alan anahtarı (field key), id, ref zarfları İngilizce kalır. Çeviri tablosunun **anahtarı daima birebir İngilizce kaynak metindir.** | Kimlikler çevrilmez. |
| **K11** | `srdCorePackVersion` artırılmaz. Paket verisi değişmediği için artırma ihtiyacı doğarsa bu bir **alarm**dır — K2 ihlal edilmiş demektir. | K2'nin dolaylı kontrolü. |
| **K12** | Repo kuralları: CRLF dosyalarda satır sonu korunur, mevcut dosyalara `dart format` çalıştırılmaz, `~/flutter-3.47/bin/flutter` kullanılır, `build_runner` gerektiğinde çalıştırılır. | Repo hafızası. |

---

## 2. Her Adımda Kontrol (Adım Kapısı)

Her adım — en küçüğü dahil — bu listeden geçmeden "bitti" sayılmaz. Sonuç her adımın sonunda
kullanıcıya **kanıtıyla** raporlanır (komut çıktısı, sayılar, örnek çiftler).

```
[ ] G1  Kaynak dokunulmadı:
        git diff --stat 22b05a39 -- flutter_app/lib/domain/entities/schema/builtin/   → BOŞ
[ ] G2  Çift kontrolü 0 hata (Faz 3'ten itibaren):
        tool/srd_l10n/check_pairs  → FAIL: 0   (uyarılar listelenir)
[ ] G3  Sözlük uyumu: sözlükteki her İngilizce terim, çevirisinde onaylı Türkçe karşılığıyla geçiyor
[ ] G4  Analiz + hedefli testler yeşil:
        flutter analyze <değişen dosyalar>  ·  flutter test <ilgili testler>
[ ] G5  Veri sızıntısı yok: hiçbir kayıt yolu çevrilmiş metin görmüyor (Faz 4 testleri)
[ ] G6  Rastgele 5 çift EN | TR yan yana kullanıcıya gösterildi (çeviri içeren adımlarda)
[ ] G7  Yeni terim varsa listelendi ve onay bekleniyor (K7)
```

### Otomatik çift kontrolü — kurallar (`check_pairs`)

Her `İngilizce → Türkçe` çifti için:

| Kod | Kontrol | Sonuç |
|---|---|---|
| N1 | Rakam dizileri (sıra dahil değil, çoklu küme olarak) aynı: `3`, `150`, `1/2`, `+5`, `-1` | FAIL |
| N2 | Zar ifadeleri aynı: `\d*d\d+(\s*[+−-]\s*\d+)?` | FAIL |
| N3 | `DC <n>` sayısı aynı | FAIL |
| N4 | Birim sayıları: `foot/feet` ↔ `fit`, `mile` ↔ `mil`, `lb.` ↔ `lb.`, `gp/sp/cp/ep/pp` aynen | FAIL |
| N5 | Markdown: `**`, `*`, `_`, satır sonu, `- ` madde, `\|` sayıları aynı | FAIL |
| N6 | Boş değil; sözlükte "aynen kalır" listesinde değilse İngilizceyle aynı değil | FAIL |
| N7 | Parantez sayısı aynı | FAIL |
| N8 | Uzunluk oranı TR/EN 0,7–1,6 dışında | UYARI → insan bakar |
| N9 | Cümle sayısı farkı > 1 | UYARI → insan bakar |
| N10 | Sözlük: EN'de geçen sözlük terimi TR'de onaylı karşılığıyla geçmiyor | UYARI → insan bakar |

Yazıyla yazılmış sayılar (`one creature`, `twice`) N1'e takılmaz — bunlar N9/N10 ve G6 ile insan
gözünden geçer.

---

## 3. Mimari (Yaklaşım A)

```
 SRD paket satırları (İngilizce, DEĞİŞMEZ)
            │
            ▼
   Drift DB / dünya sentezi  ──►  Entity (İngilizce)  ──►  Kural motoru, ref çözümü, kayıt
            │                                               (hep İngilizce görür)
            ▼
   EKRANA BASARKEN
   locale == 'tr' ?  ──►  ContentTranslator.tr(scope, ingilizce)  ──►  Türkçe (yoksa İngilizce)
```

- **Çeviri tabloları:** `flutter_app/assets/srd_l10n/tr/<scope>.json` — `{ "<İngilizce>": "<Türkçe>" }`.
  - `scope` = kategori slug'ı (`spell.json`, `monster.json`, `condition.json`, …) — aynı İngilizce
    kelimenin farklı kategoride farklı çevrilmesine izin verir (silah özelliği `Light` = *Hafif*,
    ama `Light` büyüsü başka şekilde).
  - `_schema.json` = kategori adları, alan etiketleri, placeholder/helpText, `subFields` etiketleri.
  - Değer `""` = henüz çevrilmedi → İngilizce gösterilir.
- **Okuyucu:** `ContentTranslator` (domain, saf Dart, Flutter importu yok): `tr(scope, en)` → çeviri
  ya da `en`. Yükleyici application katmanında, `localeProvider`'ı izler; `tr` dışındaki dillerde
  kimlik fonksiyonu.
- **Neden metin-anahtarlı:** Kullanıcı bir SRD kartının bir alanını düzenlerse o alanın metni artık
  tabloyla eşleşmez ve kendi yazdığı görünür; düzenlenmemiş alanlar çevrili kalır. Ek kod gerekmez.
  İngilizce kaynak ileride değişirse anahtar eşleşmez → İngilizce görünür ve kapsam testi kırmızıya
  döner (sessiz bozulma yok).
- **Düzenleme modu:** Kart düzenleme modundayken **değerler orijinal (İngilizce)** gösterilir
  (K3'ün en güvenli hali). Alan etiketleri düzenleme modunda da çevrilir (etiket kart kaydına yazılmaz).
  Şablon editörü (`template_editor.dart`) her zaman orijinali gösterir.
- **Yan etki (kabul edilen):** Başka bir paket (Open5e, marketplace) aynı kategoride birebir aynı
  İngilizce metni taşıyorsa o da çevrilir. Aynı metin, aynı anlam — sorun değil.

---

## 4. Açık Kararlar (Faz 1'de kapanır)

| # | Karar | Seçenekler | Varsayılan önerim |
|---|---|---|---|
| D1 | Büyü adı (kart başlığı) | `Fireball` · `Alev Topu` · `Fireball (Alev Topu)` | ✅ `Ateştopu` — sadece Türkçe (340 ad: [BUYU-ADLARI.md](BUYU-ADLARI.md)) |
| D2 | Metin içinde geçen büyü adı | rehberdeki gibi `fireball (alevtopu)` · sadece Türkçe · sadece İngilizce | ✅ D1 ile aynı — sadece Türkçe |
| D3 | Canavar adları | Özel adlar İngilizce (`Beholder`, `Mind Flayer`), cins adları Türkçe (`Kurt`, `Dev Örümcek`) | ✅ BG3/BG:EE karşılığı (`Kemgöz`, `Zihin Yüzücü`); yoksa özel ad İngilizce, cins adı Türkçe |
| D4 | Sınıf adları | Rehberdeki: Barbar, Ozan, Rahip, Druid, Savaşçı, Keşiş, Paladin, Kolcu, Düzenbaz, Sorcerer, Warlock, Büyücü | ✅ BG3/BG:EE: Barbar, Ozan, Ruhban, Druid, Dövüşçü, Keşiş, Paladin, Kolcu, Düzenbaz, Sihirbaz, Sehhar, Büyücü |
| D5 | 5.2.1'e özgü yeni terimler (Weapon Mastery, Species, Heroic Inspiration, Bloodied, Origin feat, …) | sözlük önerisi | ✅ GLOSSARY'de onaylandı |
| D6 | Türkçe adla arama | Faz 6 / hiç | Faz 6'da, ayrı onayla |
| D7–D12 | Sözlük çıkarılırken ortaya çıkanlar: arayüz (`app_tr.arb`) ↔ sözlük terim çakışması, durum adı biçimi, `Ekstra Saldırı`, Staff/Wand, terim önceliği, kısaltmalar | bkz. [GLOSSARY.md §1](GLOSSARY.md) | ✅ |

---

## 5. Yol Haritası — en küçük adımdan en genişe

Her faz bir öncekinin kapısından geçmeden başlamaz. Fazın sonundaki **Kapı** kullanıcı onayıdır.

### Faz 0 — Hazırlık *(~yarım oturum)*
- **0.1** Bu doküman onaylanır.
- **0.2** `feature/srd-tr` branch'i açılır (main'deki yarım battle-map değişiklikleri taşınmaz).
- **0.3** PDF metni scratchpad'e çıkarılır (`pdftotext -layout`). PDF branch'le birlikte commitlenir (K9).
- **Kapı:** doküman onayı.

### Faz 1 — Sözlük *(~1 oturum)*
- **1.1** Rehberden terim çıkarımı, kategori kategori: yetenekler (Kuvvet, Çeviklik, Dayanıklılık,
  Zeka, Akıl, Karizma), beceriler, durumlar, hasar tipleri, eylemler, zar terimleri (avantaj,
  kurtulma zarı, uzmanlık bonusu), sınıf/alt sınıf/özellik adları, ekipman adları, büyü okulları,
  birimler (`fit`, `mil`, `lb.`, `gp`).
- **1.2** 2014 rehberinde karşılığı olmayan 5.2.1 terimleri listesi + öneri (D5).
- **1.3** Üslup kuralları: "sen" dili (`kazanırsın`), sayı yazımı (`3. seviye`), ek kesme işareti
  (`d20'ye`), kısaltmalar (D12: DC, CR, XP aynen; HP, HD, AC açılır), büyük/küçük harf.
- **1.4** D1–D4 kararları kapatılır.
- **Çıktı:** `docs/srd-tr/GLOSSARY.md` — tek kaynak; `check_pairs` (N10) tablolarını doğrudan ayrıştırır.
- **Kapı:** kullanıcı sözlüğü onaylar. Bundan sonra sözlük dışı terim = K7 süreci.

### Faz 2 — Çıkarma (salt okunur) *(~yarım oturum)*
- **2.1** Alan tiplerini sınıflandır: hangi `FieldType` / alt anahtar ekranda görünen metin
  (`text`, `textarea`, `markdown`, yapılandırılmış listelerin `name`/`label`/`prompt`/`description`
  alt anahtarları), hangisi makine değeri (ref zarfı, id, formül, zar, `pick_kind`, görsel yolu).
  Liste raporlanır.
- **2.2** Çıkarma aracı: `srdRawRowsBySlug()` + Tier-0 seed'leri + yerleşik şemayı gezip her scope
  için benzersiz görünen metinleri `assets/srd_l10n/tr/<scope>.json` iskeletine yazar (değerler `""`).
- **2.3** Özet tablo: scope başına metin sayısı + kelime sayısı.
- **Sonuç (2026-10-07):** `tool/srd_l10n/bin/extract.dart` → 60 scope, 6433 metin, ~89.000 kelime
  (dalga 5.1'de `character-state` makine anahtarı olarak çıkarıldı → **59 scope, 6404 metin**).
  Çıkarılmayan makine değerleri (K10): relation/sayı/zar alanları, `tags`, `source`, `icon_name`,
  `color`, `legacy_subspecies_key`, `weapon_mastery_filter`, `granted_tool_variant_group`,
  `resource-pool` (`pool:…` — görünen ad `display_name`) ve `character-state` (`state:…`) satır adları, snake_case enum değerleri
  (`mechanic_kind`, `effect_kind`). `proficiencyTable` satır adları ability/skill scope'undan,
  enum seçenekleri `_schema`'dan çevrilir. Faz 4 çalışma zamanı aynı kuralları uygular.
- **Kapı:** G1 (kaynak değişmedi), sayılar kullanıcıya raporlanır.

### Faz 3 — Doğrulama aracı (her çeviriden ÖNCE) *(~yarım oturum)*
- **3.1** `check_pairs`: N1–N10 kuralları.
- **3.2** Kapsam raporu: scope başına çevrilen / toplam.
- **3.3** Aracın kendi testi: bilerek bozulmuş çiftler (sayı değişmiş, zar silinmiş, cümle eklenmiş)
  FAIL vermeli.
- **Sonuç (2026-10-07):** `tool/srd_l10n/bin/check_pairs.dart [--dir …] [--glossary …] [scope…]`
  — FAIL/UYARI listesi + scope başına kapsam tablosu; FAIL varsa çıkış kodu 1. Sözlüğü
  GLOSSARY.md'den okur (§3–§7 tabloları: 768 terim; "aynen kalır" + İngilizceyle aynı satırlar:
  38). Değeri `""` olan çift denetlenmez. N8 yalnızca 5+ kelimelik metinlere uygulanır (adlar
  dalga onayında topluca gösterilir). N10 Türkçe çekimi tolere eder (`Kurtarma Zarı` →
  `kurtarma zarlarına`, `Yetkinlik` → `yetkinliğin`). Kendi testi
  `test/tool/srd_l10n_check_pairs_test.dart`: gerçek SRD metinleri + sözlüğe uygun çeviriler temiz,
  N1–N10'un her biri bozuk çiftini yakalıyor; son test G2 (paketteki çevirilerde FAIL 0).
- **Kapı:** araç kasıtlı hataları yakalıyor.

### Faz 4 — Altyapı + pilot *(~1 oturum)*
- **4.1** `ContentTranslator` (domain, saf) + birim testi (eksik → İngilizce, boş → İngilizce).
- **4.2** Yükleyici provider (application) + `pubspec.yaml` asset dizini.
- **4.3** Alan etiketleri + kategori adları (`field_widget_factory.dart`, `entity_card.dart`,
  `entity_sidebar.dart`) — scope `_schema`.
- **4.4** Kart okuma modu: ad, açıklama, metin alanları (`entity_card.dart`, `readOnly == true`).
- **4.5** Yapılandırılmış listeler (`structured_list_field_widgets.dart`: sınıf özellik tablosu,
  ekipman seçimleri, oyuncu seçimleri).
- **4.6** Pilot veri — sadece küçük Tier-0 scope'ları tam çevrilir: `ability`, `skill`, `condition`,
  `damage-type`. G2'den geçer.
- **4.7** Koruma testleri:
  - TR'de `Poisoned` kartı Türkçe görünür, EN'de İngilizce.
  - Düzenleme moduna geçince değerler İngilizce.
  - Kart kaydedilince DB'deki değer İngilizce (K3).
  - Mevcut resolver/chargen testleri değişmeden yeşil (K4).
- **4.8** Arayüz hizalama (D7): `app_tr.arb`'deki çakışan terimler sözlüğe çekilir (GLOSSARY §1
  tablosu) → `flutter gen-l10n`. Ayrı commit; `.arb` satır sonları korunur (K12).
- **Kapı:** kullanıcı pilotu uygulamada görür, dil değiştirip geri alır.
- **Sonuç (2026-10-07):**
  - `lib/domain/services/content_translator.dart` (`tr` / `field` / `value`; makine anahtarları
    listesi çıkarma aracıyla ortak) + `lib/application/providers/content_translator_provider.dart`
    (`localeProvider`'ı izler, `assets/srd_l10n/<dil>/`'i `AssetManifest` ile yükler; pubspec'e
    yalnızca `assets/srd_l10n/tr/` eklendi — K9).
  - Bağlantı: `entity_card.dart` (okuma modunda ad, açıklama, alan değerleri; her modda alan
    etiketleri, grup adları, kategori alt başlığı; açıklama ayrı görüntü denetleyicisinde, çevrilmiş
    değer `onChanged`'e ulaşmaz) · `entity_sidebar.dart` (kategori adları). 4.5'in yapılandırılmış
    listeleri `value` üzerinden aynı yoldan geçer — widget'lara dokunulmadı.
  - Pilot: `ability`, `skill`, `condition`, `damage-type` — 95/95, `check_pairs` FAIL 0 · UYARI 0.
  - Testler: `test/domain/services/content_translator_test.dart` (eksik/boş → İngilizce, girdi
    değişmez) · `test/presentation/srd_tr_entity_card_test.dart` (in-memory DB'de gerçek dünya +
    gerçek tablolar + gerçek `EntityCard`: TR okuma Türkçe, düzenleme İngilizce, kayıt İngilizce,
    okuma modu hiçbir şey yazmaz, EN'e dönünce İngilizce, SRD'nin kendi Poisoned kartı `Zehirlenme`).
  - 4.8: `app_tr.arb`'de 33 dize D7 tablosuna çekildi (Öncelik, Kısa/Uzun Dinlenme, Yetkinlik
    Katkısı, hüner, kabiliyet, yetenek, Büyülü eşya, Saldırı Katkısı). Sözlük §3
    `Spellcasting Ability` → `Büyü Yapma Kabiliyeti` (D11; eskiden "Yeteneği") ve arayüzde
    `spellsCastingSummary` aynı terime çekildi.

### Faz 5 — Toplu çeviri (dalgalar, küçükten büyüğe) *(~3–5 saat gerçek zaman)*

Her dalga: paralel ajanlar (ajan başına ≤ ~150 metin, aynı sözlük + kurallar) → `check_pairs`
→ FAIL 0 → 5 örnek çift kullanıcıya → onay → sonraki dalga.

| Dalga | Scope'lar | Not |
|---|---|---|
| 5.1 | Kalan Tier-0 sözlük kategorileri (39 kategori, ~369 satır) | Terimlerin kendisi — sözlükle %100 uyum |
| 5.2 | `_schema` (kategori adları, alan etiketleri) | |
| 5.3 | Ekipman: `weapon`, `armor`, `tool`, `adventuring-gear`, `ammunition`, `pack`, `mount`, `vehicle` | Rehberde karşılığı çok |
| 5.4 | `species`, `subspecies`, `background`, `class`, `subclass`, `trait` | Rehberle kısmen eşleşir; 2014≠2024 dikkat (K8) |
| 5.5 | `feat` (genel + sınıf/alt sınıf özellikleri, ~305) | |
| 5.6 | `spell` (~341) | En büyük dosya |
| 5.7 | `magic-item` (~286) | Rehberde yok |
| 5.8 | `monster` (~248), `creature-action` (~528), `animal` (~97) | Rehberde yok |

- **5.1 sonucu (2026-10-07):** 34 scope, 288 metin, hepsi sözlükten (§3–§6; sözlükte olmayan üç
  `resource-pool` adı rehberden: `Hunter's Mark` → `Avcının İşareti`, `Superiority Dice` →
  `Üstünlük Zarları`; `Focus Points` → `Odak Puanları`). `check_pairs` FAIL 0 · UYARI 0;
  toplam 383 / 6404. `character-state` satır adları makine kimliği (`state:raging`, görünen metni
  yok — sözlük §4) olduğu halde çıkarılmıştı: `extract.dart` `_machineNameSlugs`'a eklendi, dosya
  silindi. `check_pairs` artık sözlükteki her "… aynen kalır: A · B" listesini okur (§4.26 dış
  düzlem adları: 38 → 54).
- **5.2 sonucu (2026-10-07):** `_schema` 597 metin — kategori ve grup adları, alan etiketleri,
  yardım metinleri, enum seçenekleri. Terimler sözlükten; arayüzde zaten Türkçesi olanlar
  `app_tr.arb`'den (`Trinket` → `Biblo`, `Backstory` → `Geçmiş Hikâye`, `Personality Traits` →
  `Kişilik Özellikleri`, `Combat Stats` → `Savaş İstatistikleri`). D12: `HP`/`AC` → `Can Puanı` /
  `Zırh Sınıfı`; `STR`… → `KUV`…; `ASI` → `Kabiliyet Skoru Gelişimi`. Çakışmayı önlemek için:
  `Status` → `Aşama` (`Durum` = Condition), `Kind` → `Çeşit` (`Tür` = Species), `Character State` →
  `Karakter Hali`, `Caster Kind` → `Büyü Yapma Türü` (`Büyücü` = Wizard), `Lore` → `Bilgi`
  (`İrfan` = Wisdom). Sözlükte olmayan öneriler: `Lair Action` → `İn Eylemi`, `Mythic Action` →
  `Mitik Eylem`, `Hover` → `Süzülme`, `Faction` → `Hizip`, `Hireling` → `Kiralık Yardımcı`.
  `check_pairs` FAIL 0 · UYARI 6 (4'ü yanlış eşleşme, `Kişilik Özellikleri` arayüzle aynı, biri
  uzun Türkçe karşılık); toplam 980 / 6404. `NPC` sözlükte "aynen kalır"a eklendi; N6 artık
  yalnızca "aynen kalır" terimleri ve sayılardan oluşan metni (`cp 0.01, sp 0.1, …`) kabul eder.
- **5.3 sonucu (2026-10-07):** ekipman 8 scope, 337 metin. Adlar sözlük §7'den, macera tertibatı
  rehberin "Macera Tertibatı" tablosundan; BG:EE'de olanlar oradan (`Quiver` → `Sadak`, `Robe` →
  `Cübbe`, `Case` → `Kutu`, `Potion of Healing` → `İyileştirme İksiri`). Rehberden sapılanlar
  (çakışma): `Pole` → `Sırık` (rehber `Sopa` = Club), `Spikes, Iron` → `Çiviler, Demir` (rehber
  `Dikenler` ≈ Caltrops). Metindeki `DEX`/`STR` → `ÇEV`/`KUV`, `PB` → `Yetkinlik Katkısı` (D12 gibi
  açılır). FAIL 0 · UYARI 9 (hepsi `Bright Light` içindeki `Light` gibi yanlış eşleşme).
- **5.4 sonucu (2026-10-07):** `species`, `subspecies`, `background`, `class`, `subclass`, `trait` —
  1101 metin. Özellik adları sözlük §6'dan; 2014 tür nitelikleri rehberin ad listesinden (`Trans`,
  `Fey Soyu`, `Amansız Dayanıklılık`, `Cüce Sertliği`, `Taş Kurnazlığı`, `Güçlü Yapı`…). `trait`
  canavar niteliklerini de içerir (aşağıdaki canavar adları). Background ekipman listelerindeki
  `GP` sözlükte "aynen kalır"a eklendi. FAIL 0.
- **5.5 sonucu (2026-10-07):** `feat` 749 metin. Hüner adları rehberden; uyarlananlar: `Skilled` →
  `Yetenekli` (Skill = Yetenek), `Crossbow Expert` → `Kurmalı Yay Uzmanı` (Crossbow = Kurmalı Yay),
  `Sentinel` → `Nöbetçi` (rehber `Bekçi` = Warden). `Ability Score Increase` → `Kabiliyet Skoru
  Artışı`, `Repeatable` → `Tekrarlanabilir`. `check_pairs` N10 artık sayıdan sonra tekil kullanılan
  çoğul terimi kabul eder (`3 Sihirbazlık Puanı` ✓ `Sihirbazlık Puanları`). Toplam FAIL 0 · UYARI 65
  (yanlış eşleşmeler: `Light` fiil/ışık, `bonus` = "ek", `reach` fiil) → **3167 / 6404**.
- **5.3–5.5'te önerilen adlar** — ✅ kullanıcı onayladı (2026-10-07): `Forge Wise` → `Demirhane
  Bilgisi`, `Large Form` → `Büyük Biçim`, `Giant Ancestry` → `Dev Soyu`, `Elven Lineage` → `Elf Soyu`,
  `Fiendish Legacy` → `Zebani Mirası`, `Otherworldly Presence` → `Öteki Dünyalı Varoluş`, `Halfling
  Lucky` → `Buçukluk Şansı`; Goliath lütufları `Bulutun Gezintisi` / `Ateşin Yakışı` / `Ayazın Soğuğu`
  / `Tepenin Yuvarlayışı` / `Taşın Dayanıklılığı` / `Fırtınanın Gürlemesi`; Acımasız Vuruş etkileri
  `Sert` / `Topallatan` / `Sendeleten` / `Parçalayan Darbe`; `Divine Spark` → `İlahi Kıvılcım`, `Turn
  Undead` → `Hortlakları Kov`, `Divine Sense` → `İlahi Sezi`, `Elemental Fury` → `Elemental Hiddet`;
  Kurnaz Vuruş `Daze` / `Knock Out` / `Obscure` → `Şaşırtma` / `Bayıltma` / `Örtünme`, `Addle` →
  `Bocalatma` (5.6'da `Afallatma` Confusion'a gitti); lütuflar `Savaş Yiğitliği` / `Boyutlar Arası Yolculuk` / `Kader` / `Karşı Konulmaz
  Saldırı` / `Büyü Hatırlama` / `Gece Ruhu` / `Özgörü Lütfu`; `Crafter` → `Zanaatçı`.
- **5.6 sonucu (2026-10-07):** `spell` 960 metin (340 ad + açıklama, materyal bileşen, tepki tetikleyici,
  yüksek seviye metni). Adlar onaylı listeden ([BUYU-ADLARI.md](BUYU-ADLARI.md); D1 örneği `Ateştopu`ya
  çekildi). Kalıplar: `Cantrip Upgrade` → `Cantrip Gelişimi`, `Using a Higher-Level Spell Slot` / `Higher-Level
  Slot` → `Daha Yüksek Seviyeli Büyü Yuvası Kullanma` / `Daha Yüksek Seviyeli Yuva`, `per slot level above
  N` → `N'in üstündeki her yuva seviyesi için`, `GM` → `DM` (arayüzle aynı). `Alarm`, `Tsunami` sözlükte
  "aynen kalır"a eklendi. 5.4–5.5'teki 6 geçici büyü adı onaylı adlara çekildi (`Büyüyü Sapta`, `Küçük
  Yanılsama`, `Düzlem Değiştir`, `Ruhani Muhafızlar`, `Ruhani Silah`, `Asit Küresi`). FAIL 0 · UYARI 41
  (`Light` ışık/Hafif, `Touch` fiil/Temas gibi yanlış eşleşmeler) → **4127 / 6404**.
- **5.7 sonucu (2026-10-07):** `magic-item` 600 metin (286 ad + açıklama, uyumlanma koşulu, kullanım
  yenileme). Adlar [ESYA-ADLARI.md](ESYA-ADLARI.md)'de — **onay bekliyor**; metinler adları bu listeden
  doldurur, değişen ad her yerde birlikte değişir. Kalıplar: `charges` → `kullanım` (sözlük), `N daily at
  dawn` → `Her gün şafakta N`, `command word` → `emir sözcüğü`, `modifier` → `katkı` (5.5–5.6 ile aynı).
  İyileştirme iksirleri Büyük / Yüksek / Üstün (sözlükte `Supreme Healing` = `Üstün İyileştirme`).
  FAIL 0 · UYARI 36 → **4727 / 6404**. Eşya adları onaylandı (2026-10-08, ⚠ kararlarında öneri).
- **5.8 sonucu (2026-10-08):** `monster` 506 + `animal` 194 + `creature-action` 977 metin. Adlar
  [CANAVAR-ADLARI.md](CANAVAR-ADLARI.md)'de — **onay bekliyor** (kullanıcı sonra kontrol edecek); §7'de
  metinlere girmiş adların hepsi korundu (tarama: önceki scope'larda geçen her canavar adı yeni adla aynı).
  Kalıplı 211 saldırı satırı şablonla çevrildi (`*Yakın Dövüş Saldırı Zarı:* +4, erişim 5 ft. *Vuruş:* 5
  (1d6 + 2) Kesici hasar.`); sıfat hasar türleri `Delici hasar`, isim olanlar `Ateş hasarı` (önceki
  dalgaların çoğunluğu). `HP` → `Can Puanı` (D12), `Con save` → `DAY kurtarma zarı`, `(Recharge 5–6)` →
  `(Yenilenme 5–6)`, `escape DC 13` → `kaçış DC'si 13`. Çevrilmeyen özel adlar sözlüğe "aynen kalır"
  listesi olarak eklendi (GLOSSARY §8, 59 ad). FAIL 0 · UYARI 179 (bu dalgada 40, hepsi yanlış eşleşme) →
  **6404 / 6404**.

### Faz 6 — Yüzeyleri genişletme *(~1 oturum)*
- **6.1** Ad gösteren tüm noktaların envanteri (~160 çağrı): kenar listesi, `entity_link` çipleri,
  arama sonuçları, karakter sayfası, savaş takibi, savaş haritası tokenları, zar kaydı,
  chargen/level-up listeleri.
- **6.2** Projeksiyon alt penceresi (ayrı süreç) — çeviri tablosunun orada da yüklenmesi.
- **6.3** Çevrimiçi oyuncu kendi dilinde görür (çeviri istemci tarafında olduğu için otomatik) — test.
- **6.4** (D6 onaylanırsa) Türkçe adla arama.
- **Faz 6 sonucu (2026-10-08):** Kural: **her cihaz SRD'yi kendi dilinde görür.** Dil
  `contentLanguageProvider` = cihazın SRD dili ayarı (Ayarlar → SRD İçerik Dili, arayüz dilinden
  bağımsız; 2026-10-08); DM'den çıkan her şey İngilizce kalır, çeviri
  alıcıda yapılır.
  - 6.1: tek giriş `presentation/widgets/srd_text.dart` (`srdText`, `srdName`, `srdRefName`,
    `srdDescription`, `srdCombatantName`, `srdConditionName`). Bağlanan yüzeyler: kenar listesi kart
    adları, ilişki alanı/çipleri, önizleme diyaloğu, kart seçici, açık kart sekmeleri, savaş takibi,
    token ve durum rozetleri, karakter sayfası, karakter oluşturucu adımları, bekleyen seçim diyaloğu,
    zihin haritası, harita pin filtresi. Ad eşleştiren mantık (ref çözümü, beceri satırları) İngilizce
    adla kalır; savaşçı adı kartın adıysa çevrilir, DM'in verdiği ad ("Goblin 2") aynen.
    Bilerek dışarıda: harita pin etiketleri (veriye yazılır, DM düzenler) ve savaş günlüğü (sabit
    İngilizce arayüz metni — arayüz yerelleştirmesinin işi).
  - 6.2: projeksiyon anlık görüntüleri İngilizce gider + çevrilebilir parçalar (`EntitySnapshot`
    satırlarında `parts`, `TokenSnapshot.nameScope`); alıcı görünümler `localized()` ile çevirir.
    Ayrı motordaki ikinci pencere ve ekran yansıtma DM'in dilini tam durumla alır (IPC `lang`,
    yansıtmada `_contentLang`) — onlar DM'in kendi ekranı. Eski gönderenle uyumlu (alan yoksa aynen).
  - 6.3: çevrimiçi oyuncu aynı görünümü kendi uygulamasında, kendi dil ayarıyla çizer; DM'in dili ona
    hiç gitmez. Test: aynı İngilizce yayın Türkçe cihazda Türkçe, İngilizce cihazda İngilizce.
  - 6.4 (D6 — öneri olarak uygulandı): kenar listesi ve kart seçici hem İngilizce hem gösterilen adla
    arar; `searchFold` Türkçe `İ` → `i` (Dart `'İ'.toLowerCase()` = `i̇`).
  - Test: `test/presentation/srd_tr_surfaces_test.dart` (10); tam paket 1655 geçti, 1 bilinen hata
    (`bundled_pack_resolve_test`, önceden de kırmızı).

### Faz 7 — Kapanış *(~yarım oturum)*
- **7.1** Kapsam testi CI'da: çevirisi eksik metin = kırmızı.
- **7.2** Bayat anahtar testi: TR tablosunda olup kaynakta artık olmayan anahtar = kırmızı
  (ileride İngilizce metin değişirse çeviri de güncellenmek zorunda kalır).
- **7.3** Vault: yeni dosya notları, `World-and-Content` MoC, `_Architecture-Overview.md`,
  `Vault-Changelog.md`.
- **7.4** Son G1–G7 turu + release notu. PR kullanıcı isterse.
- **Faz 7 sonucu (2026-10-08):**
  - Önce kullanıcının bulduğu eksikler kapandı (karakter sayfası):
    - Alan etiketleri ve grup adları çevriliyor.
    - Kabiliyet bloğu kısaltmaları (`STR` → `KUV`) ve kurtarma / yetenek satırları çevriliyor; zar
      günlüğü ve kayıt İngilizce adla.
    - Karakter sekmesi liste çiplerinde tür ve sınıf adı çevriliyor; HP / AC etiketleri L10n'den.
    - Sınıf kaynakları kartı ve seviye atlama havuz satırları çevriliyor.
    - Bekleyen seçim etiketleri ("Pick 2 spells") ve seviye atlama büyü özeti sabit İngilizceydi →
      4 dilde L10n anahtarı. Sınıf, hüner ve özellik adı SRD tablosundan.
    - Türkçe büyük harfli başlıklar `İ` ile.
  - 7.1 + 7.2: `test/tool/srd_l10n_coverage_test.dart`. Kaynak kümesi `extract.dart`'ın
    `collectSrdTexts()`'i (CLI çıktısı değişmedi: 6404 / 6404, bayat 0). Bilerek bozulan tabloyla
    iki test de kırmızı oldu. CI'daki tam `flutter test` koşusu bunları içerir.
  - 7.3: vault notları `content_translator`, `extract`, `pending_choices`; `World-and-Content`,
    `_Architecture-Overview`, `Vault-Changelog`.
  - 7.4: G1 boş · G2 FAIL 0 · G3 N10 uyarıları (179) bilgi olarak duruyor · G4 analiz temiz, tam paket
    1660 geçti, 1 bilinen hata (`bundled_pack_resolve_test`) · G5 kayıt testleri yeşil · G6/G7 yeni
    SRD çevirisi yok; L10n Türkçeleri sözlük terimleriyle, kısaltma uydurulmadı (D12). Sürüm notu
    taslağı: [RELEASE-NOTE.md](RELEASE-NOTE.md) — sürüm yükseltilince `RELEASE_NOTES.md`'ye taşınır.

---

## 6. Riskler

| Risk | Önlem |
|---|---|
| Türkçe veriye sızar, motor bozulur | K3 + Faz 4.7 kayıt testi + G5 |
| Çeviri anlamı kaydırır | K1, N1–N10, G6 örnek çiftler, dalga dalga onay |
| 2014 rehber metni 5.2.1'in yerine geçer | K8; çeviri her zaman bizim İngilizce kaynaktan |
| Aynı İngilizce kelime farklı bağlamda farklı anlam | scope = kategori slug'ı |
| İngilizce kaynak ileride değişir, çeviri eskir | metin-anahtarı + 7.1/7.2 testleri |
| Sözlük dışı terim uydurulur | K7 + N10 + G7 |

---

## 7. Sonraki dalgalara devreden adlar

Metinlerde geçen ama kendi dalgası henüz gelmemiş adlar. **Geçicidir:** dalga 5.8 (canavar) ad listesi
onayında değişirse, bu metinlerde de aynı adla değiştirilir.

**Karar (2026-10-07):** 5.8'de canavar kartları da aşağıdaki adlarla çevrilir (tutarlılık); kullanıcı
listeyi sonra kontrol eder, değişen ad her metinde birlikte değiştirilir. `Slam` → `Çarpma` şimdilik kalır.

- **Büyü adları:** 5.6'da kesinleşti — [BUYU-ADLARI.md](BUYU-ADLARI.md). SRD dışı, yalnızca `trait`
  metinlerinde geçenler: Melf's Acid Arrow → Melf'in Asit Oku · Armor of Agathys → Agathys'in Zırhı ·
  Snilloc's Snowball Swarm → Snilloc'un Kartopu Sürüsü · Storm Sphere → Fırtına Küresi. `magic-item`
  metinlerinde: Pyrotechnics → Piroteknik · Branding Smite → Damgalayan Çarpma · Crown of Madness → Delilik Tacı.
- **Canavar adları** (`trait` metinlerinde): BG:EE'den Kemgöz · Zihin Yüzücü · Liç · Kurtadam · Ağaç
  Perisi · Piksi · İblis · Hobgoblin · Sahte Ejderha · Quasit · Sprite; özel adlar aynen: aboleth · chuul
  · roper · nothic · otyugh · couatl · xorn · lamia · rakshasa · gargoyle; cins adları Türkçe: sfenks ·
  hidra · ölüm şövalyesi · ölüm köpeği · timsah · yarasa · dev porsuk · ateş böceği · ahtapot · cadı ·
  vampir · pas canavarı · kült fanatiği · İmp.
- **Canavar adları** (`spell` metinlerinde): BG:EE'den Zombi · Gûl · Gast · Tarask · Ombra Yarması
  (umber hulk) · Piksi · Sprite; öneri: İskelet · Mumya · Minotor · goristro iblisi · Wight (aynen) ·
  `Draconic Spirit` → `Draconic Ruh` (değer bloğu adı); `Slam` → `Çarpma`.
- **Canavar / hayvan adları** (`magic-item` metinlerinde): BG:EE'den İfrit · Cin · Griffin · Suretçalan
  (doppelganger) · Kara Ayı · Treant · Hava / Su / Ateş / Toprak Elementali · Leş Golem; BG:EE kalıbından
  Dehşet Kurdu (dire wolf; BG: Dread Wolf = Dehşet Kurt); değer blokları Başıbozuk (Berserker) · Kıdemli
  (Veteran) · Şampiyon · Şövalye; cins adları Türkçe: Gelincik · Dev Sıçan · Porsuk · Yaban Domuzu · Panter
  · Dev Porsuk · Dev Geyik · Sıçan · Baykuş · Mastiff · Keçi · Dev Keçi · Dev Yaban Domuzu · Aslan · Boz Ayı
  · Çakal · Maymun · Babun · Baltagaga (axe beak) · Dev Gelincik · Dev Sırtlan · Kaplan · Dev Boğucu Yılan ·
  Sıçan Sürüsü · Roc (aynen).

---

## 8. Yan notlar (SRD dışı)

- **`Database` sekmesinin adı** (`tabDatabase`; ayrıca `sessionAddFromDatabase`, `helpWorldsBody`):
  kullanıcı dünya kurmaya uygun bir ad istiyor (2026-10-07). Arayüzde çakışma taraması yapıldı —
  `Archive` / `Library` (`Kütüphane`) zaten başka yerde kullanılıyor, `Lore` Türkçede `Bilgi`/`İrfan`
  ile çakışır. Adaylar (EN / TR):

  | Ad | Not |
  |---|---|
  | **Codex / Kodeks** (önerim) | Dünya kurma araçlarında yerleşik; kısa; arayüzde hiç geçmiyor |
  | Compendium / Derleme | D&D araçlarından tanıdık; Türkçesi zayıf |
  | Encyclopedia / Ansiklopedi | Türkçede en doğal; EN uzun |
  | World Book / Dünya Kitabı | Açık ama iki kelime, sekme için uzun |
  | Almanac / Almanak | Fantastik tını; Türkçede az bilinir |

  Karar kullanıcıda. Seçilince 4 dilde `tabDatabase` + iki ilişkili metin değişir; kod içi adlar
  (`screens/database/`) değişmez.
- **Kart kapatılırken son yazılanlar kaybolabiliyor** — `docs/KNOWN_ISSUES.md`'de.
