# Mekanikler — 5e'nin Üstüne Eklenenler

> **Durum: kanon.** README §0 hiyerarşisine bağlıdır.
> [`act1.md`](act1.md) Blight'ın kural kartını yazdı; bu belge **geri kalan kural
> sapmalarını** kanona alıyor: büyünün toplumsal yeri, lisans, ilahi büyünün
> hissiyatı, diriltmenin bedeli, ışınlanma, yozlaşma, simya ve kalıcı yaralar.
>
> Dayanak: `lore/archive/YAKIN TARİH VE OYUN MEKANİKLERİ 1.pdf` §Aşama 1–2 (`YT`) ·
> `lore/archive/AETHELGARD- İRADENİN SON ADASI.pdf` §3.3, §4 (`AE`) ·
> [`lonca-sehir.md`](lonca-sehir.md) §2, §4, §5 · [`act1.md`](act1.md) §4 ·
> 02 §5.3 · 06 #11 · 10 M1.
>
> **Filtre kuralı (Yönerge §4, README §0):** `YT` ve `AE` birer **PDF**, yani
> hiyerarşinin en altı — MD ile çeliştiğinde MD kazanır. Bu belgeye giren her madde
> o testten geçti; **düşenler §10'da isim isim yazılı** ve kanon değil.

**Sapma işareti zorunlu** (Yönerge §3.3, README §6.5): aşağıdaki her kural 5e'nin
üstüne eklenmiştir ve kartında böyle işaretlenir. Sıfırdan sistem yazılmadı —
hepsi mevcut 5e nesnelerine (slot, kurtarma zarı, exhaustion, Can Zarı) bağlanıyor.

---

## 0. Türetme ilkesi — kural, dünyanın kendi cümlesini tekrar etmeli

Bu belgenin tek testi şu: **bir kural, bu dünyada zaten doğru olan bir şeyi
mekaniğe çeviriyor mu?** Çevirmiyorsa girmiyor, ne kadar iyi bir kural olursa olsun.

Üç örnek:

- **Lisans** giriyor, çünkü [`lonca-sehir.md` §0](lonca-sehir.md) zaten *"kaydı kim
  tutuyorsa o yönetir"* diyor. Büyü lisansı bir defter satırıdır; kural sadece o
  satırın fiyatını yazıyor.
- **Diriltmenin bedeli** giriyor, çünkü bu dünyada tanrılar 300 yıldır cevap
  vermiyor (`lore/İrade Çağı`). Bedava diriltme, hikayenin omurgasını yalanlar.
- **Hastalık Puanı sistemi girmiyor**, çünkü `act1.md` §4 hastalığı üç **evreye**
  bağladı ve o karar bu belgeden üstün. Aynı hastalık iki sayaçla ölçülemez.

---

## 1. Büyünün toplumsal yeri

Üç katman, ve üçü birbirini tanımıyor:

| Katman | Büyü nedir | Sonucu |
|---|---|---|
| **Şehir ve akademi** | Lonca eliyle disipline edilmiş **akademik bir kariyer** | Büyücü olmak bir meslektir; ustası, çırağı ve defteri vardır |
| **Ordu** | "Savaş Büyücüsü" — stratejik ve **korunması gereken** bir azınlık | Sayıları az; kaybedilmesi bir mevzi kaybından ağırdır |
| **Kırsal** | Bir **tuhaflık**, bazen korkulan bir figür | Köyde büyü yapan adam yardım etse de yabancıdır |

Bu, `act1.md` §3.3'ün beşinci izini (Arcana DC 13) kendiliğinden açıklıyor:
Gümüşsu'da o izi görebilecek ikinci bir insan yok, çünkü köyde büyüyü bilen kimse
yok. Şehirde bu iz **altı kişinin** işi olurdu.

**Sihir Loncası Öğrencisi** background'ı (`act1.md` §2) buraya oturuyor: öğrenci,
kariyerin ilk basamağıdır ve kariyerin her basamağı kayda geçer.

---

## 2. Lisans ve yasak — büyü bir defter satırıdır

**Büyücü Loncası'nın tekeli** ([`lonca-sehir.md` §2](lonca-sehir.md)) üç şeydi:
izinli büyü, akademi, ışınlanma kaydı. Üçünün de mekanik karşılığı var.

