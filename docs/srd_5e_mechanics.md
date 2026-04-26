# D&D 5e SRD 5.2.1 — Mekanik Listesi

Bu döküman `docs/SRD_CC_v5.2.1.pdf` (CC-BY-4.0) içeriğinden damıtılmış mekanik referansıdır. Her madde **atomic** bir kuraldır — koda gömülürken tek bir fonksiyon/branch karşılık gelir. Sayfa referansları SRD PDF'i içindir.

## §0 Okuma Rehberi — 3-State Checkbox Sistemi

Her mekanik maddesi başında **3 checkbox** vardır. Soldan sağa:

```
- [ ] [ ] [ ] [ ] [ ] **Madde** — açıklama (s.NNN).
   ↑   ↑   ↑
   p   s   i
```

| Pozisyon | Etiket | Anlamı | Ne zaman işaretlenir |
|---|---|---|---|
| 1 | **[p] Planned** | Mekanik gelecek roadmap'e / issue tracker'a eklendi | Roadmap'te explicit task var |
| 2 | **[s] Supported** | Şemada (FieldType + category field) bu mekaniği tutacak alan var | İlgili field tanımlı (`content.dart` / `dm.dart`) |
| 3 | **[i] Implemented** | Dart runtime'da resolver bu mekaniği gerçekten uyguluyor | Test'le doğrulanmış kod yolu var |

**Tipik akış:** mekanik önce `[p]` işaretlenir (roadmap), sonra `[s]` (şema field eklenir), en son `[i]` (resolver yazılır + test geçer). Üçü de boş = mekanik henüz tanımlı değil. Sadece `[p]` = planda var ama dokunulmadı. `[p][s]` = data tutuluyor ama runtime hiçbir şey yapmıyor (sadece UI form). `[p][s][i]` = tam çalışıyor.

Sayfa referansları PDF'in 364-sayfa SRD v5.2.1 ile birebir hizalanmıştır (yan-dosya `srd_5e_field_mechanics.md` aynı semantiği kullanır).

---

## 1. Karakter Yaratma Akışı

### 1.1 5 Adımlık Akış (s.19)
- [ ] [x] [ ] **Adım 1: Sınıf seç** — primary ability, hit die, save profs, weapon/armor profs, starting equipment (s.19)
- [ ] [x] [ ] **Adım 2: Origin** — background + species + 2 dil seçimi (s.19-20)
- [ ] [x] [ ] **Adım 3: Ability Scores** — Standard Array / Random (4d6 drop low ×6) / Point Cost (27 puan) (s.21)
- [ ] [x] [ ] **Adım 4: Alignment** — 9 alignment'ten biri (LG/NG/CG/LN/N/CN/LE/NE/CE) veya unaligned (s.21)
- [ ] [x] [ ] **Adım 5: Detaylar** — class features, fill in numbers (saves, skills, passive perception, HP, init, AC, attacks, spellcasting) (s.22)

### 1.2 Ability Score üretimi (s.21)
- [ ] [x] [ ] **Standard Array** — 15, 14, 13, 12, 10, 8 (s.21)
- [ ] [x] [ ] **Random Generation** — 4d6 drop lowest, 6 kez (s.21)
- [ ] [x] [ ] **Point Cost (27)** — score=8(0), 9(1), 10(2), 11(3), 12(4), 13(5), 14(7), 15(9) (s.21)
- [ ] [x] [ ] **Background ASI artışı** — +2/+1 veya +1/+1/+1 background'un 3 ability'sine, max 20 (s.21, 83)

### 1.3 Final detay hesapları
- [ ] [x] [ ] **Passive Perception = 10 + Wis(Perception) check mod** — proficiency + advantage/disadv dahil (s.22)
- [ ] [x] [ ] **Initiative = Dex modifier** — adv +5, disadv −5 (s.22, 184)
- [ ] [x] [ ] **AC base = 10 + Dex** — armor/feature ile değişir, sadece 1 base hesabı kullanılabilir (s.7, 22)
- [ ] [x] [ ] **Melee atk bonus = Str + PB** (proficient) (s.22)
- [ ] [x] [ ] **Ranged atk bonus = Dex + PB** (proficient) (s.22)
- [ ] [x] [ ] **Spell save DC = 8 + spellcasting ability + PB** (s.23)
- [ ] [x] [ ] **Spell attack bonus = spellcasting ability + PB** (s.23)
- [ ] [x] [ ] **Trinket roll** — d100 ile küçük gizemli bir öğe (opsiyonel) (s.26-27)

### 1.4 Level 1 HP (s.22)
- [ ] [x] [ ] **Barbarian L1 HP = 12 + Con** (s.22)
- [ ] [x] [ ] **Fighter/Paladin/Ranger L1 HP = 10 + Con** (s.22)
- [ ] [x] [ ] **Bard/Cleric/Druid/Monk/Rogue/Warlock L1 HP = 8 + Con** (s.22)
- [ ] [x] [ ] **Sorcerer/Wizard L1 HP = 6 + Con** (s.22)

### 1.5 Level Advancement (s.23)
- [ ] [x] [ ] **XP tablosu** — L1=0, L2=300, L3=900, L4=2700, L5=6500, L6=14k, L7=23k, L8=34k, L9=48k, L10=64k, L11=85k, L12=100k, L13=120k, L14=140k, L15=165k, L16=195k, L17=225k, L18=265k, L19=305k, L20=355k (s.23)
- [ ] [x] [ ] **Proficiency Bonus by level** — L1-4 +2, L5-8 +3, L9-12 +4, L13-16 +5, L17-20 +6 (s.23)
- [ ] [x] [ ] **Fixed HP per level by class** — Barb 7, Fighter/Pal/Ranger 6, Bard/Cleric/Druid/Monk/Rogue/Warlock 5, Sorc/Wiz 4 (+ Con) (s.23)
- [ ] [x] [ ] **Roll HP per level** — class HD + Con, min 1 (s.23)
- [ ] [x] [ ] **Con artırırsa retroactive HP bump** — her level için +1, geçmiş levellara da uygulanır (s.23)
- [ ] [x] [ ] **ASI/Feat at L4/8/12/16** (sınıf bazlı, çoğunda) (s.23)

### 1.6 Tiers of Play (s.23-24)
- [ ] [x] [ ] **Tier 1 (L1-4)** — apprentice (s.24)
- [ ] [x] [ ] **Tier 2 (L5-10)** — full-fledged (s.24)
- [ ] [x] [ ] **Tier 3 (L11-16)** — special (s.24)
- [ ] [x] [ ] **Tier 4 (L17-20)** — pinnacle (s.24)

### 1.7 Higher-Level Start (s.24)
- [ ] [x] [ ] **L2-4 başlangıç** — normal equipment + 1 Common magic item (s.24)
- [ ] [x] [ ] **L5-10 başlangıç** — 500 GP + 1d10×25 GP + normal equip + 1 Common, 1 Uncommon (s.24)
- [ ] [x] [ ] **L11-16 başlangıç** — 5000 GP + 1d10×250 GP + normal equip + 2C, 3U, 1R (s.24)
- [ ] [x] [ ] **L17-20 başlangıç** — 20000 GP + 1d10×250 GP + normal equip + 2C, 4U, 3R, 1VR (s.24)

### 1.8 Multiclassing (s.24-26)
- [ ] [x] [ ] **Prerequisite: Primary ability ≥13** — yeni sınıf VE mevcut sınıf primary'leri (s.24)
- [ ] [x] [ ] **HP/HD: yeni sınıfın HD'si eklenir** (rolled or fixed) (s.25)
- [ ] [x] [ ] **PB total character level'a göre** — sınıfın level'ına değil (s.25)
- [ ] [x] [ ] **Multiclass starting profs sınırlı** — her sınıfın multiclass profs listesi (s.25)
- [ ] [x] [ ] **Extra Attack non-stack** — yalnızca en yüksek tek instance kullanılır (s.25)
- [ ] [x] [ ] **Unarmored Defense / AC features non-stack** — sadece bir tane seçilir (s.25)
- [ ] [x] [ ] **Multiclass Spellcaster Slot Table** — Bard/Cleric/Druid/Sorc/Wiz tüm levels + Pal/Ranger ½ levels = combined slot total (s.26)
- [ ] [x] [ ] **Spells Prepared per class individually** — kombine edilmez (s.25)
- [ ] [x] [ ] **Pact Magic / Spellcasting interaction** — slotlar karşılıklı kullanılabilir (s.26)

---

## 2. Ability Scores & D20 Tests

### 2.1 6 Ability (s.5)
- [ ] [x] [ ] **Strength** — physical might (s.5)
- [ ] [x] [ ] **Dexterity** — agility, reflexes, balance (s.5)
- [ ] [x] [ ] **Constitution** — health, stamina (s.5)
- [ ] [x] [ ] **Intelligence** — reasoning, memory (s.5)
- [ ] [x] [ ] **Wisdom** — perceptiveness, mental fortitude (s.5)
- [ ] [x] [ ] **Charisma** — confidence, poise, charm (s.5)

### 2.2 Score → Modifier (s.6)
- [ ] [x] [ ] **Score modifier table** — 1=−5, 2-3=−4, 4-5=−3, 6-7=−2, 8-9=−1, 10-11=0, 12-13=+1, 14-15=+2, 16-17=+3, 18-19=+4, 20=+5, ..., 30=+10 (s.6)
- [ ] [x] [ ] **Score cap normal 20** — 20+ extraordinary, 30 max (s.5)
- [ ] [x] [ ] **Round Down** — division/multiplication daima yuvarla aşağı, kural exception belirtmedikçe (s.5)

### 2.3 D20 Test (s.6)
- [ ] [x] [ ] **3 test türü** — ability check, saving throw, attack roll (s.6)
- [ ] [x] [ ] **Hesap** — d20 + ability mod + (PB if proficient) + circumstantial bonus/penalty (s.6)
- [ ] [x] [ ] **DC ranges** — Very Easy 5, Easy 10, Medium 15, Hard 20, Very Hard 25, Nearly Impossible 30 (s.6)
- [ ] [x] [ ] **Saving throw DC = 8 + ability + PB** (caster) (s.6, 7)
- [ ] [x] [ ] **Pass save = halve damage** (typical) (s.16)

### 2.4 Proficiency (s.8-9)
- [ ] [x] [ ] **PB doesn't stack** — bonus eklenebilir/halved/doubled olabilir ama aynı roll'a iki kez eklenmez (s.8)
- [ ] [x] [ ] **Skills (18) + abilities** — Acrobatics(Dex), Animal Handling(Wis), Arcana(Int), Athletics(Str), Deception(Cha), History(Int), Insight(Wis), Intimidation(Cha), Investigation(Int), Medicine(Wis), Nature(Int), Perception(Wis), Performance(Cha), Persuasion(Cha), Religion(Int), Sleight of Hand(Dex), Stealth(Dex), Survival(Wis) (s.9)
- [ ] [x] [ ] **Tool proficiency** — PB'i eklenir; ilgili skill prof varsa Advantage (s.9)
- [ ] [x] [ ] **Saving throw prof** — sınıftan gelir, 2 ability (s.9)
- [ ] [x] [ ] **Expertise** — bir skill prof'unda PB ×2 (s.182)
- [ ] [x] [ ] **Weapon proficiency** — PB to attack roll (s.6, 89)

### 2.5 Advantage / Disadvantage (s.7-8)
- [ ] [x] [ ] **Roll 2d20, take higher (adv) / lower (disadv)** (s.8)
- [ ] [x] [ ] **Stack-iptal** — birden fazla adv/disadv aynı roll'da olunca biri varsa diğeri = neither (s.8)
- [ ] [x] [ ] **Cancel even if multiple sides** — 2 disadv + 1 adv = neither, hala (s.8)
- [ ] [x] [ ] **Reroll ile etkileşim** — adv/disadv ile rollanmış 2 zardan sadece biri reroll (s.8)
- [ ] [x] [ ] **Heroic Inspiration reroll** — d20 sonrası reroll, yeni sonuç kullanılır; aynı anda max 1 (s.8)

---

## 3. Combat Sistemi

### 3.1 Combat Akışı (s.13)
- [ ] [x] [ ] **3 Adım** — Establish Positions → Roll Initiative → Take Turns (s.13)
- [ ] [x] [ ] **Initiative = d20 + Dex (or 10+Dex score)** — yüksekten düşüğe sıralanır (s.13)
- [ ] [x] [ ] **Surprise = Disadvantage on Initiative roll** (s.13, 189)
- [ ] [x] [ ] **Round = ~6 saniye** (s.13)
- [ ] [x] [ ] **Tie: monsters arası GM, players arası player, mixed GM seçer** (s.13)
- [ ] [x] [ ] **Ending Combat** — bir taraf yenildiğinde / surrender / flee / mutual end (s.14)

### 3.2 Turn Yapısı (s.13)
- [ ] [x] [ ] **Move + 1 Action** — sıraları değiştirilebilir, breakup edilebilir (s.13)
- [ ] [x] [ ] **1 Bonus Action (if available)** — sadece bir feature/spell verirse (s.10)
- [ ] [x] [ ] **1 Reaction per round** — opportunity attack, readied actions, etc. (s.10)
- [ ] [x] [ ] **1 Free object interaction** — move VEYA action sırasında bir kapı açma vs (s.13)
- [ ] [x] [ ] **Communicating free** — kısa konuşma/jest (s.13)
- [ ] [x] [ ] **2nd object interaction = Utilize action** (s.13)
- [ ] [x] [ ] **Doing nothing OK** — turn skip edilebilir (s.14)

### 3.3 Movement (s.14)
- [ ] [x] [ ] **Speed = max move distance per turn** — birden fazla move modu kombinlenir (s.14)
- [ ] [x] [ ] **Climb/Crawl = 1 extra ft per ft** — 2 ft total (s.14, 178-179)
- [ ] [x] [ ] **Swim = 1 extra ft per ft** unless Swim Speed (s.189)
- [ ] [x] [ ] **Difficult Terrain = 1 extra ft per ft** — cumulative değil (s.14, 181)
- [ ] [x] [ ] **Drop Prone = no action/movement cost** — Speed 0 ise yine OK (s.14)
- [ ] [x] [ ] **Stand from Prone = ½ Speed cost** (s.186)
- [ ] [x] [ ] **High Jump = 3 + Str mod ft** if 10ft running start; standing = ½; cost 1 ft per ft (s.183)
- [ ] [x] [ ] **Long Jump = Str score ft** if 10ft running, standing = ½ (s.184-185)
- [ ] [x] [ ] **Move through ally/Tiny/2-size diff** — OK; diğerleri Difficult Terrain (s.14)
- [ ] [x] [ ] **Cannot end turn in occupied space** — eğer öyle olursa Prone (Tiny/larger size hariç) (s.14)
- [ ] [x] [ ] **Breaking Up Movement** — action arası move (s.14)

