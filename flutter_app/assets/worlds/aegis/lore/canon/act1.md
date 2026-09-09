# Act 1 — Birinci Perde: İskelet

> **Durum: Act 1 kanonu.** README §0 kanon hiyerarşisine bağlıdır; 08 §2 akışını
> ve 07'nin ilkelerini (sahne akışını değil) uygular. Buradaki her madde ya bir
> kaynağa dayanır ya §9'da açık karar olarak durur.
>
> **2026-09-09 revizyonu (1. tur):** §2 (background mekanikleri) · §3.1–3.3
> (üçlünün kimliği, cerrahi iğnenin kaldırılması, yerine geçen üç iz) · §4 (Blight
> kural kartı).
>
> **2026-09-09 revizyonu (2. tur):** Adlandırma Doktrini askıya alındı (§3) ·
> background eşyaları **kart oluyor** (§2) · Goodbarrel'ın Ocak Başı (§3.4) ve Rıhtım (§7.6)
> yer olarak yazıldı · Dönüşmüş üçlünün statblock'ları (§5.1) · Konsey aracısı
> tanımlandı (§7.4) · "Liman kaçışı" ve "Yol hakkı" kart olmaktan çıktı (§7.2, §7.3).
>
>
> **2026-09-09 revizyonu (4. tur — belirsizlik turu):** Hastalığın **ne olduğu
> bilinmiyor** ilan edildi, "bu bir hastalık mı" sorusu bile açık (§4) · Blight
> yalnız biyolojik değil **büyülü** ve **bir kaynağa bağlı**; Arcana ile hissedilir
> (§3.3 iz 5, §4.6) · üçlünün üzerindeki eşya listesi yeniden yazıldı: altın kesesi
> + boş parşömen, yüzük **gizli cepte** ve içeriği askıda (§3.3) · üçlünün geçmişi,
> yolu ve nasıl hastalandıkları **askıya alındı** (§3.1, §3.2) · gerçek adların
> nerede karşılık bulduğu yazıldı (§3.1 → Lonca Meclisi) · doğrudan lonca yolu
> yazıldı (§6.1) · Paladin Şatosu · Ravenhall · Elymsyr liman kenti **sonraya
> bırakıldı** (§6).
>
> Hepsi **kartın son hali gibi**, DM'e yönelik yazıldı. Karar sahibine notlar
> §10'da ayrı duruyor — kartların içine girmez.

Kapsam sınırı (06 #12): **Gümüşsu'da başlar, ikinci kıta ufukta görülünce biter.**

---

## 1. Giriş sözleşmesi

Karakter yaratma **serbest**. Tek zorunluluk, masaya oturmadan önce kabul edilen
tek cümle:

> **Hastalık söylentileri seni bir şekilde Gümüşsu yoluna çıkardı.**

Oyuncular birbirini tanımak zorunda değil, aynı anda varmak zorunda değil.
**İlk karşılaşma Gümüşsu'da olur.** "Neden yoldasın" sorusunun cevabı oyuncunun;
DM yalnız sebebi background'a bağlar (§2).

Dört rol yuvası (README §2) **kalkmadı, zorunlu olmaktan çıktı.** Serbest yaratımda
yuvaların boş kalması normaldir; o yüzden kilitlenme kuralı burada daha da sert:

> **Her kritik ipucunun en az iki taşıyıcısı var** — biri PC yeteneği/geçmişi ise,
> diğeri mutlaka bir NPC veya çevrede duran fiziksel bir iz olmalı.

---

## 2. Evrene özgü background'lar

Amaç: serbest yaratımı dünyaya bağlamak ve Act 1'in üç kurumunu (lonca · liman ·
paladin düzeni) daha karakter kağıdındayken masaya sokmak.

**Kural (KARAR): artı mekanik, eksi kurgusal.** 5e'de background ceza vermez; buradaki
"eksi" bir modifier değil, dünyanın o karaktere verdiği tepkidir — tanınmak,
izlenmek, borçlu olmak. Sapma işaretlenmiş sayılır (Yönerge §3.3).

**Mekanik yük (KARAR, 2026-09-09 revizyonu): 5e standart paketi + evrene özel eşya.
Ayrı bir "evrene özel feature" yok.** Sebep şema: `background` sözleşmesinde
(`world-blueprint.md` §3.22) serbest mekanik yazacak bir alan yok — zorunlular
`granted_skill_refs` · `ability_score_options` · `asi_distribution_options` ·
`origin_feat_ref`, hepsi SRD ref'i. Uydurma bir alan açmak yerine feature'ın işini
**eşya + kurgu** yapıyor: eşya dekorasyon değil **kapı**, ve kapının ne açtığı
kartın `description`'ında yazıyor.

**İkinci karar (2. tur, 2026-09-09 — önceki kararın tersi): her background eşyası
kendi kartını alır.** Gerekçe: eşya bu tasarımda dekorasyon değil **kapı**, ve
kapının ne açtığı SRD'nin `Signet Ring` satırında yazmıyor. Aynı sebeple bir
arşivcinin çantasındaki **her kitap ayrı karttır** — kitabın adı bu dünyanın bir
kurumunu adlandırır, ve masada "hangi kitabı açıyorum" sorulabilir olmalı.

*Uygulama:* eşya evrenin adıyla yazılır (`Lonca Mührü`, `Kışla Künyesi`), kategori
`adventuring-gear` / `trinket`, ve `default_inventory_refs` SRD'ye değil **bu
kartlara** ref verir. SRD nesnesi mekanik atası olarak `description`'da anılır
("SRD `Signet Ring` muadili"), ayrıca ref'lenmez. Alet (`tool`), silah ve halat
SRD'de kalır — onların evrene özel bir anlamı yok.

**İçerik sonraya.** Kitapların ve defterlerin *içi* şimdi yazılmıyor; kart adı,
kategorisi ve neyi açtığı yazılıyor. İçerik, o kurum (Lonca · Sancak Kaydı ·
Paladin düzeni) yazılırken doldurulur.

Mühür bu setin merkezinde: Sancak Kaydı'nda mühür hukuki kimliktir, yüzük taşımak
"kayıtlıyım" demektir. §3.3'teki **gizli cepteki yüzük** bu kartların karşı kutbudur
— içeriği askıda olsa da (4. tur), saklanmış bir yüzükle açıkta taşınan bir mühür
arasındaki fark masada kendiliğinden okunur.

| Background | Yetenek seçimi | Skill | Tool | Origin feat | Evrene özel eşya (kapı) | Eksi (kurgusal bedel) |
|---|---|---|---|---|---|---|
| **Arşivci** | INT · WIS · CHA | Investigation · History | Cartographer's Tools | Skilled | **Tasnif Çantası** + **Kayıt Elifbası** + **Sancak Fihristi** | Kayıt tutan kurum onu da kaydetmiştir; nerede olduğu bilinir |
| **Lonca Üyesi** | INT · WIS · CHA | Persuasion · Insight | Calligrapher's Supplies | Skilled | **Lonca Mührü** + **Lonca Rozeti** | Loncanın işi öne geçer; çağrıldığında gitmemek statü kaybı |
| **Mertebeli Lonca Çocuğu** | CHA · INT · CON | Persuasion · History | Gaming Set | Lucky | **Aile Mührü** + **Mertebe Kaftanı** | Yüzü tanınır; ailenin düşmanları da tanır. Kimliği saklamak zor |
| **Sihir Loncası Öğrencisi** | INT · WIS · CON | Arcana · Investigation | Alchemist's Supplies | Magic Initiate (Wizard) | **Öğrenci Defteri** | Öğrenci = denetim altında. İzinsiz kullanım kayda geçer |
| **Lonca Ajanı** | DEX · INT · CHA | Deception · Insight | Forgery Kit | Alert | **Sahte Mühür** (+ SRD `Forgery Kit`) | İki efendi. Loncanın çıkarı gruptan önce gelir; bir gün seçmesi gerekir |
| **Rıhtım İşçisi** | STR · DEX · WIS | Athletics · Perception | Carpenter's Tools | Tavern Brawler | **Yük Kancası** (+ SRD `Rope`) | Kayıtsız iş kayıtsız insan yapar; resmi hiçbir kapıda ağırlığı yok |
| **Gemi Kaptanı** | WIS · CHA · DEX | Persuasion · Survival | Navigator's Tools | Tough | **Seyir Defteri** | Gemi bir yükümlülüktür: borç, mürettebat, liman kaydı |
| **Paladin Askeri** | STR · CON · WIS | Athletics · Intimidation | Smith's Tools | Savage Attacker | **Kışla Künyesi** (+ SRD `Spear`) | Üniforma tanınır; halk kurumdan çekinir, kurum ondan itaat bekler |
| **Paladin Rütbelisi** | CHA · STR · WIS | Religion · Persuasion | Calligrapher's Supplies | Healer | **Emir Mührü** | Rütbe rapor demek. Sessiz kalmak da bir suç sayılır |

**Eşya kartları (13) — hangi kapıyı açar:**

