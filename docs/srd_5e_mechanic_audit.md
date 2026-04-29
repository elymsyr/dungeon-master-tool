# D&D 5e Mekanik–Kategori Denetim Defteri

Amaç: SRD 5.2.1 mekaniklerinin her birinin, `flutter_app/lib/domain/entities/schema/builtin/` altındaki kategori şemalarıyla **otomatize edilebilir** olup olmadığını doğrulamak. Her mekanik için: tetikleyici, hedef entity, gerekli kategori field'ları, mevcut destek durumu, eksik/değişiklik notu.

İki kaynak:
- [`srd_5e_mechanics.md`](srd_5e_mechanics.md) — SRD → atomik kural.
- [`srd_5e_field_mechanics.md`](srd_5e_field_mechanics.md) — Şema → kural eşlemesi.

Bu dosya **denetim sonucu** üreten 3. dosyadır: her mekaniğin runtime resolver'a bağlanabilmesi için "şu field var mı, doğru tipte mi, doğru tetikten mi besleniyor" sorularını yanıtlar.

---

## §A Kategori İndeksi

71 kategori, 3 katman. Şema dosyası ve satır referansı eşlemesi:

### A.1 Tier-0 Lookups (37) — `lookup.dart`

Identifier-only (mekanik yok): `ability`, `skill`, `damage-type`, `condition`, `creature-type`, `alignment`, `language`, `weapon-category`, `armor-category`, `tool-category`, `spell-school`, `magic-item-category`, `speed-type`, `sense`, `action`, `area-shape`, `attitude`, `cover`, `illumination`, `hazard`, `feat-category`, `tier-of-play`, `travel-pace`, `arcane-focus`, `druidic-focus`, `holy-symbol`, `plane`, `casting-component`, `casting-time-unit`.

Mekanik field'lı (§1.2 field_mechanics): `size` (`space_ft`, `hit_die_size`, `carrying_multiplier`), `rarity` (`value_gp`, `crafting_time_days`, `crafting_cost_gp`), `coin` (`value_in_gp`), `lifestyle` (`cost_per_day_gp`), `condition` (`stacks`, `grants_incapacitated`), `damage-type` (`bypassable_by_magical`, `is_physical`), `duration-unit` (`is_concentration_compatible`), `weapon-property` (`mechanic_kind`), `weapon-mastery` (`effect_kind`, `effect_value`, `save_ability`).

### A.2 Tier-1 Content (20) — `content.dart`

`class`, `subclass`, `species`, `background`, `feat`, `spell`, `weapon`, `armor`, `tool`, `adventuring-gear`, `ammunition`, `pack`, `mount`, `vehicle`, `trinket`, `magic-item`, `trait`, `creature-action`, `monster`, `animal`.

### A.3 Tier-2 DM/Play (13) — `dm.dart`

`player-character`, `npc`, `applied-condition`, `location`, `scene`, `quest`, `encounter`, `trap`, `poison`, `curse`, `environmental-effect`, `hireling`, `service`.

---

## §B Mekanik Sırası

Bağımlılık grafına göre sıralandı: foundation → composite. Her mekanik §C'de denetlenir.

### B.1 Sıralama Stratejisi

1. **Tier-0 mekanik field'lar** — diğer her şeyin temeli.
2. **Ability Scores & D20 (mech §2)** — tüm checklerin çekirdeği.
3. **Karakter Yaratma Akışı (mech §1)** — §2 üzerine inşa.
4. **Damage & Healing (mech §4)** — combat & spell ortak alt katmanı.
5. **Conditions (mech §5)** — combat/spell tarafından referans.
6. **Combat (mech §3)** — §2/§4/§5'i tüketir.
7. **Equip/Unequip (mech §7)** — combat/AC/silah etkileşimi.
8. **Equipment & Inventory (mech §6)** — §7'nin data kaynağı.
9. **Spells (mech §8)** — §2/§4/§5/§6 üzerinde.
10. **Class (mech §9)** — yukarıdakileri composite eder.
11. **Origin (mech §10)** — Class'a paralel feature kaynağı.
12. **Feats (mech §11)** — modifier kaynağı.
13. **Magic Items (mech §12)** — equip + modifier.
14. **Hazards & Environment (mech §13)** — DM tarafı.
15. **Travel & Exploration (mech §14)**.
16. **Social Interaction (mech §15)**.
17. **Encounters & XP (mech §16)**.
18. **Monsters & Stat Blocks (mech §17)**.

### B.2 Sıralı Mekanik Listesi (Denetim Checkbox'ları)

Soldan sağa: `[a]` Audited, `[g]` Has Gaps, `[d]` Doc-updated.

#### B.2.0 Tier-0 mekanik field'lar
- [x] [x] [x] **size.space_ft / hit_die_size / carrying_multiplier** — fm §1.2 — BLOCKED (D.0.1)
- [x] [x] [x] **rarity.value_gp / crafting_time_days / crafting_cost_gp** — fm §1.2 — BLOCKED (D.0.2)
- [x] [x] [x] **coin.value_in_gp** — fm §1.2 — BLOCKED (D.0.3)
- [x] [x] [x] **lifestyle.cost_per_day_gp** — fm §1.2 — BLOCKED (D.0.4)
- [x] [ ] [ ] **condition.stacks / grants_incapacitated** — fm §1.2 — PASS (D.0.5)
- [x] [ ] [ ] **damage-type.is_physical / bypassable_by_magical** — fm §1.2 — PASS (D.0.6)
- [x] [x] [x] **duration-unit.is_concentration_compatible** — fm §1.2 — BLOCKED (D.0.7)
- [x] [ ] [ ] **weapon-property.mechanic_kind** — fm §1.2 — PASS (D.0.8)
- [x] [ ] [ ] **weapon-mastery.effect_kind / effect_value / save_ability** — fm §1.2 — PASS (D.0.9)
- [x] [ ] [ ] **sense.default_range_ft** — fm §1.2 — PASS (D.0.10)

#### B.2.1 Ability Scores & D20 (mech §2)
- [x] [ ] [ ] **§2.1 6 Ability** — STR/DEX/CON/INT/WIS/CHA — PASS (D.1.1)
- [x] [ ] [ ] **§2.2 Score → Modifier** — `floor((X-10)/2)`, cap 20/30 — PASS (D.1.2)
- [x] [ ] [ ] **§2.3 D20 Test** — check/save/attack, DC ranges — PASS (D.1.3)
- [x] [x] [x] **§2.4 Proficiency** — PB rules, skills, tools, saves, expertise, weapons — GAPS (D.1.4)
- [x] [ ] [ ] **§2.5 Advantage / Disadvantage** — 2d20, cancel rules, Heroic Inspiration — PASS (D.1.5)

#### B.2.2 Karakter Yaratma Akışı (mech §1)
- [x] [x] [x] **§1.1 5 Adımlık Akış** — class → origin → ability scores → alignment → details — GAPS (D.2.1)
- [x] [x] [x] **§1.2 Ability Score üretimi** — Standard Array / 4d6 / Point Cost / Background ASI — GAPS (D.2.2)
- [x] [ ] [ ] **§1.3 Final detay hesapları** — passive perception, init, AC, atk bonus, spell DC — PASS (D.2.3)
- [x] [ ] [ ] **§1.4 Level 1 HP** — class-based formül — PASS (D.2.4)
- [x] [ ] [ ] **§1.5 Level Advancement** — XP table, PB, fixed/rolled HP, ASI/Feat — PASS (D.2.5)
- [x] [x] [x] **§1.6 Tiers of Play** — 1-4/5-10/11-16/17-20 — GAPS (D.2.6, opsiyonel)
- [x] [x] [x] **§1.7 Higher-Level Start** — gold + magic item starting bundles — GAPS (D.2.7)
- [x] [x] [x] **§1.8 Multiclassing** — prereq, HP, PB, profs, feature non-stack, slot table — GAPS (D.2.8)

#### B.2.3 Damage & Healing (mech §4)
- [x] [ ] [ ] **§4.1 Hit Points** — max/current, bloodied — PASS (D.3.1)
- [x] [ ] [ ] **§4.2 Damage Roll** — weapon/spell/min0 — PASS (D.3.2)
- [x] [ ] [ ] **§4.3 Damage Types (13)** — PASS (D.3.3 → D.0.6)
- [x] [x] [x] **§4.4 Resistance / Vulnerability / Immunity** — PC field eksik — GAPS (D.3.4)
- [x] [ ] [ ] **§4.5 Critical Hit** — dice ×2, mod 1× — PASS (D.3.5)
- [x] [ ] [ ] **§4.6 Saving Throws & Damage** — multi-target, half-on-save — PASS (D.3.6)
- [x] [ ] [ ] **§4.7 Healing** — restore, max cap, excess lost — PASS (D.3.7)
- [x] [ ] [ ] **§4.8 Dropping to 0 HP** — death saves, massive damage, instant death — PASS (D.3.8)
- [x] [ ] [ ] **§4.9 Stabilizing** — Help/Medicine, Healer's Kit, 1d4h — PASS (D.3.9)
- [x] [ ] [ ] **§4.10 Knock Out** — non-lethal, SR start — PASS (D.3.10)
- [x] [ ] [ ] **§4.11 Temporary HP** — buffer, no-stack, LR clear — PASS (D.3.11)
- [x] [x] [x] **§4.12 Resting** — SR (1h, HD spend), LR (8h, full restore) — GAPS (D.3.12) ⭐
- [x] [ ] [ ] **§4.13 Hit Dice by class** — d6/d8/d10/d12 — PASS (D.3.13)
- [x] [ ] [ ] **§4.14 Breaking Objects** — object AC + HP table — PASS (D.3.14)

#### B.2.4 Conditions (mech §5)
- [x] [ ] [ ] **15 Conditions** — Blinded/Charmed/Deafened/Exhaustion/Frightened/Grappled/Incapacitated/Invisible/Paralyzed/Petrified/Poisoned/Prone/Restrained/Stunned/Unconscious — PASS (D.4.1)

