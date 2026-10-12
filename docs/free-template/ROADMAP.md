# Free Template — Yol Haritası

> **Tek cümlelik hedef:** [DESIGN.md](DESIGN.md)'deki free template sistemini, her biri kendi başına
> çalışan ve **uygulama açılarak elle kontrol edilen** küçük fazlarla, bugün çalışan hiçbir şeyi
> bozmadan uygulamak.

- **Tasarım:** [DESIGN.md](DESIGN.md) (kararlar D1–D33, varsayımlar V1–V28). Bu doküman *ne
  zaman ve hangi sırayla* sorusunu cevaplar; *ne ve neden* DESIGN.md'dedir.
- **Branch:** `feature/free-template` · **Başlangıç (base):** `1d3eba6b` — 2026-10-09
- **Durum:** Faz 0 kapandı (2026-10-11, R turu referansı alınmadan, bkz. Faz 0 sonucu). Faz 1
  kapandı (2026-10-11, arayüz kullanıcıyla gözden geçirildi; E listesi tek tek yapılmadı). Faz 2
  kapandı (2026-10-11, kullanıcı onayladı). Faz 3 kapandı (2026-10-11, kullanıcı onayladı). Faz 4
  ikiye bölündü (kullanıcı kararı). Faz 4a'nın elle kontrolünde kullanıcı skill / save için ayrı
  bir tarz istedi (D32 revize); düzeltme ve Faz 4b uygulandı, otomatik kapı yeşil; ikisi birlikte
  elle kontrol bekliyor (2026-10-11). Kullanıcı kararıyla (2026-10-12) elle kontrol sonraya
  ertelendi ve iş commit'lendi; bekleyen kontroller Faz 4b sonucundaki listede. Faz 5 uygulandı,
  otomatik kapı yeşil (2026-10-12). Faz 4a, 4b ve 5 kapandı (2026-10-12): kullanıcı elle kontrolü
  kısmen yaptı ("genel olarak okey, bir şey kırılmış gibi durmuyor"); bulgular ve düzeltmeler Faz 5
  sonucunun altında. Faz 6 öncesi kararlar (2026-10-12): V14 reddedildi → D34 (Seviye ve Otomatik
  kaynaklar silinebilir, bağımlılık uyarısı), V15 onaylandı → D35, V17 / V19 / V23 yerine D36
  (Savaş değerleri bloğu).

| Faz | Konu | Boyut | Durum |
|---|---|---|---|
| 0 | Güvenlik ağı | S | ✅ (R turu yok) |
| 1 | Template deposu ve Templates sekmesi | M | ✅ (E listesi yok) |
| 2 | Template editörü: kategoriler ve düzen | L | ✅ |
| 3 | Free dünya ve template güncellemesi | M | ✅ |
| 4a | Tablo, Stat tablosu, SRD dönüşümü v2 | M | ✅ (elle kontrol kısmi) |
| 4b | Hazır içerikler | M | ✅ (elle kontrol kısmi) |
| 5 | Paketler | M | ✅ (elle kontrol kısmi) |
| 6 | Oyuncu kartı, karakter kağıdı, kaynak, dinlenme | L | ⏳ |
| 7 | Seviye sistemi | L | ⏳ |
| 8 | Karakter oluşturma rehberi | M | ⏳ |
| 9 | Encounter ve harita ayarları | M | ⏳ |
| 10 | Kapanış | S | ⏳ |

---

## İçindekiler

