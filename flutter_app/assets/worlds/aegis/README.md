# Aegis — Meridia (eski adıyla Aethelgard)

**Aegis** evreninin birinci kıtası merkezli, DnD 5e tabanlı **özgün** bir dünya.
99 Devils'tan farkı: bu bir üçüncü taraf metninin aktarımı değil,
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
| 0 | `lore/canon` | Burada düzenlediğimiz amna notlar | En öncelikli ve sürekli güncellenen içerik |
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

**Bugünkü masa da kanon değil.** Dünya burada tasarlanırken aynı anda bir masada
oynatılıyor; oynanan oturumlar [`oturum-kaydi.md`](oturum-kaydi.md)'de tutulur.
Masada olan olay kartlara taşınmaz — oradan yalnız yazım geri bildirimi gelir.

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

> **Kart dökümü: [`lore/canon/kart-listesi.md`](lore/canon/kart-listesi.md)** —
> oluşturulacak bütün kartlar (**127**), kategoriye göre, tek listede. Yazarken buna
> bakılır. Perdeye bölünmüş eski çalışma listeleri
> [`act1-kartlar.md`](lore/canon/act1-kartlar.md) ve
> [`genel-kartlar.md`](lore/canon/genel-kartlar.md)'de duruyor.
>
> **Kanon dört içerik belgesi** (`lore/canon/`, çelişkide sırayla değil, konuya
> göre); klasördeki diğer üç dosya (`kart-listesi`, `act1-kartlar`, `genel-kartlar`)
> bunlardan türeyen kart listeleridir:
>
> | Belge | Ne kapsar |
> |---|---|
> | [`act1.md`](lore/canon/act1.md) | Açılış, background'lar, Gümüşsu, Gizli Liman, Blight kural kartı, ilk savaş |
> | [`lonca-sehir.md`](lore/canon/lonca-sehir.md) | Altı lonca, haneler, Konsey/Meclis, Lucid Triton, Meclis oturumu |
> | [`bolgeler.md`](lore/canon/bolgeler.md) | Kıta geneli (doktrin, adalet, mimari, ırk, mesafe) + **Elymsyr · Votumar · Ravenhall** + Cinervik/Argenfon |
> | [`mekanikler.md`](lore/canon/mekanikler.md) | 5e'nin üstündeki kural sapmaları: lisans, diriltme, ışınlanma, yozlaşma, simya, kalıcı yaralar |

