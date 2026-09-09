# Lonca ve Şehir — Plan

> **Durum: plan belgesi.** [`act1.md`](act1.md) Gümüşsu ve Gizli Liman'ı yazdı;
> bu belge güzergahın bir sonraki iki durağını (**Lonca** ve **Merkezi Şehir**)
> kart yazılabilir hale getiriyor. Detay değil **yapı**: kimin neyin tekelinde
> olduğu, kimin kimi yönettiği, şehrin ne durumda olduğu, meclis, ve NPC'ler.
>
> Dayanak: 09 §2 (yönetim), §4 (bilgi eğimi), §5 (lokasyon), §7 (NPC standardı) ·
> 10 M1 (Sancak Kaydı), M2 (liyakat yalanı), M6 (loncalar), M8 (asayiş) ·
> Adlandırma Doktrini §5 (ek = statü) · act1.md §2, §6, §7.

**Adlar geçici.** Bu belgedeki lonca ve hane adlarının hiçbiri kilit değil; hepsi
kart adı olarak yazılır ve tek bir grep ile değişir ([`act1-kartlar.md` §0]
(act1-kartlar.md)). Merkezi Şehir'in adı hâlâ **yok** (M0), o yüzden burada da
"Merkezi Şehir" diye geçiyor.

**Kart eşiği geçerli** (genel-kartlar): adı olan ve masada işaret edilebilen her
şey kart. Loncalar `lore`, binalar `location`, insanlar `npc`.

---

## 0. Türetme ilkesi — kalemi tutan yönetir

Bu kıtada insanlar kanla değil **kayıtla** bölünür (10 M1). O zaman gücün nerede
olduğu kendiliğinden çıkar: **kaydı kim tutuyorsa o yönetir.** Lonca burada bir
esnaf birliği değil, bir **defter sahibidir** — her lonca bir defterin tekelinde,
ve o defterde yazmayan şey resmi olarak olmamıştır.

Bu, üç şeyi bedavaya veriyor:

- **Liyakat yalanı** (10 M2) mekanik kazanıyor: "yeteneğinle yükselirsin" doğru,
  ama yükselişin *kayda geçmesi* bir loncanın karşı-imzasına bağlı. Himaye = imza.
- **Mühür** (act1.md §2) neden bu evrenin merkezî nesnesi belli oluyor: mühür, bir
  deftere yazma yetkisidir. On üç background eşyasının dördünün mühür olması
  tesadüf değil.
- **Act 1'in kanıtı** (§3.3, mührü eğelenmiş yüzük) doğrudan buraya bağlanıyor:
  bir sayfanın silinmesi, bir loncanın hizmetidir. Ücreti vardır.

---

## 1. Konsey mi, Meclis mi — çelişki kapatılıyor (KARAR)

