# SRD 5.2.1 Türkçe Sözlük

> **Durum: ONAYLANDI (2026-10-07, Faz 1 kapısı).**
> Bu dosya tek kaynaktır: çevirmen ajanlar buradan okur, `check_pairs` (Faz 3)
> buradaki tabloları ayrıştırır (N10). Ayrı bir `glossary.json` tutulmaz.

## 0. Nasıl okunur

**Terim önceliği (kullanıcı kararı, 2026-10-07):** **BG3 > BG:EE > rehber > öneri.**
BG3'ün resmî Türkçesi (AiBell) ve Beamdog'un *Baldur Geçidi: Yenilenmiş Sürüm Türkçe Terim
Belgesi* Türk oyuncuların en çok gördüğü terimlerdir; bir terim oralarda varsa onlar kazanır.
Rehber (`dnd_5e_tr_rehber.pdf`) oralarda olmayan terimler ve üslup için kaynaktır.

**Kaynak** kolonu:

| Kod | Anlamı | Onay |
|---|---|---|
| **B** | BG3 ya da BG:EE resmî Türkçesinde aynen geçiyor | Onaylı (kullanıcı kararı) |
| **B~** | BG3/BG:EE teriminden türetildi (ör. `Can Puanı` → `Geçici Can Puanı`) | Toplu onay |
| **R** | Rehberde aynen geçiyor (BG'de karşılığı yok) | Rehber onaylı sayılır |
| **R~** | Rehberden uyarlandı (büyük harf, tekil/çoğul, ek ya da 2024 adına uyarlama) | Toplu onay |
| **Ö** | Öneri — hiçbir kaynakta karşılığı yok (çoğu 5.2.1'e özgü) | Onaylandı (2026-10-07) |
| **D#** | §1'deki bir kararla belirlendi | Karar onaylı |

**Kapsam.** Bu sözlük, metinlerin içinde tekrar tekrar geçen kural terimlerini, Tier-0 sözlük
kategorilerini, sınıf/tür/alt sınıf/özellik adlarını ve karşılığı bilinen ekipman adlarını
kapsar. Tek tek varlık adları (büyü, canavar, büyülü eşya, hüner, macera tertibatı) kendi
dalgasında çevrilir ve **dalga onayında ad listesi topluca** gösterilir (ROADMAP Faz 5).
Varlık adları için de aynı öncelik geçerlidir: BG:EE terim belgesinde yüzlerce büyü, canavar ve
eşya adı vardır (`Bless` → `Kutsa`, `Beholder` → `Kemgöz`, `Bag of Holding` → `Dipsiz Çuval`).

**Aynen kalır** (N6 istisnası — İngilizceyle aynı olması hata değildir): Arcana · Druid · Paladin ·
Elf · Drow · Goliath · Tiefling · Fey · Elemental · Feywild · Shadowfell · dış düzlem özel adları ·
Mastiff · Dart · Normal · Cantrip · Ki · DC · CR · XP · gp · sp · cp · ep · pp · lb. · ft.

---

## 1. Kararlar

| # | Karar | Durum |
|---|---|---|
| D1 | Büyü adı (kart başlığı) | ✅ **Sadece Türkçe**: `Fireball` → `Alev Topu`. Ad önce BG3/BG:EE'den, yoksa rehberden (`fireball (alev topu)`) alınır, o da yoksa öneri olur; ad listesi dalga 5.6 onayında topluca gösterilir. |
| D2 | Metin içinde geçen büyü adı | ✅ D1 ile aynı — sadece Türkçe, kaynaktaki büyük harf korunur |
| D3 | Canavar adları | ✅ BG3/BG:EE'deki karşılık (`Beholder` → `Kemgöz`, `Mind Flayer` → `Zihin Yüzücü`, `Bugbear` → `Öcügoblin`); orada yoksa özel adlar İngilizce, cins adları Türkçe |
| D4 | Sınıf adları | ✅ §5.1 — BG3/BG:EE (Ruhban, Dövüşçü, Sihirbaz, Sehhar…) |
| D5 | 5.2.1'e özgü terimler (**Ö** satırları) | ✅ Onaylandı (2026-10-07); BG3/BG:EE karşılığı bulunanlar **B**'ye çekildi |
| D6 | Türkçe adla arama | ⏳ Faz 6'da, ayrı onayla |
| **D7** | **Uygulama arayüzü sözlükle hizalanır** (aşağıdaki tablo) | ✅ `app_tr.arb`'deki çakışan terimler sözlüğe çekilir (ayrı commit, ROADMAP 4.8) |
| **D8** | Durum adları | ✅ İsim hâli (`Körlük`, `Zehirlenme`); metin içinde "`<ad> durumunda`" kalıbı |
| **D9** | Extra Attack | ✅ `Ekstra Saldırı` (sözlük onayıyla, 2026-10-07) |
| **D10** | Staff / Wand | ✅ Staff = **Asa**, Wand = **Değnek** (BG:EE ile aynı); Quarterstaff = **Dövüş Sopası** (BG:EE) |
| **D11** | Terim önceliği | ✅ **BG3 > BG:EE > rehber > öneri** — BG'nin 5e'ye uymayan terimleri dahil hepsi (Kabiliyet/Yetenek, katkı, İrfan) |
| **D12** | İngilizce kısaltmalar | ✅ HP, HD, AC yazılmaz; tam Türkçe terim kullanılır (`Can Puanı 45 (6d10 + 12)`, `Zırh Sınıfı 15`). DC, CR, XP aynen kalır. |

**D7 — arayüzde değişecek terimler** (`app_tr.arb` → sözlük):

| İngilizce | Arayüz şu an | Sözlük |
|---|---|---|
| Proficiency Bonus | Yeterlilik Bonusu | Yetkinlik Katkısı |
| Ability (yetenek skoru) | yetenek | kabiliyet |
| Skill / Skills | Beceri / Beceriler | Yetenek / Yetenekler |
| Short Rest / Long Rest | Kısa Mola / Uzun Mola | Kısa Dinlenme / Uzun Dinlenme |
| Initiative | İnisiyatif | Öncelik |
| feat | feat | hüner |
| Magic items | Sihirli eşyalar | Büyülü eşyalar |
| Bonus (ör. "+{amount} to chosen ability") | bonus | katkı |

Arayüzle zaten **uyumlu** olanlar (BG ile aynı): Kurtarma Zarı · Yetkin / Yetkinlikler · Can Puanı ·
Can Zarı · Hasar Türü · Çoklu Sınıf · Durum · Sınıf · Alt Sınıf · Geçmiş · Tür · Yönelim · Büyü ·
Cantrip · Büyü Yapma · Silah Ustalığı · İlahi Düzen · Direnç · Bağışıklık · Hırsız Argosu · Seviye.

---

## 2. Üslup kuralları

1. **Hitap "sen", geniş zaman** — rehberdeki gibi: *"Bir d20 at ve ilgili kabiliyet katkını
   eklersin."* · *"…kurtarma zarı atar ya da yere düşer."*
2. **Sayılar rakamla, birebir** (K5): `3. seviye`, `1 dakika`, `DC 15 Çeviklik kurtarma zarı`,
   `2d6 + 3 ateş hasarı`. Yazıyla yazılmış İngilizce sayı Türkçede de yazıyla
   (`one creature` → `bir varlık`).
3. **Kesme işareti** kısaltma ve rakamlarda: `DC'si`, `d20'ye`, `3d6'yı`, `CR'si`.
4. **Kısaltmalar** (D12): DC, CR, XP, gp/sp/cp/ep/pp, lb., ft., d4–d100 aynen; HP → `Can Puanı`,
   HD → `Can Zarı`, AC → `Zırh Sınıfı` (kısaltma yok).
5. **Birimler dönüştürülmez** (K5): `feet/foot` → `fit` · `ft.` → `ft.` · `mile` → `mil` ·
   `pound` → `pound` · `lb.` → `lb.` · `gallon` → `galon` · `pint` → `pint` · `ounce` → `ons` ·
   `inch` → `inç`. (Rehber bazı yerlerde litreye çevirir; biz çevirmeyiz — K5.)
6. **Büyük harf kaynağı izler**: İngilizcede büyük harfle başlayan oyun terimi (özellik, eylem,
   durum, büyü, sınıf adı) Türkçede de büyük harfle başlar. Böylece eşleme birebir kalır.
7. **Parantez içi nitelik çevrilir**: `Extra Attack (Fighter)` → `Ekstra Saldırı (Dövüşçü)` ·
   `Expertise (Bard II)` → `Uzmanlık (Ozan II)` · `Mystic Arcanum (Level 6 Spell)` →
   `Mistik Sır (6. Seviye Büyü)` · `Draconic Ancestor — Fire` → `Ejderha Ata — Ateş`.
8. **Kabiliyet zarı kalıbı**: `Strength check` → `Kuvvet zarı` · `Wisdom (Perception) check` →
   `İrfan (Algı) zarı` · `Dexterity saving throw` → `Çeviklik kurtarma zarı`.
9. **Durum kalıbı** (D8): `has the Poisoned condition` → `Zehirlenme durumundadır` ·
   `is Prone` → `yere düşme durumundadır`.
10. **creature → varlık**, **monster → canavar**, **object → nesne** (rehberin kural dili).
11. **Katkı/ceza** (BG:EE): `+2 bonus to AC` → `Zırh Sınıfı'na +2 katkı`; `−5 penalty` → `−5 ceza`.
12. **Markdown aynen** (K6): `**…**`, `*…*`, madde işaretleri, tablo satırları aynı sayıda kalır;
    sadece içleri çevrilir.

---

## 3. Temel kural terimleri

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Ability | Kabiliyet | B |
| Ability Score | Kabiliyet Skoru | B~ |
| Ability Modifier / modifier | Kabiliyet Katkısı / katkı | B~ |
| Ability Check | Kabiliyet Zarı | B~ |
| Saving Throw | Kurtarma Zarı | B |
| Death Saving Throw | Ölüm Kurtarma Zarı | B~ |
| Attack Roll | Saldırı Zarı | R |
| Damage Roll | Hasar Zarı | R |
| Melee Attack Roll | Yakın Dövüş Saldırı Zarı | R~ |
| Ranged Attack Roll | Menzilli Saldırı Zarı | R~ |
| D20 Test | d20 Testi | Ö |
| Advantage | Avantaj | R |
| Disadvantage | Dezavantaj | R |
| Proficiency | Yetkinlik | B |
| Proficiency Bonus | Yetkinlik Katkısı | B~ |
| proficient | yetkin | B |
| Expertise | Uzmanlık | B |
| Skill | Yetenek | B |
| Difficulty Class (DC) | DC (Zorluk Sınıfı) | R |
| Armor Class (AC) | Zırh Sınıfı | B (BG3) |
| Hit Points (HP) | Can Puanı | B |
| Hit Point Maximum | Azami Can Puanı | B~ |
| Temporary Hit Points | Geçici Can Puanı | B~ |
| Hit Die / Hit Dice / Hit Point Dice | Can Zarı | B |
| Initiative | Öncelik | R |
| Surprise | Sürpriz | R |
| Round | Raunt | B |
| Turn | Tur | B |
| Action | Eylem | R |
| Bonus Action | Bonus Eylem | R |
| Reaction | Reaksiyon | R |
| Opportunity Attack | Fırsat Saldırısı | R |
| Unarmed Strike | Silahsız Darbe | R |
| Critical Hit | Kritik İsabet | B |
| Melee | Yakın Dövüş | R |
| Ranged | Menzilli | R |
| reach | erişim | R |
| range | menzil | R |
| Hit: | Vuruş: | Ö |
| Miss: | Iska: | R~ |
| Failure: | Başarısızlık: | R~ |
| Success: | Başarı: | R~ |
| Speed | Hız | R |
| Difficult Terrain | Zorlu Arazi | R |
| Resistance | Direnç | R |
| Immunity | Bağışıklık | R |
| Vulnerability | Zayıflık | R |
| Spell | Büyü | R |
| cast (a spell) | (büyü) yapmak / kullanmak | R |
| Cantrip | Cantrip | R |
| Spell Slot | Büyü Yuvası | R |
| Spellcasting | Büyü Yapma | R |
| Spellcasting Ability | Büyü Yapma Kabiliyeti | D11 |
| Spellcasting Focus | Büyü Yapma Odağı | R |
| Spell Save DC | Büyü Kurtarma DC'si | B~ |
| Spell Attack | Büyü Saldırısı | R |
| Casting Time | Büyü Yapma Süresi | B |
| Duration | Etki Süresi | B |
| Touch (menzil) | Temas | B |
| Area of Effect | Etki Alanı | B |
| bonus | katkı | B |
| penalty | ceza | B |
| Concentration | Konsantrasyon | R |
| Ritual | Ritüel | R |
| Using a Higher-Level Spell Slot | Daha Yüksek Seviyeli Büyü Yuvası Kullanma | Ö |
| Cantrip Upgrade | Cantrip Gelişimi | Ö |
| Short Rest | Kısa Dinlenme | R |
| Long Rest | Uzun Dinlenme | R |
| Stable | Stabil | R |
| creature | varlık | R |
| monster | canavar | R |
| object | nesne | R |
| Class | Sınıf | R |
| Subclass | Alt Sınıf | R~ |
| Species | Tür | Ö (rehber: Irk; 5.2.1 "Race"ı "Species" yaptı, arayüz "Tür" kullanıyor) |
| Background | Geçmiş | R |
| Feat | Hüner | R |
| Origin Feat | Köken Hüneri | Ö |
| Epic Boon | Destansı Lütuf | Ö |
| Feature | Özellik | R |
| Trait (canavar/tür niteliği) | Nitelik | Ö (arayüz "Nitelikler") |
| Level / Character Level | Seviye / Karakter Seviyesi | R |
| Experience Points (XP) | Tecrübe Puanı (XP) | B~ |
| Challenge Rating (CR) | CR | R |
| Multiclassing | Çoklu Sınıf | B |
| Ability Score Improvement | Kabiliyet Skoru Gelişimi | B~ |
| Heroic Inspiration | Kahramanca İlham | Ö |
| Bloodied | Kanlı | Ö |
| Weapon Mastery | Silah Ustalığı | B~ (BG:EE "Silah Ustalıkları"; arayüzle aynı) |
| Emanation | Yayılım | Ö |
| Lightly Obscured | Hafifçe Örtülü | R |
| Heavily Obscured | Yoğun Örtülü | R |
| Passive Perception | Pasif Algı | R~ |
| Multiattack | Çoklu Saldırı | R |
| Legendary Action | Efsanevi Eylem | Ö |
| Legendary Resistance | Efsanevi Direnç | Ö |
| Recharge | Yenilenme | Ö |
| Shapechanger | Şekildeğiştiren | R |
| Telepathy | Telepati | Ö |
| Attunement | Uyumlanma | Ö |
| charges | kullanım | B |
| Escape DC | Kaçış DC'si | Ö |
| Tier of Play | Oyun Aşaması | R |

---

## 4. Tier-0 sözlük kategorileri

`character-state` ve `resource-pool` satır adları makine kimliğidir (`state:raging`, `pool:rage_uses`),
**çevrilmez** (K10); bunların `label` alanı dalga 5.1'de bu sözlükle çevrilir.

### 4.1 ability — Kabiliyet

| İngilizce | Türkçe | Kısaltma | Kaynak |
|---|---|---|---|
| Strength | Kuvvet | STR → KUV | R (kısaltma R~: rehber "Kuv") |
| Dexterity | Çeviklik | DEX → ÇEV | R (kısaltma R~: rehber "Çev") |
| Constitution | Dayanıklılık | CON → DAY | R (kısaltma Ö) |
| Intelligence | Zeka | INT → ZEK | R (kısaltma Ö) |
| Wisdom | İrfan | WIS → İRF | B (kısaltma Ö) |
| Charisma | Karizma | CHA → KAR | R (kısaltma Ö) |

### 4.2 skill — Yetenek

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Acrobatics | Akrobasi | R |
| Animal Handling | Hayvan İdaresi | R |
| Arcana | Arcana | R |
| Athletics | Atletizm | R |
| Deception | Aldatma | R |
| History | Tarih | R |
| Insight | Sezgi | R |
| Intimidation | Gözdağı | R |
| Investigation | İnceleme | R |
| Medicine | Tıp | R |
| Nature | Doğa | R |
| Perception | Algı | R |
| Performance | Performans | R |
| Persuasion | İkna | R |
| Religion | Din | R |
| Sleight of Hand | El Çabukluğu | R |
| Stealth | Gizlilik | B |
| Survival | Hayatta Kalma | R |

### 4.3 damage-type — Hasar Türü

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Acid | Asit | R |
| Bludgeoning | Ezici | B |
| Cold | Soğuk | R |
| Fire | Ateş | R |
| Force | Güç | R |
| Lightning | Yıldırım | R |
| Necrotic | Nekrotik | R |
| Piercing | Delici | B |
| Poison | Zehir | R |
| Psychic | Psişik | R |
| Radiant | Radyant | R |
| Slashing | Kesici | B |
| Thunder | Ses | R |

### 4.4 condition — Durum (D8)

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Blinded | Körlük | R |
| Charmed | Cezbedilme | R |
| Deafened | Sağırlık | R |
| Exhaustion | Bitkinlik | R |
| Frightened | Korkma | R |
| Grappled | Yakalanma | R |
| Incapacitated | Etkisiz Hal | R |
| Invisible | Görünmezlik | R |
| Paralyzed | Felç | R |
| Petrified | Taşa Dönme | R |
| Poisoned | Zehirlenme | R |
| Prone | Yere Düşme | R |
| Restrained | Kısıtlanma | R |
| Stunned | Sersemleme | R |
| Unconscious | Bilinçsizlik | R |

### 4.5 creature-type — Yaratık Tipi

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Aberration | Aberasyon | R~ |
| Beast | Hayvan | R~ |
| Celestial | Kutsal | R~ |
| Construct | Yapı | R~ |
| Dragon | Ejderha | R~ |
| Elemental | Elemental | R~ |
| Fey | Fey | R~ |
| Fiend | Zebani | B |
| Giant | Dev | R~ |
| Humanoid | İnsansı | B |
| Monstrosity | Canavar | R~ |
| Ooze | Vıcık | B |
| Plant | Bitki | R~ |
| Undead | Hortlak | B |

> Dikkat: `Monstrosity` ile `monster` ikisi de **canavar**. Scope ayrımı tablo eşlemesini korur;
> metin içinde bağlamdan anlaşılır. (`Huge` artık **Kocaman** olduğu için `Giant` = **Dev** çakışmaz.)

### 4.6 language — Dil

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Common | Ortak | R |
| Common Sign Language | Ortak İşaret Dili | Ö |
| Draconic | Draconic | R |
| Dwarvish | Cücece | R |
| Elvish | Elfçe | R |
| Giant | Devce | R |
| Gnomish | Gnomish | R |
| Goblin | Goblince | R |
| Halfling | Buçuklukça | R |
| Orc | Orkça | R |
| Abyssal | Abyssal | R |
| Celestial | Celestial | R |
| Deep Speech | Derin Dil | R |
| Druidic | Druidic | R |
| Infernal | Infernal | R |
| Primordial | Primordial | R |
| Sylvan | Sylvan | R |
| Thieves' Cant | Hırsız Argosu | R |
| Undercommon | Alt Ortak | R |

### 4.7 weapon-property — Silah Özelliği

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Ammunition | Cephane | R |
| Finesse | Beceri | R |
| Heavy | Ağır | R |
| Light | Hafif | R |
| Loading | Kurmalı | R |
| Range | Menzil | R |
| Reach | Erişim | R |
| Thrown | Fırlatma | R |
| Two-Handed | Çift El | R |
| Versatile | Değişken | R |
| Improvised | Doğaçlama | R~ |

### 4.8 weapon-mastery — Silah Ustalığı (tamamı 5.2.1'e özgü)

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Cleave | Yarma | Ö |
| Graze | Sıyırma | Ö |
| Nick | Çentik | Ö |
| Push | İtme | Ö |
| Sap | Zayıflatma | Ö |
| Slow | Yavaşlatma | Ö |
| Topple | Devirme | Ö |
| Vex | Bezdirme | Ö |

### 4.9 spell-school — Büyü Okulu (BG:EE)

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Abjuration | Sakınma | B |
| Conjuration | Çağırma | B |
| Divination | Kehanet | B |
| Enchantment | Efsunlama | B |
| Evocation | Oluşturma | B |
| Illusion | Yanılsama | B |
| Necromancy | Ölüm İlmi | B |
| Transmutation | Başkalaşım | B (BG:EE "Alteration") |

### 4.10 magic-item-category — Büyülü Eşya Kategorisi

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Armor | Zırh | R~ |
| Potions | İksirler | R~ |
| Rings | Yüzükler | Ö |
| Rods | Bastonlar | B~ |
| Scrolls | Tomarlar | R~ |
| Staffs | Asalar | D10 |
| Wands | Değnekler | D10 |
| Weapons | Silahlar | R~ |
| Wondrous Items | Harikulade Eşyalar | Ö |

### 4.11 sense — Duyu

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Blindsight | Kör Görüş | R |
| Darkvision | Gece Görüşü | R |
| Tremorsense | Titreşim Hissi | Ö |
| Truesight | Özgörü | B |

### 4.12 hazard — Tehlike

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Burning | Yanma | Ö |
| Dehydration | Susuzluk | R~ |
| Falling | Düşme | R |
| Malnutrition | Açlık | R~ |
| Suffocation | Boğulma | R |

### 4.13 arcane-focus · druidic-focus · holy-symbol

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Crystal | Kristal | R |
| Orb | Küre | R |
| Rod | Baston | B |
| Staff | Asa | D10 |
| Wand | Değnek | D10 |
| Sprig of Mistletoe | Ökseotu Filizi | R |
| Wooden Staff | Ahşap Asa | D10 |
| Yew Wand | Porsuk Ağacından Değnek | D10 |
| Amulet | Muska | B |
| Emblem | Sembol | R |
| Reliquary | Röliker | R |

### 4.14 size — Boy

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Tiny | Minik | B |
| Small | Küçük | R |
| Medium | Orta Boy | B |
| Large | Büyük | R |
| Huge | Kocaman | B |
| Gargantuan | Devasa | B |

### 4.15 rarity — Nadirlik

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Common | Yaygın | R~ |
| Uncommon | Sıradışı | Ö |
| Rare | Nadir | R~ |
| Very Rare | Çok Nadir | Ö |
| Legendary | Efsanevi | Ö |
| Artifact | Yadigâr | B |

### 4.16 coin — Para

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Copper | Bakır (bakır pare, cp) | R |
| Silver | Gümüş (gümüş pare, sp) | R |
| Electrum | Elektrum (elektrum pare, ep) | R |
| Gold | Altın (altın pare, gp) | R |
| Platinum | Platin (platin pare, pp) | R |

### 4.17 lifestyle — Yaşam Tarzı

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Wretched | Acınası | R |
| Squalid | Sefil | R |
| Poor | Fakir | R |
| Modest | Mütevazı | R |
| Comfortable | Konforlu | R |
| Wealthy | Zengin | R |
| Aristocratic | Aristokrat | R |

### 4.18 duration-unit · casting-time-unit

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Instantaneous | Anlık | R |
| Rounds | Raunt | B |
| Minutes / Minute | Dakika | R |
| Hours / Hour | Saat | R |
| Days | Gün | R |
| Special | Özel | R |
| Until Dispelled | Defedilene Kadar | R~ |
| Action | Eylem | R |
| Bonus Action | Bonus Eylem | R |
| Reaction | Reaksiyon | R |
| Ritual | Ritüel | R |

### 4.19 body-slot — Vücut Yuvası

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Head | Baş | Ö |
| Eyes | Gözler | Ö |
| Neck | Boyun | Ö |
| Shoulders | Omuzlar | Ö |
| Body | Beden | Ö |
| Arms | Kollar | Ö |
| Hands | Eller | Ö |
| Finger | Parmak | Ö |
| Waist | Bel | Ö |
| Feet | Ayaklar | Ö |
| None | Yok | Ö |

### 4.20 alignment — Yönelim

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Lawful Good | Kuralcı İyi | B |
| Neutral Good | Tarafsız İyi | B |
| Chaotic Good | Kaotik İyi | B |
| Lawful Neutral | Kuralcı Tarafsız | B |
| Neutral | Tarafsız | B~ (BG:EE "True Neutral" = Gerçek Tarafsız) |
| Chaotic Neutral | Kaotik Tarafsız | B |
| Lawful Evil | Kuralcı Kötü | B |
| Neutral Evil | Tarafsız Kötü | B |
| Chaotic Evil | Kaotik Kötü | B |
| Unaligned | Yönelimsiz | Ö |

### 4.21 weapon-category · armor-category · tool-category

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Simple | Basit | R |
| Martial | Askeri | R |
| Simple Melee | Basit Yakın Dövüş | R |
| Simple Ranged | Basit Menzilli | R |
| Martial Melee | Askeri Yakın Dövüş | R |
| Martial Ranged | Askeri Menzilli | R |
| Light (zırh) | Hafif | R |
| Medium (zırh) | Orta | R |
| Heavy (zırh) | Ağır | R |
| Shield | Kalkan | R |
| Artisan's Tools | Zanaatkar Aletleri | R |
| Gaming Set | Oyun Seti | R |
| Musical Instrument | Müzik Enstrümanı | R |
| Other Tools | Diğer Aletler | R~ |

### 4.22 feat-category — Hüner Kategorisi

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Origin | Köken | Ö |
| General | Genel | Ö |
| Fighting Style | Dövüş Stili | R |
| Epic Boon | Destansı Lütuf | Ö |
| Class Feature | Sınıf Özelliği | R |
| Subclass Feature | Alt Sınıf Özelliği | R~ |
| Species Feature | Tür Özelliği | Ö |
| Divine Order | İlahi Düzen | Ö (arayüzle aynı) |
| Primal Order | İlkel Düzen | Ö |
| Feature Option: … | Özellik Seçeneği: … | Ö |

### 4.23 action — Eylem

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Action | Eylem | R |
| Bonus Action | Bonus Eylem | R |
| Reaction | Reaksiyon | R |
| Free Action | Serbest Eylem | Ö |
| Magic Action | Büyü Eylemi | Ö |
| Attack Action | Saldırı Eylemi | R |
| Dash | Depar | R |
| Dodge | Kaçınma | R |
| Disengage | Ayrılma | R |
| Help | Yardım | R |
| Hide | Gizlenme | R |
| Ready | Hazırla | R |
| Search | Arama | R |
| Influence | Etkileme | Ö |
| Study | Araştırma | Ö |
| Utilize | Nesne Kullanma | R~ |

### 4.24 area-shape — Alan Şekli

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Cone | Koni | R |
| Cube | Küp | R |
| Cylinder | Silindir | R |
| Line | Hat | R |
| Sphere | Küre | R |
| Emanation | Yayılım | Ö |

### 4.25 attitude · illumination · travel-pace · cover

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Friendly | Dost | R~ |
| Indifferent | Barışçıl | B |
| Hostile | Düşman | B |
| Bright | Parlak Işık | R~ |
| Dim | Loş Işık | R~ |
| Darkness | Karanlık | R |
| Slow (tempo) | Yavaş | R |
| Normal | Normal | R |
| Fast | Hızlı | R |
| Half Cover | Yarı Siper | R |
| Three-Quarters Cover | Üç Çeyrek Siper | R |
| Total Cover | Tam Siper | R |

### 4.26 plane — Düzlem (BG:EE: "Ateş Düzlemi", "Gölge Düzlemi")

Dış düzlemlerin özel adları aynen kalır: Mount Celestia · Bytopia · Elysium · Beastlands ·
Arborea · Ysgard · Limbo · Pandemonium · Abyss · Carceri · Hades · Gehenna · Acheron · Mechanus ·
Arcadia · Outlands · Feywild · Shadowfell

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Material Plane | Materyal Düzlem | B~ |
| Astral Plane | Astral Düzlem | B~ |
| Ethereal Plane | Ethereal Düzlem | B~ |
| Plane of Air | Hava Düzlemi | B~ |
| Plane of Earth | Toprak Düzlemi | B~ |
| Plane of Fire | Ateş Düzlemi | B |
| Plane of Water | Su Düzlemi | B~ |
| Nine Hells | Dokuz Cehennem | Ö |

### 4.27 casting-component · speed-type · tier-of-play

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Verbal (V) | Sözlü (S) | R |
| Somatic (S) | Bedensel (B) | R |
| Material (M) | Materyal (M) | R |
| Walk | Yürüme | R |
| Burrow | Kazma | Ö |
| Climb | Tırmanma | R |
| Fly | Uçma | R |
| Swim | Yüzme | R |
| Local Heroes | Yerel Kahramanlar | Ö |
| Heroes of the Realm | Diyarın Kahramanları | Ö |
| Masters of the Realm | Diyarın Efendileri | Ö |
| Masters of the World | Dünyanın Efendileri | Ö |

> Bileşen kısaltmaları rehberde **S/B/M**'dir (V/S/M değil). Yalnızca görüntülemede; veri `V, S, M`
> kalır (K3).

---

## 5. Sınıf, alt sınıf, tür, geçmiş

### 5.1 class — Sınıf (D4 — BG3/BG:EE)

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Barbarian | Barbar | B |
| Bard | Ozan | B |
| Cleric | Ruhban | B |
| Druid | Druid | B |
| Fighter | Dövüşçü | B |
| Monk | Keşiş | B |
| Paladin | Paladin | B |
| Ranger | Kolcu | B (BG3; BG:EE "Korucu") |
| Rogue | Düzenbaz | B |
| Sorcerer | Sihirbaz | B |
| Warlock | Sehhar | B (BG3) |
| Wizard | Büyücü | B |

### 5.2 subclass — Alt Sınıf

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Path of the Berserker | Başıbozuğun Yolu | B~ (BG:EE: Berserker = Başıbozuk) |
| College of Lore | Bilgi Koleji | R |
| Life Domain | Yaşam Alanı | R |
| Circle of the Land | Toprak Çemberi | R |
| Champion | Şampiyon | R |
| Warrior of the Open Hand | Açık Elin Savaşçısı | R~ (2014: Açık Elin Yolu) |
| Oath of Devotion | Bağlılık Yemini | R |
| Hunter | Avcı | R |
| Thief | Hırsız | B |
| Draconic Sorcery | Ejderha Sihirbazlığı | B~ |
| Fiend Patron | Zebani Efendi | R~ (rehber: patron → Efendi) |
| Evoker | Oluşturucu | B (BG:EE: Invoker) |

### 5.3 species · subspecies — Tür · Alt Tür

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Dragonborn | Ejderdoğan | R |
| Dwarf | Cüce | R |
| Elf | Elf | R |
| Gnome | Gnom | B |
| Goliath | Goliath | Ö |
| Half-Elf | Yarı-Elf | B |
| Halfling | Buçukluk | B |
| Human | İnsan | R |
| Orc | Ork | R |
| Tiefling | Tiefling | Ö |
| High Elf | Ulu Elf | R |
| Drow | Drow | B |
| Wood Elf | Orman Elfi | R |
| Hill Dwarf | Tepe Cücesi | R~ |
| Mountain Dwarf | Dağ Cücesi | R |
| Forest Gnome | Orman Gnomu | B~ |
| Rock Gnome | Kaya Gnomu | B |
| Lightfoot Halfling | Hafifayak Buçukluk | Ö |
| Stout Halfling | Gürbüz Buçukluk | Ö |
| Standard Human | Standart İnsan | Ö |
| Half-Orc | Yarı-Ork | B |
| Abyssal / Chthonic / Infernal Tiefling | Abyssal / Chthonic / Infernal Tiefling | Ö |
| Cloud / Fire / Frost / Hill / Stone / Storm Giant | Bulut / Ateş / Ayaz / Tepe / Taş / Fırtına Devi | Ö |
| Black / Blue / Brass / Bronze / Copper Dragonborn | Siyah / Mavi / Pirinç / Bronz / Bakır Ejderdoğan | Ö |
| Gold / Green / Red / Silver / White Dragonborn | Altın / Yeşil / Kırmızı / Gümüş / Beyaz Ejderdoğan | Ö |

### 5.4 background — Geçmiş (rehberde 5.2.1 geçmişleri yok)

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Acolyte | Mürit | Ö |
| Artisan | Zanaatkar | R~ |
| Charlatan | Şarlatan | Ö |
| Criminal | Suçlu | Ö |
| Entertainer | Eğlendirici | Ö |
| Farmer | Çiftçi | Ö |
| Guard | Muhafız | Ö |
| Guide | Rehber | Ö |
| Hermit | Münzevi | Ö |
| Merchant | Tüccar | R~ |
| Noble | Soylu | R~ |
| Sage | Bilge | R~ |
| Sailor | Denizci | Ö |
| Scribe | Katip | R~ |
| Soldier | Asker | Ö |
| Wayfarer | Gezgin | Ö |

---

## 6. Sınıf ve alt sınıf özellikleri

Parantez içi nitelikler §2 kural 7'ye göre çevrilir; tabloda yalnızca temel adlar var.

### 6.1 Sınıf özellikleri

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Rage | Hiddet | B (BG:EE "Barbar Hiddeti") |
| Unarmored Defense | Zırhsız Savunma | R |
| Danger Sense | Tehlike Hissi | R |
| Reckless Attack | Pervasız Saldırı | R |
| Primal Knowledge | İlkel Bilgi | Ö |
| Extra Attack | Ekstra Saldırı | R~ (D9) |
| Two Extra Attacks / Three Extra Attacks | İki Ekstra Saldırı / Üç Ekstra Saldırı | R~ (D9) |
| Fast Movement | Hızlı Hareket | R |
| Feral Instinct | Vahşi İçgüdü | R |
| Instinctive Pounce | İçgüdüsel Atılış | Ö |
| Brutal Strike | Acımasız Vuruş | R~ (2014: Acımasız Kritik) |
| Relentless Rage | Amansız Hiddet | B~ |
| Persistent Rage | Kalıcı Hiddet | B~ |
| Indomitable Might | Yılmaz Kuvvet | R |
| Primal Champion | İlkel Şampiyon | R |
| Bardic Inspiration | Ozan İlhamı | R |
| Superior Bardic Inspiration | Üstün Ozan İlhamı | R~ (rehber: Üstün İlham) |
| Jack of All Trades | Her İşten Anlar | R |
| Font of Inspiration | İlham Kaynağı | R |
| Countercharm | Karşı Cazibe | R |
| Magical Secrets | Büyülü Sırlar | R |
| Words of Creation | Yaratılış Sözleri | Ö |
| Expertise | Uzmanlık | B |
| `<Class>` Spellcasting | `<Sınıf>` Büyü Yapma | R~ |
| Channel Divinity | Kutsal Yönlendirme | R |
| Sear Undead | Hortlakları Dağla | B~ |
| Blessed Strikes | Kutsanmış Darbeler | Ö |
| Divine Intervention | Kutsal Müdahale | R |
| Greater Divine Intervention | Büyük Kutsal Müdahale | R~ |
| Wild Shape | Yabani Şekil | R |
| Wild Companion | Yabani Yoldaş | Ö |
| Wild Resurgence | Yabani Diriliş | Ö |
| Improved Elemental Fury | Gelişmiş Elemental Hiddet | Ö |
| Beast Spells | Hayvan Büyüleri | R |
| Archdruid | Baş Druid | R |
| Second Wind | Soluklan | R |
| Action Surge | Eylem Taşması | R |
| Tactical Mind | Taktik Zihin | Ö |
| Tactical Shift | Taktik Kayma | Ö |
| Indomitable | Yenilmez | R |
| Studied Attacks | İncelenmiş Saldırılar | Ö |
| Martial Arts | Dövüş Sanatları | R |
| Monk's Focus | Keşişin Odağı | Ö (2014: Ki) |
| Unarmored Movement | Zırhsız Hareket | R |
| Flurry of Blows | Darbe Yağmuru | R |
| Patient Defense | Sabırlı Savunma | R |
| Step of the Wind | Rüzgarın Adımı | R |
| Deflect Attacks | Saldırıları Saptır | R~ (2014: Misilleri Saptır) |
| Deflect Energy | Enerjiyi Saptır | Ö |
| Slow Fall | Yavaş Düşüş | R |
| Stunning Strike | Sersemleten Darbe | B |
| Empowered Strikes | Güçlendirilmiş Vuruşlar | R~ (2014: Ki Etkili Vuruşlar) |
| Evasion | Sıyrılma | R |
| Acrobatic Movement | Akrobatik Hareket | Ö |
| Perfect Focus | Kusursuz Odak | Ö |
| Superior Defense | Üstün Savunma | Ö |
| Body and Mind | Beden ve Zihin | Ö |
| Lay On Hands | Şifalı El | B |
| Paladin's Smite | Paladinin Çarpması | R~ (2014: Kutsal Çarpma) |
| Faithful Steed | Sadık Binek | Ö |
| Aura of Protection | Koruma Aurası | R |
| Abjure Foes | Düşmanları Kov | Ö |
| Radiant Strikes | Radyant Darbeler | Ö |
| Restoring Touch | Onaran Dokunuş | Ö |
| Aura Expansion | Aura Genişlemesi | R~ |
| Favored Enemy | Kayrılan Düşman | R |
| Deft Explorer | Becerikli Kaşif | R~ (2014: Doğal Kaşif) |
| Roving | Gezginlik | Ö |
| Tireless | Yorulmaz | Ö |
| Relentless Hunter | Amansız Avcı | Ö |
| Nature's Veil | Doğanın Örtüsü | Ö |
| Feral Senses | Yabani Hisler | R |
| Foe Slayer | Düşman Katili | R |
| Sneak Attack | Sinsi Saldırı | R |
| Cunning Action | Kurnaz Eylem | R |
| Steady Aim | Sabit Nişan | Ö |
| Cunning Strike | Kurnaz Vuruş | Ö |
| Improved Cunning Strike | Gelişmiş Kurnaz Vuruş | Ö |
| Devious Strikes | Hilekar Vuruşlar | Ö |
| Uncanny Dodge | Olağanüstü Kaçınma | R |
| Reliable Talent | Güvenilir Beceri | R |
| Slippery Mind | Kaygan Zihin | R |
| Elusive | Kaçamak | R |
| Stroke of Luck | Şanslı Vuruş | R |
| Innate Sorcery | Doğuştan Sihirbazlık | B~ |
| Font of Magic | Büyü Kaynağı | R |
| Sorcery Points | Sihirbazlık Puanları | B~ |
| Metamagic | Metabüyü | R |
| Sorcerous Restoration | Sihirbaz Yenilemesi | B~ |
| Sorcery Incarnate | Vücut Bulmuş Sihirbazlık | B~ |
| Arcane Apotheosis | Arcane Yücelme | Ö |
| Pact Magic | Ahit Büyüsü | R |
| Magical Cunning | Büyülü Kurnazlık | Ö |
| Mystic Arcanum | Mistik Sır | R |
| Eldritch Master | Eldritch Üstadı | R |
| Eldritch Resilience | Eldritch Dayanıklılığı | Ö |
| Eldritch Invocations | Eldritch Yakarışları | R |
| Pact Boon | Ahit Lütfu | R |
| Ritual Adept | Ritüel Ustası | Ö |
| Arcane Recovery | Arcane Yenilenme | R |
| Memorize Spell | Büyü Ezberle | Ö |
| Spell Mastery | Büyü Ustalığı | B~ (Mastery = Usta; Uzmanlık artık Expertise) |
| Signature Spells | İmza Büyüler | R |
| Weapon Mastery | Silah Ustalığı | B~ |
| Improved `<X>` | Gelişmiş `<X>` | R |
| Protector / Thaumaturge (Divine Order) | Koruyucu / Mucizeci | Ö |
| Warden / Magician (Primal Order) | Bekçi / Büyübaz | Ö (Sihirbaz = Sorcerer olduğu için) |

### 6.2 Alt sınıf özellikleri

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Frenzy | Çıldırma | R |
| Mindless Rage | Akılsız Hiddet | B~ |
| Retaliation | İntikam | R |
| Intimidating Presence | Korkutucu Görünüş | R |
| Bonus Proficiencies | Bonus Yetkinlikler | B~ |
| Cutting Words | Keskin Sözler | R |
| Magical Discoveries | Büyülü Keşifler | Ö (2014: Fazladan Büyülü Sırlar) |
| Peerless Skill | Emsalsiz Yetenek | B~ (Skill = Yetenek) |
| Disciple of Life | Yaşam Müridi | R |
| Preserve Life | Yaşamı Koru | R |
| Blessed Healer | Kutsanmış Şifacı | R |
| Supreme Healing | Üstün İyileştirme | R |
| Circle Spells | Çember Büyüleri | R |
| Land's Aid | Toprağın Yardımı | Ö |
| Natural Recovery | Doğal Yenilenme | R |
| Nature's Ward | Doğanın Kalkanı | R |
| Nature's Sanctuary | Doğanın Mabedi | R |
| Improved Critical | Gelişmiş Kritik | R |
| Remarkable Athlete | Fevkalade Atlet | R |
| Additional Fighting Style | Ek Dövüş Stili | R |
| Superior Critical | Üstün Kritik | R |
| Survivor | Hayatta Kalan | R |
| Open Hand Technique | Açık El Tekniği | R |
| Wholeness of Body | Bedenin Bütünlüğü | R |
| Fleet Step | Çevik Adım | Ö |
| Quivering Palm | Titreşen Avuç | B |
| Sacred Weapon | Kutsal Silah | Ö |
| Aura of Devotion | Bağlılık Aurası | R |
| Smite of Protection | Koruma Çarpması | Ö |
| Holy Nimbus | Kutsal Bulut | R |
| Hunter's Lore | Avcının Bilgisi | Ö |
| Hunter's Prey | Avcının Avı | R |
| Defensive Tactics | Savunma Taktikleri | R |
| Superior Hunter's Defense | Üstün Avcının Savunması | R |
| Multiattack (Avcı seçeneği) | Çoklu Saldırı | R |
| Fast Hands | Çabuk Eller | R |
| Second-Story Work | İkinci Kat İşi | R |
| Supreme Sneak | Üstün Gizlenme | R |
| Use Magic Device | Büyülü Alet Kullan | R |
| Thief's Reflexes | Hırsız Refleksleri | R |
| Draconic Resilience | Draconic Direnç | R |
| Draconic Spells | Draconic Büyüler | Ö |
| Draconic Ancestor | Ejderha Ata | R |
| Elemental Affinity | Elemental Yakınlık | R |
| Dragon Wings | Ejderha Kanatları | R |
| Dragon Companion | Ejderha Yoldaş | Ö |
| Draconic Presence | Draconic Varoluş | R |
| Dark One's Blessing | Karanlık Olanın Kutsaması | R |
| Dark One's Own Luck | Karanlık Olanın Kendi Şansı | R |
| Fiendish Resilience | Zebani Direnci | R |
| Hurl Through Hell | Cehenneme Yolla | R |
| Evocation Savant | Oluşturma Bilgini | B~ |
| Potent Cantrip | Güçlü Cantrip | R |
| Sculpt Spells | Büyüleri Şekillendir | R |
| Empowered Evocation | Güçlenmiş Oluşturma | B~ |
| Overchannel | Aşırı Yönlendir | R |

### 6.3 Seçenekler (Feature Option)

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Colossus Slayer | Cüsse Düşmanı | R |
| Horde Breaker | Ordu Kıran | R |
| Escape the Horde | Ordudan Kaç | R |
| Multiattack Defense | Çoklu Saldırı Savunması | R |
| Steel Will | Çelik İrade | R |
| Volley | Yaylım Ateşi | R |
| Whirlwind Attack | Kasırga Saldırısı | R |
| Stand Against the Tide | Akıntıya Karşı Dur | R |
| Careful Spell | Dikkatli Büyü | R |
| Distant Spell | Uzak Büyü | R |
| Empowered Spell | Güçlenmiş Büyü | R |
| Extended Spell | Uzatılmış Büyü | R |
| Heightened Spell | Yükseltilmiş Büyü | R |
| Quickened Spell | Hızlanmış Büyü | R |
| Seeking Spell | Arayan Büyü | Ö |
| Subtle Spell | Sinsi Büyü | R |
| Transmuted Spell | Dönüştürülmüş Büyü | Ö |
| Twinned Spell | İkiz Büyü | R |
| Agonizing Blast | Istıraplı Patlama | R |
| Armor of Shadows | Gölgelerin Zırhı | R |
| Devil's Sight | Şeytanın Görüşü | R |
| Eldritch Mind | Eldritch Zihin | Ö |
| Eldritch Sight | Eldritch Görüşü | R |
| Eldritch Spear | Eldritch Mızrağı | R |
| Fiendish Vigor | Şeytani Dinçlik | R |
| Gaze of Two Minds | İki Zihnin Bakışı | R |
| Mask of Many Faces | Çok Yüzün Maskesi | R |
| Misty Visions | Sisli Görüler | R |
| One with Shadows | Gölgelerle Bir | R |
| Repelling Blast | İtici Patlama | R |
| Pact of the Blade | Kılıcın Ahdi | R |
| Pact of the Chain | Zincirin Ahdi | R |
| Pact of the Tome | Yazıtın Ahdi | R |

### 6.4 Dövüş Stilleri

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Archery | Okçuluk | R |
| Blind Fighting | Kör Dövüş | Ö |
| Defense | Savunma | R |
| Dueling | Düello | R |
| Great Weapon Fighting | Büyük Silahla Savaşma | R |
| Interception | Araya Girme | Ö |
| Protection | Koruma | R |
| Thrown Weapon Fighting | Fırlatma Silahıyla Dövüşme | Ö |
| Two-Weapon Fighting | Çift Silahla Dövüşme | R |
| Unarmed Fighting | Silahsız Dövüşme | Ö |

---

## 7. Ekipman (BG:EE ve rehberde karşılığı olanlar)

Macera tertibatı (107 satır) dalga 5.3'te rehberin "Macera Tertibatı" tablosu kaynak alınarak
çevrilir; burada yalnızca rehberin doğrudan kapsadığı gruplar var.

### 7.1 weapon — Silah

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Club | Sopa | R |
| Dagger | Hançer | R |
| Greatclub | Büyük Sopa | R |
| Handaxe | El Baltası | R |
| Javelin | Cirit | R |
| Light Hammer | Hafif Çekiç | R |
| Mace | Gürz | R |
| Quarterstaff | Dövüş Sopası | B |
| Sickle | Orak | R |
| Spear | Mızrak | R |
| Dart | Dart | R |
| Light Crossbow | Hafif Kurmalı Yay | B |
| Shortbow | Kısa Yay | R |
| Sling | Sapan | R |
| Battleaxe | Savaş Baltası | R |
| Flail | Zincirli Topuz | B |
| Glaive | Kılıçlı Kargı | R |
| Greataxe | Büyük Balta | R |
| Greatsword | Çift-el Kılıcı | B (Two-handed Sword) |
| Halberd | Teber | B |
| Lance | Süvari Mızrağı | R |
| Longsword | Uzun Kılıç | R |
| Maul | Tokmak | R |
| Morningstar | Seher Yıldızı | B |
| Pike | Kargı | R |
| Rapier | Epe | B |
| Scimitar | Pala | R |
| Shortsword | Kısa Kılıç | R |
| Trident | Üç Dişli Mızrak | R |
| Warhammer | Savaş Çekici | R |
| War Pick | Savaş Kazması | R |
| Whip | Kırbaç | R |
| Blowgun | Dart Borusu | R |
| Hand Crossbow | El Kurmalı Yayı | B~ |
| Heavy Crossbow | Ağır Kurmalı Yay | B |
| Longbow | Uzun Yay | R |
| Musket | Misket Tüfeği | Ö (BG:EE'de Misket = sapan mermisi) |
| Pistol | Tabanca | Ö |

### 7.2 armor — Zırh

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Padded Armor | Dolgu Zırh | R |
| Leather Armor | Deri Zırh | R |
| Studded Leather Armor | Perçinli Deri Zırh | R |
| Hide Armor | Post Zırh | R |
| Chain Shirt | Örme Gömlek | R |
| Scale Mail | Pullu Zırh | R |
| Breastplate | Göğüslük | R |
| Half Plate Armor | Yarı Plaka Zırh | R |
| Ring Mail | Halka Örme Zırh | R |
| Chain Mail | Zincir Zırh | B |
| Splint Armor | Geçmeli Zırh | B |
| Plate Armor | Plaka Zırh | R |
| Shield | Kalkan | R |

### 7.3 ammunition · pack

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Arrows | Oklar | R~ |
| Bolts | Kısa Oklar | B~ |
| Bullets, Firearm | Mermi, Ateşli Silah | Ö |
| Bullets, Sling | Misket | B |
| Needles | Dart Borusu Dartı | R~ |
| Burglar's Pack | Hırsız Paketi | R |
| Diplomat's Pack | Diplomat Paketi | R |
| Dungeoneer's Pack | Zindancı Paketi | R |
| Entertainer's Pack | Ozan Paketi | R |
| Explorer's Pack | Kaşif Paketi | R |
| Priest's Pack | Rahip Paketi | R |
| Scholar's Pack | Bilge Paketi | R |

### 7.4 mount · vehicle

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Camel | Deve | R |
| Elephant | Fil | R |
| Draft Horse | Yük Atı | R~ |
| Riding Horse | Binek Atı | R~ |
| Mastiff | Mastiff | R |
| Mule | Katır | R |
| Pony | Midilli | R |
| Warhorse | Savaş Atı | R |
| Carriage | Yolcu Vagonu | R |
| Cart | Araba | R |
| Chariot | Savaş Arabası | R |
| Sled | Kızak | R |
| Wagon | Vagon | R |
| Galley | Kalyon | R |
| Keelboat | Altı Düz Mavna | R |
| Longship | Viking Yelkenlisi | R |
| Rowboat | Sandal | R |
| Sailing Ship | Yelkenli | R |
| Warship | Savaş Gemisi | R |
| Airship | Hava Gemisi | Ö |

### 7.5 tool — Alet

| İngilizce | Türkçe | Kaynak |
|---|---|---|
| Alchemist's Supplies | Simyacılık Malzemeleri | R |
| Brewer's Supplies | Mayacılık Malzemeleri | R |
| Calligrapher's Supplies | Hattatlık Malzemeleri | R |
| Carpenter's Tools | Marangozluk Aletleri | R |
| Cartographer's Tools | Haritacılık Aletleri | R |
| Cobbler's Tools | Kunduracılık Aletleri | R |
| Cook's Utensils | Aşçılık Ekipmanı | R |
| Glassblower's Tools | Camcılık Aletleri | R |
| Jeweler's Tools | Kuyumculuk Aletleri | R |
| Leatherworker's Tools | Dericilik Aletleri | R |
| Mason's Tools | Taşçılık Aletleri | R |
| Painter's Supplies | Ressamlık Malzemeleri | R |
| Potter's Tools | Çömlekçilik Aletleri | R |
| Smith's Tools | Demircilik Aletleri | R |
| Tinker's Tools | Mucitlik Aletleri | R |
| Weaver's Tools | Dokumacılık Aletleri | R |
| Woodcarver's Tools | Oymacılık Aletleri | R |
| Disguise Kit | Kılık Değiştirme Kiti | R |
| Forgery Kit | Sahtecilik Kiti | R |
| Herbalism Kit | Otacılık Kiti | R |
| Navigator's Tools | Rotacılık Aletleri | R |
| Poisoner's Kit | Zehircilik Kiti | R |
| Thieves' Tools | Hırsızlık Aletleri | R |
| Gaming Set | Oyun Seti | R |
| Dice Set | Zar Seti | R |
| Dragonchess Set | Ejderha Satrancı Seti | Ö |
| Playing Card Set | Oyun Kartı Seti | R |
| Three-Dragon Ante Set | Üç-Ejder Bopu Seti | R |
| Bagpipes | Gayda | R |
| Drum | Davul | R |
| Dulcimer | Santur | R |
| Flute | Flüt | R |
| Horn | Boru | R |
| Lute | Ut | R |
| Lyre | Lir | R |
| Pan Flute | Pan Flütü | R |
| Shawm | Kaval | R |
| Viol | Viola | R |