> **Lisans:** şehir sınırları içinde büyü yapmak **Lonca Lisansı** gerektirir.
> Lisanssız büyü, "kamu güvenliğini tehdit" suçudur.

- **Kim yazar:** lisansı Büyücü Loncası verir; **suçu Askeri Hukuk Loncası** yazar
  (suç sicili onun defteri, [`lonca-sehir.md` §2](lonca-sehir.md)). Yani lisanssız
  bir büyücü iki loncaya birden borçlanır — bu, tek bir zarla çözülen bir sorun
  değil.
- **Nerede işler:** yalnız şehirde. Köyde, yolda, limanda lisans sorulmaz — çünkü
  soracak masa yok. **Gizli Liman'da lisans bir şaka**, ve orada büyü yapmak kimseyi
  ilgilendirmez (`act1.md` §7).
- **Cezası:** hapis değil (`AE §3.2`); kamu hizmeti, para, ve sicile bir satır.
  Sicildeki satır cezanın kendisinden ağırdır: bir daha lisans alamaz.

**Yasaklı iki okul — istisnasız:**

| Yasak | Neden bu dünyada özellikle ağır |
|---|---|
| **Necromancy** | Ölüm sebebi beyanı Simya ve Şifacılar Loncası'nın defteridir. Ölüyü kaldıran adam bir defteri yalanlıyor |
| **Zihin kontrolü içeren Enchantment** | Bu kıtanın kurucu cümlesi iradedir (`lore/İrade Çağı`). İradeyi elinden alan büyü, doktrine karşı işlenmiş bir suçtur |

İkisi de "lisansla yapılabilir" listesinde **yok** — lisans genişletilerek
alınamaz. Bilen biri bulunur, ve bulunduğu yer şehir değildir.

> **Masadaki karşılığı:** bu iki okulu oynayan bir PC yasadışı değil, **kayıtsız**
> olur. Sancak Kaydı'nın diliyle: büyüsü onu *Yazısız* yapar
> ([`lonca-sehir.md` §9](lonca-sehir.md)).

---

## 3. İlahi büyü — "Yankılanan Sessizlik"

`lore/Tanrılar ve Fısıltı` kartının mekanik yüzü. Üç cümle, üçü de kanon:

1. **Tanrılar pasif, ama sağır değil.** İlahi büyü yapılabiliyor ve **çok kişi
   yapıyor**. Kural tek yönlü: *biri ilahi büyü yapabiliyorsa, tanrılar ona cevap
   vermiş demektir.* Cevabın sebebi söylenmez, sorulmaz ve garanti edilmez.
2. **Şifa huzurlu değil.** Şifa büyüsü hem yapana hem alana **fiziksel ağırlık ve
   yorgunluk** hissettirir: kemikte bir basınç, sonrasında geçmeyen bir yorgunluk.
   Mekanik yükü yok — anlatı kuralı. Bu dünyada kimse iyileştirilmeyi "ferahlatıcı"
   diye tarif etmez.
3. **Kutsal sembol bir anten.** Aksesuar değil; ilahi enerjiyi **odaklayan** bir
   alet. Kaybedilen sembol, kaybedilen bir bileşen değil kaybedilen bir **hat**.

**Toplumsal yüzü değişmedi** ([`lonca-sehir.md` §5](lonca-sehir.md)): ilahi büyü
yapan biri mucize değil **usulsüzlük** olarak okunur. Bu ikisi çelişmiyor — tanrı
cevap veriyor, ve şehir cevabı kayda geçirecek bir satır bulamıyor.

> **Paladin Askeri** ve **Paladin Rütbelisi** background'larının (`act1.md` §2)
> sessiz avantajı burada: Kışla Künyesi bir *Emblem*'dir, yani düzenin verdiği
> anten. Düzenden kopan paladin, antenini de bırakmak zorunda kalır.

---

## 4. Mekanik sınırlar

### 4.1 Seviye eşiği

**1. ve 2. seviye büyüler nispeten güvenlidir** ve bu belgede hiçbir ek kural
almazlar. Sapmalar 3. seviyeden itibaren başlıyor — Act 1'in tamamı (1–2. seviye
masa) bu belgenin çoğunu hiç görmez, ve bu bilerek böyle.

### 4.2 Işınlanma — mesafe bir engeldir

