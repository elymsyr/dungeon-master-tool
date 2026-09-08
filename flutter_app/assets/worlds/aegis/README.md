# Aegis — Meridia (eski adıyla Aethelgard)

**Aegis** evreninin birinci kıtası merkezli, DnD 5e tabanlı **özgün** bir dünya.
Cairn veya 99 Devils'tan farkı: bu bir üçüncü taraf metninin aktarımı değil,
**kendi evrenimiz** — lore birincil, mekanik ikincil.

Hedef: `assets/worlds/aegis/` → `aegis-act1.pkg.json`, uygulamaya kurulabilir
bir dünya. **Dil: Türkçe** (entity adları, açıklamalar, lore sayfaları).
**İlk kapsam: yalnızca Act 1.**

Bu dosya süreç brifingidir. Aegis'in *ne olduğu* `lore/archive/` içinde;
burada olan şey **hangi kaynağın geçerli olduğu, neyin karara bağlanmadığı ve
uygulamaya nasıl aktarılacağı**.

---

## 0. Kanon hiyerarşisi — çelişkide üstteki kazanır

Arşiv üç ayrı zaman katmanı taşıyor ve **birbirleriyle açıkça çelişiyorlar.**
Aşağıdaki sıra ölçüldü (Notion sayfa id'leri + dosya tarihleri + sayfaların
kendi "bu sayfa geçerlidir" beyanları):

| # | Kaynak | Tarih / kanıt | Not |
|---|---|---|---|
| 1 | `lore/archive/notion-notes/00 · Proje Yönergesi` | 3b0f…, "tüm belgelerin üstündedir" | Anayasa |
| 2 | `notion-notes/08` → `09` → `Adlandırma Doktrini` → `10` → `Başlıyoruz` | 3d2f…/3d3f… (en yeni Notion batch) | **Kanon revizyonu.** 08 ve 09 kendi başlıklarında "eskiyle çelişirse bu sayfa geçerlidir" diyor |
| 3 | `notion-notes/01–07` | 3b0f… | Revizyondan önce; 06 açık kararların kaydı, güncel tutuluyor |
| 4 | `claude-project/*.json` → `Genel_Ozet_Guncel`, `DM-1a/1b/1c`, `DM-3_Kampanya_Yapisi` | 2026-04 | Zengin detay, **kısmen geçersiz** — Suretsiz'i baş kötü sanıyor |
| 5 | Kök `.md`'ler (`Özet_Kitap`, `Bilgi_Katmanlari_Tablosu`, `DM-1*`) | 2026-04 | Aynı içeriğin dosya kopyaları |
| 6 | `*.pdf` | En eski | Yönerge §4: "MD ile çeliştiğinde MD kazanır" |

**Açıkça arşive kaldırılanlar (kanon DEĞİL):**
`Oyun_Durumu_Güncel`, `YAZIM_KOMUTU.md`, `YAZIM_PLANI_RAPORU.md`
(Proje Yönergesi §4 bunları isim isim geçersiz ilan ediyor).

> `Oyun_Durumu_Güncel` (claude-project doc #9, 2026-06-19) tarih olarak **en yeni
> dosya** ama kanon değil — oynanmış bir masanın oturum kaydı. Yönerge §2 canlı
> oturum takibini tamamen bıraktı: "Eski oyun geçmişi, kitabın kaynağı değil;
> kitabın test edilmiş bir örneğidir." Sahneleri fikir olarak kullan, olay
> olarak yazma.

`notion-notes/` (2026-09-07 export) `update/` klasörünün (2026-08-13) üst
kümesidir. **`update/` klasörünü kullanma** — eski ve eksik.

---

## 1. Kanon revizyonu — neyin değiştiğini bilmeden yazma

Arşivin %80'i (tüm PDF'ler, Özet_Kitap, DM-1a/b/c, Genel_Ozet) **revizyon
öncesi** yazıldı. Aşağıdaki beş madde o metinlerin hepsini kısmen geçersiz kılar:

| Eski (PDF / Özet_Kitap / Genel_Ozet) | Yeni (08, 09, Adlandırma, 06) |
|---|---|
| Baş kötü **Suretsiz** | Baş kötü **Kral Aethel/Lucian**. Suretsiz onun eli/proxy'si |
| Mızrağı yalnız "Aethel'in soyu" kullanabilir; kolye kan bağı kilidi | **Kan bağı kaldırıldı.** Kolye kilit değil **pusula** — herkes taşıyabilir |
| Aethelgard kapalı ada, dışarısı efsane | **İzolasyon coğrafi değil arşivsel.** Ticaret yolları sağlam; boşluk *bilgide*. Tek gerçek arşiv Occulus |
| İsimler: Aethel, Aethelgard | **Terk edildi.** Kral = **Lucian**, başkent = **Lucid Triton**, kıta = **Meridia** (§3.1 onaylandı). Bkz. §3 |
| Blight bir iklim, dünya çürüyor | **Blight bir cephe, iklim değil.** Sınırı var ve tutuluyor. Ton kuralı: *karanlık geçmişte ve yapılarda; ışık insanlarda ve bugünde* |

Ayrıca kaldırılanlar: Act 1'de **mızrak parçası yok** (perdenin ödülü bilgi ve
müttefiktir), Kara Donanma ablukası Act 1 **başında yok** (öneri: sonunda).

---

## 2. Act 1 — kapsam ve iskelet

> Kart dökümü: [`lore/canon/act1-kartlar.md`](lore/canon/act1-kartlar.md) (Act 1) ·
> [`lore/canon/genel-kartlar.md`](lore/canon/genel-kartlar.md) (perdeden bağımsız).
>
> Çalışma belgesi: [`lore/canon/act1.md`](lore/canon/act1.md) — açılış, background'lar,
> Gümüşsu ve ilk savaş orada. Aşağısı perdenin genel çerçevesi.

