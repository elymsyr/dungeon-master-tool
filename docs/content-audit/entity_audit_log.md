# Entity Audit Log — Official & Built-in Packages

> Automated System Architecture Inspector — per-entity ledger for the
> `dungeon-master-tool` D&D 5e content packages. Companion roadmap:
> [`system_mechanics_roadmap.md`](system_mechanics_roadmap.md). Branch: `list`.
> Generated 2026-06-10.

## Scope & method

Two sources of official / built-in content were inspected:

1. **Official first-party catalog — Open5e packs** (machine-imported JSON):
   `flutter_app/assets/open5e_packs/*.pkg.json`, declared in `manifest.json`.
   **19 packs · 20,712 entity cards.** Every card's `attributes` map was parsed
   from JSON and compared field-by-field against the typed schema
   (`flutter_app/lib/domain/entities/schema/builtin/content.dart`) and the
   mechanics the runtime actually consumes
   (`character_resolver.dart`, `pending_choice_resolver_dialog.dart`).
2. **Built-in pack — SRD 5.2.1 core** (hand-authored Dart):
   `flutter_app/lib/domain/entities/schema/builtin/srd_core/`. Audited at the
   per-builder level (deficiencies are uniform within a builder) and used as the
   **structural reference** — it populates the typed fields the official packs
   leave empty.

**Card inventory (official packs)**

| Category | Cards | Audit granularity |
|---|---:|---|
| feat | 73 | per-entity |
| background | 53 | per-entity |
| class | 2 | per-entity |
| subclass | 101 | per-entity |
| species | 11 | per-entity |
| subspecies | 30 | per-entity |
| spell | 1,297 | per pack×category (machine-uniform) |
| magic-item | 1,063 | per pack×category |
| adventuring-gear | 159 | per pack×category |
| trait | 6,423 | per pack×category |
| creature-action | 8,615 | per pack×category |
| monster | 2,885 | per pack×category |
| **Total** | **20,712** | |

Chargen entities (270) are **enumerated individually** because the three
inspection criteria vary card-to-card. Bulk content (20,442 cards) is
machine-uniform within each category, so it is audited at category granularity.

**Finding codes**

- **E** — benefits/mechanics live entirely in `description`; no typed
  `effects`/`granted_modifiers` (Missing Mechanics — roadmap 2.1).
- **P** — prerequisite stated in text but **not enforced at apply-time**; no
  structured prereq field either (Unimplemented Prerequisite — roadmap 1.1).
- **Pc** — structured prereq present (`prereq_clauses`/flat) but (a) unenforced
  by the resolver and (b) `prereq_clauses` is undeclared in the schema (roadmap
  1.1 + 1.2).
- **D** — `description` duplicated verbatim into `attributes.description` (Poor
  Data Structure — roadmap 3.1). **Applies to every feat/background/subclass/
  species card; noted once here, not repeated per row.**
- **✓m** — partially mechanized: a typed `effects` block is present.

Sources abbreviated: **AG** Adventurer's Guide · **ToH** Tome of Heroes ·
**TDCS** Tal'dorei Campaign Setting · **DDG** Dungeon Delver's Guide ·
**GPG** Gate Pass Gazette · **O5e** Open5e Originals · **BFRD** Black Flag SRD.

---

## 1. Feats — 73 cards (per-entity)

All 73 carry **D** (description mirrored into `attributes.description`).
**64/73 carry E** (no typed effects). **27/73 declare a prerequisite**, none
enforced at apply-time. The 9 partially mechanized feats are marked ✓m.

