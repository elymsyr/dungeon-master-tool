# Aegis — Kart Listesi

> Uygulamada oluşturulacak **bütün kartlar**, tek listede. Kaynak: bu klasördeki
> kanon. İçerik burada yazılmaz, sadece sayılır ve adı konur.
>
> Liste **perdeye göre değil kategoriye göre** düzenlidir: kart yazılırken evrenin
> tamamı varmış gibi yazılır, bir bölümün parçası gibi değil.

**Durum kodları:** `✅` yazılabilir · `🟡` bir alanı karar bekliyor, kart yine de
başlıkla yazılır · `⬜` kart yok, önce karar.

**Adlar geçici, her ad link.** Kart gövdesinde başka bir karttan söz ediyorsan düz
metin değil entity linki kullan — `@[Sicim](entity:npc/Sicim)`. Ad değişimi böyle
tek grep olur.

| Kart | Neyi linkler |
|---|---|
| `location` | üstünü (`parent_location_ref`) + içindeki NPC'ler |
| `npc` | bulunduğu yer + açtığı kapının kartı |
| `scene` | geçtiği yer + sahnedeki NPC'ler + tetiklediği `encounter`/`quest` |
| `quest` | zincirdeki her sahne ve her taşıyıcı NPC |
| `monster` | insan hali (`npc` ikizi) |
| `background` | verdiği evrene özel eşya kartları (`default_inventory_refs`) |

**Kart eşiği:** adı olan ve masada işaret edilebilen her şey kart olur. Kart
yazmamanın tek geçerli sebebi o şeyin **var olmaması**. İçeriği eksik kart
yazılabilir, olmayan kart yazılamaz.

**Sır yerleşimi:** DM bilgisi ayrı karta değil, kartın `secrets` alanına yazılır
(`location.secrets` · `npc.secrets` · `quest.secrets` · `encounter.tactics`).

---

## 1. `campaign` — 1

