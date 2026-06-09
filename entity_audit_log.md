# Entity Audit Log — Official & Built-in Packages

> Automated System Architecture Inspector · audit date **2026-06-09** · branch `list`

## Scope & Methodology

Two package sources were inspected:

1. **Built-in SRD 5.2.1 Core pack** — hand-authored in-code at `flutter_app/lib/domain/entities/schema/builtin/srd_core/` (the structural exemplar; ~488 `packEntity` rows + ~341 spells + ~287 magic items).
2. **19 official / bundled Open5e packages** — `flutter_app/assets/open5e_packs/*.pkg.json`, also published through the first-party catalog `flutter_app/assets/first_party/manifest.json`. **20,712 entity cards total.**

Every **character-build entity** (`class`, `subclass`, `species`, `subspecies`, `background`, `feat` — 270 cards) is enumerated individually below with its specific findings. The **reference-content entities** (`spell`, `monster`, `trait`, `creature-action`, `magic-item`, `adventuring-gear` — 20,442 cards) share one identical data shape per type, so they are audited as a class: each pack lists the per-type count, the systematic finding that applies uniformly to every card of that type, and representative card names. "Clean" = correctly typed *and* mechanically wired.

---

## Built-in: SRD 5.2.1 Core pack (in-code)

This pack is the **structural reference** — feats carry `category_ref`, typed `prereq_*` fields, `asi_*` gates, and (for 18 of 62 feats) real `effects` Effect-DSL arrays (e.g. *Magic Initiate*, *Skilled* use `choice_group`). Findings:

- **Text-only benefits (44 / 62 feats):** *Alert*, *Savage Attacker*, *Archery* (+2 ranged attack), *Defense* (+1 AC), and 40 others describe numeric/active benefits in the `benefits` markdown with **no `effects` entry**, so those bonuses are not folded into `EffectiveCharacter`.
- **OR-ability prerequisite not fully enforced:** *Grappler* ("Strength or Dexterity 13+") sets `prereq_min_score: 13` but cannot set a single `prereq_ability_ref` for an OR — the clause-based `prereq_clauses` mechanism that the UI *can* evaluate is authored by **zero** content rows.
- **Leveled subclass/class features** default to level 1 (no `granted_at_level`).
- **Spells/magic items** are generated via `_spell()` / `_mi()` helpers with typed metadata but prose effect bodies (same effect-automation gap as the Open5e spells/items below).

---

## open5e-a5e-ag — Adventurer's Guide

*Publisher: EN Publishing · License: ogl-10a · System: a5e*  
Counts: adventuring-gear 44, background 21, class 1, feat 59, spell 371, subclass 3

### class (1)

- **Marshal** — Hit die, saving throws, proficiencies and caster kind are typed; **leveled class features and spell lists remain freeform prose with no level field**, so per-level feature granting is unsupported. `primary_ability_ref` empty → multiclass entry prereq cannot be enforced.

### subclass (3)

- **Gambling General** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Swift Strategist** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Talented Tactician** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.

### background (21)

- **Acolyte** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Artisan** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Charlatan** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Criminal** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Cultist** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Entertainer** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Exile** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Farmer** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Folk Hero** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Gambler** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Guard** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Guildmember** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Hermit** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Marauder** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Noble** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Outlander** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Sage** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Sailor** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Soldier** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Trader** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Urchin** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.

### feat (59)