| # | Feat | Source | Findings |
|---:|---|---|---|
| 1 | Ace Driver | AG | E · P (prereq text, no structured field) |
| 2 | Athletic | AG | E |
| 3 | Attentive | AG | E |
| 4 | Battle Caster | AG | E · Pc |
| 5 | Boundless Reserves | ToH | E · Pc |
| 6 | Brutal Attack | AG | E |
| 7 | Bull Rush | AG | E |
| 8 | Combat Thievery | AG | E |
| 9 | Covert Training | AG | E |
| 10 | Crafting Expert | AG | ✓m |
| 11 | Crossbow Expertise | AG | E |
| 12 | Deadeye | AG | E · Pc |
| 13 | Deflector | AG | E · Pc |
| 14 | Destiny's Call | AG | E |
| 15 | Diehard | ToH | E · Pc |
| 16 | Dual-Wielding Expert | AG | E |
| 17 | Dungeoneer | AG | E |
| 18 | Empathic | AG | E |
| 19 | Fear Breaker | AG | E |
| 20 | Floriographer | ToH | E · Pc |
| 21 | Forest Denizen | ToH | E |
| 22 | Fortunate | AG | E |
| 23 | Friend of the Forest | ToH | E |
| 24 | Giant Foe | ToH | E · P (prereq text, no structured field) |
| 25 | Guarded Warrior | AG | E |
| 26 | Hardy Adventurer | AG | E |
| 27 | Harrier | ToH | E · P (prereq text, no structured field) |
| 28 | Heavily Outfitted | AG | ✓m · Pc |
| 29 | Heavy Armor Expertise | AG | E · Pc |
| 30 | Heraldic Training | AG | E |
| 31 | Idealistic Leader | AG | E |
| 32 | Inner Resilience | ToH | E · Pc |
| 33 | Intuitive | AG | E |
| 34 | Keen Intellect | AG | E |
| 35 | Lightly Outfitted | AG | ✓m |
| 36 | Linguistics Expert | AG | E |
| 37 | Martial Scholar | AG | E · Pc |
| 38 | Medium Armor Expert | AG | E · Pc |
| 39 | Moderately Outfitted | AG | ✓m · Pc |
| 40 | Monster Hunter | AG | E · Pc |
| 41 | Mounted Warrior | AG | E |
| 42 | Mystical Talent | AG | E |
| 43 | Natural Warrior | AG | ✓m |
| 44 | Part of the Pack | ToH | E · Pc |
| 45 | Physician | AG | E |
| 46 | Polearm Savant | AG | E |
| 47 | Power Caster | AG | E · Pc |
| 48 | Powerful Attacker | AG | E |
| 49 | Primordial Caster | AG | E · Pc |
| 50 | Rallying Speaker | AG | E · Pc |
| 51 | Rapid Drinker | TDCS | E |
| 52 | Resonant Bond | AG | E |
| 53 | Rimecaster | ToH | E · Pc |
| 54 | Rite Master | AG | E · Pc |
| 55 | Shield Focus | AG | ✓m |
| 56 | Skillful | AG | ✓m |
| 57 | Skirmisher | AG | ✓m |
| 58 | Sorcerous Vigor | ToH | E · Pc |
| 59 | Spellbreaker | AG | E |
| 60 | Stalker | ToH | E |
| 61 | Stalwart | AG | E |
| 62 | Stealth Expert | AG | E · Pc |
| 63 | Street Fighter | AG | E |
| 64 | Stunning Sniper | ToH | E · P (prereq text, no structured field) |
| 65 | Surgical Combatant | AG | E |
| 66 | Survivor | AG | E |
| 67 | Swift Combatant | AG | ✓m · Pc |
| 68 | Tactical Support | AG | E |
| 69 | Tenacious | AG | E |
| 70 | Thespian | AG | E |
| 71 | Weapons Specialist | AG | E |
| 72 | Well-Heeled | AG | E · P (prereq text, no structured field) |
| 73 | Woodcraft Training | AG | E |

**Note on ✓m feats.** Even the 9 mechanized feats carry their prerequisite (when
present) as data that the resolver does not validate at apply-time, and their
`prereq_clauses` key is undeclared in the schema. None is fully "Clean."

---

## 2. Backgrounds — 53 cards (per-entity)

**Universal finding (all 53):** missing schema-`required` `origin_feat_ref`
(0/53) and `asi_distribution_options` (0/53); no `starting_gold_gp`,
`default_inventory_refs`, or `rule_effects`; **D** (description mirrored). Skills
(51/53) and equipment choice groups (52/53) are otherwise well-populated. Extra
per-entity gaps below: **A** = no `ability_score_options`; **S** = no
`granted_skill_refs`; **Q** = no `equipment_choice_groups`.