### 3.4 Creature Size & Space (s.14)
- [ ] [x] [ ] **Tiny 2.5×2.5** (4/sq) (s.14)
- [ ] [x] [ ] **Small/Medium 5×5** (1 sq) (s.14)
- [ ] [x] [ ] **Large 10×10** (4 sq) (s.14)
- [ ] [x] [ ] **Huge 15×15** (9 sq) (s.14)
- [ ] [x] [ ] **Gargantuan 20×20** (16 sq) (s.14)

### 3.5 Actions (12) (s.9-10)
- [ ] [x] [ ] **Attack** — silah/Unarmed Strike ile attack roll (s.9)
- [ ] [x] [ ] **Dash** — Speed kadar ek hareket (s.180)
- [ ] [x] [ ] **Disengage** — turn boyunca opportunity attack tetiklemez (s.181)
- [ ] [x] [ ] **Dodge** — gelen attack rolls disadv, Dex saves adv; Speed 0 / Incapacitated iptal (s.181)
- [ ] [x] [ ] **Help** — bir ally'e check/atk için adv ver, ya da first aid (s.10, 182-183)
- [ ] [x] [ ] **Hide** — DC 15 Dex(Stealth); HV obscured veya 3/4+ cover gereklidir (s.183)
- [ ] [x] [ ] **Influence** — Cha (Dec/Intim/Perf/Pers) veya Wis (Animal Handling) (s.10, 184)
- [ ] [x] [ ] **Magic** — büyü cast / magic item / magical feature (s.10, 185)
- [ ] [x] [ ] **Ready** — trigger + reaction-action belirle (s.10, 186)
- [ ] [x] [ ] **Search** — Wis (Insight/Medicine/Perception/Survival) (s.10, 187)
- [ ] [x] [ ] **Study** — Int (Arcana/History/Investigation/Nature/Religion) (s.10, 189)
- [ ] [x] [ ] **Utilize** — non-magical objeyi kullan (action gerektiren) (s.10, 191)

### 3.6 Bonus Action (s.10)
- [ ] [x] [ ] **Sadece feature/spell verirse** — varsayılan yoktur (s.10)
- [ ] [x] [ ] **1 BA per turn** (s.10)
- [ ] [x] [ ] **Action'dan vazgeçince BA da gider** (deprive ability) (s.10)

### 3.7 Reaction (s.10)
- [ ] [x] [ ] **1 reaction per round** — turn arası reset (start of next turn) (s.10, 186)
- [ ] [x] [ ] **Trigger zorunlu** — açıklamada belirtilir (s.10)
- [ ] [x] [ ] **Reaction interrupt eder** — trigger'dan hemen sonra (default) (s.10)

### 3.8 Attack Roll Yapısı (s.14-15)
- [ ] [x] [ ] **3 Adım** — Choose Target → Determine Modifiers (cover, adv/dis) → Resolve (s.15)
- [ ] [x] [ ] **Roll 20 = Critical Hit** (s.7)
- [ ] [x] [ ] **Roll 1 = automatic miss** (s.7)
- [ ] [x] [ ] **Critical Hit = damage dice ×2 + mod** (Sneak Attack vs dahil) (s.16, 179)
- [ ] [x] [ ] **Unseen Attacker** — disadv on attack vs unseen target; adv vs seen-but-can't-see-you target (s.14)
- [ ] [x] [ ] **Unseen Target reveals on hit/miss** — pozisyon belli olur (s.14)

### 3.9 Cover (s.15)
- [ ] [x] [ ] **Half Cover** — +2 AC, +2 Dex saves (en az ½ kaplı) (s.15)
- [ ] [x] [ ] **Three-Quarters Cover** — +5 AC, +5 Dex saves (s.15)
- [ ] [x] [ ] **Total Cover** — hedeflenemez (s.15)
- [ ] [x] [ ] **Sadece en yüksek cover sayılır** — additive değil (s.15)

### 3.10 Ranged Attacks (s.15)
- [ ] [x] [ ] **Range = (normal/long) ft** — long beyond = disadv, beyond long = miss (s.15)
- [ ] [x] [ ] **Ranged in close combat = disadv** if hostile within 5ft, sees, not Incapacitated (s.15)

### 3.11 Melee Attacks (s.15)
- [ ] [x] [ ] **Reach default 5 ft** (s.15, 186)
- [ ] [x] [ ] **Reach property = +5 ft** (10 ft total) (s.15, 90)

### 3.12 Opportunity Attack (s.15, 185)
- [ ] [x] [ ] **Reach'tan çıkan creature = OA** (Reaction) (s.15)
- [ ] [x] [ ] **Disengage cancels OA** (s.15, 181)
- [ ] [x] [ ] **Teleport cancels OA** (s.190)
- [ ] [x] [ ] **Forced movement (push/pull) cancels OA** (s.15)
- [ ] [x] [ ] **OA = 1 melee attack right before leaving** (s.15)

### 3.13 Equipping/Unequipping Weapons (s.177)
- [ ] [x] [ ] **Attack action içinde 1 weapon equip/unequip free** — drawing/sheathing/stowing/dropping (s.177)
- [ ] [x] [ ] **Equip = draw or pick up** (s.177)
- [ ] [x] [ ] **Unequip = sheathe / stow / drop** (s.177)
- [ ] [x] [ ] **Move between attacks (Extra Attack)** — Attack action sırasında (s.177)

### 3.14 Mounted Combat (s.15-16)
- [ ] [x] [ ] **Mount/Dismount = ½ Speed cost** (s.15)
- [ ] [x] [ ] **Controlled mount: Initiative değişir, mount Dash/Disengage/Dodge yapar** (s.16)
- [ ] [x] [ ] **Independent mount: kendi Initiative'i, kendi davranır** (s.16)
- [ ] [x] [ ] **Forced movement → DC 10 Dex save or Prone** (s.16)
- [ ] [x] [ ] **Knocked Prone (mount or rider) → save same DC** (s.16)

### 3.15 Underwater Combat (s.16)
- [ ] [x] [ ] **Melee weapon underwater (no Swim Speed) = disadv unless Piercing** (s.16)
- [ ] [x] [ ] **Ranged: long range auto-miss, normal range disadv** (s.16)
- [ ] [x] [ ] **Fire Resistance underwater** (s.16)

### 3.16 Two-Weapon Fighting (Light property) (s.89)
- [ ] [x] [ ] **Light melee + extra attack BA** — farklı Light weapon, 2nd hit ability mod yok unless negative (s.89)
- [ ] [x] [ ] **Nick property** — extra attack Attack action içinde, BA değil (s.90)
- [ ] [x] [ ] **Two-Weapon Fighting feat** — off-hand'a ability mod ekler (s.88)

---

## 4. Damage & Healing

### 4.1 Hit Points (s.16)
- [ ] [x] [ ] **HP max set on creation; current 0..max** (s.16)
- [ ] [x] [ ] **Bloodied = ≤ ½ HP** — kendi etki yok ama trigger olabilir (s.16, 178)
- [ ] [x] [ ] **HP loss no capability impact until 0** (s.16)

### 4.2 Damage Roll (s.16)
- [ ] [x] [ ] **Weapon: damage die + ability mod** (s.16)
- [ ] [x] [ ] **Spell: per spell description** (s.16)
- [ ] [x] [ ] **Min 0 dmg (no negative)** (s.16)
- [ ] [x] [ ] **No mod to fixed damage (e.g. Blowgun)** (s.16)

### 4.3 Damage Types (13) (s.16, 180)
- [ ] [x] [ ] **Acid / Bludgeoning / Cold / Fire / Force / Lightning / Necrotic / Piercing / Poison / Psychic / Radiant / Slashing / Thunder** (s.180)

### 4.4 Resistance / Vulnerability / Immunity (s.17)
- [ ] [x] [ ] **Resistance = ½ damage (round down)** (s.17)
- [ ] [x] [ ] **Vulnerability = ×2 damage** (s.17)
- [ ] [x] [ ] **Immunity = no damage / no condition effect** (s.17)
- [ ] [x] [ ] **No stack** — multiple resist = single instance (s.17)
- [ ] [x] [ ] **Order: bonus/penalty/multiplier → resistance → vulnerability** (s.17)
- [ ] [x] [ ] **Damage Threshold (object)** — under threshold = 0 dmg, equal/over = full (s.180)

### 4.5 Critical Hit (s.16, 179)
- [ ] [x] [ ] **Damage dice ×2** (Sneak Attack dahil) (s.16, 179)
- [ ] [x] [ ] **Modifier eklenir 1 kez** (s.16)

### 4.6 Saving Throws & Damage (s.16)
- [ ] [x] [ ] **Multiple targets: 1 damage roll, all targets** (s.16)
- [ ] [x] [ ] **Half damage on save (typical)** (s.16)

### 4.7 Healing (s.17)
- [ ] [x] [ ] **Healing = HP restore, max = HP max** (s.17, 182)
- [ ] [x] [ ] **Excess healing lost** (s.17)

### 4.8 Dropping to 0 HP (s.17)
- [ ] [x] [ ] **Monster: dies at 0 (default)** (s.17)
- [ ] [x] [ ] **PC: Unconscious + Death Saves** (s.17-18)
- [ ] [x] [ ] **Massive Damage = die if remainder ≥ HP max** (s.17)
- [ ] [x] [ ] **Hit Point Max = 0 → die** (s.17)
- [ ] [x] [ ] **Death Saves: roll d20** (no mod), 10+ success, <10 fail (s.17)
- [ ] [x] [ ] **3 successes = Stable** (s.17)
- [ ] [x] [ ] **3 failures = die** (s.17)
- [ ] [x] [ ] **Nat 1 = 2 fails** (s.18)
- [ ] [x] [ ] **Nat 20 = +1 HP, conscious** (s.18)
- [ ] [x] [ ] **Damage at 0 HP = 1 fail (2 if crit, instant death if ≥ HP max)** (s.18)

### 4.9 Stabilizing (s.18)
- [ ] [x] [ ] **Help action + DC 10 Wis(Medicine)** (s.18)
- [ ] [x] [ ] **Healer's Kit = stabilize without check** (s.97)
- [ ] [x] [ ] **Stable + no damage → 1 HP after 1d4 hours** (s.18)

### 4.10 Knock Out (s.17, 184)
- [ ] [x] [ ] **Melee → 1 HP + Unconscious** (instead of die at 0) (s.17, 184)
- [ ] [x] [ ] **Short Rest starts on creature** (s.17)
- [ ] [x] [ ] **Ends if HP regained or first aid (DC 10 Wis Med)** (s.17)

### 4.11 Temporary HP (s.18)
- [ ] [x] [ ] **Buffer, lost first** (s.18)
- [ ] [x] [ ] **Don't stack — choose new or keep** (s.18)
- [ ] [x] [ ] **Long Rest finishes them** (s.18)
- [ ] [x] [ ] **Not healing — don't restore consciousness** (s.18)

### 4.12 Resting (s.16, 185, 187)
- [ ] [x] [ ] **Short Rest = 1 hour** (s.187)
- [ ] [x] [ ] **Spend Hit Dice during SR — d + Con** min 1 HP (s.187)
- [ ] [x] [ ] **SR Interrupt** — Initiative / non-cantrip cast / damage (s.187)
- [ ] [x] [ ] **Long Rest = 8 hours** (≥6 sleep + ≤2 light activity) (s.185)
- [ ] [x] [ ] **LR: full HP + ½ HD restore + scores reset + −1 Exhaustion** (s.185)
- [ ] [x] [ ] **LR Interrupt** — Initiative / non-cantrip cast / damage / 1h walking; ≥1h before interrupt → SR benefit (s.185)
- [ ] [x] [ ] **No 2nd LR within 16 hours** (s.185)

### 4.13 Hit Dice by class (s.22-23)
- [ ] [x] [ ] **d12** — Barbarian (s.22)
- [ ] [x] [ ] **d10** — Fighter, Paladin, Ranger (s.22)
- [ ] [x] [ ] **d8** — Bard, Cleric, Druid, Monk, Rogue, Warlock (s.22)
- [ ] [x] [ ] **d6** — Sorcerer, Wizard (s.22)

### 4.14 Breaking Objects — Object AC & HP (s.177-178)

Karakterler kapı, sandık, heykel gibi objelere saldırdığında bu kurallar çalışır. GM, çok kırılgan bir nesneyi `Attack`/`Utilize` action ile otomatik kırdırabilir; sağlam objeler için AC + HP tablosundan değer seçer.

**Object Armor Class (s.178):**
- [ ] [x] [ ] **AC 11 — Cloth, paper, rope** — bez, kâğıt, ip; saldırıyla rahatça delinir (s.178)
- [ ] [x] [ ] **AC 13 — Crystal, glass, ice** — kristal, cam, buz; orta DEX'li PC bile vurur ama iyi parçalanır (s.178)
- [ ] [x] [ ] **AC 15 — Wood** — odun objeler (sandık, kapı, masa); zırhlı bir hedef hissi verir (s.178)
- [ ] [x] [ ] **AC 17 — Stone** — taş yüzey; yüksek DC, melee atak için Skilled karakter gerekir (s.178)
- [ ] [x] [ ] **AC 19 — Iron, steel** — demir/çelik; magic weapon olmadan kırmak çok zor (s.178)
- [ ] [x] [ ] **AC 21 — Mithral** — mithral; sadece yüksek-PB karakterler veya magic objeler vurabilir (s.178)
- [ ] [x] [ ] **AC 23 — Adamantine** — adamantine; pratikte sadece nat-20 veya çok yüksek bonuslar vurur (s.178)