| Kart | Sayfa | Durum |
|---|---|---|
| **Aegis** | Bu dünyada oynamak (ton sözleşmesi) · Masa kuralları (rol yuvaları, iki taşıyıcı kuralı, sayaç NPC'de) · Karakter yaratma (serbest, tek cümlelik sözleşme) · DM'e (bilgi eğimi, sır yerleşimi) · Sözlük | ✅ |

Giriş kartı oyuncunun ilk okuduğu şeydir: baş kötünün kim olduğu buraya yazılmaz,
sözlük de dünyayı anlatmaz — ilk oturumda duyulacak kelimeleri açar.

## 2. `lore` — 22

| Kart | Ne | Durum |
|---|---|---|
| **Fihrist** | Kart aramayı bitiren kart: üç zincirin, 18 mekanın, dokuz background'ın ve kural kartlarının fihristi. 7 sayfa | ✅ |
| **İrade Çağı** | Tanrıların kesilmesi, özgürlüğün bedeli | ✅ |
| **Tanrılar ve Fısıltı** | Bant genişliği kalmamış sevgi; ilahi büyünün bugünkü durumu | ✅ |
| **Blight — Bilinen Hali** | Halkın bildiği yüz. Yön değil **taşıyıcı** anlatılır | ✅ |
| **Vorstrand — Bilinen Hali** | Hastalığın geldiği, üçlünün kaçtığı yer. Halk ağzında sadece **"Öte"** | ✅ |
| **Konsey ve Lonca Meclisi** | Konsey çerçeve, Meclis içerik; altı koltuğu loncalar doldurur | ✅ |
| **Sancak Kaydı** | Mühür = hukuki kimlik; kayıtsızın kaybolması kayda geçmez. Üç sınıf: **Mühürlü · Kayıtlı · Yazısız** | ✅ |
| **Büyücü Loncası** | İzinli büyü, akademi, ışınlanma kaydı. Hanesiz koltuk | ✅ |
| **Sınır ve Ticaret Loncası** | Geçiş, gümrük, tonaj, tahıl; taşrada Sancak Kaydı'nın kalemi. Hane: Sancarlar | ✅ |
| **Demircilik ve İşçi Loncası** | Metal, sikke, **ayar damgası**, yevmiye. Hane: Ferrunlar | ✅ |
| **Simya ve Şifacılar Loncası** | Hekimlik ruhsatı, iksir, ölüm sebebi beyanı. Hane: Kalenderler | ✅ |
| **Askeri Hukuk Loncası** | Suç sicili, kolluk yetkisi, karantina hukuku. Hane: Custarlar | ✅ |
| **Mimarlık ve Planlama Loncası** | Yapı ruhsatı, su yolları, mahalle sınırları, sur. Hane: Mizanlar | ✅ |
| **İrade Yolu** | Yaşayan doktrin: kendi kaderinin efendisi · sıradan kahramanlık · Düzen ve İrade Metni. Ve bozulması: kolektif tapınma, **lidere körü körüne güven** | ✅ |
| **Sessiz Mabetler** | Kayıt dışı inanç: kadim tanrı kırıntıları · atalar kültü · doğa ruhları · kör şans · Akışın Ruhu. Yasak değil, **görülmeyen** | ✅ |
| **Hizmet Basamakları** | 18 yaş, çırak→üstat; yükseliş gerçek ama **kayda geçmesi** karşı-imza ister | ✅ |
| **Onur Mahkemeleri** | Lonca mahkemesi / Onur Mahkemesi / kamu hizmeti. İhanet: **kayıttan düşürme + sürgün** | ✅ |
| **Gümüş Kalkan Nişanı** | Votumar'ın paladin düzeni: ağır zırh, kule kalkanı, kusursuz nizam | ✅ |
| **Kuzeyin Gözcüleri** | Ravenhall'ın druid kabilesi; kararı döngü ve rün verir, oylama değil | ✅ |
| **Liman Ahdi** | Gizli Liman'ın sözlü kanunu. İki ağır ihlal: **yeri ifşa etmek** · **izinsiz gemiye girmek** | ✅ |
| **Kural Sapmaları** | 4 sayfa: *Çağrı Zarı* · *Ölümün Ağırlığı* (diriltmenin bedeli) · *Işınlanma ve Mesafe* · *Kalıcı Yaralar* | 🟡 |
| **İlahi Büyü Listesi** | Çağrı zarını hangi büyüler istiyor: Paladin (34) · Cleric (105) · Warlock (68) dökümü, ve bu kıtada neredeyse hiç görülmeyen 38 büyü | ✅ |

`lore/Sancak Kaydı` s.2 — *Defter nasıl işler*. **Ayrı kart değil** (0.4.0'da
birleşti): kartın 1. sayfası sınıfları anlatır, 2. sayfası **işlemi**. Altı bölüm,
hepsi masada sorulan bir soruya karşılık gelir:

1. **Kim yazar** — defter Konsey'in, kalem loncanın: şehirde her lonca kendi
   sicilini kendi tutar, taşrada tek kalem **Sınır ve Ticaret**'tir
   (`lonca-sehir.md` §2). Bu yüzden bir köylünün kaydı, sınırdan geçen bir yükle
   aynı elden çıkar.
2. **Ne yazılır** — satır dört alandır: *ad · hane · lonca ve mertebe · kefil.*
   Hane kutusu boşsa adam mühürsüzdür; kefil kutusu boşsa satır hiç açılmaz.
   Halfling ve cüce soyadları hane sayılmaz, defter onları *"tek isim + boş hane"*
   yazar (act1.md §2) — üçlünün sahte kimliği bu boşluğa oturuyor.
3. **Satır nasıl açılır** — kayıt doğumla gelmez, **kefaletle** gelir: 18'inde bir
   loncaya çırak yazılırsan (`lore/Hizmet Basamakları`) ya da kayıtlı biri sana
   kefil olursa. Kefil olan, kefil olduğunun borcunu da taşır. Kimsenin yazmadığı
   çocuk Yazısız doğar ve öyle kalır.
4. **Nasıl yükselinir** — mertebe ustanın imzasıyla *fiilen*, **karşı-imzayla**
   *hukuken* değişir. İki imza arasındaki gecikme, bu evrenin en yaygın rüşvet
   yeridir: kimse "hayır" demez, sadece kağıt masada bekler
   (`scene/Geçiş Divanı'nda Sıra`).
5. **Mühür nasıl alınır** — mühür terfi değil **yetki**: bir defteri imzalama
   hakkı. Konseyin verdiği değil, hanenin devrettiği şeydir — mühür kimdeyse hane
   odur (`lonca-sehir.md` §3). Bu yüzden mühürlü sayısı yükselmez, el değiştirir.
6. **Nasıl silinir** — üç yol: Onur Mahkemesi'nin **kayıttan düşürmesi** (`lore/Onur
   Mahkemeleri`), kefilin kefaletini geri çekmesi, ve **ödenmiş silme** — bir
   sayfanın hiç yazılmamış gibi çıkarılması. Üçüncüsü suçtur, ve kartta bir **dünya
   kuralı** olarak durur: silinen sayfa arkasında iki iz bırakır — kefilin
   karşı-imzası sütunda kalır, ve satırın kopyası taşra kaleminde durur.

   ⚠️ **5. tur düzeltmesi:** bu kural Act 1'in soruşturmasına **bağlanmıyor.** Üçlü
   gümrüğe hiç uğramadı, yani hiçbir şehir defterine hiç yazılmadılar — hiç yazılmamış
   bir satır silinemez. ~~Act 1'de silinen tek defter **Gizli Liman'ın kendi defteri**~~
   *(2026-09-15: Gizli Liman insan yazmaz, yalnız mal — `act1.md` §9 madde 43).*
   Act 1'de silme hiç geçmez; üçlü hiçbir defterde yok.

Kartın `dmNotes` alanı tek cümle: **ödenmiş silme fiyatlıdır ve fiyatı bellidir.**
*(2026-09-15: rakamı bilen taşıyıcı yok — Sicim çıktı çünkü liman insan yazmaz; Vinç
Ustası NPC olarak kalıyor ama bu bilgi ondan çıkarıldı.)*

`lore/Kural Sapmaları` 🟡: üç sayfanın da **sayıları** karar bekliyor (Diriltme
Sınavı'nın zarı, Kalıcı Yara bandları — `mekanikler.md` §11). Kart başlıkla ve
anlatıyla yazılır, `pages[]` içindeki rakamlar kilitlenmez.

Haneler ayrı kart değil — ait oldukları loncanın kartı içinde yazılır. Bir hane
masada karşılaşılan bir şeye dönüştüğünde (bir konak, bir isim) kendi kartını alır.

## 3. `location` — 33

| Kart | Üst (`parent_location_ref`) | Ne | Durum |
|---|---|---|---|
| **Aegis** | — | Dünya. Kökü tutan kart | ✅ |
| **Meridia** | Aegis | Kıta. Sancak Kaydı'nın geçerli olduğu yer | ✅ |
| **Vorstrand** | Aegis | Blight oradan geldi. Meridia'da kimse adını kullanmaz, **"Öte"** der | ✅ |
| **Gümüşsu** | Meridia | Huzursuz ama işleyen köy; kimse ölmemiş | ✅ |
| **Kulübe** | Gümüşsu | Karantina değil, köyün kendi kararı. Yiyecek götürülür, kimse girmez | ✅ |
| **Goodbarrel'ın Ocak Başı** | Gümüşsu | Hanlaşmış ev; köyde "haber" burada üretilir. 4 sp/gece | ✅ |
| **Gizli Liman** | Meridia | Kayıtsız çıkış. Bir yer değil bir **durum** | ✅ |
| **Rıhtım** | Gizli Liman | Limanın çalışan yüzü; üç iskele, tebeşir işareti, bayraksız tekneler | ✅ |
| **Lucid Triton** | Meridia | Beyaz mermer; hiçbir şey üretmez, **meşruiyet** üretir. Resmi kayıtta *Lucidum Triton* | ✅ |
| **Mühür Salonu** | Lucid Triton | Kararın alındığı değil **kayda geçtiği** oda | ✅ |
| **Meclis Salonu** | Lucid Triton | Altı koltuğun toplandığı oda; §8'in iki sahnesinin yeri | ✅ |
| **Karşı-İmza Masası** | Lucid Triton | Geçiş Divanı'nın kendisi; geçiş kağıdı buradan çıkar | ✅ |
| **Elymsyr** | Meridia | Resmi kapı; ikinci adı **Claport**. Altın Nehir'in kanyon ağzında, iki yakaya kurulmuş. Hep açık kapı ve kalkmayan zincir bu kartta. Mal buradan geçer, **kağıt şehre gider** | ✅ |
| **Gümrük Binası** | Elymsyr | Yükün açıldığı, tartıldığı ve yazıldığı salon; valinin odası üst katta | ✅ |
| **Aşağı Rıhtım** | Elymsyr | İki yakadaki antrepolar, hangarlar, gnome vinçleri. Gece boşaltmalarının yeri | ✅ |
| **Kanyon Asansörleri** | Elymsyr | Kanyon duvarındaki ahşap hat; mal iç yerleşimlere buradan çıkar. Halatçıların kendi çetelesi | ✅ |
| **Votumar** | Meridia | Paladin Şatosu. Beyaz kireçtaşı, askeri valilik, "Sarsılmaz Zırh" | ✅ |
| **Gözcü Kuleleri Hattı** | Votumar | İşaret ağı: gece ateş, gündüz dev aynalar. En uçta deniz feneri | ✅ |
| **Ravenhall Avlusu** | Meridia | Rünlü taş dairesi. Bölgenin tamamı **Yazısız** — ve bu bir tercih | ✅ |
| **Cinervik** | Meridia | Yol köyü. Han, at kiralama, nalbant. Söylenti bol **ve yanlış** | ✅ |
| **Argenfon** | Meridia | Kıyı köyü. Balıkçılık, Deniz Festivali, paladin dostluğu | ✅ |
| **Meclis Binası** | Lucid Triton | Dilekçe avlusu, altı loncanın kalemi; Meclis ve Mühür salonlarının üstü | ✅ |
| **Kalem Binası** | Lucid Triton | Meclis'in arkası. İnsan burada yazılır, geçiş burada imzalanır | ✅ |
| **Kayıt Salonu** | Kalem Binası | Ad koyma = kayda geçme. Dört kutu: ad · hane · lonca · kefil | ✅ |
| **Sınır ve Ticaret Loncası Divanhanesi** | Lucid Triton | Orvan'ın loncasının merkezi. En eski mühür, en bakımsız bina | ✅ |
| **Büyücü Loncası Akademisi** | Lucid Triton | Lisans masası, ışınlanma kaydı, sınama odası | ✅ |
| **Şifacılar Kışlası** | Lucid Triton | Çırak koğuşu, eczane, ölüm sebebi beyanı. Sindri burada | ✅ |
| **Yukarı Çarşı** | Lucid Triton | Ruhsatlı çarşı, ayar masası, görünür kolluk. Mallar karışık | ✅ |
| **Aşağı Çarşı** | Lucid Triton | Sur dibi: tamir, ikinci el, yazısız borç devri | ✅ |
| **Mimar Meydanı** | Lucid Triton | Ana meydan. Heykel, fener disiplini, törenler | ✅ |
| **Şehir Kapıları** | Lucid Triton | Girişin yazıldığı yer; gündüz ve gece defterleri ayrı | ✅ |
| **Sessiz Sokak** | Lucid Triton | Eski tanrıların sokağı; hiçbir mahalle defterinde yok | ✅ |
| **Nehir Yükleme Alanı** | Lucid Triton | Altın Nehir'in mavnaları, kantar, sur dışı ve içi | ✅ |

## 4. `npc` — 35

**Gümüşsu**

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **Duran** — köy başkanı *(insan)* | Köyün dağılmaması | Üçlünün nereden geldiğini biliyor | "Limandan geldiler" | ✅ |
| **Umay** — hastalara bakan *(yarı-elf)* | Üç kişinin yaşaması | Kendi de temas etti | Belirtilerin seyri (zarsız) | ✅ |
| **Corvin** — yolu bilen *(insan)* | Para | Gizli Liman'ı biliyor, oradan mal taşıdı | Gizli Liman'a rehberlik | ✅ |
| **Milo Goodbarrel** — hancı *(halfling)* | İşin yürümesi | — (yarasız NPC) | Söylenti, yabancı kaydı, kumaş | ✅ |
| **Halim** — lonca adamı *(insan)* | İşi bitirip dönmek | Kimin yolladığını | Orvan Sancar'ın adı, Meclis'e kısa yol | ✅ |

**Kulübe** — üçü de hasta hali; her birinin `monster` ikizi var, `species_ref` SRD'ye

| Kart | Ne | Durum |
|---|---|---|
| **Alton Leagallow** (halfling) | Yorgunluk hattı. Zengin, **adı sahte** — gerçeği *Cortia Greenbottle*. Merla'nın kocası | ✅ |
| **Merla Tealeaf** (halfling) | Değişkenlik hattı. Zengin, **adı sahte** — gerçeği *Portia Greenbottle*. Alton'ın karısı; kayıtta ayrı soyadı taşıyorlar | ✅ |
| **Kromanna** (tiefling, kadın) | Beden hattı. Çiftin hizmetlisi ve koruyucusu — köle değil, tutulmuş. **Adı gerçek:** tiefling adı saklanamaz. Yüzük onun **gizli cebinde** (4. tur — parmağında değil) | ✅ |

**Gizli Liman**

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **Sicim** — mal defterini tutan | Limanın işlemesi | Gerçek adı Burgell | Ücret · kefalet · üçlünün izi **ve izin bittiği yer** | ✅ |
| **Fare** — rıhtım çırağı | Bir gemiye alınmak | — (yarasız NPC) | Her şey: kim ne zaman yanaştı | ✅ |
| **Kaptan Caelynn** *(yarı-elf)* | Göremediği yükü taşımamak | Üçlüyü geri çevirdi | Temiz yolculuk — yazı ya da yüksek fiyat | ✅ |
| **Kaptan Holg** *(yarı-orc)* | Para, hızlı sefer | Gemisi güvenilmez | Ucuz ve kötü yolculuk | ✅ |
| **Kadife** — konsey aracısı *(insan)* | Limanın konseye yararlı kalması | Hangi koltukların pay aldığı; defterdeki adı **Halet Custar** | Limanda bir lonca elinin olduğu · "İyi yazı"nın nasıl alındığı | ✅ |
| **Mine** — kuyumcu *(cüce)* | Tezgahının açık kalması | Yüzüğü eğeleyen el onunki; **damga vurmaz**; klan adını söylemiyor | Eğelemeden önce gördüğü yüz: kıtada karşılığı olmayan bir işaret | ✅ |

**Meclis — altı koltuk, altı inkâr.** Kartlar koltuk adıyla yazılır.

| Kart | İnkârı | Ne gizliyor | Durum |
|---|---|---|---|
| **Rektör — Quarion** (Büyücü, *elf*, hanesiz) | "Sınadık, hiçbir tespit büyüsü bir şey göstermedi" | Sonuç **okunamadı** — "yok" değil "bilmiyoruz" | ✅ |
| **Sınır ve Ticaret — Orvan Sancar** *(insan)* | *(tek inkâr etmeyen)* | Sicilinin kirli olduğunu; Corin'i o masaya kendisinin oturttuğunu | ✅ |
| **Kalfa Başı — Adrik Ferrun** (Demirci-İşçi, *cüce*) | "Tezgahlar dönüyor, üretim düşmedi" | Aynı adamlar iki vardiya çalışıyor | ✅ |
| **Baş Otacı — Caramip Kalender** (Simya, *gnome*) | "İlerlemiş bir humma. Adı var, tedavisi var" | Beyanları kendisi değiştirtti | ✅ |
| **Sicil Ağası — Valen Custar** (Askeri Hukuk, *insan*) | "Hastalık hukuki bir kategori değil" | Yetkisi var, kullanmıyor | ✅ |
| **Levha Sahibi — Perhun Mizan** (Mimarlık, *insan*) | "Bu şehir hastalanmayacak biçimde planlandı" | Sur onarımı kağıt üstünde kaldı | ✅ |

**Lucid Triton sokağı**

| Kart | Nerede | Hangi kapıyı açar | Durum |
|---|---|---|---|
| **Corin Sancar** — geçiş memuru *(insan)* | Karşı-İmza Masası | **Kilit** — karşı-imzayı verir ya da yığının altına kaydırır; masada Orvan'ın kayırmasıyla oturuyor | ✅ |
| **Kildrak Ferrun** — ayar ustası *(cüce)* | Demirci çarşısı | Yüzüğün tezgahı: fihristten hangi kuyumcunun vurduğu | ✅ |
| **Sindri** — simyacı çırağı *(gnome)* | Şifacılar kışlası | Hastalığın şehirde **bilindiğinin** belgesi | ✅ |
| **Kandil** — borçlu esnaf *(insan)* | Çarşı | Sokak hattı, lonca kolluğu, şehirde "iyi para" | ✅ |
| **Çavuş Krusk** — kolluk çavuşu *(yarı-orc)* | Kapılar / gece devriyesi | Kapılar, gece hareketi, kimin şehre girdiği | ✅ |

**Elymsyr** — `bolgeler.md` §2.7. Kartlar **unvanla** yazılır; adlar ayrı turda.

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **Gümrük Valisi** *(insan)* | Rakamların düzgün görünmesi | Eksik boşaltılan yükün defterde tam yazıldığını | Resmi geçiş; "iyi yazı"nın burada da geçtiği | 🟡 ad |
| **Nehir Muhafızı Çavuşu** *(insan)* | Zincirin denenmemesi | Mekanizmanın bakımsız olduğunu | Boğaz, kuleler, hangi gemi ne zaman geçti | 🟡 ad |
| **Vinç Ustası** *(gnome)* | Tezgahının kapanmaması | Bazı gece boşaltmalarına vinç verdiğini | Kayıtsız yükün **resmi** limandan geçişi | 🟡 ad |
| **Çevirmen** *(yarı-elf)* | Bir sonraki işi | Duyduğu her şeyi | **Vorstrand**'dan taze haber | 🟡 ad |

**Votumar** — `bolgeler.md` §3.7

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **Başkumandan — Varhan** *(insan görünümünde)* | İtaat ve zaman | **Suretsiz olduğunu** (`secrets`). Ne aradığı yazılmadı. **İki aydır şatoda değil** — başkentte, yanında iki yardımcısından biri | Şatonun her kapısı; ve hiçbiri | ✅ |
| **Başkumandan Yardımcısı — Aren** *(tiefling, kadın)* | Yanıldığının kanıtlanması | Başkumandan'ın soğukluğunu fark ettiğini; şüphesinin bir kısmının geride bırakılmaktan geldiğinden korktuğunu | Çatlak — inanılacak ilk kurum içi ses, ve şatonun kalemi | ✅ |
| **Kapı Komutanı — Nevra** *(insan)* | Nöbetinin temiz kapanması | Son iki ayda **hiçbir emrin yazılı gelmediğini**; defterde çıkış satırı var, dönüş satırı yok | Şatoya giriş; ve kayıt evreninde en ağır kanıt: yazılı emir yokluğu | ✅ |
| **Ocak Ustası — Torvun** *(cüce)* | Ocakların durmaması | İkmal emirlerinin de iki aydır ağızdan geldiğini; bunu kendi kusuru sandığını | Aynı eksiğin ikinci, daha kolay açılan tanığı | ✅ |
| **Şato Kâtibi — Nerion** *(ejderdoğan, kadın)* | Defterin eksiksiz kapanması | Gelmeyen bir gece kaydının boşluğunu kendi eliyle doldurduğunu | Kayıt ucu: işaretin şatoda nerede durduğu | ✅ |
| **Kule Nöbetçisi — Vrask** *(ejderdoğan)* | Gördüğünü rapor edebilmek | Bir gece raporunun şatoya ulaşmadığını | İşaret hattı: neyin görüldüğü ve neyin **silindiği** | ✅ |
| **Gözcü Yüzbaşısı — Drahan** *(ejderdoğan)* | Hattın itibarı | O geceyi yazmamasının ağızdan bir emirle olduğunu; emri getireni tanımadığını | Hattın şato ucu: kaza değil karar — **ama kararı verenin adı hiçbir yerde yok** | ✅ |
| **Kıyı Kardeşleri — Kessa, Bram ve Tomas** *(iki insan, bir tiefling)* | Teknenin ve birbirlerinin güvende kalması | Aynı gece kıyıdan bir ışık gördüklerini; o saatte orada olmamaları gerektiğini | Susan gecenin **sivil** tanığı; şatoya girmeden ulaşılır. **Üç kardeş, tek kart** | ✅ |

**Ravenhall** — `bolgeler.md` §4.6

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **En Yaşlı Druid** *(insan / elf)* | Platonun kayda girmemesi | Çürümeyi **ne zamandır** bildiğini | Blight'ın doğadaki okunuşu: nerede başladı, hangi yöne yürüyor | 🟡 ad |
| **Patika Gözcüsü** *(yarı-elf)* | Kimsenin yukarı çıkmaması | Son aylarda çıkmayı deneyen ilk kişilerin kim olduğunu | Kimin Ravenhall'ı aradığı — ve neden | 🟡 ad |

> **İki taşıyıcı kuralı (5. tur güncellemesi):** *limana nasıl gidilir* iki yerde
> (Duran/Corvin · yüzük→Kildrak). ~~*Silme oldu mu* iki yerde (Sicim · Mine).~~ *2026-09-15:* limanda insan yazılmadığı
> için Sicim'in defterinde silinen satır yok; *bir kimlik silindi* bilgisi yalnız **Mine**'da
> (eğelenmiş yüzük) — tek taşıyıcı, ama kritik değil; Mine mührün orijinal halini de
> verebilir (`act1.md` §9 madde 43).
> Eski hali aşağıdaydı ve *kim ödedi* hattı 5. turda kaldırıldı:
>
> ~~*kim ödedi* üç yerde (Sicim · Geçiş Memuru · Ayar
> Ustası). *Kaydı kim sildirdi* iki yerde (Sicim · Mine). *Kayıtsız geçiş nasıl
> satın alınır* iki limanda birden (Sicim · Vinç Ustası). *Başkumandan'da bir
> terslik var* iki bağımsız yerde (Şüpheci Rütbeli · Kule Nöbetçisi).

**Adı bekleyen 6 NPC** (🟡): Elymsyr'in dördü, Ravenhall'ın ikisi. *(Votumar'ın kadrosu 2026-09-17'de adlandırıldı ve sekize çıktı.)*
Adlandırma kuralları aşağıda hazır; kart unvanla yazılır ve ad tek grep'le girer —
`npc/Konsey Aracısı`'nın **Kadife** olmadan önceki hali gibi.

## 5. `monster` — 7

| Kart | Ne | Durum |
|---|---|---|
| **Dönüşmüş** | Jenerik gövde: Blight'lı köylü. CR 1/8, AC 11, HP 16, Güçlü Pençe Saldırısı +2 (1d8) | ✅ |
| **Dönüşmüş Alton** | Halfling, Small, AC 9, HP 12, CR 1/8 | ✅ |
| **Dönüşmüş Merla** | Halfling, Small, AC 9, HP 12, CR 1/8 | ✅ |
| **Dönüşmüş Kromanna** | Tiefling, AC 11, HP 16, ateşe direnç, CR 1/4 | ✅ |

| **Yumuşak** | Hıkka, yeni kabuk atmış yavru. Small, AC 11, HP 7, CR 1/8. Fiziksel hasara zayıf, dövüşmez | ✅ |
| **Kavkı** | Hıkka, yetişkin. Small, AC 14, HP 13, CR 1/4. Karaya çıkan bu; kışkırtılınca eşik yok | ✅ |
| **Bırakmayan** | Kabuk değiştirmeyi bırakmış yaşlı. Small, AC 18, HP 44, CR 2, büyüsüz fiziksele dirençli. Sudan çıkmaz, kovalamaz | ✅ |

Son üçü `location/Gelgit Ağzı` kolonisi — `bolge §5.3`, ırk kartı `lore/Hıkka — Kitaplardaki Kayıt`.

İlk üçü jenerik gövdeden türer ve `npc` ikizine linklidir. SRD'de birebir adı olan
hiçbir yaratık tekrar yazılmaz, ref verilir.

## 6. `creature-action` — 3 · `trait` — 4 (+ alt sınıf trait'leri §14)

Statblokların gövdesi; `monster` kartlarına ref'lenir.

| Kart | Tip | Ait olduğu | Durum |
|---|---|---|---|
| **Pençe Saldırısı** | `creature-action` | Küçük bedenler — +2, 1d4 delici | ✅ |
| **Güçlü Pençe Saldırısı** | `creature-action` | Orta/güçlü bedenler — +2, 1d8 delici | ✅ |
| **Sıçrayıp Isırma** | `creature-action` | Dördü de — şarj 5–6, 15 ft sıçrayış, saldırı zarı yok, 1d8 + CON DC 8 → +1 Hastalık Puanı | ✅ |
| **Acıyı Tanımaz** | `trait` | 0 HP'de ölüm zarı atmaz, ölür | ✅ |
| **Durmayan Adım** | `trait` | Alton: yarı HP altında hız 40 ft, fırsat saldırısı yemez | ✅ |
| **Kesik Kesik** | `trait` | Merla: sıra başında açıkta 1d6 — 1-2 eylem kaybı, 5-6 ek saldırı | ✅ |
| **Erken Güçlenme** | `trait` | Kromanna: ilk turunda ek Pençe | ✅ |

## 7. `curse` — 1

| Kart | Ne | Durum |
|---|---|---|
| **Blight — Enfeksiyon** | Maruziyet CON DC 12 → +1 Hastalık Puanı (Dönüşmüş ısırığı CON DC 8) · günlük CON DC 13 → +1 (güvenli bölgede uzun dinlenme alınmayan her gün; alınsa bile her 3 günde bir) · beş aşama: Kuluçka 1–2 · Sistemik Yayılma 3–4 · Ağır Bozulma 5–6 · Morfolojik Çözülme 7–8 · Tam Çöküş 9+ (dönüşüm, geri dönüş yok) · puan silinmez; vahşide Medicine DC 15 o günün zarını atlatır · tedavi: *Lesser Restoration* sonraki zara +2, *Greater Restoration* +4 | ✅ |

Act 1'de **fiilen işleyen** kural sapması; kartta sapma işareti zorunlu. Halkın
bildiği yüzü ayrı kart: `lore/Blight — Bilinen Hali`.

Karta ayrıca **Yozlaşma Kontrolü** (cephenin ötesinde 3+ seviye büyü → CON ya da
Spellcasting Ability DC 13, başarısızlıkta +1 Hastalık Puanı) ve şifa büyülerinin **yapana**
bedeli girer (`mekanikler.md` §6–7). Dünyanın kalan sapmaları ayrı kart:
`lore/Kural Sapmaları`.

## 8. `scene` — 15

| Kart | Yer | Ne | Durum |
|---|---|---|---|
| **Köye Varış** | Gümüşsu | İlk karşılaşma; köy huzursuz ama ayakta | ✅ |
| **Kulübe Sorgusu** | Kulübe | Üçünün son konuşabilen hali | ✅ |
| **Şafak Dönüşümü** | Kulübe | Üçü döndüğünde — anı DM'in | ✅ |
| **Limana Kabul** | Gizli Liman | Birinci kapı: kefil, iş veya yük | ✅ |
| **Geçiş Pazarlığı** | Rıhtım | İkinci kapı: iyi yazı ya da iyi para | ✅ |
| **Meclis Oturumu** | Meclis Salonu | Altı koltuk, beş inkâr, inkâr etmeyen tek üye | ✅ |
| **Kapı Önündeki Teklif** | Meclis Salonu | Orvan'ın elindeki teklif, ne zaman yapacağı yazılmaz: "onları geçireni bana getirin" | ✅ |
| **Geçiş Divanı'nda Sıra** | Geçiş Divanı | **Kilit sahnesi** (5. tur): Orvan'ın imzası elde, Corin ikinciyi vermiyor. Rüşvet · Orvan'ın adı · terfi | ✅ |
| **Gümrük Rıhtımı** | Elymsyr | Yükün didik didik edilmesi; kaydın çıkması, kağıdın şehre gitmesi. İyi yazı buradan da gemiye bindirir (5. tur) | ✅ |
| **Avluda Karşılanma** | Ravenhall Avlusu | Şaşırmayan bir yaşlı. Bilgi kazanılmıyor, **teslim alınıyor**. Patikanın iki anahtarı: gözcüyü ikna · çürümeden söz etmek | ✅ |
| **Kapıya En Yakın Masa** | Goodbarrel'ın Ocak Başı | **Kilit sahnesi** (kapı turu): Halim'in kim olduğu → Orvan Sancar'ın adı ve Lucid Triton yolu | ✅ |
| **Dilekçe Avlusu** | Meclis Binası | **Kilit sahnesi** (kapı turu): Meclis Salonu'na giriş. Lonca hattı · Halim'in anlattıkları · bir koltuğun adı · rüşvet/sabır | ✅ |
| **Ayar Masası** | Yukarı Çarşı | **Kilit sahnesi** (kapı turu): Kildrak yüzüğü okur, ad değil **yön** verir — limana ikinci kapı | ✅ |

## 9. `encounter` — 1

| Kart | Ne | Durum |
|---|---|---|
| **Şafak Çatışması** | Üç Dönüşmüş, toplam 100 XP (zorluk `Low`). Yumuşatma kolu: Alton önce, diğer ikisi bir tur sonra | ✅ |

## 10. `quest` — 6

| Kart | Zincir | Durum |
|---|---|---|
| **Söylentinin Peşinde** | Giriş kancası: söylenti Gümüşsu'ya çıkar. Açık kapılar — köy · kulübe · dönüşüm · şehir · şato · plato. **Üç kapanışı var:** bir makama ulaşmak · köyün bir sonuca bağlanması · köyü arkada bırakmak | ✅ |
| **Nereden Geldiler** | Yüzük → kayıtsız giriş → limanda soğur (*Kader*). Gerçek adlar iki taşıyıcıda: alyansın içi · tarif | ✅ |
| **İyi Yazı** | Kıtadan çıkış **kapı mekanizması**, görev değil: karşı-imza kapısı ya da para kapısı. Kullanılmayabilir | ✅ |
| **Gelgit Gecesi** | Argenfon'un sehpalarını boşaltan Hıkka kolonisi. **Amaç: yuvayı bulmak.** Yalnız köye uğrayan masaya açılır; dört kapanış (yer bulundu · şatoya bildirildi · baskın durdu · köy arkada bırakıldı) | ✅ |
| **Son Yazılı Emir** | Votumar'ın kapı kartı: Gümüşsu'da görüleni şatoya anlatmak. Muhatap **Aren**, ikna elde yazı varsa zarsız. İki kapı — mühürlü yazı (masa taşır, başkentte kapı açar) ya da sivil kıyafetli bir asker. Varhan'ın giderken bıraktığı iki maddelik emir `secrets`'ta | ✅ |
| **Sayım Açığı** | Şato ambarının sayımı tutmuyor. **Torvun** verir, çünkü kendisi arayamaz (arayan bildirir). Cevap ikili: bir çırak alıyor **ve** iki aydır yazılmayan bir çıkış onu gizliyor. Karar: insanı mı, boşluğu mu bildireceksin | ✅ |

## 11. `background` — 9

Hepsinin zorunlu alanı SRD ref'i: `granted_skill_refs` · `ability_score_options` ·
`asi_distribution_options` (`+2/+1`, `+1/+1/+1`) · `origin_feat_ref`. Evrene özel
*feature* yok — feature'ın işini eşya + kurgu yapar. `gold_alternative_gp` = 50.

| Kart | Skill | Tool | Origin feat | Eşya (kapı) | Başlangıç altını | Durum |
|---|---|---|---|---|---|---|
| **Arşivci** | Investigation · History | Cartographer's Tools | Skilled | Tasnif Çantası · Kayıt Elifbası · Sancak Fihristi | 12 | ✅ |
| **Lonca Üyesi** | Persuasion · Insight | Calligrapher's Supplies | Skilled | Lonca Mührü · Lonca Rozeti | 16 | ✅ |
| **Mertebeli Lonca Çocuğu** | Persuasion · History | Gaming Set | Lucky | Aile Mührü · Mertebe Kaftanı | 30 | ✅ |
| **Sihir Loncası Öğrencisi** | Arcana · Investigation | Alchemist's Supplies | Magic Initiate (Wizard) | Öğrenci Defteri | 16 | ✅ |
| **Lonca Ajanı** | Deception · Insight | Forgery Kit | Alert | Sahte Mühür (+ SRD Forgery Kit) | 12 | ✅ |
| **Rıhtım İşçisi** | Athletics · Perception | Carpenter's Tools | Tavern Brawler | Yük Kancası (+ SRD Rope) | 8 | ✅ |
| **Gemi Kaptanı** | Persuasion · Survival | Navigator's Tools | Tough | Seyir Defteri | 16 | ✅ |
| **Paladin Askeri** | Athletics · Intimidation | Smith's Tools | Savage Attacker | Kışla Künyesi (+ SRD Spear) | 10 | ✅ |
| **Paladin Rütbelisi** | Religion · Persuasion | Calligrapher's Supplies | Healer | Emir Mührü | 20 | ✅ |

## 12. Eşya — 16

Kart evrenin adıyla yazılır; SRD muadili yalnız `description`'da anılır, ayrıca
ref'lenmez. `default_inventory_refs` SRD'ye değil **bu kartlara** ref verir.

| Kart | Kategori | SRD muadili | Kapı | Durum |
|---|---|---|---|---|
| **Tasnif Çantası** | `adventuring-gear` | Case, Map or Scroll | Occulus dışı arşivlerde okuma hakkı | ✅ |
| **Kayıt Elifbası** | `adventuring-gear` | Book | Kayıt kısaltmaları, damgalar, tasnif işaretleri | ✅ |
| **Sancak Fihristi** | `adventuring-gear` | Book | Hangi kaydın hangi makamda tutulduğu | ✅ |
| **Mertebe Kaftanı** | `adventuring-gear` | Clothes, Fine | Odaya girildiğinde kimin konuşacağı | ✅ |
| **Öğrenci Defteri** | `adventuring-gear` | Spellbook | Lonca kütüphanesi; her açılış kayda geçer | ✅ |
| **Yük Kancası** | `adventuring-gear` | Grappling Hook | Kaçak yollar ve işçi ağı | ✅ |
| **Seyir Defteri** | `adventuring-gear` | Book | Rota ve yanaşma hakkı; limanda kimlik yerine geçer | ✅ |
| **Direnç Şerbeti** | `adventuring-gear` | — (yeni nesne) | Hastalığa karşı **tek** savunma: 24 saat, Blight kurtarma zarlarına **+8**. Ruhsatlı bir otacı, Druid bilgisi ya da Simya Seti üretir (`mekanikler.md` §7) | 🟡 |
| **Mühürlü Yazı** | `adventuring-gear` | — (yeni nesne) | Aren'in vekaleten imzalayıp mühürlediği rapor. Başkentte sıra beklemeden kapı açar; mühür bir kez kırılır | ✅ |
| **Lonca Mührü** | `trinket` | Signet Ring | Barınma, kredi, isim sorma hakkı | ✅ |
| **Lonca Rozeti** | `trinket` | — (yeni nesne) | Görünür üyelik: kapıda tartışma bitirir | ✅ |
| **Aile Mührü** | `trinket` | Signet Ring | Kapılar isimle açılır, isim yükümlülük getirir | ✅ |
| **Sahte Mühür** | `trinket` | Signet Ring | Çalışan bir yalan. Yakalanırsa suç | ✅ |
| **Kışla Künyesi** | `trinket` | Emblem (Holy Symbol) | Düzenin lojistiği: yemek, yatak, geçiş | ✅ |
| **Emir Mührü** | `trinket` | Signet Ring + Sealing Wax | Sorgusuz geçiş ve düzen içi bilgi | ✅ |
| **Mühürsüz Yüzük** | `trinket` | — (yeni nesne) | **Gizli cepte** taşınan tek nesne (act1.md §3.3 iz 3). **KAPANDI (5. tur):** mühür yüzü eğelenmiş, **damgasız**, yakın zamanda işlenmiş | ✅ |

Mühür bu evrenin merkezî nesnesi: Sancak Kaydı'nda mühür bir deftere yazma
yetkisidir. On dört kartın **beşi** mühür, ve **Mühürsüz Yüzük** diğer dördünün karşı
kutbudur — açıkta taşınan mühür "defterdeyim" der, gizli cepte taşınan yüzük tersini
ima eder.

⚠️ **4. tur (2026-09-09):** yüzük artık Kromanna'nın parmağında değil, **gizli bir
cepte**; bulunması **Investigation DC 15** ister ve mühür taşıyan PC'nin zarsız okuma
imtiyazı kalktı.

✅ **5. tur (2026-09-13): içerik kapandı** (act1.md §3.3, §9 açık 5 kapalı). Mühür
yüzü eğelenerek düzleştirilmiş, **üstünde hiçbir damga yok** — ne ayar damgası, ne
usta işareti, ne hane mührü. Kartın `description`'ı bunu yazıyor.

**SRD'de kalanlar** (kart açılmaz, ref verilir): Cartographer's Tools ·
Calligrapher's Supplies · Gaming Set · Alchemist's Supplies · Forgery Kit ·
Carpenter's Tools · Navigator's Tools · Smith's Tools · Rope · Spear.

## 13. `species` — 0 (bloke)

Yeni ırk kartı **yazılmaz**; ırksal özelliklerin kaynağı kararı açık. Blok yazmayı
engelliyor, **ref vermeyi değil**: SRD'de adı birebir olan bir ırka `species_ref`
verilir (Halfling · Tiefling).

## 14. `subclass` — 4 ✅

Tasarımın tamamı [`alt-siniflar.md`](alt-siniflar.md); burada sadece sayılıyorlar.
`class` kartı **yazılmıyor** — SRD'nin on iki sınıfı olduğu gibi duruyor.

| Kart | Ana sınıf | Ne | Durum |
|---|---|---|---|
| **Clockwork Soul** | Sorcerer (1. sv) | Mechanus'un düzeninden gelen büyü: fazlalığı siler, eksiği tamamlar, sapmayı hizaya çeker | ✅ |
| **Drakewarden** | Ranger (3. sv) | Bir drake ile kurulan bağ; yoldaş, binek ve silah. Ejderha değil `beast`, ve hiçbir seviyede **uçuş yok** | ✅ |
| **İrade Yemini** | Paladin (3. sv) | Gücü tanrıdan değil **yeminden** gelen paladin. +1 Güç, History + Investigation yetkinliği, Divine Smite yerine **Yemin Darbesi**, ve bir soruşturma büyü listesi | ✅ |
| **Siper Okulu** | Wizard (3. sv) | Çağrı zarı güvenilir iyileştiriciyi ortadan kaldırdı; bu okul boşluğu **iyileştirerek değil, hasarı aldırmayarak** kapatır. Abjuration büyüsünün sırtında, oyuncunun seçtiği anda örülen ve 0 canda **kırılan** günlük bir **Siper** (`2 × sv + Zeka`), 6. seviyede dostlara uzatılan tepki, 10'da **Karşı Büyücü** | ✅ |

Bağlı kartlar: `animal/Drake` · 21 `trait` · 10 `creature-action` · 9 `resource-pool`
satırı — hepsi [`alt-siniflar.md` §5](alt-siniflar.md)'te adıyla sayılı.

İlk ikisi WotC kaynaklarından **olduğu gibi alındı** — içerik ve isimlendirme özgünüyle
aynı — ve her kartın `source` alanı bunu söylüyor (`Tasha's Cauldron of Everything` ·
`Fizban's Treasury of Dragons`). **Son ikisi ithal değil:** çağrı zarı
([`mekanikler.md` §3.1](mekanikler.md)) Cleric ve Warlock'u oynanamaz yaptı;
**İrade Yemini** Paladin'in bu kıtada nasıl ayakta kaldığını, **Siper Okulu** da
iyileştiricisi olmayan bir grubun nasıl ayakta kaldığını söylüyor.
Sapma defteri [`alt-siniflar.md` §6](alt-siniflar.md).