| Background | Source | Extra gaps |
|---|---|---|
| Acolyte | AG | — |
| Artisan | AG | — |
| Charlatan | AG | — |
| Con Artist | O5e | A |
| Court Servant | ToH | A |
| Crime Syndicate Member | TDCS | A |
| Criminal | AG | — |
| Cultist | AG | — |
| Cursed | GPG | — |
| Deep Hunter | DDG | — |
| Desert Runner | ToH | A |
| Destined | ToH | A |
| Diplomat | ToH | A |
| Dungeon Robber | DDG | — |
| Elemental Warden | TDCS | A |
| Entertainer | AG | — |
| Escapee from Below | DDG | — |
| Exile | AG | — |
| Farmer | AG | — |
| Fate-Touched | TDCS | A · S · Q (skeleton card — all grants empty) |
| Folk Hero | AG | — |
| Forest Dweller | ToH | A |
| Former Adventurer | ToH | A |
| Freebooter | ToH | A |
| Gambler | AG | — |
| Gamekeeper | ToH | A |
| Guard | AG | — |
| Guildmember | AG | S |
| Haunted | GPG | — |
| Hermit | AG | — |
| Imposter | DDG | — |
| Innkeeper | ToH | A |
| Lyceum Student | TDCS | A |
| Marauder | AG | — |
| Mercenary Company Scion | ToH | A |
| Mercenary Recruit | ToH | A |
| Monstrous Adoptee | ToH | A |
| Mysterious Origins | ToH | A |
| Noble | AG | — |
| Northern Minstrel | ToH | A |
| Occultist | ToH | A |
| Outlander | AG | — |
| Parfumier | ToH | A |
| Recovered Cultist | TDCS | A |
| Sage | AG | — |
| Sailor | AG | — |
| Scoundrel | O5e | A |
| Scoundrel | ToH | A |
| Sentry | ToH | A |
| Soldier | AG | — |
| Trader | AG | — |
| Trophy Hunter | ToH | A |
| Urchin | AG | — |

---

## 3. Classes — 2 cards (per-entity)

| Class | Source | Findings |
|---|---|---|
| Marshal | AG | Identity fields good (`hit_die`, `caster_kind`, `saving_throw_refs`, weapon/armor proficiencies, skill choice). **No `features` map** — every leveled class feature is prose only (Missing Mechanics, roadmap 1.3/2.2). **D**. |
| Mechanist | BFRD | Same as Marshal: proficiency/identity fields populated; **no leveled `features`**; **D**. |

---

## 4. Subclasses — 101 cards (per-entity, uniform finding)

**Every one of the 101 official subclasses carries only `description` +
`parent_class_ref`.** None has `granted_at_level` (schema-`required`), `features`,
or `rule_effects`. Result: taking any official subclass grants **zero**
mechanical effect — all features are inert prose (Missing Mechanics 1.3/2.2;
Poor Data Structure 3.1; missing required field). Listed for completeness,
grouped by source. *(The four AG/BFRD entries link `parent_class_ref` to the
same-pack first-party base class via a soft UUID ref rather than a name.)*

**Adventurer's Guide (3):** Gambling General, Swift Strategist, Talented
Tactician.

**Black Flag SRD (1):** Metallurgist.

**Open5e Originals (17):** Abjurationist, Arcane Warrior, Circle of the Many,
College of Skalds, Demise Domain, Eldritch Trickster, Mischief Domain, Oathless
Betrayer, School of Abjuring and Warding, School of Divining and Soothsaying,
School of Illusions and Phantasms, School of Necrotic Arts, Storm Domain, The
Ancient Fey Court, The Great Elder Thing, Way of Shadowdancing, Wyrd Magic.

**Tal'dorei Campaign Setting (4):** Blood Domain, Path of the Juggernaut,
Runechild, Way of the Cerulean Spirit.