**Object Hit Points (s.178) — Fragile / Resilient:**
- [ ] [x] [ ] **Tiny (şişe, kilit)** — Fragile 2 (1d4) / Resilient 5 (2d4); tek vuruşta kırılan ufak nesneler (s.178)
- [ ] [x] [ ] **Small (sandık, lavta)** — Fragile 3 (1d6) / Resilient 10 (3d6); küçük taşınabilir nesneler (s.178)
- [ ] [x] [ ] **Medium (varil, avize)** — Fragile 4 (1d8) / Resilient 18 (4d8); insan boyu objeler (s.178)
- [ ] [x] [ ] **Large (araba, yemek masası)** — Fragile 5 (1d10) / Resilient 27 (5d10); kalın yapılı büyük nesneler (s.178)

**Damage rules (s.178):**
- [ ] [x] [ ] **Object damage type modifiers** — Bludgeoning iyi, Slashing zayıf çoğu nesnede; kâğıt/bez Fire'a vulnerable, GM hak verirse vulnerability/resistance uygular (s.178)
- [ ] [x] [ ] **Objects: Poison + Psychic immune** — cansız nesneler bu damage tiplerinden hiç etkilenmez (s.178)
- [ ] [x] [ ] **Damage Threshold** — kale duvarı gibi büyük yapılarda bir vuruşta DT'den az hasar alırsa hiç hasar görmez (s.178)
- [ ] [x] [ ] **No Ability Scores** — objeler ability score'a sahip değildir; ability check yapamaz, save'leri otomatik fail (s.178)
- [ ] [x] [ ] **Huge/Gargantuan objects: section HP** — devasa nesneleri Large veya küçük bölümlere ayır, her bölüme ayrı HP takip et; bir bölümün düşmesi tüm objeyi yıkmayabilir (s.178)

---

## 5. Conditions (15)

Tüm conditions: stack-etmez (Exhaustion hariç). Source: s.179.

- [ ] [x] [ ] **Blinded** — sight requiring checks fail; attacks vs you adv, your attacks disadv (s.177)
- [ ] [x] [ ] **Charmed** — attack/harm charmer no, charmer adv on social checks (s.178)
- [ ] [x] [ ] **Deafened** — hearing checks fail (s.181)
- [ ] [x] [ ] **Exhaustion (1-6)** — d20 tests −2/level, Speed −5ft/level; LR -1 level; **6 = death** (s.181)
- [ ] [x] [ ] **Frightened** — checks/attacks disadv while source in line of sight; can't move closer (s.182)
- [ ] [x] [ ] **Grappled** — Speed 0; attacks vs others disadv; mover can drag (1 extra ft); ends at distance > range or grappler Incapacitated (s.182)
- [ ] [x] [ ] **Incapacitated** — no actions/BA/Reaction; Concentration broken; speechless; if Surprised on init roll → disadv (s.184)
- [ ] [x] [ ] **Invisible** — surprise adv on init; concealed unless creator-sees; vs you disadv, your attacks adv (s.184)
- [ ] [x] [ ] **Paralyzed** — Incapacitated + Speed 0 + auto-fail Str/Dex saves + attacks vs adv + auto-crit at 5ft (s.186)
- [ ] [x] [ ] **Petrified** — turned to stone, weight ×10, no aging, Incapacitated, Speed 0, attacks vs adv, auto-fail Str/Dex saves, resist all damage, poison immunity (s.186)
- [ ] [x] [ ] **Poisoned** — checks/attacks disadv (s.186)
- [ ] [x] [ ] **Prone** — only crawl or stand (½ Speed); attacks vs disadv if attacker >5ft, adv if ≤5ft; your attacks disadv (s.186)
- [ ] [x] [ ] **Restrained** — Speed 0; attacks vs adv, your disadv; Dex saves disadv (s.187)
- [ ] [x] [ ] **Stunned** — Incapacitated + auto-fail Str/Dex saves + attacks vs adv (s.189)
- [ ] [x] [ ] **Unconscious** — Incapacitated + Prone + drop held + Speed 0 + auto-fail Str/Dex saves + attacks vs adv + auto-crit at 5ft + unaware (s.191)

---

## 6. Equipment & Inventory

### 6.1 Coins (s.89)
- [ ] [x] [ ] **Copper (CP) = 1/100 GP** (s.89)
- [ ] [x] [ ] **Silver (SP) = 1/10 GP** (s.89)
- [ ] [x] [ ] **Electrum (EP) = 1/2 GP** (s.89)
- [ ] [x] [ ] **Gold (GP) = 1 GP base** (s.89)
- [ ] [x] [ ] **Platinum (PP) = 10 GP** (s.89)
- [ ] [x] [ ] **50 coins = 1 lb** (s.89)

### 6.2 Carrying Capacity (s.178)
- [ ] [x] [ ] **Tiny: carry Str×7.5 lb / push-drag-lift Str×15 lb** (s.178)
- [ ] [x] [ ] **Small/Medium: carry Str×15 / drag Str×30** (s.178)
- [ ] [x] [ ] **Large: carry Str×30 / drag Str×60** (s.178)
- [ ] [x] [ ] **Huge: carry Str×60 / drag Str×120** (s.178)
- [ ] [x] [ ] **Gargantuan: carry Str×120 / drag Str×240** (s.178)
- [ ] [x] [ ] **Drag/lift/push >carry max → Speed ≤5 ft** (s.178)
- [ ] [x] [ ] **Goliath / Powerful Build → 1 size larger for carry** (s.86)

### 6.3 Buying & Selling (s.89)
- [ ] [x] [ ] **Equipment sells for ½ cost** (s.89)
- [ ] [x] [ ] **Trade goods, gems, art objects: full value** (s.89)

### 6.4 Weapon Properties (s.89-90)
- [ ] [x] [ ] **Ammunition** — must have ammo; recover ½ after fight (s.89)
- [ ] [x] [ ] **Finesse** — use Str or Dex for atk + dmg (same for both) (s.89)
- [ ] [x] [ ] **Heavy** — Str <13 (melee) or Dex <13 (ranged) → disadv (s.89)
- [ ] [x] [ ] **Light** — extra BA attack different Light weapon, no mod to dmg unless negative (s.89)
- [ ] [x] [ ] **Loading** — only 1 ammo per Action/BA/Reaction regardless of attacks (s.90)
- [ ] [x] [ ] **Range (n/m)** — n=normal, m=long; disadv beyond n, miss beyond m (s.90)
- [ ] [x] [ ] **Reach** — +5 ft reach (s.90)
- [ ] [x] [ ] **Thrown** — ranged attack, draw is part of attack; melee weapon → use melee mod (s.90)
- [ ] [x] [ ] **Two-Handed** — needs 2 hands (s.90)
- [ ] [x] [ ] **Versatile (dN)** — 2-handed = dN damage (s.90)

### 6.5 Weapon Mastery (8 properties) (s.90)
- [ ] [x] [ ] **Cleave** — hit + extra atk vs creature within 5ft (no mod dmg), 1/turn (s.90)
- [ ] [x] [ ] **Graze** — miss → ability mod damage (s.90)
- [ ] [x] [ ] **Nick** — Light extra attack within Attack action instead of BA (s.90)
- [ ] [x] [ ] **Push** — hit Large or smaller → push 10 ft (s.90)
- [ ] [x] [ ] **Sap** — hit → target's next attack disadv (s.90)
- [ ] [x] [ ] **Slow** — hit → Speed −10 ft (max −10) (s.90)
- [ ] [x] [ ] **Topple** — hit → Con save DC 8+abil+PB or Prone (s.90)
- [ ] [x] [ ] **Vex** — hit → adv on next attack vs same target (s.90)
- [ ] [x] [ ] **Mastery requires class feature** — not all weapon users get it (s.90)

### 6.6 Improvised Weapons (s.90, 183)
- [ ] [x] [ ] **1d4 damage, GM picks type** (s.183)
- [ ] [x] [ ] **No PB to attack** (unless feature) (s.183)
- [ ] [x] [ ] **Range: 20/60 if thrown, lacks Thrown property** (s.183)
- [ ] [x] [ ] **Resembles real weapon → may use that weapon's stats** (s.183)

### 6.7 Armor (s.92)
- [ ] [x] [ ] **Light: Padded(11) / Leather(11) / Studded(12) — full Dex; 1m don/doff** (s.92)
- [ ] [x] [ ] **Medium: Hide(12) / Chain Shirt(13) / Scale(14) / Breastplate(14) / Half Plate(15) — Dex max +2; 5m don, 1m doff** (s.92)
- [ ] [x] [ ] **Heavy: Ring(14) / Chain(16) / Splint(17) / Plate(18) — no Dex; 10m don, 5m doff** (s.92)
- [ ] [x] [ ] **Shield: +2 AC; Utilize action don/doff** (s.92)
- [ ] [x] [ ] **Strength req on heavy** — Chain 13, Splint 15, Plate 15; lacks → −10 ft Speed (s.92)
- [ ] [x] [ ] **Stealth disadv** — Padded, Scale, Half Plate, Ring, Chain, Splint, Plate (s.92)
- [ ] [x] [ ] **Only 1 armor + 1 shield at a time** (s.92)

### 6.8 Armor Training (s.92, 177)
- [ ] [x] [ ] **Lacks training (Light/Medium/Heavy worn)** — disadv all Str/Dex D20 Tests + can't cast spells (s.92)
- [ ] [x] [ ] **Lacks shield training** — no AC bonus from shield (s.92)
- [ ] [x] [ ] **Casting in Armor → need training** (s.104)

### 6.9 Tools (s.93)
- [ ] [x] [ ] **Tool prof = PB to relevant check** (s.9, 93)
- [ ] [x] [ ] **Tool + skill prof = Advantage** (s.9, 93)
- [ ] [x] [ ] **Utilize action with tool** — DC per tool (s.93)
- [ ] [x] [ ] **Craft list per tool** — what items can be made (s.93)
- [ ] [x] [ ] **Artisan's Tools (16+)** — each separate proficiency (Alchemist, Brewer, Calligrapher, Carpenter, Cartographer, Cobbler, Cook, Glassblower, Jeweler, Leatherworker, Mason, Painter, Potter, Smith, Tinker, Weaver, Woodcarver) (s.93-94)
- [ ] [x] [ ] **Other Tools** — Disguise Kit, Forgery Kit, Gaming Set, Herbalism Kit, Musical Instrument, Navigator's, Poisoner's, Thieves' Tools (s.94)

### 6.10 Adventuring Gear (s.94-99)
- [ ] [x] [ ] **Acid (25 GP)** — 2d6 acid, Dex save DC 8+Dex+PB (s.94)
- [ ] [x] [ ] **Alchemist's Fire (50 GP)** — 1d4 fire ongoing burn (s.94)
- [ ] [x] [ ] **Antitoxin (50 GP)** — BA, adv on Poisoned saves 1h (s.96)
- [ ] [x] [ ] **Ammunition packs** — Arrows(20), Bolts(20), Firearm Bullets(10), Sling Bullets(20), Needles(50) (s.96)
- [ ] [x] [ ] **Backpack (5 lb cap, 30 lb) (2 GP)** (s.96)
- [ ] [x] [ ] **Ball Bearings (1 GP)** — Dex DC 10 or Prone, area 10ft (s.96)
- [ ] [x] [ ] **Caltrops (1 GP)** — Dex DC 15 or 1 Piercing + Speed 0 (s.96)
- [ ] [x] [ ] **Candle / Torch / Lamp / Lanterns** — light radius, Bright + Dim (s.96-98)
- [ ] [x] [ ] **Component Pouch (25 GP)** — substitutes free M components (s.97)
- [ ] [x] [ ] **Healer's Kit (5 GP, 10 uses)** — Utilize stabilize, no check (s.97)
- [ ] [x] [ ] **Holy Symbol** — Amulet/Emblem/Reliquary (Cleric/Pal Spellcasting Focus) (s.97)
- [ ] [x] [ ] **Holy Water (25 GP)** — 2d8 Radiant vs Fiend/Undead (s.97)
- [ ] [x] [ ] **Hunting Trap (5 GP)** — Dex DC 13 / 1d4 Pierce + Speed 0 (s.97)
- [ ] [x] [ ] **Manacles (2 GP)** — Restrained if Dex DC 13 success; Athletics DC 25 to break (s.98)
- [ ] [x] [ ] **Net (1 GP)** — Restrained on hit (Dex DC 8+Dex+PB save) (s.98)
- [ ] [x] [ ] **Oil (1 SP)** — douse 5×5 area, 5 fire dmg if lit (s.98)
- [ ] [x] [ ] **Poison, Basic (100 GP)** — coat weapon, +1d4 Poison 1m (s.99)
- [ ] [x] [ ] **Potion of Healing (50 GP)** — BA drink, 2d4+2 HP (s.99)
- [ ] [x] [ ] **Spell Scroll Cantrip (30 GP) / Level 1 (50 GP)** — DC 13 / +5 atk (s.99)
- [ ] [x] [ ] **Tinderbox (5 SP)** — light Candle/Lamp/Torch as BA (s.99)
- [ ] [x] [ ] **Adventuring Packs** — Burglar's(16), Diplomat's(39), Dungeoneer's(12), Entertainer's(40), Explorer's(10), Priest's(33), Scholar's(40) GP (s.95)

### 6.11 Spellcasting Focus (s.96-97, 188)
- [ ] [x] [ ] **Arcane Focus** — Crystal/Orb/Rod/Staff/Wand (Sorc/Warlock/Wiz) (s.96)
- [ ] [x] [ ] **Druidic Focus** — Mistletoe/Wooden staff/Yew wand (Druid/Ranger) (s.97)
- [ ] [x] [ ] **Holy Symbol** — Amulet (worn/held), Emblem (fabric/shield), Reliquary (held) (s.97)
- [ ] [x] [ ] **Component Pouch substitute** — free M components only (s.96)
- [ ] [x] [ ] **Bard: Musical Instrument** (s.32)
- [ ] [x] [ ] **Wizard: Spellbook** (s.78)
- [ ] [x] [ ] **Pact of the Tome: Book of Shadows** (s.74)