| Kart | Kategori | SRD muadili | Kapı |
|---|---|---|---|
| **Tasnif Çantası** | `adventuring-gear` | Case, Map or Scroll | *Belgesel kapı* (07): Occulus dışı arşivlerde okuma hakkı |
| **Kayıt Elifbası** | `adventuring-gear` | Book | Kayıt kısaltmalarını, damgaları, tasnif işaretlerini okumak |
| **Sancak Fihristi** | `adventuring-gear` | Book | Hangi kaydın hangi makamda tutulduğu — nereye sorulacağı |
| **Lonca Mührü** | `trinket` | Signet Ring | Barınma, kredi, isim sorma hakkı |
| **Lonca Rozeti** | `trinket` | — (yeni) | Yüzük cepte kalırken **görünür** üyelik: kapıda tartışma bitirir |
| **Aile Mührü** | `trinket` | Signet Ring | Kapılar isimle açılır — ve isim yükümlülük getirir |
| **Mertebe Kaftanı** | `adventuring-gear` | Clothes, Fine | Bir odaya girildiğinde kimin konuşacağına karar veren giysi |
| **Öğrenci Defteri** | `adventuring-gear` | Spellbook | Sihir loncasının kütüphanesine giriş; her açılış kayda geçer |
| **Sahte Mühür** | `trinket` | Signet Ring | Çalışan bir yalan: gizli kanal, sahte kimlik. **Yakalanırsa suç** |
| **Yük Kancası** | `adventuring-gear` | Grappling Hook | Kaçak yollar ve işçi ağı — rıhtımda kancayı taşıyan işçidir |
| **Seyir Defteri** | `adventuring-gear` | Book | Rota bilgisi ve yanaşma hakkı; bir limanda kimliğin yerine geçer |
| **Kışla Künyesi** | `trinket` | Emblem (Holy Symbol) | Düzenin lojistiği ve kışla dili: yemek, yatak, geçiş |
| **Emir Mührü** | `trinket` | Signet Ring + Sealing Wax | Sorgusuz geçiş ve düzen içi bilgi — mühürlenen şey emirdir |

Dördü mühür (`Lonca` · `Aile` · `Sahte` · `Emir`); bu dördünü taşıyan PC §3.3'ün
yüzüğünü zar atmadan okur. Kartların **içeriği** (kitaplarda ne yazdığı, rozetin
nakşı, künyenin ibaresi) bu turda yazılmadı — ilgili kurum yazılırken doldurulur.

Dokuzunda da `asi_distribution_options` = `+2/+1` ve `+1/+1/+1`;
`gold_alternative_gp` = 50 (SRD standardı). Başlangıç altını statüye göre:
Mertebeli 30 · Rütbeli 20 · Lonca Üyesi / Öğrenci / Kaptan 16 · Arşivci / Ajan 12 ·
Asker 10 · Rıhtım İşçisi 8.

Liste **açık uçlu** — sonradan eklenir. Yeni background eklerken tek test:
*Act 1'in hangi kapısını açıyor ve dünyaya hangi bedeli ödetiyor?*

---

## 3. Gümüşsu — yer olarak

07 "Yöntem Notu": akış değil, **yer** kurulur. Akış yerden çıkar.

**Manzara:** huzursuz ama işleyen bir köy. Kimse ölmemiş. Söylentiler artık
fısıltı değil, günlük konuşma. Bakım estetiği görünür (kaynayan kazan, tebeşirle
işaretli kapı, temiz bez) — ton kuralı gereği (02 §5).

**Kulübe:** hasta olduğu düşünülen **üç kişi**, köyün biraz dışındaki bir kulübeye
alınmış. Bu bir karantina değil, köyün kendi kararı — korku ve nezaketin karışımı.
Yiyecek götürülüyor, kimse içeri girmiyor.

**Ad kuralı (KARAR, 2026-09-09 2. tur — önceki kural geri alındı):** *halk dili /
Latin* ayrımı diye bir kanon **yok**. Adlandırma Doktrini'nin dil ayrımı bu
belgeden çıkarıldı; adlar şu anki gibi **karışık** kalır ve hiçbir ad bir dil
kuralına uymak zorunda değil. Doktrin bölümüne sonra dönülecek — o zamana kadar
adlar tek tek seçilir, kuraldan türetilmez.

Bu, aşağıdaki dört adı ve Gümüşsu'nun adını değiştirmez; sadece onları bir sistemin
*örneği* olmaktan çıkarır.

**Kadro:**

| NPC | Ne istiyor | Ne gizliyor | Hangi kapıyı açar |
|---|---|---|---|
| **Duran** — köy başkanı *(insan)* | Köyün dağılmaması, dışarıdan müdahale gelmemesi | Üçlünün nereden geldiğini biliyor, söylemek istemiyor | "Limandan geldiler" |
| **Umay** — hastalara bakan *(yarı-elf)* | Üç kişinin yaşaması | Kendi de temas etti, saklıyor | Belirtilerin seyri (§4) |
| **Corvin** — yolu bilen *(insan)* | Para | Gizli Liman'ı biliyor, çünkü oradan mal taşıdı | **Gizli Liman** — ücret karşılığı rehberlik |
| **Milo Goodbarrel** — hancı *(halfling)* | İşin yürümesi | — (yarası olmayan NPC, 02 §4 kotası) | Söylenti, yabancı kaydı |

**Umay'ın yarı-elf olması bedava bir kanıt hattı:** kırk yıldır aynı köyde hasta
bakıyor ve köylülerin yarısını doğarken gördü. "Kimse ölmedi"yi ilk yadırgayan
odur, çünkü karşılaştıracağı kırk yılı var.

**Kayıt notu.** Köyde iki adı olan tek kişi Milo — ve onunki bile hane değil:
halfling soyadı Sancak Kaydı'nda hane sayılmaz, defter onu *"tek isim + boş hane"*
yazar. Gümüşsu'da **kimsenin hanesi yok**; köyün kayıttaki yeri tek satırda budur.

### 3.1 Üçlü — kim oldukları (KARAR, 2026-09-09 revizyonu)

**Alton · Merla · Kromanna.** İkisi halfling, biri tiefling. SRD'de üçünün de ırkı
var → `species_ref` ile ref verilir, `species` kartı yazılmaz (genel-kartlar §5
bloğu yeni ırk *yazmayı* engelliyor, ref vermeyi değil).

**Üçü bir aile değil, bir hane (KARAR, 2026-09-09).** İki halfling **karı koca**;
tiefling kadın onların **hizmetlisi ve koruyucusu** — köle değil, tutulmuş ve
yıllardır aynı evde. Üçü de **Vorstrand'dan** geldi.

Bu tek karar üç şeyi bedavaya açıklıyor: kulübedeki üç yatağın neden eşit olmadığını,
birinin neden kapıya en yakın yattığını, ve Şafak Çatışması'nda (§5) neden **iki
zayıf bir güçlü** gövdeyle karşılaşıldığını.

**Üçü de zengin.** Yıpranmış ama pahalı kumaş, bu kıtada dokunmamış bir dokuma, bu
kıtada olmayan bir boya. Yanlarında bavul yok. Kumaşın üçünde de aynı kalitede
olması ayrı bir iz: hizmetli de efendisi gibi giydirilmiş, yani bu hane onu
**yanında götürecek kadar** değerli görmüş.

**Hikaye — ASKIDA (KARAR, 2026-09-09 4. tur).** Üçlünün hastalığı **nasıl kaptığı**,
tam geçmişleri ve izledikleri yol **karar verilmedi.** Aşağıdaki anlatı bu belgenin
şu anki *en güçlü adayıdır*, kanon değil:

> İkinci kıtada hastalık yayılırken limanlar kapanmadan çıkmak için çok para ödediler.
> **Kaçamadılar** — bindiklerinde zaten taşıyorlardı. Meridia'ya vardıklarında bir kez
> daha ödediler: bu sefer karaya çıkışlarının **kayıttan silinmesi** ve kimsenin soru
> sormadığı bir yere yerleştirilmeleri için.

**Karar verilene kadar masada doğru olan üç şey:** üçü de **ikinci kıtadan** geldi ·
**kayıtsız** geldi · ve **limandan sonra yol bitti** — Gümüşsu seçilmiş bir yer değil,
**gidebildikleri son yer.** Bunun ötesi (kim ödedi, kim aldı, nasıl hastalandılar)
Act 1'de *kanıtlanmaz*. Oyuncuların ulaşabildiği en uç katman aşağıda yazılı ve
orada bitiyor.

**İki ad sahte, biri değil (KARAR).**

| Köyün bildiği ad | Gerçek ad | Neden |
|---|---|---|
| **Alton Leagallow** | *Cortia Greenbottle* | Halfling soyadı Sancak Kaydı'nda **hane sayılmaz** — yani kontrol edilecek bir kaydı yoktur. Sahte kimlik için kusursuz seçim |
| **Merla Tealeaf** | *Portia Greenbottle* | Aynı sebep. **Ayrı soyadı seçtiler:** kayıtta karı koca değil, yolda tanışmış iki yolcu görünüyorlar |
| **Kromanna** | *Kromanna* | Tiefling adı saklanamaz: hangi adı verirse versin tiefling olduğunu söyler. Değiştirmenin faydası yoktu, değiştirmedi |

**Gerçek adlar nerede karşılık buluyor (KARAR, 4. tur).** Köyde hiçbir yerde. Bir
yerde: **Lonca Meclisi.** Oyuncular üçlünün nereden geldiğini araştırmayı seçerse
ulaşabilecekleri bilgi katmanı **iki basamaktır ve orada biter:**

1. **Geldikleri yer** — ikinci kıta. (Kumaş · beden · boş parşömen; §3.3.)
2. **Gerçek adları** — *Cortia* ve *Portia Greenbottle*.