**Tome of Heroes (76):** Ancient Dragons, Animal Lords, Beast Trainer, Cantrip
Adept, Cat Burglar, Chaplain, Circle of Ash, Circle of Bees, Circle of Crystals,
Circle of Sand, Circle of Wind, Circle of the Green, Circle of the Shapeless,
Cold-Blooded, College of Echoes, College of Investigation, College of Shadows,
College of Sincerity, College of Tactics, College of the Cat, Courser Mage, Dawn
Blade, Familiar Master, Gravebinding, Grove Warden, Haunted Warden, Hungering,
Hunt Domain, Hunter in Darkness, Legionary, Mercy Domain, Oath of Justice, Oath
of Safeguarding, Oath of the Elements, Oath of the Guardian, Oath of the Hearth,
Oath of the Plaguetouched, Old Wood, Path of Booming Magnificence, Path of
Hellfire, Path of Mistwood, Path of Thorns, Path of the Dragon, Path of the
Herald, Path of the Inner Eye, Portal Domain, Primordial, Pugilist, Radiant
Pikeman, Resonant Body, Rifthopper, Sapper, School of Liminality, Serpent
Domain, Shadow Domain, Smuggler, Snake Speaker, Soulspy, Spear of the Weald,
Spellsmith, Spore Sorcery, Timeblade, Tunnel Watcher, Underfoot, Vermin Domain,
Wasteland Strider, Wastelander, Way of Concordant Motion, Way of the Dragon, Way
of the Humble Elephant, Way of the Still Waters, Way of the Tipsy Monkey, Way of
the Unerring Arrow, Way of the Wildcat, Wind Domain, Wyrdweaver.

---

## 5. Species — 11 cards (per-entity)

All carry `creature_type_ref` and `description` (**D**). Granted traits are in
text; structured grants are partial. **Sz** = missing `size_ref`; **Sp** =
missing `speed_ft`; **M** = no `granted_modifiers`.

| Species | Source | Findings |
|---|---|---|
| Alseid | ToH | size, speed, modifiers present; trait text un-mechanized |
| Catfolk | ToH | size, speed, modifiers present; trait text un-mechanized |
| Darakhul | ToH | **Sz · Sp** — no size/speed; traits text-only |
| Derro | ToH | populated; trait text un-mechanized |
| Drow | ToH | populated; trait text un-mechanized |
| Erina | ToH | populated; trait text un-mechanized |
| Gearforged | ToH | **Sz · Sp · M** — minimal structured data; all in text |
| Minotaur | ToH | populated; trait text un-mechanized |
| Mushroomfolk | ToH | **Sz** — no size; speed/mods present |
| Satarre | ToH | populated; trait text un-mechanized |
| Shade | ToH | **Sz · Sp · M** — minimal structured data; all in text |

---

## 6. Subspecies — 30 cards (per-entity, near-uniform finding)

All 30 carry `parent_species_ref`, `creature_type_ref`, `description` (**D**),
and most carry `granted_modifiers` (27/30). Grants are otherwise partial —
`granted_cantrip_refs` 4/30, `granted_spell_refs` 3/30, `granted_skill_proficiencies`
8/30, `size_ref` 10/30, `speed_ft` 13/30 — with the remainder of each
subspecies' benefits folded into `description`. Cards (O5e + ToH):

Acid Cap · Bhain Kwai · Boghaid · Delver · Derro Heritage · Dragonborn Heritage ·
Drow Heritage · Dwarf Chassis · Dwarf Heritage · Elf/Shadow Fey Heritage ·
Far-Touched · Favored · Fever-Bit · Gnome Chassis · Gnome Heritage · Halfling
Heritage · Human Chassis · Human/Half-Elf Heritage · Kobold Chassis · Kobold
Heritage · Malkin · Morel · Mutated · Pantheran · Purified · Ravenfolk · Stoor
Halfling · Tiefling Heritage · Trollkin Heritage · Uncorrupted.

---

## 7. Bulk content (per pack×category — machine-uniform)

### 7.1 Spells — 1,297 cards — **mostly Clean**
Metadata is thoroughly typed on all 1,297: `level`, `school_ref`,
`casting_time_amount`/`_unit_ref`, `components`, `duration_*`, `range_type`,
`is_ritual`, `requires_concentration`. Conditional fields populate where
applicable (`range_ft` 719, `save_ability_ref` 567, `damage_type_refs` 294,
`attack_type` 89, `material_*` 369). **Residual finding:** the spell *effect*
(including at-higher-levels scaling) remains in `description` with no typed
"upcast/scaling" field — acceptable for narrative spell text, but automation
cannot compute higher-level damage. **D** applies (description mirrored).

