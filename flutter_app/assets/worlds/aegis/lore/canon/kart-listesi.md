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
| **İrade Çağı** | Tanrıların kesilmesi, özgürlüğün bedeli | ✅ |
| **Tanrılar ve Fısıltı** | Bant genişliği kalmamış sevgi; ilahi büyünün bugünkü durumu | ✅ |
| **Blight — Bilinen Hali** | Halkın bildiği yüz. Yön değil **taşıyıcı** anlatılır | ✅ |
| **Vorstrand — Bilinen Hali** | Hastalığın geldiği, üçlünün kaçtığı yer. Halk ağzında sadece **"Öte"** | ✅ |
| **Konsey ve Lonca Meclisi** | Konsey çerçeve, Meclis içerik; altı koltuğu loncalar doldurur | ✅ |
| **Sancak Kaydı** | Mühür = hukuki kimlik; kayıtsızın kaybolması kayda geçmez. Üç sınıf: **Mühürlü · Kayıtlı · Yazısız** | ✅ |
| **Kayıt Nasıl İşler** | Defterin işleyişi: kim yazar, ne yazılır, nasıl yükselinir, nasıl silinir. Sancak Kaydı'nın prosedür yüzü | ✅ |
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
| **Kural Sapmaları** | 3 sayfa: *Ölümün Ağırlığı* (diriltmenin bedeli) · *Işınlanma ve Mesafe* · *Kalıcı Yaralar* | 🟡 |

