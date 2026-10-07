# SRD 5.2.1 Türkçeleştirme — Yol Haritası

> **Tek cümlelik hedef:** Uygulama Türkçe kullanılırken yerleşik SRD 5.2.1 paketinin kartları,
> alan etiketleri ve metin alanları otomatik olarak Türkçe görünsün — **içerik hiçbir şekilde
> değişmeden, sadece çevrilerek.**

- Başlangıç noktası (base): `22b05a39` (main) — 2026-10-07
- Branch: `feature/srd-tr` (main'deki başka yarım işlere dokunmadan)
- Seçilen mimari: **Yaklaşım A — görüntülemede çeviri** (aşağıda)
- Terim kaynağı: **BG3 > BG:EE Türkçe Terim Belgesi > rehber** (K7, D11). Üslup kaynağı:
  `flutter_app/assets/dnd_5e_tr_rehber.pdf` (repoda, uygulamaya paketlenmez — bkz. K9)
- **Durum:** Faz 0 ✅ (`0902879f`) · Faz 1 ✅ sözlük onaylandı ([GLOSSARY.md](GLOSSARY.md), 2026-10-07) · Faz 2 ✅ çıkarma (6433 metin, `17138714`) · Faz 3 ✅ `check_pairs` (`a5cf390c`) · Faz 4 ✅ altyapı + pilot (kapı: kullanıcı uygulamada görür)

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
| D1 | Büyü adı (kart başlığı) | `Fireball` · `Alev Topu` · `Fireball (Alev Topu)` | ✅ `Alev Topu` — sadece Türkçe |
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
- **Sonuç (2026-10-07):** `tool/srd_l10n/bin/extract.dart` → 60 scope, 6433 metin, ~89.000 kelime.
  Çıkarılmayan makine değerleri (K10): relation/sayı/zar alanları, `tags`, `source`, `icon_name`,
  `color`, `legacy_subspecies_key`, `weapon_mastery_filter`, `granted_tool_variant_group`,
  `resource-pool` satır adları (`pool:…` — görünen ad `display_name`), snake_case enum değerleri
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
  - 4.8: `app_tr.arb`'de 32 dize D7 tablosuna çekildi (Öncelik, Kısa/Uzun Dinlenme, Yetkinlik
    Katkısı, hüner, kabiliyet, yetenek, Büyülü eşya, Saldırı Katkısı). `spellsCastingSummary`
    ("Büyü yeteneği") sözlük §3 `Spellcasting Ability` satırı netleşene kadar bekliyor.

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

### Faz 6 — Yüzeyleri genişletme *(~1 oturum)*
- **6.1** Ad gösteren tüm noktaların envanteri (~160 çağrı): kenar listesi, `entity_link` çipleri,
  arama sonuçları, karakter sayfası, savaş takibi, savaş haritası tokenları, zar kaydı,
  chargen/level-up listeleri.
- **6.2** Projeksiyon alt penceresi (ayrı süreç) — çeviri tablosunun orada da yüklenmesi.
- **6.3** Çevrimiçi oyuncu kendi dilinde görür (çeviri istemci tarafında olduğu için otomatik) — test.
- **6.4** (D6 onaylanırsa) Türkçe adla arama.

### Faz 7 — Kapanış *(~yarım oturum)*
- **7.1** Kapsam testi CI'da: çevirisi eksik metin = kırmızı.
- **7.2** Bayat anahtar testi: TR tablosunda olup kaynakta artık olmayan anahtar = kırmızı
  (ileride İngilizce metin değişirse çeviri de güncellenmek zorunda kalır).
- **7.3** Vault: yeni dosya notları, `World-and-Content` MoC, `_Architecture-Overview.md`,
  `Vault-Changelog.md`.
- **7.4** Son G1–G7 turu + release notu. PR kullanıcı isterse.

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