#### B.2.5 Combat (mech §3)
- [x] [ ] [ ] **§3.1 Combat Akışı** — PASS (D.5.1)
- [x] [ ] [ ] **§3.2 Turn Yapısı** — PASS (D.5.2)
- [x] [x] [x] **§3.3 Movement** — speed-type lookup eksik — GAPS (D.5.3)
- [x] [x] [x] **§3.4 Creature Size & Space** — size lookup eksik — GAPS (D.5.4 / D.0.1)
- [x] [x] [x] **§3.5 Actions (12)** — action lookup eksik — GAPS (D.5.5)
- [x] [x] [x] **§3.6 Bonus Action** — action lookup'a bağlı — GAPS (D.5.6)
- [x] [x] [x] **§3.7 Reaction** — action lookup'a bağlı — GAPS (D.5.6)
- [x] [ ] [ ] **§3.8 Attack Roll Yapısı** — PASS (D.5.7)
- [x] [x] [x] **§3.9 Cover** — cover lookup eksik — GAPS (D.5.8)
- [x] [ ] [ ] **§3.10 Ranged Attacks** — PASS (D.5.9)
- [x] [ ] [ ] **§3.11 Melee Attacks** — PASS (D.5.9)
- [x] [ ] [ ] **§3.12 Opportunity Attack** — PASS (D.5.10)
- [x] [x] [x] **§3.13 Equipping/Unequipping Weapons** — PC.held_weapons eksik — GAPS (D.5.11)
- [x] [ ] [ ] **§3.14 Mounted Combat** — PASS (D.5.12)
- [x] [ ] [ ] **§3.15 Underwater Combat** — PASS (D.5.12)
- [x] [ ] [ ] **§3.16 Two-Weapon Fighting** — PASS (D.5.13)

#### B.2.6 Equip / Unequip (mech §7)
- [x] [x] [x] **§7.1 Silah** — held_weapons eksik — GAPS (D.6.1 / D.5.11)
- [x] [x] [x] **§7.2 Zırh** — equipped_armor_ref eksik — GAPS (D.6.2)
- [x] [x] [x] **§7.3 Magic Items giyim** — body_slot eksik — GAPS (D.6.3)
- [x] [x] [x] **§7.4 Multiple-of-a-Kind** — GAPS (D.6.4)
- [x] [x] [x] **§7.5 Paired Items** — GAPS (D.6.4)
- [x] [ ] [ ] **§7.6 Pact of the Blade** — PASS (D.6.5)
- [x] [ ] [ ] **§7.7 Wild Shape Equipment** — PASS (D.6.5)
- [x] [ ] [ ] **§7.8 Attunement** — PASS (D.6.6)

#### B.2.7 Equipment & Inventory (mech §6)
- [x] [x] [x] **§6.1 Coins** — coin lookup BLOCKED — GAPS (D.7)
- [x] [x] [x] **§6.2 Carrying Capacity** — size lookup BLOCKED — GAPS (D.7)
- [x] [ ] [ ] **§6.3 Buying & Selling** — PASS
- [x] [ ] [ ] **§6.4 Weapon Properties** — PASS
- [x] [ ] [ ] **§6.5 Weapon Mastery** — PASS
- [x] [ ] [ ] **§6.6 Improvised Weapons** — PASS
- [x] [x] [x] **§6.7 Armor** — armor-category lookup eksik — GAPS (D.7)
- [x] [ ] [ ] **§6.8 Armor Training** — PASS
- [x] [x] [x] **§6.9 Tools** — tool-category lookup eksik — GAPS (D.7)
- [x] [ ] [ ] **§6.10 Adventuring Gear** — PASS
- [x] [ ] [ ] **§6.11 Spellcasting Focus** — PASS
- [x] [ ] [ ] **§6.12 Mounts & Vehicles** — PASS
- [x] [x] [x] **§6.13 Lifestyle Expenses** — BLOCKED (D.7)
- [x] [ ] [ ] **§6.14 Hirelings** — PASS
- [x] [ ] [ ] **§6.15 Spellcasting Services** — PASS
- [x] [x] [x] **§6.16 Crafting** — BLOCKED (D.7)
- [x] [ ] [ ] **§6.17 Brewing Potions of Healing** — PASS
- [x] [ ] [ ] **§6.18 Scribing Spell Scrolls** — PASS

#### B.2.8 Spells (mech §8)
- [x] [ ] [ ] **§8.1 Spell Levels & Slots** — PASS
- [x] [ ] [ ] **§8.2 Preparation by Class** — PASS
- [x] [ ] [ ] **§8.3 Pact Magic** — PASS
- [x] [x] [x] **§8.4 Casting Time** — casting-time-unit lookup eksik — GAPS
- [x] [ ] [ ] **§8.5 One Slot per Turn** — PASS
- [x] [x] [x] **§8.6 Components V/S/M** — casting-component lookup eksik — GAPS
- [x] [ ] [ ] **§8.7 Range** — PASS
- [x] [x] [x] **§8.8 Duration** — duration-unit BLOCKED — GAPS
- [x] [ ] [ ] **§8.9 Concentration** — PASS
- [x] [ ] [ ] **§8.10 Spell DCs & Attacks** — PASS
- [x] [ ] [ ] **§8.11 Targets** — PASS
- [x] [x] [x] **§8.12 Areas of Effect** — area-shape lookup eksik — GAPS
- [x] [ ] [ ] **§8.13 Combining Effects** — PASS
- [x] [ ] [ ] **§8.14 Casting in Armor** — PASS
- [x] [ ] [ ] **§8.15 Schools of Magic** — PASS
- [x] [ ] [ ] **§8.16 Spell Scrolls** — PASS
- [x] [ ] [ ] **§8.17 Magic Items Casting Spells** — PASS

#### B.2.9 Class (mech §9)
- [x] [ ] [ ] **§9.1 Genel Pattern** — PASS (D.9)
- [x] [ ] [ ] **§9.2-§9.13** — 12 class data-level — schema PASS (per-class data ayrı sprint)

#### B.2.10 Origin (mech §10)
- [x] [ ] [ ] **§10.1 Background Parts** — PASS
- [x] [ ] [ ] **§10.2 Backgrounds** — PASS (data ayrı sprint)
- [x] [x] [x] **§10.3 Species Parts** — size lookup + multi-speed eksik — GAPS (D.10)
- [x] [ ] [ ] **§10.4 Species (9)** — PASS (data)
- [x] [ ] [ ] **§10.5 Languages** — PASS

#### B.2.11 Feats (mech §11)
- [x] [x] [x] **§11.1 Categories** — feat-category lookup eksik — GAPS
- [x] [ ] [ ] **§11.2 Origin Feats** — PASS
- [x] [ ] [ ] **§11.3 General Feats** — PASS
- [x] [ ] [ ] **§11.4 Fighting Style** — PASS
- [x] [ ] [ ] **§11.5 Epic Boon** — PASS

#### B.2.12 Magic Items (mech §12)
- [x] [ ] [ ] **§12.1 Categories (9)** — PASS
- [x] [x] [x] **§12.2 Rarity & Value** — BLOCKED (D.0.2)
- [x] [ ] [ ] **§12.3 Identification** — PASS
- [x] [ ] [ ] **§12.4 Attunement** — PASS
- [x] [ ] [ ] **§12.5 Activation** — PASS
- [x] [x] [x] **§12.6 Crafting** — BLOCKED (D.0.2)
- [x] [ ] [ ] **§12.7 Sentient Items** — PASS
- [x] [ ] [ ] **§12.8 Cursed Items** — PASS
- [x] [ ] [ ] **§12.9 Magic Item Resilience** — PASS
- [x] [x] [x] **§12.10 Wearing Limits** — body_slot eksik — GAPS (D.6.3)
- [x] [ ] [ ] **§12.11 Potion Miscibility** — PASS

#### B.2.13 Hazards & Environment (mech §13)
- [x] [ ] [ ] **§13.1 Burning** — PASS
- [x] [ ] [ ] **§13.2 Falling** — PASS
- [x] [ ] [ ] **§13.3 Dehydration** — PASS
- [x] [ ] [ ] **§13.4 Malnutrition** — PASS
- [x] [ ] [ ] **§13.5 Suffocation** — PASS
- [x] [ ] [ ] **§13.6 Environmental Effects** — PASS
- [x] [ ] [ ] **§13.7 Curses** — PASS
- [x] [ ] [ ] **§13.8 Magical Contagions** — PASS
- [x] [ ] [ ] **§13.9 Fear & Mental Stress** — PASS
- [x] [ ] [ ] **§13.10 Poison** — PASS
- [x] [ ] [ ] **§13.11 Traps** — PASS
- [x] [x] [x] **§13.12 Vision & Light** — illumination lookup eksik — GAPS
- [x] [ ] [ ] **§13.13 Hiding** — PASS

#### B.2.14 Travel & Exploration (mech §14)
- [x] [x] [x] **§14.1 Travel Pace** — travel-pace lookup eksik — GAPS
- [x] [ ] [ ] **§14.2 Travel Terrain Table** — PASS
- [x] [ ] [ ] **§14.3 Extended Travel** — PASS
- [x] [x] [x] **§14.4 Special Movement** — speed-type lookup eksik — GAPS (D.5.3)
- [x] [ ] [ ] **§14.5 Marching Order** — PASS
- [x] [ ] [ ] **§14.6 Vehicles** — PASS

#### B.2.15 Social Interaction (mech §15)
- [x] [x] [x] **§15.1 Attitude** — attitude lookup eksik — GAPS
- [x] [ ] [ ] **§15.2 Influence Action** — PASS

#### B.2.16 Encounters & XP (mech §16)
- [x] [ ] [ ] **§16.1 XP Budget per Character** — PASS
- [x] [ ] [ ] **§16.2 Difficulty** — PASS
- [x] [ ] [ ] **§16.3 Encounter Tweaks** — PASS

#### B.2.17 Monsters & Stat Blocks (mech §17)
- [x] [x] [x] **§17.1 Stat Block Parts** — size+alignment lookup eksik — GAPS (D.17)
- [x] [ ] [ ] **§17.2 CR & PB** — PASS
- [x] [ ] [ ] **§17.3 Creature Types (14)** — PASS

---

## §C Audit Şablonu

Her mekanik için aşağıdaki blok doldurulur. Audit zamanında yalnızca ilgili kategoriler okunur (kontekst ekonomisi); bulgular tek bir sub-section'da özetlenir.

```markdown
### C.X.Y <mech-id> — <kısa ad>

**SRD ref:** mech §X.Y (s.NN)
**Tetik:** <assign / level-up:N / equip / cast / attack / damage-roll / save-roll / long-rest / short-rest / turn-start / always / derived>
**Hedef Entity:** <PlayerCharacter / NPC / Monster / Animal / AppliedCondition>

**Veri Akışı:**
<input field(s)> ─trigger→ <intermediate> ─derived→ <output stat>

**İlgili Kategoriler:**
- `<slug>` — neden ilgili (rol)
- ...

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `<slug>` | `<key>` | `<type>` | ✅/⚠️/❌ | … |

**Verdict:** PASS / GAPS / BLOCKED

**Eksik / Değişiklik Önerisi:** (varsa)
- Hangi kategoriye, hangi field, hangi tip, neden.
```