İkinci basamak zar değil **yer** ister: gerçek adı Meclis'te **bir üye tanır**, çünkü
ikinci kıta kayıtları o odaya girer, köye girmez. Tanıyan üye üç şey söyler ve
fazlasını söylemez: bu iki isim **serbest ticaretçi**, ikinci kıtada kayıtlı, ve
*"oradan buraya, hele gizli bir yoldan gelmişlerse ortada bir sorun var — ve sorun
onlar değil, onları geçiren."* Ad bir cevap değil, **soruyu kuruma taşıyan bilettir**
(bkz. [`lonca-sehir.md` §6.3](lonca-sehir.md)).

**Bu hat hiç yaşanmayabilir.** Oyuncular üçlünün geçmişini hiç kurcalamadan doğrudan
loncaya gidebilir — §6.1 o yolu ayrıca yazıyor. İki yol da aynı kapıya çıkar; biri
diğerinin ön koşulu değil.

> **Perdenin en erken çatlağı bu.** İki halfling aynı yatakta yatıyor ve ellerinde
> **eş bir çift alyans** var *(gizli cepteki yüzükle karıştırma — o saklı ve ayrı bir
> nesne, §3.3 iz 3)*, ama verdikleri iki ad iki ayrı soyadı taşıyor. Oyuncu ikisinin evli
> olduğunu gördüğü an kayıt ile oda birbirini yalanlar — ve bunun için hiçbir zar
> gerekmez. Sorulduğunda ikisi de aynı cevabı verir, ayrı ayrı, fazla hazır:
> *"Yolda tanıştık."*

Şatoya bağ **kurulmuyor** — Paladin Şatosu Act 1'de kendi kapısından girilecek bir
yer, buranın uzantısı değil.

### 3.2 Ensedeki cerrahi iğne — KALDIRILDI

07'nin "ensedeki cerrahi iğne" belkemiği **kaldırıldı** (KARAR, 2026-09-09).
İz yok, iğne yok, kimse onlara bir şey yerleştirmedi. Üçlü hastalığı **ikinci
kıtadan getirdi.**

07'nin asıl cümlesi yerinde duruyor ve suç değişti:

> **Salgın araştırılmaz, suç araştırılır.**

Suç artık *bulaştırma* değil **gizleme**: birileri üç hasta insanı kordonun içinden
geçirdi, kayıtlarını sildi ve kayıtsız bir köye yerleştirdi. Onları buraya sokan kişi
Gümüşsu'yu satmış oldu.

**Üçlünün bu işlemdeki rolü açık değil (4. tur).** Parayı onlar mı verdi, biri onlar
için mi ödedi, yoksa sadece taşındılar mı — **karar verilmedi** (§3.1, §9 açık).
Önceki turun "bu insanlar kurban değil müşteri" cümlesi bu belgeden **çıkarıldı**;
masada iki okuma da açık duruyor ve kulübede söylenen hiçbir cümle ikisi arasında
seçim yapmıyor.

Değişmeyen soru şu: *neden bu üç kişi değil — **kim aldı bu parayı?***

### 3.3 Catch — iğnenin yerine geçen izler

Hiçbiri zorunlu değil, hepsi aynı yeri gösteriyor.

**Üçlünün üzerinde ne var (KARAR, 4. tur):** giysileri, **bir altın kesesi**, **birkaç
boş parşömen**, ve **gizli bir cepte bir yüzük.** Bavul yok, mektup yok, mühürlü kağıt
yok, ensede iğne yok. Liste bu kadar — DM buraya kendiliğinden bir şey eklemez.

| # | İz | Nasıl bulunur | Ne söyler |
|---|---|---|---|
| 1 | **Kumaş** | Zar yok. Bakan görür; @[Milo](entity:npc/Milo) (hancı, kumaş görmüş adam) ya da @[Corvin](entity:npc/Corvin) (mal taşır) sorulmadan söyler | Yabancılar, ve zengindiler |
| 2 | **Altın kesesi + boş parşömenler** | Zar yok, üstlerinde duruyor | Kese **dolu**: parası bitmiş insanlar değil, **yolu** bitmiş insanlar. Parşömenler **boş**: yazılı bir şey taşıyorlardı ya da taşıyacaklardı, ve şimdi ellerinde tek bir kayıt yok. Kayıtsızlık bir kaza değil, bir **hâl** |
| 3 | **Gizli cepteki yüzük** | **Investigation DC 15** — üstlerini arama beyanı ister; kimse göstermez, kimse söylemez | Saklanan tek nesne, ve saklanmış olması tek başına bir cümle: bu üçünün gizleyecek bir **kaydı** var. *(Yüzüğün ne olduğu askıda — aşağı bak)* |
| 4 | **Beden** | **Medicine DC 12** (Umay'a sorulursa zarsız: kendisi zaten fark etti ama adını koyamıyor) | Hastalık köyün sandığından **eski**. Bu üçü hasta *geldi*. Gümüşsu bu hastalığı üretmedi, **teslim aldı** |
| 5 | **Hava** | **Arcana DC 13** — yalnız büyü yapan/bilen bir PC atar. Köyde ikinci taşıyıcısı **yok**; Umay bunu göremez | Bu yalnızca hastalık değil. Üçünün üstünde **duran** bir şey var: sönmeyen, dağılmayan, **bir yere bağlı** bir iz. Yön yok, mesafe yok, ad yok — sadece *"bunun bir sahibi var"* (§4.6) |

**İki taşıyıcı kuralının bu tablodaki karşılığı (4. tur).** Perdeyi taşıyan kritik
cümle *"bu üçü hasta **geldi**"* ve onun iki taşıyıcısı var: **beden** (iz 4) ve
**Umay** (zarsız). Buna kumaş (iz 1) ve kese (iz 2) de zarsız eşlik ediyor.

Buna karşılık **yüzük (iz 3) ve Arcana (iz 5) kritik değil** — tek kapıları var,
kaçırılabilirler, ve kaçırıldıklarında hiçbir hat kapanmaz. Bu bilinçli:
**kritik olan kolay, ödül olan zor.**

**Yüzüğün ne olduğu askıda (KARAR, 4. tur — §9 açık).** Nesnenin *var olduğu* ve
*saklandığı* kanon; içeriği değil. Karar verilene kadar bu belgedeki **yedek içerik**
şudur ve kanon sayılmaz:

> Mühür yüzü **eğelenerek düzleştirilmiş**, kırılmamış. İç kenardaki ayar damgası
> **taze Meridia damgası** — yani yüzük bu kıtaya geldikten *sonra* işlenmiş.

Bu okuma seçilirse §7.4'teki **Mine** (klan adını söylemeyen cüce kuyumcu) ve
aşağıdaki zincir olduğu gibi çalışır. Başka bir yüzük seçilirse ikisi de onunla
birlikte değişir — **Mine'ın kartı bu karara bağlı.**

**Yüzük neden bu dünyada bir şey ifade eder** (hangi içerik seçilirse seçilsin):
Sancak Kaydı'nda mühür **hukuki kimliktir** (§2); mühürlü yüzük "ben defterde varım"
demektir. Böyle bir yüzüğün **gizli cepte** taşınması, sahibiyle kayıt arasında
düzeltilmiş bir şey olduğunu söyler. Nesnenin ayrıntısı bu cümleyi *güçlendirir*,
kurmaz.

**Zincir (yedek içerik doğrulanırsa):** yüzük → *kim işledi* →
@[Gizli Liman](entity:location/Gizli Liman) (§7.5) → *kim ödedi* → Lonca ve Şehir
hattı, yani Act 1'in bu kapsamının dışı. İçerik değişse bile zincirin **girişi**
duruyor: üçlü kayıtsız geldi, kayıtsızlık satın alınmış bir hizmettir, ve satan
liman orada.

Üçlü **Gizli Liman'dan gelmiş** (KARAR, korunuyor): resmi limandan geçselerdi kayıt
olurdu. **Kayıt olmaması bir kaza değil, satın alınmış bir hizmet.** Corvin'in yolu
bilmesi de aynı sebeple doğal: o da oradan mal taşıyor.

### 3.4 Goodbarrel'ın Ocak Başı — yer olarak

Köyün tek toplanma yeri. Han değil, **hanlaşmış bir ev**: alt katta ocaklı bir
salon ve altı masa, üst katta iki oda, arkada üç atlık bir ahır. Yolcu çok
gelmediği için oda genelde boştur; salon ise akşamları köyün yarısını tutar.
Gümüşsu'da "haber" denen şey burada üretilir.

**Fiyat:** yatak + iki öğün **4 sp/gece**, sadece yemek 3 cp, ahır 1 sp.
Pazarlık yok; Milo fiyat düşürmez ama borç yazar.

**Ne verir:**

- **Söylenti.** Salonda oturup dinlemek Perception ya da Insight istemez; Milo
  konuşulanı zaten tekrarlar. Bilgi eğiminin (09 §4) köydeki ucu burasıdır.
- **Yabancı kaydı.** Milo resmi bir kayıt tutmaz — tuttuğu şey alışkanlık: kim
  geldi, kaç gece kaldı, kim ödedi. Sorulursa söyler, saklamaz.
- **Üçlünün ilk iki gecesi.** @[Alton](entity:npc/Alton), @[Merla](entity:npc/Merla)
  ve @[Kromanna](entity:npc/Kromanna) köye geldiklerinde iki gece burada kaldılar;
  kulübeye sonra alındılar. Kumaşı gören adam bu yüzden Milo'dur (§3.3, iz 1) —
  ve parayı da o gördü: peşin, tartışmasız, **fazla**.

**Ne vermez:** Milo'nun yarası yok (02 §4 kotası). Sırrı yok, planı yok, kapıyı
para karşılığı açmaz — çünkü kapı zaten açık. Masayı tıkayan bir NPC değil,
tıkandığında dönülecek NPC.

---

## 4. Blight — hastalık ve kural kartı

Bu, 5e'nin üstüne eklenen **tek** kuraldır. Sapma işareti zorunlu (Yönerge §3.3,
README §6.5).

