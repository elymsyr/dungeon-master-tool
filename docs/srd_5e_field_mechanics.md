# D&D 5e Şema Alanı → Mekanik Eşlemesi

Bu döküman `flutter_app/lib/domain/entities/schema/builtin/` altındaki **kategori şemalarını** SRD 5.2.1 mekaniğine bağlar. Her kategori → field → mekanik bir satır. Amaç: ileride yazılacak resolver implementation'ı için deterministik spec; homebrew yazarının "şu field'ı doldurursam karaktere ne olur" sorusunu netleştirmek; şema-vs-SRD uyuşmazlıklarını "açık mekanik" olarak işaretlemek.

Eşlik eden kural referansı: [`srd_5e_mechanics.md`](srd_5e_mechanics.md). Bu döküman *şema → kural*; o döküman *SRD → kural*.

---

## §0 Okuma Rehberi

### 0.1 Sütun Anlamları (controlled vocabulary)

Tüm tablolar 7 sabit sütun kullanır:

| Sütun | Anlam |
|---|---|
| **Alan** | `field_key` code-style + bold etiket. `*` zorunlu (`isRequired: true`). `[]` suffix `isList: true`. |
| **Tip / Liste** | `text`, `textarea`, `markdown`, `integer`, `boolean`, `enum{a,b,c}`, `relation→[allowedTypes]`, `dice`, `slot`, `statBlock`, `combatStats`, `proficiencyTable`, `levelTable`, `levelTextTable`, `image`, `file`, `pdf`, `tagList`. Validation min/max parantez içinde. |
| **Tetik** | Değer ne zaman akar. Tek vokabüler: `assign` / `level-up:N` / `equip` / `attune` / `cast` / `attack` / `damage-roll` / `save-roll` / `long-rest` / `short-rest` / `turn-start` / `turn-end` / `always` / `derived` / `n/a`. |
| **Hedef Stat** | Tüketici entity üzerinde tam yol. Örn: `PlayerCharacter.saving_throw_proficiencies[]`, `derived: spell_save_dc`, `Monster.ac`. Identifier-only ise `—`. |
| **Operasyon** | `set` / `append` / `union` / `replace-if-higher` / `sum` / `formula(expr)` / `enum-tag` / `lookup` / `roll-and-set` / `manual-import` / `source` / `gate` / `none`. Formüller code-style. |
| **Multiclass** | `n/a` (class-dışı) / `per-class` / `take-highest` / `sum` / `union` / `first-class-only` / `combined-table` / `non-stack`. |
| **SRD / Notlar** | SRD sayfa referansı (`s.NN`) + 1 satır edge case. Forward-link mechanics.md'ye (`→ §X.Y`). |

### 0.2 Hedef Entity Tipleri

Field değerinin ETKİLEDİĞİ entity tipleri:

- **PlayerCharacter** (`slug: player-character`) — oyuncu karakteri. En ağır consumer.
- **NPC** (`slug: npc`) — kampanya NPC'si. PC ile büyük ölçüde paralel; subset.
- **Monster** (`slug: monster`) — stat-block tabanlı yaratık. Bestiary entry; instance kullanımda Encounter üzerinden bağlanır.
- **Animal** (`slug: animal`) — Monster delta (aynı şekil; bkz. §2.20).
- **AppliedCondition** (`slug: applied-condition`) — bir Condition lookup'ının bir karakter/NPC/monster'a uygulanmış instance'ı. Süre + save DC taşır.

### 0.3 Yardımcı Semboller

Formüllerde sabit sembol seti:

| Sembol | Tanım |
|---|---|
| `PB` | `proficiencyBonusForLevel(total_character_level)` (dnd5e_constants.dart). L1-4 +2, L5-8 +3, L9-12 +4, L13-16 +5, L17-20 +6. |
| `ability_mod(X)` | `floor((X - 10) / 2)`; X bir ability score (1-30). |
| `spell_mod` | `ability_mod(casting_ability_ref)`. |
| `total_level` | `Σ PlayerCharacter.class_levels.values`. |
| `level_in(C)` | `PlayerCharacter.class_levels[C]` veya 0. |
| `caster_total_level` | `Σ over caster classes (per-class fraction × level)` per SRD §1.8 / s.26. |

### 0.4 Multiclass Vokabülerinin SRD §1.8 Eşlemesi