---

## Sayım

| Kategori | ✅ | 🟡 | ⬜ | Toplam |
|---|---|---|---|---|
| `campaign` | 1 | — | — | 1 |
| `lore` | 22 | 1 | — | 23 |
| `location` | 34 | — | — | 34 |
| `npc` | 31 | 10 | — | 41 |
| `monster` | 7 | — | — | 7 |
| `creature-action` | 16 | — | — | 16 |
| `trait` | 31 | — | — | 31 |
| `curse` | 1 | — | — | 1 |
| `scene` | 15 | — | — | 15 |
| `encounter` | 1 | — | — | 1 |
| `quest` | 6 | — | — | 6 |
| `background` | 9 | — | — | 9 |
| `adventuring-gear` | 8 | 1 | — | 9 |
| `trinket` | 7 | — | — | 7 |
| `species` | — | — | 0 | 0 (bloke) |
| `subclass` | 4 | — | — | 4 |
| `animal` | 1 | — | — | 1 |
| `resource-pool` | 9 | — | — | 9 |
| **Toplam** | **203** | **12** | **—** | **215** |

**203/215 ✅, 12 🟡, 0 ⬜** *(2026-09-19, Votumar'ın iki işi: `quest/Son Yazılı Emir` ·
`quest/Sayım Açığı` · `adventuring-gear/Mühürlü Yazı`; 212'den 215'e. Yeni kanon
[`bolgeler.md` §3.6, §3.8](bolgeler.md) — Varhan'ın giderken bıraktığı iki maddelik
yazılı emir, ve şatonun bir yabancıya iş vermesinin üç geçerli sebebi.)*