**Sınır (06 #12, ÇÖZÜLDÜ):** Act 1, **Gümüşsu'da başlar**; deniz yolculuğunun
bitmesi ve **ikinci kıtanın ufukta görülmesiyle biter.** Yolculuk perdenin
dışında bir geçiş değil, perdenin içinde tasarlanacak bir bölüm.

Akış (08 §2):

1. **Başlangıç** — herkes birinci kıtada, herkesin hastalıkla ilgili *bir* amacı
   var. "Kaynağı bul" olmak zorunda değil.
2. **Gümüşsu** — köyde buluşma. Aynı anda varmak şart değil. Sahne bir savaş
   değil bir **soruşturma** (07: "Salgın araştırılmaz, suç araştırılır" — üç genç
   paladinin ensesine cerrahi iğne yerleştirilmiş). Köy kötü biter; ölmekte olan
   hastalar sayıklar, ilk iz oradan çıkar.
3. **Diplomasi Kuşağı** — Paladin Şatosu, Merkezi Şehir, diğer köyler. Asıl
   direnç **kurumsal sessizlik**: hastalık gizlenmek isteniyor.
4. **Süre baskısı** — sayaç oyuncuların değil **bir NPC'nin** üzerinde taşınır.
   Hastalanma zorlama değil, bir seçimin sonucu olur (cesede dokundu, hastayı
   taşıdı).
5. **Geçiş** — iki liman: **Elymsyr** (açık, resmi, hızlı / donanma riski) veya
   **Gizli Liman** (donanmadan güvenli / yaratık riski).
6. **Gemi** — kapalı mekan bölümü: kimin ne bildiği, kimin hasta olduğu orada
   açığa çıkar. Kapanış görüntüsü: ikinci kıta ufukta.

**Rol yuvaları (Proje Yönergesi §3.2 — zorunlu tasarım kuralı).** Hiçbir sahne
belirli bir PC'ye bağlanamaz. Act 1'in dört yuvası (07 "Yakınsama Tasarımı"):

| Yuva | Neden Gümüşsu'da | Ne fark eder |
|---|---|---|
| **Uyarıcı** | Rüyalar/işaretler güneye çekti | Çürümenin doğal olmadığını ilk o söyler |
| **Şüphelenen** | Kayıp askerleri aramaya geldi | Cesetlerdeki iğneyi o bulur |
| **Kaçan** | Buraya yerleştirdiği insanlar var | Kimin nereye götürüldüğünü o bilir |
| **İşaretlenen** | Kaçtığı şey buraya kadar geldi | Bedeni tepki verir |

Yuva boş kalabilir → sahne bir NPC'ye devredilir veya çıkarılır.
`01 · Başlangıç Karakterleri` bu dört yuvanın **pre-gen örnekleridir**
(**Jaonos** = Uyarıcı, **Bızdır** = Şüphelenen, **Aly** = Kaçan,
**Will** = İşaretlenen) — zorunlu değiller.

**NPC standardı (09 §7):** her kilit NPC üç satır — *ne istiyor · ne gizliyor ·
hangi kapıyı açıyor*. **Kilitlenme kuralı:** her kritik kapının **en az iki
taşıyıcısı** olmalı. Tek NPC'de duran bilgi hikayeyi kilitler.

**Bilgi eğimi (09 §4)** — soruşturmanın haritasını kendiliğinden çizer:
limanlarda söylenti bol · Merkezi Şehir'de bastırılmış · Ravenhall'da yok
(çünkü zaten biliniyor, kimse sormadı).

**Act 1 lokasyon güzergahı (09 §5, 10 M13):**
Gümüşsu → büyük köyler (Cinervik / Argenfon) → Merkezi Şehir → Elymsyr →
Gizli Liman → Paladin Şatosu (Votumar) → Ravenhall Avlusu.

---

## 3. Kararlar

### 3.1 Bu oturumda kapatılanlar (2026-09-08)

| # | Karar | İçerik |
|---|---|---|
| M0.1 | **Kıta adı: Meridia** | Adlandırma Doktrini **tam** uygulanıyor. Kral **Lucian**, başkent **Lucid Triton**, kıta **Meridia**. `Aethel` / `Aethelgard` **terk edildi** — arşivdeki her geçiş aktarımda çevrilecek |
| M0.4 | **Gümüşsu Türkçe kalıyor** | Latin resmi isim ağının dışında, kayda değer görülmemiş bir köy. Adının hâlâ halk dilinde olması, orayı kimsenin umursamadığının kanıtı |
| M0.5 | **Latin hafif dozu** | Custodar · Claport · Altimont · Cinervik · Argenfon · Votumar (2-3 hece). Ağır sonekler (-castrum, -arx, -portus, -montes) kullanılmıyor |
| 06 #1 | **Pre-gen isim seti: Jaonos · Bızdır · Aly · Will** | Diğer set (Ilysard / Fyli / Goliath) terk edildi |
| 06 #8 | **Gümüşsu kurtarılabilir** | Karantina tutulabilir, köyün bir kısmı yaşar → oyunun ilk zaferi. Ton kuralıyla ("ışık bugünde") örtüşür. **Not: Gümüşsu bölümü ve açılış yeniden kurgulanacak** — 07'deki ilkeler geçerli, sahne akışı değil |

### 3.2 Hâlâ açık — yazmadan önce kapatılması gerekenler

`10 · Sıfırdan İnşa Planı`'nın **M0 Karar Kilidi**'nden kalanlar. Bunlar
kapanmadan yazılan her şey yeniden yazılır:

| # | Karar | Durum |
|---|---|---|
| M0.2 | **Lucian'ın doğum adı** — Cor / Rhen / Bast / Dorn / Vell | Seçilmedi. Act 1'i bloke etmez (sır) |
| M0.3 | **Triton isminin kökeni** — A+C önerildi (isim fetihten kaldı + Oculus kökeni sildi; halk "üç dişli mızrak" sanıyor) | Onay bekliyor |
| M0.6 | **Kara Gemiler ablukasının zamanı** | Öneri: Act 1 sonu — liman seçimi gerçek baskı altında yapılsın |

`06 · Açık Kararlar`'dan Act 1'i doğrudan etkileyenler:

- **#9 Açılış yeniden kurgulanacak** — 3.1'de teyit edildi. Gümüşsu bir *yer*
  olarak kurulmadan akış yazılmaz (07 "Yöntem Notu": kim yaşıyor, kim kimi
  seviyor, kim ne saklıyor, karantinayı kim yönetiyor, kaç gün var).
- **#10 Lucian şu an ne halde?** (yaşıyor / kurum olarak işliyor / yarı-varlık)
  — öneri (b)+(c). Act 1'de düşman zaten kurum, o yüzden Act 1'i bloke etmiyor.
- **#11 Irksal özellikler de simyacı güçlendirmesinden mi geliyor?** — Act 2
  ikilemini kuruyor; Act 1'de `species` kartı yazacaksak bilmemiz gerekir.
- **#14 Hastalığın haritadaki konumu** — "kuzeyden gelen çürüme" deniyor ama
  Ravenhall da kuzeyde; Gümüşsu güneyde. Coğrafya çelişkisi açık.
- **#15 Abluka**, **#16 Occulus tekelciliği**, **#17 gerçek Başkumandan nerede**.

**Kanon ama henüz yazılmamış:** kronoloji tablosu (`03` boş), fraksiyonlar
(09 §8 adım 2), Sancak Kaydı statü sistemi (10 M1 — "omurga, M2–M17 buna bağlı"),
kişi adı dağarcığı (10 M5 — Adlandırma Doktrini yalnız *yer* adlarını çözdü),
mesafe/seyahat süreleri (10 M12 — "bu olmadan Act 1'in temposu hesaplanamaz").

---

## 4. Uygulama tarafı — teknik brifing

### 4.1 Süreç dokümanları (önce bunları oku)

| Dosya | Ne verir |
|---|---|
| [tool/content/README.md](../../../../tool/content/README.md) | Aktarım süreci, doğrulama, paketleme |
| [tool/content/world-blueprint.md](../../../../tool/content/world-blueprint.md) | **Alan sözleşmesi** — her kategorinin key/tip/zorunluluk tablosu |
| [tool/content/WORLD_CONTENT_ORDER.md](../../../../tool/content/WORLD_CONTENT_ORDER.md) | Kategori ekleme sırası (bağımlılık zinciri) + Tier kuralları |
| [tool/content/character-blueprint.md](../../../../tool/content/character-blueprint.md) | Pre-gen PC alanları (`blueprint.json`) |
| [assets/worlds/cairn/README.md](../cairn/README.md) | Faz planı + karar kaydı formatının en iyi örneği |
| [vault/10-Files/world-content/world_blueprint_converter.md](../../../../vault/10-Files/world-content/world_blueprint_converter.md) | Converter'ın kendisi |

### 4.2 Aegis'in farkı: kaynak PDF yok

`tool/content/README.md` §0 "kaynaktaki her cümle dünyaya girer, özetleme yok"
diyor ve `audit_coverage.py` ile %95 kapsam zorunlu tutuyor. **Bu Aegis'e
olduğu gibi uygulanamaz** — ortada aktarılacak bitmiş bir kitap yok; arşiv
çelişkili taslaklar yığını, kanonun bir kısmı henüz yazılmadı (§3).

Yerine geçen kural — **aynı sertlikte:**

1. **Kanon dışı uydurma yok.** §0 hiyerarşisinde bir dayanağı olmayan mekan,
   NPC, olay veya mekanik yazılmaz. Kaynak bir alanı söylemiyorsa alan **boş**
   bırakılır.
2. **Boşluk doldurmak yazmak değil, karar almaktır.** Kanonda olmayan bir şey
   gerekiyorsa önce §3'e madde olarak eklenir ve sorulur; sonra yazılır.
3. **Her entity'nin izi sürülebilir olmalı.** Blueprint'in yanında
   `PROVENANCE.md` tutulur: `<entity adı> ← <kaynak dosya> § <bölüm>`.
   Kapsam denetiminin yerini bu tutar.
4. `--check` yine zorunlu ve yine yalnız şemayı doğrular, sadakati doğrulamaz.

### 4.3 Hedef dizin yapısı

```
assets/worlds/aegis/
  README.md              ← bu dosya (authoring brifingi, pakete girmez)
  PROVENANCE.md          ← entity → kaynak izi (yazılacak)
  lore/archive/          ← ham arşiv, pakete GİRMEZ
  aegis-act1/            ← modül dizini (yazılacak)
    manifest.json
    world-blueprint.json
    blueprint.json       ← pre-gen PC'ler (Tier 3)
    media/
      Maps/  Artwork/  Handouts/
```

`cairn/` gibi çok modüllü bir kök: `assets/worlds/aegis/` **doğrudan bir dünya
dizini değil**, alt modül taşır. `convert_blueprint.dart --dir` her zaman
`aegis/aegis-act1`'i alır, `aegis`'i değil.

### 4.4 manifest.json

```json
{
  "slug": "aegis-act1",
  "title": "Aegis — Meridia: Birinci Perde",
  "system": "dnd5e",
  "publisher": "elymsyr",
  "author": "elymsyr",
  "license": "all-rights-reserved",
  "attribution": "Copyright © 2026 elymsyr. Tüm hakları saklıdır.",
  "version": "0.1.0",
  "description": "…",
  "files": ["media/Maps/…"]
}
```

`publisher` / `author` = **elymsyr** — dünya bu kimlik altında oluşturulacak,
marketplace'e yayınlandığında da atıf buradan gelir. `files` listesinde
olmayan medya installer tarafından **diske çıkarılmaz.**

### 4.5 Act 1 için kategori planı

Sıra [WORLD_CONTENT_ORDER.md](../../../../tool/content/WORLD_CONTENT_ORDER.md)
zincirine uyar. Act 1'de kullanılacaklar:

| Sıra | Kategori | Act 1 içeriği |
|---|---|---|
| 1 | `campaign` | Kitabın giriş bölümü: ton sözleşmesi, "bu dünyada oynamak", DM'e bağlama (`pages[]`) |
| 2 | `location` | Gümüşsu → Cinervik/Argenfon → Merkezi Şehir → Elymsyr → Gizli Liman → Votumar → Ravenhall. Hiyerarşi `parent_location_ref` ile |
| 3 | `lore` | Sansürlü resmi tarih, İrade doktrini, Adlandırma Doktrini'nin oyuncuya görünen yüzü, fraksiyonlar, Blight'ın bilinen hali. **DM sırları buraya değil** — `secrets` alanlarına |
| 4 | `monster` | Blight'lı asker/köylü, ele geçirilmiş paladin. SRD'de birebir adı olan hiçbir şeyi tekrar yazma, referans ver |
| 5 | `npc` | Halder, Elara, Başkumandan (= Suretsiz, `secrets`'te), Gümüşsu kadrosu, karantina doktoru, meclis üyesi, kaçakçı. Her biri *ne istiyor / ne gizliyor / hangi kapıyı açıyor* |
| 6-7 | `environmental-effect`, `trap` | Karantina bölgesi, Blight teması, gemi ambarı |
| 8 | `scene` | Paslı Kadeh, karantina kararı, meclis, liman pazarlığı, gemi bölümü |
| 9 | `encounter` | Gümüşsu çatışması, liman kaçışı, deniz karşılaşması |
| 10 | `quest` | Yuva başına giriş kancaları + ana hat |
| — | `species` / `background` | **Bölgeye özgü** background'lar (lonca ajanı, paladin çırağı, Ravenhall druidi, kayıtsız). Irklar M0.11 kapanmadan yazılmaz |
| Tier 3 | `blueprint.json` | Dört pre-gen (rol yuvası başına bir tane) |

**Sır yerleşimi:** DM-only bilgi `location.secrets`, `npc.secrets`,
`quest.secrets`, `encounter.tactics` alanlarına gider. Oyuncu Kitabı ↔ DM
Kitabı ayrımı bu alanlarla kurulur — ayrı bir "DM lore" kategorisi açma.

**Entity link'i bırak:** `@[Halder](entity:npc/Halder)` — hedef aynı
blueprint'te tanımlı olmalı, SRD satırlarına link verilemez.

### 4.6 Medya

`lore/archive/media/` — 17 görsel, **110 MB**, tanesi 5–8 MB JPG/PNG
(kıta haritası, güney/kuzey köyleri, Gümüşsu, Gümüşsu savaş, Paladin
Şatosu, deniz feneri, Gizli Liman, bar, 7 adet Gemini üretimi).
`.import` dosyaları Godot artığı — **kopyalanmayacak.**

Kullanılacaklar `aegis-act1/media/` altına **webp'e çevrilerek** alınır
(diğer dünyalar `.webp` kullanıyor; 110 MB olduğu gibi paketlenemez) ve
`manifest.json` → `files` listesine yazılır.

### 4.7 Komutlar

```bash
cd flutter_app
dart run tool/content/convert_blueprint.dart --dir assets/worlds/aegis/aegis-act1 --check
dart run tool/content/convert_blueprint.dart --dir assets/worlds/aegis/aegis-act1
# → aegis-act1.pkg.json
```

`--check` çözülemeyen ref / şema dışı alan / eksik medyada non-zero döner.
CI karşılığı: `test/domain/services/bundled_worlds_blueprint_test.dart`.

`pubspec.yaml`'da `assets/worlds/` bloğu **yorumda** (~326 MB) —
`assets/worlds/manifest.json`'a giriş eklemek dünyayı "bundled" yapar ve
`BundledWorldsInstaller` görür. Aegis'i oraya eklemek ayrı bir karar; önce
`.pkg.json` üretilip elle kurulur.

---

## 5. Faz planı

| # | Faz | Çıktı | Bitti sayılma koşulu |
|---|---|---|---|
| 0 | **M0 kilidini kapat** (§3) | Karar listesi | Kıta adı ✅ · Gümüşsu ✅ · pre-gen seti ✅ · #8 tonu ✅ · kalan: M0.2/M0.3/M0.6 |
| 1 | Kanon damıtma | `lore/canon/` — çelişkisiz Act 1 kanonu (kronoloji, fraksiyonlar, bilgi eğimi) | Her madde §0 hiyerarşisinde bir kaynağa dayanıyor |
| 2 | Lokasyonlar | 7 lokasyon, `location` + `parent_location_ref` | Her biri: kim yönetiyor · kim çalışıyor · neye benziyor · neyi gizliyor · hangi kapıyı açıyor |
| 3 | Fraksiyon + NPC | `lore` (fraksiyonlar) + `npc` | Her kritik kapının iki taşıyıcısı var |
| 4 | Sahne / encounter / quest | `scene`, `encounter`, `quest`, `trap` | Her zorunlu sahne bir **yuvaya** bağlı, PC'ye değil |
| 5 | Campaign + lore sayfaları | `campaign.pages[]` | Ton sözleşmesi + sansürlü tarih |
| 6 | Pre-gen'ler | `blueprint.json` | Dört yuva, dört karakter |
| 7 | Medya + paketleme | `media/*.webp`, `.pkg.json` | `--check` temiz, `PROVENANCE.md` tam |

Bir faz kapanmadan sonrakine geçilmez (10 · Çalışma Ritmi).

---

## 6. Yazarken uyulacak ilkeler

1. **DM Kitabı önce yazılır**, Oyuncu Kitabı ondan damıtılır → app'te bu
   `secrets` alanı ayrımıdır.
2. **Tarih bugüne varmak için kurgulanmaz.** Her büyük olayın en az bir
   istenmeyen sonucu var; boşa giden şeyler var; kimse "kötü olduğu için"
   hareket etmiyor.
3. **Hikaye belirli karakterlere bağlanmaz** — rol yuvaları.
4. **Ton kuralı:** karanlık geçmişte ve yapılarda; ışık insanlarda ve bugünde.
   *Dünya yaşanabilir, ama gidişat kötü.* En az üç NPC'nin yarası olmasın.
5. **Taban DnD 5e**, ikincil referans Forgotten Realms. Sapmalar (Blight
   kuralları, ilahi büyünün durumu) açıkça işaretlenir; sıfırdan sistem yazılmaz.
6. **Gerçekçilik iddia edilmez, hissettirilir.** "Bu dünya gerçekçidir" cümlesi
   metinde geçmez.