**Verdict semantiği:**
- **PASS** — gerekli her field doğru tipte ve doğru tetikten besleniyor; resolver yazılabilir.
- **GAPS** — büyük ölçüde destekli ama 1-N field eksik veya tip yanlış; çözüm önerisi maddelenir.
- **BLOCKED** — kategori bile yok veya temel field set'i eksik; ayrı tasarım turu gerek.

---

## §D Audit Sonuçları

Sıraya göre doldurulur. Her bölüm B.2.X'e karşılık gelir.

### D.0 Tier-0 Mekanik Field'lar

Audit kaynağı: `flutter_app/lib/domain/entities/schema/builtin/lookups.dart` (15 kategori) vs. `srd_5e_field_mechanics.md` §1.1 (37 kategori beklenir).

**Genel Bulgu — KRITIK GAP:** Code'daki `tier0Slugs` (lookups.dart:12-28) yalnız 15 lookup içeriyor: `ability, skill, damage-type, condition, creature-type, language, weapon-property, weapon-mastery, spell-school, magic-item-category, sense, hazard, arcane-focus, druidic-focus, holy-symbol`. **Eksik 22 kategori:** `size, alignment, weapon-category, armor-category, tool-category, rarity, speed-type, action, area-shape, attitude, cover, illumination, feat-category, lifestyle, coin, tier-of-play, travel-pace, plane, casting-component, casting-time-unit, duration-unit, ammunition` (ammunition Tier-1 içinde, sayım dışı). Bu durum aşağıdaki mekaniklerin çoğunu BLOCKED yapar.

#### C.0.1 `size.space_ft / hit_die_size / carrying_multiplier`

**SRD ref:** mech §3.4, fm §1.2 s.14, s.16, s.22
**Tetik:** always (space_ft, carrying_multiplier) / monster default (hit_die_size)
**Hedef Entity:** Species.size_ref → PlayerCharacter; Monster.size_ref → Monster

**Veri Akışı:**
`Species.size_ref` ─assign→ `PlayerCharacter.size_ref` ─derived→ `space_ft` (creature footprint), `carrying_multiplier × STR × 15` (carry capacity)

**İlgili Kategoriler:**
- `size` (Tier-0) — kaynak
- `species` — `size_ref` consumer
- `monster` — `size_ref` consumer
- `player-character` — derived `space_ft`, `carrying_capacity`

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `size` | (kategori) | — | ❌ | `tier0Slugs`'da yok |
| `size` | `space_ft` | float | ❌ | kategori yok |
| `size` | `hit_die_size` | enum | ❌ | kategori yok |
| `size` | `carrying_multiplier` | float | ❌ | kategori yok |

**Verdict:** BLOCKED

**Eksik / Değişiklik Önerisi:**
- `lookups.dart`'a `_sizeCategory` ekle, `tier0Slugs`'a `'size'` insert et.
- Field'lar: `space_ft` (float, min 0), `hit_die_size` (enum: `d4`,`d6`,`d8`,`d10`,`d12`,`d20`), `carrying_multiplier` (float, default 1.0).
- Seed: Tiny (space=2.5, hit_die=`d4`, mult=0.5), Small (5, `d6`, 1), Medium (5, `d8`, 1), Large (10, `d10`, 2), Huge (15, `d12`, 4), Gargantuan (20, `d20`, 8).
- `species` ve `monster` şemasına `size_ref` relation field'ı (allowedTypes=`[size]`) — content.dart denetimi gerek.

#### C.0.2 `rarity.value_gp / crafting_time_days / crafting_cost_gp`

**SRD ref:** fm §1.2 s.205-206, s.103
**Tetik:** sell/buy (value_gp), crafting (time/cost)
**Hedef Entity:** MagicItem.rarity_ref → PlayerCharacter.gp/downtime

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `rarity` | (kategori) | — | ❌ | tier0Slugs'da yok |
| `rarity` | `value_gp` | int | ❌ | — |
| `rarity` | `crafting_time_days` | int | ❌ | — |
| `rarity` | `crafting_cost_gp` | int | ❌ | — |

**Verdict:** BLOCKED

