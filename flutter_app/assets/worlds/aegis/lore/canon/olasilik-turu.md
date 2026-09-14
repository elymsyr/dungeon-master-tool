# Olasılık Turu — kartlardan takvimi sökmek

> **Durum: öneri turu, onay bekliyor (2026-09-14).**
> Dayanağı README §6.8 (karar A3). Bu belge kanon *içerik* getirmez: hiçbir yeni
> NPC, mekan, olay ya da bağlantı önermiyor. Yaptığı tek şey, **yazılmış
> kartlardaki zaman kipini değiştirmek** — aynı malzeme, farklı gerginlik.
> Onaylanan maddeler blueprint'e işlenir, bu belge arşive düşer.

Masadan gelen geri bildirim: **planlı şeyin olduğu gibi oynatılması sevilmiyor.**
Oyuncu bir şeyi seçmeden önce sonucun yazılı olduğunu sezdiği an, seçim dekora
dönüşüyor.

Elimizde aslında şu var: **bir durum, mekanlar ve insanlar.** Kartların çoğu
zaten bunu yazıyor. Sorun, aralarına sıkışmış bir avuç cümlede: *"ertesi sabah
dönüşürler"*, *"o sabah köydedir"*, *"çıkışta teklifi alırlar"*. Bu cümleler
dünyanın saatini kartın eline veriyor. Bu tur onu masaya geri veriyor.

---

## 1. Üç çevirme

Hiçbir olay silinmiyor. Her biri üç kalıptan birine çevriliyor.

| Şu anki kip | Neye çevrilir | Örnek |
|---|---|---|
| **Takvim** — *"ertesi gün olur"* | **Eşik** — durum, saat değil | *"son eşiğin bir adım berisindeler"* |
| **Randevu** — *"o sabah oradadır"* | **Alışkanlık** — sıklık, gün değil | *"ara ara köye uğrar"* |
| **Teslimat** — *"teklifi alırlar"* | **Olasılık** — koşul, garanti değil | *"o adamın elinde bir teklif var ve alıcı arıyor"* |

**Kaçınılmaz olan kaçınılmaz kalır.** Üç hastanın dönmesi, Meclis'in bir karar
çıkarmaması, Halim'in yolu bulup anlatması — bunların hiçbiri tartışmaya
açılmıyor. Kalkan tek şey **günleri**.

---

## 2. Kart kart döküm — Tur 1 (dar)

Yalnız metin değişir. Kart eklenmez, silinmez, yeniden adlandırılmaz; entity
linkleri ve medya dosyaları aynı kalır.

### 2.1 `scene/Köye Varış` — "Saat" başlığı

**Şu an:** başlık *Saat*. İçinde *"şafağa kadar 9'a çıkacaklar"* ve *"Ne olursa
olsun şafakta Şafak Dönüşümü olur."*

**Öneri:** başlık **"Üç hasta nerede duruyor"**, ve şu metin:

> Üç hasta **8 Hastalık Puanında**: son eşiğin bir adım berisinde. Dokuzuncu
> puanda dönerler ve geri dönüşü yoktur. Dokuza ne zaman varacakları yazılı
> değil — ama varacakları yazılı. Bunu kimse bilmiyor; köylüler de, Umay da,
> karakterler de.
>
> Köylüler geceyi köyde geçirmeyi önerir — *"Sabah gidin. Gece yol karanlık."*
> Bu bir yönlendirme değil, köyün alışkanlığı: yol karanlıkta tehlikeli ve
> konuk göndermek ayıp.
>
> Kulübede geçen her gece, dokunulan her hasta, sarılan her yara eşiği
> yaklaştırır. @[Şafak Dönüşümü](entity:scene/Şafak Dönüşümü) elinde duran bir
> karttır; ne zaman açılacağı sende.

**Ad neden değişmiyor.** *Şafak* kartta kalıyor, çünkü dönüşüm gerçekten bir
şafakta olur — beden geceyi zor geçirir. Değişen şey *hangi* şafak: kart artık
**"o sabah"** demiyor, **"bir sabah"** diyor.

### 2.2 `scene/Köye Varış` — "Corvin" paragrafı

**Şu an:** *"Dönüşüm sabahı köye şafaktan birkaç saat önce döner… zorunlu olan
tek şey, dönüşüm olduğunda köyde olması."*

**Öneri:**

> **Corvin.** @[Corvin](entity:npc/Corvin) köyde sürekli değildir; kıyıyla köy
> arasında gider gelir ve birkaç günde bir uğrar. Karakterler vardığında köyde
> olabilir de olmayabilir de. Yoksa köylüler *"yolda"* der ve ne zaman
> döneceğini söylemez, çünkü bilmezler. Dönerse handa ya da kuyu başında
> bulunur, yükü hâlâ sırtında.

