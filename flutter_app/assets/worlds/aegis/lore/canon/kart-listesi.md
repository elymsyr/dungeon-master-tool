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
| **Aegis — Meridia** | Bu dünyada oynamak (ton sözleşmesi) · Masa kuralları (rol yuvaları, iki taşıyıcı kuralı, sayaç NPC'de) · Karakter yaratma (serbest, tek cümlelik sözleşme) · DM'e (bilgi eğimi, sır yerleşimi) · Sözlük | 🟡 Sözlük |

Giriş kartı oyuncunun ilk okuduğu şeydir: baş kötünün kim olduğu buraya yazılmaz,
sözlük de dünyayı anlatmaz — ilk oturumda duyulacak kelimeleri açar.

## 2. `lore` — 12

| Kart | Ne | Durum |
|---|---|---|
| **İrade Çağı** | Tanrıların kesilmesi, özgürlüğün bedeli | ✅ |
| **Tanrılar ve Fısıltı** | Bant genişliği kalmamış sevgi; ilahi büyünün bugünkü durumu | ✅ |
| **Blight — Bilinen Hali** | Halkın bildiği yüz. Yön değil **taşıyıcı** anlatılır | ✅ |
| **İkinci Kıta — Bilinen Hali** | Hastalığın geldiği, üçlünün kaçtığı yer | 🟡 adı yok |
| **Konsey ve Lonca Meclisi** | Konsey çerçeve, Meclis içerik; altı koltuğu loncalar doldurur | ✅ |
| **Sancak Kaydı** | Mühür = hukuki kimlik; kayıtsızın kaybolması kayda geçmez | 🟡 kayıt sınıfları yok |
| **Büyücü Loncası** | İzinli büyü, akademi, ışınlanma kaydı. Hanesiz koltuk | ✅ |
| **Sınır ve Ticaret Loncası** | Geçiş, gümrük, tonaj, tahıl; taşrada Sancak Kaydı'nın kalemi. Hane: Sancarlar | ✅ |
| **Demircilik ve İşçi Loncası** | Metal, sikke, **ayar damgası**, yevmiye. Hane: Ferrunlar | ✅ |
| **Simya ve Şifacılar Loncası** | Hekimlik ruhsatı, iksir, ölüm sebebi beyanı. Hane: Kalenderler | ✅ |
| **Askeri Hukuk Loncası** | Suç sicili, kolluk yetkisi, karantina hukuku. Hane: Custarlar | ✅ |
| **Mimarlık ve Planlama Loncası** | Yapı ruhsatı, su yolları, mahalle sınırları, sur. Hane: Mizanlar | ✅ |

Haneler ayrı kart değil — ait oldukları loncanın kartı içinde yazılır. Bir hane
masada karşılaşılan bir şeye dönüştüğünde (bir konak, bir isim) kendi kartını alır.

## 3. `location` — 11

| Kart | Üst (`parent_location_ref`) | Ne | Durum |
|---|---|---|---|
| **Aegis** | — | Dünya. Kökü tutan kart | ✅ |
| **Meridia** | Aegis | Kıta. Sancak Kaydı'nın geçerli olduğu yer | ✅ |
| **İkinci Kıta** | Aegis | Blight oradan geldi | 🟡 adı yok |
| **Gümüşsu** | Meridia | Huzursuz ama işleyen köy; kimse ölmemiş | ✅ |
| **Kulübe** | Gümüşsu | Karantina değil, köyün kendi kararı. Yiyecek götürülür, kimse girmez | ✅ |
| **Bulut'un Hanı** | Gümüşsu | Hanlaşmış ev; köyde "haber" burada üretilir. 4 sp/gece | ✅ |
| **Gizli Liman** | Meridia | Kayıtsız çıkış. Bir yer değil bir **durum** | ✅ |
| **Rıhtım** | Gizli Liman | Limanın çalışan yüzü; üç iskele, tebeşir işareti, bayraksız tekneler | ✅ |
| **Merkezi Şehir** | Meridia | Beyaz mermer; hiçbir şey üretmez, **meşruiyet** üretir | 🟡 adı yok |
| **Meclis Salonu** | Merkezi Şehir | Kararın alındığı değil **kayda geçtiği** oda | ✅ |
| **Geçiş Divanı** | Merkezi Şehir | Karşı-imza masası; geçiş kağıdı buradan çıkar | ✅ |

## 4. `npc` — 24

**Gümüşsu**

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **Duran** — köy başkanı | Köyün dağılmaması | Üçlünün nereden geldiğini biliyor | "Limandan geldiler" | ✅ |
| **Umay** — hastalara bakan | Üç kişinin yaşaması | Kendi de temas etti | Belirtilerin seyri (zarsız) | ✅ |
| **Karaca** — yolu bilen | Para | Gizli Liman'ı biliyor, oradan mal taşıdı | Gizli Liman'a rehberlik | ✅ |
| **Bulut** — hancı | İşin yürümesi | — (yarasız NPC) | Söylenti, yabancı kaydı, kumaş | ✅ |

**Kulübe** — üçü de 1. gün hali; her birinin `monster` ikizi var, `species_ref` SRD'ye

| Kart | Ne | Durum |
|---|---|---|
| **Toygar** (halfling) | Yorgunluk hattı. Zengin, adı sahte | ✅ |
| **Selvi** (halfling) | Değişkenlik hattı. Zengin, adı sahte | ✅ |
| **Demir** (tiefling) | Beden hattı. Mührü eğelenmiş yüzük onun parmağında | ✅ |

**Gizli Liman**

| Kart | Ne istiyor | Ne gizliyor | Hangi kapıyı açar | Durum |
|---|---|---|---|---|
| **Sicim** — defter tutan | Limanın işlemesi | Üçlünün geçişini kimin sildirdiğini | Ücret · kefalet · üçlünün izi | ✅ |
| **Fare** — rıhtım çırağı | Bir gemiye alınmak | — (yarasız NPC) | Her şey: kim ne zaman yanaştı | ✅ |
| **Kaptan Vela** | Göremediği yükü taşımamak | Üçlüyü geri çevirdi | Temiz yolculuk — yazı ya da yüksek fiyat | ✅ |
| **Kaptan Halim** | Para, hızlı sefer | Gemisi güvenilmez | Ucuz ve kötü yolculuk | ✅ |
| **Konsey Aracısı** | Limanın konseye yararlı kalması | Hangi koltukların pay aldığı | "İyi yazı"nın nasıl alındığı | 🟡 adı yok |
| **Kuyumcu** — yüzüğü eğeleyen | — | — | *Kaydı kim sildirdi*'nin ikinci taşıyıcısı | ⬜ karar |

**Meclis — altı koltuk, altı inkâr.** Kartlar koltuk adıyla yazılır.

| Kart | İnkârı | Ne gizliyor | Durum |
|---|---|---|---|
| **Rektör** (Büyücü) | "Sınadık, hiçbir tespit büyüsü bir şey göstermedi" | Sonuç **okunamadı** — "yok" değil "bilmiyoruz" | 🟡 adı yok |
| **Sınır ve Ticaret koltuğu** | *(tek inkâr etmeyen)* | Kendi defterinden sayfa silindiğini | 🟡 adı yok |
| **Kalfa Başı** (Demirci-İşçi) | "Tezgahlar dönüyor, üretim düşmedi" | Aynı adamlar iki vardiya çalışıyor | 🟡 adı yok |
| **Baş Otacı** (Simya) | "İlerlemiş bir humma. Adı var, tedavisi var" | Beyanları kendisi değiştirtti | 🟡 adı yok |
| **Sicil Ağası** (Askeri Hukuk) | "Hastalık hukuki bir kategori değil" | Yetkisi var, kullanmıyor | 🟡 adı yok |
| **Levha Sahibi** (Mimarlık) | "Bu şehir hastalanmayacak biçimde planlandı" | Sur onarımı kağıt üstünde kaldı | 🟡 adı yok |

**Merkezi Şehir sokağı**

| Kart | Nerede | Hangi kapıyı açar | Durum |
|---|---|---|---|
| **Geçiş Memuru** | Geçiş Divanı | ***Kim ödedi*** — silinen sayfanın ikinci imzası onun | 🟡 adı yok |
| **Ayar Ustası** | Demirci çarşısı | Yüzüğün tezgahı: fihristten hangi kuyumcunun vurduğu | 🟡 adı yok |
| **Simyacı Çırağı** | Şifacılar kışlası | Hastalığın şehirde **bilindiğinin** belgesi | 🟡 adı yok |
| **Borçlu Esnaf** | Çarşı | Sokak hattı, lonca kolluğu, şehirde "iyi para" | 🟡 adı yok |
| **Kolluk Çavuşu** | Kapılar / gece devriyesi | Kapılar, gece hareketi, kimin şehre girdiği | 🟡 adı yok |

> **İki taşıyıcı kuralı:** *kim ödedi* üç yerde (Sicim · Geçiş Memuru · Ayar
> Ustası). *Kaydı kim sildirdi* şu an **yalnız Sicim'de** — ikinci taşıyıcı
> Kuyumcu kartıdır ve yazılmadı. Masaya çıkmadan kapat.

## 5. `monster` — 4

| Kart | Ne | Durum |
|---|---|---|
| **Dönüşmüş** | Jenerik gövde: Blight'lı köylü. CR 1/2, AC 12, HP 22, Pençe +5 (1d8+3) | ✅ |
| **Dönüşmüş Toygar** | Halfling, Small, HP 18, CR 1/2 | ✅ |
| **Dönüşmüş Selvi** | Halfling, Small, HP 18, CR 1/2 | ✅ |
| **Dönüşmüş Demir** | Tiefling, HP 30, ateşe direnç, CR 1 | ✅ |

Üçü de jenerik gövdeden türer ve `npc` ikizine linklidir. SRD'de birebir adı olan
hiçbir yaratık tekrar yazılmaz, ref verilir.

## 6. `creature-action` — 4 · `trait` — 5

Statblokların gövdesi; `monster` kartlarına ref'lenir.

| Kart | Tip | Ait olduğu | Durum |
|---|---|---|---|
| **Pençe** | `creature-action` | Dönüşmüş — +5, 1d8+3 delici | ✅ |
| **Pençe (Toygar)** · **Pençe (Selvi)** | `creature-action` | +4, 1d6+2 delici | ✅ |
| **Pençe (Demir)** | `creature-action` | +6, 1d10+4 delici | ✅ |
| **Acıyı Tanımaz** | `trait` | 0 HP'de ölüm zarı atmaz, ölür | ✅ |
| **Bulaştıran Yara** | `trait` | İsabette CON DC 12 → Blight Evre 1 | ✅ |
| **Durmayan Adım** | `trait` | Toygar: yarı HP altında hız 40 ft, fırsat saldırısı yemez | ✅ |
| **Kesik Kesik** | `trait` | Selvi: sıra başında açıkta 1d6 — 1-2 eylem kaybı, 5-6 ek saldırı | ✅ |
| **Erken Güçlenme** | `trait` | Demir: ilk turunda ek Pençe | ✅ |

## 7. `curse` — 1

| Kart | Ne | Durum |
|---|---|---|
| **Blight — Enfeksiyon** | Bulaşma CON DC 12 · Evre 1 sessiz taşıma (~1 ay) · Evre 2 her uzun dinlenmede CON DC 13, üç başarı/üç başarısızlık · Evre 3 dönüşüm, geri dönüş yok · tedavi: *Lesser Restoration* bir başarısızlığı siler, *Greater Restoration* Evre 1–2'de kaldırır | ✅ |

Dünyanın **tek** kural sapması; kartta sapma işareti zorunlu. Halkın bildiği yüzü
ayrı kart: `lore/Blight — Bilinen Hali`.

## 8. `scene` — 8

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

## 9. `encounter` — 1

| Kart | Ne | Durum |
|---|---|---|
| **Şafak Çatışması** | Üç Dönüşmüş, toplam 400 XP. Yumuşatma kolu: Toygar önce, diğer ikisi bir tur sonra | ✅ |

## 10. `quest` — 3

| Kart | Zincir | Durum |
|---|---|---|
| **Söylentinin Peşinde** | Giriş kancası: hastalık söylentileri seni Gümüşsu yoluna çıkardı | ✅ |
| **Nereden Geldiler** | Yüzük → kayıtsız giriş → kaydı kim sildirdi | ✅ |
| **Silinen Sayfa** | Kim ödedi. Ödül para değil **karşı-imzalı geçiş kağıdı** | ✅ |

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

## 12. Eşya — 14

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
| **Lonca Mührü** | `trinket` | Signet Ring | Barınma, kredi, isim sorma hakkı | ✅ |
| **Lonca Rozeti** | `trinket` | — (yeni nesne) | Görünür üyelik: kapıda tartışma bitirir | ✅ |
| **Aile Mührü** | `trinket` | Signet Ring | Kapılar isimle açılır, isim yükümlülük getirir | ✅ |
| **Sahte Mühür** | `trinket` | Signet Ring | Çalışan bir yalan. Yakalanırsa suç | ✅ |
| **Kışla Künyesi** | `trinket` | Emblem (Holy Symbol) | Düzenin lojistiği: yemek, yatak, geçiş | ✅ |
| **Emir Mührü** | `trinket` | Signet Ring + Sealing Wax | Sorgusuz geçiş ve düzen içi bilgi | ✅ |
| **Mühürsüz Yüzük** | `trinket` | — (yeni nesne) | Mühür yüzü eğelenmiş, ayar damgası taze Meridia. Kendi kaydını sildirmiş insanın üzerinde kalan tek delil | ✅ |

Mühür bu evrenin merkezî nesnesi: Sancak Kaydı'nda mühür bir deftere yazma
yetkisidir. On dört kartın **beşi** mühür, ve **Mühürsüz Yüzük** diğer dördünün tam
tersidir — mühür taşıyan PC onu zar atmadan okur.

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
| `campaign` | — | 1 | — | 1 |
| `lore` | 10 | 2 | — | 12 |
| `location` | 9 | 2 | — | 11 |
| `npc` | 12 | 11 | 1 | 24 |
| `monster` | 4 | — | — | 4 |
| `creature-action` | 4 | — | — | 4 |
| `trait` | 5 | — | — | 5 |
| `curse` | 1 | — | — | 1 |
| `scene` | 8 | — | — | 8 |
| `encounter` | 1 | — | — | 1 |
| `quest` | 3 | — | — | 3 |
| `background` | 9 | — | — | 9 |
| `adventuring-gear` | 7 | — | — | 7 |
| `trinket` | 7 | — | — | 7 |
| `species` | — | — | 0 | 0 (bloke) |
| **Toplam** | **80** | **16** | **1** | **97** |

🟡'lerin hepsi **yazılabilir**: eksik olan bir ad, kartın kendisi değil. Kart
başlıkla (koltuk adı, meslek adı) yazılır, ad sonradan girer.

⬜ tek: **Kuyumcu**. Kart değil karar eksik.

---

## Yazılmayacaklar (bilerek)

- **Karantina doktoru** — karantina yok; kulübe köyün kendi kararı.
- **Cerrahi iğne** — kimse kimseye bir şey yerleştirmedi. Perdenin kanıtı
  **Mühürsüz Yüzük**.
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