### 6.12 Mounts & Vehicles (s.100)
- [ ] [x] [ ] **Mount carry capacities** — Camel 450, Elephant 1320, Draft Horse 540, Riding Horse 480, Mastiff 195, Mule 420, Pony 225, Warhorse 540 (lb) (s.100)
- [ ] [x] [ ] **Pulling vehicle = 5× carry capacity** (multiple animals add) (s.100)
- [ ] [x] [ ] **Barding cost ×4, weight ×2** (s.100)
- [ ] [x] [ ] **Saddle: Exotic (60 GP), Military (20 GP, adv on stay-mounted), Riding (10 GP)** (s.100)
- [ ] [x] [ ] **Vehicles: Cart(15), Carriage(100), Chariot(250), Sled(20), Wagon(35) GP** (s.100)
- [ ] [x] [ ] **Ships** — speed/crew/passengers/cargo/AC/HP/threshold/cost; Airship(40k), Galley(30k), Keelboat(3k), Longship(10k), Rowboat(50), Sailing Ship(10k), Warship(25k) GP (s.101)
- [ ] [x] [ ] **Ship repair = 1 day + 20 GP per HP** (½ if shipyard) (s.101)
- [ ] [x] [ ] **Stabling 5 SP/day, Feed 5 CP/day** (s.100)

### 6.13 Lifestyle Expenses (per day, s.101)
- [ ] [x] [ ] **Wretched (free)** — risk hazards (s.101)
- [ ] [x] [ ] **Squalid (1 SP)** (s.101)
- [ ] [x] [ ] **Poor (2 SP)** (s.101)
- [ ] [x] [ ] **Modest (1 GP)** (s.101)
- [ ] [x] [ ] **Comfortable (2 GP)** (s.101)
- [ ] [x] [ ] **Wealthy (4 GP)** (s.101)
- [ ] [x] [ ] **Aristocratic (10 GP min)** (s.101)

### 6.14 Hirelings (s.102)
- [ ] [x] [ ] **Skilled hireling** — 2 GP/day (s.102)
- [ ] [x] [ ] **Untrained** — 2 SP/day (s.102)
- [ ] [x] [ ] **Messenger** — 2 CP/mile (s.102)

### 6.15 Spellcasting Services (s.102)
- [ ] [x] [ ] **Cantrip 30 GP** — village/town/city (s.102)
- [ ] [x] [ ] **L1 50 GP** (s.102)
- [ ] [x] [ ] **L2 200 GP** (s.102)
- [ ] [x] [ ] **L3 300 GP** — town/city only (s.102)
- [ ] [x] [ ] **L4-5 2000 GP** (s.102)
- [ ] [x] [ ] **L6-8 20000 GP** — city only (s.102)
- [ ] [x] [ ] **L9 100000 GP** (s.102)
- [ ] [x] [ ] **Plus expensive component costs** (s.102)

### 6.16 Crafting (s.103)
- [ ] [x] [ ] **Tools required + proficiency** (s.103)
- [ ] [x] [ ] **Raw materials = ½ cost** (s.103)
- [ ] [x] [ ] **Time = cost / 10 GP per day** (8h/day) (s.103)
- [ ] [x] [ ] **Multiple workers / divide time** (s.103)

### 6.17 Brewing Potions of Healing (s.103)
- [ ] [x] [ ] **Herbalism Kit prof** + 25 GP raw + 1 day (8h) (s.103)

### 6.18 Scribing Spell Scrolls (s.103)
- [ ] [x] [ ] **Arcana / Calligrapher's Supplies prof** (s.103)
- [ ] [x] [ ] **Spell prepared on each day of inscription** (s.103)
- [ ] [x] [ ] **M components consumed only at completion** (s.103)
- [ ] [x] [ ] **Cost/Time table** — Cantrip 1d/15g, L1 1d/25g, ..., L9 120d/50000g (s.103)
- [ ] [x] [ ] **Scroll uses caster's DC + atk bonus** (s.103)

---

## 7. Equip / Unequip Mekaniği

### 7.1 Silah (s.177)
- [ ] [x] [ ] **Attack action içinde 1 silah free equip/unequip** — turn başına (s.177)
- [ ] [x] [ ] **Equip = drawing or picking up** (s.177)
- [ ] [x] [ ] **Unequip = sheathing / stowing / dropping** (s.177)
- [ ] [x] [ ] **Move between attacks** — Extra Attack ile arada move OK (s.177)

### 7.2 Zırh (s.92)
- [ ] [x] [ ] **Light don/doff = 1 dakika** (s.92)
- [ ] [x] [ ] **Medium don = 5 dakika, doff = 1 dakika** (s.92)
- [ ] [x] [ ] **Heavy don = 10 dakika, doff = 5 dakika** (s.92)
- [ ] [x] [ ] **Shield don/doff = Utilize action** (s.92)
- [ ] [x] [ ] **One armor + one shield at a time max** (s.92)

### 7.3 Magic Items giyim (s.103, 207)
- [ ] [x] [ ] **Worn intended fashion** — boots feet, gloves hands, hats helmets head, rings finger (s.103)
- [ ] [x] [ ] **Magic armor = donned**, shield = strapped, weapon = held (s.103)
- [ ] [x] [ ] **Auto-fits wearer (size)** — exception possible (s.207)
- [ ] [x] [ ] **Unusual anatomy** — GM discretion if usable (s.207)

### 7.4 Multiple-of-a-Kind (s.103)
- [ ] [x] [ ] **Max 1: footwear / gloves-or-gauntlets / bracers / armor / headwear / cloak** (s.103)

### 7.5 Paired Items (s.103)
- [ ] [x] [ ] **Both must be worn for benefit** — Boots/Bracers/Gloves (s.103)

### 7.6 Pact of the Blade (Warlock) (s.74)
- [ ] [x] [ ] **BA conjure pact weapon** — Simple/Martial Melee, or bind to existing (s.74)
- [ ] [x] [ ] **Cha for atk + dmg** (s.74)
- [ ] [x] [ ] **Bond ends if conjure new / 1m+ apart / die** (s.74)

### 7.7 Wild Shape Equipment (Druid) (s.43)
- [ ] [x] [ ] **Falls / merges / worn** — chosen per item per shift (s.43)
- [ ] [x] [ ] **Falls = drops to ground**; **merges = no effect**; **worn = remains usable if anatomy allows** (s.43)
- [ ] [x] [ ] **Cannot wear ill-fitting items in form** (s.43)

### 7.8 Attunement (s.102)
- [ ] [x] [ ] **Max 3 attuned items** — 4'üncü deneme = mevcut birini kes (s.102)
- [ ] [x] [ ] **Short Rest contact-only attunement** — bağımsız SR olmalı (s.102)
- [ ] [x] [ ] **Ends: voluntary SR end / 100ft + 24h / die / another attunes** (s.102)
- [ ] [x] [ ] **Cursed item = non-voluntary end** — Remove Curse gerekli (s.206)
- [ ] [x] [ ] **Cannot attune to >1 copy of same item** (s.102)

---

## 8. Spells & Spellcasting

### 8.1 Spell Levels & Slots (s.104)
- [ ] [x] [ ] **Levels 0-9** — 0 = cantrip (s.104)
- [ ] [x] [ ] **Spell slots = limited resource per LR (most classes)** (s.104)
- [ ] [x] [ ] **Casting at higher slot** — spell may scale per description (s.104)
- [ ] [x] [ ] **Cantrip = no slot, scales by character level (5/11/17)** (s.104)
- [ ] [x] [ ] **Ritual = 10 min extra, no slot, must have prepared** (s.104, 187)
- [ ] [x] [ ] **Special abilities cast without slot** — limited (e.g. species "1/LR") (s.104)
- [ ] [x] [ ] **Magic items cast without slot** — per item (s.104)

### 8.2 Preparation by Class (s.104)
- [ ] [x] [ ] **Bard: change 1 on level gain; total = features table** (s.104)
- [ ] [x] [ ] **Cleric: change any on Long Rest** (s.104)
- [ ] [x] [ ] **Druid: change any on Long Rest** (s.104)
- [ ] [x] [ ] **Paladin: change 1 on Long Rest** (s.104)
- [ ] [x] [ ] **Ranger: change 1 on Long Rest** (s.104)
- [ ] [x] [ ] **Sorcerer: change 1 on level gain** (s.104)
- [ ] [x] [ ] **Warlock: change 1 on level gain** (s.104)
- [ ] [x] [ ] **Wizard: change any on Long Rest from spellbook** (s.104)
- [ ] [x] [ ] **Always-Prepared spells don't count toward limit** (s.104)

### 8.3 Pact Magic (Warlock) (s.71)
- [ ] [x] [ ] **Separate slots from Spellcasting feature** (s.71)
- [ ] [x] [ ] **All slots same level** (table) (s.71)
- [ ] [x] [ ] **Restored on Short OR Long Rest** (s.71)
- [ ] [x] [ ] **Compatible w/ Spellcasting class slots** — cross-cast (s.26)

### 8.4 Casting Time (s.105)
- [ ] [x] [ ] **Magic action (default)** (s.105)
- [ ] [x] [ ] **Bonus Action** (per spell) (s.105)
- [ ] [x] [ ] **Reaction** (with trigger in spell) (s.105)
- [ ] [x] [ ] **1 minute / 10 minutes / longer** — Magic action each turn + Concentration (s.105)
- [ ] [x] [ ] **Ritual = +10 minutes** (s.104)

### 8.5 One Slot per Turn (s.105)
- [ ] [x] [ ] **Cannot cast 2 slot spells in same turn** (action + BA both consume slot prohibited) (s.105)

### 8.6 Components V/S/M (s.105-106)
- [ ] [x] [ ] **Verbal: chant, hands free not needed; silenced/gagged → can't** (s.105)
- [ ] [x] [ ] **Somatic: gesture, 1 free hand** (s.105)
- [ ] [x] [ ] **Material: specific item; cost-specified or consumed → must have** (s.105)
- [ ] [x] [ ] **Component Pouch substitutes free M** — must have hand free (s.105-106)
- [ ] [x] [ ] **Spellcasting Focus substitutes free M** — must hold (s.106)

### 8.7 Range (s.106)
- [ ] [x] [ ] **Self** — caster origin (s.106)
- [ ] [x] [ ] **Touch** — caster touches target (s.106)
- [ ] [x] [ ] **Distance ft** — must see / clear path (s.106)

### 8.8 Duration (s.106)
- [ ] [x] [ ] **Instantaneous** (s.106)
- [ ] [x] [ ] **Concentration** — see rules (s.106)
- [ ] [x] [ ] **Time Span** — minutes/hours; can dismiss no-action if not Incapacitated (s.106)

### 8.9 Concentration (s.179)
- [ ] [x] [ ] **Damage → Con save, DC = max(10, ½ damage), max 30** (s.179)
- [ ] [x] [ ] **Casting another C-spell breaks current** (s.179)
- [ ] [x] [ ] **Incapacitated breaks Concentration** (s.179)
- [ ] [x] [ ] **Death breaks Concentration** (s.179)
- [ ] [x] [ ] **Voluntary end any time, no action** (s.179)

### 8.10 Spell DCs & Attacks (s.106)
- [ ] [x] [ ] **Spell save DC = 8 + ability mod + PB** (s.23, 106)
- [ ] [x] [ ] **Spell attack mod = ability mod + PB** (s.23, 106)

### 8.11 Targets (s.106)
- [ ] [x] [ ] **Clear path required (Total Cover blocks)** (s.106)
- [ ] [x] [ ] **Targeting yourself = OK if not Hostile-only** (s.106)
- [ ] [x] [ ] **Invalid target → no effect, slot still used** (s.106)
- [ ] [x] [ ] **Awareness of Targeting** — perceptible effect → known; subtle → unknown (s.106)

### 8.12 Areas of Effect (s.106, 178-180, 188)
- [ ] [x] [ ] **Cone** — origin → straight lines, width = distance from origin (s.179)
- [ ] [x] [ ] **Cube** — origin on a face (s.179)
- [ ] [x] [ ] **Cylinder** — base center / top (s.180)
- [ ] [x] [ ] **Emanation** — moves with origin creature/object (s.181)
- [ ] [x] [ ] **Line** — origin → straight, length × width (s.184)
- [ ] [x] [ ] **Sphere** — radius from origin (s.188)
- [ ] [x] [ ] **Origin not in AoE unless creator decides (most)** (s.179, exception Sphere/Cylinder)
- [ ] [x] [ ] **Total Cover blocks line from origin** (s.177)

### 8.13 Combining Effects (s.106)
- [ ] [x] [ ] **Same spell, same target = most-potent only (or latest if equal)** (s.106)
- [ ] [x] [ ] **Different spells stack** — durations independent (s.106)

### 8.14 Casting in Armor (s.104)
- [ ] [x] [ ] **Need armor training to cast in armor** — yoksa cast yok (s.104)

### 8.15 Schools of Magic (s.105)
- [ ] [x] [ ] **Abjuration / Conjuration / Divination / Enchantment / Evocation / Illusion / Necromancy / Transmutation** — descriptive only (s.105)

### 8.16 Spell Scrolls (s.99)
- [ ] [x] [ ] **On class list = cast w/o slot, no M** (s.99)
- [ ] [x] [ ] **Scroll DC = 13, attack +5** (s.99)
- [ ] [x] [ ] **Scroll disintegrates after use** (s.99)
- [ ] [x] [ ] **Higher-level scrolls (Wizard Use Magic Device etc.)** — Int Arcana DC 10+lvl else lost (s.64)

### 8.17 Magic Items Casting Spells (s.206)
- [ ] [x] [ ] **Item DC + own caster level** (no slot) (s.206)
- [ ] [x] [ ] **Concentration if spell requires** (s.206)

---

## 9. Class Mechanics

### 9.1 Genel Pattern (Tüm sınıflarda)
- [ ] [x] [ ] **Subclass at L3** (most) (s.28+)
- [ ] [x] [ ] **ASI/Feat L4/8/12/16** (most) (s.28+)
- [ ] [x] [ ] **Epic Boon at L19** (s.28+, 88)