### 2.3 `scene/Kulübe Sorgusu` — "Gece" başlığı

**Şu an:** *"Karakterler kulübede ya da köyde kalırsa şafak gelir: Şafak
Dönüşümü."*

**Öneri:** başlık **"Eşik"**:

> Üçü de dokuzuncu puana bir adım uzakta ve bu kulübede geçen her gecede bir
> zar daha atılıyor. Karakterler kalsa da gitse de eşik kapanır; kalırlarsa
> orada olurlar, giderlerse haberini alırlar.

### 2.4 `scene/Şafak Dönüşümü` — "Ne oldu" başlığı

**Şu an:** *"Kulübede geçen gecenin günlük hastalık zarı… Üçü de döndü, ve
karakterlerin gece ne yaptığı bunu değiştirmez. Dönüşüm bir seçimin cezası
değil, hastalığın takvimi."*

**Öneri:**

> Günlük hastalık zarı üçünü de dokuzuncu puana taşıdı, ve üçü birden döndü.
> **Karakterlerin ne yaptığı bunu değiştirmez** — dönüşüm bir seçimin cezası
> değil, hastalığın kendisi. Değiştirdiği tek şey, bu sabah kulübeyle köyün
> arasında kimin durduğu.

*(Son cümle "takvim" kelimesinin yerine geçiyor ve sahnenin asıl sorusunu öne
alıyor: iki hâli — "Ayakta" ve "Kırılmış" — ayıran şey zaten bu.)*

### 2.5 `scene/Şafak Dönüşümü` — "Köyde" içindeki Corvin

**Şu an:** *"Corvin o sabah köydedir: birkaç saat önce kıyıdan, yükü sırtında
dönmüştü."*

**Öneri:**

> @[Corvin](entity:npc/Corvin) o sabah köydeyse kaçmaz, öne de atılmaz; kendi
> kapısının önünde, elinde bıçağıyla durur — ve karakterler onu korumazsa
> ölebilir. Köyde değilse birkaç saat sonra, yükü sırtında döner ve köyü
> bulduğu hâlde bulur.

### 2.6 `npc/Corvin` — "Ne zaman köyde" ve "Corvin ölürse"

**Öneri — "Ne zaman köyde":**

> Corvin köyde sürekli değildir; kıyıyla köy arasında gider gelir ve **birkaç
> günde bir** uğrar. Köyde olup olmaması sahneye göre değişir: karakterler onu
> arıyorsa handa bir yatağı ve bekleyen bir yükü vardır, ya da bir gün içinde
> döner. Köylüler *"Corvin yolda"* der; ne zaman döneceğini bilmezler.

**"Corvin ölürse" paragrafı** aynen kalır, tek kelime değişir: *"Şafakta
ölürse"* → *"Dönüşümde ölürse"*.

### 2.7 `npc/Halim` — "Savaşmaz"

*"@[Şafak Dönüşümü](entity:scene/Şafak Dönüşümü)'nde koşar ve durmaz"* →
*"Dönüşüm olduğunda köydeyse koşar ve durmaz"*.

### 2.8 `curse/Blight — Enfeksiyon` — dmNotes

**Şu an:** *"Kulübedeki üç kişi 8 puanla gelir; kulübedeki gecenin günlük zarı
onları 9'a taşır."*

**Öneri:**

> Kulübedeki üç kişi **8 puanla**, yani son eşiğin bir adım berisinde durur.
> Dokuzuncu puan bir gün meselesidir; hangi gün olduğuna zar ya da sen karar
> verirsin. Kartın garanti ettiği şey gün değil, **eşik**.

### 2.9 `scene/Kapı Önündeki Teklif` — "Kim bekliyor" ve dmNotes

En büyük değişiklik bu. Şu an teklif karakterlere **ulaşıyor**: salonun
kapısında, ya da çırak eliyle şehirde, ya da Votumar yolunda bir mektupla.
Üç ayrı garanti, tek bir sonuç.

**Öneri — "Kim bekliyor" yerine "Teklif ortada duruyor":**

> @[Sınır ve Ticaret — Orvan Sancar](entity:npc/Sınır ve Ticaret — Orvan Sancar)
> hastalığa inanan tek koltuk, ve bunu taşıyacak birini arıyor. Teklif hazır;
> kime, nerede ve ne zaman söyleneceği değil.
>
> **En kısa yol salonun kapısıdır.** Karakterler Meclis'e çıktıysa Orvan
> oturumdan sonra koridorda beklemeyi seçebilir — bu adamın elindeki en hızlı
> yol, bir zorunluluk değil.
>
> **Meclis'e çıkmadılarsa teklif peşlerine düşmez.** Bunun yerine adı üç yerden
> duyulur: @[Halim](entity:npc/Halim) kimin yolladığını söylediğinde,
> @[Kadife](entity:npc/Kadife) onları Meclis'e yollarken, ve şehirde hastalığı
> soran herkese verilen o tek cevapta — *"o konuyla ilgilenen bir koltuk var,
> ama kimse onu dinlemiyor."* Kapıyı karakterler çalar.