> **4. seviye ve üstü ışınlanma (Teleport) büyüsü, yapana 1 seviye Exhaustion
> verir.** Uzun mesafe ışınlanma **loncalar haricinde mümkün değildir.**

İki sonucu var ve ikisi de siyasi:

- **Işınlanma kaydı gerçek bir tekeldir.** Büyücü Loncası "kimin nereye gittiğini"
  tutuyor ([`lonca-sehir.md` §2](lonca-sehir.md)) çünkü uzun mesafe ışınlanmanın
  tek yolu o. Kayıt tutması bir formalite değil, **hizmetin kendisi**.
- **Haber atla gider.** Kıtasal iletişim fiziksel kalıyor (`AE §3.3`): mesafe
  tempoyu belirleyen gerçek bir değişken, ve bir yeri iki gün uzakta tutmak onu
  siyasi olarak da iki gün uzakta tutuyor
  ([`bolgeler.md` §1.5](bolgeler.md)).

### 4.3 Bileşenler

Yüksek seviye büyülerin nadir bileşenleri **Lonca izni ya da karaborsa bağlantısı**
gerektirir. Karaborsanın adresi yazılı: **Gizli Liman** (`act1.md` §7) — kıtaya
büyü malzemesi oradan sızar.

Yani her yüksek seviye büyücü, iki kapıdan birine borçludur: ya loncaya ya limana.
Üçüncü bir kapı yok.

---

## 5. Ölümün Ağırlığı — diriltme

`Revivify` ve üstü diriltme büyüleri **slot harcayarak yapılamaz.** Bu, bu
belgedeki en sert sapma ve gerekçesi dünyanın kendisi: burada 300 yıldır kimse
tanrıdan bir şey almadı.

> **Bir cana karşılık, bir can.** Diriltme başlamadan önce bedel seçilir ve
> **seçen, bedeli ödeyen olur:**
>
> - **Büyüyü yapan** kalıcı bir **Can Zarı (Hit Die)** kaybeder, **VEYA**
> - **Dirilen kişi** kalıcı bir **stat puanından** feragat eder.

**Diriltme Sınavı:** kesin başarı garantisi **yok.** Bedel ödenmiş olması sonucu
garanti etmiyor — bedel giriş ücretidir, bilet değil.

**Başarısızlıkta ruh üç halden biriyle döner:**

| Hal | Ne demek |
|---|---|
| **Eksik** | Bir şey geri gelmedi. Bir hatıra, bir yetenek, bir alışkanlık — ve kişi eksiğinin ne olduğunu bilmiyor |
| **Bozulmuş** | Geri geldi ama aynı değil. Kendi olduğunu iddia ediyor, ve masa emin olamıyor |
| **Ele geçirilmiş** | Dönen şey o değil. Bunu **DM bilir, oyuncu bilmez** |

⚠️ **Zarı ve DC'si yazılmadı — açık karar (§11).** Kanon *sınavın var olduğunu*
söylüyor, zarını söylemiyor. Kart yazılabilir; `mechanical_notes` alanı bu karar
verilmeden kilitlenmemeli.

> **Neden Act 1'i bloke etmiyor:** perdede 3. seviye üstü büyü yapan kimse yok ve
> diriltme masanın erişiminde değil. Kural masaya *tehdit* olarak girer, işlem
> olarak değil — ve tam olarak bunun için yazıldı.

---

## 6. Yozlaşma Kontrolü — büyü ile Blight'ın teması

Blight bir cephedir, iklim değil (README §1): sınırı var ve tutuluyor. Bu kural
**sınırın öte tarafında** işler.

> **Tetikleyici:** ağır Blight altındaki bir zeminde **3. seviye veya üstü** bir büyü
> yapmak. Kirlilik büyüye sızmaya çalışır.
>
> **Zar:** Constitution **veya** Spellcasting Ability kurtarma zarı — büyücü hangisini
> istiyorsa. **DC 13.** ⚠️
>
> **Başarısızlık:** büyü **gerçekleşir**, ama **Bozulma** olur: büyücü `Blight —
> Enfeksiyon`un (`act1.md` §4) **Evre 1'ine** girer. Zaten Evre 1'deyse bir sonraki
> uzun dinlenmede Evre 2 zarını atmaya başlar.