Öncesi: **200/212 ✅** *(2026-09-16, kapı turu: üç kilit sahnesi —
`scene/Kapıya En Yakın Masa` · `scene/Dilekçe Avlusu` · `scene/Ayar Masası`;
187'den 190'a. Aynı turda bütün sahnelere `## Kapı` bloğu, üç görev kartına açık
kapı listesi ve çoklu kapanış yazıldı.)*

Öncesi: **175/187 ✅** *(2026-09-13, Siper Okulu turu: `subclass/Siper Okulu`,
dört okul `trait`'i, `creature-action/Siperi Uzat` + `Siperi Ör` ve `pool:siper` —
164'ten 172'ye. Wizard'a çağrı zarına girmeyen bir destek hattı yazıldı, ve siper
aynı turda **günde bir / kırılabilir** hâline çekildi;
[`alt-siniflar.md` §4](alt-siniflar.md).)*

**Elymsyr turu (2026-09-16):** resmi limana 4 alt mekan yazıldı — 184'ten 188'e; sonra `location/Boğaz ve Zincir` geri çekildi (187), içeriği şehir kartının **Kapı ve zincir** bölümüne taşındı: boğaz kendi başına bir mekan değil, kentin bir özelliği.
Kentin kaynak metni kanona alındı: ordunun adı **Demir Lejyon** (`bolgeler.md` §9 açık 2'nin
ad yarısı kapandı), kent **iki parça** (su üstü giriş yapıları + yamaç terasları), balistalar
örtülü ve **ticareti ürkütmemek için** saklı, kent kıtanın **yüzü**, ve ırklara göre oturmuş
bir işbölümü. Dört NPC tek "Elymsyr" kartından kendi mekanlarına dağıldı; `scene/Gümrük
Rıhtımı` artık `Gümrük Binası`'na bağlı. `lore/Fihrist` s.5 yer ağacı yeniden yazıldı —
Lucid Triton'ın 12 alt mekanı da oraya girdi.