### 9.2 Barbarian (s.28-30)
- [ ] [x] [ ] **Hit Die d12, Primary Str, Saves Str+Con** (s.28)
- [ ] [x] [ ] **Rage: BA, # uses by level (2→6), no Heavy armor** (s.28-29)
- [ ] [x] [ ] **Rage effects** — Resist BPS, +Rage Damage (Str atk only), Adv Str checks/saves, no Concentration, no spells (s.29)
- [ ] [x] [ ] **Rage duration = 10 minutes; ends if Incapac / Heavy don / no extend (atk/save force/BA)** (s.29)
- [ ] [x] [ ] **Unarmored Defense = 10 + Dex + Con** (no armor; shield OK) (s.29)
- [ ] [x] [ ] **Weapon Mastery: 2 → 4 weapon kinds (level)** (s.29)
- [ ] [x] [ ] **L2 Danger Sense = adv on Dex saves vs effects you can see** (s.29)
- [ ] [x] [ ] **L2 Reckless Attack = Str atk adv, attacks vs you adv** (s.29)
- [ ] [x] [ ] **L3 Primal Knowledge = +1 skill, Rage Str-substitute on Acrobatics/Intim/Perc/Stealth/Survival** (s.29)
- [ ] [x] [ ] **L5 Extra Attack** (s.29)
- [ ] [x] [ ] **L5 Fast Movement = +10 ft Speed (no heavy armor)** (s.29)
- [ ] [x] [ ] **L7 Feral Instinct = adv on Initiative** (s.29)
- [ ] [x] [ ] **L7 Instinctive Pounce = ½ Speed during Rage BA** (s.29)
- [ ] [x] [ ] **L9 Brutal Strike = forgo adv, 1d10 extra dmg + 1 effect (Forceful/Hamstring)** (s.29)
- [ ] [x] [ ] **L11 Relentless Rage = Con save DC 10 (escalating +5) → 2×lvl HP at 0 HP if Rage active** (s.30)
- [ ] [x] [ ] **L13 Improved Brutal Strike = +Staggering Blow / Sundering Blow** (s.30)
- [ ] [x] [ ] **L15 Persistent Rage = init regain Rage uses, 10m duration auto** (s.30)
- [ ] [x] [ ] **L17 Improved Brutal Strike = 2d10, 2 effects** (s.30)
- [ ] [x] [ ] **L18 Indomitable Might = Str check/save min = Str score** (s.30)
- [ ] [x] [ ] **L20 Primal Champion = Str/Con +4, max 25** (s.30)

### 9.3 Bard (s.31-35)
- [ ] [x] [ ] **Hit Die d8, Primary Cha, Saves Dex+Cha** (s.31)
- [ ] [x] [ ] **Bardic Inspiration: BA, d6→d12 (lvl 5/10/15), # = Cha mod (min 1), LR restore** (s.32)
- [ ] [x] [ ] **Spellcasting (Cha), 4 cantrips L1, change 1 on level** (s.32)
- [ ] [x] [ ] **L2 Expertise (2 skills)** (s.32)
- [ ] [x] [ ] **L2 Jack of All Trades = ½ PB on non-prof checks** (s.32)
- [ ] [x] [ ] **L5 Font of Inspiration = restore on SR/LR; spend slot to regain BI use** (s.32)
- [ ] [x] [ ] **L7 Counter charm = Reaction reroll w/ adv vs Charmed/Frightened (within 30ft)** (s.33)
- [ ] [x] [ ] **L9 Expertise (+2 skills)** (s.32)
- [ ] [x] [ ] **L10 Magical Secrets** — choose any new prepared from Bard/Cleric/Druid/Wizard list (s.33)
- [ ] [x] [ ] **L18 Superior Inspiration = init regain BI to min 2** (s.33)
- [ ] [x] [ ] **L20 Words of Creation** — always Power Word Heal + Power Word Kill, double-target if within 10ft (s.33)

### 9.4 Cleric (s.36-40)
- [ ] [x] [ ] **Hit Die d8, Primary Wis, Saves Wis+Cha** (s.36)
- [ ] [x] [ ] **Spellcasting (Wis), prepare any from Cleric list on LR** (s.37)
- [ ] [x] [ ] **L1 Divine Order: Protector (Martial+Heavy) or Thaumaturge (+1 cantrip + Int bonus on Arcana/Religion)** (s.37)
- [ ] [x] [ ] **L2 Channel Divinity (2 uses, SR/LR restore)** (s.37)
- [ ] [x] [ ] **CD: Divine Spark = Magic action, 1d8+Wis heal-or-Necrotic/Radiant DC** scales 7/13/18 (+d8) (s.37)
- [ ] [x] [ ] **CD: Turn Undead = 30ft, Wis save fail → Frightened+Incapac, flee 1m** (s.37)
- [ ] [x] [ ] **L5 Sear Undead = Turn → +# d8 Radiant** (Wis mod) (s.37)
- [ ] [x] [ ] **L7 Blessed Strikes** — Divine Strike (1d8 Necrotic/Radiant 1/turn) OR Potent Spellcasting (+Wis to cantrip dmg) (s.38)
- [ ] [x] [ ] **L10 Divine Intervention = Magic action, cast any Cleric spell ≤L5 free, 1/LR** (s.38)
- [ ] [x] [ ] **L14 Improved Blessed Strikes = 2d8** (s.38)
- [ ] [x] [ ] **L20 Greater Divine Intervention = cast Wish; 2d4 LRs** (s.38)
- [ ] [x] [ ] **CD DC = spell save DC** (s.37)