1. [Nasıl çalışıyoruz?](#1-nasıl-çalışıyoruz)
2. [Kesin kurallar](#2-kesin-kurallar)
3. [Faz kapısı](#3-faz-kapısı)
4. [Kodda bulunanlar: tasarımla farklar](#4-kodda-bulunanlar-tasarımla-farklar)
5. [Tasarım fazlarıyla eşleşme](#5-tasarım-fazlarıyla-eşleşme)
6. [SRD tiplerinin dönüşüm takvimi](#6-srd-tiplerinin-dönüşüm-takvimi)
7. [Fazlar](#7-fazlar)
8. [Yol haritası kararları — onay bekleyenler](#8-yol-haritası-kararları--onay-bekleyenler)

---

## 1. Nasıl çalışıyoruz?

```mermaid
flowchart LR
    A["Faz başlar<br/>(ilgili V'ler onaylı)"] --> B["Uygulama + otomatik testler"]
    B --> C["Faz kapısı<br/>G1–G6 yeşil"]
    C --> D["Faz raporu:<br/>ne yapıldı · nasıl açılır · elle kontrol listesi"]
    D --> E{"Kullanıcı uygulamayı<br/>açıp kontrol eder"}
    E -- "bulgu var" --> B
    E -- "✅" --> F["Faz kapanır, durum tablosu güncellenir,<br/>sonraki faz başlar"]
```

- **Bir faz, kullanıcı elle kontrol edip onaylamadan kapanmaz.** Sonraki faza onaysız geçilmez.
- **Bulgular aynı fazda düzeltilir.** Düzeltme sonrası sadece ilgili kontrol maddeleri ve R turu
  tekrarlanır.
- **Her fazın başında** o fazın dayandığı varsayımlar (V…) kullanıcıya hatırlatılır. Biri
  değişirse faz başlamadan DESIGN.md güncellenir.
- **Commit ve push** sadece kullanıcı isteyince yapılır. Öneri: her faz kendi commit(ler)iyle
  kapanır, böylece faz bazında geri dönülebilir.

### 1.1 Faz raporu

Her fazın sonunda kullanıcıya şu yapıda bir rapor verilir:

```
Faz N — <konu>
  Yapılanlar        : madde madde, kullanıcının göreceği şekilde
  Otomatik kapı     : G1–G6 sonuçları (komut çıktısıyla)
  Nasıl açılır      : komut (§1.2)
  Elle kontrol      : fazın E listesi + R turu
  Bilinen sınırlar  : bu fazda bilerek eksik bırakılanlar ve hangi fazda geldikleri
```

### 1.2 Uygulamayı açmak

```bash
cd flutter_app
~/flutter-3.47/bin/flutter pub get
~/flutter-3.47/bin/dart run build_runner build --delete-conflicting-outputs
DM_DATA_ROOT=$HOME/dmt-free-test ~/flutter-3.47/bin/flutter run -d linux
```

Windows (PowerShell; `flutter` PATH'te, 3.47.6):

```powershell
cd flutter_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
$env:DM_DATA_ROOT = "$HOME\dmt-free-test"; flutter run -d windows
```

- **Ayrı veri klasörü:** `DM_DATA_ROOT` ile branch, gerçek verinden ayrı bir kopyada çalışır
  (gerçek veri: Linux'ta `~/Documents/DungeonMasterTool`, Windows'ta
  `%LOCALAPPDATA%\DungeonMasterTool`). Kopya Faz 0'da bir kez alınır (§7, Faz 0). Böylece
  yarım bir faz gerçek dünyalarına dokunamaz.
- **Hesapla kullanıyorsan** her zamanki `--dart-define` değerlerini de ekle; yoksa uygulama
  offline açılır ve hesaba bağlı veri klasörünü görmez.
- **Telefon görünümü (desktop'ta):** pencereyi kısa kenarı 600 px'in altında kalacak şekilde
  daralt (ör. 420 × 860). Uygulama bunu telefon sayar
  ([screen_type.dart](../../flutter_app/lib/core/utils/screen_type.dart)).
- **Gerçek dokunmatik:** basılı tutup sürükleme gibi hareketler için Android cihaz ya da emülatör:
  `~/flutter-3.47/bin/flutter run -d <cihaz>`. Bu kontrol Faz 2, 6 ve 7'de istenir.

---

## 2. Kesin kurallar

Pazarlığa açık değildir. Biri ihlal ediliyorsa iş durur, kullanıcıya sorulur.

| # | Kural | Neden |
|---|---|---|
| **K1** | `flutter_app/lib/domain/entities/schema/builtin/` altında hiçbir dosya değişmez. `srdCorePackVersion` artmaz. | DESIGN §17. Yerleşik template ve SRD içeriği dokunulmazdır. |
| **K2** | **Yerleşik şemanın JSON çıktısı değişmez.** Modellere (`WorldSchema`, `EntityCategorySchema`, `FieldGroup`, `FieldSchema`) eklenen her yeni alan nullable olur ve `@JsonKey(includeIfNull: false)` taşır. Yeni `FieldType` değerleri eklenebilir; mevcut değerlerin adı ve JSON değeri değişmez. | Yeni alan JSON'a girerse yerleşik dünyalarda kayıtlı şema ile üretilen şema ayrışır. Faz 0'daki koruma testi bunu yakalar. |
| **K3** | **Free yol ayrı bir daldır.** Tek kapı: `isFreeTemplate(schema)`. Yerleşik kod yolunun içine free mantığı yazılmaz; sadece çağrı noktasında dallanılır. Büyük yerleşik ekranlara (ör. 4040 satırlık [character_editor_screen.dart](../../flutter_app/lib/presentation/screens/characters/character_editor_screen.dart)) dal eklemek yerine free için ayrı ekran yazılır. | İ5 / D18. Yerleşik davranışın değişmediğini göstermenin en kolay yolu o koda dokunmamaktır. |
| **K4** | Kural motoruna dokunulmaz: `CharacterResolver`, sihirbaz, seviye atlama planlayıcısı, bekleyen seçimler. `grant_contract_test` ve `grant_field_isolation_test` dokunulmadan geçer. | DESIGN §17. Seviye sistemi (Faz 7) resolver'ı kullanmaz; kendi küçük ve saf fonksiyonunu kullanır. |
| **K5** | Drift `schemaVersion` artmaz. Yeni depolar `beforeOpen` içinde idempotent DDL'li yan tablo olur (bugünkü `asset_refs` / `sync_tombstones` gibi). Veritabanı erişimi DAO'dan geçer. | DESIGN §17, CLAUDE.md. |
| **K6** | Free template'li dünyada "online yap" kapalıdır. Free template'ler hiçbir senkron, paylaşım ya da marketplace yoluna girmez. | V21, D18. |
| **K7** | Kullanıcıya görünen her metin `app_en.arb` → `app_tr.arb`, `app_de.arb`, `app_fr.arb` sırasıyla eklenir. | CLAUDE.md. |
| **K8** | Repo kuralları: CRLF dosyalarda satır sonu korunur; mevcut dosyalara `dart format` çalıştırılmaz; `~/flutter-3.47/bin/flutter` kullanılır; anotasyonlu sınıf değişince `build_runner` çalıştırılır. | Repo hafızası. |
| **K9** | Mimari açıdan önemli her yeni dosyanın `vault/10-Files/<alan>/` altında notu olur; davranışı değişen dosyanın notu güncellenir; her faz `vault/90-Meta/Vault-Changelog.md`'ye bir satır ekler. | CLAUDE.md, vault SOP. |

---

## 3. Faz kapısı

Her faz, en küçük düzeltme dahil, bu listeden geçmeden "bitti" sayılmaz.

### 3.1 Otomatik kapı

```
[ ] G1  Yerleşik template dokunulmadı:
        git diff --stat 1d3eba6b -- flutter_app/lib/domain/entities/schema/builtin/   → BOŞ
[ ] G2  Yerleşik şema donmuş (Faz 0'da eklenen koruma testi):
        flutter test test/domain/entities/schema/builtin_schema_frozen_test.dart      → PASS
[ ] G3  Kural motoru sözleşmeleri:
        flutter test test/domain/services/grant_contract_test.dart \
                     test/domain/services/grant_field_isolation_test.dart              → PASS
[ ] G4  flutter analyze                                                                → yeni uyarı yok
[ ] G5  Fazın kendi testleri + dokunulan dosyaların testleri                           → PASS
[ ] G6  Tam test seti, Faz 0'daki temel çizgiyle karşılaştırılır                       → yeni kırmızı yok
```

### 3.2 R turu — her fazda tekrarlanan regresyon kontrolü

Yerleşik template'le çalışan her şeyin aynı kaldığını gösterir. Faz 0'da bir kez **referans**
olarak yapılır; sonraki her fazda Faz 0'daki gözlemle karşılaştırılır.

| # | Kontrol | Beklenen |
|---|---|---|
| R1 | Mevcut yerleşik bir dünyayı aç. Kenar çubuğuna, bir büyüye (Fireball), bir canavara (Goblin) ve bir sınıfa (Fighter) bak. | Kenar çubuğu Tier gruplu; kartlar Faz 0'daki gibi. |
| R2 | Mevcut bir karakteri aç. | AC, HP, skill toplamları ve "çözülen grant'ler" kartı Faz 0'daki gibi. |
| R3 | Yerleşik template'le yeni karakter oluştur. | Sihirbaz baştan sona çalışır. |
| R4 | Bu karakterle seviye atla, sonra kısa ve uzun dinlen. | Seviye atlama planlayıcısı ve dinlenme Faz 0'daki gibi. |
| R5 | Bir encounter kur: bir canavar ve bir oyuncu. İnisiyatif at, HP'yi +/− ile değiştir. | Faz 0'daki gibi; oyuncunun HP'si kağıda yazılır. |
| R6 | Packages sekmesinde mevcut bir paketi aç ve bir kartına bak. | Faz 0'daki gibi. |
| R7 | "SRD içeriğini ekle" açık yeni bir yerleşik dünya oluştur. | SRD kartları gelir. |
| R8 | Templates sekmesinde yerleşik template'i incele. | Salt okunur; düzenleme yok. |

---

## 4. Kodda bulunanlar: tasarımla farklar

Yol haritası hazırlanırken kod okundu. DESIGN.md'nin varsaydığı ama kodda farklı olan noktalar:

| # | Bulgu | Etkisi | Faz |
|---|---|---|---|
| B1 | **Template güncelleme diyaloğu ölü kod.** DESIGN §6.4 "banner bugün de var" diyor; ama diyaloğu açan servis (`TemplateSyncService`, `pendingTemplateUpdateProvider`) `781b8bd7`'de silinmiş. Diyalog [worlds_tab.dart](../../flutter_app/lib/presentation/screens/hub/worlds_tab.dart) içinde `_showPreOpenTemplateDialogDead` adıyla duruyor. `applyTemplateUpdate` / `dismissTemplateUpdate` / `muteTemplateUpdates` ise [campaign_provider.dart](../../flutter_app/lib/application/providers/campaign_provider.dart) içinde çalışır halde. | Değişiklik kontrolü yeniden yazılır, diyalog canlandırılır. Eski servis `git show 781b8bd7^:flutter_app/lib/application/services/template_sync_service.dart` ile referans alınabilir. | 3 |
| B2 | **Yerleşik şemanın hash'i her açılışta değişir.** `generateBuiltinDnd5eV2Schema()` her kategori ve alana `DateTime.now()` ve rastgele (v4) `categoryId` / `fieldId` yazıyor; `computeWorldSchemaContentHash` kategorileri bunlarla birlikte hash'liyor. | Değişiklik kontrolü sadece **free template'li dünyalarda** çalışır. Yerleşik dünyada açılırsa her açılışta sahte "güncelleme var" çıkar. Faz 0'daki koruma testi zaman damgalarını ve id'leri çıkarıp hash'ler. | 0, 3 |
| B3 | `allTemplatesProvider` bugün sadece yerleşik template'i döndürdüğü için tüketicileri buna güveniyor: sihirbaz, paket oluşturma, dünya oluşturma, karakter ekranı, global etiketler. | Free template'ler listeye girince sihirbaz ve paket oluşturma onları **görmemeli** (ilgili fazlar gelene kadar). Faz 1'de her tüketici tek tek ele alınır. | 1 |
| B4 | Eski kullanıcı template'leri `cache/templates/*.json` dosyalarında tutuluyordu (`781b8bd7^`). Cache klasörü silinebilir bir yer. | Yeni depo kullanıcı başına veritabanında yan tablo olur (K5). | 1 |
| B5 | SRD içeriği altı yerde `templateId == builtinDnd5eV2SchemaId` ile kapılı: [world_repository_impl.dart](../../flutter_app/lib/data/repositories/world_repository_impl.dart) (171, 567, 605), worlds_tab.dart (572), [srd_core_bootstrap.dart](../../flutter_app/lib/application/services/srd_core_bootstrap.dart) (27), [world_join_service.dart](../../flutter_app/lib/application/services/world_join_service.dart) (132). | SRD soyundan gelen kopyalarda SRD paketinin kurulabilmesi (V28) için kapı genişletilir. `_overlayMissingBuiltinCategories` (605) **genişletilmez**: kopyada silinen SRD kategorileri geri gelmemeli. | 3 |
| B6 | Mevcut `FieldType.levelTable` adı zaten kullanılıyor (`Map<int,int>`). | Yeni "Seviye tablosu" tarzı başka bir enum adı alır (K2). Adlar fazında seçilir. | 7 |

---

## 5. Tasarım fazlarıyla eşleşme

DESIGN §19'daki beş faz, elle kontrol edilebilecek büyüklükte parçalara bölündü:

| DESIGN §19 | Bu yol haritası |
|---|---|
| 1 — Template editörü | 0 · 1 · 2 · 3 · 4 · 5 |
| 2 — Oyuncu kartı ve kağıt | 6 |
| 3 — Seviye sistemi | 7 |
| 4 — Rehber | 8 |
| 5 — Encounter ve harita | 9 |
| — | 10 (kapanış) |

---

## 6. SRD tiplerinin dönüşüm takvimi

SRD kopyası dönüştürücüsü (DESIGN §16.2) fazlarla büyür. Bir tip, hedef tarzının geldiği fazda
dönüşür. O zamana kadar kopyada **eski tipiyle** kalır: bugünkü widget'la gösterilir, paletten
eklenemez, editörde sadece etiket, grup, genişlik ve görünürlüğü değişir, yanında "SRD tipi"
rozeti olur.

| SRD tipi | Kopyada | Faz |
|---|---|---|
| `crCalculator` | Kaldırılır | 1 |
| Yazı, sayı, zar, görsel, kart bağlantısı, etiket, tarih, dosya | Aynen kalır | 1 |
| `statBlock` | Stat tablosu (değiştirici açık / kapalı) | 4 |
| `proficiencyTable` | Yetenek tablosu, Skill / Saving throw hazır içeriğine bağlı | 4 |
| `levelTable`, `levelTextTable` | Tablo (Seviye · Değer / Seviye · Yazı) | 4 |
| `rangedSenseList`, `spellEffectList` | Tablo, serbest satırlar | 4 |
| `equipmentChoiceGroups`, `playerChoices`, `subspeciesOptions` | Markdown (SRD verisi okunurken metne çevrilir) | 4 |
| `combatStats` | Savaş değerleri (D36): HP / Max HP, AC, İnisiyatif, XP, Durumlar; Hız ve NPC'de CR bloğun dışında sayı alanı | 6 |
| Canavar, Hayvan › `ac`, `hp_average`, `initiative_modifier` | Savaş değerleri bloğu eklenir, değerler okuyucuyla blokta (D36) | 6 |
| `slot` | Kaynak (kutucuk) | 6 |
| `spellSlotGrid`, `class_levels` | Kaldırılır | 6 |
| `classFeatures` | Seviye tablosu | 7 |
| `resourcePoolGrants` | Kaynak verme | 7 |
| `spellSlotProgression` + büyücü türü | Sınıf kartında Kaynak verme | 7 |
| `spellsAtLevel` | Seviye tablosu (+ günlük kullanım için Kaynak verme) | 7 |

> **Önemli:** Bir fazda yeni dönüşüm eklenince önceki fazlarda oluşturulmuş test kopyaları eski
> haliyle kalır. Kontrol listeleri bu yüzden "SRD'yi yeniden kopyala" adımıyla başlar. Fazlar
> arası template geçiş kodu yazılmaz (§8, Y1).

---

## 7. Fazlar

Her faz aynı yapıdadır: **Amaç · Onay gereken varsayımlar · Yapılacaklar · Dokunulan yerler ·
Kapsam dışı · Otomatik testler · Elle kontrol · Çıkış kriteri.**

---

### Faz 0 — Güvenlik ağı

**Amaç:** Hiçbir davranış değişmeden önce, "bozmadık" demeyi mümkün kılan ölçümleri kurmak.

**Yapılacaklar:**

1. **Test temel çizgisi:** temiz ağaçta tam `flutter test` çalıştırılır. Kırmızı testlerin listesi
   bu dokümana (§7, Faz 0 sonucu) yazılır. G6 bununla karşılaştırır.
2. **Yerleşik şema koruma testi** (`test/domain/entities/schema/builtin_schema_frozen_test.dart`):
   `generateBuiltinDnd5eV2Schema().schema.toJson()` çıktısından `createdAt` / `updatedAt` ve
   rastgele `categoryId` / `fieldId` çıkarılır, kanonik JSON'un SHA-256'sı sabit bir değerle karşılaştırılır. Kategori sayısı (75)
   ve alan sayısı (928) da ayrıca doğrulanır. Bu test K1 ve K2'nin otomatik bekçisidir.
3. **Test veri klasörü:** `cp -a ~/Documents/DungeonMasterTool ~/dmt-free-test` (§1.2). Bundan
   sonra branch hep bu klasörle açılır.

**Dokunulan yerler:** sadece yeni test dosyası. Uygulama kodu değişmez.

**Otomatik testler:** koruma testi yeşil; `builtin/` altında tek satır değiştirilince kırmızı
olduğu bir kez elle denenip geri alınır.

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E0.1 | Uygulamayı test klasörüyle aç (§1.2). | Gerçek verinle aynı dünyalar, karakterler, paketler görünür. |
| E0.2 | R turunu (§3.2) baştan sona yap; her maddede gördüğünü kısaca not et (gerekirse ekran görüntüsü). | Bu notlar sonraki fazların **referansıdır**. |

**Çıkış kriteri:** temel çizgi kayıtlı, koruma testi yeşil, R turu referansı alınmış.

**Faz 0 sonucu** (2026-10-11, Windows, Flutter 3.47.6, base `0b6b2b79` + koruma testi):

- **Tam test:** 1695 test → 1692 geçti, 3 kırmızı, 1 asılı. Temel çizgideki kırmızılar:
  - `test/application/services/content_transfer/content_archive_test.dart` — "zip olmayan dosya net hata verir"
  - `test/domain/services/bundled_pack_resolve_test.dart` — "M1 — pack mechanics reach EffectiveCharacter every (pack, mechanic field) pair produces a sheet effect"
  - `test/presentation/srd_tr_entity_card_test.dart` — "SRD kartı TR okuma modunda Türkçe, düzenleme ve kayıt İngilizce"
- **Asılı:** `test/presentation/entity_card_flush_test.dart` — "closing the card inside the debounce
  window keeps the edit" hiç bitmiyor; `--timeout` da kesmiyor ve tam çalıştırmayı kilitliyor. Bu
  yüzden G6 bu dosya **hariç** çalıştırılır:

  ```bash
  cd flutter_app
  flutter test $(find test -name '*_test.dart' ! -name entity_card_flush_test.dart)
  ```
- **`flutter analyze`:** 32 info, 0 warning, 0 error (G4 bununla karşılaştırır).
- **Koruma hash'i:** `2776a95a777c3300d23d31adc126f2f47fa1c16a1e1fb70174fc088affd8d110` (75 kategori, 928 alan).
- **Test veri klasörü:** `C:\Users\122oa\dmt-free-test` (`%LOCALAPPDATA%\DungeonMasterTool`'un
  kopyası). Kopyanın `.root_moved_from` dosyası gerçek kökü gösterir: ilk açılışta `beforeOpen`
  gövdelerdeki mutlak medya yollarını kopyaya çevirir, test sırasında gerçek dosyalara dokunulmaz.
- **Elle kontrol yapılmadı:** E0.1 (test klasörüyle açılış) ve E0.2 (R turu referansı) bu adımda
  yapılmadı; faz, Faz 0'da uygulama kodu değişmediği için kullanıcı kararıyla kapatıldı. Sonraki
  fazların R turu yazılı bir referansla değil, `main`'deki davranışla karşılaştırılır; ilk R turu
  yapıldığında gözlemler buraya referans olarak eklenir.

---

### Faz 1 — Template deposu ve Templates sekmesi

**Amaç:** Kullanıcı SRD'yi kopyalayabilsin, kopyalarını listeleyip yeniden adlandırabilsin ve
silebilsin. Kopyalar uygulama kapanıp açılınca kalır. Henüz düzenleme ve dünya yok.

**Onay gereken varsayımlar:** V1 (boş template sadece oyuncu kartıyla başlar), V2 (template
silinirse dünyalar kendi kopyalarıyla sürer).

**Yapılacaklar:**

1. **Model:** `WorldSchema`'ya free bilgisi (free mi + soy kökü, yani hangi template'ten
   türediği) ve `EntityCategorySchema`'ya "oyuncu kartı mı" bilgisi eklenir. İkisi de nullable,
   `includeIfNull: false` (K2). Tek kapı `isFreeTemplate(schema)` yazılır.
2. **Depo:** `user_templates` yan tablosu (`beforeOpen` DDL, K5) + DAO + repository: listele,
   getir, kaydet, sil. Kaydederken `originalHash` ilk kayıtta dondurulur.
3. **SRD kopyası dönüştürücüsü (v1):** saf bir domain fonksiyonu. Yeni benzersiz kimlik, ad
   "… (kopya)", free işareti, soy kökü = yerleşik template, `player-character` → oyuncu kartı
   işareti, `crCalculator` alanları kaldırılır (§6). Kopyadaki `isBuiltin` bayraklarının nerede
   okunduğu kontrol edilir; kopyayı yerleşik saymaya yol açan bir okuma varsa kopyada kapatılır.
4. **Boş template:** sadece oyuncu kartı kategorisiyle başlar. Sabit alanları (Seviye, Otomatik
   kaynaklar) Faz 6'da gelir.
5. **Free'den free kopya:** soy kökü korunur (SRD → kopyam → kopyam-low-magic hepsi SRD soyunda).
6. **Sağlayıcı:** `allTemplatesProvider` = yerleşik + kullanıcı template'leri. Tüketiciler (B3):
   - Sihirbaz ve karakter oluşturma → sadece yerleşik (Faz 6'ya kadar).
   - Paket oluşturma → sadece yerleşik (Faz 5'e kadar).
   - Dünya oluşturma → sadece yerleşik (Faz 3'e kadar).
   - Karakter ekranı ve global etiketler → olduğu gibi (kimlikle arama yapıyorlar).
7. **Templates sekmesi:** yerleşikte "İncele" ve "Kopyala"; free'de "İncele", "Yeniden adlandır",
   "Kopyala" ve "Sil" (onaylı). "Boş template oluştur" butonu. "Düzenle" Faz 2'de gelir.

**Dokunulan yerler:** [world_schema.dart](../../flutter_app/lib/domain/entities/schema/world_schema.dart),
[entity_category_schema.dart](../../flutter_app/lib/domain/entities/schema/entity_category_schema.dart),
[app_database.dart](../../flutter_app/lib/data/database/app_database.dart) (yan tablo DDL),
yeni DAO + repository, [template_provider.dart](../../flutter_app/lib/application/providers/template_provider.dart),
[templates_tab.dart](../../flutter_app/lib/presentation/screens/hub/templates_tab.dart),
[worlds_tab.dart](../../flutter_app/lib/presentation/screens/hub/worlds_tab.dart),
[packages_tab.dart](../../flutter_app/lib/presentation/screens/hub/packages_tab.dart),
[character_creation_wizard_screen.dart](../../flutter_app/lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart),
`.arb` dosyaları.

**Kapsam dışı:** düzenleme, dünya, paket, karakter.

**Otomatik testler:** dönüştürücü (yeni kimlik, soy, oyuncu kartı işareti, CR yok, 75 kategori,
diğer alanlar aynen); depo (kaydet → getir → sil; ikinci açılışta liste aynı); sağlayıcı
filtreleri (sihirbazın ve paket oluşturmanın listesinde free yok).

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E1.1 | Templates sekmesi → yerleşik template → **Kopyala**. | "D&D 5e (SRD 5.2.1) (kopya)" listede belirir. |
| E1.2 | Kopyayı **İncele**. | Kategoriler ve alanlar yerleşikle aynı; canavarda CR hesaplayıcı yok. |
| E1.3 | Kopyayı **yeniden adlandır**: "SRD kopyam". | Yeni ad listede. |
| E1.4 | "SRD kopyam"dan bir kopya daha al, sonra onu **Sil**. | Silmeden önce onay sorulur; silinen listeden kalkar. |
| E1.5 | **Boş template oluştur**, incele. | Tek kategori: oyuncu kartı. |
| E1.6 | Uygulamayı kapat ve aç. | Template'ler, adları ve sıraları duruyor. |
| E1.7 | Yeni dünya, yeni karakter ve yeni paket diyaloglarını aç. | Üçünde de free template **görünmüyor**. |
| E1.8 | Telefon görünümünde Templates sekmesi. | Butonlar sığıyor, taşma yok. |
| E1.8b | Kendi şablonunu seç → **Aktar → Dışa aktar**; sonra sil ve **Aktar → İçe aktar** ile geri al. | Ad, açıklama, etiket ve kapakla geri gelir. Yerleşik seçiliyken Sil ve Dışa aktar kapalı. |
| E1.9 | R turu. | Faz 0 referansıyla aynı. |

**Çıkış kriteri:** SRD kopyalanır, kopya kalıcıdır; yerleşik akışların hiçbirinde free template
görünmez.

**Faz 1 sonucu** (2026-10-11, Windows; kapandı):

- **Yapılanlar:**
  - `WorldSchema.freeRootId` (free ise soy kökü; ayrı bir "free mi" bayrağı yok, kök doluysa
    free) ve `EntityCategorySchema.isPlayerCard`. İkisi de nullable, `includeIfNull: false`;
    koruma hash'i değişmedi.
  - [free_template.dart](../../flutter_app/lib/domain/services/free_template.dart): `isFreeTemplate`
    (tek kapı), `isSrdLineage`, `copyAsFreeTemplate` (yerleşik ya da free kaynak), `emptyFreeTemplate`.
    Kategori ve alan kimlikleri korunur (şema içinde geçerli); `originalHash` kopyada dondurulur.
  - `user_templates` yan tablosu + [user_templates_dao.dart](../../flutter_app/lib/data/database/daos/user_templates_dao.dart).
  - [template_provider.dart](../../flutter_app/lib/application/providers/template_provider.dart):
    `userTemplatesProvider` (kopyala, boş oluştur, bilgileri kaydet, sil).
  - Templates sekmesi (kullanıcı geri bildirimiyle, 2026-10-11) Worlds sekmesinin düzeninde:
    bütün şablonlar aynı banner kartıyla (`MetadataListTile`); karta tıklamak seçer, çift tık
    açar (Görüntüle); en altta **Görüntüle · Kopyala · Aktar · Sil** seçili şablona uygulanır.
    Yerleşik şablon seçiliyken Sil ve Dışa aktar kapalı. Rozet yok; yalnız yerleşik kartta
    adın yanında çerçevesiz bir kilit ikonu. Faz 2'de kendi şablonlarında ilk buton "Düzenle" olur. Sağ üstteki **+** boş şablon oluşturur.
    Kendi şablonlarında ⚙ → Worlds'teki gibi ayarlar (`MetadataEditorSection`): ad, açıklama,
    etiketler, kapak; en altta **Şablonu sil**. SRD soyundaki şablonlar kapak seçilmediyse SRD
    bannerını kullanır. Kopyalama ve boş oluşturma ad sorar; silme onay sorar.
  - **Aktar (`.dmtz`):** free template dışa / içe aktarılır (`ContentItemType.template`).
    Kapak `LocalMediaLocalizer.templateDir(id)`'ye kopyalanır ve dosyaya girer; içe aktarmada
    aynı kimlikli şablon dosyadaki haliyle değişir. Yerleşik şablon aktarılmaz.
  - Açıklama `WorldSchema.description`'da; etiketler ve kapak `metadata['tags']` /
    `metadata['cover_image_path']`'te (dünya ve paketlerle aynı anahtarlar; etiketler global
    etiket önerilerine de girer). **Faz 3 için not:** `metadata` içerik hash'ine giriyor; değişiklik
    kontrolü bu iki anahtarı hariç tutmalı, yoksa kapak değişince dünyaya "şablon güncellendi"
    sorulur.
  - İnceleyici: telefonda kategori listesi → kategori sayfası (geri tuşu ve "Kategoriler" listeye
    döner); desktop'ta iki panel. Desktop'taki seçili kategori vurgusu eskiden hiç görünmüyordu
    (liste `ColoredBox` içindeydi), düzeltildi.
- **Roadmap'ten sapmalar:**
  - Madde 6: `allTemplatesProvider`'a free template **eklenmedi**; yerleşik akışlar için yalnız
    yerleşik template'i döndürmeye devam ediyor. Free template'ler ayrı `userTemplatesProvider`'da.
    Böylece sihirbaz, dünya, paket ve karakter ekranlarına filtre eklemek gerekmedi (K3); her
    akış kendi fazında yeni sağlayıcıyı kullanmaya başlar (dünya Faz 3, paket Faz 5, karakter Faz 6).
  - Madde 2: ayrı bir repository sınıfı yok; DAO'yu doğrudan sağlayıcıdaki notifier kullanıyor
    (bu repoda `character_repository` gibi arayüzsüz örnekler var).
  - DESIGN §20 "`.dmtz` ile tek başına template" sonraya bırakılmıştı; kullanıcı Templates
    sekmesinde de Aktar istediği için Faz 1'e alındı. Yalnız yerel dosya; senkron, paylaşım ve
    marketplace yolu yok (K6 korunuyor).
  - Madde 3: kopyadaki `isBuiltin` bayrakları olduğu gibi kaldı; şema düzeyindeki bu bayrağı
    okuyan kod yok (uygulamadaki `isBuiltin` okumaları paket ve kartlarla ilgili).
- **Otomatik kapı:** G1 boş · G2 yeşil · G3 60/60 · G4 32 info, 0 uyarı (temel çizgiyle aynı) ·
  G5 `free_template_test` (6), `user_templates_provider_test` (2, dosyalı DB kapatılıp açılıyor),
  `templates_tab_layout_test` (10: telefon/desktop × en/tr, büyük yazı, seç → kopyala → ayarlarda
  ad değiştir → sil akışı, ayarlardan sil, boş liste, inceleyici akışı), `template_archive_test`
  (iki ayrı veri kökü arasında `.dmtz` gidiş-dönüşü, kapak dahil; yerleşik dışa aktarılamaz) yeşil · G6 1712 geçti; kırmızılar temel çizgideki 3 testle aynı
  (tam çalıştırma sırasında yakalanan diyalog hatası düzeltildikten sonra
  `templates_tab_layout_test` ayrıca yeniden çalıştırıldı, yeşil).
- **Testin yakaladığı hata:** ad diyaloğunun `TextEditingController`'ı diyalog kapanırken dispose
  ediliyordu ("used after being disposed"). Controller diyalog widget'ının kendi `State`'ine
  taşındı. Aynı kalıp [packages_tab.dart](../../flutter_app/lib/presentation/screens/hub/packages_tab.dart)
  paket kopyalama diyaloğunda da var; yerleşik akış olduğu için bu işte dokunulmadı.
- **G6 Windows'ta:** bütün dosyaları tek tek vermek "command line is too long" hatası verir;
  klasörler + `test/presentation` dosyaları verilir:

  ```powershell
  $pres = Get-ChildItem test/presentation -Recurse -Filter *_test.dart | ? { $_.Name -ne 'entity_card_flush_test.dart' } | % { (Resolve-Path -Relative $_.FullName) -replace '^\.\\','' }
  flutter test (@('test/application','test/core','test/data','test/database','test/domain','test/tool','test/local_media_localizer_dir_safe_test.dart','test/widget_test.dart') + $pres)
  ```
- **Elle kontrol yapılmadı:** E1.1–E1.9 tek tek işaretlenmedi. Kullanıcı Templates sekmesini
  açıp üç turda geri bildirim verdi (kart düzeni, alt buton satırı, rozetler) ve "devam"
  dedi. R turu referansı olmadığı için E1.9 da yok.
- **Bilinen sınırlar:** düzenleme Faz 2'de; free template'le dünya Faz 3'te. Boş template'in
  oyuncu kartı alansız başlar (sabit alanlar Faz 6). Aynı adlı iki template'e izin veriliyor
  (kimlikleri ayrı).

---

### Faz 2 — Template editörü: kategoriler ve düzen

**Amaç:** DESIGN'ın ilk hedefi (D5): kullanıcı SRD kopyasında kategorileri, grupları, kolonları ve
alanları istediği gibi düzenleyebilsin. Mobil ve desktop'ta rahat.

**Onay gereken varsayımlar:** V3 (anahtar etiketten üretilir, değişmez), V4 (uyumsuz tip
değişimi = yeni anahtar), V5 (silinen kategori), V22 (telefonda tek kolon), V26 (otomatik kayıt),
V27 (önizleme).

**Yapılacaklar:**

1. **Editör ekranı** (free için yeni; yerleşik için mevcut inceleyici aynen kalır, R8):
   - Desktop: üç panel (template · kategori düzeni · ayarlar) + altta palet şeridi (DESIGN §7.5).
   - Telefon: iç içe ekranlar + alttan açılan "Ekle" sayfası (DESIGN §7.6).
   - Silinmiş eski editör (`git show 781b8bd7^:flutter_app/lib/presentation/screens/hub/template_editor.dart`)
     sadece referans olarak okunur; kopyalanmaz.
2. **Template içeriği:** Bilgiler (ad, açıklama, sürüm) ve Kategoriler (ekle, sil, sürükleyerek
   sırala). Oyuncu kartı silinemez (adı ve ikonu değişir).
3. **Kategori ayarları** (DESIGN §7.2): ad, ikon, renk, filtre alanları, göründüğü bölümler.
   Seviye modu Faz 7'de gelir.
4. **Gruplar:** ekle, sil, yeniden adlandır; kolon sayısı; "kapalı başlasın"; sürükleyerek sırala;
   ⋮ menüsünden "alanları başka gruba taşı".
5. **Alanlar:**
   - Paletten basit tarzlar (DESIGN §8, basit tarzlar tablosu) eklenir: sürükle-bırak ya da
     tıklayınca seçili gruba.
   - Grup içinde ve gruplar arasında sürüklenir.
   - Alan ayarları (DESIGN §7.3): etiket, anahtar (salt okunur), liste, yardım metni, varsayılan,
     zorunlu, görünürlük, genişlik, grup ve tarza özel ayarlar (seçenek listesi, en az / en çok,
     hedef kategori, izinli uzantılar).
   - Tip değişikliği DESIGN §6.6'daki uyumlu tip tablosuna göre. Uyumsuzsa uyarı, onaylanırsa
     yeni anahtarla yeni alan.
   - Eski SRD tipleri rozetle görünür, sınırlı ayarla (§6).
6. **Otomatik kayıt** (gecikmeli). Silmeler her zaman onay sorar.
7. **Önizle:** orta panel, gerçek kart görünümüyle örnek bir kart çizer. Bu, Faz 3'teki kart
   ekranının free'de doğru çizdiğinin de ilk kontrolüdür.

**Dokunulan yerler:** yeni editör ekranı ve widget'ları (`lib/presentation/screens/templates/`
altında), [templates_tab.dart](../../flutter_app/lib/presentation/screens/hub/templates_tab.dart)
("Düzenle"), router, `.arb` dosyaları. Kart çizimi için
[entity_card.dart](../../flutter_app/lib/presentation/screens/database/entity_card.dart) okunur;
free'de `_shouldCenterGroup` gibi yerleşik sabitleri devre dışı bırakan kapı burada eklenir.

**Kapsam dışı:** Tablo, Stat tablosu, Kaynak, Seviye tablosu tarzları; hazır içerikler; rehber;
encounter ayarları; dünyaya yansıma.

**Otomatik testler:** editör işlemlerinin saf mantığı ayrı tutulur ve test edilir: alan ekle,
taşı, sil; grup sil → alanların taşınması; anahtar üretimi (etiketten, çakışmada ek; bir daha
değişmez); uyumlu / uyumsuz tip kararı; oyuncu kartının silinememesi. Editör için birkaç widget
testi: telefonda ve desktop'ta açılıyor, taşma yok.

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E2.1 | "SRD kopyam" → **Düzenle** → Oyuncu kartı. | Mevcut gruplar ve alanlar düzen halinde görünür. |
| E2.2 | "Kimlik" adında grup ekle, 3 kolon yap; Tür, Sınıf ve Geçmiş'i içine sürükle. | Üçü yan yana durur. |
| E2.3 | Bir alanın genişliğini 2 yap. | İki kolon kaplar (DESIGN §7.4'teki çizim). |
| E2.4 | **Önizle.** | Oyuncunun göreceği kart görünümü; değişiklikler orada. |
| E2.5 | "Fraksiyon" kategorisi ekle: Yazı, Seçim (3 seçenek), NPC'ye giden Kart bağlantısı listesi ve Markdown alanları. Kategoriyi listede yukarı sürükle. | Kategori ve alanlar yerinde. |
| E2.6 | Bir Yazı alanını Markdown'a çevir. Sonra Seçim → Tam sayı dene. | İlki uyarısız; ikincisi uyarı verir, onaylanınca yeni alan oluşur. |
| E2.7 | Bir alanın etiketini değiştir. | Anahtar aynı kalır (ayarlarda salt okunur görünür). |
| E2.8 | Oyuncu kartını silmeyi dene. | Mümkün değil. |
| E2.9 | Bir grubu sil. | Onay sorar; içindeki alanlar silinmez, "Özellikler" altına geçer ya da seçilen gruba taşınır. |
| E2.10 | Uygulamayı kapat ve aç, editörü yeniden aç. | Bütün değişiklikler duruyor. |
| E2.11 | Aynı işleri telefon görünümünde (dar pencere) tekrarla: ekle, ayarla, sırala. | Ekranlar tek işe odaklı, taşma yok, alttan açılan sayfalar çalışıyor. |
| E2.12 | Android'de basılı tutup sürükleyerek alan ve kategori sırala. | Tek elle rahat. |
| E2.13 | R turu (özellikle R8). | Yerleşik template hâlâ salt okunur. |
| E2.14 | Editörü koyu, açık ve köşesi keskin bir temada (Grim) aç. | Kutular, checkbox'lar ve seçiciler uygulamanın geri kalanıyla aynı görünür. |
| E2.15 | Bir kategoride "Dünya haritası"nı işaretle, yanındaki simgeyi değiştir; serbest renk seç; Tier'ı değiştir. | Simge yalnız harita işaretliyken görünür; renk ve Tier kaydedilir. |

**Çıkış kriteri:** kullanıcı SRD kopyasının alanlarını ve düzenini değiştirebilir; telefonda ve
desktop'ta rahat; değişiklikler kalıcı.

**Faz 2 sonucu** (2026-10-11, Windows; kapandı):

- **Yapılanlar:**
  - Templates sekmesinde kendi şablonu seçiliyken ilk buton **Düzenle**; çift tık da açar. Yol
    (`/template/edit`) free şablonu editöre, yerleşiği değişmeyen inceleyiciye gönderir (R8).
  - [template_edit.dart](../../flutter_app/lib/domain/services/template_edit.dart): saf işlemler.
    Alan ekle / taşı / sil, grup ekle / sil / sırala / alanlarını taşı, kategori ekle / sil /
    sırala, anahtar üretimi (`keyFromLabel`: Türkçe harfler katlanır, çakışmada `_2`), DESIGN
    §6.6 uyum tablosu (`typeChangeOf`) ve uyumsuz değişimde yeni anahtarlı yeni alan.
  - Editör (`lib/presentation/screens/templates/`): genişlik ≥ 1000 px'te üç panel (şablon ·
    kategori düzeni · ayarlar) + altta palet şeridi; daha darda şablon sayfası → kategori sayfası
    → alttan açılan ayar sayfası, "+ Alan ekle" alttan tarz listesi açar.
  - Sol: Bilgiler, oyuncu kartı (sabit, silinmez), kategoriler (ekle; tutamaçla ya da basılı
    tutarak sırala). Orta: "Özellikler" kutusu + gruplar kendi kolonlarında (telefonda tek kolon,
    V22); grup başlıktaki tutamaçla, alan kendi tutamacıyla anında ya da kutucuğa basılı tutarak
    sürüklenir; paletten sürüklenen tarz bırakıldığı yere eklenir, tıklanan tarz seçili gruba.
  - Ayarlar: kategori (ad, ikon, renk, filtre alanları, dünya haritası / zihin haritası /
    projeksiyon), grup (ad, kolon 1–4, kapalı başlasın, alanları taşı, sil), alan (etiket, salt
    okunur anahtar, tarz + liste, yardım metni, varsayılan, zorunlu, görünürlük, genişlik, grup;
    tarza özel: yer tutucu ve en fazla uzunluk, en az / en çok, seçenekler, hedef kategoriler,
    izinli uzantılar). Şablon bilgileri: ad, açıklama, sürüm.
  - Eski SRD tipleri "SRD tipi" rozetiyle görünür; yalnız etiket, görünürlük, genişlik, grup ve
    sil (§6).
  - Yeni alan eklerken önce etiket sorulur: anahtar etiketten bir kez üretilir (V3).
  - Sürüklemenin alternatifi: alan, grup ve kategori ayarlarında **Yukarı / Aşağı taşı**
    butonları (WCAG 2.2 "dragging movements"; klavyeyle de çalışır). Alan tutamacı ve renk
    daireleri 44 px dokunma alanında.
  - Silmeler (alan, grup, kategori) onay sorar; grup silinince alanları "Özellikler"e geçer.
  - Otomatik kayıt: son değişiklikten 600 ms sonra ve editör kapanırken; üst çubukta
    Kaydedildi / Kaydediliyor / Kaydedilemedi (dokununca tekrar dener).
  - **Önizle:** seçili kategorinin boş örnek kartı, kartın kendi parçalarıyla (grup başlığı,
    kolon kuralı, `FieldWidgetFactory`); yazılanlar saklanmaz.
  - **Arayüz turu (kullanıcı geri bildirimi, 2026-10-11):** editör uygulamanın kendi kalıplarına
    geçirildi: `featureCardBg` / `featureCardBorder` kutular ve temanın yarıçapı (`palette.br`),
    switch yerine küçük checkbox satırları, segmented button yerine `PillTabBar` tarzı pill
    seçici, kenar çubuğu gibi renk noktalı kategori satırları, eski editördeki gibi palet
    butonları. Kategori ikonu seçimi kaldırıldı; ikon yalnız dünya haritasının iğnesi için
    kullanıldığından "Dünya haritası" işaretliyken checkbox'ın yanında seçilir (haritanın
    çözdüğü adla, `mapIconFromName`). Renge serbest renk (zihin haritasının HSV diyaloğu,
    `showCustomColorDialog`) eklendi. Kategoriye **Tier** (codex kenar çubuğu grubu) eklendi:
    `EntityCategorySchema.tier` (null olabilir, K2); boşken yerleşik slug listeleri karar verir
    (`builtinTier`), SRD kopyası her kategoriye bu değeri yazar. Kenar çubuğu bunu Faz 3'te
    kullanır.
- **Roadmap'ten sapmalar:**
  - `entity_card.dart`'taki "free'de yerleşik sabitler kapalı" kapısı **eklenmedi**: free şablonlu
    kart ekranı Faz 3'te geliyor; şimdi kapıyı çağıracak yer yok. Önizleme kendi çizimini
    kullanıyor ve grup ortalamıyor. Kapı Faz 3 madde 4'e taşındı.
  - Ayrı bir "editör ekranı" yerine dar pencerede de aynı ekran telefon akışına geçiyor; tablet
    genişliği (600–1000) telefon akışını kullanıyor.
  - "Telefonda kolon sayısı" (V22'nin isteğe bağlı kısmı) eklenmedi.
  - Kategori ikonu seçimi genel ayardan çıktı, dünya haritası satırına taşındı; kategoriye Tier
    eklendi (arayüz turu).
- **Otomatik kapı:** G1 boş · G2 yeşil · G3 yeşil · G4 32 info (temel çizgiyle aynı) · G5
  `template_edit_test` (12), `free_template_editor_test` (19: telefon / orta / desktop × en / tr,
  büyük yazı, alan ekle + yeniden adlandır + anahtar sabit + kayıt, grup / kolon / genişlik /
  taşıma, tutamaçla gruba sürükleme, yukarı / aşağı taşı, uyumsuz tarz değişimi, oyuncu kartı silinmez, grup silme,
  önizleme, SRD kopyasının 75 kategorisinin hepsi hatasız önizleniyor, telefonda ayar sayfası ve
  silince kapanması, tarz listesinden ekleme, kapanırken kayıt), `templates_tab_layout_test` (10;
  inceleyici testleri artık yerleşik şablonu açıyor) yeşil · G6 1742 geçti (Faz 1'deki 1712 + 30
  yeni); kırmızılar temel çizgideki 3 testle aynı. Arayüz turundan sonra yeniden: G1 boş · G4 32
  info · G5 `free_template_editor_test` 20 (+ Tier ve harita simgesi), `free_template_test` + SRD
  kopyasında Tier · G6 1745 geçti (+ yukarı / aşağı, Tier testleri); kırmızılar yine aynı 3 test.
- **Elle kontrol:** E2.1–E2.15. E2.12 (Android'de basılı tutup sürükleme) gerçek cihaz ister.
- **Bilinen sınırlar:**
  - Ondalık sayı alanı kartta bugünkü yazı kutusuyla çizilir (alan widget'larında ayrı ondalık
    widget'ı yok).
  - Uyumsuz değişimde emekliye ayrılan anahtar hatırlanmıyor; sonra aynı etiketle eklenen alan
    eski anahtarı (ve kartlardaki eski tipteki gizli veriyi) geri alabilir. Dünyalar free şablon
    kullanmaya başlayınca (Faz 3) ele alınmalı.
  - Harita simgesi listesi harita iğnelerinin ikonları; SRD'nin listede olmayan bir ikonu seçili
    değilse listede işaretli görünmez (editör ve harita aynı ikonu çizer, kaydedilen ad değişmez).
  - Geri al yok; silmeler onayla korunuyor.

---

### Faz 3 — Free dünya ve template güncellemesi

**Amaç:** Free template'le dünya kurulsun; SRD paketinin kartları kopyanın düzeniyle görünsün;
template değişikliği dünyaya banner ile gitsin.

**Onay gereken varsayımlar:** V2, V5, V21, V28.

**Yapılacaklar:**

1. **Dünya oluşturma:** diyalog free template'leri de listeler. Dünya, template'in kopyasını ve
   kimliğini zaten saklıyor (`settings_json` içinde `_world_schema`).
2. **SRD soyu (V28, B5):** SRD soyundaki kopyalarda "SRD içeriğini ekle" çıkar; SRD paketi ve
   Tier-0 içerik kurulur. `_overlayMissingBuiltinCategories` free'de çalışmaz (silinen
   kategoriler geri gelmesin).
3. **Kenar çubuğu:** free'de Tier grupları kategorinin kendi `tier`'ından gelir (boşsa
   `builtinTier(slug)`); grup içinde template sırası. Tier editörde seçilir (Faz 2 arayüz turu).
4. **Kart ekranı:** free'de yerleşik sabitler devre dışı (kapı burada eklenir; Faz 2'nin önizlemesi
   kendi çizimini kullanıyor, bkz. Faz 2 sonucu). Silinen alan
   gösterilmez. **Kartı kaydetmek şemada olmayan anahtarları silmemeli** (D17); bu doğrulanır,
   siliyorsa free yolda düzeltilir. Silinen kategorinin kartları görünmez (V5).
5. **Template güncellemesi (B1, B2):** dünya açılınca, free template'li dünyalar için template'in
   güncel hash'i dünyanınkiyle karşılaştırılır. Fark varsa mevcut diyalog canlandırılır:
   Güncelle / Yoksay / Bu dünya için bir daha gösterme. Kayıt `applyTemplateUpdate` ile yapılır.
   Template silinmişse hiçbir şey sorulmaz (V2). Yerleşik dünyalarda bu kontrol **çalışmaz**.
6. **Free dünyada kapalı olanlar:** yeni karakter (Faz 6'ya kadar, açıklamalı), "online yap"
   (V21, açıklamalı), kural ayarları diyaloğu (`RuleConfigDialog`).
7. **`.dmtz`:** free dünya dışa aktarılıp içe aktarılır. Template dosyaya girmez; içe aktarılan
   dünya kendi kopyasıyla açılır. Template olmadığı için güncelleme sorulmaz.

**Dokunulan yerler:** [worlds_tab.dart](../../flutter_app/lib/presentation/screens/hub/worlds_tab.dart),
[world_repository_impl.dart](../../flutter_app/lib/data/repositories/world_repository_impl.dart),
[srd_core_bootstrap.dart](../../flutter_app/lib/application/services/srd_core_bootstrap.dart),
[campaign_provider.dart](../../flutter_app/lib/application/providers/campaign_provider.dart),
[entity_sidebar.dart](../../flutter_app/lib/presentation/widgets/entity_sidebar.dart),
[entity_card.dart](../../flutter_app/lib/presentation/screens/database/entity_card.dart),
[save_sync_indicator.dart](../../flutter_app/lib/presentation/widgets/save_sync_indicator.dart)
("online yap"), [main_screen.dart](../../flutter_app/lib/presentation/screens/main_screen.dart),
yeni değişiklik kontrolü servisi.

**Kapsam dışı:** karakter, paket oluşturma, yeni birleşik tarzlar, free encounter ayarları.
Encounter bu fazda kopyanın bugünkü `encounterConfig`'iyle olduğu gibi çalışır (§8, Y5).

**Otomatik testler:** değişiklik kontrolü (free'de fark → istem; aynı → yok; yerleşik → hiç
çalışmaz; template silinmiş → yok); bilinmeyen anahtarların kayıtta korunması; SRD soyu kapısı
(kopya → SRD kurulur; boş template → kurulmaz); `_overlayMissingBuiltinCategories`'in free'de
çalışmaması.

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E3.1 | "SRD kopyam" ile, "SRD içeriğini ekle" açık, "Deneme" dünyasını kur. | Dünya açılır. |
| E3.2 | Kenar çubuğu. | Template sırasıyla düz liste; Faz 2'de eklenen "Fraksiyon" var. |
| E3.3 | Fireball, Goblin ve Fighter kartlarını aç. | SRD verisi görünür; Faz 2'deki düzen uygulanmış. Eski SRD tipleri bugünkü gibi çizilir. |
| E3.4 | Bir "Fraksiyon" kartı oluştur, alanlarını doldur. | Kalıcı. |
| E3.5 | Template'te Fraksiyon'un bir alanını sil. Dünyayı aç. | "Template güncellendi" diyaloğu çıkar. |
| E3.6 | **Güncelle.** | Alan kartta görünmüyor. |
| E3.7 | Alanı aynı etiketle geri ekle, dünyayı aç, güncelle. | Eski değer geri gelir (D17). |
| E3.8 | Template'te bir değişiklik yap, dünyayı aç, **Yoksay**. Dünyayı kapatıp yeniden aç. | Aynı değişiklik için bir daha sorulmaz. Yeni bir değişiklikte yine sorulur. |
| E3.9 | Yeni karakter oluşturmayı ve "online yap"ı dene. | İkisi de kapalı ve nedeni yazıyor. |
| E3.10 | "Deneme" dünyasını `.dmtz` olarak dışa aktar, kopya olarak içe aktar, aç. | Aynı düzen ve kartlarla açılır. |
| E3.11 | Boş template'le dünya kur. | "SRD içeriğini ekle" çıkmaz; sadece oyuncu kartı kategorisi var. |
| E3.12 | R turu + yerleşik dünyayı birkaç kez açıp kapat. | Yerleşik dünyada güncelleme diyaloğu **hiç** çıkmıyor. |

**Çıkış kriteri:** DESIGN §19 Faz 1'in çıkış kriterinin dünya kısmı: kullanıcı SRD'yi kopyalar,
düzenler, bu template'le dünya kurar; SRD kartları kopyada doğru görünür; yerleşik dünyalar
değişmeden çalışır.

**Faz 3 sonucu** (2026-10-11, Windows; kapandı):

- **Yapılanlar:**
  - Dünya oluşturma diyaloğu kendi şablonlarını da listeler. SRD soyundaki şablonda "SRD içeriğini
    ekle" çıkar; açıksa SRD paketi bağlanır, açılıştaki kendini onarma da bağı korur
    ([world_repository_impl.dart](../../flutter_app/lib/data/repositories/world_repository_impl.dart):
    `isSrdLineage`, açılışta şemadaki `freeRootId`). Boş şablonda çıkmaz.
    `_overlayMissingBuiltinCategories` yalnız yerleşik kimlikte çalıştığı için free dünyada zaten
    çalışmıyordu; testle sabitlendi.
  - Kenar çubuğu: free'de Tier kategorinin `tier`'ından (boşsa `builtinTier`); filtre ve "yeni
    kart" diyaloglarında grup içinde şablon sırası (yerleşikte alfabetik kalır).
  - Kart ekranı: free'de `_shouldCenterGroup` ve slug'a bağlı alt başlık (büyü seviyesi, canavar
    boyutu…) kapalı; alt başlık kategori adı. Alt başlık, silinen bir alanın verisini
    gösterebilirdi (D17). Kart kaydı şemada olmayan anahtarları silmiyor: `_updateField` kartın
    bütün alanlarını kopyalıyor, depo `attributes`'ı olduğu gibi yazıyor (testle sabitlendi).
  - Silinen kategorinin kartları (V5) `visibleEntityProvider`'da süzülüyor
    (`withoutDeletedCategories`); veri silinmiyor, kategori geri eklenince kartlar görünür.
  - **Bulgu:** `worldSchemaProvider` her açılışta dört eski yerleşik yamayı uyguluyor.
    `_migrateWorldmapAllowedSections` editörde "Dünya haritası" kapatılan kategoriyi geri açardı,
    `_migrateLocationMapFields` Location'dan silinen harita alanlarını geri eklerdi. Free şemada
    dördü de atlanıyor.
  - Şablon güncellemesi:
    [template_update_dialog.dart](../../flutter_app/lib/presentation/dialogs/template_update_dialog.dart)
    dünya yüklemesi bitince main screen'den çalışır. Hub artık yükleme bitmeden `/main`'e geçtiği
    için eski "hub'da yükle, sonra sor" akışı çalışmazdı. Karşılaştırma dünyanın kendi kopyasıyla,
    içerikten yapılır (`freeTemplateContentHash`: etiket ve kapak hariç, Faz 1 notu). Güncelle /
    Yoksay / "Bu dünya için bir daha gösterme" mevcut `applyTemplateUpdate` /
    `dismissTemplateUpdate` / `muteTemplateUpdates` ile. Worlds sekmesindeki ölü diyalog silindi.
  - Free dünyada kapalı: karakter ekleme (dünya içindeki "+" pasif, ipucunda nedeni yazıyor;
    sihirbazın dünya listesinde free dünya yok, açık dünya free ise kendiliğinden seçilmiyor), çok
    oyunculu (iki giriş de `turnMultiplayerOn`'dan geçiyor, orada nedeni yazan bildirim çıkar),
    kural ayarları (düğme gizli), dünya ayarlarındaki marketplace paneli (K6).
  - `.dmtz`: kod değişikliği gerekmedi. Dünya gövdesi şemayı taşıyor; şablonun olmadığı başka bir
    veri kökünde aynı şema ve SRD kartlarıyla açılıyor, güncelleme sorulmuyor (testle).
- **Roadmap'ten sapmalar:**
  - Madde 6: "yeni karakter" ile birlikte "mevcut karakteri içe aktar" da kapandı (aynı "+"
    menüsü): yerleşik kağıtlı bir karakter free dünyaya bağlanmasın. Marketplace paneli de kapandı
    (K6 gereği; maddede yazmıyordu).
  - Madde 5: diyalogda değişiklik listesi yok. `computeWorldSchemaDiff` İngilizce sabit metin
    üretiyor ve alanları etiketle eşleştiriyor (K7).
  - Madde 5: diyalog hub'da değil main screen'de (yükleme akışı değişmiş).
- **Otomatik kapı:** G1 boş · G2 yeşil · G3 yeşil · G4 32 info (temel çizgiyle aynı) · G5
  `free_template_test` 14 (+ güncelleme kontrolü 5, V5 süzgeci 1), `world_free_template_test` 5
  (SRD soyu, SRD kapalı, boş şablon, silinen kategori geri gelmez, şemada olmayan anahtar kalır),
  `template_archive_test` 2 (+ free dünya `.dmtz` gidiş-dönüşü) yeşil · G6 1757 geçti (Faz 2'deki 1745 + 12 yeni);
  kırmızılar temel çizgideki 3 testle aynı.
- **Elle kontrol:** E3.1–E3.12.
- **Bilinen sınırlar:**
  - Karakter ekleme yalnız ipucuyla açıklanıyor (telefonda uzun basınca görünür); çok oyunculu
    düğmesi görünür kalıyor, basınca nedenini söylüyor.
  - Kenar çubuğunun "kategoriye göre sırala" modu slug'a göre, şablon sırasına göre değil.
  - Açık bir dünyanın şablonu düzenlenirse soru dünya bir sonraki açılışında gelir.

---

### Faz 4 — Tablo, Stat tablosu ve hazır içerikler

**Amaç:** Skill, saving throw, duyular gibi "satır listesi" alanlarının tek bir genel tarzla
(Tablo), statların hesap yapan tek tarzla (Stat tablosu) kurulması; bunların hazır içerikle
birden fazla kategoriye bağlı eklenmesi.

**Onay gereken varsayımlar:** V6 (hazır içerik tek alan ya da grup), V7 (silinirse bağlılar
bağımsızlaşır), V8 (bir kategoriye bir kez).

**Yapılacaklar:**

1. **Tablo tarzı** (DESIGN §8.1): kolon türleri (yazı, sayı, onay, seçim, zar, kart bağlantısı);
   sabit ya da serbest satırlar; sabit satırlarda template hücreleri kartta salt okunur.
   Editörde kolon ve satır ayarları.
2. **Stat tablosu** (DESIGN §8.2): etiketler, temel değer, adım, "değiştiriciyi göster".
   Değiştirici = ⌊(değer − temel) ÷ adım⌋, **aşağı** yuvarlanır. Yerleşik stat bloğunun yuvarlama
   hatası (DESIGN §8.2) bu fazda **düzeltilmez**.
3. **Hazır içerikler** (DESIGN §9): editörün 2. bölümü. Oluştur, bağlı ekle, bağı kopar,
   kopyala, sil. Bağlı alanlar sadece yapıyı paylaşır; kart değerleri bağlı değildir.
4. **SRD kopyası dönüştürücüsü (v2):** §6'da Faz 4 satırları. Skill tablosu, Saving throw tablosu
   ve Stat tablosu hazır içerikleri kopyayla birlikte gelir ve ilgili kategorilere bağlıdır.
5. **SRD verisi okuyucuları** (DESIGN §16.3): SRD paketinin bugünkü veri şekilleri (ör.
   `proficiencyTable` değerleri, `rangedSenseList` satırları, ekipman seçimleri) yeni tarzlarda
   okunurken dönüştürülür. Paket verisi değişmez (K1).

**Dokunulan yerler:** [field_schema.dart](../../flutter_app/lib/domain/entities/schema/field_schema.dart)
(yeni `FieldType` değerleri, belgelenmiş değer şekilleriyle),
[field_widget_factory.dart](../../flutter_app/lib/presentation/widgets/field_widgets/field_widget_factory.dart)
/ [structured_list_field_widgets.dart](../../flutter_app/lib/presentation/widgets/field_widgets/structured_list_field_widgets.dart),
editör, dönüştürücü, yeni okuyucular.

**Faz başı kararları (2026-10-11, kullanıcı):**

- **Toplam hesaplanır (DESIGN D32, İ3-e).** Skill / Saving throw tablosunun stat kolonu karttaki
  stat tablosunun etiketlerini alır; template satır başına varsayılanı yazar, kart satır satır
  değiştirebilir. Toplam = stat değiştiricisi + toplama eklenen sayılar + işaretli kutu başına
  karttaki seçilen sayı alanı (SRD'de Proficiency Bonus). E4.2'deki "stat salt okunur" bu yüzden
  "stat varsayılan, kartta değiştirilebilir" olur.
  - *Revize (2026-10-11, 4a elle kontrolü, kullanıcı):* skill / save ayrı bir tarz olur
    (**Yetenek tablosu**), kategorideki stat tablosunu okur, SRD'deki gibi görünür ve çalışır. Genel
    Tablo'dan stat ve toplam kolonları çıkar; tablo toplamla ilgili değildir.
- **Faz ikiye bölünür.** 4a: Tablo, Stat tablosu, editör ayarları, SRD kopyası v2 ve SRD
  okuyucuları (madde 1, 2, 4, 5). 4b: hazır içerikler (madde 3); SRD'nin Skill / Save / Stat
  alanları 4b'de hazır içeriğe bağlanır. E4.6 ve E4.7 4b'nin; geri kalan E maddeleri 4a'nın.
- **V6 daraltıldı:** Faz 4'te hazır içerik yalnız tek alan; grup hazır içeriği ilk gerektiği
  Faz 6'da (`combat_stats` bölünürken). V7 ve V8 onaylı.

**Kapsam dışı:** Kaynak, Seviye tablosu, Kaynak verme; karakter kağıdı.

**Otomatik testler:** stat hesabı (DESIGN §8.2'deki iki satırlık tablo birebir); tablo değer
şekli okuma / yazma; hazır içerik bağı (yapı değişince bütün bağlılar güncellenir, değerler
korunur; bağı kopar; sil → bağımsız kopyalar); SRD okuyucuları (gerçek SRD satırlarıyla örnek
testler); dönüştürücü v2.

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E4.1 | SRD'yi **yeniden kopyala** (§6), adını "SRD kopyam 2" yap, onunla dünya kur. | — |
| E4.2 | Editörde Oyuncu kartı → Skills. | Yetenek tablosu; "Hazır içerik: Skills" ve "Bağı kopar" görünür; 18 satır hazır içerikte (Hazır içerikler › Skills) düzenlenir. Kartta skill adı salt okunur, stat varsayılan ama değiştirilebilir. |
| E4.3 | Goblin kartı. | Skills, saving throw ve duyular SRD verisiyle dolu; statlar ve değiştiricileri doğru. |
| E4.4 | Bir NPC kartında Stat tablosuna 7, 9, 10, 15 gir. | −2, −1, 0, +2. |
| E4.5 | Editörde stat tablosunu temel 0, adım 3 yap; aynı kartta 7 ve 20'ye bak. | +2 ve +6. |
| E4.6 | "Skill tablosu" hazır içeriğine "Denizcilik" satırı ekle; dünyayı güncelle. | Oyuncu kartı, NPC ve canavarın hepsinde yeni satır var; mevcut işaretler duruyor. |
| E4.7 | NPC'deki Skills alanında **Bağı kopar**, sonra hazır içeriğe bir satır daha ekle. | NPC değişmez, diğerleri değişir. |
| E4.8 | Bir tür ya da feat kartında stat bonusu tablosu. | Değiştirici kapalı; sadece değerler. |
| E4.9 | Fighter kartında başlangıç ekipmanı. | Okunaklı metin olarak görünür. |
| E4.10 | Serbest satırlı bir "Duyular" tablosuna satır ekle ve sil. | Çalışır, kalıcı. |
| E4.11 | Telefon görünümünde geniş bir tabloya bak. | Okunur; yatay taşma kontrollü. |
| E4.12 | R turu. | Yerleşik stat bloğu eskisi gibi (yuvarlama hatası dahil). |

**Çıkış kriteri:** SRD kopyasındaki bütün tablo ve stat alanları yeni tarzlarla çalışır; hazır
içerik bağı doğru.

**Faz 4a sonucu** (2026-10-11, Windows; elle kontrol bekliyor):

- **Yapılanlar:**
  - İki yeni tarz: `FieldType.table` (Tablo) ve `FieldType.statTable` (Stat tablosu). Ayarları
    `FieldSchema.styleConfig`'te (null olabilir, `includeIfNull: false`; K2, koruma hash'i aynı).
    Değer şekilleri enum değerlerinin belge yorumunda.
  - [free_field_styles.dart](../../flutter_app/lib/domain/services/free_field_styles.dart) (saf):
    değiştirici ⌊(değer − temel) ÷ adım⌋, aşağı yuvarlanır; kolon türleri yazı, sayı, onay, seçim,
    zar, kart bağlantısı, **stat**, **toplam**; sabit satırlar şablondan gelir, kart yalnız şablondan
    farklı hücreleri saklar (şablon varsayılanı sonradan değişirse dokunulmamış kartlara ulaşır);
    şablondan silinen satırın kart verisi gizli kalır, satır geri gelince döner (D17). Toplam
    D32'deki gibi; kartta skor yoksa "—".
  - SRD okuyucuları: kart verisi değişmeden okunur. Proficiency tablosunun `{rows: [...]}` şekli
    satır adıyla (kilitli hücre) eşleşir; seviye tablolarının `{seviye: değer}` haritası
    Seviye · Değer satırları olur; duyu ve büyü etkisi satırları olduğu gibi (kolon anahtarları
    SRD'nin satır anahtarları). Başlangıç ekipmanı, oyuncu seçimleri ve alt tür seçenekleri
    markdown olarak gösterilir (kart düzenlenirse metin olarak kaydedilir).
  - SRD kopyası v2 ([free_template.dart](../../flutter_app/lib/domain/services/free_template.dart)):
    §6'daki Faz 4 satırları. `stat_block` → Stat tablosu (STR–CHA, temel 10, adım 2),
    `ability_bonuses` → değiştiricisiz; skill / save → sabit satırlı Tablo (Skill/Save kilitli,
    Ability = stat kolonu, Proficient / Expertise / Misc toplama eklenir, Total kategorinin
    `proficiency_bonus`'unu ekler); seviye tabloları (`class_levels` hariç, Faz 6), duyular, büyü
    etkileri → serbest satırlı Tablo; üç yapılı liste → Markdown.
  - Kart: [free_style_field_widgets.dart](../../flutter_app/lib/presentation/widgets/field_widgets/free_style_field_widgets.dart).
    Stat tablosu sarılarak dizilir; tablo sığarsa yazı / bağlantı kolonları genişler, sığmazsa
    (telefon) yana kayar. Serbest satırlarda + ve satır sil. `FieldWidgetFactory` iki tarzı ve
    markdown okuyucusunu çağırır; kart, önizleme ve kart önizleme diyaloğu kategorinin alanlarını
    verir (`categoryFields`).
  - Editör: iki tarz palette ve telefonun tarz sayfasında. Stat tablosu ayarları: etiketler
    (ekle, yeniden adlandır, yukarı / aşağı, sil; anahtar ilk etiketten bir kez), temel, adım,
    değiştiriciyi göster, canlı örnek satırı (`9 → −1 · 10 → +0 · 12 → +1`). Tablo ayarları:
    serbest / sabit satır, kolon kutuları (etiket, tür, seçenekler, hedefler, stat kaynağı,
    toplamın bonus alanı, toplama eklenir, şablondan), şablon satırları editörü.
- **Roadmap'ten sapmalar:**
  - Faz 4a / 4b bölünmesi ve D32 (faz başı kararları).
  - `spellEffectList`'in `condition_refs` ve `scaling_dice` kolonu yok (DESIGN §16.2'deki beş
    kolon); SRD'de bu alanda veri yok, kartta saklı kalır.
  - Tablo hücresine dokununca zar atılmıyor (yerleşik tablo atıyor).
- **Otomatik kapı:** G1 boş · G2 yeşil · G3 yeşil · G4 32 info (temel çizgiyle aynı) · G5
  `free_field_styles_test` 15 (DESIGN §8.2'nin iki satırı birebir; gerçek SRD Goblin Warrior,
  Bard, Fireball, Fighter satırları), `free_field_styles_widget_test` 8 (kart telefon / desktop,
  skor değişince toplam, E4.4, serbest satır ekle / sil, başlangıç ekipmanı; editörde E4.5, sabit
  satırlı tablo, telefonda SRD Skills), `free_template_test` (SRD kopyası v2: yalnız tarz
  değişir), `template_edit_test` 13, `free_template_editor_test` 20 · G6 1781 geçti (Faz 3'teki 1757 +
  24 yeni); kırmızılar temel çizgideki 3 testle aynı.
- **Tam çalıştırmanın yakaladığı:** Faz 3'ün `template_archive_test` "free dünya şablonsuz taşınır"
  testi zamanlamaya bağlı düşüyordu: dünya içe aktarılırken UI durumunun gecikmeli kaydı
  SharedPreferences'a gidiyor, testte mock yoktu. `setUp`'a `setMockInitialValues` eklendi.
- **Elle kontrol (4a):** E4.1, E4.2 ("bağlı olduğu hazır içerik" hariç; stat kartta
  değiştirilebilir), E4.3, E4.4, E4.5, E4.8, E4.9, E4.10, E4.11, E4.12. E4.6 ve E4.7 4b'de.
- **Bilinen sınırlar:**
  - TR okuma modunda genel tablo hücreleri ve markdown'a çevrilen SRD listeleri İngilizce;
    etiketler şablon verisi olduğu için editörde değiştirilebilir (DESIGN §16.5). (Yetenek
    tablosunda SRD skill adları çevrilir; 4a düzeltmesi.)
  - Faz 1–3'te alınmış SRD kopyaları eski tipleriyle kalır (§6 notu); E4.1 "yeniden kopyala".
  - Tablonun şablon satırları editöründe kart bağlantısı hücresi yok (bağlantılar kartın).
  - Kolon silinince kartlardaki o kolonun verisi gizli kalır; kolon silme onay sormuyor.

**Faz 4a elle kontrol bulgusu ve düzeltmesi** (2026-10-11, kullanıcı):

- **Bulgu:** skill / save tablosu genel Tablo'nun stat ve toplam kolonlarıyla kurulmuştu; kullanıcı
  bunun ayrı, özel bir tablo olmasını, kategorideki stat tablosunu kullanmasını, SRD template'teki
  gibi görünüp çalışmasını; genel Tablo'nun ise toplamla ilgisi olmamasını istedi (D32 revize).
- **Düzeltme:**
  - Yeni tarz **Yetenek tablosu** (`FieldType.skillTable`): ayarları satırlar (ad, varsayılan stat),
    statların kaynağı (kategorinin stat tablosu; varsayılan ilki), "bir işaret şunu ekler" (sayı alanı).
    Kartta yerleşik SRD tablosunun görünüşü: Yetkin / Uzman noktaları (aynı `ProficiencyDot`), ad,
    stat (dokununca başka stat seçilir), Ek, Toplam, başlıkta bonus alanı; satıra dokununca d20 +
    toplam atılır ve oturum günlüğüne yazılır. SRD skill adları uygulama dilinde gösterilir.
  - Genel Tablo'dan `stat` / `total` kolon türleri ve "toplama eklenir" / bonus ayarları çıktı.
  - SRD kopyası: skill / save alanları Yetenek tablosu olur. Şablonda adı değiştirilen SRD satırı kart
    verisini kimliğiyle (SRD adı) bulmaya devam eder.

**Faz 4b sonucu** (2026-10-11, Windows; commit'lendi, 4a düzeltmesiyle birlikte elle kontrol **ertelendi** — kullanıcı
sonra yapacak, 2026-10-12):

- **Yapılanlar:**
  - Model: `WorldSchema.presets` (hazır içerikler, her biri bir `FieldSchema`) ve
    `FieldSchema.presetId` (bağlı alan). İkisi de null olabilir, `includeIfNull: false` (K2).
  - Saf fonksiyonlar ([template_edit.dart](../../flutter_app/lib/domain/services/template_edit.dart)):
    oluştur, bağlı ekle (kategoriye bir kez, aynı anahtarlı alanın üstüne değil — V8), hazır içerik
    değişince bütün bağlıları güncelle (etiket, tarz, ayarlar; kart değerleri bağlı değil), bağı kopar,
    kopyala (D21), sil (bağlılar bağımsız kopya olur — V7), "hazır içerik olarak kaydet".
  - Editör: sol panelde **Hazır içerikler** bölümü (+, liste, kaç kategoride kullanıldığı). Hazır
    içerik formu: etiket, anahtar, tarza özel ayarlar, kullanıldığı kategoriler, Kopyala, Sil (onay
    sorar). Palet şeridinde tarzlardan sonra hazır içerikler (tıkla ya da sürükle → bağlı alan);
    telefonun "+ Ekle" sayfasında "Hazır içerikler" başlığı. Bağlı alanın formunda "Hazır içerik:
    Skills" kutusu ve **Bağı kopar**; yapısı orada değil hazır içerikte düzenlenir. Bağlı alan tuvalde
    yer imi işaretiyle görünür. Bağsız alanlarda **Hazır içerik olarak kaydet**.
  - SRD kopyası: Skills, Saving Throws ve Ability Scores hazır içerikleri gelir; oyuncu, NPC,
    canavar ve hayvanın skill / save / `stat_block` alanları bunlara bağlıdır (`ability_bonuses`
    değil).
- **Roadmap'ten sapmalar:**
  - D33: bağlı alanın anahtarı kendisinindir. SRD'de canavar `skill_bonuses`, oyuncu `skills`
    anahtarını kullanıyor; anahtar hazır içerikten gelseydi SRD kartlarının verisi okunmazdı. Hazır
    içerikten yeni eklenen alan hazır içeriğin anahtarını alır (V8 aynen).
  - Hazır içeriğin tarzı oluşturulurken seçilir, sonra değişmez (anahtar ve kart verisi uyumu).
  - Telefonun "+ Ekle" sayfasında sekme yerine iki başlık (DESIGN §7.6).
  - Bağlı alanın formunda "hazır içeriği düzenle" düğmesi yok; hazır içerik sol panelden açılır.
- **Otomatik kapı:** G1 boş · G2 yeşil · G3 yeşil · G4 32 info (temel çizgiyle aynı) · G5
  `free_field_styles_test` 16 (yeniden adlandırılan SRD satırı, skill toplamları),
  `template_edit_test` 18 (+5 hazır içerik: değişiklik bütün bağlılara gider ve kart işaretleri
  durur — E4.6, bağı kopar, sil — V7, kategoriye bir kez — V8, hazır içerik olarak kaydet /
  kopyala), `free_template_test` 15 (SRD hazır içerikleri ve bağları),
  `free_field_styles_widget_test` 12 (skill satırında işaret ve stat değişimi; editörde E4.6,
  E4.7, yeni hazır içerik + V8 uyarısı; telefonda SRD Skills'in hazır içerik kutusu),
  `free_template_editor_test`, `templates_tab_layout_test`, `template_archive_test`,
  `world_free_template_test` yeşil · G6 1792 geçti (4a'daki 1781 + 11 yeni); kırmızılar temel
  çizgideki 3 testle aynı.
- **Elle kontrol (4a düzeltmesi + 4b):** önce **SRD'yi yeniden kopyala** (E4.1; eski kopyalarda
  skill / save genel tablo olarak kalır).
  - E4.2 (yeni beklenen), E4.3 (Goblin: skill toplamları SRD tablosu gibi; satıra dokununca zar),
    E4.6, E4.7.
  - E4b.1: Kartta bir skill satırında Yetkin noktasına dokun → toplam PB kadar artar; stat
    harfine dokunup başka stat seç → toplam ona göre değişir.
  - E4b.2: Boş template'te Hazır içerikler › + → Yetenek tablosu → "Skills"; satır ekle; paletten
    oyuncu kartına ekle; aynı kategoriye ikinci kez eklemeye çalış → uyarı.
  - E4b.3: Bir hazır içeriği Kopyala, sonra Sil → bağlı alanlar kalır, "Hazır içerik" kutusu
    kaybolur.
  - E4b.4: Genel Tablo ayarlarında kolon türleri: yazı, sayı, onay, seçim, zar, kart bağlantısı (stat
    ve toplam yok).
  - R turu (E4.12).
- **Bilinen sınırlar:**
  - Grup hazır içeriği yok (V6 daraltıldı, Faz 6).
  - Yetenek tablosunda statların kaynağı / bonus alanı hazır içerikte, onu kullanan kategorilerin
    alanlarından seçilir; bir kategoride o anahtarda alan yoksa toplam "—", başlıkta bonus görünmez.
  - Kaydetme tuşu yok, değişiklik bütün bağlı alanlara hemen gider; dünyalar banner'la günceller
    (Faz 3).

---

### Faz 5 — Paketler

**Amaç:** Free template'le paket oluşturulsun, paket kendi template'iyle açılsın; farklı
template'li dünyaya kurarken eşleşmeyenler anahtarla bulunup kullanıcı uyarılsın (D11).

**Yapılacaklar:**

1. **Paket oluşturma:** free template'ler listeye girer; paket template'in kopyasını saklar.
2. **Açılış** ([package_repository_impl.dart:461](../../flutter_app/lib/data/repositories/package_repository_impl.dart#L461)):
   kayıtlı template kimliği yerleşikse bugünkü yol aynen; değilse kayıtlı şema kullanılır.
3. **Uyumluluk** ([template_compatibility_service.dart](../../flutter_app/lib/application/services/template_compatibility_service.dart)):
   taraflardan biri free ise kategoriler slug'la, alanlar **anahtarla** eşleşir. İki taraf da
   yerleşikse bugünkü kod yolu aynen (§8, Y4).
4. **Uyarı ekranı** ([import_package_dialog.dart](../../flutter_app/lib/presentation/dialogs/import_package_dialog.dart)):
   eşleşmeyen kategoriler ve alanlar listelenir; "Vazgeç" / "Yine de kur".
5. **Paketin template güncellemesi:** pakette de Faz 3'teki kontrol çalışır
   (`package_provider.applyTemplateUpdate` mevcut).
6. **`.dmtz`:** free template'li paket dışa / içe aktarılır.

**Kapsam dışı:** marketplace'e free paket yayınlamak (K6).

**Otomatik testler:** paket açılışı (yerleşik → yerleşik şema; free → kayıtlı şema); anahtar
bazlı uyumluluk (etiketi değişmiş alan eşleşir; eksik kategori / alan listelenir); yerleşik ↔
yerleşik sonuçlarının değişmediği.

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E5.1 | "SRD kopyam 2" ile "Paketim" oluştur; bir Fraksiyon ve bir NPC kartı ekle. | Paket kopyanın düzeniyle açılır. |
| E5.2 | Uygulamayı kapat, aç, paketi aç. | Hâlâ kendi düzeniyle. |
| E5.3 | Paketi "SRD kopyam 2" dünyasına kur. | Uyarı yok; kartlar görünür. |
| E5.4 | Boş template'ten bir template kur, onunla dünya aç, paketi oraya kurmayı dene. | Uyarı ekranı eşleşmeyen kategori ve alanları listeler. |
| E5.5 | **Yine de kur.** | Eşleşen kartlar görünür; eşleşmeyen alanlar görünmez. |
| E5.6 | Template'te bir alanın etiketini değiştir, paketi tekrar o template'in dünyasına kur. | Alan yine eşleşir (anahtar aynı). |
| E5.7 | Paketi `.dmtz` ile dışa aktar, içe aktar. | Kendi düzeniyle açılır. |
| E5.8 | Yerleşik bir paketi aç ve yerleşik dünyaya kur. | Bugünkü gibi, aynı uyarılarla. |
| E5.9 | R turu (özellikle R6). | Faz 0 referansıyla aynı. |

**Çıkış kriteri:** DESIGN §19 Faz 1 tamamen bitti.

**Faz 5 sonucu** (2026-10-12, Linux; elle kontrol bekliyor):

- **Yapılanlar:**
  - Paket oluşturma diyaloğu kendi şablonlarını da listeler.
  - Açılış ([package_repository_impl.dart](../../flutter_app/lib/data/repositories/package_repository_impl.dart)):
    free şablonlu paket şablonun tamamını `packages.state_json` içinde `_world_schema` anahtarıyla
    taşır (dünyanın `settings_json._world_schema`'sı gibi; `package_schemas`'ta `freeRootId` /
    `presets` kolonu yok, K5) ve onunla açılır. Diğer bütün paketler bugünkü gibi canlı yerleşik
    şemayla. `world_schema`'sız kayıt (sadece metadata) şablonu silmez; kopya ve çöp kutusu
    `load` / `save` üzerinden taşır.
  - Uyumluluk ([template_compatibility_service.dart](../../flutter_app/lib/application/services/template_compatibility_service.dart)):
    taraflardan biri free ise kategori slug'la, alan anahtarla; sadece paketin kartı olan
    kategoriler sayılır. Eşleşmeyen yoksa uyarısız kurulur; varsa kartta liste ve kurarken
    **Farklı şablon** ekranı: dünyada olmayan kategoriler (kartları görünmez), alanlar (verileri
    görünmez), "veri pakette kalır" notu; **Vazgeç / Yine de kur**. Yerleşik ↔ yerleşik eski yolda
    (Y4). Kurulum kodu değişmedi: zaten slug ve alanları olduğu gibi kopyalıyor.
  - Paket açılınca Faz 3'ün şablon güncellemesi sorulur (paketin `ProviderScope`'u içinde aynı
    `offerTemplateUpdate`). Free pakette kural ayarları gizli.
  - K6: free pakette "online yap" yerine "bu cihazda kalır" yazısı (hub ayarları ve Save & Sync,
    ikisi de `PackageOnlineRow`); marketplace paneli gizli.
  - `.dmtz`: free paket şablonuyla taşınır (kod değişmedi, repository üzerinden).
- **Roadmap'ten sapmalar:**
  - Uyarı ekranı ayrı bir diyalog; eski "Zorla" diyaloğunun metni ("ciddi veri kaybı") D11'e uymadığı
    için free yolda kullanılmadı.
  - Bulunan hata: `package_schemas` satırının kimliği şablonun `schemaId`'si, tablonun anahtarı
    yalnız `id`; aynı şablondan iki paket birbirinin satırını alıyordu (listede şablon adı boş
    kalırdı). Free pakette satır kimliği paket kimliği. Yerleşik paketlerde aynı durum var, dokunulmadı
    (satır açılışta zaten okunmuyor).
- **Otomatik kapı:** G1 boş · G2 yeşil · G3 yeşil · G4 32 info (temel çizgiyle aynı) · G5
  `package_free_template_test` 5 (yerleşik → yerleşik şema; free → kendi şeması ve hazır içerikleri;
  kaydet / metadata kaydı / kopya; iki paket aynı şablondan; `isFreePackageState`),
  `template_compatibility_free_test` 5 (aynı template; E5.6 etiket değişse de eşleşir; eksik
  kategori / alan ve kartsız kategori; yerleşik → free anahtarla; yerleşik ↔ yerleşik eski yol),
  `template_archive_test` +1 (E5.7), paket testleri (`package_save_ids`, `world_package_installer`,
  `cloud_push_pump_package`, `pack_install_roundtrip`, `package_link_service`) yeşil · G6 1804 geçti (4b'deki 1792 + 12 yeni); kırmızılar temel çizgideki 3 testle aynı.
- **Elle kontrol:** E5.1–E5.9. E5.4'te uyarı sadece paketin kartı olan kategorileri listeler.
- **Bilinen sınırlar:**
  - Eşleşmeyen alanların listesi alan etiketleriyle; aynı anahtar farklı tarzdaysa (DESIGN §15.2
    "aynı anahtar, farklı şekil") listelenmez, alan boş görünür.
  - Uyarı listesi paketin şemasına göre; paketin şemasında olmayan bir kategoride kart varsa
    sayılmaz.

**Faz 4–5 elle kontrol bulguları ve düzeltmeleri** (2026-10-12, Linux; kullanıcı):

- T testleri tamam; P1'de bir hata görüldü, kalan P ve R kontrolleri kısmen yapıldı. Kullanıcı
  "genel olarak okey" dedi, fazlar kapandı.
- **Yetenek tablosu, stat seçilmemiş satır:** satır toplamsız kalıyor ve zar atılmıyordu. Artık
  stat seçilmemişse ya da kartta o statın değeri yoksa stat 0 sayılır; satır toplanır ve zar atar
  (D32'ye ek, kullanıcı kararı).
- **Yetenek tablosu, iki ayar (kullanıcı isteği):** "Kartta satır adı değiştirilebilir" (varsayılan
  kapalı; kartın adı satırın `label`'ında, şablondaki ad eşleşme için kalır) ve "Kartta stat
  değiştirilebilir" (varsayılan açık, bugünkü davranış). `styleConfig`'te `name_editable` /
  `stat_editable`, sadece varsayılandan farklıysa yazılır.
- **P1 — paket ekranı başlığı:** dar pencerede eylem düğmeleri başlığa 24 px bırakıyordu
  (RenderFlex taşması). Başlık daralınca ikon gizlenir, ad solar. Aynı logdaki üç hata
  (`TextEditingController` dispose sonrası, 99585 px taşma, `_dependents.isEmpty`) yeniden
  üretilemedi; tam hata bloğu gelirse bakılacak.
- **SRD paketlerde zorunlu değil (kullanıcı isteği):** paket ekranı SRD kartlarını her pakette
  referans olarak gösteriyordu. Paket oluştururken dünyadaki gibi "D&D 5e SRD içeriğini ekle"
  seçeneği çıkar (yerleşik template ve SRD soyu); kapalıysa paketin `state_json`'ına
  `_srdCoreOptOut: true` yazılır ve `packageReferenceOverlayProvider` SRD'yi katmaz (bağlı
  paketler yine görünür). Daha önce oluşturulan paketler SRD'yi göstermeye devam eder.
- **"SRD içeriğini ekle" varsayılan kapalı:** dünya ve paket oluştururken kutu artık işaretsiz
  gelir (kullanıcı isteği).
- **Otomatik kapı:** G4 32 info (temel çizgiyle aynı) · G5 `free_field_styles_test`,
  `free_field_styles_widget_test` (+1: stat'sız satır 0, iki ayar), `package_free_template_test`
  (+1: SRD'siz paket, seçim metadata kaydında korunur) yeşil · G6 1806 geçti (Faz 5'teki 1804 + 2 yeni); kırmızılar temel çizgideki 3 testle aynı.

---

### Faz 6 — Oyuncu kartı, karakter kağıdı, kaynak ve dinlenme

**Amaç:** Free dünyada karakter oluşturulsun, kağıt oyuncu kartının düzeniyle çizilsin; Kaynak
tarzı ve Kısa / Uzun dinlenme çalışsın.

**Kararlar (2026-10-12):** D34 (V14 yerine), D35 (V15 onaylı), D36 (V17, V19, V23 yerine).

**Yapılacaklar:**

1. **Oyuncu kartının özel alanları** (DESIGN §10.1, D34): Seviye ve Otomatik kaynaklar. Yeni
   template'te hazır gelir; silinebilir, tarzı değişmez, oyuncu kartında en fazla birer tane, yeri
   ve grubu serbest. Silinince paletin "Oyuncu kartı" bölümünden geri eklenir. Silerken onay
   sorulur (kullananların listesi Faz 7'de dolmaya başlar). Otomatik kaynaklar Faz 7'ye kadar boş
   görünür. Seviye yoksa kağıt başlığında seviye gösterilmez.
2. **Kaynak tarzı** (DESIGN §8.3): sayı ya da kutucuk görünümü; kısa ve uzun dinlenme için
   doldur / boşalt / dokunma; maks elle; mevcut +/− ya da yazarak.
3. **Savaş değerleri tarzı** (DESIGN §8.6, D36): mevcut `combatStats` tipi, free ayarları
   `styleConfig`'te. Zorunlu HP / Max HP (dinlenme davranışı Kaynak gibi); değer ekle / sil /
   sırala; tür Sayı, Zar ya da Kart listesi (en fazla bir); değer başına "encounter'da göster",
   genişlik, düzenlenebilir, +/−. Kategoride en fazla bir blok. Kart ve kağıtta widget'ı.
   Encounter ayarlarının bu bloktan okunması Faz 9'da.
4. **SRD kopyası dönüştürücüsü (v3):** §6'da Faz 6 satırları. Dinlenme ayarları DESIGN §12.3'teki
   örnek tabloya göre. Savaş değerleri hazır içeriği Oyuncu, NPC, Canavar, Hayvan'a bağlanır;
   anahtarlar `combat_stats` ve SRD alt anahtarları (`hp`, `max_hp`, `ac`, `initiative`, `xp`)
   aynı kalır. Okuyucular (DESIGN §16.3): canavarın düz alanları blokta; `speed` / `cr` metni
   sayıya.
5. **Karakter oluşturma:** free dünyada sihirbaz yok; boş kağıt (seviye 1, D35) açılır. Hub'daki
   Characters sekmesinden free template seçilirse de aynı.
6. **Free karakter kağıdı:** **ayrı ekran** (K3). Oyuncu kartı düzenini Faz 2–4'teki alan
   widget'larıyla çizer. Başlıkta Seviye, [Kısa dinlenme] ve [Uzun dinlenme]. [Seviye atla] Faz
   7'de, [Rehber] Faz 8'de gelir. Yerleşik parçalar (çözülen grant'ler, sınıf kaynak takipçisi,
   gizli alan davranışları) yoktur.
7. **Şemanın kaynağı:** free karakter, şemayı global listeden değil dünyanın kendi kopyasından
   okur (DESIGN §18).
8. **Dinlenme:** her kaynak alanına ve Savaş değerleri'nin HP'sine o butonun davranışını uygular,
   başka hiçbir şeye dokunmaz.

**Dokunulan yerler:** yeni free kağıt ekranı, [character_provider.dart](../../flutter_app/lib/application/providers/character_provider.dart)
(oluşturma dalı), Characters sekmesi, field widget'ları (Kaynak, Savaş değerleri), editör (özel alanlar, Savaş değerleri ayarları),
dönüştürücü. [character_editor_screen.dart](../../flutter_app/lib/presentation/screens/characters/character_editor_screen.dart)'e
sadece "free ise yeni ekrana git" kapısı eklenir.

**Kapsam dışı:** seviye atlama, verilen kartlar, otomatik kaynakların dolması, rehber, encounter
geri yazma, encounter kolonlarının Savaş değerleri'nden okunması (Faz 9), bağımlılık uyarıları
(Seviye tablosu / Kaynak verme Faz 7'de, encounter kategorisi Faz 9'da).

**Otomatik testler:** dinlenme davranışları (üç seçenek × iki buton, HP dahil); Kaynak değer
şekli; Savaş değerleri (HP / Max HP silinemez, izinli türler, en fazla bir kart listesi, değer şekli
yerleşik `combat_stats` ile aynı); dönüştürücü v3 (`combat_stats` → blok, canavar düz alanları,
`speed` / `cr` → sayı, slot → kaynak); özel alanların silinip geri eklenmesi ve ikinci kez
eklenememesi; free karakterin yerleşik sihirbaza düşmemesi.

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E6.1 | SRD'yi yeniden kopyala ("SRD kopyam 3"), onunla dünya kur. | — |
| E6.2 | Free dünyada **Yeni karakter**. | Sihirbaz yok; boş kağıt, seviye 1, oyuncu kartının düzeninde. |
| E6.3 | Adını, türünü, sınıfını (kart bağlantısı olarak) ve statlarını doldur. | Kalıcı; değiştiriciler doğru. |
| E6.4 | Savaş değerleri'nde HP'yi 31 / 38 yap; − ve + kullan. | Değer değişir; maksimum sabit. |
| E6.5 | **Kısa dinlenme.** | HP değişmez; Focus Points gibi "kısa: doldur" kaynakları dolar. |
| E6.6 | **Uzun dinlenme.** | HP 38 olur; Heroic Inspiration değişmez. |
| E6.7 | Editörde oyuncu kartına yeni bir Kaynak alanı ekle (kutucuk, uzun: doldur), dünyayı güncelle. | Kağıtta görünür; uzun dinlenmede dolar. |
| E6.8 | Editörde Seviye alanını başka gruba taşı, tarzını değiştirmeyi dene; sonra sil ve paletten geri ekle; ikinci bir Seviye eklemeyi dene. | Taşınır; tarzı değişmez; silerken onay sorulur; geri eklenir; ikincisi eklenemez. |
| E6.8b | Seviye silinmiş template'le dünya kur, karakter aç. | Kağıt açılır, başlıkta seviye yok, hata yok. |
| E6.8c | Editörde Savaş değerleri'ne "Hız" (Sayı) ekle, encounter'da göster'i kapat; HP'yi silmeyi ve bloğa Yazı türünde değer eklemeyi dene; ikinci bir Kart listesi eklemeyi dene. | Hız eklenir; HP silinmez; Yazı türü seçilemez; ikinci kart listesi eklenemez. |
| E6.8d | SRD kopyasıyla kurulan dünyada bir canavar (ör. Goblin Warrior) ve bir NPC kartını aç. | Canavarın bloğunda HP, AC, İnis. (`1d20+N`) SRD değerleriyle dolu; NPC'de Hız ve CR sayı olarak blok dışında. |
| E6.9 | Kağıdı telefon görünümünde ve Android'de kullan. | Butonlar erişilebilir; +/− tek elle rahat. |
| E6.10 | R turu (özellikle R2, R3, R4). | Yerleşik karakter, sihirbaz ve dinlenme aynen. |

**Çıkış kriteri:** DESIGN §19 Faz 2: free dünyada karakter oluşturulur, kağıt template düzeniyle
görünür, dinlenme kaynakları günceller.

---

### Faz 7 — Seviye sistemi

**Amaç:** Seviye tablosu ve kaynak verme ile karakter seviye atlasın; ayrı / beraber modlar,
verilen kartlar ve zincir çalışsın. DESIGN §11.9'daki Aria örneği baştan sona işlesin.

**Onay gereken varsayımlar:** V9, V10, V11, V12, V13, V24, V25.

**Yapılacaklar:**

1. **Seviye tablosu tarzı** (DESIGN §8.4; enum adı B6'ya göre yeni): Seviye · Yazı (markdown) ·
   Verilen kartlar (isteğe bağlı hedef listeyle). Kategoride en fazla bir tane (V9).
2. **Kaynak verme tarzı** (DESIGN §8.5): ad, açıklama, kısa / uzun davranışı, seviye → maks
   tablosu.
3. **Kategori ayarı:** seviye tablolu kategorilerde seviye modu Ayrı / Beraber.
   **Bağımlılık uyarısı** (DESIGN §10.1, D34): Seviye tablosu ya da Kaynak verme eklenirken oyuncu
   kartında Seviye / Otomatik kaynaklar yoksa editörde **[Ekle]**'li uyarı; silerken onay listesi
   bu kullanımları gösterir. Seviye yoksa [Seviye atla] çıkmaz.
4. **Karakter verisi** (DESIGN §10.3): kart seviyeleri, verilen kart etiketleri ("Savaşçı'dan ·
   seviye 2"), otomatik kaynakların mevcut değerleri.
5. **Seviye motoru:** saf ve durumsuz yeni bir domain fonksiyonu, **resolver değil** (K4).
   Girdisi karakter + dünya kartları, çıktısı ulaşılan satırlar, verilecek kartlar (V10 hedef
   kuralı, tekrar yok, zincir, döngü koruması), otomatik kaynak maksimumları (seviyeye eşit ya da
   küçük en yüksek satır; aynı adlıda büyük olan, V25) ve özet. DESIGN §11.3'teki "neyin
   seviyesi nereden gelir" kuralı burada uygulanır.
6. **Seviye atlama akışı** (DESIGN §11.4): her ayrı kategoriden bir kart seç ya da yeni ekle;
   tek kartlı kategori otomatik seçili, kartsız kategori atlanır (V13); özet ekranı.
7. **Kart ekleme** (DESIGN §11.5) ve **geri alma önerileri** (DESIGN §11.7, V12).
8. **Otomatik kaynaklar** alanı dolar; dinlenme onlara da uygulanır.
9. **Kart görünümünde** karakterin ulaştığı satırlar işaretlenir (DESIGN §11.8).
10. **SRD kopyası dönüştürücüsü (v4) + okuyucular** (DESIGN §16.3): §6'da Faz 7 satırları. Sınıf
    özelliklerindeki `granted_*_refs` → hedef listeler tablosu; kaynak havuzu formülleri →
    tablo ya da düz yazı. Varsayılan modlar: Sınıf ayrı, Alt sınıf ve Tür beraber.

**Dokunulan yerler:** [field_schema.dart](../../flutter_app/lib/domain/entities/schema/field_schema.dart),
yeni seviye motoru (`lib/domain/services/` altında), free kağıt ekranı, editör (kategori ayarı,
yeni tarzlar), dönüştürücü ve okuyucular.

**Kapsam dışı:** seviye atlama rehberi, DM'in kaynak düzenlemesi (D31), çok sınıflı birleşik
slot tablosu (V25).

**Otomatik testler:** Aria örneği (DESIGN §11.9) **birebir test** olarak; Rage tablosu (seviye 8
→ 4); ayrı kartın kendi kaynağının kart seviyesini izlemesi (Büyücü slotları); verilen kartın ana
seviyeyi izlemesi (Second Wind); hedef liste kuralları (V10'un üç durumu); A ↔ B döngüsü; tekrar
eklenmeme; beraber kategoriye sonradan eklenen kart (D10); bağımlılık uyarısı (Seviye yokken seviye
tablosu eklemek uyarı verir, [Ekle] alanı ekler); SRD okuyucuları (gerçek Fighter,
Wizard, Barbarian satırlarıyla).

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E7.1 | SRD'yi yeniden kopyala ("SRD kopyam 4"); editörde Sınıf = Ayrı, Alt sınıf = Beraber olduğunu gör. Dünya kur. | — |
| E7.2 | Aria'yı oluştur, Sınıf listesine **Fighter** ekle. | Özet ekranı: Second Wind ve Weapon Mastery eklendi; "HP: 10 + CON" okunacaklarda. |
| E7.3 | **Seviye atla.** | Fighter otomatik seçili; Action Surge eklendi. |
| E7.4 | Seviye atla, **Wizard** ekle. | Wizard 1'den başlar; 1. seviye slot = 2 otomatik kaynaklarda. |
| E7.5 | Seviye atla, Fighter'ı seç. | Fighter 3: "alt sınıf seç" okunacaklarda. |
| E7.6 | Alt sınıf listesine Champion ekle. | 1–4. satırlar işledi, özet çıktı. |
| E7.7 | Verilen bir kartın etiketine bak. | "Fighter'dan · seviye 2" gibi. |
| E7.8 | Wizard'ı listeden çıkar. | Wizard'dan gelen kartların çıkarılması önerilir; onaylayınca çıkar. |
| E7.9 | Ana seviyeyi elle düşür. | Artık ulaşılmayan satırlardan gelen kartların çıkarılması önerilir. |
| E7.10 | Bir Barbarian karakteri 8. seviyeye çıkar. | Rage maks 4; uzun dinlenmede dolar. |
| E7.11 | Fighter kartını kağıttan aç. | Ulaşılan satırlar işaretli. |
| E7.12 | Birbirini veren iki test kartı yaz (A → B, B → A), birini ekle. | Uygulama takılmaz; ikisi de bir kez eklenir. |
| E7.13 | Seviye atlama ve özet ekranlarını telefonda ve Android'de kullan. | Rahat ve okunaklı. |
| E7.14 | R turu (özellikle R3, R4). | Yerleşik seviye atlama aynen. |

**Çıkış kriteri:** DESIGN §19 Faz 3: Aria örneği baştan sona çalışır.

---

### Faz 8 — Karakter oluşturma rehberi

**Amaç:** Template sahibi adım adım bir rehber yazsın; oyuncu boş kağıttan rehberle karakter
oluştursun (D24).

**Onay gereken varsayımlar:** V15, V16.

**Yapılacaklar:**

1. **Rehber editörü** (DESIGN §13.2): adım ekle / sil / sürükleyerek sırala; her adımda isteğe
   bağlı bir alan (alan seçici grupları ve [Sv] etiketlerini gösterir) ve markdown açıklama.
2. **Oyuncu deneyimi** (DESIGN §13.3): yeni karakterde rehber kendiliğinden açılır; her adımda
   ilgili alana kaydırılır ve vurgulanır; Geri / Kapat / Tamam; doğrulama yok. Telefonda alt
   panel, desktop'ta alanın yanında küçük panel.
3. **İlerleme** karakterde saklanır; [Rehber] butonu kaldığı adımdan sürdürür. Rehber yoksa buton
   gizli.
4. Rehber sırasında seviye tablolu kart eklenirse Faz 7'deki özet çıkar, sonra rehber sürer.

**Kapsam dışı:** seviye atlama rehberi (D31).

**Otomatik testler:** adım ilerleme ve kalıcılık; alansız adım; silinmiş alana bağlı adımın
çökmemesi (alan bulunamazsa sadece yazı gösterilir).

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E8.1 | Editörde DESIGN §13.2'deki 6 adımlık örnek rehberi yaz; adımları sürükleyerek sırala. | Kalıcı. |
| E8.2 | Dünyayı güncelle, yeni karakter oluştur. | Rehber kendiliğinden açılır, adım 1 Tür alanında. |
| E8.3 | **Tamam** → adım 2. | Sınıf alanına kayar ve vurgulanır. |
| E8.4 | Sınıf ekle. | Seviye özeti çıkar, kapatınca rehber sürer. |
| E8.5 | Adım 3'te **Kapat**; uygulamayı kapat ve aç; karakteri aç, [Rehber]. | Adım 3'ten sürer. |
| E8.6 | Alansız adım 6. | Sadece açıklama; kaydırma yok. |
| E8.7 | Rehberi telefonda ve desktop'ta kullan. | Telefonda alt panel, alan panelin üstünde görünür; desktop'ta yan panel. |
| E8.8 | Rehbersiz bir template'le karakter oluştur. | [Rehber] butonu yok. |
| E8.9 | R turu. | Faz 0 referansıyla aynı. |

**Çıkış kriteri:** DESIGN §19 Faz 4: oyuncu rehberle boş kağıttan karakter oluşturur.

---

### Faz 9 — Encounter ve harita ayarları

**Amaç:** Free dünyada encounter ve battlemap, template ayarlarına göre çalışsın; koda sabit
yazılmış slug ve anahtarlar free yolda template'ten okunsun.

**Onay gereken varsayımlar:** V18, V20. (V17 gereksiz, V19 D36'ya göre revize; 2026-10-12.)

**Yapılacaklar:**

1. **Editör bölümü "Encounter ve harita"** (DESIGN §14): encounter'a girebilen kategoriler (Savaş
   değerleri bloğu olmayan kategori için **[Ekle]**'li uyarı, D34 deseni); sıra değeri (bloktan bir
   Sayı ya da Zar) ve yön; sayı için zar ifadesi; battlemap görsel alanları; hareket izi rengi.
   Kolonlar ayrı listelenmez: Savaş değerleri'nde "encounter'da göster" açık değerler (Faz 6'da
   gelen ayarlar). Mevcut `EncounterConfig` modeli K2'ye uyarak genişletilir.
2. **Free encounter:** kolonlar Savaş değerleri'nden (HP her zaman); savaşçı başına ayrı değer;
   HP'de +/− mevcut değeri değiştirir, mevcut boşsa Max HP'ye eşitlenir; Durumlar kolonu bloktaki
   Kart listesinin hedefinden; oyuncu satırındaki değişiklik kağıda yazılır; sıralama, sürükleme,
   zar.
3. **Sabitler** (DESIGN §18): `combat_stats`, `location` / `battlemaps`, NPC / canavar iz rengi,
   `condition` slug'ı free yolda template ayarlarından okunur. Yerleşik yol aynen kalır.
4. **SRD kopyası varsayılanları** (DESIGN §14.1–14.2, §16.1): Canavar, Hayvan, NPC, Oyuncu kartı,
   Encounter, Tuzak; kolonlar İnis. (sıra, azalan), AC, HP, Durumlar. Encounter ve Tuzak'a da
   Savaş değerleri bağlanır ya da listeden çıkarılır (uygularken yerleşik encounter'ın bu iki
   kategoriyle ne yaptığına bakılıp karar verilir).

**Otomatik testler:** kolonların bloktan çıkması (gösterilmeyen değer kolonsuz, HP her zaman);
SRD canavarının düz alanlarının okunması; savaşçı başına kopya; geri yazma; sıra ve zar kuralları
(V18); bloksuz kategori uyarısı.

**Elle kontrol:**

| # | Kontrol | Beklenen |
|---|---|---|
| E9.1 | SRD'yi yeniden kopyala ("SRD kopyam 5"), dünya kur, Aria'yı oluştur. | — |
| E9.2 | Encounter'a Aria ve 3 Goblin ekle. | Kolonlar İnis., AC, HP, Durumlar; 3 ayrı Goblin HP'si. |
| E9.3 | Bir Goblin'e hasar ver (−). | Sadece o Goblin değişir. |
| E9.4 | Aria'ya hasar ver, kağıdını aç. | Kağıttaki HP de düşmüş. |
| E9.5 | **Zar at.** | İnisiyatif atılır, tablo sıralanır. |
| E9.6 | Bir satırı sürükle. | Elle sıra değişir. |
| E9.7 | Bir Goblin'e Prone ekle. | Durumlar kolonunda görünür. |
| E9.8 | Editörde Savaş değerleri'ne "Hız" (Sayı) ekle ya da var olanın "encounter'da göster"ini aç, dünyayı güncelle. | Encounter'da yeni kolon; kapatınca kalkar. |
| E9.9 | Battlemap'te bir Location görseli seç; token'ları hareket ettir. | Görsel template'teki alanlardan gelir; iz renkleri V20'ye göre. |
| E9.10 | Encounter'ı telefon görünümünde kullan. | +/− ve zar erişilebilir. |
| E9.11 | R turu (özellikle R5). | Yerleşik encounter aynen. |

**Çıkış kriteri:** DESIGN §19 Faz 5: free dünyada canavar ve oyuncu aynı encounter'da doğru
kolonlarla oynanır.

---

### Faz 10 — Kapanış

**Amaç:** Bütün sistemi baştan sona bir kez daha görmek, belgeleri güncellemek, merge kararını
kullanıcıya bırakmak.

**Yapılacaklar:**

1. **Uçtan uca tur:** SRD'yi kopyala → düzenle → hazır içerik ekle → dünya kur → paket oluştur ve
   kur → rehberle karakter oluştur → 5. seviyeye çıkar → dinlen → encounter oyna → `.dmtz` ile
   taşı.
2. **Vault** (K9): yeni dosyaların notları (template deposu, SRD kopyası dönüştürücüsü, seviye
   motoru, free kağıt, değişiklik kontrolü…); ilgili Map-of-Content'ler;
   [Template-System.md](../../vault/20-Systems/Template-System.md) "geçersiz kılındı, bkz.
   DESIGN.md" notuyla; `_Architecture-Overview.md`; Vault-Changelog.
3. **DESIGN.md:** §21'deki varsayımların son durumu; uygulamada tasarımdan sapılan noktalar
   (bu dokümanın §4'ü dahil) DESIGN'a işlenir.
4. **Tam test ve analiz** Faz 0 temel çizgisiyle karşılaştırılır.
5. **Merge:** sürüm notu ve PR, kullanıcı isterse.

**Elle kontrol:** uçtan uca tur + tam R turu.

---

## 8. Yol haritası kararları — onay bekleyenler

DESIGN.md'deki V1–V28'e ek olarak, bu yol haritası için benim seçtiğim noktalar:

| # | Karar | Neden |
|---|---|---|
| **Y1** | Branch, bütün fazlar bitene kadar `main`'e merge edilmez. Fazlar arası veri geçiş kodu yazılmaz; önceki fazların test template'leri gerekirse yeniden kopyalanır. | Yarım sistem kullanıcıya gitmez; geçiş kodu yazıp sonra silmek gerekmez. Ara bir fazda merge istenirse o noktadan sonra her şema değişikliği geçiş ister. |
| **Y2** | Free karakter kağıdı ve free template editörü ayrı ekranlardır; yerleşik ekranlara sadece yönlendirme kapısı eklenir. | K3. Yerleşik ekranların davranışının değişmediğini garanti etmenin en ucuz yolu. |
| **Y3** | Template güncelleme kontrolü sadece free template'li dünya ve paketlerde çalışır. | B2: yerleşik şemanın hash'i her açılışta değişiyor; yerleşikte sahte istem çıkar. |
| **Y4** | Anahtar bazlı uyumluluk sadece taraflardan biri free ise kullanılır; yerleşik ↔ yerleşik bugünkü etiket bazlı yolda kalır. | İ5. |
| **Y5** | Free dünyada encounter Faz 9'a kadar kopyanın bugünkü ayarlarıyla "olduğu gibi" çalışır. *(2026-10-12, D36: `combat_stats` bölünmüyor, anahtarlar aynı kaldığı için HP kolonu Faz 6'dan sonra da dolu kalmalı; Durumlar ve gizlenen değerler Faz 9'a kadar eski davranışta.)* | Encounter'ı iki kez yazmamak için. |
| **Y6** | SRD kopyası rehbersiz gelir; rehberi kullanıcı yazar. | DESIGN rehberin kopyayla gelip gelmeyeceğini söylemiyor. İstenirse §13.2'deki örnek varsayılan olarak eklenebilir (Faz 8'de küçük bir iş). |
| **Y7** | Yerleşik stat bloğunun yuvarlama hatası (DESIGN §8.2) bu işin parçası değildir; ayrı bir düzeltme olarak ele alınır. | K1, İ5: bu iş yerleşik davranışı değiştirmez. |