### 7.2 Magic items — 1,063 cards (all in Vault of Magic) — **Clean structure**
All 1,063 carry typed `rarity_ref`, `magic_category_ref`, `requires_attunement`,
`is_cursed`, `is_sentient`, `activation`, and a typed `effects` block; no
mirrored `description`. **Residual finding:** restricted-attunement clauses
("by a spellcaster / by a creature of evil alignment" — 35 items) live only in
prose; `requires_attunement` is a bare boolean with no typed *who-may-attune*
field, so the restriction is unenforced (roadmap 1.1).

### 7.3 Adventuring gear — 159 cards — **Clean**
Uniformly typed `cost_cp`, `weight_lb`, `consumable`, `is_focus`; no mirrored
description. No deficiency for mundane gear.

### 7.4 Creature-actions — 8,615 cards — **Clean structure**
Well typed: `action_type`, `is_attack`, `attack_bonus`/`attack_kind`/`damage_dice`
(3,471–3,549 where attacks), `reach_ft`/`range_*`, `recharge_kind`/`recharge_min_roll`,
`uses_per_day`. The free-form rider text (riders/conditions on a hit) remains in
`description` — acceptable. **D** applies.

### 7.5 Monsters — 2,885 cards — **Clean structure, one hygiene flag**
Extensively typed: `ac`, `hp_average`/`hp_dice`, `cr`, `xp`, all speeds, saves,
skills, senses, resistances/immunities/vulnerabilities, languages, action/
bonus/reaction/legendary refs, `proficiency_bonus`, `initiative_*`. **Residual
finding (3.2):** every card also carries a `stat_block` field duplicating the
typed data as rendered text — redundant and a drift risk.

### 7.6 Monster traits — 6,423 cards — **Missing Mechanics (uniform)**
Every trait carries only `description` + `source` + `trait_kind`. Mechanically
load-bearing traits (damage resistances, regeneration, *Magic Resistance*, *Pack
Tactics*, *Sunlight Sensitivity*, etc.) are indistinguishable from flavor and
carry no typed effect (roadmap 2.4). **D** applies.

---

## 8. Built-in SRD 5.2.1 core — reference pack (hand-authored)

Audited per-builder under `flutter_app/lib/domain/entities/schema/builtin/srd_core/`.
Unlike the imported packs, the SRD core **populates the typed fields**: the
subclass builder emits `granted_at_level` + level-keyed `features`; the feat
builders emit typed `effects`, flat `prereq_min_score`/`prereq_ability_ref`, and
`granted_modifiers`; classes carry `features`; species/subspecies carry typed
grants. It is therefore logged as the **structural gold standard** and is
**Clean** on the Poor-Data-Structure and Missing-Mechanics criteria.

**One system-wide caveat that still applies to the SRD core:** feat/magic-item
prerequisites it declares are validated **only** by the picker dialog, never by
the resolver at apply-time (roadmap 1.1). So even hand-authored content inherits
the unenforced-prerequisite gap — it is a runtime deficiency, not a data one.

---

## Summary tally

| Criterion | Official cards affected |
|---|---:|
| Unimplemented prerequisites (feats) | 27 declared, **0 enforced** at apply-time |
| Unimplemented prerequisites (magic-item attunement restrictions) | 35+ (text-only) |
| `prereq_clauses` undeclared in schema | 22 feats |
| Missing mechanics — feat benefits text-only | 64 / 73 feats |
| Missing mechanics — subclass features text-only | **101 / 101 subclasses** |
| Missing mechanics — class leveled features text-only | 2 / 2 classes |
| Missing mechanics — monster traits text-only | 6,423 / 6,423 traits |
| Missing required field — background `origin_feat_ref` | 53 / 53 |
| Missing required field — background `asi_distribution_options` | 53 / 53 |
| Missing required field — subclass `granted_at_level` | 101 / 101 |
| Poor data structure — `description` mirrored into attributes | feats, backgrounds, subclasses, species, spells, traits, creature-actions |
| Poor data structure — monster `stat_block` duplication | 2,885 monsters |
| **Clean (structure + mechanics)** | spells (metadata), magic items, adventuring gear, creature-actions, monsters (typed fields), and the entire SRD 5.2.1 core |