**Öneri — dmNotes'taki *"Teklifi aynı oturumda ver"* yerine:**

> **Teklifi bekletme, ama zorla da verme.** Karakterler Orvan'ın adını duyduğu
> an teklif ulaşılabilir hâle gelir; gitmeyi seçmezlerse teklif de olmaz.
> Meclis'ten eli boş çıkmak bir çıkmaz değil — ret zaten sahnenin ödülü, ve
> limandan geçen para yolu (@[İyi Yazı](entity:quest/İyi Yazı)) hiçbir koşulda
> kapanmaz.

*(Kilitlenme kontrolü: @[İyi Yazı](entity:quest/İyi Yazı) zaten iki yollu ve
kaçak yol Orvan'dan tamamen bağımsız. Teklifin opsiyonel olması hiçbir kapıyı
kapatmıyor.)*

---

## 3. Numaralı akışı sökmek — Tur 1, ikinci yarı

Dört sahne kartı *"Sahneyi oynatmak: 1 → 2 → 3"* biçiminde yazılmış. Numaralar
sahneye bir sıra dayatıyor; içerikleri dayatmıyor. Numaralar kalkar, içerik
kalır.

| Kart | Şu anki başlık | Öneri |
|---|---|---|
| `scene/Meclis Oturumu` | *Sahneyi oynatmak* 1–6 | **"Salonda ne var"** — altı koltuk ve cevapları · **"Zorlarsa"** · **"Gerçek adlar söylenirse"**. Son iki adım (*"Ret"* ve *"Çıkış → Kapı Önündeki Teklif"*) kalkar; yerine tek cümle: **"Oturum nasıl giderse gitsin salondan bir karar çıkmaz — altı koltuğun altısı da kendi mesleğinin gözünden bakıyor."** |
| `scene/Susan Kule` | *Sahneyi oynatmak* 1–5 | **"Kulede ne var"** · **"Nöbetçi ne biliyor, ne söylemiyor"** · **"Şatoda aynı terslik"**. Kıvrık sayfanın fark edilmesi bir adım değil, orada duran bir ayrıntı |
| `scene/Avluda Karşılanma` | *Sahneyi oynatmak* 1–4 | **"Druid ne biliyor"** · **"Ne zamandır biliyor"** · **"Plato"**. Karşılanmanın kendisi zaten açılış metninde |
| `scene/Limana Kabul` | *Kural* + *Sahneyi oynatmak* | Zaten olasılık kipinde (üç kabul yolu, dört ayrı tutum). **Dokunma** |

---

## 4. Görev kartları — adım listesinden duruma

Üç görev kartının `objective` alanı da numaralı. Görev bir yol tarifi değil, bir
**durum + eldekiler + açılan kapılar** olmalı.

### 4.1 `quest/Söylentinin Peşinde`

**Şu an:** 4 numaralı adım, ve *"Görev, gidilen makam reddettiğinde kapanır."*

**Öneri:**

> **Durum.** Hastalık söylentileri karakterleri @[Gümüşsu](entity:location/Gümüşsu)
> yoluna çıkardı. Köyde hasta sanılan üç yabancı var, ve köy bunu kendi başına
> idare etmeye çalışıyor.
>
> **Ne var.** Bir köy, bir han, köyün dışında bir kulübe · beş köylü ve her
> birinin sorulmadan verdiği bir şey · kulübede üç hasta ve üstlerinde beş iz ·
> köye bakmaya gelmiş dördüncü bir yabancı.
>
> **Nereye açılır.** Gördüğünü bir makama götürmek isteyen karakterler için iki
> kapı var: Lucid Triton'da Lonca Meclisi, @[Votumar](entity:location/Votumar)'da
> @[Başkumandan](entity:npc/Başkumandan). İkisi de reddeder, ve ikisi de retten
> başka bir şey verir. Hiçbirine gitmemek de bir seçim — o zaman söylentiyi
> @[Halim](entity:npc/Halim) taşır ve şehir olanı karakterlerden değil ondan duyar.
>
> **Görev kapanmaz, dağılır:** buradan @[Nereden Geldiler](entity:quest/Nereden Geldiler)
> ve @[İyi Yazı](entity:quest/İyi Yazı) çıkar.