**Bu bölüm DM'in bildiğidir. Masada "Blight" diye *bilinen* bir şey yok
(KARAR, 4. tur).** Köy bir ad koydu; adın arkasında ne olduğunu **kimse** bilmiyor —
köylüler de, Umay da, oyuncular da, Meclis'in Simya koltuğu da
([`lonca-sehir.md` §6](lonca-sehir.md)). Dahası: **bunun bir hastalık olduğu bile
kesin değil.** Bulaşıyor *gibi görünüyor*, hasta ediyor *gibi görünüyor*; ama Act 1
boyunca "bu bir hastalıktır" cümlesini kanıtlayan tek bir sahne yok. Oyuncular buna
hastalık der çünkü ellerinde başka kelime yok — ve §4.6 o kelimeyi zayıflatır.

Aşağıdaki kural kartı **hastalık gibi işler.** Bu bir mekanik tercih, bir teşhis değil.

**Kategori kararı (2026-09-09):** kart `curse` olarak yazılır, `applied-condition`
olarak değil. Sebep şema: `applied-condition` zorunlu `condition_ref` ister ve
Blight bir SRD condition'ı değil; `curse` ise `trigger` · `effect` ·
`mechanical_notes` · `removed_by` alanlarını serbest bırakıyor
(`world-blueprint.md` §3.10). Kartın adı: **Blight — Enfeksiyon**. Halkın bildiği
yüzü ayrı kalır: `lore` kartı *Blight — Bilinen Hali*.

### 4.1 Bulaşma

Temasla. Üç yol: hastanın ya da cesedin sıvılarıyla temas · bir gece aynı kapalı
mekanda kalmak · bir Dönüşmüş'ün açtığı yara.

> Her maruziyet: **CON kurtulma zarı DC 12.** Başarısızlık = taşıyıcı, Evre 1.

Hastalanmak bir cezanın sonucu değil, **bir seçimin sonucu** (08 §4): cesede
dokundun, hastayı taşıdın, kulübeye girdin. Zar maruziyet olmadan atılmaz.

### 4.2 Evreler

**Evre 1 — sessiz taşıma (~1 ay).** Yorgunluk, iştahsızlık, damar renginin
koyulaşması. **Mekanik yük yok** — ve taşıyıcı bu sürede bulaştırır. Bu, üçlünün
gemiye binerken sağlıklı görünmesinin sebebidir (§3.1).

**Evre 2 — patlama.** Bir zorlanma tetikler: uzun yolculuk, yara, açlık, uykusuz
gece. O andan sonra **her uzun dinlenmede CON DC 13.**

> **Üç başarı** → atlatır. Bağışıklık kazanmaz; yeniden maruz kalırsa yeniden atar.
> **Üç başarısızlık** → Evre 3, saatler içinde.
> Her başarısızlık ayrıca **1 seviye exhaustion** verir ve belirtinin **biçimini
> değiştirir** (bkz. 4.3).

**Evre 3 — dönüşüm.** Bilinç gider, **beden güçlenir.** Blight insanı emir bekleyen
bir ete çevirir (02 §2). PC artık PC değildir: kağıt DM'e geçer, karakter
`Dönüşmüş` statblock'unu alır. **Geri dönüş yok.**

### 4.3 İki hasta hiç aynı seyri izlemez

Hastalığın imzası budur (02 §5.1) ve **mekanik değil anlatı** olarak işler: her Evre
2 başarısızlığında DM belirtiyi değiştirir — birinde yorgunluk, birinde kesik kesik
gidip gelme, birinde bedenin erken güçlenmesi. Sayılar aynı, görüntü asla aynı değil.
Kulübedeki üçlü bu kuralın canlı örneğidir: Alton yorgunlukta, Merla
değişkenlikte, Kromanna bedende.

### 4.4 Tedavi

**Bilinen bir tedavi yok** ve Act 1'de kimse bulmaz.

- *Lesser Restoration* — bir Evre 2 başarısızlığını siler. Bir gün kazandırır,
  hastalığı kaldırmaz.
- *Greater Restoration* — Evre 1 veya 2'de hastalığı **kaldırır.** Meridia'da bu
  büyüyü kimin yapabildiği ayrı ve **siyasi** bir sorudur; cevap Act 1'de verilmez.
- Evre 3'te hiçbir şey işe yaramaz. Dönüşmüş bir insan öldürülür, iyileştirilmez.

### 4.5 DM bilgisi — oyuncuya verilmez

Hastalık doğa değil, **birinin eseri**: Blight kralın mızrağının taşından çıkma
(02 §2). Act 1'de bu **kanıtlanmaz** — iğne kaldırıldığı için (§3.2) perdede bunu
işaret eden fiziksel bir nesne yok. Ama artık **tamamen görünmez de değil**: §4.6.
Act 1'in kanıtladığı tek şey suçun **gizleme** olduğu; eserin kendisi sonraki
perdelere kalır.