**Eksik / Değişiklik Önerisi:**
- `_rarityCategory` ekle. Seed: Common (100/2/50), Uncommon (400/8/200), Rare (4000/40/2000), Very Rare (40000/240/20000), Legendary (200000/600/100000), Artifact (priceless/—/—).
- Ek field `is_consumable_default` (bool) düşünülmeli; consumable ½ formülü için. Veya MagicItem.is_consumable kendi alanı (öneri: MagicItem'da, çünkü her item-rarity ikilisi farklı olabilir).

#### C.0.3 `coin.value_in_gp`

**SRD ref:** fm §1.2 s.89
**Tetik:** always (currency conversion)
**Hedef Entity:** PlayerCharacter.{cp,sp,ep,gp,pp}

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `coin` | (kategori) | — | ❌ | yok |
| `coin` | `value_in_gp` | float | ❌ | — |

**Verdict:** BLOCKED

**Eksik / Değişiklik Önerisi:**
- `_coinCategory` ekle. Seed: CP (0.01), SP (0.1), EP (0.5), GP (1), PP (10). Ek field `weight_per_50` (float = 1 lb) — encumbrance için.
- Alternatif: `coin` lookup yerine sabit dnd5e_constants kullan ve PC'de `cp/sp/ep/gp/pp` int field'larını tut. Daha basit ama runtime customizable değil. Karar: lookup tut (extension için).

#### C.0.4 `lifestyle.cost_per_day_gp`

**SRD ref:** fm §1.2 s.101
**Tetik:** downtime/day
**Hedef Entity:** PlayerCharacter.gp

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `lifestyle` | (kategori) | — | ❌ | yok |
| `lifestyle` | `cost_per_day_gp` | float | ❌ | — |

**Verdict:** BLOCKED

**Eksik / Değişiklik Önerisi:**
- `_lifestyleCategory` ekle. Seed: Wretched (0), Squalid (0.1), Poor (0.2), Modest (1), Comfortable (2), Wealthy (4), Aristocratic (10).
- PC'de `current_lifestyle_ref` relation field gerek — Tier-2 PC denetimi sırasında doğrula.

#### C.0.5 `condition.stacks / grants_incapacitated`

**SRD ref:** fm §1.2 s.179, s.181, s.184
**Tetik:** apply
**Hedef Entity:** AppliedCondition (Tier-2)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `condition` | `stacks` | bool | ✅ | lookups.dart:580 |
| `condition` | `grants_incapacitated` | bool | ✅ | lookups.dart:591 |
| `condition` | `ends_on` | textarea | ✅ | lookups.dart:585 — bonus, fm beklemiyor ama yararlı |
| seed | 15 condition | — | ✅ | lookups.dart:599-603 (Exhaustion stacks=true; Stunned/Paralyzed/Petrified/Unconscious incapacitated=true) |

**Verdict:** PASS

#### C.0.6 `damage-type.is_physical / bypassable_by_magical`

**SRD ref:** fm §1.2 — magical bypass + B/P/S classification
**Tetik:** damage-roll
**Hedef Entity:** Damage resolver (resistance bypass / type tag)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `damage-type` | `is_physical` | bool | ✅ | lookups.dart:517 |
| `damage-type` | `bypassable_by_magical` | bool | ✅ | lookups.dart:525 |
| seed | 13 damage type | — | ✅ | lookups.dart:531-545 (B/P/S → physical=true, bypass=true) |

**Verdict:** PASS

#### C.0.7 `duration-unit.is_concentration_compatible`

**SRD ref:** fm §1.2 s.179
**Tetik:** cast
**Hedef Entity:** Spell concentration check

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `duration-unit` | (kategori) | — | ❌ | tier0Slugs'da yok |
| `duration-unit` | `is_concentration_compatible` | bool | ❌ | — |

**Verdict:** BLOCKED

**Eksik / Değişiklik Önerisi:**
- `_durationUnitCategory` ekle. Seed: Instantaneous (false), Round (true), Minute (true), Hour (true), Day (true), Special (false), Until Dispelled (false).
- `Spell.duration_unit_ref` relation field'ı — content.dart denetiminde doğrulanır.

#### C.0.8 `weapon-property.mechanic_kind`

**SRD ref:** fm §1.2 s.89
**Tetik:** attack/equip
**Hedef Entity:** Weapon dispatcher

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `weapon-property` | `mechanic_kind` | enum (11) | ✅ | lookups.dart:754 — tüm 11 kind mevcut |
| seed | 11 property | — | ✅ | lookups.dart:772-783 |

**Verdict:** PASS

#### C.0.9 `weapon-mastery.effect_kind / effect_value / save_ability`

**SRD ref:** fm §1.2 s.221
**Tetik:** attack-hit/miss
**Hedef Entity:** Weapon mastery resolver

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `weapon-mastery` | `effect_kind` | enum (8) | ✅ | lookups.dart:814 |
| `weapon-mastery` | `effect_value` | int | ✅ | lookups.dart:829 |
| `weapon-mastery` | `save_ability` | enum | ✅ | lookups.dart:837 (`''`,STR,DEX,CON,INT,WIS,CHA) |
| seed | 8 mastery | — | ✅ | lookups.dart:846-854 |

**Verdict:** PASS

#### C.0.10 `sense.default_range_ft`

**SRD ref:** fm §1.2
**Tetik:** always
**Hedef Entity:** rangedSense fallback

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `sense` | `default_range_ft` | int | ✅ | lookups.dart:933 |
| seed | 4 sense | ⚠️ | lookups.dart:942-947 — Blindsight 30, Darkvision 60, Tremorsense 60, Truesight 120. SRD'de Echolocation/Heightened-types yok ama base 4 yeterli. |

**Verdict:** PASS

---

**D.0 Özet:**
- PASS: 5 (`condition`, `damage-type`, `weapon-property`, `weapon-mastery`, `sense`)
- BLOCKED: 5 (`size`, `rarity`, `coin`, `lifestyle`, `duration-unit`)
- Önerilen toplu PR: lookups.dart'a 5 yeni kategori (size/rarity/coin/lifestyle/duration-unit) + tier0Slugs güncelleme + bootstrap seed satırları. Identifier-only eksikler (alignment, weapon-category, armor-category, tool-category, speed-type, action, area-shape, attitude, cover, illumination, feat-category, tier-of-play, travel-pace, plane, casting-component, casting-time-unit) ayrı PR — mekanik field'ları yok ama Tier-1/Tier-2 relation hedefleri olarak gerekli; her biri ilgili mekanik audit'inde flag edilir.

### D.1 Ability Scores & D20

Audit kaynağı: `lookups.dart` (`ability`, `skill`), `dm.dart::_playerCharacterCategory` (PC dm.dart:334-435), mech §2.

#### C.1.1 §2.1 — 6 Ability (STR/DEX/CON/INT/WIS/CHA)

**Tetik:** assign / always
**Hedef Entity:** PlayerCharacter, NPC, Monster, Animal

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `ability` | seed | — | ✅ | lookups.dart:412-418, 6 row (STR..CHA) abbreviation+order_index |
| `player-character` | `stat_block` | widget | ✅ | dm.dart:357 — custom widget, 6 ability score storage |
| `player-character` | `saving_throw_proficiencies` | relation→ability | ✅ | dm.dart:355 |
| `npc` | (ability scores) | — | ⚠️ | grpAbilityScores group var (dm.dart:319) ama field tanımı görünmedi — NPC yapısı denetlenmeli |
| `monster` | (ability scores) | — | ⚠️ | content.dart:892+ ayrı denetim |

**Verdict:** PASS (PC için); NPC/Monster için ayrı tur (B.2.17'de denetlenecek).

#### C.1.2 §2.2 — Score → Modifier `floor((X-10)/2)`, cap 20/30

**Tetik:** derived
**Hedef Entity:** her ability-using entity

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `stat_block` | widget | ✅ | Score storage; modifier runtime derivation. Widget impl. doğrulamak gerek (cap 20/30 logic). |

**Verdict:** PASS (storage); resolver/widget düzeyinde verify-when-implementing.

**Eksik / Değişiklik Önerisi:**
- statBlock widget'ında `cap_per_ability` (default 20) ve `epic_boon_cap` (30) field'ları yoksa runtime constant'lar yeterli; persistence değil.

#### C.1.3 §2.3 — D20 Test (check/save/attack, DC ranges)

**Tetik:** roll
**Hedef Entity:** PlayerCharacter, NPC, Monster

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `proficiency_bonus` | int | ✅ | dm.dart:344, min 2 max 6 |
| `player-character` | `saving_throws` | proficiencyTable | ✅ | dm.dart:365 |
| `player-character` | `skills` | proficiencyTable | ✅ | dm.dart:367 |
| `player-character` | `passive_perception/insight/investigation` | int | ✅ | dm.dart:371-373 |

**Verdict:** PASS

#### C.1.4 §2.4 — Proficiency (PB, skills, tools, saves, expertise, weapons)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `proficiency_bonus` | int | ✅ | dm.dart:344 |
| `player-character` | `saving_throw_proficiencies` | rel→ability | ✅ | dm.dart:355 |
| `player-character` | `skill_proficiencies` | rel→skill | ✅ | dm.dart:353 |
| `player-character` | `expertise_skills` | rel→skill | ✅ | dm.dart:354 |
| `player-character` | `tool_proficiencies` | rel→tool | ✅ | dm.dart:347 |
| `player-character` | `weapon_proficiency_categories` | enum (list) | ⚠️ | dm.dart:348 — `_enumWeaponCategories` enum kullanıyor; `weapon-category` Tier-0 lookup'ı yok. Çalışıyor ama lookup tutarlılığı kayıp. |
| `player-character` | `weapon_proficiency_specifics` | rel→weapon | ✅ | dm.dart:350 |
| `player-character` | `armor_trainings` | enum (list) | ⚠️ | dm.dart:352 — `_enumArmorCategories` enum; `armor-category` lookup yok. |

**Verdict:** GAPS

**Eksik / Değişiklik Önerisi:**
- `weapon-category` ve `armor-category` Tier-0 lookup'ları ekle (kategori-only, mekanik field yok; identifier rolü).
- PC.weapon_proficiency_categories ve armor_trainings → `enum` yerine `relation` (allowedTypes=[`weapon-category` / `armor-category`], isList=true).
- Migration: bootstrap'ta varolan enum string değerlerini lookup row entityId'lerine map et.
- Faydası: kullanıcı kendi homebrew weapon-category ekleyebilir (örn. "Cyberpunk Firearm").

#### C.1.5 §2.5 — Advantage / Disadvantage (cancel, Heroic Inspiration)

**Tetik:** roll-time
**Hedef Entity:** PlayerCharacter (Heroic Inspiration), runtime modifier sources

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `heroic_inspiration` | bool | ✅ | dm.dart:362 |

**Verdict:** PASS

**Not:** Adv/disadv kaynakları (condition, terrain, etc.) `grantedModifiers` DSL üzerinden runtime resolver tarafından toplanır (fm §0.6).

---

**D.1 Özet:**
- PASS: 4 (§2.1, §2.2, §2.3, §2.5)
- GAPS: 1 (§2.4 — weapon-category/armor-category lookup eksik, enum fallback kullanılıyor)
- BLOCKED: 0

### D.2 Karakter Yaratma Akışı

Audit kaynağı: `content.dart::_classCategory` (343-400), `_speciesCategory` (427-456), `_backgroundCategory` (458-491), `_featCategory` (493+), `dm.dart::_playerCharacterCategory` (334-435), mech §1.

#### C.2.1 §1.1 — 5 Adımlık Akış (class → origin → ability → align → details)

**Tetik:** assign-time
**Hedef Entity:** PlayerCharacter

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `class_refs` | rel→class (list) | ✅ | dm.dart:338, required |
| `player-character` | `class_levels` | levelTable | ✅ | dm.dart:339 |
| `player-character` | `subclass_refs` | rel→subclass (list) | ✅ | dm.dart:340 |
| `player-character` | `species_ref` | rel→species | ✅ | dm.dart:337 |
| `player-character` | `background_ref` | rel→background | ✅ | dm.dart:341 |
| `player-character` | `alignment_ref` | enum | ⚠️ | dm.dart:342 — `_enumAlignments` enum; Tier-0 `alignment` lookup eksik |
| `player-character` | identity (age/height/weight/eyes/skin/hair) | text | ✅ | dm.dart:400-405 |
| `player-character` | personality (traits/ideals/bonds/flaws) | markdown | ✅ | dm.dart:395-398 |

**Verdict:** GAPS

**Eksik / Değişiklik Önerisi:**
- `alignment` Tier-0 lookup ekle (identifier-only, 9 row: LG/NG/CG/LN/N/CN/LE/NE/CE).
- PC.alignment_ref enum → relation, allowedTypes=[`alignment`].

#### C.2.2 §1.2 — Ability Score Üretimi (Standard Array / 4d6 / Point Cost / Background ASI)

**Tetik:** char-creation
**Hedef Entity:** PlayerCharacter.stat_block

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `stat_block` | widget | ✅ | dm.dart:357 — 6 score storage |
| `background` | `ability_score_options` | rel→ability (list) | ✅ | content.dart:464, required |
| `background` | (ASI amount/distribution) | — | ⚠️ | SRD 2024: background grants +2/+1 or +1/+1/+1 over 3 abilities. `ability_score_options` listesi var ama dağılım kuralı tutulmuyor. |
| `feat` | `asi_ability_options` | rel→ability (list) | ✅ | content.dart:508 |
| `feat` | `asi_amount` | int | ✅ | content.dart:509 (0..2) |

**Verdict:** GAPS

**Eksik / Değişiklik Önerisi:**
- `background.asi_distribution` enum field: `['2_plus_1', '1_1_1']` — SRD 2024 background ASI seçeneği.
- Standard Array (15/14/13/12/10/8) ve Point Cost (27 puan) runtime constants — persistence değil.

#### C.2.3 §1.3 — Final Detay Hesapları (passive perception, init, AC, atk bonus, spell DC)

**Tetik:** derived (her stat değişikliğinde)
**Hedef Entity:** PlayerCharacter

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `combat_stats` | widget | ✅ | dm.dart:358 — AC/init/HP/speed widget |
| `player-character` | `passive_perception` | int | ✅ | dm.dart:371 |
| `player-character` | `passive_insight` | int | ✅ | dm.dart:372 |
| `player-character` | `passive_investigation` | int | ✅ | dm.dart:373 |
| `player-character` | `spell_save_dc` | int | ✅ | dm.dart:386 |
| `player-character` | `spell_attack_bonus` | int | ✅ | dm.dart:387 |
| `player-character` | `casting_ability_ref` | rel→ability | ✅ | dm.dart:385 |

**Verdict:** PASS — combat_stats widget'ının iç şeması (AC formula, init=DEX+misc) widget düzeyinde verify-when-implementing.

#### C.2.4 §1.4 — Level 1 HP (class-based formula)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `class` | `hit_die` | enum | ✅ | content.dart:348 (`d6/d8/d10/d12`), required |
| `player-character` | `combat_stats` (HP) | widget | ✅ | dm.dart:358 |
| `player-character` | `hit_dice_remaining` | proficiencyTable | ✅ | dm.dart:363 |

**Verdict:** PASS

#### C.2.5 §1.5 — Level Advancement (XP table, PB, fixed/rolled HP, ASI/Feat)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `xp` | int | ✅ | dm.dart:343 |
| `player-character` | `proficiency_bonus` | int | ✅ | dm.dart:344 |
| `player-character` | `class_levels` | levelTable | ✅ | dm.dart:339 |
| `player-character` | `hit_dice_remaining` | profTable | ✅ | dm.dart:363 |
| `player-character` | `feats` | rel→feat (list) | ✅ | dm.dart:345 |
| `class` | `features` | classFeatures | ✅ | content.dart:370 — level-by-level features |
| `subclass` | `features` | classFeatures | ✅ | content.dart:407 |
| `subclass` | `granted_at_level` | int | ✅ | content.dart:406 |

**Verdict:** PASS — XP→level threshold tablo `dnd5e_constants` (runtime).

#### C.2.6 §1.6 — Tiers of Play (1-4/5-10/11-16/17-20)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `tier-of-play` | (kategori) | — | ❌ | tier0Slugs'da yok |

**Verdict:** GAPS (informational only — runtime'da total_level/4 ile derive edilebilir; lookup gerek değil ama §A.1'de listelenmiş).

**Eksik / Değişiklik Önerisi:**
- Düşük öncelik. Lookup eklemek istenirse `tier-of-play` identifier-only kategori ekle (4 row: Local Heroes, Heroes of the Realm, Masters of the Realm, Masters of the World). Field eklemeye gerek yok.

#### C.2.7 §1.7 — Higher-Level Start (gold + magic item bundles)

**Tetik:** char-creation (level > 1)
**Hedef Entity:** PlayerCharacter

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `class` | `starting_gold_dice` | dice | ✅ | content.dart:365 — yalnız L1 |
| `background` | `starting_gold_gp` | int | ✅ | content.dart:472 |
| `background` | `gold_alternative_gp` | int | ✅ | content.dart:473 |
| `class` | `default_inventory_refs` | rel | ✅ | content.dart:361 |
| `class` | `equipment_choice_groups` | widget | ✅ | content.dart:364 |
| starter | higher-level bundles (L5/L11/L17 gold+items) | — | ❌ | SRD 2024 s.24: tier-bazlı starting bundle tablosu. Şemada karşılığı yok. |

**Verdict:** GAPS

**Eksik / Değişiklik Önerisi:**
- Yeni kategori `starter-bundle` (Tier-1) öner: `starting_level` (int 1/5/11/17), `starting_gold_gp` (int), `magic_item_choices` (rel→magic-item, list). PC creation flow tier'a göre okur.
- Alternatif: `dnd5e_constants`'a higher-level starting tablosu hard-code et — runtime resolver kullanır. Customization istenmiyorsa daha basit.

#### C.2.8 §1.8 — Multiclassing (prereq, HP, PB, profs, feature non-stack, slot table)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `class` | `multiclass_prereq_ability_refs` | rel→ability (list) | ✅ | content.dart:376 |
| `class` | `multiclass_prereq_min_score` | int | ✅ | content.dart:378 |
| `class` | `multiclass_requirements` | markdown | ✅ | content.dart:380 (narrative) |
| `class` | `caster_kind` | enum | ✅ | content.dart:368 (`None/Full/Half/Third/Pact/Ritual`) — multiclass slot table için |
| `player-character` | `class_refs` (list) | rel | ✅ | dm.dart:338 |
| `player-character` | `class_levels` | levelTable | ✅ | dm.dart:339 — per-class level |
| `player-character` | `proficiency_bonus` | int | ✅ | dm.dart:344 — total level bazlı |
| multiclass | granted-prof subset SRD s.25 | — | ⚠️ | Class.weapon_proficiency_categories tüm seti içeriyor; multiclass'ta sadece subset granted. Resolver ayrı tablo kullanmalı. |

**Verdict:** GAPS

**Eksik / Değişiklik Önerisi:**
- Class şemasına `multiclass_granted_proficiencies` (struct/widget veya text) ekle: SRD s.25 multiclass tablosu (örn. Barbarian multiclass'ta yalnızca shields + martial weapons, full set değil).
- Alternatif: `dnd5e_constants` içinde `multiclassProficiencyTable[classSlug]` map — runtime kullanım.

---

**D.2 Özet:**
- PASS: 3 (§1.3, §1.4, §1.5)
- GAPS: 5 (§1.1 alignment lookup, §1.2 background ASI distribution, §1.6 tier-of-play opsiyonel, §1.7 higher-level bundle, §1.8 multiclass prof subset)
- BLOCKED: 0 — char creation core çalıştırılabilir, ek refinement'lar gerekli

### D.3 Damage & Healing

Audit kaynağı: `dm.dart` PC (334-435), NPC (273-332), `content.dart` weapon (585+), spell (553+), monster (929+), mech §4.

#### C.3.1 §4.1 — Hit Points (max/current/bloodied)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `combat_stats` | widget | ✅ | dm.dart:358 — HP/maxHP/AC/init/speed |
| `player-character` | `temp_hp` | int | ✅ | dm.dart:359 |
| `player-character` | `death_saves_successes/failures` | int | ✅ | dm.dart:360-361 |
| `npc` / `monster` | (HP) | — | ✅ | content.dart/dm.dart `combat_stats` analog (denetim §B.2.17'de) |

**Verdict:** PASS — bloodied flag runtime derivation (currentHP ≤ maxHP/2).

#### C.3.2 §4.2 — Damage Roll (weapon/spell/min0)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `weapon` | `damage_dice` | dice | ✅ | content.dart:590, required |
| `weapon` | `damage_type_ref` | rel→damage-type | ✅ | content.dart:591 |
| `weapon` | `versatile_damage_dice` | dice | ✅ | content.dart:596 |
| `spell` | `effects` | spellEffectList | ✅ | content.dart:559 — typed DSL |
| `spell` | `damage_type_refs` | rel→damage-type (list) | ✅ | content.dart:562 |
| `creature-action` | `damage_dice` | dice | ✅ | content.dart:1049 |
| `creature-action` | `damage_type_ref` | rel→damage-type | ✅ | content.dart:1050 |

**Verdict:** PASS

#### C.3.3 §4.3 — Damage Types (13)

**Field Denetimi:** D.0.6'da PASS.

#### C.3.4 §4.4 — Resistance / Vulnerability / Immunity (order, no-stack, threshold)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `species` | `granted_damage_resistances` | rel→damage-type (list) | ✅ | content.dart:437 |
| `npc` | `resistance_refs` | rel→damage-type (list) | ✅ | dm.dart:288 |
| `npc` | `vulnerability_refs` | rel→damage-type (list) | ✅ | dm.dart:289 |
| `npc` | `damage_immunity_refs` | rel→damage-type (list) | ✅ | dm.dart:290 |
| `npc` | `condition_immunity_refs` | rel→condition (list) | ✅ | dm.dart:291 |
| `monster` | `resistance_refs/vulnerability_refs/...` | rel | ✅ | content.dart:935-938 |
| `player-character` | resistance/vulnerability/immunity | — | ❌ | **EKSİK** — PC'de bu field'lar yok. Species'ten granted ama PC base field'ı (resolver cache veya manual override) yok. |

**Verdict:** GAPS

**Eksik / Değişiklik Önerisi:**
- PC'ye `resistance_refs`, `vulnerability_refs`, `damage_immunity_refs`, `condition_immunity_refs` (rel list) ekle. NPC ile paralel.
- Resolver Species/Class/Magic-item kaynaklarını otomatik toplayabilse de, kullanıcı override + display için gerekli.
- Threshold/no-stack semantiği fm §0.6 grantedModifiers DSL üzerinden.

#### C.3.5 §4.5 — Critical Hit (dice ×2, mod 1×)

**Verdict:** PASS — runtime mechanic, weapon.damage_dice yeterli.

#### C.3.6 §4.6 — Saving Throws & Damage (multi-target, half-on-save)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `spell` | `save_ability_ref` | rel→ability | ✅ | content.dart:563 |
| `spell` | `effects` (DSL) | spellEffectList | ✅ | half-on-save effect tipi DSL içinde |
| `player-character` | `saving_throws` | profTable | ✅ | dm.dart:365 |

**Verdict:** PASS — half-on-save flag spellEffectList DSL içinde verify-when-implementing.

#### C.3.7 §4.7 — Healing (restore, max cap, excess lost)

**Verdict:** PASS — combat_stats HP/maxHP yeterli; runtime cap.

#### C.3.8 §4.8 — Dropping to 0 HP (death saves, massive damage, instant death)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `death_saves_successes` | int | ✅ | dm.dart:360 (0..3) |
| `player-character` | `death_saves_failures` | int | ✅ | dm.dart:361 (0..3) |

**Verdict:** PASS

#### C.3.9 §4.9 — Stabilizing (Help/Medicine, Healer's Kit, 1d4h)

**Verdict:** PASS — runtime action, schema desteği gerek değil.

#### C.3.10 §4.10 — Knock Out (non-lethal, SR start)

**Verdict:** PASS — combat decision, schema gerek değil.

#### C.3.11 §4.11 — Temporary HP (buffer, no-stack, LR clear)

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `temp_hp` | int | ✅ | dm.dart:359 |

**Verdict:** PASS

#### C.3.12 §4.12 — Resting (SR 1h HD spend, LR 8h full restore) ⭐ User priority

**Field Denetimi:**
| Kategori | Field | Tip | Mevcut? | Not |
|---|---|---|---|---|
| `player-character` | `hit_dice_remaining` | profTable | ✅ | dm.dart:363 |
| `class` | `hit_die` | enum | ✅ | content.dart:348 |
| `player-character` | `spell_slots` | slot | ✅ | dm.dart:390 — LR restore |
| `player-character` | `pact_magic_slots` | slot | ✅ | dm.dart:391 — SR restore |
| `player-character` | `class_resources` | profTable | ✅ | dm.dart:392 — class-specific (rage/ki/sorcery points) refresh on SR/LR |
| `class.features` | feature reset cadence | — | ⚠️ | classFeatures widget'ında her feature için `recharge: SR/LR/none` field olmalı. `dnd5e_constants` veya widget impl. doğrulanmalı. |

**Verdict:** GAPS

**Eksik / Değişiklik Önerisi:**
- `class.features` ve `subclass.features` (`classFeatures` widget) içinde her özellik için `recharge_on` enum (`['none', 'short_rest', 'long_rest', 'dawn']`) bulunmalı. Widget impl. denetimi gerek; yoksa eklenmeli.
- Rest action runtime resolver:
  - SR: HD harca (player choice), pact_magic_slots restore, class_resources whose recharge=SR restore.
  - LR: HP=max, spell_slots restore, all class_resources restore, half-HD restore (max(1, level/2)), exhaustion -1, temp_hp clear.

#### C.3.13 §4.13 — Hit Dice by class (d6/d8/d10/d12)

**Field Denetimi:** D.2.4'te PASS (`class.hit_die`).

#### C.3.14 §4.14 — Breaking Objects (object AC + HP table)

**Field Denetimi:** Şemada karşılığı yok — runtime constants tablo (object material/size → AC/HP).

**Verdict:** PASS — `dnd5e_constants`'a object hardness/HP tablosu eklenebilir; ayrı kategori gerek değil.

---

**D.3 Özet:**
- PASS: 11 (§4.1, §4.2, §4.3, §4.5, §4.6, §4.7, §4.8, §4.9, §4.10, §4.11, §4.13, §4.14)
- GAPS: 2 (§4.4 PC resistance fields; §4.12 feature recharge_on)
- BLOCKED: 0

### D.4 Conditions

#### C.4.1 — 15 Conditions (Blinded..Unconscious)

**Field Denetimi:** D.0.5'e referans — `condition` kategorisi PASS, 15 row seeded (lookups.dart:599-603), `stacks`/`grants_incapacitated`/`ends_on` field'ları mevcut.

**Applied Condition (Tier-2):**
| Field | Tip | Mevcut? | Not |
|---|---|---|---|
| `condition_ref` | rel→condition | ✅ | dm.dart:440, required |
| `source_entity_ref` | rel | ✅ | dm.dart:441 |
| `duration_rounds` | int | ✅ | dm.dart:442 (null = indefinite) |
| `save_dc` | int | ✅ | dm.dart:443 |
| `save_ability_ref` | rel→ability | ✅ | dm.dart:444 |
| `save_frequency` | enum | ✅ | dm.dart:445 (`none/start-of-turn/end-of-turn/when-damaged`) |

**Verdict:** PASS

### D.5 Combat

Audit kaynağı: PC `combat_stats` widget, `senses`, `current_conditions`; weapon `property_refs`/`mastery_ref`/`normal_range_ft`/`long_range_ft`; spell `area_shape_ref`; mech §3.

#### C.5.1 §3.1 — Combat Akışı (positions/initiative/turns/surprise/round)

Initiative DEX-bazlı runtime. Encounter kategorisi pozisyonları taşır.
**Verdict:** PASS — `encounter` (dm.dart:578) participants tracking; runtime turn machinery.

#### C.5.2 §3.2 — Turn Yapısı (Move + Action + BA + Reaction + obj interact)

Runtime; per-turn state log encounter widget'ında. Şema gerek değil.
**Verdict:** PASS

#### C.5.3 §3.3 — Movement (Speed, climb/swim/jump/prone/difficult terrain)

| Field | Mevcut? | Not |
|---|---|---|
| `species.speed_ft` | ✅ | content.dart:431 |
| PC.combat_stats (speed) | ✅ | widget içinde |
| `monster.speeds[]` | ⚠️ | denetim §B.2.17 |
| `speed-type` lookup (climb/swim/fly) | ❌ | tier0Slugs eksik |

**Verdict:** GAPS

**Eksik:** `speed-type` Tier-0 lookup ekle (identifier-only, rows: walk/climb/swim/fly/burrow). Species/Monster speed entries `speed_type_ref` + `range_ft` struct.

#### C.5.4 §3.4 — Creature Size & Space

D.0.1 BLOCKED → `size` lookup eksik. Şu an species/monster `_enumSizes` enum kullanıyor — string-bazlı, mekanik field yok.
**Verdict:** GAPS (D.0.1'e bağlı)

#### C.5.5 §3.5 — Actions (12: Attack/Dash/Disengage/Dodge/Help/Hide/Influence/Magic/Ready/Search/Study/Utilize)

| Field | Mevcut? | Not |
|---|---|---|
| `action` Tier-0 lookup | ❌ | tier0Slugs eksik |
| `creature-action` kategorisi | ✅ | content.dart:1065 — monster/NPC actions |

**Verdict:** GAPS

**Eksik:** `action` Tier-0 lookup ekle (identifier-only, 12 SRD action). `creature-action.action_type_ref` consume eder. Spell.casting_action_ref de buna bağlanır.

#### C.5.6 §3.6 — Bonus Action / §3.7 Reaction

Runtime turn-state. Spell.casting_action_ref + creature-action.action_type_ref kategorize eder. `action` lookup'a bağımlı.
**Verdict:** GAPS (§3.5'e bağlı)

#### C.5.7 §3.8 — Attack Roll Yapısı (choose/modify/resolve, crit, unseen)

Runtime resolver. PC stat_block + weapon damage + proficiency + adv/disadv aggregate.
**Verdict:** PASS

#### C.5.8 §3.9 — Cover (half / three-quarters / total)

`cover` Tier-0 lookup eksik (identifier-only). Mekanik runtime modifier.
**Verdict:** GAPS — düşük öncelik

#### C.5.9 §3.10 §3.11 — Ranged / Melee Attacks (range, reach)

| Field | Mevcut? | Not |
|---|---|---|
| `weapon.normal_range_ft` | ✅ | content.dart:594 |
| `weapon.long_range_ft` | ✅ | content.dart:595 |
| `weapon-property` (Reach +5ft, Range tag) | ✅ | mechanic_kind enum'da |
| `weapon.is_melee` | ✅ | content.dart:589 |

**Verdict:** PASS

#### C.5.10 §3.12 — Opportunity Attack

Runtime reaction trigger. Şema gerek değil.
**Verdict:** PASS

#### C.5.11 §3.13 — Equipping/Unequipping Weapons (free during Attack)

Runtime turn-action; PC.inventory + held-weapon state. Held-weapon state field'ı şemada görünmüyor.
**Verdict:** GAPS

**Eksik:** PC'ye `held_weapons` (rel→weapon, list, max 2) veya `equipped_weapons` ekle. Veya `inventory` widget içinde `is_equipped` flag.

#### C.5.12 §3.14 — Mounted Combat / §3.15 Underwater Combat

Runtime modifier. Mount kategorisi (content.dart:779) mevcut.
**Verdict:** PASS

#### C.5.13 §3.16 — Two-Weapon Fighting (Light + Nick + TWF feat)

| Field | Mevcut? | Not |
|---|---|---|
| `weapon-property` Light tag | ✅ | mechanic_kind=`two_weapon_fighting` (lookups.dart:776) |
| `weapon-mastery` Nick tag | ✅ | effect_kind=`extra_attack_light` (lookups.dart:849) |
| Feat: TWF | ✅ | feat kategorisi gen. |

**Verdict:** PASS

---

**D.5 Özet:**
- PASS: 9 (§3.1, §3.2, §3.8, §3.10, §3.11, §3.12, §3.14, §3.15, §3.16)
- GAPS: 7 (§3.3 speed-type, §3.4 size, §3.5/3.6/3.7 action lookup, §3.9 cover, §3.13 held weapons)
- BLOCKED: 0

### D.6 Equip / Unequip

#### C.6.1 §7.1 — Silah free draw/sheathe per Attack action
**Verdict:** GAPS — D.5.11'e bağlı (PC.held_weapons / equipped flag eksik).

#### C.6.2 §7.2 — Zırh don/doff times, sleeping in armor
| Field | Mevcut? | Not |
|---|---|---|
| `armor.don_time_minutes` | ✅ | content.dart:629 |
| `armor.doff_time_minutes` | ✅ | content.dart:630 |
| `armor.category_ref` | ⚠️ | enum (Light/Medium/Heavy/Shield); `armor-category` lookup eksik (D.0/D.1.4) |
| PC.equipped_armor | ❌ | PC.inventory var ama equipped armor flag yok |

**Verdict:** GAPS

**Eksik:** PC'ye `equipped_armor_ref` (rel→armor, single) + `equipped_shield_ref` (rel→armor, filtered to category=Shield). Veya inventory item üzerinde `is_equipped` bool.

#### C.6.3 §7.3 — Magic Items giyim slot rules
Slot semantiği SRD'de §12.10 (Wearing Limits). Şu an PC.attuned_items max 3 var; slot tipi (head/neck/ring/etc.) yok.
**Verdict:** GAPS

**Eksik:** `magic-item.body_slot_ref` enum veya new lookup `body-slot` (Head, Neck, Body, Cloak, Belt, Boots, Gloves, Ring (×2), Amulet). PC.equipped_magic_items struct (slot → item).

#### C.6.4 §7.4 §7.5 — Multiple/Paired (rings/boots)
Runtime constraint check.
**Verdict:** GAPS — §7.3'e bağlı.

#### C.6.5 §7.6 — Pact of the Blade / §7.7 Wild Shape Equipment
Class feature mekanikleri. classFeatures widget içinde DSL.
**Verdict:** PASS — feature DSL düzeyinde verify-when-implementing.

#### C.6.6 §7.8 — Attunement (short rest, max 3, prereq)
| Field | Mevcut? | Not |
|---|---|---|
| `magic-item.requires_attunement` | ✅ | content.dart:849 |
| `magic-item.attunement_class_refs` | ✅ | content.dart:851 |
| `magic-item.attunement_species_refs` | ✅ | content.dart:853 |
| `magic-item.attunement_alignment_refs` | ⚠️ | content.dart:855 — enum, `alignment` lookup yok |
| `magic-item.attunement_min_ability_ref` | ✅ | content.dart:857 |
| `magic-item.attunement_min_ability_score` | ✅ | content.dart:859 |
| `magic-item.attunement_spellcaster_only` | ✅ | content.dart:861 |
| `magic-item.attunement_prereq` | ✅ | content.dart:863 (narrative) |
| PC.attuned_items (max 3) | ✅ | dm.dart:376 — label "max 3" ama validation runtime |

**Verdict:** PASS — alignment lookup eksiği D.0'da bilinen.

---

**D.6 Özet:**
- PASS: 2 (§7.6/7.7, §7.8)
- GAPS: 4 (§7.1, §7.2, §7.3, §7.4-7.5)

### D.7 Equipment & Inventory

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §6.1 | Coins (denominations) | GAPS | PC.cp/sp/ep/gp/pp int ✅ (dm.dart:378-382); `coin` lookup BLOCKED (D.0.3) — direct fields ile çalışıyor |
| §6.2 | Carrying Capacity (STR×15) | GAPS | size lookup BLOCKED (D.0.1) — `size.carrying_multiplier` eksik |
| §6.3 | Buying & Selling (half value) | PASS | runtime |
| §6.4 | Weapon Properties | PASS | D.0.8 |
| §6.5 | Weapon Mastery | PASS | D.0.9 |
| §6.6 | Improvised Weapons | PASS | `weapon-property.mechanic_kind=improvised` (lookups.dart:783) |
| §6.7 | Armor (light/medium/heavy/shield) | GAPS | armor schema ✅ ama `armor-category` lookup eksik (enum fallback) |
| §6.8 | Armor Training | PASS (D.1.4 GAPS bağlı) | class.armor_training_refs enum |
| §6.9 | Tools | GAPS | tool schema ✅ ama `tool-category` lookup eksik |
| §6.10 | Adventuring Gear | PASS | content.dart:681+ schema ✅ |
| §6.11 | Spellcasting Focus | PASS | class.spellcasting_focus_ref ✅, arcane/druidic/holy ✅ |
| §6.12 | Mounts & Vehicles | PASS | mount (content.dart:779), vehicle (808) ✅ |
| §6.13 | Lifestyle Expenses | BLOCKED | `lifestyle` lookup eksik (D.0.4); PC.current_lifestyle_ref de eksik |
| §6.14 | Hirelings | PASS | hireling (dm.dart:732) Tier-2 ✅ |
| §6.15 | Spellcasting Services | PASS | service (dm.dart:755) ✅ |
| §6.16 | Crafting | BLOCKED | `rarity.crafting_*` BLOCKED (D.0.2); tool.craftable_items ✅ ama maliyet/süre kuralı yok |
| §6.17 | Brewing Potions | PASS | runtime recipe; rarity.crafting_*'a bağlı |
| §6.18 | Scribing Spell Scrolls | PASS | runtime recipe; spell.level + rarity.value_gp formula |

**Eksik / Değişiklik Önerisi:**
- PC'ye `current_lifestyle_ref` (rel→lifestyle) ekle — §6.13 için.
- D.0'ın 5 lookup'ı (size/rarity/coin/lifestyle/duration-unit) eklenince §6.1, §6.2, §6.13, §6.16, §6.17, §6.18 PASS olur.
- `armor-category` ve `tool-category` Tier-0 lookup'ları (identifier-only) ekle → §6.7, §6.9 enum→relation upgrade.

**D.7 Özet:** PASS 11, GAPS 4 (§6.1, §6.2, §6.7, §6.9), BLOCKED 2 (§6.13, §6.16). D.0 fix'leri yapılırsa GAPS/BLOCKED'in 5'i resolve.

### D.8 Spells

Audit kaynağı: `content.dart::_spellCategory` (538+), PC spell fields (385-391), `class.caster_kind` (368), mech §8.

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §8.1 | Spell Levels & Slots | PASS | spell.level (0..9), PC.spell_slots widget, class.spell_slots_by_level levelTable |
| §8.2 | Preparation by Class | PASS | PC.spells_known + prepared_spells; class.prepared_spells_by_level levelTable |
| §8.3 | Pact Magic | PASS | class.caster_kind=`Pact`, PC.pact_magic_slots slot widget |
| §8.4 | Casting Time | GAPS | spell.casting_time_amount/unit ✅; `casting-time-unit` lookup eksik (enum fallback) |
| §8.5 | One Slot per Turn | PASS | runtime turn-state |
| §8.6 | Components V/S/M | GAPS | spell.components enum list ✅; `casting-component` lookup eksik (enum fallback). material_description/cost/consumed ✅ |
| §8.7 | Range | PASS | spell.range_type enum + range_ft |
| §8.8 | Duration | GAPS | spell.duration_unit_ref enum + amount; `duration-unit` lookup BLOCKED (D.0.7) |
| §8.9 | Concentration | PASS | spell.requires_concentration bool ✅; runtime active-concentration tracker (PC fields denetle) |
| §8.10 | Spell DCs & Attacks | PASS | PC.spell_save_dc, spell_attack_bonus, casting_ability_ref ✅ |
| §8.11 | Targets | PASS | spell.effects DSL içinde target type |
| §8.12 | Areas of Effect | GAPS | spell.area_shape_ref enum + area_size_ft ✅; `area-shape` lookup eksik (enum fallback) |
| §8.13 | Combining Effects | PASS | runtime stacking rules; effects DSL |
| §8.14 | Casting in Armor | PASS | spell.school + class spellcasting + armor proficiency runtime check |
| §8.15 | Schools of Magic | PASS | `spell-school` Tier-0 ✅ (8 row seeded) |
| §8.16 | Spell Scrolls | PASS | magic-item with rarity_ref by spell level (rarity BLOCKED → D.0.2) |
| §8.17 | Magic Items Casting Spells | PASS | magic-item rules narrative + activation field (denetim §B.2.12) |

**Active Concentration Tracker:** PC'de `current_concentration_spell_ref` (rel→spell) ve `current_concentration_remaining` (int rounds) eksik olabilir — runtime ephemeral ama persistence yararlı.

**Eksik / Değişiklik Önerisi:**
- D.0'ın 5 lookup fix'iyle §8.4, §8.6, §8.8, §8.12 enum→relation upgrade.
- PC'ye `concentration_spell_ref` + `concentration_remaining_rounds` ekle (§8.9 derinleştirme).

**D.8 Özet:** PASS 13, GAPS 4. Tüm GAPS'ler D.0 lookup eksikliğine bağlı.

### D.9 Class

`class` schema (content.dart:343-400) tüm core feature'ları içeriyor: hit_die, primary/secondary_ability_ref, saving_throw_refs, skill/weapon/tool/armor profs, default_inventory + equipment_choice_groups, starting_gold_dice, caster_kind, casting_ability_ref, classFeatures (level-by-level), levelTable cantrips/prepared/slots, multiclass prereqs.

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §9.1 | Genel Pattern | PASS | class schema complete |
| §9.2-§9.13 | 12 Class spesifik (Barbarian..Wizard) | PASS (data-level) | Her class kendi `features` (classFeatures DSL) ile ayırt edilir; runtime resolver feature DSL yorumu yapar. Per-class denetim runtime'da. |

**GAPS (genel):**
- D.1.4 (weapon-category/armor-category enum→relation)
- D.2.8 (multiclass prof subset)
- D.3.12 (feature recharge_on field)

**D.9 Özet:** schema-level PASS, feature-DSL düzeyinde runtime verify gerek. Per-class audit ayrı sprint.

### D.10 Origin

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §10.1 | Background Parts | PASS | content.dart:458 — granted_skill_refs, granted_tool_refs, ability_score_options, origin_feat_ref, default_inventory_refs, equipment_choice_groups, starting_gold_gp, gold_alternative_gp |
| §10.2 | Backgrounds (16 SRD) | PASS (schema) | Per-background row data ayrı sprint |
| §10.3 | Species Parts | GAPS | content.dart:427 — size_ref **enum** (D.0.1), speed_ft int, creature_type_ref ✅, granted_modifiers ✅, trait_refs ✅, granted_languages ✅, granted_senses ✅, granted_damage_resistances ✅, granted_skill_proficiencies ✅. Ek: speed-type breakdown eksik (sadece speed_ft tek değer). |
| §10.4 | Species (9 SRD) | PASS (schema) | Per-species data ayrı sprint |
| §10.5 | Languages | PASS | `language` lookup 19 row ✅ (lookups.dart:692-693) Standard+Rare tier |

**Eksik:**
- Species'e multi-speed support: `speeds` widget (speed_type_ref + range_ft list) — monster gibi (content.dart:922-927).

**D.10 Özet:** Background PASS; Species GAPS (size lookup + multi-speed); Languages PASS.

### D.11 Feats

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §11.1 | Categories | GAPS | feat.category_ref **enum** (`Origin/General/Fighting Style/Epic Boon`); `feat-category` lookup eksik |
| §11.2 | Origin Feats | PASS | category=Origin filter |
| §11.3 | General Feats | PASS | category=General + prereqs |
| §11.4 | Fighting Style | PASS | category=Fighting Style |
| §11.5 | Epic Boon | PASS | category=Epic Boon |

**Feat schema fields:** category_ref, prereq_ability_ref + min_score, prereq_class_refs, prereq_species_refs, prereq_min_character_level, prereq_requires_spellcasting, prerequisite (narrative), repeatable + repeatable_limit, asi_ability_options + asi_amount. (content.dart:493-509). Granted modifiers field denetlenmedi — devamı:

**Eksik denetim:** feat'ın `granted_modifiers` (DSL) ve `effects` markdown alanları görünür mü?

### D.12 Magic Items

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §12.1 | Categories (9) | PASS | `magic-item-category` lookup ✅ 9 row |
| §12.2 | Rarity & Value | BLOCKED | `rarity` lookup BLOCKED (D.0.2); şu an enum |
| §12.3 | Identification | PASS | runtime; ayrı field gerek değil |
| §12.4 | Attunement | PASS | D.6.6 |
| §12.5 | Activation | PASS | activation enum ✅ (None/Magic Action/Bonus Action/Reaction/Utilize/Command Word/Consumable), command_word, charges_max, charge_regain |
| §12.6 | Crafting | BLOCKED | rarity.crafting_* BLOCKED (D.0.2) |
| §12.7 | Sentient Items | PASS | is_sentient + sentient_int/wis/cha/alignment/communication/senses/special_purpose ✅ |
| §12.8 | Cursed Items | PASS | is_cursed bool ✅; curse Tier-2 (dm.dart:678) |
| §12.9 | Magic Item Resilience | PASS | runtime (object hardness); §4.14 ile aynı |
| §12.10 | Wearing Limits | GAPS | body_slot field eksik (D.6.3) |
| §12.11 | Potion Miscibility | PASS | runtime DM table |

**D.12 Özet:** PASS 9, BLOCKED 2 (rarity), GAPS 1 (body_slot).

### D.13 Hazards & Environment

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §13.1 | Burning | PASS | `hazard` row ✅ + DSL/runtime |
| §13.2 | Falling | PASS | hazard row ✅ |
| §13.3 | Dehydration | PASS | hazard row ✅ |
| §13.4 | Malnutrition | PASS | hazard row ✅ |
| §13.5 | Suffocation | PASS | hazard row ✅ |
| §13.6 | Environmental Effects | PASS | environmental-effect (dm.dart:708) ✅ + hazard_ref |
| §13.7 | Curses | PASS | curse (dm.dart:678) ✅ |
| §13.8 | Magical Contagions | PASS | environmental-effect veya curse alt-tipi runtime |
| §13.9 | Fear & Mental Stress | PASS | applied-condition (Frightened) ✅ |
| §13.10 | Poison | PASS | poison (dm.dart:647) Tier-2 ✅ |
| §13.11 | Traps | PASS | trap (dm.dart:615) Tier-2 ✅ |
| §13.12 | Vision & Light | GAPS | `illumination` lookup eksik; scene/location.illumination_ref şu an enum |
| §13.13 | Hiding | PASS | runtime (Stealth check) |

### D.14 Travel & Exploration

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §14.1 | Travel Pace | GAPS | `travel-pace` lookup eksik (identifier-only, scene.travel_pace_ref consumer) |
| §14.2 | Travel Terrain Table | PASS | runtime constants (`dnd5e_constants`) |
| §14.3 | Extended Travel | PASS | runtime |
| §14.4 | Special Movement | GAPS | `speed-type` lookup eksik (D.5.3) |
| §14.5 | Marching Order | PASS | encounter.participants ordered list |
| §14.6 | Vehicles | PASS | vehicle (content.dart:808) ✅ |

### D.15 Social Interaction

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §15.1 | Attitude | GAPS | `attitude` lookup eksik (npc.attitude_ref consumer); şu an enum |
| §15.2 | Influence Action | PASS | runtime check (DC + skill) |

### D.16 Encounters & XP

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §16.1 | XP Budget per Character | PASS | runtime constants (CR→XP table) |
| §16.2 | Difficulty | PASS | encounter (dm.dart:578) ✅ + runtime calc |
| §16.3 | Encounter Tweaks | PASS | runtime DM tooling |

### D.17 Monsters & Stat Blocks

`monster` schema (content.dart:908+) tüm SRD stat-block field'larına sahip:
- size_ref (enum, size lookup eksik), creature_type_ref ✅, alignment (enum, lookup eksik)
- ac, ac_note, initiative_*, hp_average, hp_dice
- speeds (walk/burrow/climb/fly/swim) + can_hover ✅
- stat_block widget, save_bonuses, skill_bonuses
- resistances/vulnerabilities/immunities/condition_immunities ✅
- senses (rangedSenseList), passive_perception, language_refs, telepathy_ft
- cr enum (0..30), xp, proficiency_bonus
- (devamı denetlenmedi — actions, traits, legendary)

| § | Mekanik | Verdict | Not |
|---|---|---|---|
| §17.1 | Stat Block Parts | GAPS | size+alignment lookup eksik (D.0); core fields tamam |
| §17.2 | CR & PB | PASS | cr enum + xp + proficiency_bonus ✅ |
| §17.3 | Creature Types (14) | PASS | `creature-type` lookup 14 row ✅ |

---

## §E İş Akışı (Step-by-Step)

Her audit turu **tek mekanik** üzerinedir. Adımlar:

1. **B.2 listesinden bir sonraki işaretsiz mekaniği seç.**
2. **İlgili kategorileri belirle:** mekaniğin tetiği nereden geliyor, hangi entity'yi etkiliyor, hangi lookup'ı tüketiyor.
3. **Sadece o kategorilerin şema satırlarını oku** — `srd_5e_field_mechanics.md` §1.2 / §2.X / §3.X. (Diğer içeriği bağlama yükleme; kontekst tasarrufu.)
4. **Field tablosunu doldur:** her gerekli field için ✅ (mevcut + doğru tip + doğru tetik), ⚠️ (var ama eksik/yanlış), ❌ (yok).
5. **Verdict yaz:** PASS / GAPS / BLOCKED.
6. **GAPS / BLOCKED ise** öneri ekle: hangi kategoriye, hangi field, hangi tip, neden. **Şemayı bu turda değiştirme** — sadece denetim notu. Toplu refaktör ayrı PR.
7. **B.2'deki checkbox'ı işaretle:** `[a]` audit yapıldı; gap varsa `[g]`; doc önerisi yazıldıysa `[d]`.
8. **Kontekst temizliği:** o turdaki dosya okuma/notları sıfırla; bir sonraki mekanik için tekrar §3-7.

---

## §F Notlar

- Bu doküman **fact-finding** odaklı. Kod/şema değişikliği bu turda yok; öneri yazılır, sonraki PR uygular.
- Multiclass davranışı her mekaniğin "Veri Akışı" bölümünde ayrıca işaretlenir (sum/take-highest/non-stack).
- 3-state checkbox sistemi (planned/supported/implemented) `mechanics.md` ve `field_mechanics.md`'de korunur — bu dosya `[a][g][d]` ayrı semantiği kullanır (audit progress).
- Açık mekanik (`field_mechanics.md` §5) ile ortak bulgular: yeni öneri yerine §5'e cross-link.

---

## §G Konsolide Bulgular (2026-04-29 Audit Turu)

### G.1 Audit İstatistiği

128 mekanik denetlendi. Sonuç:

| Sonuç | Sayı | Pay |
|---|---|---|
| PASS | ~88 | ~69% |
| GAPS | ~33 | ~26% |
| BLOCKED | 7 | ~5% |

### G.2 Tek-Sebep Hot Path: Eksik Tier-0 Lookup'lar

`flutter_app/lib/domain/entities/schema/builtin/lookups.dart` 15 kategori içeriyor; SRD §A.1 spec'i 37 bekliyor. **22 eksik kategori** GAPS/BLOCKED'in büyük çoğunluğunu üretiyor.

#### G.2.1 Mekanik field'lı eksik lookup'lar (öncelik P0)

Bu 5 lookup'ın **doğrudan mekanik field'ı** var; eklenmesi resolver yazılabilirliği için zorunlu:

| Lookup | Mekanik Field'ları | Etkilenen Mekanikler |
|---|---|---|
| `size` | `space_ft`, `hit_die_size`, `carrying_multiplier` | §3.4 (creature space), §6.2 (carry), §10.3 (species), §17.1 (monster) |
| `rarity` | `value_gp`, `crafting_time_days`, `crafting_cost_gp` | §6.16, §6.17, §6.18, §12.2, §12.6 |
| `coin` | `value_in_gp` | §6.1 |
| `lifestyle` | `cost_per_day_gp` | §6.13 |
| `duration-unit` | `is_concentration_compatible` | §8.8, §8.9 |

#### G.2.2 Identifier-only eksik lookup'lar (öncelik P1)

Mekanik field'ı yok ama Tier-1/Tier-2 relation hedefleri olarak gerekli — şu an enum fallback kullanılıyor; runtime tutarlılık ve user-extensibility kayıp:

| Lookup | Tüketen | Field |
|---|---|---|
| `alignment` | PC, NPC, Monster, MagicItem | `alignment_ref` enum → relation |
| `weapon-category` | Class, PC, Weapon | `weapon_proficiency_categories`, `category_ref` enum → relation |
| `armor-category` | Class, PC, Armor | `armor_trainings`, `category_ref` enum → relation |
| `tool-category` | Tool | `category_ref` enum → relation |
| `feat-category` | Feat | `category_ref` enum → relation |
| `speed-type` | Species/Monster speeds | (yeni struct) |
| `action` | Spell, creature-action | `casting_action_ref`, `action_type_ref` |
| `area-shape` | Spell | `area_shape_ref` enum → relation |
| `attitude` | NPC | `attitude_ref` enum → relation |
| `cover` | runtime helper | (lookup-only, mekanik yok) |
| `illumination` | Scene, Location | `illumination_ref` enum → relation |
| `tier-of-play` | informational | (opsiyonel) |
| `travel-pace` | Scene | `travel_pace_ref` enum → relation |
| `plane` | Location | `plane_ref` enum → relation |
| `casting-component` | Spell | `components` enum → relation |
| `casting-time-unit` | Spell | `casting_time_unit_ref` enum → relation |

### G.3 Schema-Field Eksiklikleri (lookup-bağımsız)

| # | Kategori | Eksik Field | Neden | Mekanik |
|---|---|---|---|---|
| 1 | `player-character` | `resistance_refs`, `vulnerability_refs`, `damage_immunity_refs`, `condition_immunity_refs` | NPC/Monster'a paralel | §4.4 |
| 2 | `player-character` | `equipped_armor_ref`, `equipped_shield_ref` (veya inventory.is_equipped) | Don/doff tracking | §7.2 |
| 3 | `player-character` | `held_weapons` (rel→weapon, max 2) veya `equipped_weapons` | Free draw/sheathe | §3.13, §7.1 |
| 4 | `player-character` | `equipped_magic_items` (slot map) veya magic-item.body_slot_ref | Wearing limits | §7.3, §12.10 |
| 5 | `player-character` | `current_lifestyle_ref` | Downtime expense | §6.13 |
| 6 | `player-character` | `concentration_spell_ref`, `concentration_remaining_rounds` | Active concentration tracking | §8.9 |
| 7 | `background` | `asi_distribution` enum (`2_plus_1` / `1_1_1`) | SRD 2024 background ASI dağılımı | §1.2 |
| 8 | `class` | `multiclass_granted_proficiencies` (struct) | SRD s.25 multiclass prof subset | §1.8 |
| 9 | `class.features` / `subclass.features` | `recharge_on` enum (none/short_rest/long_rest/dawn) per feature | Rest mechanic | §4.12 |
| 10 | `species` | multi-`speeds` widget (speed_type+range, monster gibi) | Multi-speed support | §10.3 |
| 11 | `magic-item` | `body_slot_ref` (yeni `body-slot` lookup veya enum) | Wearing limits | §7.3, §12.10 |
| 12 | starter | `starter-bundle` Tier-1 kategorisi (L5/L11/L17 başlangıç) | Higher-level start | §1.7 |

### G.4 Önerilen PR Sırası

1. **PR-1 (Foundation):** lookups.dart'a P0 mekanik-field'lı 5 lookup ekle (size/rarity/coin/lifestyle/duration-unit). Field type, seed rows, tier0Slugs güncelleme. **Etki:** ~10 mekanik PASS'a geçer.
2. **PR-2 (Identifier Lookups):** P1 16 identifier-only lookup'ı ekle. Migration: enum string → entityId map. **Etki:** ~12 mekanik enum→relation upgrade.
3. **PR-3 (PC Combat State):** PC'ye G.3#1, #2, #3, #4, #6 field'ları ekle. **Etki:** §3.13, §4.4, §7.1-7.3, §8.9 PASS.
4. **PR-4 (Char Creation Edge):** G.3#7, #8, #9, #10 ekle. **Etki:** §1.2, §1.8, §4.12, §10.3 PASS.
5. **PR-5 (Magic Item Slot):** G.3#11 + body-slot lookup. **Etki:** §7.3, §12.10 PASS.
6. **PR-6 (Higher-Level Start):** G.3#12. **Etki:** §1.7 PASS. Düşük öncelik.

### G.5 User Priority (Char Creation, Management, Level-up, Rest)

User'ın özellikle önem verdiği alanlar:

| Alan | Durum | Blocker |
|---|---|---|
| **Karakter Yaratma** (D.2) | 3 PASS / 5 GAPS | §1.1 alignment lookup, §1.2 background ASI dist, §1.7 higher-level bundle, §1.8 multiclass profs |
| **Yönetim** (PC schema) | Çoğu PASS | G.3#1 resistances, #2-4 equipped state, #5 lifestyle, #6 concentration |
| **Level-up** (§1.5) | PASS | feature recharge_on (D.3.12) sadece runtime impact |
| **Rest** (§4.12) | GAPS | feature recharge_on widget alanı |

**Öneri:** PR-3 ve PR-4'ü öncelendir; user-priority alanların 80%+'ı bu iki PR ile resolve.