*Aynı turda yazılıp geri alındı:* `scene/Gece Boşaltması` · `scene/Zincir Denemesi` ·
`encounter/Antrepo Araması`. Zincir sahnesi §2.3'ün *"karar verilmeden manzara, sonra
sahne"* kuralına aykırıydı (M0.6 açık), antrepo baskını da "Yazılmayacaklar"daki *kavga
bir kurgu değil bir sonuç* maddesine. Taşıdıkları bilgi mekan kartlarının `secrets`
alanında duruyor.
Kentin coğrafyası kanona girdi (`bolgeler.md` §2): **Altın Nehir**'in kanyon ağzı, iki
yakaya kurulmuş ve ağzın dışına taşmış kent, **hep açık kapı**, ve **uzun zamandır
kaldırılmayan zincir**. **Teraslar** bilerek kart değil: NPC'si ve sahnesi yok, manzarası ana kartta duruyor.

**Lucid Triton turu (2026-09-16, 0.9.0):** başkente 12 alt mekan yazıldı — 172'den 184'e.
`Meclis Salonu` ve `Mühür Salonu`'nun üstü **Meclis Binası**, `Karşı-İmza Masası`'nınki
**Kalem Binası** oldu; `Kildrak Ferrun` · `Kandil` · `Sindri` · `Çavuş Krusk` kendi
mekanlarına taşındı. Nehrin adı bu turda kondu: **Altın Nehir** (`bolgeler.md` §9 madde 5).