Üçlü **şu an son evrenin eşiğinde** (Evre 2'nin sonunda). Oyuncular bunu bilmiyor;
kimse bilmiyor.

### 4.6 Yalnız biyolojik değil — büyülü de (KARAR, 4. tur)

Blight bir hastalık gibi bulaşır ve bir hastalık gibi ilerler, ama **büyüseldir** ve
**bir kaynağa bağlıdır.** Kaynağın ne olduğu Act 1'de söylenmez, gösterilmez,
adlandırılmaz.

Perdedeki karşılığı **tek bir duyu**:

> **Arcana DC 13** (§3.3, iz 5) — büyü yapan/bilen bir PC hastanın yanında durunca
> bunun kendiliğinden olmuş bir şey olmadığını **hisseder.** Sönmeyen, yayılmayan,
> bir yere **bağlı duran** bir iz. Doğrultu yok, mesafe yok, ad yok.

**Ne verir:** perdenin "bu doğal değil" anı. Kaldırılan iğnenin (§3.2) yerini bir
nesne değil **bir PC'nin yeteneği** alıyor — yani her masada çıkmaz, ve çıktığında
o oyuncunun *kazandığı* bir şeydir.

**Ne vermez:** kaynağı, yönü, sorumluyu, tedaviyi. Bir de şunu vermez: **kesinlik.**
Büyülü olması hastalığın biyolojik *olmadığı* anlamına gelmiyor — ikisi birden, ve
Act 1 hangisinin önce geldiğini söylemiyor. *Detect Magic* ve benzeri tespit büyüleri
de aynı yere varır: bir şey **var**, ne olduğu **okunmuyor.** (Meclis'in Büyücü
koltuğu bunu zaten denedi ve okuyamadı — [`lonca-sehir.md` §6](lonca-sehir.md);
"sonuç yok" dediği şey aslında "okuyamadım".)

**Neden DC bu kadar düşük (13):** amaç saklamak değil. Masada büyücü varsa bu anın
**çıkması** isteniyor; yoksa perde onsuz da tam çalışıyor, çünkü §3.3'ün kritik hattı
zaten zarsız.

---

## 5. İlk savaş

Oyuncular kulübeye gidince üç **hastayı** bulur: konuşabilen, sayıklayan, korkmuş
insanlar. Sorgu mümkün — buradan çıkacak son bilgi budur.

Geceyi köyde geçirmek doğal seçim; köylüler de buna yönlendirir ("sabah bakın,
gece yol tehlikeli"). **Şafakta üçü tamamen döner:** üstün güç, bilinç yok.
Bu perdenin ilk çatışması. Bir gün önce NPC olan üç kişi artık monster.

> **Sayaç oyuncuda değil (08 §4).** Dönüşüm bir seçimin cezası değil, hastalığın
> takvimi. Oyuncular gece kalmazsa dönüşüm yine olur — köy ardından haber yollar,
> ya da yolda karşılarına çıkar. **Savaş atlanabilir bir yan sahne değil**, ama
> nerede olacağı oyuncuya bağlı.

Kart ihtiyacı: her biri için **iki kart** —
`npc` (1. gün, hasta) + `monster` (2. gün, dönüşmüş).
Aynı üç kişi, iki hal. Bu ikilik oyuncuya kimin öldürüldüğünü hatırlatır.

### 5.1 Statblock'lar

Üçü de **Dönüşmüş** gövdesinden türer; jenerik kart (`monster/Dönüşmüş`,
genel-kartlar §7) bu gövdenin kendisidir ve Blight'lı herhangi bir köylü için
kullanılır. Aşağıdaki üçü onun adlandırılmış hâlidir — ırkları ve §4.3'teki
belirti hattı statblock'a yansır.

**Ortak gövde — Dönüşmüş** · Humanoid (Blight'lı), Unaligned · **CR 1/2 (100 XP)**

> **AC** 12 (sertleşmiş deri) · **HP** 22 (4d8 + 4) · **Hız** 30 ft
> **STR** 16 (+3) · **DEX** 12 (+1) · **CON** 13 (+1) · **INT** 4 (−3) · **WIS** 8 (−1) · **CHA** 5 (−2)
> **Duyular** karanlıkgörüş 60 ft, pasif Algı 9 · **Diller** bildiği dilleri anlar, konuşamaz
> **Bağışıklık (durum)** charmed · frightened · exhaustion
>
> ***Acıyı Tanımaz.*** Sıfır HP'ye düştüğünde ölüm zarı atmaz; **ölür.** İnsan hâli
> zaten Evre 3'te bitmişti (§4.2) — bu kural masaya "kurtarma şansı yok" demenin
> mekanik hâli.
>
> ***Bulaştıran Yara.*** Pençesinin isabet ettiği yaratık **CON DC 12** atar;
> başarısızlık = Blight Evre 1 (@[Blight — Enfeksiyon](entity:curse/Blight — Enfeksiyon)).
> Zar savaşın sonunda bir kez atılır, her isabette değil.
>
> **Eylem — Pençe.** Yakın silahlı saldırı: **+5** isabet, erişim 5 ft, tek hedef.
> **Vuruş:** 1d8 + 3 delici (ort. 7).

**Dönüşmüş Alton** — halfling, *yorgunluk hattı* (§4.3) · **CR 1/2**

> Small. **AC** 13 · **HP** 18 (4d6 + 4) · **Hız** 25 ft · **STR** 14 (+2) · **DEX** 14 (+2)
> **Pençe** +4, 1d6 + 2 delici (ort. 5).
> ***Durmayan Adım.*** HP'sinin yarısının altına düştüğünde hızı 40 ft olur ve
> fırsat saldırılarına maruz kalmaz. Yorgunluk hattı böyle biter: beden yorulmayı
> unutur.

**Dönüşmüş Merla** — halfling, *değişkenlik hattı* (§4.3) · **CR 1/2**

> Small. **AC** 13 · **HP** 18 (4d6 + 4) · **Hız** 30 ft · **STR** 14 (+2) · **DEX** 14 (+2)
> **Pençe** +4, 1d6 + 2 delici (ort. 5).
> ***Kesik Kesik.*** Sırasının başında 1d6 at. **1–2:** bir yere bakakalır, eylemini
> kaybeder. **5–6:** fazladan bir Pençe saldırısı yapar. Masaya "iki hasta aynı
> seyri izlemez" kuralını gösteren tek mekanik budur; DM zarı **açıkta** atar.

**Dönüşmüş Kromanna** — tiefling, *beden hattı* (§4.3) · **CR 1 (200 XP)**

> Medium. **AC** 13 · **HP** 30 (4d8 + 12) · **Hız** 30 ft
> **STR** 18 (+4) · **CON** 16 (+3) · **Direnç** ateş (tiefling kalıntısı)
> **Pençe** +6, 1d10 + 4 delici (ort. 9).
> ***Erken Güçlenme.*** İlk turunda ek bir Pençe saldırısı yapar. Üçünün içinde
> hastalığın en çok "ödüllendirdiği" beden odur — ve masanın önce onu hedeflemesi
> doğru karardır.

**Tempo notu (DM).** Üçü birlikte 400 XP; 4 kişilik 1. seviye bir masa için
**zorlu-üstü.** Bilerek: köy tehlikede olmalı. Yumuşatma kolu üçü aynı anda
saldırmasın — Alton önce, diğer ikisi bir tur sonra kulübeden çıksın. Sertleştirme
kolu tersi. Masa 2. seviyeyse üçü birlikte gelir.

**Kurtarılabilirlik (06 #8 ✅):** köy ayakta kalır. Üçü ölür ama köy oyunun ilk
zaferidir — kaybetmek değil, kaybetmemek (07 "Motivasyon").

---

## 6. Sonrası — açılan kapılar

Savaştan sonra yön **oyuncuya kalır.** Köyün elinde şunlar var:

- **"Hastalık" / "Blight"** — köylüler adı koyar; ne olduğunu bilmezler.
- **"Bir limandan geldiler"** — kimin söylediğine göre hangi liman değişir (§8).
- **Gizli Liman** — yolu bilen kişi para karşılığı götürür. Resmi olmayan giriş.
- **Gizli cepteki yüzük** — perdenin en sağlam **nesnesi** (§3.3, iz 3), ama içeriği
  askıda. Şimdilik masaya verdiği şey saklanmış olmasıdır: bu insanların gizleyecek
  bir kaydı vardı.
- **"Hasta geldiler"** — Medicine DC 12'nin ya da Umay'ın verdiği cümle. Köyün
  kendini suçlamasını bitirir ve yönü limana çevirir. **Perdenin kritik cümlesi
  budur** (§3.3).
- **"Üstlerinde bir hastalıktan fazlası var"** — yalnız Arcana atan bir PC varsa
  (§3.3 iz 5, §4.6). Yön vermez, **ton** verir: bunun bir sahibi var.
- **İkinci kıta ve gerçek adlar** — üçlünün geçmişini kurcalayan masanın gidebildiği
  en uç katman (§3.1). Cevabı köyde değil, Meclis'te.

Buradan sonraki lokasyonlar (README §2 güzergahı) sırayla değil, oyuncunun seçtiği
sırayla açılır. Her biri için **en az 3–4 NPC** yazılacak, aynı üç satırlık
standartla:

| Yer | NPC ihtiyacı |
|---|---|
| **Gizli Liman** | → §7'de yazıldı |
| **Lonca** (Merkezi Şehir) | mertebeli lonca yetkilisi · kayıt memuru · sahada ajan · borçlu esnaf |
| **Merkezi Şehir** | meclis üyesi · şehir muhafızı · söylenti taşıyan · bastırılan tanık |
| **Paladin Şatosu (Votumar)** | kapı komutanı · rütbeli · kışkırtılmış genç asker · şüpheci vaiz |

Bilgi eğimi (09 §4) burada işler: limanda söylenti bol, şehirde bastırılmış,
Ravenhall'da yok.

**Paladin Şatosu · Ravenhall · Elymsyr liman kenti — KARAR VERİLMEDİ (4. tur).**
Üçü de bu turda detaylandırılmadı ve sonraya bırakıldı. Yukarıdaki NPC ihtiyacı
satırları onlar için **taslak**, söz değil. Yazılan tek yan hat Lonca/Şehir'dir
([`lonca-sehir.md`](lonca-sehir.md)) — ve Act 1'in kapsamı (Gümüşsu → ufukta ikinci
kıta) o hatla kapanıyor.

### 6.1 Doğrudan loncaya gitmek — en kısa yol (KARAR, 4. tur)

Oyuncular üçlünün geçmişini hiç kurcalamayabilir. Köyden çıkıp doğrudan **loncaya**
gidebilirler; bu yol kapalı değil, **en hızlısı.**

**Lonca ne yapar: bastırır.** Kurum olarak hastalığın konuşulmasını istemez ve sebebi
kötülük değil **hesap** — söylenti tek başına ticareti kesiyor. Altı koltuğun altı
ayrı inkârı için bkz. [`lonca-sehir.md` §6](lonca-sehir.md).

**Ama üyelerden biri görevlendirir.** Kurum bastırırken tek bir üye tersini yapar ve
oyunculara işi verir: **bu şeyin ne olduğunu bulun.** Karşılığında iki şey teklif eder:

1. **Ücretsiz seyahat** — perdenin sonundaki gemi bileti, parayla değil imzayla
   (§7.2'nin "iyi yazı"sı).
2. **Tüm mirasına ortaklık** — verecek parası yok, ama bir hanesi var.

> **Masanın görebileceği ince yer:** o miras **her gün küçülüyor.** Bu üyenin geliri
> akıştan gelir ve söylenti ticaret gemilerini azaltıyor — yani teklif ettiği pay,
> tam da oyuncuların çözmesi istenen sorun yüzünden eriyor.
>
> Bunu fark eden oyuncu iki şeyi birden anlar: teklif **düşündüğünden küçük**, ve adam
> **samimi** — elindeki tek şeyi veriyor, ve verdiği şey ancak iş biterse bir değer
> taşıyor. Insight istemez; rakamları duyan duyar.

**Kilitlenme yok:** bu görev yolun tek kapısı değil. Aynı yazıyı para da alır (§7.2),
aynı bilgiyi liman hattı da taşır (§7.5), ve üçlünün geçmişi hattı (§3.1) aynı odaya
başka kapıdan girer. Teklif metni ve ayrıntı:
[`lonca-sehir.md` §6.2](lonca-sehir.md).

---

## 7. Gizli Liman — yer olarak

Dünyanın her yerine açılabilen **gizli bir kapı**. Act 1'in en değerli kaynağı bu
yüzden burada duruyor: Meridia'dan çıkmanın kayıtsız yolu.

**Ad kuralı:** burada takma ad, meslek adı ve gemi adı kullanılır — herkes başka
bir yerden gelmiş, kimse doğduğu adı vermiyor. (Dil ayrımı kanon değil, §3.)

### 7.1 İçeri girmek — birinci kapı

Corvin yolu bilir ama **yol son kapı değil.** Yolun sonunda kayıt yok, kapı yok,
sadece insan var: kimse kefilsiz içeri alınmaz.

> **Kural: kefil, iş veya yük.** Üç giriş yolu var — içerideki birinin kefil olması,
> içerideki biri için bir iş görmek, ya da satılacak gerçek bir yükle gelmek.
> Corvin zayıf bir kefildir: kendisi de misafirdir. Onun sözü kapıyı aralar,
> açmaz.

Bu, "para verip tak diye varma"yı kapatan yerdir: para ikinci kapının konusu,
birincinin değil.

### 7.2 Buradan çıkmak — ikinci kapı

> **Yolculuk = ya konseyden iyi bir yazı/dost, ya iyi para.** İkisi de Act 1'in
> açılış kesesinde yok. Liman geçilen bir yer değil, **çalışılan** bir yer.

- **İyi para**, oyuncuların Gümüşsu'dan çıkarken taşıdığı paranın çok üstünde.
  Kazanılır: limanda iş, mal, ya da birinin borcunu devralmak.
- **İyi yazı**, konsey ağırlığı taşıyan bir kefalet — Lonca/Şehir hattından gelir.
  Yani ikinci kapı oyuncuları başka lokasyonlara yollar; liman tek başına
  bir çıkış değil, bir **kavşak**.

**Bu bir görev değil (KARAR, 2026-09-09 2. tur).** "Yol hakkı" diye ayrı bir `quest`
kartı yazılmıyor. Meridia'da yol serbesttir: köyden çıkmak, limana gitmek, şehre
yürümek kimseden izin istemez. Fiyatı olan tek şey **gemiye binmek** — o da bir
görev değil, oyuncular bir gemiye binmek istediğinde açılan **pazarlık sahnesi**
(`scene/Geçiş pazarlığı`). Kart olarak zaten var; ikinci bir sarmalayıcıya gerek yok.

### 7.3 Tehdit işlemez

- **Konseyle tehdit edilemezler**, çünkü konsey zaten burayı biliyor ve
  kısmen kullanıyor. İhbar bir silah değil, bilinen bir gerçek.
- **Genel tehdit de işlemez.** Burada tehdit, kavga başlatmaz; **ilan eder.**
  İlan edilen adama fiyat yükselir, kefil bulunmaz, kapılar kapanır. Ceza
  şiddet değil, **yalnızlık** — ve yalnız adam bu limandan çıkamaz.
- Yer yine de **tehlikeli**: kimse kimseyi korumak zorunda değil.

**İş çığırından çıkarsa (KARAR, 2026-09-09 2. tur): hazır kart yok.** "Liman
kaçışı" diye bir `encounter` yazılmıyor, çünkü bu limanda kavga bir kurgu değil bir
**sonuçtur** — masa kendisi ilan edilirse çıkar, ve nasıl çıkacağı ne yaptıklarına
bağlı. DM doğaçlar; üç sabit doğru yeter:

1. **Kimse yardıma gelmez.** Bir kavgaya karışmak, kavgayı çıkaranla aynı listeye
   yazılmak demektir. Rıhtım seyreder.
2. **Kaçmak kazanmaktır, ve pahalıdır.** Çıkış yolu bellidir (yol, iskele, bir
   gemi) ama arkalarında kapanan şey kapı değil **kefil**: bir daha bu limana
   girmek için yeni bir kefil bulmaları gerekir.
3. **Ölü bırakmak kapatır.** Burada birini öldüren, bu limanı Act 1 boyunca kaybeder.
   Bu bir ceza değil, fiyat — ve oyunculara **önceden** söylenir (@[Fare](entity:npc/Fare)
   söyler, bedava).

### 7.4 Düzen — yöneticisi yok, düzenleyeni var

Reis yok, bayrak yok. İşleri yürüten birkaç kişi var; sözleri geçer çünkü
sözlerinin bozulması herkese pahalıya patlar.

| NPC | Ne istiyor | Ne gizliyor | Hangi kapıyı açar |
|---|---|---|---|
| **Sicim** — defter tutan, düzenleyici *(gnome)* | Limanın işlemeye devam etmesi | Üçlünün geçişini kimin sildirdiğini biliyor · gerçek adı **Burgell** | Ücret · kefalet · **üçlünün izi** |
| **Fare** — rıhtım çırağı *(halfling)* | Bir gün bir gemiye alınmak | — (yarası olmayan NPC, 02 §4 kotası) · gerçek adı **Trym** | Her şey: kim ne zaman yanaştı, hangi kaptan kimi alır |
| **Kaptan Caelynn** — iyi kaptan *(yarı-elf)* | Göremediği yükü taşımamak | Üçlüyü geri çevirdi; sonra başka gemiyle gittiklerini duydu | Temiz yolculuk — **yazı ya da yüksek fiyat** |
| **Kaptan Holg** — ucuz kaptan *(yarı-orc)* | Para, hızlı sefer | Gemisi ve mürettebatı güvenilmez | Ucuz ve kötü yolculuk (gerçek bir seçenek) |
| **Kadife** — konsey aracısı, saklanmıyor *(insan)* | Limanın konseye yararlı kalması | Hangi konsey koltuklarının pay aldığı · defterdeki adı **Halet Custar** | "İyi yazı"nın nasıl alındığı |
| **Mine** — kuyumcu *(cüce)* | Tezgahının açık kalması | Yüzüğü eğeleyen el onunki · **klan adını söylemiyor** | *Kaydı kim sildirdi*'nin ikinci taşıyıcısı (§9) |

**Adlandırma kuralı — limanın tamamı lakapla konuşur.** *Sicim · Fare · Kadife ·
Mine* ad değil takma addır, ve kuralı şudur: **bir insana eşya adı takılmışsa o
insanın mührü yoktur.** Lakap, Sancak Kaydı'nın negatifidir. Gerçek adlar bir
ödüldür — oyuncu kazanır, DM dağıtmaz. **Kaptan Caelynn'in lakabı yok** çünkü
kayıtlı: limandaki tek tek-katmanlı insan o, ve oyuncu farkı üç cümlede duyar.

**Kuyumcunun cüce olması kartı kendi kendine yazıyor.** Ayar damgası Demirci-İşçi
Loncası'nın, o loncanın hanesi (Ferrunlar) cüce; mührü eğeleyip damgayı tazeleyen
elin cüce eli olması masada hiçbir açıklama istemez. Ve **klan adını söylemiyor** —
bir cüce için bu, insan için "adım yok" demekten ağırdır. Adam kayıtsız değil,
*kendini kayıttan düşürmüş* biri: üçlüyle aynı şeyi yapmış, onlardan önce.

**Konsey aracısı — nasıl tanınır (2026-09-09 2. tur).** Rıhtımdaki herkesten
**daha iyi giyimli**: temiz yaka, lekesiz çizme, tuz lekesi olmayan bir palto.
Yük tutmamış eller. Burada gizlenmeye çalışmaz, çünkü gizlenmesi gerekmiyor — bu
limanın konseyce bilindiği zaten kabul edilmiş bir gerçek (§7.3).

> **Zar yok:** lonca hattından gelen bir PC (§2 — Lonca Üyesi · Mertebeli · **Lonca
> Ajanı** · Rütbeli) onu **görür görmez tanır.** Yüzünü değil, *cinsini* tanır:
> duruşu, kâğıt taşıma biçimi, konuşmadan önce beklemesi. "Bu adam bir kurumun
> adamı, ve burada onun adına duruyor." Bu, background'un kurgusal değil masada
> işleyen karşılığıdır.
>
> Diğer PC'ler için **Insight DC 13**: adamın rıhtıma ait olmadığını görür, kime
> ait olduğunu göremez.

Kart **Konsey Aracısı** başlığıyla yazılır; rıhtımda **Kadife** diye çağrılır,
defterdeki adı **Halet Custar**'dır (KARAR, 2026-09-09 3. tur). İki adı birleştiren
oyuncu "konsey aracısı"nı soyut bir rolden bir haneye çevirir: **Askeri Hukuk
koltuğunun limanda parası var** demektir. İkinci ad şehirde bulunur, limanda değil.

**Fare, bilgi eğiminin taşıyıcısı (09 §4):** limanda söylenti boldur, ve Fare
söylentinin haritasıdır. Oyuncular tıkanırsa açılan kapı odur — bedeli para değil,
ilgi: kimse ona bir şey sormaz.

### 7.5 Buranın Act 1'e verdiği

Üçlünün izi burada bitmiyor, **burada başlıyor**: kaydın silinmesi satın alınmış
bir hizmetti ve birisi o parayı aldı. Yüzüğün yedek içeriği doğrulanırsa (§3.3, iz 3)
iç kenardaki taze Meridia ayar damgası bu limanı işaret eder — eğeleme burada, bir
arka odada yapıldı. *Yüzük içeriği askıda olduğu için bu cümle şu an **koşulludur**;
limanın Act 1'deki yeri ona bağlı değil.*

Sicim'in defteri soruyu somutlaştırır: *kim ödedi.* Cevap limanda **değil**;
Lonca ve Şehir hattında. Limanın verdiği şey cevap değil, **bir sonraki kapı.**

✅ Yüzüğü eğeleyen kuyumcu yazıldı (§7.4): **Mine**, klan adını söylemeyen bir cüce.
*Kaydı kim sildirdi*'nin ikinci taşıyıcısı odur — bilgi yalnız Sicim'de değil, iki
taşıyıcı kuralı (§1) bu hatta da sağlanmış durumda.

⚠️ **Mine'ın kartı yüzük kararına bağlı (4. tur).** Yüzüğün içeriği değişirse Mine'ın
"ne gizlediği" de değişir; **kişi durur, işi değişir.** Klan adını söylemeyen,
kendini kayıttan düşürmüş bir cüce kuyumcu her senaryoda ayakta kalıyor.

### 7.6 Rıhtım — yer olarak

Limanın çalışan yüzü ve **ayrı bir kart** (KARAR, 2026-09-09 2. tur): Gizli Liman
bir *durum*, Rıhtım bir *yer*. Masanın vaktinin çoğu burada geçer.

**Manzara:** üç ahşap iskele, hiçbiri düz değil. Vinç yok — her şey el, halat ve
kanca. Balıkçı kayığından iki direkli yük gemisine kadar her boyda tekne, hiçbiri
bayrak taşımıyor. Fıçı, denk, sandık; üstlerinde damga değil **tebeşir işareti**
var, çünkü damga kayıt demek.

**Ne yapılır:**

- **İş bulunur.** Gündelik yük taşıma; kimse ad sormaz, akşam nakit öder. §7.2'nin
  "iyi para"sının ilk basamağı burasıdır — ve tek başına yetmez.
- **Görülür.** Kimin ne zaman yanaştığı, hangi geminin hangi gece yüklendiği burada
  açıkta olur. @[Fare](entity:npc/Fare) bu görüntünün hafızasıdır.
- **Duyulur.** Söylenti rıhtımda bol, iç odalarda az. Bilgi eğiminin (09 §4) en
  yüksek noktası.

**Kural:** rıhtımda kavga çıkaran **ilan edilmiş olur** (§7.3). Bu yüzden burada
sesler yükselir, bıçak çıkmaz.

**Rıhtım İşçisi background'ı** (§2) burada eve döner: kancayı tanıyan adam
kendiliğinden işe alınır, ve işçi ağı ona ilk gün konuşmaz ama ikinci gün konuşur.

---

## 8. Bu belgeden çıkan yazım listesi

> Kartların tek tek dökümü: [`act1-kartlar.md`](act1-kartlar.md).
> Act'tan bağımsız kartlar (giriş kartı, background, evren lore'u):
> [`genel-kartlar.md`](genel-kartlar.md).

| Kategori | Act 1 açılışı için |
|---|---|
| `location` | Gümüşsu · Kulübe · **Goodbarrel'ın Ocak Başı** (§3.4) · Gizli Liman · **Rıhtım** (§7.6) |
| `npc` | Gümüşsu kadrosu (4) + üç hasta (1. gün hali) + Gizli Liman kadrosu (5, **Konsey Aracısı** dahil) |
| `monster` | Dönüşmüş üçlü (3 kart, statblock §5.1) |
| `background` | §2'deki 9 background — mekanikleri kapandı, yazılabilir |
| `curse` | **Blight — Enfeksiyon** (§4): perdenin tek kural sapması |
| eşya | **Mühürsüz Yüzük** (§3.3) ⚠️ *içerik askıda, ad geçici* + **13 background eşyası** (§2) — hepsi kendi kartı |
| `scene` | Köye varış · kulübe sorgusu · şafak dönüşümü · **limana kabul** · **geçiş pazarlığı** |
| `encounter` | Şafak çatışması *(tek — "Liman kaçışı" kaldırıldı, §7.3)* |
| `quest` | "Söylentinin peşinde" (giriş) + "Nereden geldiler" *("Yol hakkı" kaldırıldı, §7.2)* |

Sonraki lokasyonların NPC'leri (§6 tablosu) ikinci turda yazılır.

---

## 9. Bu belgenin açtığı kararlar

**Kapatılanlar (2026-09-08):** Gümüşsu'nun 7 adı + halk dili/Latin ayrımı ·
background eksisi kurgusal · liman iki kapılı (kefil/iş/yük → yazı/para) ·
konsey limanı biliyor, tehdit işlemez · üçlü **Gizli Liman**'dan geldiler.

**Kapatılanlar (2026-09-09 revizyonu):**

1. **Cerrahi iğne kaldırıldı** (§3.2). Kimse kimseyi bilerek hasta etmedi; hastalık
   ikinci kıtadan geldi. Suç bulaştırma değil **gizleme**.
2. **Üçlü kim** (§3.1): iki halfling + bir tiefling, üçü de zengin, ikinci kıtadan
   kaçtılar, kaçamadılar, kayıtlarını parayla sildirdiler, limandan sonra yol bitti.
   "Sivil yolcu" kararı korundu — paladin/asker değiller.
3. **Adları sahte** (§3.1). Gerçek adlar köyde yazılmıyor; **4. turda** karşılığını
   Meclis'te buldular ([`lonca-sehir.md` §6.3](lonca-sehir.md)).
4. ~~**Catch = üç iz**~~ — **4. turda beşe çıktı ve içeriği değişti** (§3.3):
   kumaş (zarsız) · altın kesesi + boş parşömen (zarsız) · **gizli cepteki** yüzük
   (Investigation DC 15, tek kapı) · beden (Medicine DC 12) · hava (Arcana DC 13).
5. **Background mekanik yükü** (§2): evrene özel *feature* yok — şemada yeri yok.
   Feature'ın işini eşya + kurgu yapıyor.
6. **Background eşyaları için yeni kart yazılmıyor** (§2): dokuzu da SRD nesnesi.
   Bu, genel-kartlar §4'teki 9 ⬜ kartı tamamen kapatıyor.
7. **Blight kural kartı `curse`** (§4), `applied-condition` değil. Evreler, DC'ler
   ve tedavi yazıldı.
8. **Giriş kartında Miras vurgusu düşürülüyor** (genel-kartlar §1): üç aşamalı
   omurga (Act 1 = Miras) kanon olarak duruyor ama **oyuncunun ilk okuduğu sayfada
   ilan edilmiyor.** Ton kuralı zaten aynı şeyi gösteriyor; söylemek fazlaydı.

**Kapatılanlar (2026-09-09, 2. tur):**

9. **Adlandırma Doktrini'nin dil ayrımı kaldırıldı** (§3, §7). "Halk dili köyde,
   Latin kurumda" diye bir kanon yok; adlar karışık kalır. Doktrin bölümüne sonra
   dönülecek. §3.1'in "sahte ad" gerekçesi de buna göre yeniden yazıldı.
10. **Background eşyaları kart oluyor** (§2) — 5. kararın (1. tur) tersi. 13 eşya
    kartı; içerikleri sonraya. Gerekçe: eşya kapıdır, kapının ne açtığı SRD
    satırında yazmıyor.
11. **Goodbarrel'ın Ocak Başı** (§3.4) ve **Rıhtım** (§7.6) yer olarak yazıldı; ikisi de
    ayrı `location` kartı.
12. **Dönüşmüş üçlünün statblock'ları** (§5.1): ortak CR 1/2 gövde + iki halfling
    (CR 1/2) + bir tiefling (CR 1). Jenerik *Blight'lı köylü* kartı bu gövdedir.
13. **Konsey aracısı tanımlandı** (§7.4): rıhtımın en iyi giyimlisi, saklanmıyor;
    lonca hattından bir PC onu **zarsız** tanır, diğerleri Insight DC 13.
14. **"Liman kaçışı" `encounter` kartı yazılmıyor** (§7.3) — doğaçlama, üç sabit
    doğruyla. **"Yol hakkı" `quest` kartı yazılmıyor** (§7.2) — yol serbest,
    fiyatı olan tek şey gemiye binmek, o da mevcut pazarlık sahnesi.
15. **Sicim'in defteri kart değil** (§7.5) — sahnede duran bir prop, ayrı karta
    ihtiyacı yok.
16. **Kolye (pusula) Act 1'de yok** — karar verilene kadar yokmuş gibi davranılır.

**Kapatılanlar (2026-09-09, 3. tur — adlandırma):**

17. **M5 kapandı: bütün adlar kondu.** Kadro artık *Duran · Umay · Corvin · Milo
    Goodbarrel* (köy), *Alton Leagallow · Merla Tealeaf · Kromanna* (kulübe),
    *Sicim · Fare · Kaptan Caelynn · Kaptan Holg · Kadife · Mine* (liman).
18. **Irk ve statblock her NPC'ye yazıldı** — ad ırkı ele veriyor, DM tarif etmiyor.
    Kural: **soyadı ≠ hane.** Halfling ve cüce soyadları Sancak Kaydı'nda hane
    sayılmaz, defter onları *"tek isim + boş hane"* yazar.
19. **Üçlü bir hane** (§3.1): karı koca halfling + tiefling kadın hizmetli-koruyucu.
    İki sahte ad **ayrı soyadı** taşıyor → alyans çifti perdenin ilk çatlağı.
    Kromanna adını değiştirmedi çünkü tiefling adı saklanamaz.
20. **Kuyumcu yazıldı** (§7.4): **Mine**, klan adını söylemeyen cüce. ⬜ kapandı,
    *kaydı kim sildirdi*'nin ikinci taşıyıcısı yerine oturdu.
21. **Konsey Aracısı'nın iki katmanı** (§7.4): limanda *Kadife*, defterde
    *Halet Custar* — Custarlar, yani Askeri Hukuk koltuğu.

**Kapatılanlar (2026-09-09, 4. tur — belirsizlik turu):**

22. **Hastalığın ne olduğu bilinmiyor, ve "hastalık mı" sorusu bile açık** (§4).
    Blight bir DM adı; masada kimsenin elinde teşhis yok. Kural kartı hastalık *gibi*
    işler — bu mekanik tercih, teşhis değil.
23. **Blight büyülü + biyolojik, ve bir kaynağa bağlı** (§4.6). Perdedeki tek
    karşılığı **Arcana DC 13** (§3.3 iz 5). Kaynak adlandırılmıyor, yön verilmiyor.
24. **Üçlünün üzerindeki eşya listesi kapandı** (§3.3): giysi · **altın kesesi** ·
    **birkaç boş parşömen** · **gizli cepte bir yüzük.** Başka hiçbir şey yok.
25. **Yüzük artık parmakta değil, gizli cepte** ve **tek kapılı** (Investigation
    DC 15). Bu yüzden **kritik iz değil**; kritik hat beden + Umay (§3.3).
26. **"Kurban değil müşteri" geri alındı** (§3.2). Üçlünün ödeyen mi taşınan mı
    olduğu karar verilmedi; iki okuma da masada açık.
27. **Gerçek adların karşılık bulduğu yer: Lonca Meclisi** (§3.1). Bilgi katmanı iki
    basamak — geldikleri yer, gerçek adları — ve orada biter.
28. **Doğrudan lonca yolu yazıldı** (§6.1): kurum bastırır, bir üye görevlendirir;
    ödül **ücretsiz seyahat + mirasa ortaklık**, ve miras her gün küçülüyor.

**Açık:**

1. ~~**M5 kişi adı dağarcığı**~~ — **KAPANDI** (3. tur, yukarıda 17–21).
2. ~~**"İyi yazı" tam olarak nedir**~~ — **KAPANDI** (2026-09-09, lonca turu):
   Sınır ve Ticaret koltuğunun **karşı-imzalı geçiş kağıdı.** Karşılığında para
   istemez, iş ister — Meclis'in en fakir üyesinin gizli görevi
   ([`lonca-sehir.md` §6.2](lonca-sehir.md)). Para yolu (§7.2) kapanmadı; bu ikinci
   ve ucuz yol.
3. **"İyi para"nın rakamı ve kazanma yolları** — limanda yapılabilecek 2-3 iş.
   Liman `scene`'leri yazılırken.
4. ~~**Yüzüğü kim eğeledi**~~ — **KAPANDI** (3. tur): **Mine**, Gizli Liman'ın
   kuyumcusu, klan adını söylemeyen bir cüce (§7.4). ⚠️ *Yüzüğün içeriği 4. turda
   askıya alındığı için bu cevap **koşullu**: eğeleme okuması düşerse Mine'ın işi
   değişir, kendisi durur.*
5. **Yüzüğün ne olduğu** (§3.3, iz 3) — **AÇIK, 4. tur.** Nesnenin var olduğu ve
   gizli cepte taşındığı kanon; ne olduğu değil. Yedek içerik (mührü eğelenmiş,
   ayar damgası taze Meridia) belgede duruyor ve kanon sayılmıyor. Karar verilince
   §3.3 · §6 · §7.5 · Mine'ın kartı ve `Mühürsüz Yüzük` kart adı birlikte güncellenir.
6. **Üçlünün geçmişi, yolu ve hastalığı nasıl kaptıkları** (§3.1, §3.2) — **AÇIK,
   4. tur.** Sabit olan üç şey: ikinci kıtadan geldiler · kayıtsız geldiler ·
   limandan sonra yol bitti. Gerisi karar bekliyor, ve Act 1 gerisi olmadan da oynanır.
7. **Hastalığın kaynağı** (§4.6) — Act 1'de adlandırılmıyor; kaynağın *ne* olduğu
   sonraki perdelerin kararı.
8. **Paladin Şatosu · Ravenhall · Elymsyr liman kenti** (§6) — **AÇIK, 4. tur.**
   Detaylandırma sonraya bırakıldı; §6 tablosundaki NPC ihtiyaçları taslak.
9. Devam eden M0 kalıntıları: M0.2 · M0.3 · M0.6 (README §3.2).

---

## 10. DM'e not — bu revizyonun bedeli

*Karar sahibine, kartın içine girmeyecek notlar.*

- **İğne gitti ama "bu doğal değil" anı gitmedi** *(4. turda düzeltildi).* Eski not
  fazla kesin yazılmıştı. Doğal olmadığı zaten **kısmen anlaşılıyor**: beden,
  hastalığın köyün sandığından eski olduğunu söylüyor (§3.3 iz 4) ve kimsenin
  ölmemesi Umay'ın kırk yılıyla çelişiyor. 4. turda buna **Arcana DC 13** eklendi
  (§4.6) — hastalık büyülü ve bir kaynağa bağlı, ve bir büyücü bunu **hissedebiliyor.**
  Değişen şey şu: eskiden bu an bir nesneyle **garantiydi**, şimdi bir yetenekle
  **kazanılıyor.** Doğaüstünün ilk *kanıtı* yine Act 2'de; ilk **sezgisi** Act 1'de.
- **Üçlünün ne olduğu açık değil, ve bu bilerek böyle** *(4. tur).* "Kurban değil
  müşteri" cümlesi geri alındı — geçmişleri, yolları ve hastalığı nasıl kaptıkları
  karar verilmedi (§3.1, §3.2). Masada iki okuma da açık: parayı verenler onlarsa
  masa onlara kızar, taşınanlarsa acır, ve kulübede söylenen hiçbir cümle ikisi
  arasında seçim yapmıyor. **Karar vermeden oynanır.** Ama *kim aldı bu parayı*
  sorusunun cevabı buna dayanıyor, yani Act 2'den önce kapanması gerekiyor.
- **"Yüzük mühür sistemine bağlı" ne demekti** *(anlaşılmadı, sade yazıldı).* Üç
  cümlede: **(1)** Bu dünyada mühür = kimlik; mühürlü yüzük taşımak "ben devletin
  defterinde varım" demek. **(2)** Bu kural henüz **hiçbir yerde yazılı değil** —
  Sancak Kaydı belgesi yok (10 M1). **(3)** Yani yüzük şu an *henüz yazılmamış bir
  kuralın kanıtı*; Sancak Kaydı'nı yazarken "mühür = hukuki kimlik" cümlesini
  koymazsan yüzük anlamsız bir takıya döner.
  **Yapılacak iş tek satır:** Sancak Kaydı yazılırken o cümleyi kanon olarak koy.
  *(4. turda yüzüğün içeriği askıya alındı, yani risk şimdilik ertelendi — ama içerik
  yine mühre bağlanırsa aynen geri gelir.)*
- **"Medicine DC 12 kasten düşük" ne demekti** *(anlaşılmadı, sade yazıldı).* DC 12'yi
  Medicine'e bakan bir 1. seviye karakter neredeyse **her zaman** geçer. Bu bilerek:
  o ipucu (*"bu üçü hasta geldi"*) perdenin yönünü veren cümle, kaçırılırsa masa
  köyü suçlamaya devam eder. O yüzden zarı **engel değil hediye** yaptım — üstelik
  Umay aynı şeyi zaten zarsız söylüyor, yani zar atmayı seven masa atsın diye duruyor.
  Tersi Investigation DC 15 (yüzük, §3.3 iz 3): **gerçekten başarısız olunabilsin**
  diye yüksek, çünkü yüzük kritik değil — kaçırılırsa hiçbir hat kapanmıyor.
- **Üçlünün üstünde ne var, artık kapalı bir liste** *(4. tur).* Altın kesesi + boş
  parşömen + gizli cepte yüzük. Bu listenin sessiz faydası: **arama sahnesi kısa.**
  DM "başka ne var" sorusuna üç kez "bu kadar" der ve boşluğun kendisi bilgi olur —
  bavulu olmayan, mektubu olmayan, kağıdı boş üç zengin. Kese dolu olduğu için de
  masa "parayı bitirmişler" diye yanlış hikayeye sapmıyor.
- **Eşya kartı sayısı 1'den 14'e çıktı** *(4. turda düzeltildi).* Haklısın: kartların
  **kendileri yazıldı** — ad, kategori, SRD muadili ve neyi açtığı
  ([`genel-kartlar.md` §4](genel-kartlar.md)). Boş duran şey kart değil, kartların
  içindeki **metin**: kitapların içi, rozetin nakşı, künyenin ibaresi. O da bilerek
  bekliyor, çünkü kitabın içini yazmak Sancak Kaydı'nı (10 M1) yazmadan mümkün değil.
  Yani bu bir borç değil, **sıraya konmuş bir iş.**
- **Üç lokasyon bilerek boş** *(4. tur).* Paladin Şatosu · Ravenhall · Elymsyr liman
  kenti (§6) yazılmadı. Riski yok: Act 1'in kapsamı Gümüşsu → liman → (Lonca/Şehir) →
  ufukta ikinci kıta ile kapanıyor. Tek dikkat edilecek şey, §6 tablosundaki o üç
  satırın **taslak** olduğunu unutmamak — masaya söz verme.
- **Statblock'lar "1–2. seviye" dedin, ben 1. seviyeye ayarladım.** Üçü birlikte
  400 XP; 4 kişilik 1. seviye masa için zorlu-üstü, 2. seviye için tam yerinde.
  §5.1'in sonundaki tempo notu iki yönde de kolu veriyor. Masan 2. seviyede
  başlıyorsa hiçbir şey değiştirme, üçünü aynı anda gönder.
- **Adlandırma Doktrini askıya alındı, ama boşluk bıraktı.** Dil kuralı gitti; onun
  yerine "ad nasıl seçilir" sorusuna cevap koymadım — bilerek, çünkü sen o bölüme
  sonra bakacağını söyledin. O zamana kadar yeni ad koyarken tek ölçü kulak.
- **Konsey aracısı, lonca background'larına ilk somut karşılığını verdi.** §2'deki
  "artı mekanik, eksi kurgusal" kuralı burada tersine çalışıyor: kurgusal bir geçmiş,
  zarsız bir bilgi kazandırıyor. Bu iyi — ama tek örnek kalırsa tesadüf gibi durur.
  Sonraki lokasyonlarda her background'a bir tane böyle "zarsız tanıma" anı borçluyuz.
- **Background sayısı 9 ve hepsi kurumsal.** Hiçbiri köylü/çiftçi değil; kayıtsız,
  taşralı bir PC isteyen oyuncu SRD'den `Farmer` alacak. Onuncu bir "Kayıtsız"
  background'ı isteyip istemediğini söyle — §3'ün temasıyla (kayıtsız insanın
  kaybolması kayda geçmez) doğrudan örtüşürdü.