⚠️ **İki sayı türetildi, kanon değil** — `YT` DC vermiyor ve başarısızlığı "Geçici
Hastalık Puanı" diye ölçüyor; o sayaç bu evrende yok (§0). DC 13, `act1.md` §4.2'nin
Evre 2 zarıyla aynı tutuldu. Kanon bir sayı verdiğinde bu satır onunla değişir.

**Sınıfsal istisnalar:**

| Sınıf | Fark |
|---|---|
| **Druid** | Yozlaşma zarına **+2**. Doğanın hastalandığını okuyabilen tek meslek; Ravenhall'un öğrettiği şey bu ([`bolgeler.md` §4](bolgeler.md)) |
| **Paladin** | Bozulmanın **fiziksel** etkilerini daha kolay savuşturur: Evre 1'in belirtileri onda görünmez, ilerleyişi değişmez |

**Neden Act 1'de hiç atılmıyor:** perdenin tamamı cephenin **iç** tarafında geçiyor
ve masa 3. seviye büyü yapmıyor. Kural, bir sonraki perdenin coğrafyası için yazıldı.

---

## 7. Simya ve zanaat

**Şifa İksiri kıt bir maldır.** Sebep dünyanın kendisi: iksir **Simya ve Şifacılar
Loncası'nın ruhsatlı kalemi** ([`lonca-sehir.md` §2](lonca-sehir.md)). Tezgahta
bulunması bir kayıt işlemidir, ve kaydı olmayan iksir satılmaz.

- **Kim üretir:** ruhsatlı bir otacı, **ya da** Druid bilgisi olan biri, **ya da**
  Simya Seti kullanan biri. Şart: **temiz su** ve doğru bitki.
