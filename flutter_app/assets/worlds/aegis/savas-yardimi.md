# Savaş Yardımı — Masa Başı Hızlı Referans

> **Durum: kanon DEĞİL.** Bu belge Aegis evreninin bir parçası değildir ve
> README §0 kanon hiyerarşisine girmez. Hiçbir kartın, lore sayfasının veya
> `aegis-act1.pkg.json` içeriğinin kaynağı olarak kullanılmaz.
>
> Burada yazan her şey **SRD 5.2.1'in kendisidir** — [`mekanikler.md`](lore/canon/mekanikler.md)
> gibi 5e'nin *üstüne* bir şey eklemez, sadece 5e'nin kendi savaş akışını masada
> bakılacak hale getirir. Sapma işareti taşımaz çünkü sapma yoktur.
>
> Bir çelişki olursa SRD kazanır; bu belge yalnızca bir hatırlatmadır.

---

## 0. Tek cümlelik özet

Savaşta bir şeye vurmak iki ayrı atıştır: **önce tutturuyor musun (d20 + bonus,
hedefin AC'sini geçmeli), sonra ne kadar acıttın (silahın zarı + ability mod).**
Bazı büyüler bu akışı hiç kullanmaz — orada d20'yi sen değil, hedef atar.

---

## 1. Saldırı zarı — AC'yi geçmek

```
d20  +  ability mod  +  proficiency bonus  (+ büyülü silah bonusu)   ≥   hedefin AC'si
```

- Eşitse **vurur** (AC 15'e karşı 15 = isabet).
- **Natural 20** her zaman vurur ve **kritiktir** — hasar zarlarını iki kez atarsın,
  modifier tek kalır (1d8+3 kritikte 2d8+3 olur, 2d8+6 değil).
- **Natural 1** her zaman ışınlar, bonusun ne olursa olsun.
- Proficiency bonusu **sadece kullanmayı bildiğin** silahlarda eklenir. Yetkin
  olmadığın bir silahı tutabilirsin ama bonusu alamazsın.

### Hangi ability?

| Durum | Modifier |
|---|---|
| Melee silah (Longsword, Greataxe, Warhammer…) | **STR** |
| Menzilli silah (Longbow, Crossbow, Sling…) | **DEX** |
| **Finesse** property'li (Rapier, Dagger, Shortsword, Scimitar…) | STR **veya** DEX — oyuncu seçer |
| **Thrown** ile fırlatırken | Silahın kendi tipi neyse o. Javelin → STR. Dagger finesse olduğu için → STR/DEX seçimi |
| Unarmed strike | STR |
| Büyü saldırısı | Sınıfının casting ability'si (§3) |

> **Finesse kuralı:** seçtiğin ability hem saldırıda hem hasarda aynı olmak
> zorunda. Saldırıda DEX kullanıp hasarda STR diyemezsin.

---

## 2. Hasar zarı — ayrı bir atış

```
silahın zarı  +  ability mod  (+ büyülü silah bonusu)
```

**Proficiency bonusu hasara EKLENMEZ.** Sadece saldırı zarına eklenir. En sık
yapılan hata bu.

Kullanılan ability, saldırıda kullandığının aynısıdır.

### Versatile silahlar

Longsword, Quarterstaff, Spear gibi **Versatile** property'li silahların iki zarı
vardır ve hangisini kullandığın, o an **kaç elini** kullandığına bağlıdır:

| Nasıl tutuyorsun | Zar | AC |
|---|---|---|
| Tek elle + kalkan | küçük zar (Longsword: **1d8**) | kalkan sayesinde **+2** |
| İki elle, kalkan yok | büyük zar (Longsword: **1d10**) | kalkan yok |

Kararı her turda yeniden verebilirsin, ama kalkanı takıp çıkarmak bir **Utilize
action** ister — yani pratikte savaşın başında seçip öyle kalırsın.

> Uygulamadaki silah kartı bunu iki ayrı alanda gösteriyor: `damage_dice` (1d8)
> üstte, `versatile_damage_dice` (1d10) Properties kutusunda. Kart "+STR" yazmaz
> ve yazmamalı — o modifier silaha değil, silahı tutan karaktere ait.

---

## 3. Büyüler — üç ayrı davranış

Büyülerin hepsi aynı çalışmaz. Büyünün metni hangisi olduğunu söyler.

### 3a. Spell Attack — d20 atarsın (silahla aynı mantık)

Metinde **"Spell Attack Roll"** geçiyorsa:

```
d20  +  casting ability mod  +  proficiency bonus   ≥   hedefin AC'si
```

Örnek: Fire Bolt, Guiding Bolt, Eldritch Blast, Chill Touch.

### 3b. Saving Throw — sen d20 ATMAZSIN

Metinde **"... Saving Throw"** geçiyorsa AC hiç devreye girmez. Sen sadece sabit
bir sayı sunarsın, d20'yi **hedef** atar:

```
Spell Save DC  =  8  +  proficiency bonus  +  casting ability mod
```

Hedef `d20 + kendi save bonusu` atar. DC'yi tutturamazsa yer. Çoğu büyüde başarılı
save = hiç etki yok; alan büyülerinde (Fireball) = **yarım hasar**.

Örnek: Fireball (DEX), Hold Person (WIS), Sacred Flame (DEX), Command (WIS).

### 3c. Otomatik — ne d20 ne save

Hedefin AC'si de save'i de sorulmaz, büyü çalışır.

Örnek: Magic Missile, Cure Wounds, Bless, Shield, Healing Word.

### Casting ability hangi sınıfta ne?

| Ability | Sınıflar |
|---|---|
| **CHA** | Paladin, Warlock, Sorcerer, Bard |
| **WIS** | Cleric, Druid, Ranger |
| **INT** | Wizard, Artificer, Eldritch Knight, Arcane Trickster |

Silah saldırısı ile büyü saldırısı **farklı ability kullanabilir** — Paladin'de
silah STR'dir, büyü CHA'dır. İkisi aynı karakterde yan yana yaşar.

---

## 4. Örnek — Dragonborn Paladin, 1. seviye

Referans karakter. STR 16 (+3), DEX 12 (+1), CHA 16 (+3), proficiency **+2**.
Kuşanımı: Chain Mail + Shield + Longsword (Paladin başlangıç paketi).

### AC hesabı

| Durum | Hesap | Sonuç |
|---|---|---|
| Zırhsız, kalkanlı | 10 + DEX 1 + kalkan 2 | **13** |
| Chain Mail + kalkan | 16 (sabit) + kalkan 2 | **18** |
| Chain Mail, kalkansız | 16 (sabit) | **16** |

> **Chain Mail heavy armor: DEX hiç eklenmez.** Kartta `base_ac: 16`,
> `adds_dex: false`. DEX'i yüksek bir karakterde bile 16'dır. 1. seviye için 18
> fazla değil — kalkanlı paladin/fighter'ın standart değeri budur.
>
> Ayrıca Chain Mail'in `strength_requirement: 13` var (STR 13'ün altındaysan hızın
> 10 ft düşer) ve `stealth_disadvantage: true` (gizlenmede dezavantaj).

### Bir tur nasıl işler

**Action: Longsword ile saldırı (tek elle, kalkan takılı)**

1. **Saldırı:** `d20 + 3 (STR) + 2 (prof)` = **d20 + 5** → hedefin AC'sini geçmeli
2. **Vurdu:** `1d8 + 3` slashing

İki elle tutsaydı (kalkanı bırakıp AC 16'ya düşerek): saldırı yine **d20 + 5**,
hasar **1d10 + 3**. Ortalama fark sadece +1 hasar — **2 AC'ye değmez**, kalkanda kal.

**Divine Smite eklemek**

Smite bir büyü saldırısı **değildir** — ikinci bir zar atmazsın, kendi DC'si yoktur:

1. Önce normal silah saldırısını yap (yukarıdaki d20 + 5)
2. **Vurduktan sonra** karar ver ve bir spell slot harca
3. 1. seviye slot → **+2d8 radiant**, otomatik gelir, hedefin savunması sorulmaz

Yani isabet eden bir vuruş: `1d8 + 3` slashing **+** `2d8` radiant.
Kritikte smite zarları da ikiye katlanır.

**Büyü kullanırsa**

Command, Bless gibi paladin büyülerinde:

```
Spell Save DC = 8 + 2 (prof) + 3 (CHA) = 13
```

Hedef bu 13'ü kendi save'iyle geçmeye çalışır. Sen d20 atmazsın.

### Dragonborn Breath Weapon

Irkın nefes silahı da bir **saving throw** etkisidir (§3b), silah saldırısı değil:
hedefler DEX save atar, DC yine `8 + prof + CON mod` formatındadır — ırkın kendi
metnindeki ability'yi kullan.

---

## 5. Sık yapılan hatalar

- ❌ Hasara proficiency eklemek → sadece saldırıya eklenir
- ❌ Chain Mail'e DEX eklemek → heavy armor, `adds_dex: false`, 16 sabit
- ❌ Longsword'ü "iki elli silah" sanmak → Versatile'dır, kalkanla gayet kullanılır
- ❌ Kritikte modifier'ı da ikiye katlamak → sadece **zarlar** ikiye katlanır
- ❌ Save büyüsünde saldırı zarı atmak → orada d20'yi hedef atar, sen DC sunarsın
- ❌ Smite için ayrı saldırı zarı atmak → vuruştan **sonra** eklenir, otomatiktir
- ❌ Finesse silahta saldırıda DEX, hasarda STR kullanmak → ikisi aynı olmalı

---

## 6. Tek sayfalık hatırlatma

```
SİLAH SALDIRISI
  isabet : d20 + (STR|DEX) + proficiency     ≥ AC
  hasar  : silah zarı + (STR|DEX)            [proficiency YOK]

BÜYÜ — saldırılı
  isabet : d20 + casting ability + proficiency ≥ AC
  hasar  : büyü zarı                          [ability genelde YOK]

BÜYÜ — kurtarmalı
  DC     : 8 + proficiency + casting ability
  hedef atar: d20 + save bonusu ≥ DC

AC
  zırhsız    : 10 + DEX (+ kalkan 2)
  light      : base + DEX (+ kalkan 2)
  medium     : base + min(DEX, 2) (+ kalkan 2)
  heavy      : base (DEX YOK) (+ kalkan 2)
```