**Sınır (06 #12, ÇÖZÜLDÜ):** Act 1, **Gümüşsu'da başlar**; deniz yolculuğunun
bitmesi ve **ikinci kıtanın ufukta görülmesiyle biter.** Yolculuk perdenin
dışında bir geçiş değil, perdenin içinde tasarlanacak bir bölüm.

Akış (08 §2):

1. **Başlangıç** — herkes birinci kıtada, herkesin hastalıkla ilgili *bir* amacı
   var. "Kaynağı bul" olmak zorunda değil.
2. **Gümüşsu** — köyde buluşma. Aynı anda varmak şart değil. Sahne bir savaş
   değil bir **soruşturma**. Köy **huzursuz ama işleyen** bir yer, kimse ölmemiş;
   hasta sanılan üç kişi köyün dışındaki kulübede. Üçü **ikinci kıtadan, kayıtsız**
   geldi — Gümüşsu hastalığı üretmedi, **teslim aldı.** "Bu doğal değil" anını
   iğne değil **beden** (Medicine DC 12) ve **Arcana DC 13** taşır
   ([`act1.md` §3–4](lore/canon/act1.md)). Köy **kurtarılabilir** (06 #8).
3. **Diplomasi Kuşağı** — Paladin Şatosu, Lucid Triton, diğer köyler. Asıl
   direnç **kurumsal sessizlik**: hastalık gizlenmek isteniyor.
4. **Süre baskısı** — sayaç oyuncuların değil **bir NPC'nin** üzerinde taşınır.
   Hastalanma zorlama değil, bir seçimin sonucu olur (hastaya dokundu, kulübeye
   girdi).
5. **Geçiş** — iki liman: **Elymsyr** (açık, resmi, hızlı / donanma riski) veya
   **Gizli Liman** (donanmadan güvenli / yaratık riski).
6. **Gemi** — kapalı mekan bölümü: kimin ne bildiği, kimin hasta olduğu orada
   açığa çıkar. Kapanış görüntüsü: ikinci kıta ufukta.

**Rol yuvaları (Proje Yönergesi §3.2 — zorunlu tasarım kuralı).** Hiçbir sahne
belirli bir PC'ye bağlanamaz. Act 1'in dört yuvası (07 "Yakınsama Tasarımı"):

| Yuva | Neden Gümüşsu'da | Ne fark eder |
|---|---|---|
| **Uyarıcı** | Rüyalar/işaretler güneye çekti | Çürümenin doğal olmadığını ilk o söyler |
| **Şüphelenen** | Söylentinin doğal olmadığından şüphelendi | Hastalığın köyden eski olduğunu (beden izi) o okur |
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
limanlarda söylenti bol · Lucid Triton'da bastırılmış · Ravenhall'da yok
(çünkü zaten biliniyor, kimse sormadı).

**Act 1 lokasyon güzergahı (09 §5, 10 M13):**
Gümüşsu → büyük köyler (Cinervik / Argenfon) → Lucid Triton → Elymsyr →
Gizli Liman → Paladin Şatosu (Votumar) → Ravenhall Avlusu.

---

## 3. Kararlar

### 3.1 Bu oturumda kapatılanlar (2026-09-08)

| # | Karar | İçerik |
|---|---|---|
| M0.1 | **Kıta adı: Meridia** | Adlandırma Doktrini **tam** uygulanıyor. Kral **Lucian**, başkent **Lucid Triton**, kıta **Meridia**. `Aethel` / `Aethelgard` **terk edildi** — arşivdeki her geçiş aktarımda çevrilecek |
| M0.4 | **Gümüşsu adı kalıyor** | Latinleştirilmiyor. Halk dili / Latin ayrımı kanon **değil** — adlar karışık kalır, hiçbir ad bir dil kuralına uymak zorunda değil ([`act1.md` §3](lore/canon/act1.md)) |
| M0.5 | **Hafif ad dozu** | Cinervik · Argenfon · Votumar · Elymsyr (ikinci adı **Claport**) — 2-3 hece. Ağır sonekler (-castrum, -arx, -portus, -montes) kullanılmıyor |
| M0.7 | **Nehrin adı: Altın Nehir** | `bolgeler.md` §9 madde 5 kapandı (2026-09-16). Batı dağlarından çıkar, ağzında **Elymsyr** durur, mavnaları başkente çıkar. Lucid Triton'a gelen mal **teslim**tir, transit değil — `location/Nehir Yükleme Alanı` |
| 06 #1 | **Pre-gen isim seti: Jaonos · Bızdır · Aly · Will** | Diğer set (Ilysard / Fyli / Goliath) terk edildi |
| A1 | **Anlatım üslubu: WotC read-aloud** | Kart gövdelerinin ve sahne metinlerinin üslubu karara bağlandı — atmosferik, duyusal, eyleme hazır. Tolkien ağırlıklı kadim/destansı üslup ve hibrit denendi, **seçilmedi**. Uygulama kuralı §6.7 |
| A2 | **Uydurma yasağı + öneri kanalı** | Teyit edilmemiş hiçbir görev, NPC, mekan veya olay örgüsü metne kanon gibi girmez. Fikirler ayrı bir **"Öneri / Fikir:"** bloğunda sorulur, onay beklenir. Uygulama kuralı §4.2.2 |
| A3 | **Durum yazılır, olay takvimi yazılmaz** (2026-09-14) | Kartlar bir durum, mekanlar ve NPC'ler kurar; olayları saate ya da oyuncunun hamlesine bağlayıp *olacakmış gibi* yazmaz. *"Şafakta üçü döner"* → *"üçü son aşamaya geçmek üzere"*; *"Corvin şafaktan önce köye döner"* → *"Corvin ara ara köye uğrar"*; *"Orvan kapıda bekler ve teklif eder"* → Orvan'ın elinde bir teklif var, yapıp yapmayacağı masanın. Masadan gelen yorumlardan çıktı ([`oturum-kaydi.md`](oturum-kaydi.md)). Uygulama kuralı §6.8 |
| 06 #8 | **Gümüşsu kurtarılabilir** | Karantina tutulabilir, köyün bir kısmı yaşar → oyunun ilk zaferi. Ton kuralıyla ("ışık bugünde") örtüşür. Gümüşsu bölümü ve açılış [`act1.md` §1–3](lore/canon/act1.md)'te yeniden kurgulandı — 07'deki ilkeler geçerli, sahne akışı değil |

### 3.2 Hâlâ açık — yazmadan önce kapatılması gerekenler

`10 · Sıfırdan İnşa Planı`'nın **M0 Karar Kilidi**'nden kalanlar. Bunlar
kapanmadan yazılan her şey yeniden yazılır:

| # | Karar | Durum |
|---|---|---|
| M0.2 | **Lucian'ın doğum adı** — Cor / Rhen / Bast / Dorn / Vell | Seçilmedi. Act 1'i bloke etmez (sır) |
| M0.3 | **Triton isminin kökeni** — A+C önerildi (isim fetihten kaldı + Oculus kökeni sildi; halk "üç dişli mızrak" sanıyor) | Onay bekliyor |
| M0.6 | **Kara Gemiler ablukasının zamanı** | Öneri: Act 1 sonu — liman seçimi gerçek baskı altında yapılsın. ⚠️ **Artık iki yazılmış bölümü doğrudan etkiliyor:** Elymsyr'in zinciri ve Votumar'ın bugünkü hali ([`bolgeler.md` §2.3, §3.6](lore/canon/bolgeler.md)). Filonun **kimliği** de yazılmadı (arşivdeki "ork donanması" reddedildi) |

`06 · Açık Kararlar`'dan Act 1'i doğrudan etkileyenler:

- ~~**#9 Açılış yeniden kurgulanacak**~~ — **KAPANDI:** Gümüşsu yer olarak
  [`act1.md` §3](lore/canon/act1.md)'te kuruldu, akış oradan çıkıyor.
- **#10 Lucian şu an ne halde?** (yaşıyor / kurum olarak işliyor / yarı-varlık)
  — öneri (b)+(c). Act 1'de düşman zaten kurum, o yüzden Act 1'i bloke etmiyor.
- **#11 Irksal özellikler de simyacı güçlendirmesinden mi geliyor?** — Act 2
  ikilemini kuruyor; Act 1'de `species` kartı yazacaksak bilmemiz gerekir.
- ~~**#14 Hastalığın haritadaki konumu**~~ — **KAPANDI:** hastalık Meridia'ya
  kuzeyden değil **ikinci kıtadan** taşındı ([`act1.md` §3.1](lore/canon/act1.md)),
  Gümüşsu'nun güneyde olması çelişki değil.
- **#15 Abluka**, **#16 Occulus tekelciliği**, **#17 gerçek Başkumandan nerede**.

**Kanon ama henüz yazılmamış:** kronoloji tablosu (`03` boş) ve fraksiyonlar
(09 §8 adım 2). ~~Sancak Kaydı statü sistemi~~ (10 M1) `lonca-sehir.md` §9'da,
~~kişi adı dağarcığı~~ (10 M5) `kart-listesi.md`'nin adlandırma kurallarında kapandı.
**10 M12 (mesafeler) kısmen açıldı:** ilk sayı yazıldı — Lucid Triton → Votumar
2 gün atlı ([`bolgeler.md` §1.7](lore/canon/bolgeler.md)); diğer mesafeler hâlâ yok.

---

## 4. Uygulama tarafı — teknik brifing

### 4.1 Süreç dokümanları (önce bunları oku)

| Dosya | Ne verir |
|---|---|
| [tool/content/README.md](../../../../tool/content/README.md) | Aktarım süreci, doğrulama, paketleme |
| [tool/content/world-blueprint.md](../../../../tool/content/world-blueprint.md) | **Alan sözleşmesi** — her kategorinin key/tip/zorunluluk tablosu |
| [tool/content/WORLD_CONTENT_ORDER.md](../../../../tool/content/WORLD_CONTENT_ORDER.md) | Kategori ekleme sırası (bağımlılık zinciri) + Tier kuralları |
| [tool/content/character-blueprint.md](../../../../tool/content/character-blueprint.md) | Pre-gen PC alanları (`blueprint.json`) |
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
2. **Boşluk doldurmak yazmak değil, karar almaktır** (karar A2). Kanonda olmayan
   bir şey gerekiyorsa önce §3'e madde olarak eklenir ve sorulur; sonra yazılır.

   **Ana akışa yalnız teyit edilmiş öğe girer.** Konuşulup onaylanmamış hiçbir
   görev, NPC, mekan, nesne, olay örgüsü veya kırılma anı — ne kart gövdesine,
   ne sahne metnine, ne `secrets` alanına — **kesinleşmiş gerçeklik gibi
   yazılmaz.** Bir alan kanonda yoksa alan boş kalır; DM'e "burada bir şey var"
   izlenimi veren dolgu cümlesi de uydurmadır.

   **Fikir üretmek serbest, gömmek yasak.** Bir yan görev, bağlantı ya da detay
   yakışıyorsa metnin **sonuna ayrı bir blok** olarak yazılır ve onay sorulur:

   ```
   ### Öneri / Fikir
   - <öneri> — nereye takılır, ne açar, hangi kanona yaslanıyor.
     Eklensin mi?
   ```

   Bu blok kartın içine, blueprint'e veya kanon belgesine **girmez**; sohbette
   ya da çalışma notunda durur. Onay verildiği an öğe §3'e karar olarak yazılır,
   sonra metne girer. Onaysız öneri, tekrar sorulmadan hiçbir turda metne
   taşınmaz.
3. **Her entity'nin izi sürülebilir olmalı.** Blueprint'in yanında
   `PROVENANCE.md` tutulur: `<entity adı> ← <kaynak dosya> § <bölüm>`.
   Kapsam denetiminin yerini bu tutar.
4. `--check` yine zorunlu ve yine yalnız şemayı doğrular, sadakati doğrulamaz.

### 4.3 Hedef dizin yapısı

```
assets/worlds/aegis/
  README.md              ← bu dosya (authoring brifingi, pakete girmez)
  PROVENANCE.md          ← entity → kaynak izi ✅
  lore/canon/            ← damıtılmış Act 1 kanonu (pakete GİRMEZ)
  lore/archive/          ← ham arşiv, pakete GİRMEZ
  aegis-act1/            ← modül dizini ✅
    manifest.json        ← ✅
    world-blueprint.json ← ✅ 125 entity (§4.8)
    blueprint.json       ← pre-gen PC'ler (Tier 3) — yazılmadı, Faz 6
    media/               ← yazılmadı, Faz 7 (§4.6)
      Maps/  Artwork/  Handouts/
```

Çok modüllü bir kök: `assets/worlds/aegis/` **doğrudan bir dünya
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
  "files": {}
}
```

`publisher` / `author` = **elymsyr** — dünya bu kimlik altında oluşturulacak,
marketplace'e yayınlandığında da atıf buradan gelir. `files` içinde
olmayan medya installer tarafından **diske çıkarılmaz**; medya henüz
paketlenmediği için şimdilik boş bir nesne (`{}`).

### 4.5 Act 1 için kategori planı

Sıra [WORLD_CONTENT_ORDER.md](../../../../tool/content/WORLD_CONTENT_ORDER.md)
zincirine uyar. Act 1'de kullanılacaklar:

| Sıra | Kategori | Act 1 içeriği |
|---|---|---|
| 1 | `campaign` | Kitabın giriş bölümü: ton sözleşmesi, "bu dünyada oynamak", DM'e bağlama (`pages[]`) |
| 2 | `location` | Gümüşsu → Cinervik/Argenfon → Lucid Triton → Elymsyr → Gizli Liman → Votumar → Ravenhall. Hiyerarşi `parent_location_ref` ile |
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
`BundledWorldsInstaller` görür. **Aegis oraya eklenmedi** — o ayrı bir karar.
CI'daki `bundled_worlds_blueprint_test` yine de aegis'i geziyor: manifest
listesinin yanında `aegis/` paket kökünü de dolaşır.

Kurulum yolu şimdilik **diskten içe aktarma**: Admin → *Import world folder* →
`assets/worlds/aegis/aegis-act1` klasörünü seç. `BundledWorldsInstaller
.installFromDirectory` klasörü paketlenmiş dünyayla aynı düzende okur
(`manifest.json` + blueprint'ler + `media/`), build almadan kurar ve
`installed_from: assets` damgalar — yani bundled toggle'ının kaldırma yolu
bunu da temizler.

Depoyu klonlamadan taşımak için aynı klasörün zip'i de burada duruyor:
[`aegis-act1.zip`](aegis-act1.zip). Aç, çıkan `aegis-act1/` klasörünü seç —
zip'in kökünde klasörün kendisi var, içeriği değil. `aegis-act1/` klasörünün
birebir kopyasıdır (blueprint + `.pkg.json` + `manifest.json` + `media/`);
blueprint ya da medya değişirse zip'i yeniden üret:

```bash
cd flutter_app/assets/worlds/aegis && rm -f aegis-act1.zip && zip -r -X -9 aegis-act1.zip aegis-act1
```

### 4.8 Yazılan kartlar (0.8.2)

**0.8.2 (2026-09-15).** Yeni kart yok. **Gizli Liman'da insan yazılmaz, yalnız mal** — Sicim'in
defteri hangi geminin ne getirdiğini ve ne ödediğini yazar; limanda silinen satır yok. Sekiz kartın
metni değişti (`npc/Sicim` · `location/Gizli Liman` · `quest/Nereden Geldiler` · `lore/Sancak Kaydı` ·
`lore/Fihrist` · `npc/Vinç Ustası` · `background/Arşivci` · `scene/Limana Kabul`).
Vinç Ustası parayla silmenin fiyatını artık bilmiyor. Kanon: [`act1.md` §9 madde 43](lore/canon/act1.md).
Yazılmayı bekleyen işler: [`yapilacaklar.md`](yapilacaklar.md).

**0.8.1 (2026-09-15).** Yeni kart yok. Silmenin parasını *Kader*'in kaptanının verdiği
bilgisi `npc/Sicim`, `location/Gizli Liman` ve `quest/Nereden Geldiler`'den çıktı — üçlüyü
*Kader* getirdi, kimin ödediği yazılmıyor. `npc/Başkumandan`'ın refakatçi teklifi silindi.
Kanon: [`act1.md` §9 madde 41–42](lore/canon/act1.md).

**0.8.0 (2026-09-14) — durum turu (karar A3).** Yeni kart yok, adı değişen kart yok;
**26 kartın metni** olay takviminden durum anlatımına çevrildi. Üçlü artık *"8 puan,
şafakta döner"* değil **son aşamaya geçmek üzere** — dönüşümün anı DM'in; iki *Şafak*
kartı adını korudu ama içlerinde saat yok. Corvin **ara ara köye uğrar**, Halim **sağ
dönerse** anlatır, Orvan'ın teklifi zorla ulaşmaz — elinde duran bir olasılık; Meclis'in
kesin reddi de sahneden çıktı. **Kadife kimseyi Meclis'e yollamıyor**; limanda bir lonca
eli olarak kaldı. `curse/Blight — Enfeksiyon`'a **Genel seyir** eklendi: yaklaşık bir
hafta kuluçka, genelde bir ay ilerleme, sonunda ölüm ya da tam dönüşüm. Hastalık Puanı
oyuncu karakterinin sayacı olarak aynen duruyor. Kanon:
[`act1.md` §9 madde 38–40](lore/canon/act1.md), [`lonca-sehir.md` §6.2](lore/canon/lonca-sehir.md).

**0.6.9 (2026-09-13) — İrade Yemini sadeleştirildi.** Üç madde, üçü de yemini SRD
paladininin önüne geçiren şeyleri geri alıyor: alt sınıf **1. seviyeden 3'e** taşındı
(artık SRD 5.2.1 iskeletiyle uyumlu ve dünyadaki tek 2014-şekilli özgün seviye kapandı),
`trait/Yeminin Ağırlığı`'nın **+1 Dayanıklılık** bonusu **kaldırıldı** (**+1 Güç** ve
History + Investigation yetkinliği kalıyor — iki puan birden yarım feat ediyordu), ve
3. kademe yemin büyülerinden
***Shield of Faith* çıkarıldı** — o seviye zaten Yeminin Ağırlığı, Yemin Darbesi ve
Channel Divinity taşıyor. Yemin Darbesi de 1'den 3'e taşındı, yani yeminin verdiği her
şey tek bir seviyede açılıyor. **Act 1 sonucu:** perde 1–2. seviye olduğu için yemin
Act 1 boyunca **hiç açılmıyor** — paladin perde boyunca SRD Paladin'i olarak oynanır ve
yemin perdenin ödülü olur. Kart sayısı değişmedi; `campaign/Aegis` ile
`lore/İlahi Büyü Listesi` metinleri buna göre düzeltildi.
Sapma defteri [`alt-siniflar.md` §6.3](lore/canon/alt-siniflar.md).

**0.6.7 (2026-09-13) — Siper Okulu.** Wizard'a Aegis'in kendi alt sınıfı yazıldı:
**`subclass/Siper Okulu`** ([`alt-siniflar.md` §4](lore/canon/alt-siniflar.md)),
3. seviyede açılan, kademeleri **3/6/10/14** olan — yani SRD 5.2.1 iskeletiyle birebir
uyumlu — bir abjuration okulu. Gerekçe çağrı zarının ikinci sonucu: kural Cleric'i
oynanamaz yapınca masada **güvenilir iyileştirici** kalmadı, ve bu okul boşluğu
iyileştirerek değil **hasarı aldırmayarak** kapatıyor. `2 × seviye + Zeka` canlık bir
**Siper**, 6. seviyede o siperi 30 ft içindeki dostlara uzatan bir tepki, 10'da
*Counterspell*/*Dispel Magic* hattı, 14'te büyü direnci. Verdiği hiçbir şey **çağrı zarı
istemez** — arkana güç zara girmez. Sapma defteri
[`alt-siniflar.md` §6.4](lore/canon/alt-siniflar.md).

**0.6.8 (2026-09-13) — siper dengelendi.** Siper ilk taslakta 0 canda *bekliyor* ve
bonus aksiyonla yuva yakılarak *doldurulabiliyordu*; bu onu sınırsız bir yuva-can
pompasına çeviriyordu. Yeni hâli: elle doldurma **kaldırıldı**, siper canı 0'a
düştüğünde **kırılır**, ve **uzun dinlenmede bir kez** örülür. Buna karşılık *ne zaman*
örüleceği artık oyuncunun kararı — `creature-action/Siperi Ör` (**Free** aksiyon,
uzun dinlenmede yenilenir) ve `pool:siper` sayacı bunun için eklendi. Abjuration
büyüsü şartı aynen duruyor: siper havadan örülmez, mutlaka bir yuva harcanmış
1. kademe+ abjuration büyüsünün sırtında kurulur. Ayaktayken beslenmesi kendiliğinden
sürüyor. **+2 kart:** `creature-action` +1 · `resource-pool` +1.

**Toplam +8 kart:** `subclass` +1 · `trait` +4 · `creature-action` +2 ·
`resource-pool` +1.

**0.6.6 (2026-09-13).** Kart listesi görevin kendi kartına indi. Üç görevin de
`objective` alanı **Bu görevde geçen kartlar** bölümüyle bitiyor: sahneler, mekanlar,
NPC'ler rolüne göre öbeklenmiş, çatışma ve yaratıkları, eşyalar, kural ve kurum kartları,
ve zincirin komşu görevleri — hepsi masada görevi açan DM'in gözünün önünde, ayrı bir
karta gitmeden. `lore/Fihrist` yerinde duruyor ve bölümlerin sonundan link alıyor; artık
görevler arası dolaşmak için, zincirin kendi kartları için değil. Görev `dmNotes`'ları
buna göre kısaldı. **Kart sayısı değişmedi.**

**0.6.5 (2026-09-13).** Kart aramayı bitiren tek kart: **`lore/Fihrist`**, yedi sayfa.
2–4. sayfalar üç zinciri (`Söylentinin Peşinde` · `Nereden Geldiler` · `İyi Yazı`) sahne
sırasıyla açar ve her zincirde geçmesi muhtemel bütün kartları — mekan, NPC, sahne, çatışma,
eşya, kural — kategori kategori sayar; 5. sayfa 18 mekanın dünya → kıta → yer ağacı ve
sahneleri, 6. sayfa dokuz background ile üç alt sınıf ve eşyaları, 7. sayfa kural ve kurum
kartları. Sayfalarda sır yok, hepsi kartların açık alanlarından; sırlar kendi kartlarının
`secrets` alanında kaldı.

Kart üç yerden bulunur: `pinned`'in ikinci sırası, giriş kartının *Macerayı yönetmek*
sayfasındaki **Kartlar nerede** bölümü, ve üç görev kartının `dmNotes`'u. Fihrist aynı
zamanda hiçbir kartın link vermediği dört kartı zincire bağlar — `subclass/Clockwork Soul`,
`subclass/Drakewarden`, `animal/Drake`, `lore/İlahi Büyü Listesi`. **+1 kart:** `lore` +1.

**0.6.4 (2026-09-13).** Yeni kart yok, bir bağ eksiği kapandı: **Halim** hiçbir
mekan kartında geçmiyordu, yani kartı olan ama ulaşılamayan bir NPC'ydi.
`location/Gümüşsu` artık dördüncü yabancıyı sayıyor (*"üç yabancı"* → üçü kulübede,
dördüncüsü hanın üst katında ve hasta değil) ve *Kim var* listesinde Halim var;
`location/Goodbarrel'ın Ocak Başı`'nda üst kattaki iki odadan birinin dolu olduğu
yazıyor. Kanon ([`act1.md` §3.5](lore/canon/act1.md)) bunu zaten söylüyordu.

Görseli olmayan iki kart kaldı — `npc/Halim` ve `creature-action/Sıçrayıp Isırma`;
prompt'ları hazır, bkz. [`tool/aegis_art/README.md` §6.1](../../../../tool/aegis_art/README.md).

**0.6.3 (2026-09-13).** Dönüşmüş'lere üçüncü bir eylem: **Sıçrayıp Isırma**
(*yeniden şarj 5–6*, 15 ft sıçrayış, saldırı zarı yok, 1d8 delici, ardından **CON DC
8** → +1 Hastalık Puanı). Bulaşma buraya taşındı — pençe hâlâ bulaştırmıyor, ısırık
bulaştırıyor, ve `curse/Blight — Enfeksiyon`'un maruziyet yolları yeniden dört.

Aynı turda **Kadife** yeniden yazıldı ([`act1.md` §7.4](lore/canon/act1.md)): artık
zincirde durmayan bir süs değil, **DM'in kolu.** Karakterler rıhtımda üç yabancıyı ya
da *Kader*'i konuşmaya başlayınca o gelir, *"bunu kime anlatacaksınız"* diye sorar ve
onları Meclis'e yollar — *"önce onlar duymalı."* Lonca adı masada hiç geçmediyse o adı
ilk koyan sahne budur; geçtiyse acele ettiren sahne. İz uzamıyor, Custar katmanı hâlâ
kapalı. **+1 kart:** `creature-action` +1.

**0.6.2 (2026-09-13) — denge turu.** Üç Dönüşmüş masada fazla güçlüydü. Jenerik
**Dönüşmüş** ve **Dönüşmüş Kromanna** (tiefling) AC **11** / HP **16**'ya, **Dönüşmüş
Alton** ve **Dönüşmüş Merla** (halfling) AC **9** / HP **12**'ye indi; CR'ler 1/2 · 1 →
1/8 · 1/4. Dört ayrı pençe kartı **ikiye** indi — `Pençe Saldırısı` (+2, 1d4) ve
`Güçlü Pençe Saldırısı` (+2, 1d8); isabet bonusu hepsinde **+2**, hasarda yetenek
modifikatörü yok. **Pençe artık hastalık bulaştırmıyor:** `trait/Bulaştıran Yara`
kaldırıldı, `curse/Blight — Enfeksiyon`'un maruziyet yolları dörtten üçe indi ve
`encounter/Şafak Çatışması` `Low` / **100 XP** oldu.

Aynı turda **Corvin** ([`act1.md` §3.6](lore/canon/act1.md)) ve **Fare**
([`act1.md` §7.4](lore/canon/act1.md)) yazıldı: Corvin köyün *yabancısı ama sevilen*
adamı, köyün dışarıyla alışverişi onun sırtından yürür ve köy Gizli Liman'ı bilmez;
dönüşüm sabahı şafaktan **birkaç saat önce** köye döner ve **ölürse kıyı yolu kapanır**.
Fare kendisine *Fare* denmesinden hoşlanmaz — ona **Sincap** diyen tek kişi Corvin.
**−3 kart:** `creature-action` −2 · `trait` −1.

**0.6.0 (2026-09-13) — ilahi büyü turu.** `mekanikler.md` §3 yeniden yazıldı: her ilahi
büyü bir **çağrı zarı** ister (`d20 + Religion`; çatışmada 19, çatışma dışında saat içinde
18 → 20 → doğal 20 → imkansız), başarısızlık yuvayı ve çatışmada aksiyonu harcar. Kapsam
**Cleric · Warlock · Paladin'in ilahi büyüleri**; Druid/Ranger dışarıda. İki sonuç kartlara
girdi: **Cleric ve Warlock bu kıtada oynanmaz** (giriş kartının *Karakter yaratma* sayfası
bunu söylüyor) ve Paladin için Aegis'in kendi alt sınıfı yazıldı —
**İrade Yemini** ([`alt-siniflar.md` §3](lore/canon/alt-siniflar.md)), 1. seviyede açılan,
gücü yeminden gelen, +1 Güç / +1 Dayanıklılık ve History + Investigation veren, Divine
Smite yerine **Yemin Darbesi** koyan ve hiçbir kullanımı zar istemeyen bir yemin.

Aynı turda: Gümüşsu'ya **Halim** eklendi (Sınır ve Ticaret koltuğunun duruma bakması için
yolladığı adam — izci giyimli, savaşmaz, kaçar, ve her hâlde geri döner); ve
[`act1.md` §5](lore/canon/act1.md) **akış olmaktan çıkıp dünyanın saati olarak** yeniden
yazıldı: *"şafakta üçü döner, oyuncular orada olsun olmasın"*, sonrası iki **hâl** — köy
ayakta ya da kırılmış. Oyuncunun ne yapacağını varsayan cümleler (*"doğal seçim"*,
*"yolda karşılarına çıkar"*) kanondan ve iki sahne kartından çıkarıldı. **+10 kart:**
`npc` +1 · `subclass` +1 · `trait` +6 · `resource-pool` +2.