| Token | SRD anlamı |
|---|---|
| `first-class-only` | Save proficiencies, full skill choices, full tool choices, starting equipment, starting gold — sadece KARAKTERin ilk sınıfından (s.25). |
| `per-class subset` | Multiclass tablosundaki kısıtlı subset (örn. Barb multiclass'a girince sadece Shields + Martial weapon training; full Barb starting profs alınmaz). |
| `per-class` | Her sınıf seviyesinde kendi field değeriyle hesaplanır; toplanır veya ayrı tutulur. |
| `combined-table` | SRD §1.8 s.26 multiclass spell slot tablosu — Full=1×lvl, Half=½lvl, Third=⅓lvl. Tüm caster sınıfların etkili level'ları toplanır → tek slot satırı. |
| `non-stack` | Birden fazla sınıf aynı feature'ı sağlasa da yalnız bir tane uygulanır (Extra Attack, Unarmored Defense). |
| `take-highest` | Birden fazla kaynak farklı değer veriyorsa en yüksek (örn. Speed bonusu). |
| `sum` | Tüm kaynaklar toplanır (HD havuzu, total level). |
| `union` | Set birleşimi; aynı eleman bir kez sayılır (skill prof, weapon prof). |

### 0.5 Tetik Zincirleri

Bir field'ın değerinin başka field'lara yansıması "tetik zinciri" oluşturur. Örnek:

```
xp (PlayerCharacter) ─assign→ class_levels (level-up) ─derived→ total_level
                                                        ─derived→ PB
                                                        ─level-up:N→ class.feature_table[N]
                                                        ─level-up:N→ class.spell_slots_by_level[N]
                                                        ─long-rest→ spell_slots
```

Tam zincirler §4'te (3 ana akış).

---

## §1 Tier-0 Lookup Kategorileri

Tier-0 lookups **identifier** sağlar — kendi başlarına mekanik taşımazlar; mekanikleri *tüketen* entity'lerde (Class, PlayerCharacter, Spell, Weapon, vs.) saklanır. Bu bölümde sadece **identifier-only** lookups toplu listelenir; gerçek mekanik etkisi olan lookup field'ları §1.2'de tablolaşır.

### 1.1 Identifier-Only Lookups (36 kategori)

Her satır: bu lookup'ın `slug`'ı ve hangi consumer field'lardan referans aldığı. Field'ların kendileri sadece `name`, `description`, `icon` gibi tanımlayıcı bilgi taşır — mekanik etki §2/§3 satırlarında.

| Lookup | Slug | Tüketen alanlar (örnek) | SRD |
|---|---|---|---|
| Ability | `ability` | `Class.primary_ability_ref`, `Class.saving_throw_refs[]`, `Class.casting_ability_ref`, `Spell.save_ability_ref`, `PlayerCharacter.saving_throw_proficiencies[]` | s.5 |
| Skill | `skill` | `Class.skill_proficiency_options[]`, `PlayerCharacter.skill_proficiencies[]`, `PlayerCharacter.expertise_skills[]` | s.9 |
| Damage Type | `damage-type` | `Spell.damage_type_refs[]`, `Weapon.damage_type_ref`, `Monster.damage_resistances[]/immunities[]/vulnerabilities[]` | s.180 |
| Condition | `condition` | `Spell.applied_condition_refs[]`, `Monster.condition_immunities[]`, `AppliedCondition.condition_ref` | s.179 |
| Size | `size` | `Species.size_ref`, `Monster.size_ref`. Field: `space_ft` mekanik (§1.2). | s.14 |
| Creature Type | `creature-type` | `Species.creature_type_ref`, `Monster.creature_type_ref` | s.83 |
| Alignment | `alignment` | `PlayerCharacter.alignment_ref`, `NPC.alignment_ref`, `Monster.alignment_ref` | s.21 |
| Language | `language` | `Species.granted_languages[]`, `PlayerCharacter.languages[]`, `Background.granted_languages[]` | s.20 |
| Weapon Category | `weapon-category` | `Class.weapon_proficiency_categories[]`, `PlayerCharacter.weapon_proficiencies[]`, `Weapon.weapon_category_ref` | s.89 |
| Weapon Property | `weapon-property` | `Weapon.property_refs[]` | s.89-90 |
| Weapon Mastery | `weapon-mastery` | `Weapon.mastery_property_ref` | s.90 |
| Armor Category | `armor-category` | `Class.armor_training_refs[]`, `Armor.armor_category_ref`, `PlayerCharacter.armor_trainings[]` | s.92 |
| Tool Category | `tool-category` | `Tool.tool_category_ref` | s.93 |
| Spell School | `spell-school` | `Spell.school_ref` | s.105 |
| Magic Item Category | `magic-item-category` | `MagicItem.category_ref` | s.204 |
| Rarity | `rarity` | `MagicItem.rarity_ref`. Fields: `value_gp`, `crafting_*` mekanik (§1.2). | s.205 |
| Speed Type | `speed-type` | `Species.granted_senses[]`'in yanı sıra movement entries; `Monster.speeds[]` | s.14 |
| Sense | `sense` | `Species.granted_senses[]`, `PlayerCharacter.senses[]`, `Monster.senses[]` | s.11 |
| Action | `action` | `Spell.casting_action_ref`, `creature-action.action_type_ref` | s.9-10 |
| Area of Effect Shape | `area-shape` | `Spell.area_shape_ref` | s.106 |
| Attitude | `attitude` | `NPC.attitude_ref` | s.10 |
| Cover | `cover` | (combat helper; mekanik §3.9 mechanics.md'de) | s.15 |
| Illumination | `illumination` | `Scene.illumination_ref`, `Location.illumination_ref` | s.11 |
| Hazard | `hazard` | `Location.hazard_refs[]`, `EnvironmentalEffect.hazard_ref` | s.12 |
| Feat Category | `feat-category` | `Feat.category_ref` | s.87 |
| Lifestyle | `lifestyle` | `PlayerCharacter` downtime; field `cost_per_day_gp` mekanik (§1.2) | s.101 |
| Coin | `coin` | `PlayerCharacter.{cp,sp,ep,gp,pp}`; field `value_in_gp` mekanik (§1.2) | s.89 |
| Tier of Play | `tier-of-play` | (informational; mekanik §1.6 mechanics.md'de) | s.23-24 |
| Travel Pace | `travel-pace` | `Scene.travel_pace_ref` | s.192 |
| Arcane Focus | `arcane-focus` | `Class.spellcasting_focus`, `MagicItem` cinsi | s.96 |
| Druidic Focus | `druidic-focus` | `Class.spellcasting_focus`, `MagicItem` cinsi | s.96 |
| Holy Symbol | `holy-symbol` | `Class.spellcasting_focus`, `MagicItem` cinsi | s.97 |
| Plane | `plane` | `Location.plane_ref` | (lore) |
| Casting Component | `casting-component` | `Spell.component_refs[]` (V/S/M) | s.105 |
| Casting Time Unit | `casting-time-unit` | `Spell.casting_time_unit_ref` | s.105 |
| Duration Unit | `duration-unit` | `Spell.duration_unit_ref`. Field: `is_concentration_compatible` mekanik (§1.2). | s.106 |

### 1.2 Mekaniği Olan Lookup Alanları

Tier-0 lookup *kendi field'ları arasında* bazıları doğrudan mekanik üretir. Bu satırlar tablo formatında:

| Lookup.Alan | Tip | Tetik | Hedef Stat | Operasyon | SRD / Notlar |
|---|---|---|---|---|---|
| **`size.space_ft`** | int | always | Creature.space (square edge ft) | lookup | s.14. Tiny=2.5, S/M=5, Large=10, Huge=15, Gargantuan=20. |
| **`size.hit_die_size`** | enum | n/a | — (referans; gerçek HD `class.hit_die`'den) | lookup | s.22. Sadece monster default HD için fallback. |
| **`size.carrying_multiplier`** | float | always | `PlayerCharacter.carrying_capacity` | formula(`STR × 15 × multiplier`) | s.16. Tiny ×0.5, S/M ×1, Large ×2, Huge ×4, Gargantuan ×8. |
| **`sense.default_range_ft`** | int | always | rangedSense fallback range | lookup | Darkvision 60, Truesight 120, Blindsight 30, Tremorsense 60. Consumer override eder. |
| **`damage-type.bypassable_by_magical`** | boolean | damage-roll | derived: nonmagical resistance bypass | enum-tag | Magical/silvered/adamantine weapon nonmagical-only resistance'ı bypasses. Sadece B/P/S için true. |
| **`rarity.value_gp`** | integer | sell/buy | `PlayerCharacter.gp` | formula(consumable ? value/2 : value) | s.206. Common 100, Uncommon 400, Rare 4000, VR 40000, Legendary 200000, Artifact priceless. Spell Scroll = 2× scribe cost. |
| **`rarity.crafting_time_days`** | integer | crafting | downtime tracker | sum | s.103. |
| **`rarity.crafting_cost_gp`** | integer | crafting | `PlayerCharacter.gp` | sub | s.103. |
| **`coin.value_in_gp`** | float | always | currency conversion | formula(amount × value_in_gp) | s.89. CP=0.01, SP=0.1, EP=0.5, GP=1, PP=10. 50 coins = 1 lb. |
| **`lifestyle.cost_per_day_gp`** | float | downtime/day | `PlayerCharacter.gp` | sub-per-day | s.101. Wretched 0, Squalid 0.1, Poor 0.2, Modest 1, Comfortable 2, Wealthy 4, Aristocratic ≥10. |
| **`condition.stacks`** | boolean | apply | `AppliedCondition` semantics | enum-tag | s.179, s.181. Yalnız Exhaustion `true`. Diğerleri stack-etmez. |
| **`condition.grants_incapacitated`** | boolean | apply | derived: incapacitated flag chain | enum-tag | s.184. Stunned/Paralyzed/Petrified/Unconscious `true` → no actions/BA/Reaction + concentration broken. |
| **`damage-type.is_physical`** | boolean | damage-roll | weapon/spell damage classification | enum-tag | Bludgeoning/Piercing/Slashing `true`. Magic weapon resistance bypass kontrolü. |
| **`duration-unit.is_concentration_compatible`** | boolean | cast | derived: spell needs concentration check | enum-tag | s.179. Rounds/Minutes/Hours `true`; Instantaneous false. |

---

## §2 Tier-1 Content Kategorileri

### 2.1 Class  *(slug: `class` — `content.dart:259`)*

SRD §1.4–1.8 (s.22–26).
`PB` = `proficiencyBonusForLevel(total_character_level)` (`dnd5e_constants.dart`).
`level_in(C)` = `PlayerCharacter.class_levels[C]`.

**Field grupları:** Identity, Progression, Spellcasting, Features.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`primary_ability_ref`** \* | relation→ability | assign | derived: multiclass_eligibility | lookup | per-class: her sınıfın primary'si ≥13 zorunlu | s.24. Multiclass gating; PC'a yazılmaz, kontrol için okunur. → §1.8 |
| **`secondary_ability_ref`** | relation→ability | n/a | — | none | n/a | UI/öneri. Mekanik etki yok. |
| **`hit_die`** \* | enum{d6,d8,d10,d12} | level-up:N | `PlayerCharacter.hit_dice_remaining[+1 of size]`; `combat_stats.max_hp` | sum + L1 max-roll | per-class: her seviye kendi HD'si | s.22, §4.13. L1 yalnızca *ilk* sınıfta `max(die)+CON`; sonraki sınıf L1'leri `avg(die)+CON`. → §1.4, §1.8 |
| **`saving_throw_refs`** \*[] | relation→ability[] | assign (only first class) | `PlayerCharacter.saving_throw_proficiencies[]` | union | first-class-only | s.25. Multiclass'ta yeni sınıfın save'leri **gelmez**. → §1.8 |
| **`skill_proficiency_choice_count`** | integer (0–4) | assign (first class) | UI: skill seçim kutusu sayısı | set | first-class-only | s.25. Yeni sınıftan skill prof gelmez (sınıfa özel multiclass tablosu hariç). |
| **`skill_proficiency_options`** [] | relation→skill[] | assign (first class) | choice pool → `PlayerCharacter.skill_proficiencies[]` | source | first-class-only | s.83 vs s.25. `choice_count` kadar seçilen union'lanır. |
| **`weapon_proficiency_categories`** [] | relation→weapon-category[] | assign | `PlayerCharacter.weapon_proficiencies[]` | union | per-class subset (multiclass tablosu) | s.25. Barb/Fight/Pala/Ranger martial alır multiclass'ta da; diğerleri kısıtlı. |
| **`weapon_proficiency_specifics`** [] | relation→weapon[] | assign | `PlayerCharacter.weapon_proficiencies[]` | union | per-class subset | s.25. Specific weapon'lar multiclass'ta tipik gelmez (sınıf-spesifik). |
| **`tool_proficiency_count`** | integer (0–3) | assign (first class) | UI: tool seçim kutusu sayısı | set | first-class-only | s.25. |
| **`tool_proficiency_options`** [] | relation→tool[] | assign (first class) | `PlayerCharacter.tool_proficiencies[]` | source | first-class-only | s.25. |
| **`armor_training_refs`** [] | relation→armor-category[] | assign | `PlayerCharacter.armor_trainings[]` | union | per-class subset (Light+Medium+Shield genelde; Heavy & Martial sınıfa özel) | s.25, §6.8. Heavy worn without training → disadv all Str/Dex tests + no spells. |
| **`starting_equipment_options`** | markdown | assign (first class) | `PlayerCharacter.inventory[]` | manual-import | first-class-only | s.25. Multiclass'ta gear gelmez. |
| **`starting_gold_dice`** | dice | assign (first class) | `PlayerCharacter.gp` | roll-and-set | first-class-only | s.83. Background ile karşılıklı (biri seçilir). |
| **`complexity`** | enum{Low,Average,High} | n/a | — | none | n/a | UI yardımcı, mekanik yok. |
| **`casting_ability_ref`** | relation→ability | assign | derived: `spell_save_dc`, `spell_attack_bonus` (when this class's spells used) | formula | per-class: her caster sınıf kendi ability'sini kullanır | s.106, §8.10. `spell_save_dc = 8 + PB + ability_mod(casting_ability_ref)`; `spell_attack_bonus = PB + ability_mod(casting_ability_ref)`. |
| **`caster_kind`** \* | enum{None,Full,Half,Third,Pact,Ritual} | level-up:N | derived: `spell_slots` (combined slot table input) | combined-table | combined-table per s.26 | s.71, §1.8. Full=full level, Half=½, Third=⅓, Pact=ayrı havuz (Mystic Arcanum hariç), Ritual=slot vermez. |
| **`spellcasting_focus_ref`** | relation→[arcane-focus, druidic-focus, holy-symbol] | n/a | UI: focus seçimi; satisfies-V/S/M flag | lookup | n/a | s.96–97. Inventory'de Focus item'ı varsa V/S/M satisfy. (Önceki `spellcasting_focus: text` typed ref'e dönüştürüldü — T6 kapandı.) |
| **`features`** | classFeatures: List&lt;{level,name,kind,dice,uses,recharge,description}&gt; | level-up:N | `PlayerCharacter.class_resources`, derived: features-active-at-level | per-row | per-class: kendi seviyesine göre | s.28+. **K1 kapandı:** typed feature listesi (Rage uses, Sneak Attack dice, Bardic Inspiration die, Extra Attack count). |
| **`cantrips_known_by_level`** | levelTable | level-up:N | `PlayerCharacter.spells_known[type=cantrip]` count cap | set (replace) | per-class: cap her sınıf için ayrı | s.32+, §8.2. |
| **`prepared_spells_by_level`** | levelTable | long-rest | `PlayerCharacter.prepared_spells[]` count cap | set (replace) | per-class: prepared count her sınıf için ayrı | s.25, §8.2. "Prepared per class individually". |
| **`spell_slots_by_level`** | levelTable | level-up:N + long-rest | `PlayerCharacter.spell_slots` | combined-table | combined-table (Full=lvl, Half=½lvl, Third=⅓lvl → s.26 satırı) | s.26, §1.8. Pact slots **ayrı** (`pact_magic_slots`). |
| **`multiclass_requirements`** | markdown | assign | derived: multiclass_eligibility | gate | required for entry into this class | s.24. Hem mevcut hem yeni sınıfın PA ≥13. |

**Açık konular:**
- `feature_table`'ın `levelTable` tipi yetersiz — typed `level→feature[]` shape gerek (§5 #1).
- `saving_throw_refs` first-class-only kuralı schema'da kodlu değil; convention (§5 #5).
- Multiclass starting prof subset tablosu (s.25) `multiclass_requirements` markdown'da; data değil (§5 #7).

**Örnek:** Rogue (`hit_die=d8`, `saving_throw_refs=[DEX,INT]`, `casting_ability_ref=null`, `armor_training_refs=[Light]`, `weapon_proficiency_categories=[Simple]` + martial-Finesse-or-Light) bir karaktere ilk sınıf olarak L3'te atanırsa:

- `hit_dice_remaining` += 3 × d8.
- `combat_stats.max_hp` = `max(8) + CON` + 2 × `(avg(8) + CON)` = `8 + CON + 2·(5 + CON)` = `18 + 3·CON`.
- `saving_throw_proficiencies` ⊇ {DEX, INT}.
- `armor_trainings` ⊇ {Light}; `weapon_proficiencies` ⊇ {Simple, Martial-Finesse-or-Light}.
- `class_resources` += Sneak Attack 2d6, Cunning Action, Steady Aim (feature_table satırlarından — şu an metin).
- `proficiency_bonus` = `proficiencyBonusForLevel(3)` = +2.
- Caster değil → `spell_save_dc` / `spell_slots` etkilenmez.

---

- §2.2 Subclass
### 2.2 Subclass  *(slug: `subclass` — `content.dart:305`)*

SRD §1.1 (Adım 5), §9 (her sınıfın subclass listesi). Subclass parent class'ın belirttiği seviyede etkin olur (Cleric L1, çoğu sınıf L3, bazı L2).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`parent_class_ref`** \* | relation→class | assign | derived: feature gate | gate | per-class: kendi parent'ının seviyesine bakar | s.28+. Subclass yalnız parent class içinde geçerlidir. |
| **`granted_at_level`** \* | integer (1–20) | level-up:N | derived: subclass effective from level=N | enum-tag | per-class | s.28+. Cleric=1, Barb/Bard/Druid/Fighter/Monk/Paladin/Ranger/Rogue/Sorc/Warlock/Wizard=3. Bazı homebrew=2. |
| **`features`** | classFeatures: List&lt;{level,name,kind,dice,uses,recharge,description}&gt; | level-up:N (level_in(parent_class) ≥ N) | `PlayerCharacter.class_resources` | per-row | per-class: parent_class seviyesine göre | s.28+. **K1 kapandı:** typed feature listesi parent class ile aynı şekilde. |
| **`flavor_description`** | markdown | n/a | — | none | n/a | UI/lore. |

---

### 2.3 Species  *(slug: `species` — `content.dart:330`)*

SRD §10.3-10.4 (s.83-86). Karakter yaratımında bir kez seçilir; tüm bonusları kalıcı.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`size_ref`** \* | relation→size | assign | `PlayerCharacter` derived: space, carry capacity multiplier | lookup | n/a | s.84. Tiny→Med (most species Med). Carrying = `STR × multiplier(size)` (§6.2). |
| **`speed_ft`** \* | integer (0–120) | assign | derived: `combat_stats.speed` (walk) | set (override base) | n/a | s.84. Most species 30; Goliath 35; Small 30 (Halfling/Gnome). Class feature/feat üst eklenir (Fast Movement, Roving). |
| **`creature_type_ref`** \* | relation→creature-type | assign | `PlayerCharacter.creature_type` (derived) | set | n/a | s.83. Çoğu Humanoid; spell/feature targeting (Hold Person sadece Humanoid). |
| **`traits`** \* | markdown | always | derived: special abilities | manual-import | n/a | s.84-86. **Açık mekanik #6:** Free-form metin; numeric trait bonusları (Lucky reroll, Brave adv) için yapısal alan yok. |
| **`granted_languages`** [] | relation→language[] | assign | `PlayerCharacter.languages[]` | union | n/a | s.20. Common her species'e default; bu liste ek diller. |
| **`granted_senses`** [] | relation→sense[] | assign | `PlayerCharacter.senses[]` | union | n/a | s.84. Darkvision 60 (most), Darkvision 120 (Dwarf, Orc), Truesight (rare). |
| **`granted_damage_resistances`** [] | relation→damage-type[] | always | `PlayerCharacter` derived: resistance check | union | n/a | s.84. Dwarf=Poison, Tiefling=Fire (Infernal), vs. → §4.4. |
| **`granted_skill_proficiencies`** [] | relation→skill[] | assign | `PlayerCharacter.skill_proficiencies[]` | union | n/a | s.84. Elf Keen Senses (Insight/Perception/Survival prof). |
| **`age`** | text | n/a | — | none | n/a | Lore only. |

**Açık konular:** `traits` markdown'dan numeric değer çıkarılamaz (Lucky reroll-on-1, Halfling Nimbleness move-thru-larger, Goliath Powerful Build). Resolver bunları client-side hard-code etmek zorunda (§5 #6).

---

### 2.4 Background  *(slug: `background` — `content.dart:360`)*

SRD §10.1 (s.83). Karakter yaratımında bir kez seçilir.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`granted_skill_refs`** \*[] | relation→skill[] | assign | `PlayerCharacter.skill_proficiencies[]` | union | n/a | s.83. Sabit 2 skill per background. |
| **`granted_tool_refs`** [] | relation→tool[] | assign | `PlayerCharacter.tool_proficiencies[]` | union | n/a | s.83. Sabit veya choice (sınıfa göre). |
| **`granted_language_count`** | integer (0–5) | assign | UI: language seçim sayısı → `PlayerCharacter.languages[]` | set | n/a | s.20, s.83. SRD 2024'te background language vermez genelde (0); custom homebrew için. |
| **`ability_score_options`** \*[] | relation→ability[] | assign | `PlayerCharacter.stat_block` | manual-distribute (+2/+1 OR +1/+1/+1, max 20) | n/a | s.21, s.83. **Açık mekanik #12:** Dağılım UI seçimi; hangi alana hangi bonus gittiği schema'da yok. |
| **`origin_feat_ref`** \* | relation→feat | assign | `PlayerCharacter.feats[]` | append | n/a | s.83. Each background bir Origin feat sağlar (Acolyte=Magic Initiate Cleric, Criminal=Alert, vs.). |
| **`starting_equipment`** \* | markdown | assign | `PlayerCharacter.inventory[]` | manual-import | n/a | s.83. Background equipment package OR `starting_gold_gp` seçimi. |
| **`starting_gold_gp`** | integer | assign | `PlayerCharacter.gp` | set (override) | n/a | s.83. Equipment package alternatifi (genelde 50 GP). Class.starting_gold_dice ile karşılıklı (sadece biri kullanılır). |

---

### 2.5 Feat  *(slug: `feat` — `content.dart:388`)*

SRD §11 (s.87-88). 4 kategori: Origin, General, Fighting Style, Epic Boon.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`category_ref`** \* | relation→feat-category | assign | derived: gating (origin = L1, general = L4+ ASI slot, fighting style = class-feature, epic boon = L19) | gate | n/a | s.87. |
| **`prerequisite`** | markdown | assign | derived: eligibility | manual-validate | n/a | s.87. Free-form metin → resolver okuyup karşılaştıramaz; UI advisory. |
| **`repeatable`** \* | boolean | n/a | UI: same feat tekrar alınabilir flag | enum-tag | n/a | s.87. Most feats once; ASI/Skilled/Magic Initiate-variant repeatable. |
| **`repeatable_limit`** | integer (1–20) | assign (each take) | UI: max take count | set | n/a | s.87. null = unlimited. |
| **`ability_score_increase`** | markdown | assign | `PlayerCharacter.stat_block` | manual-distribute | n/a | s.87. Genelde "+1 STR/DEX/CON/INT/WIS/CHA (max 20)". Numeric çıkarımı manuel. |
| **`benefits`** \* | markdown | always | derived: feat effects | manual-import | n/a | s.87. **Açık mekanik #6:** Free-form; Alert Init-bonus, Lucky reroll-on-1 gibi numeric/trigger feat'ları structurally encode edilemez. |

---

### 2.6 Spell  *(slug: `spell` — `content.dart:416`)*

SRD §8 (s.104-176). Spell entity bir tarif; karakterin `spells_known`/`prepared_spells` listesine girince cast edilebilir.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`level`** \* | integer (0–9) | cast | derived: required slot level | gate | n/a | s.104. 0 = cantrip (slot tüketmez). |
| **`school_ref`** \* | relation→spell-school | n/a | UI/lore | enum-tag | n/a | s.105. Abjuration/Conjuration/Divination/Enchantment/Evocation/Illusion/Necromancy/Transmutation. |
| **`casting_time_amount`** \* | integer (≥1, default 1) | cast | derived: action economy cost | set | n/a | s.105. |
| **`casting_time_unit_ref`** \* | relation→casting-time-unit | cast | derived: action economy cost (action/BA/reaction/min/hr) | enum-tag | n/a | s.105. Reaction casting → `reaction_trigger` zorunlu. |
| **`reaction_trigger`** | text | cast (reaction) | UI: trigger string | manual | n/a | s.105. Shield/Feather Fall/Hellish Rebuke örnekleri. |
| **`is_ritual`** \* | boolean | cast | derived: ritual cast option (no slot, +10 min) | gate | n/a | s.104. Ritual Adept (Wizard L1) prepare olmadan ritual cast eder. |
| **`range_type`** \* | enum{Self,Touch,Ranged,Sight,Unlimited} | cast | derived: targeting | enum-tag | n/a | s.106. Ranged → `range_ft` zorunlu. |
| **`range_ft`** | integer (≥0) | cast | derived: max range | set | n/a | s.106. |
| **`area_shape_ref`** | relation→area-shape | cast | derived: AoE coverage | lookup | n/a | s.106. Cone/Cube/Cylinder/Emanation/Line/Sphere. |
| **`area_size_ft`** | integer (≥0) | cast | derived: AoE size | set | n/a | s.106. Emanation = `distanceFt`, diğerleri radius/edge/length. |
| **`components`** \*[] | relation→casting-component[] | cast | derived: V/S/M satisfy check | gate | n/a | s.105. V=Verbal, S=Somatic, M=Material. |
| **`material_description`** | text | cast | UI: M component text | manual | n/a | s.105. |
| **`material_cost_gp`** | integer (≥0) | cast | `PlayerCharacter.gp` (if consumed) | sub-if-consumed | n/a | s.105. Find Familiar 10gp consumed; Identify 100gp not consumed. |
| **`material_consumed`** | boolean | cast | derived: gp drain flag | enum-tag | n/a | s.105. true → gp deducted on cast. |
| **`duration_unit_ref`** \* | relation→duration-unit | cast | derived: ends-at | enum-tag | n/a | s.106. Instantaneous/Round/Minute/Hour/Day/Until Dispelled. |
| **`duration_amount`** | integer (≥0) | cast | derived: duration count | set | n/a | s.106. |
| **`requires_concentration`** \* | boolean | cast | `PlayerCharacter.concentration` | replace (drop previous) | n/a | s.179. Tek concentration max; yeni concentration eski'yi düşürür. → §8.9 |
| **`description`** \* | markdown | n/a | UI: narrative description | manual-import | n/a | s.107+. Lore metin. Mekanik etki **`effects` field'ından** akar. |
| **`effects`** | spellEffectList: List&lt;{kind: damage\|heal\|condition\|buff\|debuff, dice, type_ref, save_ability_ref, save_effect: none\|half\|negate\|partial, condition_refs[], scaling_dice}&gt; | cast | derived: effect resolution (damage roll / save / condition apply) | per-row | n/a | s.107+. **K5/E1-E4 kapandı:** typed DSL — SpellAttack/SaveOrDamage/ConditionOnAttack primitives. |
| **`at_higher_levels_text`** | levelTextTable | cast (slot > base level) | UI: scaling narrative | manual-import | n/a | s.104. Narrative; numeric scaling `effects[].scaling_dice`'da. |
| **`class_refs`** \*[] | relation→class[] | n/a | UI: spell list belonging | source | n/a | Bu spell'in ait olduğu sınıf listeleri. PC.spells_known'a ekleme gating. |
| **`damage_type_refs`** [] | relation→damage-type[] | damage-roll | derived: damage type for resistance check | enum-tag | n/a | s.180. → §4.4 |
| **`save_ability_ref`** | relation→ability | save-roll | derived: target's save ability | enum-tag | n/a | s.106. SaveDC = caster's `spell_save_dc`. |
| **`attack_type`** | enum{None,Melee,Ranged} | attack | derived: spell attack roll variant | enum-tag | n/a | s.106. **Açık mekanik #9:** `creature-action.attack_kind` ile vokabüler farklı (4 vs 3 değer). |
| **`applied_condition_refs`** [] | relation→condition[] | cast (on hit / failed save) | target.current_conditions[] | union | n/a | s.179. Spell başlık-seviyesinde condition listesi (effects[] satırlarındaki condition_refs ile birlikte kullanılır). |

---

### 2.7 Weapon  *(slug: `weapon` — `content.dart:461`)*

SRD §6.4-6.6 (s.89-90).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`category_ref`** \* | relation→weapon-category | equip + assign | derived: prof check (`weapon_proficiency_categories` içeriyorsa PB ekle) | gate | n/a | s.89. Simple/Martial. |
| **`is_melee`** \* | boolean | attack | derived: attack ability default (STR melee, DEX ranged; Finesse override) | enum-tag | n/a | s.15. |
| **`damage_dice`** \* | dice | damage-roll | derived: damage roll | formula(`damage_dice + ability_mod`) | n/a | s.16. Min 0. |
| **`damage_type_ref`** \* | relation→damage-type | damage-roll | derived: damage type for resistance | enum-tag | n/a | s.180. |
| **`property_refs`** [] | relation→weapon-property[] | attack/equip | derived: behavior modifiers | enum-tag | n/a | s.89-90. Finesse/Heavy/Light/Loading/Range/Reach/Thrown/Two-Handed/Versatile/Ammunition. |
| **`mastery_ref`** \* | relation→weapon-mastery | attack (if PC has mastery slot for this weapon) | derived: mastery effect (Cleave/Graze/Nick/Push/Sap/Slow/Topple/Vex) | enum-tag | non-stack: yalnız aktif mastery slotundaki weapon | s.90. Class.feature_table mastery slot count belirler. |
| **`normal_range_ft`** | integer (≥0) | attack (ranged) | derived: normal range | set | n/a | s.90. Beyond → disadv. |
| **`long_range_ft`** | integer (≥0) | attack (ranged) | derived: long range cap | set | n/a | s.90. Beyond → auto miss. |
| **`versatile_damage_dice`** | dice | damage-roll (2H grip) | derived: alternate damage | replace-if-2H | n/a | s.90. Versatile property gerekli. |
| **`ammunition_type_ref`** | relation→ammunition | attack (ranged) | derived: ammo consumption | sub-1-per-attack | n/a | s.89. Loading: 1 ammo per Action/BA/Reaction. |
| **`cost_gp`** \* | float (≥0) | buy/sell | `PlayerCharacter.gp` | sub/add (sell ½) | n/a | s.89. |
| **`weight_lb`** \* | float (≥0) | always | derived: carry total | sum | n/a | s.178. |

---

### 2.8 Armor  *(slug: `armor` — `content.dart:496`)*

SRD §6.7-6.8 (s.92).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`category_ref`** \* | relation→armor-category | equip | derived: training check | gate | n/a | s.92, §6.8. Light/Medium/Heavy/Shield. Lacks training → disadv Str/Dex tests + no spell cast. |
| **`base_ac`** \* | integer (10–20) | equip | derived: `combat_stats.ac` | formula(`base_ac + (DEX_mod capped) + shield + misc`) | non-stack: tek armor instance, tek shield | s.92. Padded/Leather 11, Studded 12, vs. **Açık mekanik #8:** AC formülü kodlu değil. |
| **`adds_dex`** \* | boolean | equip | derived: AC formula DEX dahil mi | gate | n/a | s.92. Heavy=false, others=true. |
| **`dex_cap`** | integer (0–10) | equip | derived: DEX_mod cap | set | n/a | s.92. Medium=2, Heavy=0 (n/a since adds_dex=false), Light=null (uncapped). |
| **`strength_requirement`** | integer (0–30) | equip | derived: speed penalty | formula(STR < req → speed −10) | n/a | s.92. Chain 13, Splint 15, Plate 15. |
| **`stealth_disadvantage`** \* | boolean | save-roll (stealth) | derived: stealth disadv | enum-tag | n/a | s.92. Padded/Scale/Half Plate/Ring/Chain/Splint/Plate. |
| **`don_time_minutes`** \* | integer (≥0) | equip | derived: time cost | set | n/a | s.92. Light 1m, Medium 5m, Heavy 10m, Shield 1 action (Utilize). |
| **`doff_time_minutes`** \* | integer (≥0) | unequip | derived: time cost | set | n/a | s.92. |
| **`cost_gp`** \* | float (≥0) | buy/sell | `PlayerCharacter.gp` | sub/add | n/a | s.92. |
| **`weight_lb`** \* | float (≥0) | always | derived: carry total | sum | n/a | s.178. |

---

### 2.9 Tool  *(slug: `tool` — `content.dart:528`)*

SRD §6.9 (s.93).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`category_ref`** \* | relation→tool-category | n/a | UI grouping | enum-tag | n/a | s.93. Artisan's Tools / Gaming Sets / Musical Instruments / Other. |
| **`variant_of_ref`** | relation→tool | n/a | UI: variant link | source | n/a | Sub-tool grupları için (Carpenter's = Artisan's variant). |
| **`ability_ref`** \* | relation→ability | check | derived: tool check ability | enum-tag | n/a | s.93. Default ability for the tool's check. |
| **`utilize_check_dc`** | integer (0–30) | check | derived: default DC | set | n/a | s.93. |
| **`utilize_description`** | textarea | check | UI: usage hint | manual | n/a | s.93. |
| **`craftable_items`** [] | relation→adventuring-gear[] | crafting | derived: what this tool can craft | source | n/a | s.103. |
| **`cost_gp`** \* | float (≥0) | buy/sell | `PlayerCharacter.gp` | sub/add | n/a | s.93. |
| **`weight_lb`** \* | float (≥0) | always | derived: carry total | sum | n/a | s.178. |

---

### 2.10 Adventuring Gear  *(slug: `adventuring-gear` — `content.dart:557`)*

SRD §6.10 (s.94-99).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`cost_cp`** \* | integer (≥0) | buy/sell | `PlayerCharacter.{cp,sp,ep,gp,pp}` | sub/add (cp denomination) | n/a | s.94+. CP precision (Coin lookup convert). |
| **`weight_lb`** \* | float (≥0) | always | derived: carry total | sum | n/a | s.178. |
| **`utilize_description`** | markdown | check (Utilize action) | derived: effect | manual | n/a | s.10, s.94+. Healer's Kit, Holy Water, Caltrops, vs. |
| **`consumable`** \* | boolean | use | inventory remove | dec-on-use | n/a | s.94. Potion/Holy Water/Healer's Kit charge. |
| **`is_focus`** | boolean | cast | derived: V/S/M satisfy (M slot via focus) | gate | n/a | s.96-97. Class.spellcasting_focus ile eşleşmeli. |
| **`focus_kind_ref`** | relation→{arcane-focus,druidic-focus,holy-symbol} | cast | derived: focus kind check | enum-tag | n/a | s.96-97. is_focus=true ise dolu. |

---

### 2.11 Ammunition  *(slug: `ammunition` — `content.dart:584`)*

SRD §6.4 Ammunition (s.89).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`storage_container`** | text | n/a | UI: container hint (quiver/pouch/case) | manual | n/a | s.89. |
| **`cost_gp`** \* | float (≥0) | buy/sell | `PlayerCharacter.gp` | sub/add (per bundle) | n/a | s.89. |
| **`weight_lb`** \* | float (≥0) | always | derived: carry total | sum | n/a | s.178. |
| **`bundle_count`** \* | integer (1–500) | attack | inventory dec | sub-1-per-attack | n/a | s.89. Recover ½ after fight. |

---

### 2.12 Pack  *(slug: `pack` — `content.dart:608`)*

SRD §6.10 packs (s.94-99).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`cost_gp`** \* | integer (≥0) | buy | `PlayerCharacter.gp` | sub | n/a | s.94+. |
| **`weight_lb`** | float (≥0) | always | derived: carry total | sum | n/a | s.178. |
| **`contents`** | markdown | open/buy | `PlayerCharacter.inventory[]` | manual-import | n/a | s.94+. **Açık konu:** Quantity-on-relation desteklenmiyor; içerik markdown olarak listelenir (notes design §9 #2). |

---

### 2.13 Mount  *(slug: `mount` — `content.dart:633`)*

SRD §6.12 (s.100), §3.14 (s.15-16).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`carrying_capacity_lb`** \* | integer (≥0) | always | derived: cargo limit | set | n/a | s.100. |
| **`speed_ft`** \* | integer (≥0) | mounted | derived: mount speed (rider uses) | set | n/a | s.16. |
| **`cost_gp`** \* | integer (≥0) | buy/sell | `PlayerCharacter.gp` | sub/add | n/a | s.100. |
| **`is_trained`** | boolean | mounted | derived: controlled vs independent (s.16) | enum-tag | n/a | s.16. Trained → controlled (rider Initiative + mount Dash/Disengage/Dodge). |

---

### 2.14 Vehicle  *(slug: `vehicle` — `content.dart:657`)*

SRD §6.12 (s.100).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`vehicle_kind`** \* | enum{Land,Waterborne,Airborne} | n/a | UI grouping | enum-tag | n/a | s.100. |
| **`speed_mph`** | float (≥0) | travel | derived: travel speed | set | n/a | s.100. |
| **`crew`** | integer (≥0) | n/a | UI: required crew | set | n/a | s.100. |
| **`passengers`** | integer (≥0) | n/a | UI: passenger limit | set | n/a | s.100. |
| **`cargo_tons`** | float (≥0) | always | derived: cargo limit | set | n/a | s.100. |
| **`ac`** | integer (0–30) | attack vs vehicle | derived: AC | set | n/a | s.100. |
| **`hp`** | integer (≥0) | damage-roll | live HP | sub | n/a | s.100. |
| **`damage_threshold`** | integer (≥0) | damage-roll | derived: ignore damage < threshold | gate | n/a | s.180. Damage Threshold rule. |
| **`cost_gp`** | integer (≥0) | buy/sell | `PlayerCharacter.gp` | sub/add | n/a | s.100. |

---

### 2.15 Trinket  *(slug: `trinket` — `content.dart:687`)*

SRD §1.3 trinket roll (s.26-27).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`roll_d100`** \* | integer (1–100) | character creation (optional) | UI: lookup table key | lookup | n/a | s.26-27. Random table starting trinket. |
| **`description`** \* | markdown | n/a | `PlayerCharacter.trinket_ref` UI | manual | n/a | s.26-27. Lore/flavor only. |

---

### 2.16 Magic Item  *(slug: `magic-item` — `content.dart:710`)*

SRD §12 (s.204-253). Karaktere `inventory[]`'e girer; bazıları `attuned_items[]`'e (max 3).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`magic_category_ref`** \* | relation→magic-item-category | n/a | UI grouping | enum-tag | n/a | s.204. Armor/Potion/Ring/Rod/Scroll/Staff/Wand/Weapon/Wondrous. |
| **`rarity_ref`** \* | relation→rarity | buy/sell | `PlayerCharacter.gp`; UI: filter | lookup | n/a | s.205-206. Rarity.value_gp formülü (§1.2). |
| **`requires_attunement`** \* | boolean | attune | `PlayerCharacter.attuned_items[]` | gate (max 3) | n/a | s.102. Untuned magic item still functional but limited. |
| **`attunement_prereq`** | markdown | attune | derived: eligibility | manual-validate | n/a | s.102. Class/race/alignment-restricted attunement (Holy Avenger = Paladin). |
| **`is_cursed`** \* | boolean | attune/use | derived: cursed flag | enum-tag | n/a | s.206. Identification gizler curse'u. |
| **`base_item_ref`** | relation→{weapon,armor,adventuring-gear} | equip | derived: base stats inheritance | source | n/a | s.207. Longsword +1 → base weapon Longsword stats + bonus. |
| **`charges_max`** | integer (≥0) | use | derived: charge pool cap | set | n/a | s.206. |
| **`charge_regain`** | text | long-rest/dawn | charges += parsed expr | manual | n/a | s.206. **Açık mekanik #10:** "1d6+4 at dawn" parser yok. |
| **`activation`** \* | enum{None,Magic Action,Bonus Action,Reaction,Utilize,Command Word,Consumable} | use | derived: action economy cost | enum-tag | n/a | s.206. |
| **`command_word`** | text | use | UI: command string | manual | n/a | s.206. activation=Command Word. |
| **`effects`** \* | markdown | always (when equipped/attuned) | derived: stat modifications | manual-import | n/a | s.207+. **Açık mekanik #6:** Free-form; Cloak of Protection +1 AC/save gibi bonuses structurally encode edilemez. |
| **`cost_gp`** | integer (≥0) | buy/sell | `PlayerCharacter.gp` | sub/add | n/a | s.205-206. Rarity.value_gp ile tutarlı. |
| **`weight_lb`** | float (≥0) | always | derived: carry total | sum | n/a | s.178. |
| **`is_sentient`** \* | boolean | attune | derived: sentient interactions | enum-tag | n/a | s.207. |
| **`sentient_int`** | integer (3–30) | always (sentient) | item.stat | set | n/a | s.207. |
| **`sentient_wis`** | integer (3–30) | always (sentient) | item.stat | set | n/a | s.207. |
| **`sentient_cha`** | integer (3–30) | always (sentient) | item.stat | set | n/a | s.207. |
| **`sentient_alignment_ref`** | relation→alignment | always (sentient) | item.alignment (conflict check vs PC) | enum-tag | n/a | s.207. |
| **`sentient_communication`** | text | always (sentient) | UI | manual | n/a | s.207. |
| **`sentient_senses`** | text | always (sentient) | UI | manual | n/a | s.207. |
| **`sentient_special_purpose`** | text | always (sentient) | UI / DM trigger | manual | n/a | s.207. |

---

### 2.17 Trait  *(slug: `trait` — `content.dart:838`)*

Yardımcı kategori — NPC/Monster trait list'leri için. Free-form metin taşır; kendi mekaniği yok (entry'ye eklendiğinde manuel etki).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`source`** | text | n/a | UI: kategori (race/class/monster/feat name) | manual | n/a | Lore/grouping. |
| **`trait_kind`** | enum{Passive,Sense,Defensive,Movement,Spellcasting,Other} | n/a | UI grouping | enum-tag | n/a | Filter helper. |
| **`description`** | markdown | always (when assigned) | derived: special ability | manual-import | n/a | **Açık mekanik #6.** |

---

### 2.18 Creature Action  *(slug: `creature-action` — `content.dart:870`)*

NPC/Monster action entry'leri. Bir attack veya non-attack action olarak çalışır.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`source`** | text | n/a | UI: origin (monster/NPC/class name) | manual | n/a | Grouping. |
| **`action_type`** \* | enum{Action,Bonus Action,Reaction,Legendary Action,Lair Action,Mythic Action,Free} | use | derived: action economy slot | enum-tag | n/a | s.9-10. |
| **`recharge`** | text | turn-start | derived: recharge dice (5-6/SR/Day) | parse-and-roll | n/a | Free-form parser gerek (e.g. "5-6" → roll d6 each turn-start). |
| **`uses_per_day`** | integer (≥0) | use | derived: daily charge | sub-on-use | n/a | s.255. |
| **`is_attack`** | boolean | attack | derived: attack roll branch | gate | n/a | true → attack_kind/attack_bonus/reach/range zorunlu. |
| **`attack_kind`** | enum{Melee Weapon,Ranged Weapon,Melee Spell,Ranged Spell} | attack | derived: attack flow | enum-tag | n/a | **Açık mekanik #9:** spell.attack_type ile vokabüler farklı (3 vs 4 değer). |
| **`attack_bonus`** | integer | attack | derived: attack roll = `d20 + attack_bonus` | formula | n/a | s.255. Stat block'ta önceden hesaplanmış. |
| **`reach_ft`** | integer (≥0) | attack (melee) | derived: melee reach | set | n/a | s.15. Default 5. |
| **`range_normal_ft`** | integer (≥0) | attack (ranged) | derived: normal range | set | n/a | s.15. |
| **`range_long_ft`** | integer (≥0) | attack (ranged) | derived: long range | set | n/a | s.15. |
| **`damage_dice`** | dice | damage-roll | derived: damage | formula | n/a | s.16. |
| **`damage_type_ref`** | relation→damage-type | damage-roll | derived: damage type | enum-tag | n/a | s.180. |
| **`save_dc`** | integer (1–30) | save-roll | derived: target save DC | set | n/a | **T2 kapandı:** typed integer (önceden text). |
| **`save_ability_ref`** | relation→ability | save-roll | derived: target save ability | enum-tag | n/a | **T2 kapandı:** save ability ayrı relation field. |
| **`description`** \* | markdown | use | derived: effect text | manual-import | n/a | s.255. Free-form effects. |

---

### 2.19 Monster  *(slug: `monster` — `content.dart:760`)*

SRD §17, §13.1-13.5 (s.254-343). Bestiary entry; instance Encounter aracılığıyla combat'a girer.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`size_ref`** \* | relation→size | spawn | `Monster.space` | lookup | n/a | s.14, s.254. |
| **`creature_type_ref`** \* | relation→creature-type | spawn | derived: targeting (Hold Person etc.) | enum-tag | n/a | s.179, s.254. |
| **`tags_line`** | text | n/a | UI: parenthetical tags | manual | n/a | s.254. e.g. "(goblinoid)". |
| **`alignment_ref`** | relation→alignment | n/a | UI/lore | enum-tag | n/a | s.21, s.254. |
| **`ac`** \* | integer (0–30) | attack vs | derived: hit/miss | set | n/a | s.255. Stat block AC final değer. |
| **`ac_note`** | text | n/a | UI: AC source (natural/plate/etc.) | manual | n/a | s.255. |
| **`initiative_modifier`** \* | integer | turn-start | derived: init roll = `d20 + mod` | set | n/a | s.255. |
| **`initiative_score`** \* | integer | turn-start | derived: passive init alternative (10 + mod) | set | n/a | s.13. |
| **`hp_average`** \* | integer (≥0) | spawn | `MonsterInstance.max_hp` | set | n/a | s.255. Default; rolled HP overrides. |
| **`hp_dice`** \* | dice | spawn (rolled mode) | `MonsterInstance.max_hp` | roll-and-set | n/a | s.255. e.g. "5d8+10". |
| **`speed_walk_ft`** \* | integer (≥0) | always | derived: walk speed | set | n/a | s.14, s.255. |
| **`speed_burrow_ft`** | integer (≥0) | always | derived: burrow speed | set | n/a | s.255. |
| **`speed_climb_ft`** | integer (≥0) | always | derived: climb speed | set | n/a | s.255. |
| **`speed_fly_ft`** | integer (≥0) | always | derived: fly speed | set | n/a | s.255. |
| **`speed_swim_ft`** | integer (≥0) | always | derived: swim speed | set | n/a | s.255. |
| **`can_hover`** | boolean | always | derived: fly hover flag | enum-tag | n/a | s.255. |
| **`stat_block`** | statBlock{STR..CHA} | always | derived: ability mods | set | n/a | s.255. |
| **`save_bonuses`** | proficiencyTable | save-roll | derived: save bonus override | source | n/a | s.255. Stat block'ta yazılan değer = `ability_mod + (PB if prof) + misc`. |
| **`skill_bonuses`** | proficiencyTable | check | derived: skill bonus override | source | n/a | s.255. |
| **`resistance_refs`** [] | relation→damage-type[] | damage-roll | derived: ½ damage | union | n/a | s.17, §4.4. |
| **`vulnerability_refs`** [] | relation→damage-type[] | damage-roll | derived: ×2 damage | union | n/a | s.17, §4.4. |
| **`damage_immunity_refs`** [] | relation→damage-type[] | damage-roll | derived: 0 damage | union | n/a | s.17, §4.4. |
| **`condition_immunity_refs`** [] | relation→condition[] | apply-condition | derived: condition blocked | union | n/a | s.17, s.179. |
| **`senses`** | rangedSenseList: List&lt;{sense_ref, range_ft}&gt; | always | derived: senses with explicit range | union | n/a | s.255. **T7 kapandı:** typed sense+range list (Darkvision 60ft, Truesight 120ft). NPC parite. |
| **`passive_perception`** \* | integer (0–30) | always | derived: passive Wis(Perception) | set | n/a | s.22. |
| **`language_refs`** [] | relation→language[] | always | derived: comprehension | union | n/a | s.20. |
| **`telepathy_ft`** | integer (≥0) | always | derived: telepathy range | set | n/a | s.255. |
| **`cr`** \* | enum{0..30, fractions} | always | derived: XP, encounter difficulty | enum-tag | n/a | s.255. |
| **`xp`** \* | integer (≥0) | death | encounter XP award | sum | n/a | s.255. CR'ye eşlenik. |
| **`proficiency_bonus`** \* | integer (2–9) | check/save | derived: PB | set | n/a | s.8. Monster PB CR'den derive (mechanics §17.2). |
| **`trait_refs`** [] | relation→trait[] | always | derived: passive abilities | union | n/a | s.255. **T8 kapandı:** typed trait listesi. NPC parite. |
| **`action_refs`** \*[] | relation→creature-action[] | use | action economy | union | n/a | s.255. **T8 kapandı:** typed action listesi. |
| **`bonus_action_refs`** [] | relation→creature-action[] | use | BA economy | union | n/a | s.255. |
| **`reaction_refs`** [] | relation→creature-action[] | use | reaction economy | union | n/a | s.255. |
| **`legendary_action_uses`** | integer (0–5) | turn-start | LA pool reset | set | n/a | s.255. |
| **`legendary_action_refs`** [] | relation→creature-action[] | use (LA) | LA economy | union | n/a | s.255. |
| **`lair_action_refs`** [] | relation→creature-action[] | initiative 20 (in lair) | lair action trigger | union | n/a | s.255. |
| **`spell_refs`** [] | relation→spell[] | cast | derived: spell list + slots | union | n/a | s.255. **T4 kapandı:** typed spell list (NPC parite). |
| **`gear_refs`** [] | relation→{adventuring-gear,weapon,armor}[] | spawn | inventory | source | n/a | s.255. Loot table. |

---

### 2.20 Animal  *(slug: `animal` — `content.dart:919`)*

**Delta:** Field shape Monster ile bire bir aynıdır (`_animalCategory()` Monster'ın field listesini `copyWith` ile rebuild eder). Tek fark: `slug='animal'`, `name='Animal'`, `color='#4caf50'`, `icon='cruelty_free'`. Beast filter (s.344+) için ayrı slug.

Tüm field semantikleri §2.19 ile özdeş. Mekanik açıdan referans olarak §2.19 kullanılır.

---

---

## §3 Tier-2 DM / Play Kategorileri

Yer tutucu.

### 3.1 Player Character  *(slug: `player-character` — `dm.dart:277`)*

SRD §1 (s.19-26). Tüm türev (derived) alanlar her okuma/her uzun dinlenmede yeniden hesaplanır.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`species_ref`** \* | relation→species | assign | derived: size, speed, granted_*, creature_type | source-of-truth | n/a | s.84. Bir kez seçilir; tüm species field'larının kaynağı. → §2.3 |
| **`class_refs`** \*[] | relation→class[] | assign | derived: caster total, multiclass_table_input | source-of-truth | container | Tüm class-derived alanların kaynağı. Her class iteration buradan. → §2.1 |
| **`class_levels`** | levelTable (Map<class_id,int>) | level-up | derived: total_level, PB | sum across map | container | Total level = Σ values; PB = `proficiencyBonusForLevel(total_level)`. **Açık mekanik #13:** levelTable map<int,int>; key=class_id (level değil); convention. |
| **`subclass_refs`** [] | relation→subclass[] | level-up:granted_at_level | derived: subclass features | union | per-class | s.28+. Parent class level eşleşmeli. |
| **`background_ref`** \* | relation→background | assign | derived: skill+tool grants, origin feat, gold | source-of-truth | n/a | s.83. → §2.4 |
| **`alignment_ref`** | relation→alignment | n/a | UI/lore | enum-tag | n/a | s.21. |
| **`xp`** \* | integer (≥0, default 0) | xp-gain | derived: level | formula(`xpToLevel(xp)` per s.23) | n/a | s.23. L1=0, L2=300, …, L20=355k. |
| **`proficiency_bonus`** \* | integer (2–6, default 2) | derived (or manual override) | every roll-with-prof | formula(`proficiencyBonusForLevel(total_level)`) | derived | s.8. **Açık mekanik #2:** schema manuel; derived olmalı. |
| **`feats`** [] | relation→feat[] | level-up:ASI | derived: feat effects | union | per-class: ASI L4/8/12/16 (most classes) | s.23, s.87. Origin feat (background) bu listeye girer. → §2.5 |
| **`languages`** \*[] | relation→language[] | assign + level-up | derived: language comprehension | union | n/a | s.20. Common + species + background + class. |
| **`tool_proficiencies`** [] | relation→tool[] | assign | check bonus | union → `roll_bonus = ability_mod + (PB if in list)` | first-class-only (class), per-source (background/species/feat) | s.9, s.93. |
| **`weapon_proficiencies`** [] | relation→{weapon-category,weapon}[] | assign | attack roll | union → `attack_bonus = ability_mod + (PB if in list)` | per-class subset | s.6, s.89. → §2.7 |
| **`armor_trainings`** [] | relation→armor-category[] | assign | derived: armor eligibility | union | per-class subset | s.92, §6.8. Lacks → disadv Str/Dex tests + no spell cast. |
| **`skill_proficiencies`** [] | relation→skill[] | assign | check bonus | union → `roll_bonus = ability_mod + (PB if in list) + (PB extra if in expertise) + misc` | per-class (class choice), background, species | s.9. |
| **`expertise_skills`** [] | relation→skill[] | assign (level-up:Expertise feature) | check bonus | union → `+PB extra` | per-class | s.182, e.g. Rogue L1, Bard L2. |
| **`saving_throw_proficiencies`** \*[] | relation→ability[] | assign (first class only) | save roll bonus | union → `roll_bonus = ability_mod + (PB if in list) + saves.misc` | first-class-only | s.9, s.25. Class.saving_throw_refs'ten beslenir. → §1.8 |
| **`stat_block`** | statBlock{STR..CHA} | assign + ASI/feat | derived: ability_mod, save_dc, attack_bonus, AC, init, save bonuses, skill bonuses, carrying capacity | set | n/a | s.6. `ability_mod = floor((score-10)/2)`. Cap 20 normal (30 max). → §2.2 |
| **`combat_stats`** | combatStats{hp,max_hp,ac,speed,level,initiative,cr,xp} | level-up + damage + heal + equip | live combat state | per-sub-field | per-class HD | s.16+. Sub-fields aşağıda detay. |
| ↳ `combat_stats.hp` | int | damage/heal | live HP (0..max) | sub/add (clamped) | n/a | s.16. 0 → Unconscious + Death Saves. → §4.8 |
| ↳ `combat_stats.max_hp` | int | level-up | derived | formula(L1: `max(class[0].hit_die)+CON`; Lk>1: `(avg(hit_die_at_class)+CON)` per level + `Tough` feat, vs.) | per-class HD | s.22. → §1.4, §4.13 |
| ↳ `combat_stats.ac` | int | equip/unequip + ASI | derived | formula(`armor.base_ac + (DEX_mod capped) + shield + misc`) | non-stack: tek Unarmored Defense | s.92, §6.7. **Açık mekanik #8.** |
| ↳ `combat_stats.speed` | text | always | derived | formula(`species.speed_ft + class bonuses (Fast Movement, Roving)` − Heavy armor STR penalty) | take-highest | s.84, s.92. |
| ↳ `combat_stats.initiative` | dice | turn-start | init roll | formula(`d20 + DEX_mod + PB-if-Alert/Feral`) | take-highest | s.13. |
| ↳ `combat_stats.level` | int | level-up | derived | formula(Σ class_levels.values) | sum | s.23. |
| **`temp_hp`** \* | integer (≥0, default 0) | spell/feature gain + damage | buffer; lost first | replace (no-stack) | n/a | s.18. LR ends. → §4.11 |
| **`death_saves_successes`** \* | integer (0–3, default 0) | save-roll (at 0 HP) | death save tracker | inc | n/a | s.17. 3 → Stable; nat 20 → 1 HP. → §4.8 |
| **`death_saves_failures`** \* | integer (0–3, default 0) | save-roll (at 0 HP) | death save tracker | inc | n/a | s.17. 3 → die; nat 1 → +2 fails. |
| **`heroic_inspiration`** \* | boolean (default false) | grant/use | reroll trigger | enum-tag | n/a | s.8. Spend → reroll a d20 (max 1 active). |
| **`hit_dice_remaining`** | proficiencyTable | spend (SR) + level-up + LR | HD pool | sub-on-spend, +½ on LR, +1 on level-up | per-class HD | s.187. SR spend `d_size + CON` heal min 1. |
| **`saving_throws`** | proficiencyTable (kDnd5eSavingThrows preset) | save-roll | save bonus rendering | formula(`ability_mod + (PB if proficient) + (PB×2 if expertise) + misc`) | per-class | s.9. UI rendering layer; `saving_throw_proficiencies` source-of-truth. |
| **`skills`** | proficiencyTable (kDnd5eSkills preset) | check | skill bonus rendering | formula(same as saves; default ability per skill) | n/a | s.9. UI rendering. |
| **`senses`** [] | relation→sense[] | always | derived: special sight | union | n/a | s.11. Species + class + magic item kaynaklı. |
| **`passive_perception`** | integer (0–30, default 10) | always | derived | formula(`10 + Wis(Perception) check mod`; +5 adv, −5 disadv) | derived | s.22. **Açık konu:** Manuel cache; derived olmalı. |
| **`passive_insight`** | integer (0–30, default 10) | always | derived | formula(`10 + Wis(Insight) check mod`) | derived | s.22. |
| **`passive_investigation`** | integer (0–30, default 10) | always | derived | formula(`10 + Int(Investigation) check mod`) | derived | s.22. |
| **`inventory`** [] | relation→{weapon,armor,adventuring-gear,magic-item}[] | acquire | item list | union | n/a | s.94+. |
| **`attuned_items`** [] | relation→magic-item[] | attune (max 3) | derived: attuned bonuses | gate (max 3) | n/a | s.102. → §7.8 |
| **`cp / sp / ep / gp / pp`** \* | integer (≥0, default 0) | buy/sell/gain | currency | sub/add | n/a | s.89. Coin.value_in_gp ile convert. → §6.1 |
| **`current_conditions`** [] | relation→applied-condition[] | apply | active conditions | union | n/a | s.179. Stack rule: yalnız Exhaustion. → §5 |
| **`casting_ability_ref`** | relation→ability | assign | derived: spell DC + atk | source | per-class (her caster sınıf kendi'si) | s.106. **Açık mekanik #3.** |
| **`spell_save_dc`** | integer (0–30) | derived | enemy save DC | formula(`8 + PB + ability_mod(casting_ability_ref)`) | per-class | s.106. **Açık mekanik #3.** |
| **`spell_attack_bonus`** | integer | derived | spell attack roll | formula(`PB + ability_mod(casting_ability_ref)`) | per-class | s.106. |
| **`spells_known`** [] | relation→spell[] | level-up + replace | spell pool | union | per-class | s.104. Class.cantrips_known_by_level + spellbook (Wizard) source-of-truth. |
| **`prepared_spells`** [] | relation→spell[] | long-rest | castable list | replace (cap by Class.prepared_spells_by_level) | per-class | s.104. → §8.2 |
| **`spell_slots`** | slot | long-rest + cast | castable resource | formula(combined-multiclass-table[caster_total_level] per s.26) | combined-table | s.26, §8.1. → §1.8 |
| **`pact_magic_slots`** | slot | short-rest + cast | warlock slot pool (separate) | formula(per Warlock level) | n/a (Warlock-only) | s.71. Pact ≠ regular spell_slots. |
| **`class_resources`** | proficiencyTable | level-up + use | class resource counters (Rage, Sneak Attack, Bardic Insp, Action Surge, …) | per-row | per-class | s.28+. **Açık mekanik #1.** |
| **`trinket_ref`** | relation→trinket | character creation | UI: trinket ref | source | n/a | s.26. |
| **`personality_traits / ideals / bonds / flaws`** | markdown | n/a | UI/roleplay | manual | n/a | s.19. |
| **`age / height / weight / eyes / skin / hair`** | text | n/a | UI/roleplay | manual | n/a | s.19. |
| **`appearance / backstory / allies_organizations`** | markdown | n/a | UI/roleplay | manual | n/a | s.19. |

**Açık konular:** §5 #2 (proficiency_bonus derived), #3 (multi-DC), #8 (AC formula), #13 (class_levels typing).

---

### 3.2 NPC  *(slug: `npc` — `dm.dart:211`)*

SRD §17 (s.254+). PC ile büyük ölçüde paralel ama `subclass_refs`, `feats`, `xp`, `class_levels`, `cp/sp/ep/gp/pp` yok. NPC stat block monsters'a yakın; sadece social interaction field'ları (goals/mannerisms/secrets) farklı.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`species_ref`** | relation→species | assign | derived: size, speed, traits | source | n/a | s.83. → §2.3 |
| **`class_refs`** [] | relation→class[] | assign | derived: class features | source | container | s.28+. → §2.1 |
| **`level`** | integer (1–20) | level-up | derived: PB | formula(`proficiencyBonusForLevel(level)`) | n/a (single int, multiclass split desteklenmiyor) | s.23. |
| **`background_ref`** | relation→background | assign | derived: skills, feats | source | n/a | s.83. |
| **`alignment_ref`** | relation→alignment | n/a | UI | enum-tag | n/a | s.21. |
| **`attitude_ref`** \* | relation→attitude | n/a | UI/social roll DC | enum-tag | n/a | s.10. Friendly/Indifferent/Hostile. |
| **`location_ref`** | relation→location | n/a | UI/world-map | source | n/a | Lore. |
| **`faction`** | text | n/a | UI/lore | manual | n/a | Free-form. |
| **`stat_block`** | statBlock | always | derived: ability mods | set | n/a | s.6. |
| **`combat_stats`** | combatStats | combat | live combat | per-sub-field | n/a | (PC ile aynı sub-fields). |
| **`proficiency_bonus`** | integer (2–9, default 2) | always | derived: PB | set (or formula) | n/a | s.8. |
| **`initiative_modifier`** | integer (default 0) | turn-start | init roll | formula(`d20 + mod`) | n/a | s.13. |
| **`saving_throws`** | proficiencyTable | save-roll | bonus rendering | formula(same as PC) | n/a | s.9. |
| **`skills`** | proficiencyTable | check | bonus rendering | formula | n/a | s.9. |
| **`resistance_refs`** [] | relation→damage-type[] | damage-roll | derived: ½ dmg | union | n/a | s.17. |
| **`vulnerability_refs`** [] | relation→damage-type[] | damage-roll | derived: ×2 dmg | union | n/a | s.17. |
| **`damage_immunity_refs`** [] | relation→damage-type[] | damage-roll | derived: 0 dmg | union | n/a | s.17. |
| **`condition_immunity_refs`** [] | relation→condition[] | apply-condition | derived: blocked | union | n/a | s.17. |
| **`senses`** [] | relation→sense[] | always | derived | union | n/a | s.11. |
| **`passive_perception`** | integer (0–30, default 10) | always | derived | set | n/a | s.22. |
| **`language_refs`** [] | relation→language[] | always | derived | union | n/a | s.20. |
| **`telepathy_ft`** | integer (≥0) | always | derived | set | n/a | s.255. |
| **`trait_refs`** [] | relation→trait[] | always | derived: passive abilities | union | n/a | → §2.17 |
| **`action_refs`** [] | relation→creature-action[] | use | action economy | source | n/a | → §2.18 |
| **`special_action_refs`** [] | relation→creature-action[] | use | LA/Lair/Mythic economy | source | n/a | → §2.18 |
| **`equipment_refs`** [] | relation→{weapon,armor,tool,...,magic-item}[] | spawn | inventory | source | n/a | s.255. |
| **`spell_refs`** [] | relation→spell[] | cast | spellbook | source | n/a | s.255. |
| **`goals`** | markdown | n/a | UI/roleplay | manual | n/a | DM lore. |
| **`appearance`** | markdown | n/a | UI/roleplay | manual | n/a | DM lore. |
| **`mannerisms`** | markdown | n/a | UI/roleplay | manual | n/a | DM lore. |
| **`secrets`** *(dmOnly)* | markdown | n/a | UI/DM-only | manual | n/a | Online modda gizli. |

**Delta from PC:** subclass/feats/xp/class_levels/currency/spell_slots/trinket/personality/physical/narrative slot'ları yok; bunun yerine attitude/location/faction/goals/mannerisms/secrets var.

---

### 3.3 Applied Condition  *(slug: `applied-condition` — `dm.dart:377`)*

SRD §5 (s.179). Bir Condition lookup'ının bir karaktere/NPC/monster'a uygulanmış instance'ı.

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`condition_ref`** \* | relation→condition | apply | target.current_conditions[] | union (Exhaustion stack) | n/a | s.179. Stack rule lookup'tan (`condition.stacks`). |
| **`source_entity_ref`** | relation→{npc,player-character,monster,animal} | apply | UI: causality | source | n/a | DM tracking. |
| **`duration_rounds`** | integer (≥0) | turn-end | derived: expiry tick | dec-per-round; null = indefinite | n/a | **Açık mekanik #11:** "1 minute / until next dawn" cinsinden duration round'a sığmaz. |
| **`save_dc`** | integer (1–30) | save-roll | save attempt DC | set | n/a | s.179. End-of-turn or trigger save. |
| **`save_ability_ref`** | relation→ability | save-roll | save attempt ability | enum-tag | n/a | s.179. |
| **`save_frequency`** | enum{none,start-of-turn,end-of-turn,when-damaged} | save-roll | derived: when save fires | enum-tag | n/a | s.179. e.g. Frightened end-of-turn. |
| **`notes`** | textarea | n/a | UI | manual | n/a | DM tracking. |

---

### 3.4 Location  *(slug: `location` — `dm.dart:406`)*

SRD §13.4 (s.192+).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`danger_level`** | enum{Safe,Low,Medium,High,Deadly} | n/a | UI/encounter pacing | enum-tag | n/a | DM helper. |
| **`environment`** | text | n/a | UI/lore | manual | n/a | e.g. "Forest", "Dungeon". |
| **`parent_location_ref`** | relation→location | n/a | UI/hierarchy | source | n/a | Nested locations. |
| **`plane_ref`** | relation→plane | n/a | UI/lore | enum-tag | n/a | Material/Astral/Ethereal/etc. |
| **`illumination_ref`** | relation→illumination | always (in scene) | derived: vision modifier | enum-tag | n/a | s.11. Bright/Dim/Darkness — sight check modifier source. |
| **`hazard_refs`** [] | relation→hazard[] | enter/dwell | derived: hazard exposure | union | n/a | s.12. Burning/Falling/Suffocation/etc. |
| **`description_long`** | markdown | n/a | UI | manual | n/a | Player-visible. |
| **`secrets`** *(dmOnly)* | markdown | n/a | UI/DM-only | manual | n/a | Hidden. |

---

### 3.5 Scene  *(slug: `scene` — `dm.dart:435`)*

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`location_ref`** | relation→location | n/a | UI | source | n/a | Lore. |
| **`status`** | enum{Planned,Active,Completed,Skipped} | scene-progress | UI | enum-tag | n/a | DM tracking. |
| **`illumination_ref`** | relation→illumination | always (in scene) | derived: vision modifier | enum-tag | n/a | s.11. |
| **`travel_pace_ref`** | relation→travel-pace | travel | derived: speed × pace multiplier | enum-tag | n/a | s.192. Fast/Normal/Slow. |
| **`beats`** | markdown | n/a | UI/outline | manual | n/a | Plan beats. |
| **`npc_refs`** [] | relation→npc[] | n/a | UI | source | n/a | NPCs in scene. |
| **`quest_refs`** [] | relation→quest[] | n/a | UI | source | n/a | Tied quests. |

---

### 3.6 Quest  *(slug: `quest` — `dm.dart:463`)*

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`status`** | enum{Not Started,Active,Completed,Failed} | quest-progress | UI | enum-tag | n/a | DM tracking. |
| **`giver_ref`** | relation→npc | n/a | UI | source | n/a | Quest-giver NPC. |
| **`reward`** | markdown | quest-complete | XP / gold / loot grant | manual-import | n/a | Free-form. |
| **`objective`** | markdown | n/a | UI | manual | n/a | Player-visible. |
| **`secrets`** *(dmOnly)* | markdown | n/a | UI/DM-only | manual | n/a | Hidden twist. |

---

### 3.7 Encounter  *(slug: `encounter` — `dm.dart:491`)*

SRD §13.5 (s.202).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`location_ref`** | relation→location | n/a | UI | source | n/a | |
| **`difficulty`** | enum{Trivial,Low,Moderate,High,Deadly} | n/a | UI/encounter calc | enum-tag | n/a | s.202. XP budget calculus. |
| **`monsters_refs`** [] | relation→{monster,animal}[] | spawn | combat tracker | source | n/a | s.255. → §2.19 |
| **`npcs_refs`** [] | relation→npc[] | spawn | combat tracker | source | n/a | → §3.2 |
| **`environmental_effect_refs`** [] | relation→environmental-effect[] | start-of-encounter | global save trigger | source | n/a | → §3.11 |
| **`trap_refs`** [] | relation→trap[] | trigger | save / damage | source | n/a | → §3.8 |
| **`setup`** | markdown | n/a | UI/DM | manual | n/a | Setup notes. |
| **`tactics`** *(dmOnly)* | markdown | n/a | UI/DM-only | manual | n/a | Hidden. |
| **`xp_budget`** | integer (≥0) | calc | derived: difficulty validate | sum | n/a | s.202. Σ monster.xp. |

---

### 3.8 Trap  *(slug: `trap` — `dm.dart:523`)*

SRD §13.4 traps (s.199).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`trigger`** | markdown | n/a | UI: tetiklenme şartı | manual | n/a | s.199. |
| **`save_dc`** | integer (1–30) | save-roll | target.save attempt DC | set | n/a | s.199. |
| **`save_ability_ref`** | relation→ability | save-roll | save attempt ability | enum-tag | n/a | s.199. |
| **`damage_dice`** | dice | damage-roll | damage | formula | n/a | **T1 kapandı:** typed dice (önceden text). |
| **`damage_type_ref`** | relation→damage-type | damage-roll | damage type | enum-tag | n/a | s.180. |
| **`detection_dc`** | integer (1–30) | check (Perception) | derived: detect threshold | set | n/a | s.199. |
| **`disable_dc`** | integer (1–30) | check (Thieves' Tools/Investigation) | derived: disable threshold | set | n/a | s.199. |
| **`countermeasures`** | markdown | n/a | UI | manual | n/a | DM helper. |

---

### 3.9 Poison  *(slug: `poison` — `dm.dart:553`)*

SRD §13.3 (s.197).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`poison_kind`** \* | enum{Contact,Ingested,Inhaled,Injury} | apply | derived: delivery flow | enum-tag | n/a | s.197. |
| **`save_dc`** | integer (1–30) | save-roll | target save DC | set | n/a | s.197. |
| **`save_ability_ref`** | relation→ability | save-roll | save ability | enum-tag | n/a | s.197. Genelde CON. |
| **`effect`** | markdown | apply | derived: damage/condition | manual-import | n/a | s.197. Free-form. |
| **`cost_gp`** | integer (≥0) | buy/sell | `PlayerCharacter.gp` | sub/add | n/a | s.197. |

---

### 3.10 Curse  *(slug: `curse` — `dm.dart:580`)*

SRD §13.2 (s.193).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`trigger`** | markdown | n/a | UI: tetiklenme | manual | n/a | s.193. |
| **`effect`** | markdown | apply | derived: stat modifications | manual-import | n/a | s.193. |
| **`removed_by`** | markdown | n/a | UI: cure | manual | n/a | s.193. Remove Curse spell vs DM-defined ritual. |

---

### 3.11 Environmental Effect  *(slug: `environmental-effect` — `dm.dart:604`)*

SRD §13.4 (s.195).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`effect`** | markdown | start-of-encounter / per-round | derived: damage/condition | manual-import | n/a | s.195. |
| **`save_dc`** | integer (1–30) | save-roll | target save DC | set | n/a | s.195. |
| **`save_ability_ref`** | relation→ability | save-roll | save ability | enum-tag | n/a | s.195. |

---

### 3.12 Hireling  *(slug: `hireling` — `dm.dart:628`)*

SRD §6.14 (s.102).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`skill_ref`** | relation→skill | n/a | UI: hireling specialty | enum-tag | n/a | s.102. |
| **`daily_cost_cp`** \* | integer (≥0) | hire/day | `PlayerCharacter.{cp..pp}` | sub-per-day | n/a | s.102. |
| **`skilled`** \* | boolean | n/a | UI: skilled flag (≥2 sp/day) | enum-tag | n/a | s.102. |

---

### 3.13 Service  *(slug: `service` — `dm.dart:651`)*

SRD §6.15-6.16 (s.102).

| Alan | Tip / Liste | Tetik | Hedef Stat | Operasyon | Multiclass | SRD / Notlar |
|---|---|---|---|---|---|---|
| **`kind`** \* | enum{Spellcasting,Transport,Shelter,Other} | n/a | UI grouping | enum-tag | n/a | s.102. |
| **`cost_cp`** \* | integer (≥0) | use | `PlayerCharacter.{cp..pp}` | sub | n/a | s.102. Spellcasting service cost varies by spell level. |
| **`availability`** | text | n/a | UI hint | manual | n/a | s.102. e.g. "Cities only". |

---

## §4 Tetik Zinciri Diyagramları

Bir field'ın değer değişimi diğer field'ları cascade tetikler. Aşağıdaki 3 zincir uçtan uca kapsayan kanonik akışlardır. Her ok bir tablo satırına karşılık gelir; eksik ok = §2/§3'te eksik satır.

### 4.1 Karakter Yaratma Zinciri

```
[Adım 1] Class seç
  class_refs ─assign→ class_levels[<class>] = 1
                  ├─source-of-truth→ Class.hit_die ─level-up:1→ hit_dice_remaining (1×d_size)
                  │                                ─level-up:1→ combat_stats.max_hp = max(d_size) + CON
                  ├─source-of-truth→ Class.saving_throw_refs ─assign(first)→ saving_throw_proficiencies (union)
                  ├─source-of-truth→ Class.skill_proficiency_options + choice_count
                  │                                ─assign(first)→ UI choice → skill_proficiencies (union)
                  ├─source-of-truth→ Class.weapon_proficiency_categories/specifics ─assign→ weapon_proficiencies (union)
                  ├─source-of-truth→ Class.armor_training_refs ─assign→ armor_trainings (union)
                  ├─source-of-truth→ Class.tool_proficiency_options + count ─assign(first)→ UI choice → tool_proficiencies (union)
                  ├─source-of-truth→ Class.starting_equipment_options ─assign(first)→ inventory[]
                  ├─source-of-truth→ Class.starting_gold_dice ─assign(first)→ roll → gp
                  ├─source-of-truth→ Class.casting_ability_ref ─assign→ casting_ability_ref (PC)
                  └─source-of-truth→ Class.feature_table[1] ─level-up:1→ class_resources

[Adım 2] Origin (Background + Species)
  background_ref ─assign→
                  ├─source-of-truth→ Background.granted_skill_refs ─assign→ skill_proficiencies (union)
                  ├─source-of-truth→ Background.granted_tool_refs ─assign→ tool_proficiencies (union)
                  ├─source-of-truth→ Background.ability_score_options ─assign→ UI distribute → stat_block
                  ├─source-of-truth→ Background.origin_feat_ref ─assign→ feats[] (append)
                  └─source-of-truth→ Background.starting_gold_gp ─assign→ gp (set)
  species_ref ─assign→
                  ├─source-of-truth→ Species.size_ref ─assign→ space, carry_multiplier
                  ├─source-of-truth→ Species.speed_ft ─assign→ combat_stats.speed
                  ├─source-of-truth→ Species.granted_languages ─assign→ languages[] (union)
                  ├─source-of-truth→ Species.granted_senses ─assign→ senses[] (union)
                  ├─source-of-truth→ Species.granted_damage_resistances ─always→ derived: resistance check
                  ├─source-of-truth→ Species.granted_skill_proficiencies ─assign→ skill_proficiencies (union)
                  └─source-of-truth→ Species.traits ─always→ manual-import → derived: special abilities

[Adım 3] Ability Scores (Standard / Random / Point Buy / Origin Feat +3)
  user choice ─set→ stat_block.{STR..CHA}
                ├─derived→ ability_mod(X)
                │   ├─derived→ saving_throws (rendering)
                │   ├─derived→ skills (rendering)
                │   ├─derived→ combat_stats.ac (DEX_mod)
                │   ├─derived→ combat_stats.initiative (DEX_mod)
                │   ├─derived→ combat_stats.max_hp (CON_mod, all levels)
                │   └─derived→ spell_save_dc/spell_attack_bonus (casting_ability_ref mod)

[Adım 4] Alignment
  alignment_ref ─assign→ alignment_ref (UI/lore only)

[Adım 5] Final Detaylar
  total_level=1 ─derived→ proficiency_bonus = +2
  combat_stats.hp = max_hp
  passive_perception = 10 + Wis(Perception) check_mod
  spell_save_dc = 8 + 2 + spell_mod          (if caster)
  spell_attack_bonus = 2 + spell_mod          (if caster)
  Class.spell_slots_by_level[1] ─long-rest→ spell_slots
  Class.cantrips_known_by_level[1] ─level-up→ spells_known cap
```

### 4.2 Level-Up Zinciri

```
xp ─inc→ xpToLevel(xp) > current_level
   └─level-up→ class_levels[<chosen_class>] += 1
                ├─derived→ total_level = Σ class_levels.values
                │   └─derived→ proficiency_bonus = proficiencyBonusForLevel(total_level)
                │       └─propagates→ saving_throws/skills/attack/spell DC rendering
                │
                ├─level-up:N (N=class_levels[<chosen_class>])→
                │   ├─Class.hit_die ─→ hit_dice_remaining (+1×d_size)
                │   │                ─→ combat_stats.max_hp += avg(d_size)+CON  (or rolled)
                │   │
                │   ├─Class.feature_table[N] ─per-row→ class_resources (Rage uses, SA dice, …)
                │   │   └─if subclass row at N (3/9/13/17 etc.) → trigger Subclass selection
                │   │
                │   ├─Class.cantrips_known_by_level[N] ─set→ spells_known(cantrip) cap
                │   ├─Class.spell_slots_by_level[N] ─combined-table→ spell_slots
                │   └─Class.feature_table[N] contains "ASI" → user picks Feat OR +2/+1+1 stats
                │       └─if Feat → feats[] (union)
                │       └─if ASI → stat_block (manual-distribute, max 20)
                │
                └─if subclass_refs already chosen + Subclass.granted_at_level ≤ N →
                    Subclass.feature_table[N] ─per-row→ class_resources

long-rest ─→ spell_slots = formula(combined-multiclass-table[caster_total_level])
          ─→ pact_magic_slots = formula(per Warlock level)
          ─→ hit_dice_remaining += ½ total_level (per class HD type)
          ─→ exhaustion -= 1
          ─→ prepared_spells (replace per Class.prepared_spells_by_level[N])
          ─→ temp_hp = 0
```

### 4.3 Spell Cast Zinciri

```
user picks spell from prepared_spells (or spells_known if cantrip)
  Spell.level ─cast→ gate: PlayerCharacter.spell_slots[≥ chosen slot level]
              └─if level=0 → cantrip path (no slot)
              └─if Spell.is_ritual + Class.ritual rules → optional ritual path (no slot, +10 min)

  Spell.casting_time_amount + casting_time_unit_ref ─cast→ action economy:
    ├─Action / Bonus Action / Reaction / 1 Minute / 1 Hour
    └─Reaction → Spell.reaction_trigger required

  Spell.components ─cast→ V/S/M satisfy gate:
    ├─V → can speak (not Silenced)
    ├─S → free hand
    └─M → focus OR component pouch OR specific item (if material_cost_gp set)
        └─if material_consumed=true → PlayerCharacter.gp -= material_cost_gp

  Spell.range_type + range_ft ─cast→ targeting: Self/Touch/Ranged/Sight/Unlimited
  Spell.area_shape_ref + area_size_ft ─cast→ AoE coverage (Cone/Cube/Cylinder/Emanation/Line/Sphere)

  Spell.attack_type ∈ {Melee, Ranged} ─attack→ spell attack roll:
    └─attack_bonus = PB + ability_mod(casting_ability_ref) + ModifyAttackRoll bonuses
        └─if hit → damage path

  Spell.save_ability_ref present ─save-roll→ target's save:
    └─target.save_bonus vs PlayerCharacter.spell_save_dc (= 8 + PB + spell_mod)
        └─if fail → full damage / condition applied
        └─if success → ½ damage (typical) OR no effect

  Spell.damage_type_refs ─damage-roll→ resistance check on target:
    ├─Monster.resistance_refs contains type → ½ damage
    ├─Monster.vulnerability_refs → ×2
    └─Monster.damage_immunity_refs → 0

  Spell.requires_concentration=true ─cast→ PlayerCharacter.concentration:
    └─if concentration already active → drop previous (replace)
    └─while concentration active + take damage → ConcentrationCheck (DC = max(10, ½ dmg))
        └─fail → concentration drops

  Spell.duration_unit_ref + duration_amount ─cast→ active spell tracker:
    └─Instantaneous → no tracking
    └─Round/Minute/Hour → AppliedCondition or active-effect entry with duration_rounds
```

---

## §5 Açık Mekanikler

Şema-vs-SRD uyuşmazlıkları. Numaralar §2/§3 satırlarındaki çapraz referanslara karşılık gelir.

**Schema değişikliği uygulananlar (✅):** #1, #9 (kısmen), T1, T2, T4, T6, T7, T8, +Location/Scene refs, +Sense range, +Size carrying, +DamageType bypass.

1. ✅ **`Class.features` / `Subclass.features` `classFeatures` typed list** — Rage uses, Sneak Attack dice, Bardic Inspiration die, Extra Attack count typed encode. (Önceden levelTable Map<int,int>.)

2. **`PlayerCharacter.proficiency_bonus` manuel int** — `total_level`'dan derive edilmeli. Multiclass §1.8 zorunluluğu (PB total character level'a göre). Şu an cache; level-up'ta güncellenmesi convention.

3. **`PlayerCharacter.spell_save_dc` / `spell_attack_bonus` tek skaler** — multiclass'ta iki caster için iki ayrı DC olur (Cleric WIS, Wizard INT). Schema tek tutuyor. Deferred: per-class derived map.

4. **`Class.spell_slots_by_level` per-class ama multiclass slot havuzu *combined* table gerektirir** (s.26). Cached field yok; resolver runtime'da Σ over caster classes hesaplamalı. Pact slots `pact_magic_slots`'ta ayrı.

5. **`Class.saving_throw_refs` first-class-only kuralı** — SRD-mandated (s.25) ama şemada kodlu değil. "Yalnız PC'nin starting class'ı save prof verir" kuralı convention; resolver bunu zorlamalı.

6. **`Species.traits`, `Feat.benefits`, `MagicItem.effects`, `Subclass.feature_table`, `Trait.description` markdown blob** — typed `grants_*` yok. Numeric trait bonusları (Lucky reroll-on-1, Brave adv-vs-Frightened, Tough +HP, Alert init bonus, Cloak of Protection +1 AC/save) için yapısal alan yok. Resolver bunları client-side hard-code etmek zorunda; homebrew için zor.

7. **Multiclass starting proficiency tablosu (s.25)** — `Class.multiclass_requirements` markdown'da; data değil. "Barb multiclass'a girince sadece Shields + Martial weapon training; full Barb starting profs almaz" gibi subset kuralları kodlanamaz; her satırda "per-class subset" notu var ama içerik manuel.

8. **`PlayerCharacter.combat_stats.ac` serbest int** — armor formülü kodlu değil (`base_ac + DEX [+cap] + shield + misc`). Unarmored Defense (Barb=10+DEX+CON, Monk=10+DEX+WIS) seçim mekanizması yok; non-stack multiclass kuralı (s.25) advisory.

9. **`Spell.attack_type` enum {None,Melee,Ranged}** vs **`creature-action.attack_kind` enum {Melee Weapon, Ranged Weapon, Melee Spell, Ranged Spell}** — iki vokabüler. Reconcile gerek veya divergence kabul edilip mapping function yazılmalı.

10. **`MagicItem.charges_max + charge_regain (text)`** — regain free-form ("1d6+4 at dawn"). Long-rest engine auto-restore edemez; parser yazılana kadar manuel.

11. **`AppliedCondition.duration_rounds int (null=indefinite)`** — Exhaustion (`stacks=true`) ve "1 minute / until next dawn / until cured" duration'lar lossy. Round-based tek granularity; minute/hour/day duration'ları round'a çevrilmek zorunda (1 min = 10 rounds).

12. **`Background.ability_score_options` sadece ability listesi** — "+2/+1 vs +1/+1/+1" choice (s.83) kodlu değil; dağıtım PC.stat_block'ta serbest. UI bu seçimi sunmak ve max-20 cap'ini zorlamak zorunda.

13. **`PlayerCharacter.class_levels` `levelTable` (Map<int,int>)** — implicit key class_id (UUID), value level. "level" değil. Type aliasing — convention'ı doc'la; FieldType naming yanıltıcı.

14. **`Animal` slug Monster duplicate** — şema seviyesinde `_animalCategory()` Monster field listesini `copyWith` ile rebuild eder. Field semantikleri özdeş; doc §2.20 sadece delta paragraf. UI/import/codec ayrı slug filter için ayrı.

**Schema değişikliği uygulananlar bu iterasyonda:**
- ✅ **K1** Class.features / Subclass.features → `classFeatures` typed.
- ✅ **K5/E1-E4** Spell.effects → `spellEffectList` typed (damage/heal/condition/save_effect/scaling).
- ✅ **K5/E2** Spell.applied_condition_refs → `relation→condition[]`.
- ✅ **T1** Trap.damage_dice text → `dice`.
- ✅ **T2** creature-action.save_dc text → split: integer `save_dc` + `relation→ability` `save_ability_ref`.
- ✅ **T4** Monster.spellcasting_block markdown → `relation→spell[]` (NPC parite).
- ✅ **T6** Class.spellcasting_focus text → `relation→[arcane-focus, druidic-focus, holy-symbol]`.
- ✅ **T7** Monster.sense_grants textarea → `rangedSenseList` (sense ref + range_ft).
- ✅ **T8** Monster.actions/bonus_actions/reactions/legendary/lair markdown → `relation→creature-action[]` (NPC parite).
- ✅ **+E13** Sense.default_range_ft eklendi.
- ✅ **+Size** Size.carrying_multiplier eklendi (Tiny ×0.5..Gargantuan ×8).
- ✅ **+DamageType** damage-type.bypassable_by_magical eklendi (silvered/magical resistance bypass).
- ✅ **+Location** Location.illumination_ref + hazard_refs[] eklendi (doc-cited).
- ✅ **+Scene** Scene.illumination_ref + travel_pace_ref eklendi (doc-cited).

**Yeni FieldType enum entry'leri:** `classFeatures`, `spellEffectList`, `rangedSenseList`. `defaultValue: <Map<String,dynamic>>[]`. UI editor TBD; şimdilik placeholder widget.

**Ek notlar (kalan yapısal eksikler — bu iterasyonda dokunulmadı):**
- `creature-action.recharge` `text` ("5-6", "Short Rest") — parser gerek (T3).
- `Pack.contents` markdown — quantity-on-relation desteği yok (T5; design §9 #2).
- Species/Feat/MagicItem `granted_modifiers[]` typed bonus listesi — büyük yapısal değişiklik (Tier-B).
- Weapon-property + Weapon-mastery effect DSL — markdown kalıyor (K10/K11).
- PC derived stats engine (AC formula, PB derive, passive scores) — resolver kod, schema değil (K9, V2, V4).

---

## §6 Çapraz İndeks

### 6.1 Field-Key Alfabetik

Aynı field-key birden fazla kategoride bulunabilir; her satırda parent kategori parantez içinde.

| Field key | Kategori (slug) | Section |
|---|---|---|
| `ability_ref` | tool | §2.9 |
| `ability_score_increase` | feat | §2.5 |
| `ability_score_options` | background | §2.4 |
| `ac` | monster, vehicle | §2.19, §2.14 |
| `ac_note` | monster | §2.19 |
| `action_refs` | npc | §3.2 |
| `action_type` | creature-action | §2.18 |
| `activation` | magic-item | §2.16 |
| `age` | species, player-character | §2.3, §3.1 |
| `alignment_ref` | monster, npc, player-character | §2.19, §3.2, §3.1 |
| `allies_organizations` | player-character | §3.1 |
| `ammunition_type_ref` | weapon | §2.7 |
| `appearance` | npc, player-character | §3.2, §3.1 |
| `armor_trainings` | player-character | §3.1 |
| `area_shape_ref` | spell | §2.6 |
| `area_size_ft` | spell | §2.6 |
| `attack_bonus` | creature-action | §2.18 |
| `attack_kind` | creature-action | §2.18 |
| `attack_type` | spell | §2.6 |
| `attitude_ref` | npc | §3.2 |
| `attuned_items` | player-character | §3.1 |
| `attunement_prereq` | magic-item | §2.16 |
| `at_higher_levels` | spell | §2.6 |
| `availability` | service | §3.13 |
| `backstory` | player-character | §3.1 |
| `background_ref` | npc, player-character | §3.2, §3.1 |
| `base_ac` | armor | §2.8 |
| `base_item_ref` | magic-item | §2.16 |
| `beats` | scene | §3.5 |
| `benefits` | feat | §2.5 |
| `bonds` | player-character | §3.1 |
| `bonus_actions` | monster | §2.19 |
| `bundle_count` | ammunition | §2.11 |
| `can_hover` | monster | §2.19 |
| `cargo_tons` | vehicle | §2.14 |
| `carrying_capacity_lb` | mount | §2.13 |
| `casting_ability_ref` | class, player-character | §2.1, §3.1 |
| `casting_time_amount` | spell | §2.6 |
| `casting_time_unit_ref` | spell | §2.6 |
| `cantrips_known_by_level` | class | §2.1 |
| `caster_kind` | class | §2.1 |
| `category_ref` | feat, weapon, armor, tool | §2.5, §2.7, §2.8, §2.9 |
| `charges_max` | magic-item | §2.16 |
| `charge_regain` | magic-item | §2.16 |
| `class_levels` | player-character | §3.1 |
| `class_refs` | spell, npc, player-character | §2.6, §3.2, §3.1 |
| `combat_stats` | npc, player-character | §3.2, §3.1 |
| `command_word` | magic-item | §2.16 |
| `complexity` | class | §2.1 |
| `components` | spell | §2.6 |
| `condition_immunity_refs` | monster, npc | §2.19, §3.2 |
| `condition_ref` | applied-condition | §3.3 |
| `consumable` | adventuring-gear | §2.10 |
| `contents` | pack | §2.12 |
| `cost_cp` | adventuring-gear, service | §2.10, §3.13 |
| `cost_gp` | weapon, armor, tool, ammunition, pack, mount, vehicle, magic-item, poison | §2.7, §2.8, §2.9, §2.11, §2.12, §2.13, §2.14, §2.16, §3.9 |
| `countermeasures` | trap | §3.8 |
| `cp / sp / ep / gp / pp` | player-character | §3.1 |
| `craftable_items` | tool | §2.9 |
| `cr` | monster | §2.19 |
| `creature_type_ref` | species, monster | §2.3, §2.19 |
| `crew` | vehicle | §2.14 |
| `current_conditions` | player-character | §3.1 |
| `daily_cost_cp` | hireling | §3.12 |
| `damage_dice` | weapon, creature-action, monster.hp_dice, trap | §2.7, §2.18, §2.19, §3.8 |
| `damage_immunity_refs` | monster, npc | §2.19, §3.2 |
| `damage_threshold` | vehicle | §2.14 |
| `damage_type_ref` | weapon, creature-action, trap | §2.7, §2.18, §3.8 |
| `damage_type_refs` | spell | §2.6 |
| `danger_level` | location | §3.4 |
| `death_saves_failures` | player-character | §3.1 |
| `death_saves_successes` | player-character | §3.1 |
| `description` | spell, trinket, creature-action, trait | §2.6, §2.15, §2.18, §2.17 |
| `description_long` | location | §3.4 |
| `detection_dc` | trap | §3.8 |
| `dex_cap` | armor | §2.8 |
| `difficulty` | encounter | §3.7 |
| `disable_dc` | trap | §3.8 |
| `doff_time_minutes` | armor | §2.8 |
| `don_time_minutes` | armor | §2.8 |
| `duration_amount` | spell | §2.6 |
| `duration_rounds` | applied-condition | §3.3 |
| `duration_unit_ref` | spell | §2.6 |
| `effect` | poison, curse, environmental-effect | §3.9, §3.10, §3.11 |
| `effects` | magic-item | §2.16 |
| `environment` | location | §3.4 |
| `environmental_effect_refs` | encounter | §3.7 |
| `equipment_refs` | npc | §3.2 |
| `expertise_skills` | player-character | §3.1 |
| `eyes / hair / skin / age / height / weight` | player-character | §3.1 |
| `faction` | npc | §3.2 |
| `feature_table` | class, subclass | §2.1, §2.2 |
| `feats` | player-character | §3.1 |
| `flavor_description` | subclass | §2.2 |
| `flaws` | player-character | §3.1 |
| `focus_kind_ref` | adventuring-gear | §2.10 |
| `gear_refs` | monster | §2.19 |
| `giver_ref` | quest | §3.6 |
| `goals` | npc | §3.2 |
| `granted_at_level` | subclass | §2.2 |
| `granted_damage_resistances` | species | §2.3 |
| `granted_language_count` | background | §2.4 |
| `granted_languages` | species | §2.3 |
| `granted_senses` | species | §2.3 |
| `granted_skill_proficiencies` | species | §2.3 |
| `granted_skill_refs` | background | §2.4 |
| `granted_tool_refs` | background | §2.4 |
| `groups / kind` | service | §3.13 |
| `heroic_inspiration` | player-character | §3.1 |
| `hit_dice_remaining` | player-character | §3.1 |
| `hit_die` | class | §2.1 |
| `hp_average` | monster | §2.19 |
| `hp_dice` | monster | §2.19 |
| `hp` | vehicle, monster.hp_average | §2.14, §2.19 |
| `ideals` | player-character | §3.1 |
| `initiative_modifier` | monster, npc | §2.19, §3.2 |
| `initiative_score` | monster | §2.19 |
| `inventory` | player-character | §3.1 |
| `is_attack` | creature-action | §2.18 |
| `is_cursed` | magic-item | §2.16 |
| `is_focus` | adventuring-gear | §2.10 |
| `is_melee` | weapon | §2.7 |
| `is_ritual` | spell | §2.6 |
| `is_sentient` | magic-item | §2.16 |
| `is_trained` | mount | §2.13 |
| `language_refs` | monster, npc | §2.19, §3.2 |
| `languages` | player-character | §3.1 |
| `lair_actions` | monster | §2.19 |
| `legendary_actions` | monster | §2.19 |
| `legendary_action_uses` | monster | §2.19 |
| `level` | spell, npc | §2.6, §3.2 |
| `location_ref` | npc, scene, encounter | §3.2, §3.5, §3.7 |
| `long_range_ft` | weapon | §2.7 |
| `magic_category_ref` | magic-item | §2.16 |
| `mannerisms` | npc | §3.2 |
| `material_consumed` | spell | §2.6 |
| `material_cost_gp` | spell | §2.6 |
| `material_description` | spell | §2.6 |
| `mastery_ref` | weapon | §2.7 |
| `monsters_refs` | encounter | §3.7 |
| `multiclass_requirements` | class | §2.1 |
| `normal_range_ft` | weapon | §2.7 |
| `notes` | applied-condition | §3.3 |
| `npc_refs` | scene | §3.5 |
| `npcs_refs` | encounter | §3.7 |
| `objective` | quest | §3.6 |
| `origin_feat_ref` | background | §2.4 |
| `parent_class_ref` | subclass | §2.2 |
| `parent_location_ref` | location | §3.4 |
| `pact_magic_slots` | player-character | §3.1 |
| `passengers` | vehicle | §2.14 |
| `passive_insight` | player-character | §3.1 |
| `passive_investigation` | player-character | §3.1 |
| `passive_perception` | monster, npc, player-character | §2.19, §3.2, §3.1 |
| `personality_traits` | player-character | §3.1 |
| `plane_ref` | location | §3.4 |
| `poison_kind` | poison | §3.9 |
| `prepared_spells_by_level` | class | §2.1 |
| `prepared_spells` | player-character | §3.1 |
| `prerequisite` | feat | §2.5 |
| `primary_ability_ref` | class | §2.1 |
| `proficiency_bonus` | monster, npc, player-character | §2.19, §3.2, §3.1 |
| `property_refs` | weapon | §2.7 |
| `quest_refs` | scene | §3.5 |
| `range_ft` | spell | §2.6 |
| `range_long_ft` | creature-action | §2.18 |
| `range_normal_ft` | creature-action | §2.18 |
| `range_type` | spell | §2.6 |
| `rarity_ref` | magic-item | §2.16 |
| `reaction_trigger` | spell | §2.6 |
| `reach_ft` | creature-action | §2.18 |
| `reactions` | monster | §2.19 |
| `recharge` | creature-action | §2.18 |
| `removed_by` | curse | §3.10 |
| `repeatable` | feat | §2.5 |
| `repeatable_limit` | feat | §2.5 |
| `requires_attunement` | magic-item | §2.16 |
| `requires_concentration` | spell | §2.6 |
| `resistance_refs` | monster, npc | §2.19, §3.2 |
| `reward` | quest | §3.6 |
| `roll_d100` | trinket | §2.15 |
| `save_ability_ref` | spell, trap, poison, environmental-effect, applied-condition | §2.6, §3.8, §3.9, §3.11, §3.3 |
| `save_bonuses` | monster | §2.19 |
| `save_dc` | creature-action, trap, poison, environmental-effect, applied-condition | §2.18, §3.8, §3.9, §3.11, §3.3 |
| `save_frequency` | applied-condition | §3.3 |
| `saving_throw_proficiencies` | player-character | §3.1 |
| `saving_throw_refs` | class | §2.1 |
| `saving_throws` | npc, player-character | §3.2, §3.1 |
| `school_ref` | spell | §2.6 |
| `secrets` | npc, location, quest | §3.2, §3.4, §3.6 |
| `sense_grants` | monster | §2.19 |
| `senses` | npc, player-character | §3.2, §3.1 |
| `sentient_alignment_ref` | magic-item | §2.16 |
| `sentient_cha / int / wis` | magic-item | §2.16 |
| `sentient_communication / senses / special_purpose` | magic-item | §2.16 |
| `setup` | encounter | §3.7 |
| `size_ref` | species, monster | §2.3, §2.19 |
| `skill_bonuses` | monster | §2.19 |
| `skill_proficiencies` | player-character | §3.1 |
| `skill_proficiency_choice_count` | class | §2.1 |
| `skill_proficiency_options` | class | §2.1 |
| `skill_ref` | hireling | §3.12 |
| `skilled` | hireling | §3.12 |
| `skills` | npc, player-character | §3.2, §3.1 |
| `source` | trait, creature-action | §2.17, §2.18 |
| `source_entity_ref` | applied-condition | §3.3 |
| `special_action_refs` | npc | §3.2 |
| `species_ref` | npc, player-character | §3.2, §3.1 |
| `speed_burrow_ft / climb_ft / fly_ft / swim_ft / walk_ft` | monster | §2.19 |
| `speed_ft` | species, mount | §2.3, §2.13 |
| `speed_mph` | vehicle | §2.14 |
| `spell_attack_bonus` | player-character | §3.1 |
| `spell_refs` | npc | §3.2 |
| `spell_save_dc` | player-character | §3.1 |
| `spell_slots` | player-character | §3.1 |
| `spell_slots_by_level` | class | §2.1 |
| `spellcasting_block` | monster | §2.19 |
| `spellcasting_focus` | class | §2.1 |
| `spells_known` | player-character | §3.1 |
| `starting_equipment` | background | §2.4 |
| `starting_equipment_options` | class | §2.1 |
| `starting_gold_dice` | class | §2.1 |
| `starting_gold_gp` | background | §2.4 |
| `stat_block` | monster, npc, player-character | §2.19, §3.2, §3.1 |
| `status` | scene, quest | §3.5, §3.6 |
| `stealth_disadvantage` | armor | §2.8 |
| `storage_container` | ammunition | §2.11 |
| `strength_requirement` | armor | §2.8 |
| `subclass_refs` | player-character | §3.1 |
| `tactics` | encounter | §3.7 |
| `tags_line` | monster | §2.19 |
| `telepathy_ft` | monster, npc | §2.19, §3.2 |
| `temp_hp` | player-character | §3.1 |
| `tool_proficiencies` | player-character | §3.1 |
| `tool_proficiency_count` | class | §2.1 |
| `tool_proficiency_options` | class | §2.1 |
| `trait_kind` | trait | §2.17 |
| `trait_refs` | npc | §3.2 |
| `traits` | species, monster | §2.3, §2.19 |
| `trap_refs` | encounter | §3.7 |
| `trigger` | trap, curse | §3.8, §3.10 |
| `trinket_ref` | player-character | §3.1 |
| `uses_per_day` | creature-action | §2.18 |
| `utilize_check_dc` | tool | §2.9 |
| `utilize_description` | tool, adventuring-gear | §2.9, §2.10 |
| `variant_of_ref` | tool | §2.9 |
| `vehicle_kind` | vehicle | §2.14 |
| `versatile_damage_dice` | weapon | §2.7 |
| `vulnerability_refs` | monster, npc | §2.19, §3.2 |
| `weapon_proficiencies` | player-character | §3.1 |
| `weapon_proficiency_categories` | class | §2.1 |
| `weapon_proficiency_specifics` | class | §2.1 |
| `weight_lb` | weapon, armor, tool, adventuring-gear, ammunition, pack, magic-item | §2.7, §2.8, §2.9, §2.10, §2.11, §2.12, §2.16 |
| `xp` | monster, player-character | §2.19, §3.1 |
| `xp_budget` | encounter | §3.7 |

### 6.2 SRD Sayfa İndeksi (yan-dosya tarafından sıkça referans alınan sayfalar)

| SRD Sayfa | Konu | mechanics.md | field_mechanics.md |
|---|---|---|---|
| s.5-6 | Ability scores, ability_mod | §2.1, §2.2 | §3.1.stat_block |
| s.8 | Proficiency Bonus | §2.4 | §2.1.PB, §3.1.proficiency_bonus, §5 #2 |
| s.9-10 | Actions, Bonus Action, Reaction, Skills | §3.5, §3.6, §3.7 | §2.18.action_type |
| s.13 | Combat order, initiative | §3.1 | §3.1.combat_stats.initiative |
| s.14-15 | Movement, attack roll, ranges | §3.3, §3.8 | §2.7, §2.19.speed_*_ft |
| s.16 | HP, damage roll, crit | §4.1, §4.2 | §3.1.combat_stats.hp |
| s.17 | Resistance/Vulnerability/Immunity, Healing | §4.4, §4.7 | §2.19.resistance_refs, §2.19.vulnerability_refs |
| s.17-18 | 0 HP, Death Saves | §4.8 | §3.1.death_saves_* |
| s.18 | Temp HP | §4.11 | §3.1.temp_hp |
| s.19-22 | Karakter yaratma | §1.1 - §1.4 | §4.1 zinciri |
| s.22 | L1 HP, hit dice by class | §1.4 | §2.1.hit_die, §3.1.combat_stats.max_hp |
| s.23 | XP table, PB by level, ASI | §1.5 | §3.1.xp, §3.1.proficiency_bonus |
| s.24-26 | Multiclassing | §1.8 | §2.1.multiclass_requirements, §2.1.spell_slots_by_level (combined-table), §5 #4-#7 |
| s.28+ | Class chapters (Barb→Wiz) | §9 | §2.1, §2.2 |
| s.83-86 | Backgrounds + Species | §10 | §2.3, §2.4 |
| s.87-88 | Feats | §11 | §2.5 |
| s.89-90 | Coins, Carrying, Weapons | §6.1, §6.2, §6.4-§6.5 | §2.7 |
| s.92 | Armor | §6.7-§6.8 | §2.8 |
| s.93 | Tools | §6.9 | §2.9 |
| s.94-99 | Adventuring Gear | §6.10 | §2.10 |
| s.100 | Mounts & Vehicles | §6.12 | §2.13, §2.14 |
| s.101 | Lifestyle Expenses | §6.13 | §1.2.lifestyle |
| s.102 | Hirelings, Spellcasting Services, Identification, Attunement | §6.14, §6.15, §7.8 | §3.12, §3.13, §2.16 |
| s.103 | Crafting | §6.16-§6.18 | §2.16, §1.2.rarity |
| s.104-106 | Spell rules | §8.1-§8.13 | §2.6 |
| s.176-191 | Rules glossary (Conditions, Hide, Cover, etc.) | §3.5, §5 | §3.3 |
| s.179 | Conditions (15) | §5 | §3.3, §1.2.condition |
| s.180 | Damage Types (13) | §4.3 | §1.2.damage-type |
| s.192-203 | Gameplay toolbox | §1.6 | §3.4-§3.11 |
| s.204-253 | Magic Items | §12 | §2.16 |
| s.254-343 | Monsters | §17 | §2.19 |
| s.344+ | Animals | §17 | §2.20 |