`lore/Kayıt Nasıl İşler` — `Sancak Kaydı` sınıfları anlatır, bu kart **işlemi**
anlatır. Altı sayfa, hepsi masada sorulan bir soruya karşılık gelir:

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
   sayfanın hiç yazılmamış gibi çıkarılması. Üçüncüsü suçtur ve Act 1'in bütün
   soruşturması odur: silinen sayfa arkasında iki iz bırakır — **kefilin karşı-imzası
   defterde kalır** (Corin Sancar) ve satırın kopyası taşra kaleminde durur (Orvan
   Sancar'ın "kendi defterinden sayfa silindi" dediği şey). Kağıt şehre gider, ama
   ikinci nüsha gitmez.

Kartın `secrets` alanı tek cümle: **ödenmiş silme fiyatlıdır ve fiyatı bellidir** —
Sicim de Vinç Ustası da aynı rakamı söyler, çünkü rakamı koyan yer aynıdır.

`lore/Kural Sapmaları` 🟡: üç sayfanın da **sayıları** karar bekliyor (Diriltme
Sınavı'nın zarı, Kalıcı Yara bandları — `mekanikler.md` §11). Kart başlıkla ve
anlatıyla yazılır, `pages[]` içindeki rakamlar kilitlenmez.

Haneler ayrı kart değil — ait oldukları loncanın kartı içinde yazılır. Bir hane
masada karşılaşılan bir şeye dönüştüğünde (bir konak, bir isim) kendi kartını alır.

## 3. `location` — 18

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
| **Karşı-İmza Masası** | Lucid Triton | Geçiş Divanı'nın kendisi; geçiş kağıdı buradan çıkar | ✅ |
| **Elymsyr** | Meridia | Resmi kapı; ikinci adı **Claport**. Teraslı taş kent, gnome vinçleri, gümrük. Mal buradan geçer, **kağıt şehre gider** | ✅ |
| **Votumar** | Meridia | Paladin Şatosu. Beyaz kireçtaşı, askeri valilik, "Sarsılmaz Zırh" | ✅ |
| **Gözcü Kuleleri Hattı** | Votumar | İşaret ağı: gece ateş, gündüz dev aynalar. En uçta deniz feneri | ✅ |
| **Ravenhall Avlusu** | Meridia | Rünlü taş dairesi. Bölgenin tamamı **Yazısız** — ve bu bir tercih | ✅ |
| **Cinervik** | Meridia | Yol köyü. Han, at kiralama, nalbant. Söylenti bol **ve yanlış** | ✅ |
| **Argenfon** | Meridia | Kıyı köyü. Balıkçılık, Deniz Festivali, paladin dostluğu | ✅ |

## 4. `npc` — 34

**Gümüşsu**

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **Duran** — köy başkanı *(insan)* | Köyün dağılmaması | Üçlünün nereden geldiğini biliyor | "Limandan geldiler" | ✅ |
| **Umay** — hastalara bakan *(yarı-elf)* | Üç kişinin yaşaması | Kendi de temas etti | Belirtilerin seyri (zarsız) | ✅ |
| **Corvin** — yolu bilen *(insan)* | Para | Gizli Liman'ı biliyor, oradan mal taşıdı | Gizli Liman'a rehberlik | ✅ |
| **Milo Goodbarrel** — hancı *(halfling)* | İşin yürümesi | — (yarasız NPC) | Söylenti, yabancı kaydı, kumaş | ✅ |

**Kulübe** — üçü de 1. gün hali; her birinin `monster` ikizi var, `species_ref` SRD'ye

| Kart | Ne | Durum |
|---|---|---|
| **Alton Leagallow** (halfling) | Yorgunluk hattı. Zengin, **adı sahte** — gerçeği *Cortia Greenbottle*. Merla'nın kocası | ✅ |
| **Merla Tealeaf** (halfling) | Değişkenlik hattı. Zengin, **adı sahte** — gerçeği *Portia Greenbottle*. Alton'ın karısı; kayıtta ayrı soyadı taşıyorlar | ✅ |
| **Kromanna** (tiefling, kadın) | Beden hattı. Çiftin hizmetlisi ve koruyucusu — köle değil, tutulmuş. **Adı gerçek:** tiefling adı saklanamaz. Yüzük onun **gizli cebinde** (4. tur — parmağında değil) | ✅ |

**Gizli Liman**

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **Sicim** — defter tutan | Limanın işlemesi | Üçlünün geçişini kimin sildirdiğini | Ücret · kefalet · üçlünün izi | ✅ |
| **Fare** — rıhtım çırağı | Bir gemiye alınmak | — (yarasız NPC) | Her şey: kim ne zaman yanaştı | ✅ |
| **Kaptan Caelynn** *(yarı-elf)* | Göremediği yükü taşımamak | Üçlüyü geri çevirdi | Temiz yolculuk — yazı ya da yüksek fiyat | ✅ |
| **Kaptan Holg** *(yarı-orc)* | Para, hızlı sefer | Gemisi güvenilmez | Ucuz ve kötü yolculuk | ✅ |
| **Kadife** — konsey aracısı *(insan)* | Limanın konseye yararlı kalması | Hangi koltukların pay aldığı; defterdeki adı **Halet Custar** | "İyi yazı"nın nasıl alındığı | ✅ |
| **Mine** — kuyumcu *(cüce)* | Tezgahının açık kalması | Yüzüğü eğeleyen el onunki; **klan adını söylemiyor** | *Kaydı kim sildirdi*'nin ikinci taşıyıcısı ⚠️ *(yüzük kararına bağlı, 4. tur)* | ✅ |

**Meclis — altı koltuk, altı inkâr.** Kartlar koltuk adıyla yazılır.

| Kart | İnkârı | Ne gizliyor | Durum |
|---|---|---|---|
| **Rektör — Quarion** (Büyücü, *elf*, hanesiz) | "Sınadık, hiçbir tespit büyüsü bir şey göstermedi" | Sonuç **okunamadı** — "yok" değil "bilmiyoruz" | ✅ |
| **Sınır ve Ticaret — Orvan Sancar** *(insan)* | *(tek inkâr etmeyen)* | Kendi defterinden sayfa silindiğini | ✅ |
| **Kalfa Başı — Adrik Ferrun** (Demirci-İşçi, *cüce*) | "Tezgahlar dönüyor, üretim düşmedi" | Aynı adamlar iki vardiya çalışıyor | ✅ |
| **Baş Otacı — Caramip Kalender** (Simya, *gnome*) | "İlerlemiş bir humma. Adı var, tedavisi var" | Beyanları kendisi değiştirtti | ✅ |
| **Sicil Ağası — Valen Custar** (Askeri Hukuk, *insan*) | "Hastalık hukuki bir kategori değil" | Yetkisi var, kullanmıyor | ✅ |
| **Levha Sahibi — Perhun Mizan** (Mimarlık, *insan*) | "Bu şehir hastalanmayacak biçimde planlandı" | Sur onarımı kağıt üstünde kaldı | ✅ |

**Lucid Triton sokağı**

| Kart | Nerede | Hangi kapıyı açar | Durum |
|---|---|---|---|
| **Corin Sancar** — geçiş memuru *(insan)* | Karşı-İmza Masası | ***Kim ödedi*** — silinen sayfanın ikinci imzası onun | ✅ |
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
| **Başkumandan** *(insan görünümünde)* | İtaat ve zaman | **Suretsiz olduğunu** (`secrets`). Ne aradığı yazılmadı | Şatonun her kapısı; ve hiçbiri | 🟡 ad |
| **Kapı Komutanı** *(insan)* | Nöbetinin temiz kapanması | Son iki ayda **hiçbir emrin yazılı gelmediğini** | Şatoya giriş; ve kayıt evreninde en ağır kanıt: yazılı emir yokluğu | 🟡 ad |
| **Şüpheci Rütbeli** *(insan / ejderdoğan)* | Yanıldığının kanıtlanması | Başkumandan'ın soğukluğunu fark ettiğini | Çatlak — inanılacak ilk kurum içi ses | 🟡 ad |
| **Kule Nöbetçisi** *(ejderdoğan)* | Gördüğünü rapor edebilmek | Bir gece raporunun şatoya ulaşmadığını | İşaret hattı: neyin görüldüğü ve neyin **silindiği** | 🟡 ad |

**Ravenhall** — `bolgeler.md` §4.6

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **En Yaşlı Druid** *(insan / elf)* | Platonun kayda girmemesi | Çürümeyi **ne zamandır** bildiğini | Blight'ın doğadaki okunuşu: nerede başladı, hangi yöne yürüyor | 🟡 ad |
| **Patika Gözcüsü** *(yarı-elf)* | Kimsenin yukarı çıkmaması | Son aylarda çıkmayı deneyen ilk kişilerin kim olduğunu | Kimin Ravenhall'ı aradığı — ve neden | 🟡 ad |

> **İki taşıyıcı kuralı:** *kim ödedi* üç yerde (Sicim · Geçiş Memuru · Ayar
> Ustası). *Kaydı kim sildirdi* iki yerde (Sicim · Mine). *Kayıtsız geçiş nasıl
> satın alınır* iki limanda birden (Sicim · Vinç Ustası). *Başkumandan'da bir
> terslik var* iki bağımsız yerde (Şüpheci Rütbeli · Kule Nöbetçisi).

**Adı bekleyen 10 NPC** (🟡): Elymsyr'in dördü, Votumar'ın dördü, Ravenhall'ın ikisi.
Adlandırma kuralları aşağıda hazır; kart unvanla yazılır ve ad tek grep'le girer —
`npc/Konsey Aracısı`'nın **Kadife** olmadan önceki hali gibi.

## 5. `monster` — 4

| Kart | Ne | Durum |
|---|---|---|
| **Dönüşmüş** | Jenerik gövde: Blight'lı köylü. CR 1/2, AC 12, HP 22, Pençe +5 (1d8+3) | ✅ |
| **Dönüşmüş Alton** | Halfling, Small, HP 18, CR 1/2 | ✅ |
| **Dönüşmüş Merla** | Halfling, Small, HP 18, CR 1/2 | ✅ |
| **Dönüşmüş Kromanna** | Tiefling, HP 30, ateşe direnç, CR 1 | ✅ |

Üçü de jenerik gövdeden türer ve `npc` ikizine linklidir. SRD'de birebir adı olan
hiçbir yaratık tekrar yazılmaz, ref verilir.

## 6. `creature-action` — 4 · `trait` — 5

Statblokların gövdesi; `monster` kartlarına ref'lenir.

| Kart | Tip | Ait olduğu | Durum |
|---|---|---|---|
| **Pençe** | `creature-action` | Dönüşmüş — +5, 1d8+3 delici | ✅ |
| **Pençe (Alton)** · **Pençe (Merla)** | `creature-action` | +4, 1d6+2 delici | ✅ |
| **Pençe (Kromanna)** | `creature-action` | +6, 1d10+4 delici | ✅ |
| **Acıyı Tanımaz** | `trait` | 0 HP'de ölüm zarı atmaz, ölür | ✅ |
| **Bulaştıran Yara** | `trait` | İsabette CON DC 12 → +1 Hastalık Puanı | ✅ |
| **Durmayan Adım** | `trait` | Alton: yarı HP altında hız 40 ft, fırsat saldırısı yemez | ✅ |
| **Kesik Kesik** | `trait` | Merla: sıra başında açıkta 1d6 — 1-2 eylem kaybı, 5-6 ek saldırı | ✅ |
| **Erken Güçlenme** | `trait` | Kromanna: ilk turunda ek Pençe | ✅ |

## 7. `curse` — 1

| Kart | Ne | Durum |
|---|---|---|
| **Blight — Enfeksiyon** | Maruziyet CON DC 8 → +1 Hastalık Puanı · günlük CON DC 13 → +1 (güvenli bölgede uzun dinlenme alınmayan her gün; alınsa bile her 3 günde bir) · beş aşama: Kuluçka 1–2 · Sistemik Yayılma 3–4 · Ağır Bozulma 5–6 · Morfolojik Çözülme 7–8 · Tam Çöküş 9+ (dönüşüm, geri dönüş yok) · puan silinmez; vahşide Medicine DC 15 o günün zarını atlatır · tedavi: *Lesser Restoration* sonraki zara +2, *Greater Restoration* +4 | ✅ |

Act 1'de **fiilen işleyen** kural sapması; kartta sapma işareti zorunlu. Halkın
bildiği yüzü ayrı kart: `lore/Blight — Bilinen Hali`.

Karta ayrıca **Yozlaşma Kontrolü** (cephenin ötesinde 3+ seviye büyü → CON ya da
Spellcasting Ability DC 13, başarısızlıkta +1 Hastalık Puanı) ve şifa büyülerinin **yapana**
bedeli girer (`mekanikler.md` §6–7). Dünyanın kalan sapmaları ayrı kart:
`lore/Kural Sapmaları`.

## 8. `scene` — 11

| Kart | Yer | Ne | Durum |
|---|---|---|---|
| **Köye Varış** | Gümüşsu | İlk karşılaşma; köy huzursuz ama ayakta | ✅ |
| **Kulübe Sorgusu** | Kulübe | Üçünün son konuşabilen hali | ✅ |
| **Şafak Dönüşümü** | Kulübe | Üçü tamamen döner | ✅ |
| **Limana Kabul** | Gizli Liman | Birinci kapı: kefil, iş veya yük | ✅ |
| **Geçiş Pazarlığı** | Rıhtım | İkinci kapı: iyi yazı ya da iyi para | ✅ |
| **Meclis Oturumu** | Meclis Salonu | Altı inkâr, tek sessiz üye; masa reddedilir | ✅ |
| **Kapı Önündeki Teklif** | Meclis Salonu | Oturumun **hemen ardından**: "bana kimin ödediğini getirin" | ✅ |
| **Geçiş Divanı'nda Sıra** | Geçiş Divanı | Karşı-imza nasıl alınır, kim bekletir | ✅ |
| **Gümrükte Kayıt** | Elymsyr | Yükün didik didik edilmesi; kaydın çıkması, kağıdın şehre gitmesi | ✅ |
| **Susan Kule** | Gözcü Kuleleri Hattı | Bir kulenin raporu şatoya ulaşmadı. Sessizlik, yalandan yüksek sesle konuşur | ✅ |
| **Avluda Karşılanma** | Ravenhall Avlusu | Şaşırmayan bir yaşlı. Bilgi kazanılmıyor, **teslim alınıyor** | ✅ |

## 9. `encounter` — 1

| Kart | Ne | Durum |
|---|---|---|
| **Şafak Çatışması** | Üç Dönüşmüş, toplam 400 XP. Yumuşatma kolu: Alton önce, diğer ikisi bir tur sonra | ✅ |

## 10. `quest` — 2

| Kart | Zincir | Durum |
|---|---|---|
| **Söylentinin Peşinde** | Giriş kancası: hastalık söylentileri seni Gümüşsu yoluna çıkardı | ✅ |
| **Nereden Geldiler** | Yüzük → kayıtsız giriş → kaydı kim sildirdi | ✅ |

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

## 12. Eşya — 15

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
| **Lonca Mührü** | `trinket` | Signet Ring | Barınma, kredi, isim sorma hakkı | ✅ |
| **Lonca Rozeti** | `trinket` | — (yeni nesne) | Görünür üyelik: kapıda tartışma bitirir | ✅ |
| **Aile Mührü** | `trinket` | Signet Ring | Kapılar isimle açılır, isim yükümlülük getirir | ✅ |
| **Sahte Mühür** | `trinket` | Signet Ring | Çalışan bir yalan. Yakalanırsa suç | ✅ |
| **Kışla Künyesi** | `trinket` | Emblem (Holy Symbol) | Düzenin lojistiği: yemek, yatak, geçiş | ✅ |
| **Emir Mührü** | `trinket` | Signet Ring + Sealing Wax | Sorgusuz geçiş ve düzen içi bilgi | ✅ |
| **Mühürsüz Yüzük** *(ad geçici)* | `trinket` | — (yeni nesne) | **Gizli cepte** taşınan tek nesne (act1.md §3.3 iz 3). Saklanmış olması kanon; **ne olduğu askıda.** Yedek içerik: mühür yüzü eğelenmiş, ayar damgası taze Meridia | ⚠️ |

Mühür bu evrenin merkezî nesnesi: Sancak Kaydı'nda mühür bir deftere yazma
yetkisidir. On dört kartın **beşi** mühür, ve **Mühürsüz Yüzük** diğer dördünün karşı
kutbudur — açıkta taşınan mühür "defterdeyim" der, gizli cepte taşınan yüzük tersini
ima eder.

⚠️ **4. tur (2026-09-09):** yüzük artık Kromanna'nın parmağında değil, **gizli bir
cepte**; bulunması **Investigation DC 15** ister ve mühür taşıyan PC'nin zarsız okuma
imtiyazı kalktı. İçeriği karar bekliyor (act1.md §3.3, §9 açık 5) — kart yazılabilir
ama `description` alanı o karar verilmeden kilitlenmemeli.

**SRD'de kalanlar** (kart açılmaz, ref verilir): Cartographer's Tools ·
Calligrapher's Supplies · Gaming Set · Alchemist's Supplies · Forgery Kit ·
Carpenter's Tools · Navigator's Tools · Smith's Tools · Rope · Spear.

## 13. `species` — 0 (bloke)

Yeni ırk kartı **yazılmaz**; ırksal özelliklerin kaynağı kararı açık. Blok yazmayı
engelliyor, **ref vermeyi değil**: SRD'de adı birebir olan bir ırka `species_ref`
verilir (Halfling · Tiefling).

---

## Sayım

| Kategori | ✅ | 🟡 | ⬜ | Toplam |
|---|---|---|---|---|
| `campaign` | 1 | — | — | 1 |
| `lore` | 21 | 1 | — | 22 |
| `location` | 17 | 1 | — | 18 |
| `npc` | 24 | 10 | — | 34 |
| `monster` | 4 | — | — | 4 |
| `creature-action` | 4 | — | — | 4 |
| `trait` | 5 | — | — | 5 |
| `curse` | 1 | — | — | 1 |
| `scene` | 11 | — | — | 11 |
| `encounter` | 1 | — | — | 1 |
| `quest` | 2 | — | — | 2 |
| `background` | 9 | — | — | 9 |
| `adventuring-gear` | 7 | 1 | — | 8 |
| `trinket` | 7 | — | — | 7 |
| `species` | — | — | 0 | 0 (bloke) |
| **Toplam** | **114** | **13** | **—** | **127** |

**114/127 ✅, 13 🟡, 0 ⬜** (2026-09-10, kayıt turu). Liste 97'den 127'ye çıktı:
[`bolgeler.md`](bolgeler.md) 24 kart (7 `lore` · 7 `location` · 10 `npc` · 3 `scene`),
[`mekanikler.md`](mekanikler.md) 2 kart (`lore/Kural Sapmaları` · `Direnç Şerbeti`),
kayıt turu 1 kart (`lore/Kayıt Nasıl İşler`) ekledi. **⬜ hâlâ yok** — yazılamayacak kart kalmadı.

13 🟡'nin **onu tek bir iş:** üç bölgenin NPC adları. Kalan üçü sayı ya da karar
bekliyor: (Diriltme Sınavı'nın
zarı, Kalıcı Yara bandları), `Direnç Şerbeti` (fiyat ve üretim süresi). Hiçbiri kartın
yazılmasını engellemiyor — hepsi tek bir alanı boş bırakıyor.

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