`aegis-act1/world-blueprint.json` — **164 entity**, 2026-09-13. Aşağıdaki tablo 0.4.0'ın
125 kartını sayıyor; 0.5.x alt sınıf turunu ve 0.6.0'ı eklemek için
[`kart-listesi.md` §Sayım](lore/canon/kart-listesi.md)'a bak. Kapsam
[`lore/canon/kart-listesi.md`](lore/canon/kart-listesi.md)'nin **tamamı**; `🟡` olanlar
dahil (bir kartı 🟡 yapan şey tek bir alan, ve o alan boş bırakıldı).

**0.2.0'dan farkı:** paket `e917f024`'te silinmişti ve kanon ondan sonra iki kez
değişti (Blight → Hastalık Puanı + beş aşama; Greater Restoration artık kaldırmıyor).
0.3.0 güncel kanondan **sıfırdan** yazıldı, eski metin kullanılmadı.

**0.4.0 (aynı gün): bütün kartlar §6.7 üslubuyla yeniden yazıldı.** 0.3.0 kanonun tasarım
dilini taşıyordu ("açtığı kapı", "taşıyıcı", "masa", "bir yer değil bir durum"). 0.4.0'da
oyuncuya okunan alanlar (`location.description_long` açılışı, `scene.description`,
`encounter.setup`, monster açılışları) blockquote, şimdiki zaman, görme dışında en az bir
duyu ve oyuncuya devredilen bir sonla yazıldı; DM metni WotC modülü sesiyle ("Karakterler
sorarsa…"). Mekanlara bölüm bölüm tasvir, NPC'lere yaş/beden/giysi/koku/ses ve örnek
replik eklendi. **Kayıt vurgusu azaltıldı:** "kayıt/kayd" 202 → 24 geçiş; kayıt yalnız
hikayenin gerçekten kullandığı yerlerde (silinen sayfa, gümrük, Sancak Kaydı kartı).

| Kategori | Adet | Ne |
|---|---|---|
| `campaign` | 1 | Aegis — 5 sayfa (giriş kartı) |
| `lore` | 20 | Çağ ve din (2) · Blight/Vorstrand (2) · Konsey ve Sancak Kaydı (2) · altı lonca (6) · doktrin ve toplum (4) · düzenler (3) · Kural Sapmaları (1) |
| `location` | 18 | Dünya → kıta → yer zinciri eksiksiz; güzergahın tamamı + Meclis Salonu |
| `npc` | 34 | Gümüşsu (4) · kulübe (3) · liman (6) · Meclis (6) · şehir sokağı (5) · Elymsyr (4) · Votumar (4) · Ravenhall (2) |
| `monster` | 4 | Jenerik Dönüşmüş + üç adlandırılmış hâli |
| `creature-action` | 4 | Pençe'nin dört sürümü |
| `trait` | 5 | Acıyı Tanımaz · Bulaştıran Yara · üç belirti hattı |
| `curse` | 1 | Blight — Enfeksiyon (Hastalık Puanı, beş aşama, Yozlaşma Kontrolü dahil) |
| `scene` | 11 | Gümüşsu (3) · liman (2) · şehir (3) · Elymsyr · Votumar · Ravenhall |
| `encounter` | 1 | Şafak Çatışması |
| `quest` | 2 | Söylentinin Peşinde · Nereden Geldiler |
| `background` | 9 | Dokuz kurumsal background, mekanikleri SRD ref'i |
| `adventuring-gear` | 8 | Yedi background eşyası + Direnç Şerbeti |
| `trinket` | 7 | Dört mühür + rozet + künye + Mühürsüz Yüzük |

**125, 127 değil.** `kart-listesi.md` başlıkları 22 `lore` ve 18 `location` diyor; tabloları
21 ve 17 satır sayıyor. 18. lokasyon **Meclis Salonu** (§8'in iki sahnesinin yeri) ve
yazıldı; 22. `lore` yok. `Kayıt Nasıl İşler` 0.4.0'da ayrı kart olmaktan çıktı, `Sancak
Kaydı`'nın ikinci sayfası oldu. `quest/Silinen Sayfa` 2026-09-10'da geri alındığı için
yazılmadı. Sahne `Gümrükte Kayıt` → `Gümrük Rıhtımı`; pinlenen `lore/Sancak Kaydı` →
`location/Gümüşsu`.

**Kanon içi iki çelişki `act1.md` lehine çözüldü:** maruziyet DC'si **12** (`kart-listesi`
8 diyor), Bulaştıran Yara DC'si **8** (`kart-listesi` 12 diyor).

Kartların içinde "kanon değil" işareti yok (§6.0). Türetilmiş sayılar, yorumlar, read-aloud
dokusu ve bilerek yazılmayanlar: [PROVENANCE.md](PROVENANCE.md) §Yorum ve türetme.

**On NPC unvanla yazıldı** (Elymsyr'in dördü, Votumar'ın dördü, Ravenhall'ın ikisi):
ad kararı verilince tek `name` değişikliği ve link grep'i yeter.

---

### 4.9 `pinned` ve `shared` — blueprint'in iki ref listesi

`world-blueprint.json`'ın kökünde iki liste var, ikisi de `kategori/isim`
yazılıyor ve kurulumda entity id'lerine çözülüyor
(`BundledWorldsInstaller`, `world_settings.settings_json` blob'una yazar):

```json
"pinned": ["campaign/Aegis", "lore/Fihrist", "..."],
"shared": ["subclass/İrade Yemini", "background/Arşivci", "..."]
```

| Liste | Ne yapar |
|---|---|
| `pinned` | Kartı sidebar'ın üstüne sabitler. Sadece DM'i ilgilendirir. |
| `shared` | Kartı **oyuncularla paylaşılmak üzere işaretler.** Dünya çevrimdışıyken de durur; dünya multiplayer yapıldığı anda tam olarak bu set oyunculara gider, kategoriye göre otomatik paylaşım **yok**. |

Yazım hatası ikisini de sessizce düşürür — `bundled_worlds_blueprint_test`
her iki listenin her ref'ini id'ye çözüp entity'de arar.

**`shared` ölçüsü: Tier 0/1 oyuncu içeriği, başka hiçbir şey.** Listeye yalnız
**oyuncunun karakterini kurmak için** gereken kartlar girer:

| Girer | Girmez |
|---|---|
| `subclass` · `background` · `trait` · `resource-pool` · `adventuring-gear` · `trinket` | **Bütün Tier 2 kategorileri:** `campaign`, `lore`, `location`, `npc`, `scene`, `encounter`, `quest`, `curse` |
| | `monster` · `animal` · `creature-action` · `magic-item` (motorun `seedExcludedSlugs` seti — canavar ve loot DM'de kalır) |

**Tier 2 asla paylaşılmaz.** O kartlar DM odaklı yazılıyor ve oyuncunun henüz
bilmediğini bildirirler: `lore/İlahi Büyü Listesi` ilahi büyünün mekaniğini,
`lore/Blight — Bilinen Hali` hastalığın adını, `campaign/Aegis` perdenin
kurgusunu açar. Kart "oyuncuya dönük" görünse bile Tier 2'yse girmez — DM
masada, zamanı gelince, kartın menüsünden paylaşır.

**Tier 1 içinde de sır taşıyan kart paylaşılmaz.** Kategori yeterli değil,
karta bak:

- `adventuring-gear/Direnç Şerbeti` — **dışarıda.** Var olduğunu bilmek
  hastalığa karşı bir şeyin işe yaradığını bilmek demek.
- `trinket/Sahte Mühür` · `Mühürsüz Yüzük` · `Emir Mührü` — **dışarıda.**
  Sahtecilik, Kromanna'nın cebindeki ipucu ve makam emri; üçü de oyunda açılır.
- Canavarların `trait`'leri (`Acıyı Tanımaz`, `Durmayan Adım`, `Kesik Kesik`,
  `Erken Güçlenme`) — **dışarıda.** Kategorileri Tier 1 ama sahipleri
  `monster`.

Act 1'de bu ölçü **54 kart** veriyor: 4 subclass · 9 background · 21 trait ·
9 resource-pool · 7 gear · 4 trinket.

**Yeni kart eklerken bu kararı da ver.** Sırayla: Tier 2 mi → ekleme. Tier 1
ama canavar/loot mu → ekleme. Kart oyunda açılacak bir şeyi ele veriyor mu →
ekleme. Geriye kalan, oyuncunun karakter yaratırken önünde olması gereken
şeydir → ekle. Kararsız kalırsan paylaşma: DM masada tek tıkla paylaşabilir,
ama geri alınan bir sürpriz geri gelmez.

## 5. Faz planı

| # | Faz | Çıktı | Bitti sayılma koşulu |
|---|---|---|---|
| 0 | **M0 kilidini kapat** (§3) | Karar listesi | Kıta adı ✅ · Gümüşsu ✅ · pre-gen seti ✅ · #8 tonu ✅ · kalan: M0.2/M0.3/M0.6 |
| 1 | Kanon damıtma | `lore/canon/` — çelişkisiz Act 1 kanonu (kronoloji, fraksiyonlar, bilgi eğimi) | 🟡 Dört belge yazıldı (§2). Kalan: kronoloji tablosu · fraksiyonlar |
| 2 | Lokasyonlar | Güzergahın tamamı, `location` + `parent_location_ref` | ✅ 18 lokasyon, dünya → kıta → yer zinciri kırılmadan |
| 3 | Fraksiyon + NPC | `lore` (fraksiyonlar) + `npc` | ✅ 34 NPC · altı lonca `lore` kartı. **İki taşıyıcı kuralı her hatta sağlandı.** 10 NPC unvanla yazıldı, adı bekliyor |
| 4 | Sahne / encounter / quest | `scene`, `encounter`, `quest`, `trap` | ✅ 11 sahne · 1 encounter · 2 quest (trap yok — kanonda tuzak yok). Hiçbiri belirli bir PC'ye bağlı değil |
| 5 | Campaign + lore sayfaları | `campaign.pages[]` | ✅ 5 sayfalık giriş kartı + 20 `lore` kartı. Sansürlü resmi tarih ayrı kart olarak yazılmadı |
| 6 | Pre-gen'ler | `blueprint.json` | Dört yuva, dört karakter — yazılmadı |
| 7 | Medya + paketleme | `media/*.webp`, `.pkg.json` | 🟡 `PROVENANCE.md` ✅ · `--check` temiz ✅ · medya yok · `.pkg.json` modül dizinine yazılmadı (§4.7 komutuyla üretilir) |

Bir faz kapanmadan sonrakine geçilmez (10 · Çalışma Ritmi).

---

## 6. Yazarken uyulacak ilkeler

0. **Kart son ürün gibi yazılır.** Kartı yazarken evrenin tamamı varmış gibi yaz:
   bu Aegis'in kendisidir, bir yazım sürecinin ara çıktısı değil. Kart gövdesinde
   **"Act 1" / "birinci perde" / "şimdilik" / "sonraki turda" geçmez**, ve
   **hiçbir belgeye atıf yapılmaz** — ne bu README'ye, ne `lore/canon/`'a, ne
   arşive, ne bir karar numarasına. Okuyan DM bu klasörü hiç görmemiştir; elinde
   yalnız kart vardır. Kapsam kararları (neyin yazılıp neyin yazılmadığı) burada
   ve `kart-listesi.md`'de kalır, kartın içine girmez. Örnek için diğer dünyaların
   `world-blueprint.json`'larına bak (ör. `99_devils_of_uzrahs_palace_shadowdark`):
   hiçbir kart kendi yazım sürecinden söz etmiyor.

1. **DM Kitabı önce yazılır**, Oyuncu Kitabı ondan damıtılır → app'te bu
   `secrets` alanı ayrımıdır. Kartın **bütünü** oyuncuya açılacak mı sorusu ayrı
   bir karar: her yeni kartta blueprint'in `shared` listesine girip girmeyeceğine
   de karar ver (§4.9). Ölçü dar — yalnız **Tier 0/1 oyuncu içeriği** (subclass,
   background, trait, havuz, sıradan eşya) girer; **Tier 2 asla** (campaign, lore,
   location, npc, scene, encounter, quest, curse), canavar ve loot da asla.
   Tier 1 bir kart oyunda açılacak bir şeyi ele veriyorsa yine girmez. Kararsız
   kalırsan ekleme; DM masada tek tıkla paylaşır, ama paylaşılmış bir sürpriz
   geri alınmaz.
2. **Tarih bugüne varmak için kurgulanmaz.** Her büyük olayın en az bir
   istenmeyen sonucu var; boşa giden şeyler var; kimse "kötü olduğu için"
   hareket etmiyor.
3. **Hikaye belirli karakterlere bağlanmaz** — rol yuvaları.
5. **Taban DnD 5e**, ikincil referans Forgotten Realms. Sapmalar (Blight
   kuralları, ilahi büyünün durumu) açıkça işaretlenir; sıfırdan sistem yazılmaz.
6. **Gerçekçilik iddia edilmez, hissettirilir.** "Bu dünya gerçekçidir" cümlesi
   metinde geçmez.

7. **Anlatım üslubu: WotC modülü read-aloud'u** (karar A1). Ölçü, resmi 5e
   modüllerinin yüksek sesle okunan metnidir: sahne kurulur, duyusal detay verilir
   (koku, ses, ışık, sıcaklık), gerilim ortamdan okunur ve metin **oyuncunun
   hamlesine bırakılarak** biter. Tolkien'in kadim/destansı üslubu bu dünyanın
   üslubu **değil**.

   - **Somut ol.** Sıfat yığmak yerine sayılabilir ayrıntı ver: "beş kapıda
     tebeşir işareti var, altıncıda yok" > "kapılar uğursuz işaretlerle doluydu".
   - **Aktif ve şimdiki zaman.** Pasif anlatı ve "…mişti" yığını yok.
   - **Duyulardan en az ikisi** her açılış metninde geçer, ve biri görme olmasın.
   - **Metin oyuncuya devredilir.** Okunan parça bir soruyla ya da bekleyen bir
     durumla biter; DM oyuncunun ne hissettiğini yazmaz.
   - **Tarih metnin içinde anlatılmaz.** Geçmiş, bugün ortada duran bir nesne
     olarak görünür (yıpranmış ama bu kıtada dokunmamış kumaş gibi). Kadim
     ağırlık lore kartlarında ve `secrets` alanlarında taşınır, read-aloud'da
     değil.
   - **Klişe yasağı:** zorlama dramatik giriş ("Kader sizi buraya getirdi"),
     üst üste üç sıfat, ve "hava ağırdı / kan donduran / kadim bir kötülük"
     kalıpları kullanılmaz.
7. **Onaylanmamış içerik ana metne girmez (2026-09-10).** Kanonda (§0 hiyerarşisi)
   veya §3'te karara bağlanmamış bir görev, NPC, mekan ya da olay örgüsü **asla**
   doğrudan kart olarak yazılmaz — bu §4.8'in "kanon dışı uydurma yok" kuralının
   (§4.8 madde 1) tekrarı, gevşetilmesi değil. Yeni bir yan görev / kırılma anı /
   detay fikri varsa kartın içine değil, ilgili notun sonuna **"Öneri / Fikir:"**
   başlığıyla yazılır ve elymsyr'e sorulur; onay gelmeden hikâyeye kesinleşmiş gibi
   girmez.
8. **Durum yaz, olay takvimi yazma (karar A3, 2026-09-14).** Kart DM'e bir *hâl*
   verir: kim nerede, ne istiyor, ne biliyor, hastalık hangi eşikte. Ne zaman ne
   olacağına DM masada karar verir; biz çok karışmayız.
   - **Saat bağlama.** *"Şafakta"*, *"ertesi gün"*, *"birkaç saat önce döner"* gibi
     zamanlanmış olay yazılmaz. Yerine eşik ya da alışkanlık yazılır: *"son aşamanın
     eşiğinde"*, *"ara ara köye uğrar"*.
   - **Sonucu önceden yazma.** *"Köy ayakta çıkar"*, *"iki makam da reddeder"*,
     *"teklif yine ulaşır"*, *"her hâlde geri döner"* yazılmaz. NPC'nin tutumu ve
     çıkarı yazılır; sonuç masada çıkar.
   - **Sahne bir olasılıktır.** Sahne kartı *"bu olur"* değil *"bu olursa böyle
     oynar"* der. Görev ve fihrist kartlarında sahneler olay sırası gibi numaralanmaz (bir işin
     mantıksal adımları — önce imza, sonra karşı-imza — hariç).
   - Kilitlenme kuralı (§2) aynen geçerli: bir kapının iki taşıyıcısı olması, bir
     NPC'nin kapıyı oyuncuya zorla getirmesinden iyidir.