### 4.2 `quest/Nereden Geldiler`

Zaten *"soğuyan bir iz"* olarak yazılmış ve `secrets` alanı doğru yerde duruyor.
Tek değişiklik: dört numaralı adım → **"İzler" · "Limanın iki kapısı" · "Limanda
kim ne biliyor" · "İzin bittiği yer"**. Sıra değil, harita.

### 4.3 `quest/İyi Yazı`

**Dokunma.** İki yollu, her yol üç durak, hiçbiri zorunlu değil — kart zaten bu
turun istediği biçimde yazılmış. Örnek olarak duruyor.

---

## 5. Tur 2 önerisi (geniş) — ayrı karar

Yukarıdakiler yalnız kip değiştiriyor. Daha ileri gitmek istenirse ikinci bir
tur var, ve o **ağırlık taşıyor**, kelime değil:

**Duran durum `location`'a, hareketli olan `scene`'e.** Şu an bir sahne kartı
hem *"köy ne durumda"*yı hem *"o gün ne oluyor"*u taşıyor. Ayrılırsa:

- `location/Gümüşsu` bir **"Şu an ne durumda"** bölümü kazanır: kim nerede, ne
  konuşuluyor, kapılarda ne var, kim kimi ne zaman görür. Bu bilgi bir sahneye
  bağlı olmaktan çıkar — karakterler köye üçüncü kez gelse de geçerlidir.
- `scene/Köye Varış` yalnız **açılışa** iner: okunacak metin, ilk izlenim, ve
  masanın ilk hamlesine bırakılan boşluk.

Kazancı: mekan kartı sahne sırasından bağımsız çalışır, sahne kartı kısalır.
Bedeli: sekiz-on kartın yeniden bölünmesi, ve `location` kartlarının şu anki
şemasına yeni bir alan gerekip gerekmediğine bakmak.

**Bu tur önerilmiyor, sadece duruyor.** Tur 1 tek başına masadaki şikayeti
karşılıyor.

---

## 6. Dokunulmayanlar

Bu turun kapsamı dışında kalanlar, bilerek:

- **Blight'ın kural gövdesi.** Eşikler, DC'ler, aşamalar — hepsi zaten durum
  tabanlı. Sayaç bir takvim değil.
- **`Şafak Dönüşümü`'nün "iki hâl" yapısı** (*Ayakta* / *Kırılmış*). Bu tam da
  bu turun istediği şey: sonucu masanın seçimi belirliyor.
- **Kart adları, entity linkleri, medya dosyaları.** Hiçbiri değişmiyor.
- **`secrets` alanları.** DM'in bildiği şeyler; oyuncunun seçimini sınırlamıyorlar.
- **Kaçınılmazlıklar.** Üçü döner · Meclis bir karar çıkarmaz · Halim anlatır ·
  yüzüğün izi limanda biter. Bunlar dünyanın ağırlığı, takvimi değil.

---

## 7. Uygulama notu

Değişiklikler iki dosyaya birden işlenir — `world-blueprint.json` **ve**
`aegis-act1.pkg.json` (converter'ın çıktısı; markdown alanlarını birebir taşır,
yalnız `@[...]` hedeflerini uuid'e çevirir). Yeni entity linki eklenen tek yer
§2.9; oradaki üç ad (@Halim · @Kadife · @İyi Yazı) zaten pakette var, uuid'leri
mevcut.

Doğru yol converter'ı çalıştırmak:

```bash
cd flutter_app
dart run tool/content/convert_blueprint.dart --dir assets/worlds/aegis/aegis-act1 --check
dart run tool/content/convert_blueprint.dart --dir assets/worlds/aegis/aegis-act1
cd assets/worlds/aegis && rm -f aegis-act1.zip && zip -r -X -9 aegis-act1.zip aegis-act1
```

---

## 8. Onay listesi

| # | Madde | Onay |
|---|---|---|
| 1 | §2.1–2.3 — üç hastanın saati eşiğe çevrilsin | ⬜ |
| 2 | §2.4–2.5 — dönüşüm sahnesindeki "takvim" dili | ⬜ |
| 3 | §2.6–2.7 — Corvin ve Halim'in yeri randevu değil alışkanlık olsun | ⬜ |
| 4 | §2.8 — Blight kartının dmNotes'u | ⬜ |
| 5 | §2.9 — Orvan'ın teklifi ulaşan değil duran bir şey olsun | ⬜ |
| 6 | §3 — dört sahne kartındaki numaralı akış sökülsün | ⬜ |
| 7 | §4 — görev kartları adım listesinden duruma çevrilsin | ⬜ |
| 8 | §5 — Tur 2 (durum `location`'a taşınsın) | ⬜ *ayrı karar* |