Arşivde iki isim var ve ikisi de "yönetim" diyor: **Konsey** (Adlandırma §5:
"`-um` → Konsey tanımlı şehir") ve **Lonca Meclisi** (09 §2: "kıtanın fiili
yönetimi"). Aynı şey değiller, ve ayrımı yazmadan lonca bölümü yazılamaz.

| | **Konsey** | **Lonca Meclisi** |
|---|---|---|
| Nedir | Kralın kurumu. Hukuken var olan tek yönetim | Loncaların kendi aralarındaki kurul |
| Ne yapar | Şehir tanımlar, vergi koyar, Sancak Kaydı'nın sahibidir | Kimin hangi koltuğa oturacağını belirler |
| Kim doldurur | Koltukları **loncalar** doldurur | Altı lonca, altı koltuk |
| Halk ne der | "Konsey karar verdi" | "Meclis toplandı" — ikisi de aynı odayı kastediyor |

**Karar:** Konsey **çerçeve**, Meclis **içerik**. Konsey koltuklarının hepsi bir
loncanındır; Konsey adına konuşan herkes aslında bir loncanın adına konuşur. Kral
300 yıldır oturumda görülmedi ve bu kimseyi rahatsız etmiyor — kurum kralsız da
işliyor (06 #10, (b) şıkkı).

Act 1'e karşılığı: `npc/Konsey Aracısı` (act1.md §7.4) rıhtımda **bir loncanın**
adamıdır; "hangi konsey koltuklarının pay aldığı" sorusu, "hangi loncalar"
sorusudur.

---

## 2. Loncalar — 6 kart

Her satır 10 M6'nın formatında: **neyin tekelinde · kime düşman · ne gizliyor**,
artı koltuğu tutan hane. Loncalar mesleklere göre değil, **tuttukları deftere**
göre bölünmüş; o yüzden bir lonca birden çok işi kapsıyor.

| Lonca | Tekel (defteri) | Hane | Çatışma |
|---|---|---|---|---|
| **Büyücü Loncası** | İzinli büyü, akademi, **ışınlanma kaydı** — kimin nereye gittiği | **hanesiz** — koltuğu Meclis atar (09 §2) | Herkes, ve kimse: tuttuğu kayıt hepsini rahatsız ediyor |
| **Sınır ve Ticaret Loncası** | Geçiş, gümrük, tonaj, tahıl ve fiyat — ve taşrada **Sancak Kaydı'nın kalemi** | **Sancarlar** *(düşmüş hane)* | Demirci-İşçi (ithal mal yerli tezgahı kesiyor) |
| **Demircilik ve İşçi Loncası** | Metal, sikke vuruşu, **ayar damgası**, yevmiye. Kıtanın en kalabalık loncası | **Ferrunlar** | Mimarlık (işi kim planlıyor, işçiyi kim çağırıyor) |
| **Simya ve Şifacılar Loncası** | Hekimlik ruhsatı, iksir ve simya, **ölüm sebebi beyanı** | **Kalenderler** | Büyücü Loncası (iyileştirmeyi kim yapacak) |
| **Askeri Hukuk Loncası** | Suç sicili, kolluk yetkisi, karantina ve olağanüstü hal hukuku | **Custarlar** | Sınır ve Ticaret (sınırda kimin sözü geçer) |
| **Mimarlık ve Planlama Loncası** | Yapı ruhsatı, su yolları, mahalle sınırları, sur | **Mizanlar** | Demirci-İşçi |

**Altı lonca, altı defter.** Şehirde bir şeyin var olması demek, bu altı defterden
en az birinde yazıyor olması demek. Hiçbirinde yazmayan insana **kayıtsız** denir,
ve kayıtsızın kaybolması kayda geçmez — act1.md §3'ün teması bu cümleye bağlı.

**Kapsam notları:**

- **Kayıt ayrı lonca değil.** Sancak Kaydı Konsey'in kitabıdır; taşrada kalemini
  **Sınır ve Ticaret** tutar (sınırdan geçeni yazan el, insanı da yazan eldir).
  Arşivci background'ı (act1.md §2) bu loncanın taşra koludur.
- **Tahıl ve fiyat** da Sınır ve Ticaret'te: ekmeğin fiyatı bir ithalat kalemidir.
- **Ayar damgası** Demirci-İşçi'de: damgayı vuran, metali döven eldir. Act 1'in
  yüzüğü (§3.3) bu loncanın vuruşunu taşıyor.

---

## 3. Haneler — koltuk kanla değil mühürle geçer

Hane, bir loncanın **mührünü elinde tutan ailedir.** Kural tek cümle: *mühür
kimdeyse hane odur.* Miras kanla değil mühürle işler; evlat edinme, damat alma, ve
nadiren satın alma aynı kapıya çıkar.

Üç sonucu var, üçü de masada işe yarıyor:

1. **Mertebeli Lonca Çocuğu** (act1.md §2) bir hanenin çocuğudur — yüzü tanınır,
   çünkü mührü taşıyan az sayıda insan var.
2. **Hane düşürülebilir.** Mührü kaybetmek soyu kaybetmektir; bu yüzden hanelerin
   birbirine karşı asıl silahı cinayet değil **kayıt**tır. **Sancarlar** bunun
   canlı örneği: mühür hâlâ onlarda, para değil (§6.1).
3. Altı koltuktan biri (Büyücü Loncası) hanesizdir ve bu, diğer beşi için sürekli
   bir tehdit örneğidir: demek ki koltuk bir haneden alınabiliyor.

**Kart kararı:** haneler şimdilik **ayrı kart değil**, ait oldukları loncanın
`lore` kartının içinde yazılırlar. Bir hane masada karşılaşılan bir şeye
dönüştüğünde (bir konak, bir isim, bir düşman) kendi kartını alır — kart eşiği
bunu gerektirir, ama olmayan şey yazılmaz.

---

## 4. Şehirde asayişi kim sağlıyor

Ordu değil (10 M8). Yetki **Askeri Hukuk Loncası'nda**: sicili o tutar, cezayı o
yazar. Ama sokakta duran adam onun adamı değil — her loncanın kendi kolluğu var,
kendi çarşısında, kendi defterini korur.

Şehirli için pratik sonuç: **kime şikayet edeceğin, nerede dövüldüğüne bağlı.**
Askeri Hukuk'un sözü nihai olarak geçer, ama gelmesi zaman alır ve genelde iş
bitmiş olur. Bir suçun sahibi yoksa suç da yoktur. Act 1'in Gizli Liman'daki
"kavga eden ilan edilir" kuralının (act1.md §7.3) şehirdeki karşılığı budur —
orada kayıt yokluğu cezalandırıyordu, burada kayıt fazlalığı.

---

## 5. Merkezi Şehir — kısa tarif

Kanon veri: çok büyük · çoğunluk insan · beyaz mermer mimari · canlı renklerde
ağaçlar (09 §5) · söylenti **bastırılmış** (09 §4). Üstüne dört başlık:

**Ticari.** Şehir neredeyse hiçbir şey üretmiyor; ürettiği şey **meşruiyet.**
Kıtanın malı buraya girip çıkmaz, buraya **yazılır**: geçiş kağıdı, ayar damgası,
ruhsat, karşı-imza. Zenginlik el değiştiren maldan değil, o malın kayıt ücretinden
geliyor. Bu yüzden şehir bir kıtlıkta bile aç kalmaz, ama bir kayıt tıkanmasında
felç olur.

**Sosyal.** İki isimli insanlar ve tek isimli insanlar var (M5). İkinci isim bir
haneye ya da bir loncaya aitliktir; tek isimli olan hizmet eder. Kimse kimseyi
açıkça aşağılamıyor — gerek yok, çünkü kimin hangi işi yaptığı zaten belli
(10 M3). Yükselmek mümkün ve gerçekten oluyor; sadece imzasız olmuyor.

**Kültürel.** Tanrı yok, tören var (10 M4). Doğum bir kayıt işlemidir: çocuğa ad
konması ile kayda geçmesi aynı gün, aynı salonda olur, ve halk ikisini ayırt
etmez. Bir insanın "adı var" demek, "defterde var" demektir. İlahi büyü yapan biri
mucize değil **usulsüzlük** olarak okunur.

**Siyasal.** Altı koltuk, beş hane, bir atama. Kararlar oturumda değil oturumdan
önce alınır; oturum, alınmış kararın **kayda geçtiği** yerdir. Muhalefet, koltuğu
olan birinin oturumda konuşması değil, **oturuma gelmemesidir** — çünkü karşı-imza
atmamak, hayır demenin tek işleyen biçimi.

**Şehrin bugünkü hali (Blight overlay, 10 M15):** hastalık şehre henüz gelmedi,
haberi geldi. Ve haber altı koltukta altı ayrı biçimde eritiliyor (§6).

---

## 6. Meclis — altı koltuk, altı inkâr

**Tasarım kuralı:** hiçbiri yalan söylemiyor. Her koltuk hastalığı **kendi
uzmanlığından** reddediyor, ve her reddin arkasında o loncanın gerçek bir çıkarı
var. 02'nin kuralı korunuyor: kimse kötü olduğu için hareket etmiyor.

**Adlar kondu (2026-09-09, adlandırma turu).** Kart başlığı koltuk adıyla kalır,
ad gövdeye girer: `**Rektör** — Quarion`. Altı koltukta **dört ırk** oturuyor ama
masadaki herkesin **iki adı var** — odanın asıl ayrımı ırk değil kayıt.

| Koltuk | Ne istiyor | İnkârı | Ne gizliyor |
|---|---|---|---|
| **Büyücü Loncası koltuğu** — Rektör **Quarion** *(elf, hanesiz → tek isim)* | Loncanın Meclis'e bağımlılığının görünmemesi | *"Sınadık. Hiçbir tespit büyüsü bir şey göstermedi. Görülmeyen şey yoktur."* | Sınama yapıldı ve **sonuç okunamadı** — bu, "yok" değil "bilmiyoruz" demek |
| **Sınır ve Ticaret koltuğu** — **Orvan Sancar** *(insan)*, bkz. §6.1 | Sınırın yeniden açılması | *(tek inkâr etmeyen)* | Kendi defterinden sayfa silindiğini |
| **Demircilik ve İşçi koltuğu** — Kalfa Başı **Adrik Ferrun** *(cüce)* | Yevmiyenin kesilmemesi | *"Tezgahlar dönüyor, üretim düşmedi. Hasta adam çekiç sallayamaz."* | Rakamlar düşmedi çünkü **aynı adamlar iki vardiya** çalışıyor; eksilenler yerine yenisi yazıldı |
| **Simya ve Şifacılar koltuğu** — Baş Otacı **Caramip Kalender** *(gnome)* | Loncasının aciz görünmemesi | *"Bu bilinmeyen bir şey değil, ilerlemiş bir humma. Adı var, tedavisi var."* | Beyanları kendisi değiştirtti. Bilmediğini kabul etmek ruhsat sisteminin sonu olur |
| **Askeri Hukuk koltuğu** — Sicil Ağası **Valen Custar** *(insan)* | Yetkisini kullanmak zorunda kalmamak | *"Hastalık hukuki bir kategori değil. Karantina savaş hukuku ister, ilan edilmiş savaş yok."* | Yetkisi **var.** İki mevsimdir kullanmıyor, çünkü kullandığı gün sorumluluk da onun olur |
| **Mimarlık ve Planlama koltuğu** — Levha Sahibi **Perhun Mizan** *(insan)* | Şehrin planının sorgulanmaması | *"Bu şehir hastalanmayacak biçimde planlandı: su ayrı akar, rüzgar temizler."* | Sur onarımı kağıt üstünde kaldı; plan bir süredir gerçeği tarif etmiyor |

### 6.1 Meclisin en fakir koltuğu — Sınır ve Ticaret

Mührü en eski hanede (**Sancarlar**), parası hiçbirinde yok. Sebep yapıdan
çıkıyor: bu loncanın geliri **akıştan** gelir, mülkten değil. Gemiler gecikince,
sınır kapıları yarı kapanınca, tahıl gelmeyince koltuk fakirleşti — diğer beşi
şehrin kendi bütçesinden ve kendi çarşısından besleniyor.

Aynı yapı, onu **inanan tek üye** yapıyor:

- Hastalık sınırdan geliyor, ve sınır defteri onun. **İlk gören o.**
- Kaybedecek malı yok; koruyacak bir örtbası da yok.
- Kendi defterinden sayfa silindi — yani örtbasın **kurbanı**, ortağı değil.

> **Meclisteki yeri:** konuşur, kimse dönüp bakmaz. Oyuncular oturumda bunu görür:
> adam haklıdır ve odada hiçbir ağırlığı yoktur. Odanın ders verdiği şey budur —
> Meclis'te haklı olmak bir para birimi değil.

### 6.2 Oturumdan sonra — gizli görev (KARAR)

Oyuncular Gümüşsu'nun kanıtıyla Meclis'e çıkarsa **reddedilirler.** Bu bir
başarısızlık değil, tasarım: oturum bir kapı değil bir **teşhis**. Ama çıkarken
kapıda beklenirler.

**Teklifi yapan:** Sınır ve Ticaret koltuğu — kendisi ya da tek adamı (§7'deki
geçiş memuru değil; onun kendi çırağı). Oturumda konuşmadığı şeyi burada söyler.

**Teklif üç cümle:**

1. *"Söyledikleriniz doğru. Odada kimse buna bakmayacak, ben dahil — çünkü benim
   sözümün orada ağırlığı yok."*
2. *"Ağırlığı olan tek şey kayıt. Benim defterimden bir sayfa silindi ve silen
   benim memurlarımdan biri. Bana **kimin ödediğini** getirin."*
3. *"Param yok. Verebileceğim şey imza."*

**Ödül = "iyi yazı"** (act1.md §7.2, §9 açık 2): koltuğun karşı-imzalı geçiş
kağıdı. Yani perdenin sonundaki gemi biletini Meclis'in en fakir üyesi ödüyor —
parayla değil yetkiyle. Grup gemiye para bulamazsa bile hat kapanmıyor.

**Neden kilitlenmez:** bu görev yolun tek kapısı değil. Aynı yazıyı para da alır
(act1.md §7.2), aynı bilgiyi liman hattı da taşır (Sicim + ayar ustası, §7). Meclis
yolu **en ucuz** yol, tek yol değil.

**Bunun `quest` kartı var:** *Silinen sayfa* (§8).

---

## 7. Sokak NPC'leri — beş taslak

09 §7 standardı: *ne istiyor · ne gizliyor · hangi kapıyı açar.*

| NPC | Nerede | Ne istiyor | Ne gizliyor | Hangi kapıyı açar |
|---|---|---|---|---|
| **Corin Sancar** — geçiş memuru *(insan)* | Karşı-İmza Masası | Terfi. Karşı-imza yetkisi olan bir masa | Silinen sayfanın altındaki ikinci imza onun | ***Kim ödedi*** — act1.md §3.3 zincirinin ucu |
| **Kildrak Ferrun** — ayar ustası *(cüce)* | Demirci çarşısı | Damgasının temiz kalması | Eğelenmiş mührü daha önce de gördü, bir kez değil | Yüzüğün **tezgahı**: fihristten hangi kuyumcunun vurduğu okunur (kuyumcu **Mine**'nin tezgahı — act1.md §7.4) |
| **Sindri** — simyacı çırağı *(gnome, bastırılan tanık)* | Şifacılar kışlası | Yazdığının doğru kalması | İlk beyanın kopyası onda | Hastalığın şehirde **bilindiğinin** belgesi |
| **Kandil** — borçlu esnaf *(insan)* | Çarşı | Borcunun ertelenmesi | Kolluğun kimi dövdüğünü ve kimin emrettiğini | Sokak hattı, lonca kolluğu, "iyi para"nın şehirdeki karşılığı |
| **Çavuş Krusk** — kolluk çavuşu *(yarı-orc)* | Kapılar / gece devriyesi | Nöbetinde sorun çıkmaması | Emirlerin Askeri Hukuk'tan değil tek bir haneden geldiğini | Kapılar, gece hareketi, kimin şehre girdiği |

**İki taşıyıcı kuralı sağlandı** (09 §7): *kim ödedi* artık iki yerde — **geçiş
memuru** (imza) ve **ayar ustası** (damga fihristi). Act 1'in Sicim'i üçüncü
taşıyıcı, yani hat kilitlenmiyor.

---

## 8. Bu belgeden çıkan yazım listesi

| Kategori | Kart | Durum |
|---|---|---|
| `lore` | **Büyücü** · **Sınır ve Ticaret** · **Demircilik ve İşçi** · **Simya ve Şifacılar** · **Askeri Hukuk** · **Mimarlık ve Planlama** Loncası — 6 kart | ✅ |
| `lore` | **Konsey ve Lonca Meclisi** — yapı kartı (§1) | ✅ |
| `lore` | **Sancak Kaydı** — statü sistemi (10 M1). Üç sınıf: **Mühürlü · Kayıtlı · Yazısız** | ✅ |
| `location` | **Lucid Triton** *(resmi kayıtta Lucidum Triton)* | ✅ |
| `location` | **Mühür Salonu** · **Karşı-İmza Masası** | ✅ |
| `npc` | Meclis'in altı koltuğu (§6) | ✅ |
| `npc` | Sokağın beşi (§7) | ✅ |
| `scene` | **Meclis oturumu** (altı inkâr, tek sessiz üye) · **Kapı önündeki teklif** (§6.2) · **Geçiş Divanı'nda sıra** | ✅ |
| `quest` | **Silinen sayfa** — kim ödedi; ödülü "iyi yazı" (§6.2) | ✅ |

Toplam **24 kart, hepsi ✅.** Ad kararı bekleyen kalmadı.

---

## 9. Kararlar ve açık kalanlar

**Bu belgenin kapattıkları:**

1. **Konsey = çerçeve, Meclis = içerik** (§1). Arşivin iki-yönetim çelişkisi kapandı.
2. **Lonca = defter sahibi** (§0), meslek birliği değil.
3. **Altı lonca, altı koltuk** (§2) — kayıt ve tahıl Sınır ve Ticaret'in içinde,
   ayar damgası Demirci-İşçi'nin.
4. **Hane = mührü tutan aile** (§3); koltuk kanla değil mühürle geçiyor.
5. **Asayiş: yetki Askeri Hukuk'ta, sokak lonca kolluklarında** (§4).
6. **Meclis hastalığı altı ayrı gerekçeyle reddediyor** (§6), hiçbiri kötü niyetli
   değil.
7. **Ret sonrası gizli görev** (§6.2): teklifi Meclis'in en fakir koltuğu yapar,
   ödülü para değil **karşı-imza**.
8. **"İyi yazı" = Sınır ve Ticaret koltuğunun karşı-imzalı geçiş kağıdı** —
   act1.md §9 açık 2 kapandı.
9. **Haneler ayrı kart değil** (§3), masaya çıkana kadar.

**Açık:**

1. ~~**Şehrin adı** (M0)~~ — **KAPANDI:** **Lucid Triton.**
2. ~~**Lonca ve hane adları**~~ — **KAPANDI:** §2'nin adları onaylandı. **Ferrunlar bir cüce hanesi** (KARAR) — ayar damgasının neden taklit edilemediği, kuyumcunun neden cüce olduğu ve ayar ustasının neden aynı soyadı taşıdığı bu tek karardan çıkıyor.
3. ~~**Kayıt sınıfları** (10 M1)~~ — **KAPANDI:** üç sınıf, **Mühürlü · Kayıtlı ·
   Yazısız.** Sokaktaki karşılığı ad katmanıdır: iki isim = mühürlü ve mensup ·
   tek isim = kayıtlı, hizmet eder · **lakap = yazısız.** Lakap, Sancak Kaydı'nın
   negatifidir; bir insana eşya adı takılmışsa mührü yoktur.
4. **Büyücü Loncası'nın koltuğunu kim atıyor** — "Meclis" diyoruz ama Meclis beş
   haneden ibaret; atamayı fiilen bir hane yapıyor. Hangisi?
5. ~~**Kuyumcunun adı**~~ — **KAPANDI:** **Mine**, Gizli Liman'ın kuyumcusu, klan
   adını söylemeyen bir cüce (act1.md §7.4).
6. **Sancarlar neden düştü** — hane fakirleşti, sebebini yalnız "akış kesildi"
   diye yazdım. Daha eski bir sebep (bir skandal, bir kayıp gemi filosu, bir
   kaybedilen dava) istersen buraya girer.

---

## 10. DM'e not

- **Altı inkâr, altı ayrı kapı.** §6'nın tablosu bir oturum sahnesinden fazlası:
  her inkâr aynı zamanda o üyenin **zayıf noktası.** Rektör'ü "sınama sonuç
  vermedi"nin üstünden, Baş Otacı'yı "bilmiyorum diyemem"in üstünden, Sicil
  Ağası'nı "sorumluluk benim olur"un üstünden kırarsın. Oyuncular oturumu
  kaybedecek, ama kimin neden hayır dediğini duyacaklar — sahnenin işi bu.
- **Ret bir duvar değil, bir ders.** §6.2 kapıda duruyor; masa "meclise gitmek
  boşunaymış" diye çıkmasın diye teklif oturumun **hemen ardından** gelmeli, aynı
  oturumda. Bir sonraki seansa bırakma.
- **En fakir üye tasarımın kalbi.** İnanan tek adamın ağırlığı olmaması, bu
  dünyanın nasıl işlediğini tek sahnede anlatıyor: burada doğruluk bir yetki
  biçimi değil. Ama bunun bedeli, oyunculara *kurumdan* umut kesmeyi öğretmesi —
  Act 2'de bir kurumu kazanmalarını istiyorsan, o kurum Meclis olmayacak.
- **Ödül olarak imza, paradan iyi.** Geçiş kağıdı hem Act 1'in gemi hattını
  açıyor hem de kağıdın kendisi bir iz: karşı-imza kayda geçer, yani gruba
  bindikleri gemide kim olduklarını söyleyen bir belge veriyoruz. Ucuz kapı,
  görünür kapı.
- **Ayar damgası artık işçi loncasında.** Bu, act1.md'nin yüzüğünü kalabalık ve
  fakir bir loncaya bağladı — yani kanıtın kaynağı zenginler değil, tezgahtaki
  adam. Ton olarak iyi, ama unutma: o tezgahtaki adam artık bir hane değil, ve
  onu susturmak da kolay.
- **Loncaları sen seçtin, defterleri ben ekledim.** Altı başlığın hepsi mesleki;
  onları tek sisteme bağlayan şey "her lonca bir defter tutar" cümlesi. O cümleyi
  kaldırırsan bu belgenin yarısı dağılır — değiştirmek istersen önce onu söyle.