### 9.5 Druid (s.41-46)
- [ ] [x] [ ] **Hit Die d8, Primary Wis, Saves Int+Wis** (s.41)
- [ ] [x] [ ] **Spellcasting (Wis), prepare any on LR** (s.42)
- [ ] [x] [ ] **L1 Druidic = secret language; auto-prepare Speak with Animals** (s.42)
- [ ] [x] [ ] **L1 Primal Order: Magician (+1 cantrip + Int Arcana/Nature) or Warden (Martial+Medium)** (s.42)
- [ ] [x] [ ] **L2 Wild Shape: BA, 2 uses (SR restore 1, LR all); CR ¼ at L2, ½ at L4, 1 at L8 + Fly Speed** (s.42)
- [ ] [x] [ ] **WS forms: known forms, swap on LR** (s.42)
- [ ] [x] [ ] **WS rules: temp HP = lvl, retain personality+memory+abilities, no spells (don't break Conc), equipment fall/merge/wear** (s.43)
- [ ] [x] [ ] **L2 Wild Companion = WS use → Find Familiar (Fey, vanish on LR)** (s.43)
- [ ] [x] [ ] **L5 Wild Resurgence = no WS uses → spell slot grants 1 use; expend slot ≤L1 → 1 WS use 1/LR** (s.43)
- [ ] [x] [ ] **L7 Elemental Fury** — Potent Spellcasting (+Wis to cantrip dmg) OR Primal Strike (+1d8 cold/fire/light/thunder on weapon/WS atk) (s.43)
- [ ] [x] [ ] **L15 Improved Elemental Fury = +2d8 / range +300ft** (s.43)
- [ ] [x] [ ] **L18 Beast Spells = cast spells in Wild Shape (M cost still required)** (s.43)
- [ ] [x] [ ] **L20 Archdruid: WS regain on init; convert WS uses→slots (2 levels each, max L4); slow aging** (s.43)

### 9.6 Fighter (s.47-49)
- [ ] [x] [ ] **Hit Die d10, Primary Str/Dex, Saves Str+Con** (s.47)
- [ ] [x] [ ] **L1 Fighting Style (feat)** (s.47)
- [ ] [x] [ ] **L1 Second Wind: BA, 1d10+lvl HP, 2 uses (SR restore 1)** (s.48)
- [ ] [x] [ ] **L1 Weapon Mastery (3→6 kinds)** (s.48)
- [ ] [x] [ ] **L2 Action Surge: 1 extra action (not Magic), 1/SR or LR; 2/SR L17** (s.48)
- [ ] [x] [ ] **L2 Tactical Mind = Second Wind on failed check → reroll (no HP if pass)** (s.48)
- [ ] [x] [ ] **L5 Extra Attack** (s.48)
- [ ] [x] [ ] **L5 Tactical Shift = Second Wind BA → ½ Speed no OA** (s.48)
- [ ] [x] [ ] **L9 Indomitable: failed save → reroll +lvl, 1/LR (2 L13, 3 L17)** (s.48)
- [ ] [x] [ ] **L9 Tactical Master = swap Mastery property (Push/Sap/Slow)** (s.48)
- [ ] [x] [ ] **L11 Two Extra Attacks (3 total)** (s.48)
- [ ] [x] [ ] **L13 Studied Attacks = miss → adv next attack vs target** (s.48)
- [ ] [x] [ ] **L20 Three Extra Attacks (4 total)** (s.48)

### 9.7 Monk (s.49-52)
- [ ] [x] [ ] **Hit Die d8, Primary Dex+Wis, Saves Str+Dex** (s.49)
- [ ] [x] [ ] **L1 Martial Arts: Unarmed/Monk weapons; BA Unarmed Strike; Dex for atk+dmg; d6→d12 die (lvl 5/11/17)** (s.50)
- [ ] [x] [ ] **L1 Unarmored Defense = 10+Dex+Wis** (no armor/shield) (s.50)
- [ ] [x] [ ] **L2 Focus Points = Monk lvl, SR/LR restore** (s.50)
- [ ] [x] [ ] **Flurry of Blows = 1 FP → 2 Unarmed (3 at L10)** (s.50)
- [ ] [x] [ ] **Patient Defense = 1 FP → Disengage+Dodge BA** (s.50, 51)
- [ ] [x] [ ] **Step of the Wind = 1 FP → Dash+Disengage BA, jump ×2** (s.50)
- [ ] [x] [ ] **L2 Unarmored Movement = +10/15/20/25/30 ft (lvl 2/6/10/14/18)** (s.51)
- [ ] [x] [ ] **L2 Uncanny Metabolism = init regain all FP + 1d6+lvl HP, 1/LR** (s.51)
- [ ] [x] [ ] **L3 Deflect Attacks = Reaction reduce damage 1d10+Dex+lvl** (s.51)
- [ ] [x] [ ] **L4 Slow Fall = Reaction reduce fall by 5×lvl** (s.51)
- [ ] [x] [ ] **L5 Extra Attack** (s.51)
- [ ] [x] [ ] **L5 Stunning Strike: 1 FP, Con save fail → Stunned 1 turn (1/turn)** (s.51)
- [ ] [x] [ ] **L6 Empowered Strikes = Force damage option** (s.51)
- [ ] [x] [ ] **L7 Evasion = Dex save half → 0 / fail → half** (s.51)
- [ ] [x] [ ] **L9 Acrobatic Movement = walk vertical/liquid** (s.51)
- [ ] [x] [ ] **L10 Heightened Focus = Flurry 3 strikes, etc.** (s.51)
- [ ] [x] [ ] **L13 Deflect Energy = any damage type** (s.52)
- [ ] [x] [ ] **L14 Disciplined Survivor = save reroll 1 FP** (s.52)
- [ ] [x] [ ] **L15 Perfect Focus = init recover FP to 4 if ≤3** (s.52)
- [ ] [x] [ ] **L18 Superior Defense = 3 FP, Resist all (except Force) 1m** (s.52)
- [ ] [x] [ ] **L20 Body and Mind = Dex+Wis +4 max 25** (s.52)

### 9.8 Paladin (s.53-56)
- [ ] [x] [ ] **Hit Die d10, Primary Str+Cha, Saves Wis+Cha** (s.53)
- [ ] [x] [ ] **L1 Lay on Hands = pool 5×lvl HP, BA touch heal; 5 HP cure Poisoned** (s.53-54)
- [ ] [x] [ ] **Spellcasting (Cha), half-caster, prepare any** (s.54)
- [ ] [x] [ ] **L2 Fighting Style (or Blessed Warrior = 2 Cleric cantrips)** (s.54)
- [ ] [x] [ ] **L2 Paladin's Smite = always-prep Divine Smite; 1/LR free** (s.54)
- [ ] [x] [ ] **L3 Channel Divinity (2 uses, SR/LR; +1 at L11)** (s.54)
- [ ] [x] [ ] **CD: Divine Sense = BA, detect Cele/Fiend/Undead 60ft 10m** (s.55)
- [ ] [x] [ ] **L5 Extra Attack** (s.55)
- [ ] [x] [ ] **L5 Faithful Steed = always-prep Find Steed, 1/LR free cast** (s.55)
- [ ] [x] [ ] **L6 Aura of Protection = +Cha to allies' saves (10ft, 30ft L18)** (s.55)
- [ ] [x] [ ] **L9 Abjure Foes = CD, Frightened 1m or until dmg, # = Cha** (s.55)
- [ ] [x] [ ] **L10 Aura of Courage = Frightened immunity for self+allies in aura** (s.55)
- [ ] [x] [ ] **L11 Radiant Strikes = +1d8 Radiant on melee weapon/Unarmed** (s.55)
- [ ] [x] [ ] **L14 Restoring Touch = Lay on Hands removes Blinded/Charmed/Deafened/Frightened/Paralyzed/Stunned (5 HP each)** (s.55)
- [ ] [x] [ ] **L18 Aura Expansion (30ft)** (s.55)

### 9.9 Ranger (s.57-60)
- [ ] [x] [ ] **Hit Die d10, Primary Dex+Wis, Saves Str+Dex** (s.57)
- [ ] [x] [ ] **Spellcasting (Wis), half-caster, prepare any** (s.57-58)
- [ ] [x] [ ] **L1 Favored Enemy = always-prep Hunter's Mark, 2 free uses (LR)** (s.58)
- [ ] [x] [ ] **L1 Weapon Mastery (2 kinds)** (s.58)
- [ ] [x] [ ] **L2 Deft Explorer = Expertise 1 skill + 2 languages** (s.59)
- [ ] [x] [ ] **L2 Fighting Style or Druidic Warrior (2 Druid cantrips)** (s.59)
- [ ] [x] [ ] **L5 Extra Attack** (s.59)
- [ ] [x] [ ] **L6 Roving = +10 Speed (no Heavy), Climb+Swim Speeds** (s.59)
- [ ] [x] [ ] **L9 Expertise (+2)** (s.59)
- [ ] [x] [ ] **L10 Tireless = BA temp HP 1d8+Wis (#=Wis); SR ends 1 Exhaustion** (s.59)
- [ ] [x] [ ] **L13 Relentless Hunter = damage doesn't break Conc on Hunter's Mark** (s.59)
- [ ] [x] [ ] **L14 Nature's Veil = BA Invisible 1 turn (#=Wis, LR)** (s.59)
- [ ] [x] [ ] **L17 Precise Hunter = adv on attacks vs HM target** (s.59)
- [ ] [x] [ ] **L18 Feral Senses = Blindsight 30ft** (s.59)
- [ ] [x] [ ] **L20 Foe Slayer = HM die d10** (s.59)

### 9.10 Rogue (s.61-64)
- [ ] [x] [ ] **Hit Die d8, Primary Dex, Saves Dex+Int** (s.61)
- [ ] [x] [ ] **L1 Expertise (2 skills)** (s.61)
- [ ] [x] [ ] **L1 Sneak Attack: 1d6 → 10d6 (every odd lvl); req Adv on attack OR ally adjacent (no Disadv); Finesse/Ranged** (s.61-62)
- [ ] [x] [ ] **L1 Thieves' Cant** (s.62)
- [ ] [x] [ ] **L1 Weapon Mastery (2 Finesse/Light)** (s.62)
- [ ] [x] [ ] **L2 Cunning Action: Dash/Disengage/Hide as BA** (s.62)
- [ ] [x] [ ] **L3 Steady Aim = BA grant adv on next atk; Speed 0 turn-end (no move this turn)** (s.62)
- [ ] [x] [ ] **L5 Cunning Strike: spend SA dice for effects (Poison 1d6, Trip 1d6, Withdraw 1d6 → poisoned/prone/move w/o OA)** (s.63)
- [ ] [x] [ ] **L5 Uncanny Dodge = Reaction half attack damage** (s.63)
- [ ] [x] [ ] **L6 Expertise (+2)** (s.63)
- [ ] [x] [ ] **L7 Evasion** (s.63)
- [ ] [x] [ ] **L7 Reliable Talent = prof skill check ≤9 → 10** (s.63)
- [ ] [x] [ ] **L11 Improved Cunning Strike = 2 effects** (s.63)
- [ ] [x] [ ] **L14 Devious Strikes = Daze 2d6 / Knock Out 6d6 / Obscure 3d6** (s.63)
- [ ] [x] [ ] **L15 Slippery Mind = Wis+Cha save prof** (s.63)
- [ ] [x] [ ] **L18 Elusive = no atk has adv vs you unless Incapac** (s.63)
- [ ] [x] [ ] **L20 Stroke of Luck = fail D20 → 20; 1/SR or LR** (s.63)

### 9.11 Sorcerer (s.64-66)
- [ ] [x] [ ] **Hit Die d6, Primary Cha, Saves Con+Cha** (s.64)
- [ ] [x] [ ] **Spellcasting (Cha)** (s.64-65)
- [ ] [x] [ ] **L1 Innate Sorcery: BA, +1 spell DC + adv attack 1m, 2 uses LR** (s.65-66)
- [ ] [x] [ ] **L2 Font of Magic = Sorcery Points (= lvl)** (s.66)
- [ ] [x] [ ] **Slot↔SP convert: spend slot → SP = lvl; create slot from SP (table 2/3/5/6/7 SP for L1/2/3/4/5)** (s.66)
- [ ] [x] [ ] **L2 Metamagic (2 options, +2 L10, +2 L17)** (s.66)
- [ ] [x] [ ] **Metamagic costs SP** (s.66)
- [ ] [x] [ ] **L5 Sorcerous Restoration = SR regain ½ lvl SP, 1/LR** (s.66)
- [ ] [x] [ ] **L7 Sorcery Incarnate = 2 SP activate Innate Sorcery if no uses; +2 Metamagic on each spell** (s.66)
- [ ] [x] [ ] **L20 Arcane Apotheosis = Innate Sorcery active → 1 free Metamagic per turn** (s.66)
- [ ] [x] [ ] **8 Metamagic options** — Careful, Distant, Empowered, Extended, Heightened, Quickened, Subtle, Twinned (full descriptions in SRD) (s.66+)

### 9.12 Warlock (s.70-74)
- [ ] [x] [ ] **Hit Die d8, Primary Cha, Saves Wis+Cha** (s.70)
- [ ] [x] [ ] **Pact Magic: separate slots, all-same-level (1→9 by level), SR/LR restore** (s.71)
- [ ] [x] [ ] **L1 Eldritch Invocations** — 1 → 10 by level; replace 1 on level gain (s.70-71)
- [ ] [x] [ ] **L2 Magical Cunning = 1 minute rite → ½ max Pact slots (LR)** (s.72)
- [ ] [x] [ ] **L9 Contact Patron = always-prep Contact Other Plane, free 1/LR auto-success** (s.72)
- [ ] [x] [ ] **L11 Mystic Arcanum** — L6 spell, free 1/LR (LR cooldown); +L7 at 13, L8 at 15, L9 at 17 (s.72)
- [ ] [x] [ ] **L20 Eldritch Master = Magical Cunning regen all Pact slots** (s.72)
- [ ] [x] [ ] **Common Invocations** — Agonizing Blast, Devil's Sight, Eldritch Spear, Pact of the Blade/Chain/Tome, Repelling Blast, Thirsting Blade (Extra Attack), Devouring Blade (3 atk), Lifedrinker (necrotic+self-heal), etc. (s.72-74)

### 9.13 Wizard (s.77-82)
- [ ] [x] [ ] **Hit Die d6, Primary Int, Saves Int+Wis** (s.77)
- [ ] [x] [ ] **Spellcasting (Int), prepare from Spellbook on LR** (s.78)
- [ ] [x] [ ] **Spellbook: 6 starting L1 spells; +2 per level gain; copy spell 50 GP + 2h per level** (s.78)
- [ ] [x] [ ] **Copy spellbook to new = 1h + 10 GP per level** (s.78)
- [ ] [x] [ ] **L1 Ritual Adept = ritual cast any from spellbook (no prep)** (s.78)
- [ ] [x] [ ] **L1 Arcane Recovery = SR regain slots ≤½ lvl (round up), max L5; 1/LR** (s.78)
- [ ] [x] [ ] **L2 Scholar = Expertise on 1 of Arcana/History/Investigation/Medicine/Nature/Religion** (s.78)
- [ ] [x] [ ] **L5 Memorize Spell = SR replace 1 prep w/ another spellbook spell** (s.79)
- [ ] [x] [ ] **L18 Spell Mastery: 1 L1 + 1 L2 cast at-will** (s.79)
- [ ] [x] [ ] **L20 Signature Spells: 2 L3, free 1/SR or LR each** (s.79)

---

## 10. Origin (Background + Species)

### 10.1 Background Parts (s.83)
- [ ] [x] [ ] **3 ability scores listed** — bump +2/+1 OR +1/+1/+1 (max 20) (s.83)
- [ ] [x] [ ] **Origin Feat** (s.83)
- [ ] [x] [ ] **2 skill proficiencies** (s.83)
- [ ] [x] [ ] **1 tool proficiency** (s.83)
- [ ] [x] [ ] **Equipment package OR 50 GP** (s.83)

### 10.2 Backgrounds (s.83)
- [ ] [x] [ ] **Acolyte** — Int/Wis/Cha; Magic Initiate (Cleric); Insight+Religion; Calligrapher's (s.83)
- [ ] [x] [ ] **Criminal** — Dex/Con/Int; Alert; Sleight of Hand+Stealth; Thieves' Tools (s.83)
- [ ] [x] [ ] **Sage** — Con/Int/Wis; Magic Initiate (Wizard); Arcana+History; Calligrapher's (s.83)
- [ ] [x] [ ] **Soldier** — Str/Dex/Con; Savage Attacker; Athletics+Intimidation; Gaming Set (s.83)

### 10.3 Species Parts (s.83-84)
- [ ] [x] [ ] **Creature Type (Humanoid)** (s.83)
- [ ] [x] [ ] **Size (Tiny→Medium)** (s.84)
- [ ] [x] [ ] **Speed** (s.84)
- [ ] [x] [ ] **Special Traits** (s.84)

### 10.4 Species (9) (s.84-86)
- [ ] [x] [ ] **Dragonborn** — Medium 30ft; Draconic Ancestry (10 dragons → dmg type); Breath Weapon 15ft Cone or 30ft Line (1d10→4d10); Damage Resistance; Draconic Flight L5 (Speed Fly 10m, 1/LR) (s.84)
- [ ] [x] [ ] **Dwarf** — Medium 30ft; Darkvision 120; Dwarven Resilience (Poison resist + adv save); Dwarven Toughness (+1 HP/lvl); Stonecunning (BA Tremorsense 60ft 10m, # = PB) (s.84)
- [ ] [x] [ ] **Elf** — Medium 30ft; Darkvision 60; Elven Lineage (Drow/High/Wood spells); Fey Ancestry (adv vs Charmed); Keen Senses (Insight/Perception/Survival prof); Trance (4h LR) (s.84-85)
- [ ] [x] [ ] **Gnome** — Small 30ft; Darkvision 60; Gnomish Cunning (Int/Wis/Cha save adv); Gnomish Lineage (Forest/Rock); Forest = Minor Illusion + Speak with Animals; Rock = Mending + Prestidig + Tinker (s.85)
- [ ] [x] [ ] **Goliath** — Medium 35ft; Giant Ancestry (Cloud/Fire/Frost/Hill/Stone/Storm — # = PB, SR/LR restore); Large Form L5 (BA, 10m); Powerful Build (1 size larger carry, adv vs Grappled escape) (s.85-86)
- [ ] [x] [ ] **Halfling** — Small 30ft; Brave (adv vs Frightened); Halfling Nimbleness (move thru larger creatures); Luck (reroll nat 1); Naturally Stealthy (Hide vs larger creature obscure) (s.86)
- [ ] [x] [ ] **Human** — Medium/Small 30ft; Resourceful (Heroic Inspiration on LR); Skillful (1 skill prof); Versatile (Origin feat) (s.86)
- [ ] [x] [ ] **Orc** — Medium 30ft; Adrenaline Rush (BA Dash + temp HP = PB; # = PB SR/LR); Darkvision 120; Relentless Endurance (drop to 1 HP instead of 0, 1/LR) (s.86)
- [ ] [x] [ ] **Tiefling** — Med/Small 30ft; Darkvision 60; Fiendish Legacy (Abyssal/Chthonic/Infernal — resist + cantrip + L3/L5 spells); Otherworldly Presence (Thaumaturgy cantrip) (s.86)

### 10.5 Languages (s.20)
- [ ] [x] [ ] **Common (everyone)** (s.20)
- [ ] [x] [ ] **+2 Standard** — Common Sign Language, Draconic, Dwarvish, Elvish, Giant, Gnomish, Goblin, Halfling, Orc (s.20)
- [ ] [x] [ ] **Rare requires feature** — Abyssal, Celestial, Deep Speech, Druidic, Infernal, Primordial (Aquan/Auran/Ignan/Terran), Sylvan, Thieves' Cant, Undercommon (s.20)

---

## 11. Feats

### 11.1 Categories (s.87)
- [ ] [x] [ ] **Origin / General / Fighting Style / Epic Boon** (s.87)
- [ ] [x] [ ] **Prerequisite required** (s.87)
- [ ] [x] [ ] **Feat once unless Repeatable** (s.87)

### 11.2 Origin Feats (s.87)
- [ ] [x] [ ] **Alert** — Init = +PB; Initiative Swap with willing ally (s.87)
- [ ] [x] [ ] **Magic Initiate (Cleric/Druid/Wizard)** — 2 cantrips + 1 L1 spell free 1/LR (s.87)
- [ ] [x] [ ] **Savage Attacker** — 1/turn reroll weapon damage, take higher (s.87)
- [ ] [x] [ ] **Skilled** — 3 skill OR tool profs; Repeatable (s.87)
- [ ] [x] [ ] **Lucky** (in SRD as separate; consult PDF) — reroll D20 (s.87)
- [ ] [x] [ ] **Tough** (s.87)
- [ ] [x] [ ] **Tavern Brawler** (s.87)
- [ ] [x] [ ] **Healer** (s.87)
- [ ] [x] [ ] **Musician** (s.87)
- [ ] [x] [ ] **Crafter** (s.87)

### 11.3 General Feats (L4+) (s.87)
- [ ] [x] [ ] **Ability Score Improvement** — +2 one or +1+1 (max 20); Repeatable (s.87)
- [ ] [x] [ ] **Grappler** — +1 Str/Dex; Punch+Grab (Unarmed → dmg + grapple); adv vs Grappled-by-you; Fast Wrestler (no extra move cost moving Grappled) (s.87)

### 11.4 Fighting Style (s.87-88)
- [ ] [x] [ ] **Archery** — +2 ranged atk (s.87)
- [ ] [x] [ ] **Defense** — +1 AC if Light/Med/Heavy (s.88)
- [ ] [x] [ ] **Great Weapon Fighting** — reroll 1-2 dmg dice for 2H/Versatile (s.88)
- [ ] [x] [ ] **Two-Weapon Fighting** — add ability mod to off-hand damage (Light) (s.88)

### 11.5 Epic Boon (L19+) (s.88)
- [ ] [x] [ ] **Boon of Combat Prowess** — +1 Str/Dex (max 30); miss → hit instead, 1/turn (s.88)
- [ ] [x] [ ] **Boon of Dimensional Travel** — +1 ability (max 30); Blink Steps 30ft teleport with Atk/Magic (s.88)
- [ ] [x] [ ] **Boon of Fate** — +1 ability (max 30); 60ft, save/check by anyone → 2d4 bonus/penalty 1/SR-LR (s.88)
- [ ] [x] [ ] **Boon of Irresistible Offense** — +1 Str/Dex (max 30); BPS dmg always ignore Resistance; nat 20 atk → +ability bonus dmg (s.88)
- [ ] [x] [ ] **Boon of Spell Recall** — +1 Int/Wis/Cha (max 30); slot 1-4 → 1d4 = level → slot not expended (s.88)
- [ ] [x] [ ] **Boon of the Night Spirit** — +1 ability (max 30); Dim/Dark BA Invisible until act/BA/Reaction; resist all except Psychic/Radiant in Dim/Dark (s.88)
- [ ] [x] [ ] **Boon of Truesight** — +1 ability (max 30); Truesight 60ft (s.88)

---

## 12. Magic Items

### 12.1 Categories (9) (s.204)
- [ ] [x] [ ] **Armor / Potions / Rings / Rods / Scrolls / Staffs / Wands / Weapons / Wondrous** (s.204)

### 12.2 Rarity & Value (s.205-206)
- [ ] [x] [ ] **Common 100 GP** (s.206)
- [ ] [x] [ ] **Uncommon 400 GP** (s.206)
- [ ] [x] [ ] **Rare 4000 GP** (s.206)
- [ ] [x] [ ] **Very Rare 40000 GP** (s.206)
- [ ] [x] [ ] **Legendary 200000 GP** (s.206)
- [ ] [x] [ ] **Artifact priceless** (s.206)
- [ ] [x] [ ] **Consumable = ½ value (except Spell Scroll = 2× scribe cost)** (s.206)
- [ ] [x] [ ] **Magic on existing item adds item base cost** (s.205-206)

### 12.3 Identification (s.102)
- [ ] [x] [ ] **Identify spell (fastest, no curse)** (s.102)
- [ ] [x] [ ] **Short Rest + contact = properties revealed (no curse)** (s.102)
- [ ] [x] [ ] **Tasting potion / wearing item — clues** (s.102)

### 12.4 Attunement (s.102)
- [ ] [x] [ ] **Max 3 items at once** (s.102)
- [ ] [x] [ ] **Short Rest contact only** (s.102)
- [ ] [x] [ ] **Cursed = non-voluntary end** (s.206)
- [ ] [x] [ ] **Class-prereq = must be that class** (s.205)
- [ ] [x] [ ] **Spellcaster-prereq = can cast ≥1 spell from class features** (s.205)

### 12.5 Activation (s.206)
- [ ] [x] [ ] **Magic action default** (s.206)
- [ ] [x] [ ] **Command Word** — audible, blocked by Silence (s.206)
- [ ] [x] [ ] **Consumable** — used up (s.206)
- [ ] [x] [ ] **Spells from Items** — no slot, item DC, item caster level, normal time/range/duration (s.206)
- [ ] [x] [ ] **Charges** — Identify reveals; "next dawn" recharge (s.206)

### 12.6 Crafting (s.206-207)
- [ ] [x] [ ] **Arcana proficiency** (s.206)
- [ ] [x] [ ] **Tools per category** — Armor: Leather/Smith/Weaver, Potion: Alch/Herbalism, Ring: Jeweler, Rod/Staff/Wand: Woodcarver, Scroll: Calligrapher, Weapon: Leather/Smith/Woodcarver, Wondrous: Tinker (s.207)
- [ ] [x] [ ] **Cost/Time table** — Common 5d/50gp, Uncommon 10d/200gp, Rare 50d/2000gp, Very Rare 125d/20000gp, Legendary 250d/100000gp (s.207)
- [ ] [x] [ ] **Raw materials = list cost** (s.207)
- [ ] [x] [ ] **Existing item incorporated → pay/craft base too** (s.207)
- [ ] [x] [ ] **Spell from item → caster prepared all spells daily during crafting** (s.207)

### 12.7 Sentient Items (s.207-208)
- [ ] [x] [ ] **Int/Wis/Cha scores (4d6 drop low)** (s.207)
- [ ] [x] [ ] **Alignment + Communication + Senses + Special Purpose** (s.207-208)
- [ ] [x] [ ] **Conflict: Cha save DC = 12 + item Cha mod** — fail = item demands (s.208)
- [ ] [x] [ ] **Item demands**: Chase My Dreams / Get Rid of It / Time for Change / Keep Me Close (s.208)
- [ ] [x] [ ] **Refusal consequences** — block attune / suppress / take control (Charmed 1d12h, can resist on damage) (s.208)

### 12.8 Cursed Items (s.206)
- [ ] [x] [ ] **Curse only revealed by certain methods (or never)** (s.206)
- [ ] [x] [ ] **Remove Curse spell ends curse** (s.206)
- [ ] [x] [ ] **Cursed attunement non-voluntary** (s.206)

### 12.9 Magic Item Resilience (s.206)
- [ ] [x] [ ] **Magic items Resist all damage** (potions/scrolls excluded) (s.206)
- [ ] [x] [ ] **Artifacts only destroyed by special method** (s.206)

### 12.10 Wearing Limits (s.103)
- [ ] [x] [ ] **1 footwear, 1 gloves/gauntlets, 1 bracers, 1 armor, 1 headwear, 1 cloak max** (s.103)
- [ ] [x] [ ] **Paired items both worn** (s.103)

### 12.11 Potion Miscibility (s.204)
- [ ] [x] [ ] **Mix 2+ potions → roll d100** (s.204)
- [ ] [x] [ ] **01: 4d10 Force explosion** (s.204)
- [ ] [x] [ ] **02-08: ingested poison** (s.204)
- [ ] [x] [ ] **09-15: both lose effect** (s.204)
- [ ] [x] [ ] **16-25: one loses** (s.204)
- [ ] [x] [ ] **26-35: half effect/duration** (s.204)
- [ ] [x] [ ] **36-90: normal** (s.204)
- [ ] [x] [ ] **91-99: doubled** (s.204)
- [ ] [x] [ ] **00: permanent (one)** (s.204)

---

## 13. Hazards & Environment

### 13.1 Burning (s.178)
- [ ] [x] [ ] **1d4 Fire dmg / start of turn until extinguished** (s.178)
- [ ] [x] [ ] **Action: Prone + roll = extinguish** (s.178)
- [ ] [x] [ ] **Doused / submerged / suffocated extinguishes** (s.178)

### 13.2 Falling (s.182)
- [ ] [x] [ ] **1d6 / 10ft, max 20d6** (s.182)
- [ ] [x] [ ] **Prone unless avoided damage** (s.182)
- [ ] [x] [ ] **Falls into water/liquid → DC 15 Athletics/Acrobatics → ½ dmg** (s.182)

### 13.3 Dehydration (s.181)
- [ ] [x] [ ] **Water Needs/Day**: Tiny ¼ gal, Small/Med 1 gal, Large 4, Huge 16, Garg 64 (s.181)
- [ ] [x] [ ] **<½ daily water → 1 Exhaustion at day end** (s.181)
- [ ] [x] [ ] **Dehydration Exhaustion can't be removed until full water consumed** (s.181)

### 13.4 Malnutrition (s.185)
- [ ] [x] [ ] **Food Needs/Day**: Tiny ¼ lb, Small/Med 1 lb, Large 4, Huge 16, Garg 64 (s.185)
- [ ] [x] [ ] **<½ daily food → DC 10 Con save or 1 Exhaustion** (s.185)
- [ ] [x] [ ] **5 days no food → auto 1 Exh per day** (s.185)
- [ ] [x] [ ] **Malnutrition Exhaustion can't be removed until full food consumed** (s.185)

### 13.5 Suffocation (s.189)
- [ ] [x] [ ] **Hold breath = Con mod minutes (min 30s)** (s.189)
- [ ] [x] [ ] **Out of breath → 1 Exh / turn** (s.189)
- [ ] [x] [ ] **Restored breath removes suffocation Exh** (s.189)

### 13.6 Environmental Effects (s.195)
- [ ] [x] [ ] **Deep Water (>100 ft)** — DC 10 Con/h or 1 Exh (no Swim Speed) (s.195)
- [ ] [x] [ ] **Extreme Cold (≤0°F)** — DC 10 Con/h or 1 Exh; Cold Resist auto-pass (s.195)
- [ ] [x] [ ] **Extreme Heat (≥100°F, no water)** — DC 5+1/h Con or 1 Exh; Heavy/Med armor disadv; Fire Resist auto-pass (s.195)
- [ ] [x] [ ] **Frigid Water** — Con score minutes; then DC 10 Con/min or 1 Exh; Cold Resist auto-pass (s.195)
- [ ] [x] [ ] **Heavy Precipitation** — Lightly Obscured + disadv Wis (Perception); extinguish flames (s.195)
- [ ] [x] [ ] **High Altitude (≥10000 ft)** — 1h = 2h travel; acclimate after 30 days; cap 20000 ft (s.195)
- [ ] [x] [ ] **Slippery Ice** — Difficult Terrain; DC 10 Dex or Prone on first move/start (s.195)
- [ ] [x] [ ] **Strong Wind** — disadv ranged attacks; extinguish flame; flying must land or fall; sandstorm disadv Wis Perception (s.195)
- [ ] [x] [ ] **Thin Ice** — 3d10×10 lb / 10ft sq; over → break (s.195)

### 13.7 Curses (s.193)
- [ ] [x] [ ] **Bestow Curse benchmarks**: 1m=L3, until-dispelled=L9 (s.193)
- [ ] [x] [ ] **Cursed Creatures** — werewolves spread (s.193)
- [ ] [x] [ ] **Cursed Magic Items** — by description (s.193)
- [ ] [x] [ ] **Narrative Curses** — symbolic righting required (s.193)
- [ ] [x] [ ] **Demonic Possession** — DC 15 Cha save or possessed; nat 1 → demon controls; LR end save (s.193)

### 13.8 Magical Contagions (s.194)
- [ ] [x] [ ] **Cackle Fever** — Humanoids (gnome immune); Fever 1 Exh + Uncontrollable Laughter on dmg DC 13; LR DC 13 ×3 → cure 1y (s.194)
- [ ] [x] [ ] **Sewer Plague** — Fatigue +Weakness (½ HP from HD) +Restlessness (no LR HP/Exh recover); daily DC 11 Con (s.194)
- [ ] [x] [ ] **Sight Rot** — DC 15 Con or Blinded; Heal/Lesser Restoration cure; ointment x3 daily 24h cure (s.194)
- [ ] [x] [ ] **Recuperation: 3 days no LR-interrupt → DC 15 Con; success = adv 24h** (s.194)

### 13.9 Fear & Mental Stress (s.196)
- [ ] [x] [ ] **Fear DC examples**: harmless apparition 10, fear-trap 15, Abyss portal 20 (s.196)
- [ ] [x] [ ] **Frightened condition + extra effects (Dash away, attacks vs adv, BA limits)** (s.196)
- [ ] [x] [ ] **Mental Stress = Psychic damage; Wis save (sometimes Int/Cha)** (s.196)
- [ ] [x] [ ] **Sample stress DCs**: hallucinogen DC 10/1d6, fiendish idol DC 15/3d6, Far Realm DC 20/9d6 (s.196)
- [ ] [x] [ ] **Prolonged effects**: Short-term (1d10m Frightened/Incapac/Stunned), Long-term (1d10×10h disadv), Indefinite (Greater Restoration only) (s.196)

### 13.10 Poison (s.197-198)
- [ ] [x] [ ] **4 types**: Contact, Ingested, Inhaled, Injury (s.197)
- [ ] [x] [ ] **Purchase: criminal contacts / illicit dealer** (s.197)
- [ ] [x] [ ] **Harvest: dead/Incapac creature, DC 20 Int (Nature) Poisoner's Kit, fail by 5 → exposed** (s.197)
- [ ] [x] [ ] **Sample poisons**: Assassin's Blood 150gp / Burnt Othur Fumes 500 / Crawler Mucus 200 / Essence of Ether 300 / Malice 250 / Midnight Tears 1500 / Oil of Taggit 400 / Pale Tincture 250 / Purple Worm Poison 2000 / Serpent Venom 200 / Spider's Sting 200 / Torpor 600 / Truth Serum 150 / Wyvern Poison 1200 (s.197-198)

### 13.11 Traps (s.199-201)

Trap'lar tek-kullanımlık olabilir veya tetikleyici sıfırlanır. Her trap için **severity** (Nuisance / Deadly) + **level range** + base damage tanımlıdır; "At Higher Levels" tablosu ile aynı trap daha yüksek level partileri için scale edilir.

**Genel:**
- [ ] [x] [ ] **Severity: Nuisance vs Deadly** — Nuisance trap belirtilen level'a ciddi zarar vermez; Deadly trap belirtilen level partisini öldürebilir, daha düşük level'a temasta katlanır (s.199)
- [ ] [x] [ ] **Trigger** — pressure plate, trip wire, doorknob, wrong key gibi temas/etkileşim olayı; trap çoğu zaman tetiklendiği anda Action ekonomisi dışında çalışır (s.199)
- [ ] [x] [ ] **Duration: Instant veya until dispelled** — instant trap tek seferde tepki verir; bazıları reset (örn Poisoned Darts 3 kez), bazıları kalıcı dispelled olana kadar aktif (s.199)
- [ ] [x] [ ] **Detect & Disarm pattern** — Search action ile DC 11-15 Wis(Perception) detect, sonra DC 13-15 Dex(Sleight of Hand) ya da Iron Spike kama ile disarm (s.199-201)

**Collapsing Roof** (Deadly L1-4, s.199) — trip wire tetikleyince destek payandaları çöker, alt geçenler save atar.
- [ ] [x] [ ] **L1-4 base** — DC 13 Dex save, fail 11 (2d10) Bludg, half on success; trapped area Difficult Terrain olur (s.199)
- [ ] [x] [ ] **L5-10 scaling** — 22 (4d10) Bludg, Save DC 15 (s.199)
- [ ] [x] [ ] **L11-16 scaling** — 55 (10d10) Bludg, Save DC 17 (s.199)
- [ ] [x] [ ] **L17-20 scaling** — 99 (18d10) Bludg, Save DC 19 (s.199)

**Falling Net** (Nuisance L1-4, s.199) — trip wire 10ft Net düşürür, hedef Restrained.
- [ ] [x] [ ] **L1-4 base** — DC 10 Dex save, fail Restrained (Huge+ otomatik geçer); DC 10 Str(Athletics) ile çıkar, AC/HP'si var (s.199)
- [ ] [x] [ ] **At Higher Levels (Net weight)** — Athletics check DC: L5-10 12 / L11-16 14 / L17-20 16 (Set Trap DC ve Net dayanıklılığı paralel artar) (s.199)

**Fire-Casting Statue** (Deadly L1-4, s.200) — pressure plate 15ft Cone of Fire püskürtür.
- [ ] [x] [ ] **L1-4 base** — DC 15 Dex save, fail 11 (2d10) Fire, half success; reset her round (s.200)
- [ ] [x] [ ] **L5-10 scaling** — 22 (4d10) Fire, 30-foot Cone (s.200)
- [ ] [x] [ ] **L11-16 scaling** — 55 (10d10) Fire, 60-foot Cone (s.200)
- [ ] [x] [ ] **L17-20 scaling** — 99 (18d10) Fire, 120-foot Cone (s.200)

**Hidden Pit** (Nuisance L1-4, s.200) — kamufle kapaklı çukur, üzerine basanı düşürür.
- [ ] [x] [ ] **L1-4 base** — 10ft pit, 3 (1d6) Bludg fall damage; lid sürekli açık kalır (s.200)
- [ ] [x] [ ] **L5-10 scaling** — 30ft pit, 10 (3d6) Bludg (s.200)
- [ ] [x] [ ] **L11-16 scaling** — 60ft pit, 21 (6d6) Bludg (s.200)
- [ ] [x] [ ] **L17-20 scaling** — 120ft pit, 42 (12d6) Bludg (s.200)

**Poisoned Darts** (Deadly L1-4, s.200) — pressure plate 1d3 dart fırlatır, her dart Con save.
- [ ] [x] [ ] **L1-4 base** — DC 13 Dex save, fail 1d3 dart vurur, her dart 3 (1d4 piercing) + 3 (1d6) Poison; reset 3 kez (s.200)
- [ ] [x] [ ] **L5-10 scaling Poison** — 7 (2d6) per dart (s.200)
- [ ] [x] [ ] **L11-16 scaling Poison** — 14 (4d6) per dart (s.200)
- [ ] [x] [ ] **L17-20 scaling Poison** — 24 (7d6) per dart (s.200)

**Poisoned Needle** (Nuisance L1-4, s.200-201) — kilit yanlış açılırsa iğne dışarı fırlar.
- [ ] [x] [ ] **L1-4 base** — DC 11 Con save, fail 5 (1d10) Poison + Poisoned 1h, half on success; trap Knock spell ile bypass (s.200-201)
- [ ] [x] [ ] **L5-10 scaling** — 11 (2d10) Poison, Save DC 13 (s.201)
- [ ] [x] [ ] **L11-16 scaling** — 22 (4d10) Poison, Save DC 15 (s.201)
- [ ] [x] [ ] **L17-20 scaling** — 55 (10d10) Poison, Save DC 17 (s.201)

**Rolling Stone** (Deadly L11-16 / Nuisance L17-20, s.201) — pressure plate 5ft-radius taş küre yuvarlar; her tur 60ft hareket, +8 init.
- [ ] [x] [ ] **Base mechanic** — taş yolu üstündekilere DC 15 Dex save, fail 55 (10d10) Bludg + Prone; Difficult Terrain olarak alana doluşur (s.201)
- [ ] [x] [ ] **Stop the Stone** — taş Large objet AC 17 / HP 100 / DT 10 / Poison+Psychic immune; veya DC 20 Str(Athletics) action ile yavaşlat (her başarı 15ft hız) (s.201)

**Spiked Pit** (Deadly L1-4, s.201) — Hidden Pit'in spike'lı varyantı.
- [ ] [x] [ ] **L1-4 base** — 10ft pit, 3 (1d6) Bludg fall + 9 (2d8) Piercing spike (s.201)
- [ ] [x] [ ] **L5-10 scaling** — 30ft, 10 (3d6) Bludg + 13 (3d8) Piercing (s.201)
- [ ] [x] [ ] **L11-16 scaling** — 60ft, 21 (6d6) Bludg + 36 (8d8) Piercing (s.201)
- [ ] [x] [ ] **L17-20 scaling** — 120ft, 42 (12d6) Bludg + 57 (13d8) Piercing (s.201)

### 13.12 Vision & Light (s.11, 178, 180)
- [ ] [x] [ ] **Bright Light** — see normally (s.178)
- [ ] [x] [ ] **Dim Light = Lightly Obscured** — disadv Wis(Perception) sight (s.181)
- [ ] [x] [ ] **Darkness = Heavily Obscured** — Blinded condition for sight (s.180)
- [ ] [x] [ ] **Lightly Obscured (light fog, dim, foliage)** — disadv Perception sight (s.11, 184)
- [ ] [x] [ ] **Heavily Obscured (darkness, heavy fog, dense foliage)** — Blinded sight (s.182)
- [ ] [x] [ ] **Blindsight** — see within range w/o sight; ignores Total Cover/Invisible/Darkness within (s.178)
- [ ] [x] [ ] **Darkvision** — Dim within range = Bright; Darkness = Dim; gray-only colors (s.180)
- [ ] [x] [ ] **Tremorsense** — pinpoint creatures via shared surface (no air, not sight) (s.190)
- [ ] [x] [ ] **Truesight** — pierce Darkness/Invisibility/Illusion/Transformation; see Ethereal Plane (s.190)

### 13.13 Hiding (s.183)
- [ ] [x] [ ] **DC 15 Dex(Stealth)** — must be HV obscured / 3/4+ cover / out of LoS (s.183)
- [ ] [x] [ ] **Hidden creature has Invisible condition** (s.183)
- [ ] [ ] [ ] **Reveal triggers**: louder than whisper / enemy finds / attack roll / Verbal cast (s.183)

---

## 14. Travel & Exploration

### 14.1 Travel Pace (s.12)
- [ ] [x] [ ] **Fast** — 400 ft/min, 4 mi/h, 30 mi/day; disadv Wis (Perception/Survival) + Dex (Stealth) (s.12)
- [ ] [x] [ ] **Normal** — 300 ft/min, 3 mi/h, 24 mi/day; disadv Stealth (s.12)
- [ ] [x] [ ] **Slow** — 200 ft/min, 2 mi/h, 18 mi/day; adv Perception/Survival (s.12)
- [ ] [x] [ ] **Mounts: ×2 distance for 1h, then SR/LR** (s.12)

### 14.2 Travel Terrain Table (s.192)
- [ ] [x] [ ] **Arctic / Coastal / Desert / Forest / Grassland / Hill / Mountain / Swamp / Underdark / Urban / Waterborne** (s.192)
- [ ] [x] [ ] **Each: max pace, encounter dist (NdM × 10ft), foraging DC, navigation DC, search DC** (s.192)
- [ ] [x] [ ] **Good road increases pace 1 step (Slow→Normal, Normal→Fast)** (s.192)
- [ ] [x] [ ] **Slowest party member sets pace if speed ≤ ½ normal** (s.192)

### 14.3 Extended Travel (>8h) (s.192)
- [ ] [ ] [ ] **Each extra hour: DC 10+1/extra h Con save or 1 Exhaustion** (s.192)

### 14.4 Special Movement (Wind Walk / Carpet of Flying)
- [ ] [ ] [ ] **Speed÷10 = mph; mph × hours = mi/day; ×1.33 fast / ×0.66 slow** (s.192)

### 14.5 Marching Order (s.12)
- [ ] [ ] [ ] **Determines who triggers traps, sees enemies, etc.** (s.12)

### 14.6 Vehicles (s.100, 192)
- [ ] [x] [ ] **Use vehicle speed instead of pace** (s.192)
- [ ] [x] [ ] **Ships sailing against wind = ½ speed; dead calm = 0 (rowed only)** (s.100)
- [ ] [x] [ ] **Downstream +current speed (~3 mph)** (s.100)

---

## 15. Social Interaction

### 15.1 Attitude (s.10, 184)
- [ ] [x] [ ] **Friendly** — adv on Influence checks (s.182)
- [ ] [x] [ ] **Indifferent** — default (s.184)
- [ ] [x] [ ] **Hostile** — disadv on Influence checks (s.183)

### 15.2 Influence Action (s.10, 184)
- [ ] [x] [ ] **Charisma (Deception/Intim/Performance/Persuasion)** (s.184)
- [ ] [x] [ ] **Wisdom (Animal Handling)** for Beast/Monstrosity (s.184)
- [ ] [x] [ ] **Willing → no check** (s.184)
- [ ] [x] [ ] **Unwilling → no check (refuses)** (s.184)
- [ ] [x] [ ] **Hesitant → check, DC 15 or monster Int (whichever higher)** (s.184)
- [ ] [x] [ ] **Failed Influence → 24h cooldown for same urging** (s.184)

---

## 16. Combat Encounters & XP Budget

### 16.1 XP Budget per Character (s.202)
- [ ] [x] [ ] **Tier table by party level × Low/Moderate/High difficulty** (s.202)
- [ ] [x] [ ] **Multiply by party size = total XP budget** (s.202)
- [ ] [x] [ ] **Each monster XP cost from stat block** (s.202)

### 16.2 Difficulty (s.202)
- [ ] [x] [ ] **Low — fight w/o casualties** (s.202)
- [ ] [x] [ ] **Moderate — could go badly** (s.202)
- [ ] [x] [ ] **High — possible death(s)** (s.202)
- [ ] [x] [ ] **CR ≈ Party level → low difficulty for 4 PCs (rough)** (s.202)

### 16.3 Encounter Tweaks (s.202)
- [ ] [x] [ ] **Elevation, defensive positions, mixed groups, reasons-to-move** (s.202)
- [ ] [x] [ ] **>2 monsters per character → fragile fillers recommended** (s.203)
- [ ] [x] [ ] **CR > party level → solo monster may TPK 1 turn** (s.203)
- [ ] [x] [ ] **Unusual features → caution at low level** (s.203)

---

## 17. Monsters & Stat Blocks

### 17.1 Stat Block Parts (s.188-189)
- [ ] [x] [ ] **Size** (Tiny→Garg) (s.188)
- [ ] [x] [ ] **Creature Type** (s.188)
- [ ] [x] [ ] **Alignment** (s.188)
- [ ] [x] [ ] **AC, Initiative, HP** + HD breakdown (s.188)
- [ ] [x] [ ] **Speed** + special speeds (s.188)
- [ ] [x] [ ] **Ability scores + saves (modifier)** (s.188)
- [ ] [x] [ ] **Skills** (s.188)
- [ ] [x] [ ] **Resistances / Vulnerabilities / Immunities** (s.188)
- [ ] [x] [ ] **Senses + Passive Perception** (s.188)
- [ ] [x] [ ] **Languages** (s.188)
- [ ] [x] [ ] **CR + PB + XP** (s.189)
- [ ] [x] [ ] **Traits** (always-on) (s.189)
- [ ] [x] [ ] **Actions / Bonus Actions / Reactions** (s.189)
- [ ] [x] [ ] **Attack notation: melee/ranged + bonus + reach/range + Hit:** (s.189)
- [ ] [x] [ ] **Saving Throw notation** — DC + ability + fail/success effects (s.189)
- [ ] [x] [ ] **Damage notation: static + dice (use one)** (s.189)

### 17.2 CR & PB (s.8)
- [ ] [x] [ ] **CR 0 → +2 PB** (s.8)
- [ ] [x] [ ] **CR 1-4 → +2** (s.8)
- [ ] [x] [ ] **CR 5-8 → +3** (s.8)
- [ ] [x] [ ] **CR 9-12 → +4** (s.8)
- [ ] [x] [ ] **CR 13-16 → +5** (s.8)
- [ ] [x] [ ] **CR 17-20 → +6** (s.8)
- [ ] [x] [ ] **CR 21-24 → +7** (s.8)
- [ ] [x] [ ] **CR 25-28 → +8** (s.8)
- [ ] [x] [ ] **CR 29-30 → +9** (s.8)

### 17.3 Creature Types (14) (s.179)
- [ ] [x] [ ] **Aberration** (s.179)
- [ ] [x] [ ] **Beast** (s.179)
- [ ] [x] [ ] **Celestial** (s.179)
- [ ] [x] [ ] **Construct** (s.179)
- [ ] [x] [ ] **Dragon** (s.179)
- [ ] [x] [ ] **Elemental** (s.179)
- [ ] [x] [ ] **Fey** (s.179)
- [ ] [x] [ ] **Fiend** (s.179)
- [ ] [x] [ ] **Giant** (s.179)
- [ ] [x] [ ] **Humanoid** (s.179)
- [ ] [x] [ ] **Monstrosity** (s.179)
- [ ] [x] [ ] **Ooze** (s.179)
- [ ] [x] [ ] **Plant** (s.179)
- [ ] [x] [ ] **Undead** (s.179)

---

## 18. Şema → Mekanik Eşlemesi

Bu döküman SRD kuralını atomic checkbox'lar olarak listeler. Her kuralın hangi `EntityCategorySchema` field'ına bağlandığı ve o field'ın bir karaktere/NPC/monster'a nasıl yansıdığı (tetik, hedef stat, operasyon, multiclass davranışı) ayrı bir döküman tarafından kapsanır:

- **[`docs/srd_5e_field_mechanics.md`](srd_5e_field_mechanics.md)** — Şema alanı → mekanik aktarım tabloları.

Yapı: ~70 kategori (36 Tier-0 lookup + 20 Tier-1 content + 13 Tier-2 DM/play) × 7-sütunlu sabit tablo formatı (Alan / Tip / Tetik / Hedef Stat / Operasyon / Multiclass / SRD-Notlar). Multiclass her satırda zorunlu sütun. Schema-vs-SRD uyuşmazlıkları "Açık Mekanikler" listesinde flag'lenir.

Şema (`v2.x`) ile SRD (5.2.1) bağımsız evrildiği için iki döküman ayrı tutulur. Bu dökümandaki bir SRD kuralının schema karşılığını öğrenmek için yan dosyada ilgili field-key satırını okuyun.

---

## Notlar

- Bu döküman SRD 5.2.1'i temel alır. PHB 2024'teki ek opsiyonlar (extra spells, subclasses, races, feats) buraya dahil değildir.
- Sayfa referansları PDF'in basılı sayfa numaralarıdır.
- Implementasyon sırasında `RuleV2` engine kullanılmaz — tüm mekanikler hard-coded Dart fonksiyonları olarak yazılır.
- Bir mekanik karmaşıklaştığında ek alt-checkbox'lar eklenebilir; ana yapı sabit kalır.