Öncesi: **152/164 ✅** *(2026-09-13, denge turu: dört `Pençe` kartı iki karta indi (**Pençe Saldırısı** · **Güçlü Pençe Saldırısı**), `trait/Bulaştıran Yara` kaldırıldı, ve bulaşma tek bir yeniden-şarjlı eyleme taşındı: **Sıçrayıp Isırma**.)*

> **Tablo hizalaması (2026-09-13).** Satırlar denge turundan sonra güncellenmemişti
> ve 166 topluyordu; `creature-action` 12→11 ve `trait` 22→21 yazıldı. `location`
> 17✅/1🟡 → 18✅: §3 tablosu 17 satır sayıyor ama 18. mekan **Meclis Salonu** yazıldı
> ve hiçbir alanı boş değil, yani 🟡 değildi. Toplam **164** baştan doğruydu.

Öncesi: **153/166 ✅** *(2026-09-13, çelişki turu: +1 `quest` — **İyi Yazı**.)*
Öncesi: **152/165 ✅** (2026-09-13, ilahi büyü turu — 154'ten 165'e: `npc/Halim`,
`subclass/İrade Yemini`, altı yemin `trait`'i ve iki `resource-pool` satırı).

**Öncesi (alt sınıf turu):** 141/154 ✅, 13 🟡, 0 ⬜ (2026-09-11) — 127'den 154'e;
[`alt-siniflar.md`](alt-siniflar.md) 27 kart ekledi.

**Öncesi (kayıt turu):** 114/127 ✅, 13 🟡, 0 ⬜ (2026-09-10). Liste 97'den 127'ye çıktı:
[`bolgeler.md`](bolgeler.md) 24 kart (7 `lore` · 7 `location` · 10 `npc` · 3 `scene`),
[`mekanikler.md`](mekanikler.md) 2 kart (`lore/Kural Sapmaları` · `Direnç Şerbeti`),
kayıt turu 1 kart (`lore/Kayıt Nasıl İşler`, 0.4.0'da `Sancak Kaydı` s.2'ye taşındı) ekledi. **⬜ hâlâ yok** — yazılamayacak kart kalmadı.

12 🟡'nin **onu tek bir iş:** üç bölgenin NPC adları. Kalan ikisi sayı bekliyor:
`lore/Kural Sapmaları` (Diriltme Sınavı'nın zarı, Kalıcı Yara bandları) ve
`Direnç Şerbeti` (fiyat ve üretim süresi). Hiçbiri kartın yazılmasını engellemiyor —
hepsi tek bir alanı boş bırakıyor.

**Öncesi (adlandırma turu):** 97/97 ✅ — bekleyen tek şey olan adlar kondu, 16 🟡 ve
1 ⬜ kapandı. ⬜ olan **Kuyumcu** artık **Mine**, ve *kaydı kim sildirdi*'nin ikinci
taşıyıcısı yerine oturdu.

### Adlandırma kuralları (kartlar yazılırken uyulacak)

| Katman | Biçim | Kim | Örnek |
|---|---|---|---|
| **İki isim** | ad + hane | kayıtlı **ve** mensup | Orvan Sancar · Adrik Ferrun |
| **Tek isim** | yalnız ad | kayıtlı, hizmet eder | Duran · Umay · Quarion |
| **Lakap** | nesne / hayvan / alet | **kayıtsız** — defterde yok | Sicim · Fare · Kadife · Mine · Kandil |

- **Lakap, Sancak Kaydı'nın negatifidir.** Bir insana eşya adı takılmışsa mührü
  yoktur. Gizli Liman'ın tamamı lakapla konuşur; Lucid Triton'da tek lakap **Kandil**
  vardır ve o da adı olup borçtan düşmüş biridir. Oyuncu kuralı kimse söylemeden
  çözer.
- **Soyadı ≠ hane.** Halfling ve cüce soyadları (Goodbarrel, Leagallow, Tealeaf)
  aile geleneğidir; defter onları *"tek isim + boş hane"* yazar. Üçlünün sahte
  kimliği bunun üstüne kurulu: **kontrol edilecek bir kayıt yok.**
- **Ad ırkı söyler,** DM tarif etmez: insan (Doran, Valen, Corin), cüce sert
  ünsüz + klan, gnome kısa ve tıkırtılı, elf akıcı, halfling yumuşak ad + tasvir
  soyadı, tiefling cehennem kökü ya da erdem adı.

---

## Yazılmayacaklar (bilerek)

- **Karantina doktoru** — karantina yok; kulübe köyün kendi kararı.
- **Cerrahi iğne** — kimse kimseye bir şey yerleştirmedi. Perdenin "bu doğal değil"
  anını artık **beden** (Medicine DC 12) ve **Arcana DC 13** taşıyor (act1.md §4.6).
- **Mızrak parçası** ve **kolye (pusula)** — bu kapsamda yoklar; yokmuş gibi
  davranılır.
- **Üçlünün gerçek adları** — cevap limanın dışında.
- **Sicim'in defteri** — sahnede duran prop, ayrı karta ihtiyacı yok.
- **Liman kaçışı `encounter`** — kavga burada bir kurgu değil bir sonuç; DM
  doğaçlar. Üç sabit doğru: kimse yardıma gelmez · kaçmak pahalıdır (kefil kapanır) ·
  ölü bırakan bu limanı kaybeder.
- **Yol hakkı `quest`** — yol serbest. Fiyatı olan tek şey gemiye binmek, o da
  `scene/Geçiş Pazarlığı`.
- **Haneler** — ait oldukları loncanın `lore` kartında; masaya çıkana kadar ayrı
  kart değil.