- **Masadaki sonucu:** iksir para sorunu değil **erişim** sorunu. Ruhsatlı bir
  şehirde pahalı ama vardır; taşrada parayla bulunmaz, **yapılır**. Bu, Druid'i ve
  Simya Seti taşıyan PC'yi kendiliğinden değerli kılıyor — ve `Alchemist's Supplies`
  taşıyan **Sihir Loncası Öğrencisi**'ni (`act1.md` §2) hiç ummadığı bir yerden işe
  sokuyor.

**Direnç Şerbeti (yeni kart, `adventuring-gear`).** Bu evrende hastalığa karşı var
olan **tek** savunma.

> İçildiğinde **24 saat** boyunca `Blight — Enfeksiyon`un kurtarma zarlarına
> **+5** verir — hem maruziyet zarına (CON DC 12) hem Evre 2 zarına (CON DC 13).

+5 kasten yüksek: bu bir kolaylık değil, **kıt bir kaynak.** Kural şerbeti güçlü
yapıp bulunmasını zorlaştırıyor; tersi (zayıf ve bol) hastalığı bir tempo kuralından
bir muhasebe kalemine çevirirdi.

**Şifa büyülerinin bedeli — yapan öder.** `act1.md` §4.4 iki büyünün *etkisini*
yazdı; `YT` *ücretini* ekliyor ve ikisi çelişmiyor:

| Büyü | Etki (kanon, `act1.md` §4.4) | Yapanın ödediği (bu belge) |
|---|---|---|
| *Lesser Restoration* | Bir Evre 2 başarısızlığını siler. Bir gün kazandırır | **1 seviye Exhaustion** |
| *Greater Restoration* | Evre 1 veya 2'de hastalığı **kaldırır** | Kalıcı bir **Can Zarı (Hit Die)** |

Bu, `act1.md` §4.4'ün *"Meridia'da bu büyüyü kimin yapabildiği ayrı ve siyasi bir
sorudur"* cümlesine cevabın yarısını veriyor: yapabilen az, çünkü **her seferinde
kendinden bir parça veriyor.** Diğer yarısı (kimin izni var) hâlâ siyasi.

---

## 8. Kalıcı Yaralar

> **Tetikleyici:** canın **0'a düşmesi**, VEYA tek bir saldırıda **Maksimum Canının
> yarısını** kaybetmek.
>
> **Mekanik:** **d20.** Düşük zar **kalıcı** hasar (topallama), yüksek zar **geçici**
> sakatlık (kaburga ağrısı).

⚠️ **Bandlar türetildi, kanon değil** (§11): `YT` yalnız iki ucu veriyor.
Kullanılabilir olması için üç bant yazıldı ve zar yönü korundu — **düşük kötüdür**:

| d20 | Ağırlık | Örnek |
|---|---|---|
| **1–5** | **Kalıcı** — iyileşmez, *Greater Restoration* ister | Topallama (hız −10 ft) · bir gözün kaybı · tutmayan el |
| **6–14** | **Uzun süreli** — haftalarla ölçülür, tıbbi bakımla kısalır | Kaynamamış kemik · derin kesik · sağır kalan bir kulak |
| **15–20** | **Geçici** — bir sonraki uzun dinlenmede geçer | Kaburga ağrısı · şişmiş göz · zonklayan bir el |

**Ton gerekçesi:** README §6.4 diyor ki *karanlık geçmişte ve yapılarda; ışık
insanlarda ve bugünde.* Kalıcı yara o kuralı bozmuyor, **taşıyor** — yarası olan
karakter yaşamaya devam ediyor, ve masada yarası olmayan NPC kotası (02 §4) bu
yüzden daha çok anlam kazanıyor: bu dünyada sağlam kalmak bir şanstır.

---

## 9. Bu belgeden çıkan yazım listesi

Yeni kart sayısı bilerek düşük: **kuralların çoğu var olan kartların içine giriyor.**
Yeni kart açmak, kuralı dünyadan koparıyor.

**Yeni kartlar — 2**

| Kategori | Kart | Ne |
|---|---|---|
| `lore` | **Kural Sapmaları** | 3 sayfa: *Ölümün Ağırlığı* (§5) · *Işınlanma ve Mesafe* (§4.2) · *Kalıcı Yaralar* (§8) |
| `adventuring-gear` | **Direnç Şerbeti** | Hastalığa karşı tek savunma; 24 saat, +5 (§7) |

**Var olan kartlara giren — 5**

| Kart | Ne ekleniyor |
|---|---|
| `lore/Büyücü Loncası` | Lisans sistemi · yasaklı iki okul · lisansın iki loncaya borç yazması (§2) |
| `lore/Tanrılar ve Fısıltı` | Yankılanan Sessizlik: pasif tanrılar · şifanın ağırlığı · sembol = anten (§3) |
| `lore/Simya ve Şifacılar Loncası` | İksirin ruhsatlı kalem olması, kıtlığın sebebi (§7) |
| `curse/Blight — Enfeksiyon` | **Yozlaşma Kontrolü** (§6) + şifa büyülerinin yapana bedeli (§7) |
| `campaign/Aegis` → *Masa kuralları* sayfası | Büyünün üç katmanı (§1) + 1–2. seviyenin güvenli olduğu (§4.1) |

---

## 10. Reddedilenler — kanon DEĞİL

Aşağıdakiler `YT`'de yazıyor ve **bu belgeye girmedi.** Sebebi hep aynı: bir MD
kanonuyla çelişiyorlar (README §0).

| Reddedilen | Çeliştiği kanon |
|---|---|
| **Hastalık Puanı (HP) sistemi — 5 aşama, 9+ puanda çöküş** | `act1.md` §4: hastalık **üç evre**, Evre 2'de üç başarı / üç başarısızlık. Aynı hastalık iki sayaçla ölçülemez |
| **"Hastalık Sisi"nde sürekli CON zarı** | `act1.md` §4.1: zar **maruziyet olmadan atılmaz** — hastalanmak bir cezanın değil **bir seçimin** sonucu (08 §4) |
| **Aşama 5: "Simyacı'nın iradesine bağlanmış NPC"** | README §1: baş kötü **Lucian**, Simyacı Act 1 kanonunda yok. Evre 3'ün *"emir bekleyen bir et"* hali kanon (02 §2) — **kimin** emri değil |
| **"Mızrak Etkisi: hasta bir priz gibi kullanılır"** | README §1: Act 1'de **mızrak parçası yok** |
| **Orklar dezavantajlı, yarı-orklar −3 ("hastalık orklar için özelleştirildi")** | `act1.md` §3.1, `lore/Vorstrand`: hastalık **Vorstrand'dan** geldi, bir ırk için tasarlanmadı. Ayrıca kanonun iki yarı-orc NPC'si var (Kaptan Holg · Çavuş Krusk) ve ikisinde de böyle bir işaret yok. 06 #11 (ırksal özelliklerin kaynağı) **açık** — kapanmadan ırka mekanik ceza yazılmaz |
| **Greater Restoration "1 aşama geriletir"** | `act1.md` §4.4: Evre 1–2'de hastalığı **kaldırır.** Yapanın bedeli alındı, etkisi alınmadı |
| ***Resistance* büyüsü hastalık zarına +5** | SRD: *Resistance* **+1d4** verir. README §6.5: sıfırdan sistem yazılmaz, SRD satırı yeniden tanımlanmaz. Cantrip olduğu gibi kullanılır ve yine işe yarar |
| **"Güvenli bölgede uzun dinlenme 1 Hastalık Puanı siler"** · **"Medicine DC 15 puan artışını durdurur"** | Puan sistemi düştüğü için dayanağı kalmadı. Evre 2'nin çıkış yolu kanonda **üç başarı** |
| **`AE §3.3`: "Aethelgard'da Büyücü Loncası yoktur", ışınlanma ve büyüsel mesajlaşma yok** | [`lonca-sehir.md` §2](lonca-sehir.md): Büyücü Loncası **Meclis'in altı koltuğundan biri** ve tekeli **ışınlanma kaydı.** `AE` bu noktada tamamen ters; `YT`'nin lonca temelli büyüsü kanonla örtüşen okuma |

**Kapsam dışı bırakılanlar (çelişmiyor, sadece bu turda alınmadı).**
Kaynak PDF'in `Aşama 3–5`'i (dinlenme ve erzak kuralları, bölgesel fiyatlandırma,
mühimmat ve ekipman yıpranması, zihinsel gerilim, Aranma Durumu ve "Gümüş İğne
Birimi", savaş alanı kuralları, Kırılma Noktası) **incelenmedi** — bu turun kapsamı
`Aşama 1–2` idi. Reddedilmediler; sıradadırlar.

---

## 11. Kararlar ve açık kalanlar

**Bu belgenin kapattıkları:**

1. **Büyü lonca eliyle disipline edilmiş bir kariyerdir** (§1) — `AE`'nin
   "lonca yoktur" okuması düştü.
2. **Lisans sistemi kanon** (§2): şehirde zorunlu, taşrada anlamsız, limanda şaka.
   Lisansı Büyücü Loncası verir, suçu Askeri Hukuk yazar.
3. **Necromancy ve zihin kontrolü Enchantment yasak** (§2), lisansla açılamaz.
4. **İlahi büyü çalışıyor ve çok kişi yapıyor** (§3); şifa **ağırlık** hissettirir,
   kutsal sembol bir **antendir.**
5. **1–2. seviye büyüler ek kural almaz** (§4.1) — Act 1 bu belgenin çoğunu görmez.
6. **Işınlanma: 4+ seviye = 1 exhaustion; uzun mesafe yalnız loncalarda** (§4.2).
   Büyücü Loncası'nın "ışınlanma kaydı" tekeli böylece gerçek bir hizmete dayandı.
7. **Bileşen tedariki iki kapı:** lonca izni ya da Gizli Liman (§4.3).
8. **Diriltme bedelli ve garantisiz** (§5): kalıcı Can Zarı **veya** kalıcı stat;
   başarısızlıkta ruh eksik / bozulmuş / ele geçirilmiş döner.
9. **Yozlaşma Kontrolü kanon** (§6), ama **cephenin ötesinde** işler; Act 1'de
   atılmaz. Druid +2, Paladin fiziksel etkilere dayanıklı.
10. **Şifa İksiri kıt** ve sebebi ruhsat (§7); **Direnç Şerbeti** tek savunma.
11. **Şifa büyülerinin bedeli yapana ait** (§7): *Lesser* → 1 exhaustion,
    *Greater* → kalıcı Can Zarı. Etkileri `act1.md` §4.4'te olduğu gibi kaldı.
12. **Kalıcı Yaralar kanon** (§8): 0 HP ya da tek vuruşta yarı can.
13. **Hastalık Puanı sistemi reddedildi** (§10) — Blight'ın tek sayacı **evre**.

**Açık:**

1. **Diriltme Sınavı'nın zarı ve DC'si** (§5) — sınav kanon, zarı değil. Öneri:
   büyücünün Spellcasting Ability kontrolü, DC ölümün üstünden geçen süreye göre
   yükselen bir merdiven. Karar verilmedi.
2. **Yozlaşma DC'si 13 türetildi** (§6) — `YT` sayı vermiyor. Evre 2 zarıyla
   hizalandı; kanon bir sayı verirse değişir.
3. **Kalıcı Yara bandları türetildi** (§8) — kaynak yalnız iki ucu veriyor. Üç
   bandın sınırları (1–5 / 6–14 / 15–20) ve örnek yaralar karar bekliyor.
4. **Lisansın fiyatı** (§2) yazılmadı — `service` kartı ancak fiyat kararıyla
   açılır; şimdilik lisans `lore/Büyücü Loncası`'nın içinde duruyor.
5. **Direnç Şerbeti'nin fiyatı ve üretim süresi** (§7) — kıt olduğu kanon, ne kadar
   kıt olduğu değil.
6. **06 #11 hâlâ açık** ve bu belge onu kapatmıyor: ırksal özelliklerin kaynağı
   kararı verilmeden hiçbir ırka mekanik ceza ya da bonus yazılmayacak.
7. **`Aşama 3–5` incelenmedi** (§10) — dinlenme/erzak, ekipman yıpranması, Aranma
   Durumu, savaş alanı kuralları. Ayrı bir tur ister.

---

## 12. DM'e not

- **Bu belgenin çoğu Act 1'de hiç atılmaz, ve bu bir kusur değil.** Yozlaşma
  cephenin ötesinde, diriltme 5. seviyede, ışınlanma 7'de. Perdede fiilen işleyen
  üç şey var: **Kalıcı Yaralar**, **Direnç Şerbeti** ve **iksirin bulunamaması.**
  Gerisi masaya bir kural olarak değil, dünyanın söylediği bir cümle olarak girer —
  ve tam olarak öyle girmeli.
- **Diriltme kuralı bir tehdit olarak yazıldı.** Masa onu kullanamayacak seviyede,
  ama *bileceği* seviyede. Bir NPC'nin "onu geri getirebilirim, ama bir Can Zarım
  gider" demesi, hiç diriltme yapılmadan bu dünyanın nasıl bir yer olduğunu anlatır.
  Kuralı böyle oynat: cümle olarak, işlem olarak değil.
- **Lisans, büyücü PC'ye ceza değil ilişki verir.** Lisansı olan PC bir loncaya
  bağlıdır (çağrıldığında gitmek zorunda), olmayan PC şehirde gizlenmek zorundadır.
  İkisi de oynanacak bir şey; hiçbiri "büyü yapamazsın" değil. Bir kuralı ceza gibi
  oynatırsan masa büyüyü bırakır, ve bu belgenin amacı bu değil.
- **Şerbetin +5'i büyük görünüyor, ama korkutucu olan kıtlığı.** Masa şerbeti bir
  kez içtiğinde bir daha bulamayacağını anlar, ve o andan sonra kulübeye girmeyi
  konuşarak karar verir — kural tam olarak bunu istiyordu (08 §4: hastalanmak bir
  seçimin sonucu). Şerbeti bollaştırırsan o konuşma ölür.
- **Kalıcı Yaralar'ı ilk kez Şafak Çatışması'nda göreceksin** (`act1.md` §5): üç
  Dönüşmüş, 1. seviye masa için zorlu-üstü, ve birinin 0'a düşmesi muhtemel. Zarı
  atmadan önce şunu bil: **1–5 bandı bir PC'yi kalıcı topallatabilir** ve perdenin
  ilk savaşında bu ağır bir sonuç. Masaya kuralı **önceden** söyle. Sürpriz kalıcı
  hasar, oyuncunun kabul etmediği bir bedeldir.
- **Reddedilenler listesini (§10) sil me.** Hastalık Puanı sistemi iyi yazılmış ve
  cazip; bir sonraki turda biri onu yeniden getirmek isteyecek. O tabloda neden
  düştüğü yazıyor — geri getirmek istiyorsan `act1.md` §4'ün evrelerini **birlikte**
  değiştirmen gerekir, ve o zaman `curse` kartı, üç `trait` kartı ve Şafak
  Çatışması'nın tempo notu da değişir. Yani bu ucuz bir geri alma değil.
- **Yozlaşma Kontrolü'nün asıl işi bir sonraki perdenin haritasını çizmek.**
  "3. seviye büyü yapmanın bedeli olan bir zemin" demek, "bu kıtanın bir yerinde
  büyücünün işe yaramadığı bir bölge var" demektir. O bölgeyi yazarken bu kural
  elinde hazır duruyor olacak.