- **Ace Driver** — Prerequisite is narrative text only ("Proficiency with a type of vehicle") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Athletic** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Attentive** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Battle Caster** — Prerequisite is narrative text only ("Requires the ability to cast at least one spell of 1st-level or higher") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Brutal Attack** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Bull Rush** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Combat Thievery** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Covert Training** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Crafting Expert** — Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Crossbow Expertise** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Deadeye** — Prerequisite parsed to structured field(s) and enforced ("8th level or higher"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Deflector** — Prerequisite parsed to structured field(s) and enforced ("Dexterity 13 or higher"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Destiny’s Call** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Dual-Wielding Expert** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Dungeoneer** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Empathic** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Fear Breaker** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Fortunate** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Guarded Warrior** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Hardy Adventurer** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Heavily Outfitted** — Prerequisite is narrative text only ("Proficiency with medium armor") → **not enforced** at selection (no `prereq_*` structured field). Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Heavy Armor Expertise** — Prerequisite is narrative text only ("Proficiency with heavy armor") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Heraldic Training** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Idealistic Leader** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Intuitive** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Keen Intellect** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Lightly Outfitted** — Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Linguistics Expert** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Martial Scholar** — Prerequisite is narrative text only ("Proficiency with at least one martial weapon") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Medium Armor Expert** — Prerequisite is narrative text only ("Proficiency with medium armor") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Moderately Outfitted** — Prerequisite is narrative text only ("Proficiency with light armor") → **not enforced** at selection (no `prereq_*` structured field). Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Monster Hunter** — Prerequisite parsed to structured field(s) and enforced ("Proficiency with Survival, 8th level or higher"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Mounted Warrior** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Mystical Talent** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Natural Warrior** — Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Physician** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Polearm Savant** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Power Caster** — Prerequisite is narrative text only ("The ability to cast at least one spell") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Powerful Attacker** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Primordial Caster** — Prerequisite is narrative text only ("The ability to cast at least one spell") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Rallying Speaker** — Prerequisite parsed to structured field(s) and enforced ("Charisma 13 or higher"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Resonant Bond** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Rite Master** — Prerequisite parsed to structured field(s) and enforced ("Intelligence or Wisdom 13 or higher"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Shield Focus** — Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Skillful** — Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Skirmisher** — Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Spellbreaker** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Stalwart** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Stealth Expert** — Prerequisite parsed to structured field(s) and enforced ("Dexterity 13 or higher"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Street Fighter** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Surgical Combatant** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Survivor** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Swift Combatant** — Prerequisite parsed to structured field(s) and enforced ("8th level or higher"). Proficiency-choice effect wired; remaining benefit prose unmodeled.
- **Tactical Support** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Tenacious** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Thespian** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Weapons Specialist** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Well-Heeled** — Prerequisite is narrative text only ("Prestige rating of 2 or higher") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Woodcraft Training** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.

### spell (371) — audited as a class

Rich metadata is typed (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`). **Missing mechanic:** no damage-dice / effect-amount field and no structured *cast-at-higher-level* (upcast/scaling) field — the spell outcome lives only in the prose `description`, so damage rolls, save-for-half, and upcasting are not automated.  
Representative cards: *Accelerando*, *Acid Arrow*, *Acid Splash*, *Aid*, *Air Wave*, …

### adventuring-gear (44) — audited as a class

Typed cost/weight/consumable/`is_focus` fields. **Data gap:** `is_focus` is uniformly `false` and many cost/weight values are `0`, so spellcasting-focus and encumbrance validation cannot key off the data.  
Representative cards: *Holy Symbol*, *Common Clothes*, *Robe*, *Prayer Book*, *Prayer Wheel*, …

---

## open5e-a5e-ddg — Dungeon Delver’s Guide

*Publisher: EN Publishing · License: ogl-10a · System: a5e*  
Counts: adventuring-gear 9, background 4

### background (4)

- **Deep Hunter** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Dungeon Robber** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Escapee from Below** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Imposter** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.

### adventuring-gear (9) — audited as a class

Typed cost/weight/consumable/`is_focus` fields. **Data gap:** `is_focus` is uniformly `false` and many cost/weight values are `0`, so spellcasting-focus and encumbrance validation cannot key off the data.  
Representative cards: *Chalk*, *Traveler's Clothes*, *Hunting Traps*, *Cartographers' Tools*, *Miner's Pick*, …

---

## open5e-a5e-gpg — Gate Pass Gazette

*Publisher: EN Publishing · License: ogl-10a · System: a5e*  
Counts: adventuring-gear 10, background 2

### background (2)

- **Cursed** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Haunted** — `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.

### adventuring-gear (10) — audited as a class

Typed cost/weight/consumable/`is_focus` fields. **Data gap:** `is_focus` is uniformly `false` and many cost/weight values are `0`, so spellcasting-focus and encumbrance validation cannot key off the data.  
Representative cards: *Days Of Rations*, *Person Tent*, *Traveler's Clothes*, *Days Worth Of Rations*, *Bell*, …

---

## open5e-a5e-mm — Monstrous Menagerie

*Publisher: EN Publishing · License: ogl-10a · System: a5e*  
Counts: creature-action 1657, monster 586, trait 829

### monster (586) — audited as a class

Reference statblock. Defensive/offensive numbers are typed, but mechanical behaviours (multiattack, recharge, save DCs, legendary/lair actions) are prose inside linked `creature-action`/`trait` cards. **No encounter-automation mechanic** — acceptable for a reference card, logged for completeness.  
Representative cards: *Aboleth*, *Aboleth Thrall*, *Abominable Snowman*, *Accursed Guardian Naga*, *Accursed Spirit Naga*, …

### trait (829) — audited as a class

Reference sub-card of a monster. The trait's rules text is a single prose field; no Effect DSL. Structurally clean as reference content.  
Representative cards: *Amphibious*, *Innate Spellcasting*, *Sea Changed*, *Camouflage*, *Fire Fear*, …

### creature-action (1657) — audited as a class

Reference sub-card of a monster (attack/action). Attack rules are prose; no structured attack/damage automation. Structurally clean as reference content.  
Representative cards: *Baleful Charm*, *Move*, *Multiattack*, *Slimy Cloud*, *Soul Drain*, …

---

## open5e-bfrd — Black Flag SRD

*Publisher: Kobold Press · License: cc-by-40 · System: 5e-2014*  
Counts: class 1, creature-action 1339, monster 360, subclass 1, trait 776

### class (1)

- **Mechanist** — Hit die, saving throws, proficiencies and caster kind are typed; **leveled class features and spell lists remain freeform prose with no level field**, so per-level feature granting is unsupported. `primary_ability_ref` empty → multiclass entry prereq cannot be enforced.

### subclass (1)

- **Metallurgist** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.

### monster (360) — audited as a class

Reference statblock. Defensive/offensive numbers are typed, but mechanical behaviours (multiattack, recharge, save DCs, legendary/lair actions) are prose inside linked `creature-action`/`trait` cards. **No encounter-automation mechanic** — acceptable for a reference card, logged for completeness.  
Representative cards: *Aboleth*, *Acolyte*, *Adult Black Dragon*, *Adult Blue Dragon*, *Adult Brass Dragon*, …

### trait (776) — audited as a class

Reference sub-card of a monster. The trait's rules text is a single prose field; no Effect DSL. Structurally clean as reference content.  
Representative cards: *Aberrant Resilience*, *Amphibious*, *Legendary Resistance (3/Day)*, *Probing Telepathy*, *Slime Pox*, …

### creature-action (1339) — audited as a class

Reference sub-card of a monster (attack/action). Attack rules are prose; no structured attack/damage automation. Structurally clean as reference content.  
Representative cards: *Detect*, *Multiattack*, *Psychic Bolt*, *Psychic Torrent*, *Slime Drain*, …

---

## open5e-ccdx — Creature Codex

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: creature-action 1148, monster 356, trait 921

### monster (356) — audited as a class

Reference statblock. Defensive/offensive numbers are typed, but mechanical behaviours (multiattack, recharge, save DCs, legendary/lair actions) are prose inside linked `creature-action`/`trait` cards. **No encounter-automation mechanic** — acceptable for a reference card, logged for completeness.  
Representative cards: *Aatxe*, *Acid Ant*, *Adult Light Dragon*, *Adult Wasteland Dragon*, *Agnibarra*, …

### trait (921) — audited as a class

Reference sub-card of a monster. The trait's rules text is a single prose field; no Effect DSL. Structurally clean as reference content.  
Representative cards: *Charge*, *Know Thoughts*, *Magic Resistance*, *Shapechanger*, *Explosive Death*, …

### creature-action (1148) — audited as a class

Reference sub-card of a monster (attack/action). Attack rules are prose; no structured attack/damage automation. Structurally clean as reference content.  
Representative cards: *Bulwark*, *Detect*, *Gore*, *Gore (Aatxe)*, *Paw the Earth*, …

---

## open5e-deepm — Deep Magic for 5th Edition

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: spell 515

### spell (515) — audited as a class

Rich metadata is typed (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`). **Missing mechanic:** no damage-dice / effect-amount field and no structured *cast-at-higher-level* (upcast/scaling) field — the spell outcome lives only in the prose `description`, so damage rolls, save-for-half, and upcasting are not automated.  
Representative cards: *Abhorrent Apparition*, *Accelerate*, *Acid Gate*, *Acid Rain*, *Adjust Position*, …

---

## open5e-deepmx — Deep Magic Extended

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: spell 64

### spell (64) — audited as a class

Rich metadata is typed (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`). **Missing mechanic:** no damage-dice / effect-amount field and no structured *cast-at-higher-level* (upcast/scaling) field — the spell outcome lives only in the prose `description`, so damage rolls, save-for-half, and upcasting are not automated.  
Representative cards: *Absolute Command*, *Amplify Ley Field*, *Animate Construct*, *Anomalous Object*, *Armored Heart*, …

---

## open5e-kp — Kobold Press Compilation

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: spell 31

### spell (31) — audited as a class

Rich metadata is typed (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`). **Missing mechanic:** no damage-dice / effect-amount field and no structured *cast-at-higher-level* (upcast/scaling) field — the spell outcome lives only in the prose `description`, so damage rolls, save-for-half, and upcasting are not automated.  
Representative cards: *Ambush*, *Blood Strike*, *Conjure Manabane Swarm*, *Curse of Formlessness*, *Delay Passing*, …

---

## open5e-open5e — Open5e Originals

*Publisher: Open5e · License: ogl-10a · System: 5e-2014*  
Counts: adventuring-gear 8, background 2, spell 2, subclass 17, subspecies 1

### subclass (17)

- **Abjurationist** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Arcane Warrior** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Circle of the Many** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **College of Skalds** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Demise Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Eldritch Trickster** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Mischief Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Oathless Betrayer** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **School of Abjuring and Warding** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **School of Divining and Soothsaying** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **School of Illusions and Phantasms** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **School of Necrotic Arts** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Storm Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **The Ancient Fey Court** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **The Great Elder Thing** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of Shadowdancing** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Wyrd Magic** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.

### subspecies (1)

- **Stoor Halfling** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.

### background (2)

- **Con Artist** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Scoundrel** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.

### spell (2) — audited as a class

Rich metadata is typed (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`). **Missing mechanic:** no damage-dice / effect-amount field and no structured *cast-at-higher-level* (upcast/scaling) field — the spell outcome lives only in the prose `description`, so damage rolls, save-for-half, and upcasting are not automated.  
Representative cards: *Eye bite*, *Ray of Sickness*

### adventuring-gear (8) — audited as a class

Typed cost/weight/consumable/`is_focus` fields. **Data gap:** `is_focus` is uniformly `false` and many cost/weight values are `0`, so spellcasting-focus and encumbrance validation cannot key off the data.  
Representative cards: *Fine Clothes*, *Disguise Kit*, *Tools For Your Typical Con*, *Pouch Containing*, *Bag Of 1000 Ball Bearings*, …

---

## open5e-spells-that-dont-suck — Spells That Don't Suck

*Publisher: SoMany Robots · License: cc-by-40 · System: 5e-2014*  
Counts: spell 180

### spell (180) — audited as a class

Rich metadata is typed (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`). **Missing mechanic:** no damage-dice / effect-amount field and no structured *cast-at-higher-level* (upcast/scaling) field — the spell outcome lives only in the prose `description`, so damage rolls, save-for-half, and upcasting are not automated.  
Representative cards: *Adaptation*, *Alter Weather*, *Animal Ally*, *Animal Transformation*, *Arcane Shelter*, …

---

## open5e-tdcs — Tal'dorei Campaign Setting

*Publisher: Green Ronin · License: ogl-10a · System: 5e-2014*  
Counts: adventuring-gear 13, background 5, creature-action 10, feat 1, monster 4, subclass 4, trait 11

### subclass (4)

- **Blood Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Path of the Juggernaut** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Runechild** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of the Cerulean Spirit** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.

### background (5)

- **Crime Syndicate Member** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Elemental Warden** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Fate-Touched** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Lyceum Student** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Recovered Cultist** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.

### feat (1)

- **Rapid Drinker** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.

### adventuring-gear (13) — audited as a class

Typed cost/weight/consumable/`is_focus` fields. **Data gap:** `is_focus` is uniformly `false` and many cost/weight values are `0`, so spellcasting-focus and encumbrance validation cannot key off the data.  
Representative cards: *Dark Common Clothes Including A Hood*, *Tools To Match Your Choice Of Tool Proficiency*, *Belt Pouch Containing 10g*, *Staff*, *Hunting Gear*, …

### monster (4) — audited as a class

Reference statblock. Defensive/offensive numbers are typed, but mechanical behaviours (multiattack, recharge, save DCs, legendary/lair actions) are prose inside linked `creature-action`/`trait` cards. **No encounter-automation mechanic** — acceptable for a reference card, logged for completeness.  
Representative cards: *Firetamer*, *Skydancer*, *Stoneguard*, *Waverider*

### trait (11) — audited as a class

Reference sub-card of a monster. The trait's rules text is a single prose field; no Effect DSL. Structurally clean as reference content.  
Representative cards: *Flameform*, *Spellcasting*, *Evasion*, *Flyby*, *Skysail*, …

### creature-action (10) — audited as a class

Reference sub-card of a monster (attack/action). Attack rules are prose; no structured attack/damage automation. Structurally clean as reference content.  
Representative cards: *Flamecharm*, *Scimitar*, *Multiattack*, *Skysail Staff*, *Slow Fall*, …

---

## open5e-tob — Tome of Beasts

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: creature-action 1303, monster 391, trait 1039

### monster (391) — audited as a class

Reference statblock. Defensive/offensive numbers are typed, but mechanical behaviours (multiattack, recharge, save DCs, legendary/lair actions) are prose inside linked `creature-action`/`trait` cards. **No encounter-automation mechanic** — acceptable for a reference card, logged for completeness.  
Representative cards: *Aboleth, Nihilith*, *Abominable Beauty*, *Accursed Defiler*, *Adult Cave Dragon*, *Adult Flame Dragon*, …

### trait (1039) — audited as a class

Reference sub-card of a monster. The trait's rules text is a single prose field; no Effect DSL. Structurally clean as reference content.  
Representative cards: *Dual State*, *Infecting Telepathy*, *Nihileth's Lair*, *Regional Effects*, *Undead Fortitude*, …

### creature-action (1303) — audited as a class

Reference sub-card of a monster (attack/action). Attack rules are prose; no structured attack/damage automation. Structurally clean as reference content.  
Representative cards: *Detect*, *Enslave*, *Form Swap*, *Multiattack*, *Psychic Drain*, …

---

## open5e-tob-2023 — Tome of Beasts 1 (2023 Edition)

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: creature-action 1658, monster 408, trait 1021

### monster (408) — audited as a class

Reference statblock. Defensive/offensive numbers are typed, but mechanical behaviours (multiattack, recharge, save DCs, legendary/lair actions) are prose inside linked `creature-action`/`trait` cards. **No encounter-automation mechanic** — acceptable for a reference card, logged for completeness.  
Representative cards: *Abominable Beauty*, *Accursed Defiler*, *Adult Cave Dragon*, *Adult Flame Dragon*, *Adult Mithral Dragon*, …

### trait (1021) — audited as a class

Reference sub-card of a monster. The trait's rules text is a single prose field; no Effect DSL. Structurally clean as reference content.  
Representative cards: *Burning Touch*, *Cursed Existence*, *Sand Shroud*, *Undead Nature*, *Darkness Aura*, …

### creature-action (1658) — audited as a class

Reference sub-card of a monster (attack/action). Attack rules are prose; no structured attack/damage automation. Structurally clean as reference content.  
Representative cards: *Blinding Gaze*, *Deafening Voice*, *Multiattack*, *Slam*, *Multiattack (Accursed Defiler)*, …

---

## open5e-tob2 — Tome of Beasts 2

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: creature-action 1209, monster 383, trait 1014

### monster (383) — audited as a class

Reference statblock. Defensive/offensive numbers are typed, but mechanical behaviours (multiattack, recharge, save DCs, legendary/lair actions) are prose inside linked `creature-action`/`trait` cards. **No encounter-automation mechanic** — acceptable for a reference card, logged for completeness.  
Representative cards: *A-mi-kuk*, *Aalpamac*, *Abbanith Giant*, *Adult Boreal Dragon*, *Adult Imperial Dragon*, …

### trait (1014) — audited as a class

Reference sub-card of a monster. The trait's rules text is a single prose field; no Effect DSL. Structurally clean as reference content.  
Representative cards: *Fear of Fire*, *Hold Breath*, *Icy Slime*, *Amphibious*, *Distance Distortion Aura*, …

### creature-action (1209) — audited as a class

Reference sub-card of a monster (attack/action). Attack rules are prose; no structured attack/damage automation. Structurally clean as reference content.  
Representative cards: *Bite*, *Grasping Claw*, *Multiattack*, *Strangle*, *Bite (Aalpamac)*, …

---

## open5e-tob3 — Tome of Beasts 3

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: creature-action 291, monster 397, trait 812

### monster (397) — audited as a class

Reference statblock. Defensive/offensive numbers are typed, but mechanical behaviours (multiattack, recharge, save DCs, legendary/lair actions) are prose inside linked `creature-action`/`trait` cards. **No encounter-automation mechanic** — acceptable for a reference card, logged for completeness.  
Representative cards: *Abaasy*, *Ahu-Nixta Mechanon*, *Akanka*, *Akkorokamui*, *Alabroza*, …

### trait (812) — audited as a class

Reference sub-card of a monster. The trait's rules text is a single prose field; no Effect DSL. Structurally clean as reference content.  
Representative cards: *Armored Berserker*, *Dual Shields*, *Poor Depth Perception*, *Construct Nature*, *Critical Malfunction*, …

### creature-action (291) — audited as a class

Reference sub-card of a monster (attack/action). Attack rules are prose; no structured attack/damage automation. Structurally clean as reference content.  
Representative cards: *Iron Axe*, *Multiattack*, *Cast a Spell*, *Discern*, *Guardian's Grasp*, …

---

## open5e-toh — Tome of Heroes

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: adventuring-gear 75, background 19, feat 13, species 11, spell 91, subclass 76, subspecies 29

### subclass (76)

- **Ancient Dragons** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Animal Lords** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Beast Trainer** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Cantrip Adept** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Cat Burglar** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Chaplain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Circle of Ash** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Circle of Bees** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Circle of Crystals** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Circle of Sand** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Circle of Wind** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Circle of the Green** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Circle of the Shapeless** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Cold-Blooded** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **College of Echoes** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **College of Investigation** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **College of Shadows** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **College of Sincerity** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **College of Tactics** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **College of the Cat** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Courser Mage** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Dawn Blade** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Familiar Master** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Gravebinding** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Grove Warden** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Haunted Warden** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Hungering** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Hunt Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Hunter in Darkness** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Legionary** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Mercy Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Oath of Justice** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Oath of Safeguarding** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Oath of the Elements** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Oath of the Guardian** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Oath of the Hearth** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Oath of the Plaguetouched** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Old Wood** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Path of Booming Magnificence** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Path of Hellfire** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Path of Mistwood** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Path of Thorns** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Path of the Dragon** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Path of the Herald** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Path of the Inner Eye** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Portal Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Primordial** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Pugilist** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Radiant Pikeman** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Resonant Body** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Rifthopper** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Sapper** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **School of Liminality** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Serpent Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Shadow Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Smuggler** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Snake Speaker** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Soulspy** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Spear of the Weald** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Spellsmith** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Spore Sorcery** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Timeblade** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Tunnel Watcher** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Underfoot** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Vermin Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Wasteland Strider** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Wastelander** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of Concordant Motion** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of the Dragon** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of the Humble Elephant** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of the Still Waters** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of the Tipsy Monkey** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of the Unerring Arrow** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Way of the Wildcat** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Wind Domain** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.
- **Wyrdweaver** — All mechanics dumped in one `description` field; only `parent_class_ref` is typed. Leveled features carry no `granted_at_level`, so the resolver applies every feature at level 1.

### species (11)

- **Alseid** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Catfolk** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Darakhul** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Derro** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Drow** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Erina** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Gearforged** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Minotaur** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Mushroomfolk** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Satarre** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Shade** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.

### subspecies (29)

- **Acid Cap** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Bhain Kwai** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Boghaid** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Delver** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Derro Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Dragonborn Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Drow Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Dwarf Chassis** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Dwarf Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Elf/Shadow Fey Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Far-Touched** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Favored** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Fever-Bit** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Gnome Chassis** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Gnome Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Halfling Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Human Chassis** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Human/Half-Elf Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Kobold Chassis** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Kobold Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Malkin** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Morel** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Mutated** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Pantheran** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Purified** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Ravenfolk** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Tiefling Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Trollkin Heritage** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.
- **Uncorrupted** — Size/speed/senses/ASI partly typed where source traits exist; remaining traits (and any active racial mechanics) stay as folded prose with no Effect DSL.

### background (19)

- **Court Servant** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Desert Runner** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Destined** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Diplomat** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Forest Dweller** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Former Adventurer** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Freebooter** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Gamekeeper** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Innkeeper** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Mercenary Company Scion** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Mercenary Recruit** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Monstrous Adoptee** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Mysterious Origins** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Northern Minstrel** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Occultist** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Parfumier** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Scoundrel** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Sentry** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.
- **Trophy Hunter** — `ability_score_options` empty — ASI grant not typed. `asi_distribution_options` empty — the +2/+1 vs +1/+1/+1 distribution rule is not enforced. Adventures/equipment/gold/feature text remains in the prose `description`.

### feat (13)

- **Boundless Reserves** — Prerequisite parsed to structured field(s) and enforced ("*Wisdom 13 or higher and the Ki class feature*"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Diehard** — Prerequisite parsed to structured field(s) and enforced ("*Constitution 13 or higher*"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Floriographer** — Prerequisite is narrative text only ("*Proficiency in one of the following skills: Arcana, History, or Nature*") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Forest Denizen** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Friend of the Forest** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Giant Foe** — Prerequisite is narrative text only ("*A Small or smaller race*") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Harrier** — Prerequisite is narrative text only ("*The Shadow Traveler shadow fey trait or the ability to cast the* misty step *spell*") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Inner Resilience** — Prerequisite parsed to structured field(s) and enforced ("*Wisdom 13 or higher*"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Part of the Pack** — Prerequisite is narrative text only ("*Proficiency in the Animal Handling skill*") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Rimecaster** — Prerequisite is narrative text only ("*A race or background from a cold climate and the ability to cast at least one spell*") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Sorcerous Vigor** — Prerequisite parsed to structured field(s) and enforced ("*Charisma 13 or higher and the Sorcery Points class feature*"). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Stalker** — Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.
- **Stunning Sniper** — Prerequisite is narrative text only ("*Proficiency with a ranged weapon*") → **not enforced** at selection (no `prereq_*` structured field). Benefits in prose only — no Effect DSL entries, so the feat's mechanics are not applied to the sheet.

### spell (91) — audited as a class

Rich metadata is typed (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`). **Missing mechanic:** no damage-dice / effect-amount field and no structured *cast-at-higher-level* (upcast/scaling) field — the spell outcome lives only in the prose `description`, so damage rolls, save-for-half, and upcasting are not automated.  
Representative cards: *Ambush Chute*, *Armored Formation*, *Babble*, *Battle Mind*, *Beast Within*, …

### adventuring-gear (75) — audited as a class

Typed cost/weight/consumable/`is_focus` fields. **Data gap:** `is_focus` is uniformly `false` and many cost/weight values are `0`, so spellcasting-focus and encumbrance validation cannot key off the data.  
Representative cards: *Artisan's Tools*, *Unique Piece Of Jewelry*, *Fine Clothes*, *Handcrafted Pipe*, *Belt Pouch*, …

---

## open5e-vom — Vault of Magic

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: magic-item 1063

### magic-item (1063) — audited as a class

**Poor data structure + unimplemented prerequisite:** the entire item ruleset is dumped into one free-text `effects` field; `requires_attunement` is a bare boolean and the *conditional* attunement clause ("by a spellcaster", "by a creature of good alignment") is absent from source, leaving the `attunement_prereq` schema field empty. No structured item bonuses (AC/attack/save) → no automation, no attunement-condition enforcement.  
Representative cards: *Aberrant Agreement*, *Accursed Idol*, *Adamantine Spearbiter*, *Agile Breastplate*, *Agile Chain Mail*, …

---

## open5e-wz — Warlock Zine

*Publisher: Kobold Press · License: ogl-10a · System: 5e-2014*  
Counts: spell 43

### spell (43) — audited as a class

Rich metadata is typed (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`). **Missing mechanic:** no damage-dice / effect-amount field and no structured *cast-at-higher-level* (upcast/scaling) field — the spell outcome lives only in the prose `description`, so damage rolls, save-for-half, and upcasting are not automated.  
Representative cards: *Abrupt Hug*, *Avert Evil Eye*, *Bardo*, *Battle Chant*, *Bombardment of Stings*, …

---
