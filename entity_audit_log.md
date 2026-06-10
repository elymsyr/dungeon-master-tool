# Entity Audit Log — Official & Built-in Packages

> Automated System Architecture Inspector — per-entity ledger for the
> `dungeon-master-tool` D&D 5e content packages. Companion roadmap:
> [`system_mechanics_roadmap.md`](system_mechanics_roadmap.md). Branch: `list`.
> Generated 2026-06-10.

## Scope & method

Two sources of official / built-in content were inspected:

1. **Official first-party catalog — Open5e packs** (machine-imported JSON
   assets): `flutter_app/assets/open5e_packs/*.pkg.json`, declared in
   `manifest.json` and `flutter_app/assets/first_party/manifest.json`.
   **19 packs · 20,712 entity cards.** Every card was parsed from JSON and its
   `attributes` map compared field-by-field against the typed schema
   (`flutter_app/lib/domain/entities/schema/builtin/content.dart`) and the
   mechanics the runtime actually consumes
   (`flutter_app/lib/domain/services/character_resolver.dart`,
   `flutter_app/lib/presentation/screens/characters/pending_choice_resolver_dialog.dart`).
2. **Built-in pack — SRD 5.2.1 core** (hand-authored Dart):
   `flutter_app/lib/domain/entities/schema/builtin/srd_core/`. **~2,260 cards**
   emitted by typed Dart builders. Audited at the per-builder / per-category
   level because deficiencies are uniform within a builder.

Chargen entities (feats / backgrounds / classes / subclasses / species /
subspecies — 270 official cards) are **enumerated individually** below, because
the three inspection criteria vary card-to-card there. Bulk content (spells,
magic items, gear, traits, creature-actions, monsters — 20,442 official cards)
is **machine-uniform within each pack×category**, so it is audited at that
granularity with exact counts and representative named rows.

### Verdict legend
- **Clean** — every described prerequisite sits in a typed, enforced field;
  every described mechanic has a matching typed `effects`/attribute the runtime
  reads; nothing material is stranded in a generic text field.
- **Unimplemented Prerequisite** — the card states a requirement that no
  typed/enforced field carries, OR the field exists but is never validated at
  apply-time (so the gate never fires).
- **Missing Mechanic** — a functional rule in the card's text has no
  corresponding typed mechanic the runtime applies.
- **Poor Data Structure** — content is dumped into a single generic text field
  instead of being split into dedicated typed fields.

### Headline tallies (official packs)
- **Feats (73):** 9 fully structured (prereq + `effects`); **64 carry their
  benefits as `description` text only** (Missing Mechanic); **5 have a
  prerequisite in free-text only** with no structured field; the remaining
  structured-prereq feats are **filtered in the UI picker but never validated at
  apply-time** (Unimplemented Prerequisite).
- **Backgrounds (53):** **24 set `granted_language_count` that the resolver
  never consumes** (Missing Mechanic); no card has a structured "background
  feature" field — feature text lives in `description`.
- **Subclasses (101):** **101/101 dump every feature into a single
  `description` field** (Poor Data Structure + Missing Mechanic) — none use the
  schema's structured `features` / `rule_effects` / grant rows.
- **Classes (2):** proficiencies/hit-die/caster typed; **no structured per-level
  feature list** — class features in `description`.
- **Species (11) / Subspecies (30):** mostly Clean — grants are typed and the
  resolver applies them; 5 cards leave traits in `description`.
- **Spells (1,297):** casting metadata typed; **spell `effects` empty for all
  1,297** — damage/scaling/riders are descriptive text the runtime never
  resolves (Missing Mechanic, system-wide).
- **Magic items (1,063), gear (159), creature-actions (8,615), monsters
  (2,885):** structurally Clean. **Traits (6,423)** are descriptive-by-design.

---

# Part A — Official first-party catalog (Open5e packs)

## A.1 Feats (73 cards)
#### Adventurer's Guide (`open5e-a5e-ag`) — 59 feats
- **Ace Driver**: prerequisite “Proficiency with a type of vehicle” in free-text only (no structured prereq_* field; not enforced); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Athletic**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Attentive**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Battle Caster**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Brutal Attack**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Bull Rush**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Combat Thievery**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Covert Training**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Crafting Expert**: Clean (structured prereq + effects)
- **Crossbow Expertise**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Deadeye**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Deflector**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Destiny’s Call**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Dual-Wielding Expert**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Dungeoneer**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Empathic**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Fear Breaker**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Fortunate**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Guarded Warrior**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Hardy Adventurer**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Heavily Outfitted**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only)
- **Heavy Armor Expertise**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Heraldic Training**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Idealistic Leader**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Intuitive**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Keen Intellect**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Lightly Outfitted**: Clean (structured prereq + effects)
- **Linguistics Expert**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Martial Scholar**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Medium Armor Expert**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Moderately Outfitted**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only)
- **Monster Hunter**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Mounted Warrior**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Mystical Talent**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Natural Warrior**: Clean (structured prereq + effects)
- **Physician**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Polearm Savant**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Power Caster**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Powerful Attacker**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Primordial Caster**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Rallying Speaker**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Resonant Bond**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Rite Master**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Shield Focus**: Clean (structured prereq + effects)
- **Skillful**: Clean (structured prereq + effects)
- **Skirmisher**: Clean (structured prereq + effects)
- **Spellbreaker**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Stalwart**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Stealth Expert**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Street Fighter**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Surgical Combatant**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Survivor**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Swift Combatant**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only)
- **Tactical Support**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Tenacious**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Thespian**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Weapons Specialist**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Well-Heeled**: prerequisite “Prestige rating of 2 or higher” in free-text only (no structured prereq_* field; not enforced); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Woodcraft Training**: benefits described in `description` text only — no `effects` rows (mechanics not applied)

#### Tal'dorei Campaign Setting (`open5e-tdcs`) — 1 feats
- **Rapid Drinker**: benefits described in `description` text only — no `effects` rows (mechanics not applied)

#### Tome of Heroes (`open5e-toh`) — 13 feats
- **Boundless Reserves**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Diehard**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Floriographer**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Forest Denizen**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Friend of the Forest**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Giant Foe**: prerequisite “*A Small or smaller race*” in free-text only (no structured prereq_* field; not enforced); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Harrier**: prerequisite “*The Shadow Traveler shadow fey trait or the ability to cast the* misty step *spell*” in free-text only (no structured prereq_* field; not enforced); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Inner Resilience**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Part of the Pack**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Rimecaster**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Sorcerous Vigor**: prereq stored in structured field but **not enforced at apply-time** (UI-picker filter only); benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Stalker**: benefits described in `description` text only — no `effects` rows (mechanics not applied)
- **Stunning Sniper**: prerequisite “*Proficiency with a ranged weapon*” in free-text only (no structured prereq_* field; not enforced); benefits described in `description` text only — no `effects` rows (mechanics not applied)

## A.2 Backgrounds · Subclasses · Classes · Species · Subspecies (197 cards)
### Backgrounds

#### Adventurer's Guide (`open5e-a5e-ag`) — 21 background
- **Acolyte**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Artisan**: background feature text (if any) lives in `description`; no structured `feature` field
- **Charlatan**: background feature text (if any) lives in `description`; no structured `feature` field
- **Criminal**: background feature text (if any) lives in `description`; no structured `feature` field
- **Cultist**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Entertainer**: background feature text (if any) lives in `description`; no structured `feature` field
- **Exile**: background feature text (if any) lives in `description`; no structured `feature` field
- **Farmer**: background feature text (if any) lives in `description`; no structured `feature` field
- **Folk Hero**: background feature text (if any) lives in `description`; no structured `feature` field
- **Gambler**: background feature text (if any) lives in `description`; no structured `feature` field
- **Guard**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Guildmember**: background feature text (if any) lives in `description`; no structured `feature` field
- **Hermit**: background feature text (if any) lives in `description`; no structured `feature` field
- **Marauder**: background feature text (if any) lives in `description`; no structured `feature` field
- **Noble**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Outlander**: background feature text (if any) lives in `description`; no structured `feature` field
- **Sage**: background feature text (if any) lives in `description`; no structured `feature` field
- **Sailor**: background feature text (if any) lives in `description`; no structured `feature` field
- **Soldier**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Trader**: background feature text (if any) lives in `description`; no structured `feature` field
- **Urchin**: background feature text (if any) lives in `description`; no structured `feature` field

#### Dungeon Delver’s Guide (`open5e-a5e-ddg`) — 4 background
- **Deep Hunter**: background feature text (if any) lives in `description`; no structured `feature` field
- **Dungeon Robber**: background feature text (if any) lives in `description`; no structured `feature` field
- **Escapee from Below**: background feature text (if any) lives in `description`; no structured `feature` field
- **Imposter**: background feature text (if any) lives in `description`; no structured `feature` field

#### Gate Pass Gazette (`open5e-a5e-gpg`) — 2 background
- **Cursed**: `granted_language_count=2` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Haunted**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field

#### Open5e Originals (`open5e-open5e`) — 2 background
- **Con Artist**: background feature text (if any) lives in `description`; no structured `feature` field
- **Scoundrel**: background feature text (if any) lives in `description`; no structured `feature` field

#### Tal'dorei Campaign Setting (`open5e-tdcs`) — 5 background
- **Crime Syndicate Member**: background feature text (if any) lives in `description`; no structured `feature` field
- **Elemental Warden**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Fate-Touched**: background feature text (if any) lives in `description`; no structured `feature` field
- **Lyceum Student**: `granted_language_count=2` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Recovered Cultist**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field

#### Tome of Heroes (`open5e-toh`) — 19 background
- **Court Servant**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Desert Runner**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Destined**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Diplomat**: `granted_language_count=2` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Forest Dweller**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Former Adventurer**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Freebooter**: background feature text (if any) lives in `description`; no structured `feature` field
- **Gamekeeper**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Innkeeper**: `granted_language_count=2` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Mercenary Company Scion**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Mercenary Recruit**: background feature text (if any) lives in `description`; no structured `feature` field
- **Monstrous Adoptee**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Mysterious Origins**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Northern Minstrel**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Occultist**: `granted_language_count=2` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Parfumier**: background feature text (if any) lives in `description`; no structured `feature` field
- **Scoundrel**: background feature text (if any) lives in `description`; no structured `feature` field
- **Sentry**: `granted_language_count=1` authored but **never consumed by resolver** (no language slots granted); background feature text (if any) lives in `description`; no structured `feature` field
- **Trophy Hunter**: background feature text (if any) lives in `description`; no structured `feature` field

### Subclasses

#### Adventurer's Guide (`open5e-a5e-ag`) — 3 subclass
- **Gambling General**: ALL subclass mechanics dumped in one `description` field (3165 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Swift Strategist**: ALL subclass mechanics dumped in one `description` field (2745 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Talented Tactician**: ALL subclass mechanics dumped in one `description` field (3549 chars); no structured `features`/`rule_effects`/grants → no per-level features applied

#### Black Flag SRD (`open5e-bfrd`) — 1 subclass
- **Metallurgist**: ALL subclass mechanics dumped in one `description` field (4589 chars); no structured `features`/`rule_effects`/grants → no per-level features applied

#### Open5e Originals (`open5e-open5e`) — 17 subclass
- **Abjurationist**: ALL subclass mechanics dumped in one `description` field (3482 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Arcane Warrior**: ALL subclass mechanics dumped in one `description` field (7206 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Circle of the Many**: ALL subclass mechanics dumped in one `description` field (2993 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **College of Skalds**: ALL subclass mechanics dumped in one `description` field (1812 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Demise Domain**: ALL subclass mechanics dumped in one `description` field (3200 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Eldritch Trickster**: ALL subclass mechanics dumped in one `description` field (7856 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Mischief Domain**: ALL subclass mechanics dumped in one `description` field (3869 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Oathless Betrayer**: ALL subclass mechanics dumped in one `description` field (4272 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **School of Abjuring and Warding**: ALL subclass mechanics dumped in one `description` field (2731 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **School of Divining and Soothsaying**: ALL subclass mechanics dumped in one `description` field (3069 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **School of Illusions and Phantasms**: ALL subclass mechanics dumped in one `description` field (2729 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **School of Necrotic Arts**: ALL subclass mechanics dumped in one `description` field (3078 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Storm Domain**: ALL subclass mechanics dumped in one `description` field (3011 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **The Ancient Fey Court**: ALL subclass mechanics dumped in one `description` field (3449 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **The Great Elder Thing**: ALL subclass mechanics dumped in one `description` field (3041 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of Shadowdancing**: ALL subclass mechanics dumped in one `description` field (1946 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Wyrd Magic**: ALL subclass mechanics dumped in one `description` field (9322 chars); no structured `features`/`rule_effects`/grants → no per-level features applied

#### Tal'dorei Campaign Setting (`open5e-tdcs`) — 4 subclass
- **Blood Domain**: ALL subclass mechanics dumped in one `description` field (5313 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Path of the Juggernaut**: ALL subclass mechanics dumped in one `description` field (2203 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Runechild**: ALL subclass mechanics dumped in one `description` field (4886 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of the Cerulean Spirit**: ALL subclass mechanics dumped in one `description` field (4391 chars); no structured `features`/`rule_effects`/grants → no per-level features applied

#### Tome of Heroes (`open5e-toh`) — 76 subclass
- **Ancient Dragons**: ALL subclass mechanics dumped in one `description` field (7120 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Animal Lords**: ALL subclass mechanics dumped in one `description` field (7512 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Beast Trainer**: ALL subclass mechanics dumped in one `description` field (3478 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Cantrip Adept**: ALL subclass mechanics dumped in one `description` field (1903 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Cat Burglar**: ALL subclass mechanics dumped in one `description` field (4303 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Chaplain**: ALL subclass mechanics dumped in one `description` field (3414 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Circle of Ash**: ALL subclass mechanics dumped in one `description` field (5695 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Circle of Bees**: ALL subclass mechanics dumped in one `description` field (5043 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Circle of Crystals**: ALL subclass mechanics dumped in one `description` field (4503 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Circle of Sand**: ALL subclass mechanics dumped in one `description` field (5974 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Circle of Wind**: ALL subclass mechanics dumped in one `description` field (3038 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Circle of the Green**: ALL subclass mechanics dumped in one `description` field (5588 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Circle of the Shapeless**: ALL subclass mechanics dumped in one `description` field (4924 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Cold-Blooded**: ALL subclass mechanics dumped in one `description` field (3713 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **College of Echoes**: ALL subclass mechanics dumped in one `description` field (4292 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **College of Investigation**: ALL subclass mechanics dumped in one `description` field (3020 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **College of Shadows**: ALL subclass mechanics dumped in one `description` field (3478 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **College of Sincerity**: ALL subclass mechanics dumped in one `description` field (3798 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **College of Tactics**: ALL subclass mechanics dumped in one `description` field (3631 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **College of the Cat**: ALL subclass mechanics dumped in one `description` field (2023 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Courser Mage**: ALL subclass mechanics dumped in one `description` field (1812 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Dawn Blade**: ALL subclass mechanics dumped in one `description` field (2600 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Familiar Master**: ALL subclass mechanics dumped in one `description` field (4726 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Gravebinding**: ALL subclass mechanics dumped in one `description` field (3866 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Grove Warden**: ALL subclass mechanics dumped in one `description` field (3498 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Haunted Warden**: ALL subclass mechanics dumped in one `description` field (4924 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Hungering**: ALL subclass mechanics dumped in one `description` field (1639 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Hunt Domain**: ALL subclass mechanics dumped in one `description` field (3033 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Hunter in Darkness**: ALL subclass mechanics dumped in one `description` field (3903 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Legionary**: ALL subclass mechanics dumped in one `description` field (2623 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Mercy Domain**: ALL subclass mechanics dumped in one `description` field (3503 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Oath of Justice**: ALL subclass mechanics dumped in one `description` field (4903 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Oath of Safeguarding**: ALL subclass mechanics dumped in one `description` field (6492 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Oath of the Elements**: ALL subclass mechanics dumped in one `description` field (6286 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Oath of the Guardian**: ALL subclass mechanics dumped in one `description` field (4224 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Oath of the Hearth**: ALL subclass mechanics dumped in one `description` field (6066 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Oath of the Plaguetouched**: ALL subclass mechanics dumped in one `description` field (4861 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Old Wood**: ALL subclass mechanics dumped in one `description` field (5310 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Path of Booming Magnificence**: ALL subclass mechanics dumped in one `description` field (2966 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Path of Hellfire**: ALL subclass mechanics dumped in one `description` field (548 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Path of Mistwood**: ALL subclass mechanics dumped in one `description` field (2219 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Path of Thorns**: ALL subclass mechanics dumped in one `description` field (3519 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Path of the Dragon**: ALL subclass mechanics dumped in one `description` field (3466 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Path of the Herald**: ALL subclass mechanics dumped in one `description` field (2475 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Path of the Inner Eye**: ALL subclass mechanics dumped in one `description` field (2011 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Portal Domain**: ALL subclass mechanics dumped in one `description` field (5206 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Primordial**: ALL subclass mechanics dumped in one `description` field (4650 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Pugilist**: ALL subclass mechanics dumped in one `description` field (3505 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Radiant Pikeman**: ALL subclass mechanics dumped in one `description` field (1960 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Resonant Body**: ALL subclass mechanics dumped in one `description` field (4696 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Rifthopper**: ALL subclass mechanics dumped in one `description` field (4844 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Sapper**: ALL subclass mechanics dumped in one `description` field (5137 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **School of Liminality**: ALL subclass mechanics dumped in one `description` field (4758 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Serpent Domain**: ALL subclass mechanics dumped in one `description` field (2904 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Shadow Domain**: ALL subclass mechanics dumped in one `description` field (2722 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Smuggler**: ALL subclass mechanics dumped in one `description` field (4613 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Snake Speaker**: ALL subclass mechanics dumped in one `description` field (4618 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Soulspy**: ALL subclass mechanics dumped in one `description` field (7244 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Spear of the Weald**: ALL subclass mechanics dumped in one `description` field (3585 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Spellsmith**: ALL subclass mechanics dumped in one `description` field (4675 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Spore Sorcery**: ALL subclass mechanics dumped in one `description` field (4517 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Timeblade**: ALL subclass mechanics dumped in one `description` field (3245 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Tunnel Watcher**: ALL subclass mechanics dumped in one `description` field (3392 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Underfoot**: ALL subclass mechanics dumped in one `description` field (5398 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Vermin Domain**: ALL subclass mechanics dumped in one `description` field (2846 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Wasteland Strider**: ALL subclass mechanics dumped in one `description` field (3574 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Wastelander**: ALL subclass mechanics dumped in one `description` field (5209 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of Concordant Motion**: ALL subclass mechanics dumped in one `description` field (3098 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of the Dragon**: ALL subclass mechanics dumped in one `description` field (2789 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of the Humble Elephant**: ALL subclass mechanics dumped in one `description` field (2099 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of the Still Waters**: ALL subclass mechanics dumped in one `description` field (2409 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of the Tipsy Monkey**: ALL subclass mechanics dumped in one `description` field (2814 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of the Unerring Arrow**: ALL subclass mechanics dumped in one `description` field (3664 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Way of the Wildcat**: ALL subclass mechanics dumped in one `description` field (3052 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Wind Domain**: ALL subclass mechanics dumped in one `description` field (2969 chars); no structured `features`/`rule_effects`/grants → no per-level features applied
- **Wyrdweaver**: ALL subclass mechanics dumped in one `description` field (4304 chars); no structured `features`/`rule_effects`/grants → no per-level features applied

### Classes

#### Adventurer's Guide (`open5e-a5e-ag`) — 1 class
- **Marshal**: proficiencies/hit-die/caster structured; NO structured per-level `features` list — class features in `description` only

#### Black Flag SRD (`open5e-bfrd`) — 1 class
- **Mechanist**: proficiencies/hit-die/caster structured; NO structured per-level `features` list — class features in `description` only

### Species

#### Tome of Heroes (`open5e-toh`) — 11 species
- **Alseid**: structured grants applied (granted_modifiers, granted_senses, speed_ft, granted_languages, granted_skill_proficiencies); residual lore in `description` — Clean (mechanics typed)
- **Catfolk**: structured grants applied (granted_modifiers, granted_senses, speed_ft, granted_languages, granted_skill_proficiencies); residual lore in `description` — Clean (mechanics typed)
- **Darakhul**: structured grants applied (granted_modifiers, granted_senses, granted_languages, granted_damage_resistances); residual lore in `description` — Clean (mechanics typed)
- **Derro**: structured grants applied (granted_modifiers, speed_ft, granted_languages); residual lore in `description` — Clean (mechanics typed)
- **Drow**: structured grants applied (granted_modifiers, speed_ft, granted_languages); residual lore in `description` — Clean (mechanics typed)
- **Erina**: structured grants applied (granted_modifiers, granted_senses, speed_ft, granted_languages, granted_skill_proficiencies); residual lore in `description` — Clean (mechanics typed)
- **Gearforged**: structured grants applied (granted_languages, granted_damage_resistances); residual lore in `description` — Clean (mechanics typed)
- **Minotaur**: structured grants applied (granted_modifiers, granted_senses, speed_ft, granted_languages); residual lore in `description` — Clean (mechanics typed)
- **Mushroomfolk**: structured grants applied (granted_modifiers, granted_senses, speed_ft, granted_languages, granted_skill_proficiencies, granted_damage_resistances); residual lore in `description` — Clean (mechanics typed)
- **Satarre**: structured grants applied (granted_modifiers, granted_senses, speed_ft, granted_languages, granted_skill_proficiencies, granted_damage_resistances); residual lore in `description` — Clean (mechanics typed)
- **Shade**: only `description` + `creature_type_ref` — traits not structured

### Subspecies

#### Open5e Originals (`open5e-open5e`) — 1 subspecies
- **Stoor Halfling**: structured grants applied (granted_modifiers, granted_damage_resistances); residual lore in `description` — Clean (mechanics typed)

#### Tome of Heroes (`open5e-toh`) — 29 subspecies
- **Acid Cap**: structured grants applied (granted_modifiers, speed_ft, granted_skill_proficiencies, granted_damage_resistances); residual lore in `description` — Clean (mechanics typed)
- **Bhain Kwai**: structured grants applied (granted_modifiers, speed_ft); residual lore in `description` — Clean (mechanics typed)
- **Boghaid**: structured grants applied (granted_modifiers, speed_ft, granted_skill_proficiencies); residual lore in `description` — Clean (mechanics typed)
- **Delver**: structured grants applied (granted_modifiers, speed_ft); residual lore in `description` — Clean (mechanics typed)
- **Derro Heritage**: structured grants applied (granted_modifiers, granted_cantrip_refs); residual lore in `description` — Clean (mechanics typed)
- **Dragonborn Heritage**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Drow Heritage**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Dwarf Chassis**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Dwarf Heritage**: only `description` + `creature_type_ref, parent_species_ref` — traits not structured
- **Elf/Shadow Fey Heritage**: structured grants applied (granted_modifiers, granted_skill_proficiencies); residual lore in `description` — Clean (mechanics typed)
- **Far-Touched**: structured grants applied (granted_modifiers, speed_ft, granted_spell_refs, granted_cantrip_refs); residual lore in `description` — Clean (mechanics typed)
- **Favored**: structured grants applied (granted_modifiers, speed_ft, granted_skill_proficiencies, granted_spell_refs, granted_cantrip_refs); residual lore in `description` — Clean (mechanics typed)
- **Fever-Bit**: structured grants applied (granted_modifiers, speed_ft, granted_damage_resistances); residual lore in `description` — Clean (mechanics typed)
- **Gnome Chassis**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Gnome Heritage**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Halfling Heritage**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Human Chassis**: only `description` + `creature_type_ref, parent_species_ref` — traits not structured
- **Human/Half-Elf Heritage**: only `description` + `creature_type_ref, parent_species_ref` — traits not structured
- **Kobold Chassis**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Kobold Heritage**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Malkin**: structured grants applied (granted_modifiers, speed_ft, granted_skill_proficiencies); residual lore in `description` — Clean (mechanics typed)
- **Morel**: structured grants applied (granted_modifiers, speed_ft, granted_skill_proficiencies); residual lore in `description` — Clean (mechanics typed)
- **Mutated**: structured grants applied (granted_modifiers, speed_ft, granted_skill_proficiencies); residual lore in `description` — Clean (mechanics typed)
- **Pantheran**: structured grants applied (granted_modifiers, speed_ft); residual lore in `description` — Clean (mechanics typed)
- **Purified**: structured grants applied (granted_modifiers, speed_ft, granted_spell_refs, granted_cantrip_refs); residual lore in `description` — Clean (mechanics typed)
- **Ravenfolk**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Tiefling Heritage**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Trollkin Heritage**: structured grants applied (granted_modifiers); residual lore in `description` — Clean (mechanics typed)
- **Uncorrupted**: structured grants applied (granted_modifiers, speed_ft, granted_skill_proficiencies, granted_damage_resistances); residual lore in `description` — Clean (mechanics typed)

## A.6 Bulk content (audited per pack × category — 20,442 cards)

Within each category every card shares the same typed shape, so the verdict is
uniform; exact per-pack counts and representative cards are listed.
### spell entities

*Verdict (uniform within category): all casting metadata typed (level/school/range/components/save/concentration); **spell `effects` field empty for 0/1297 → damage, scaling & rider effects live in `description` only; resolver never applies spell mechanics** (Missing Mechanic, system-wide)*

| Pack | Count | Representative cards |
|---|---:|---|
| Adventurer's Guide | 371 | Accelerando, Acid Arrow, Acid Splash, Aid |
| Deep Magic for 5th Edition | 515 | Abhorrent Apparition, Accelerate, Acid Gate, Acid Rain |
| Deep Magic Extended | 64 | Absolute Command, Amplify Ley Field, Animate Construct, Anomalous Object |
| Kobold Press Compilation | 31 | Ambush, Blood Strike, Conjure Manabane Swarm, Curse of Formlessness |
| Open5e Originals | 2 | Eye bite, Ray of Sickness |
| Spells That Don't Suck | 180 | Adaptation, Alter Weather, Animal Ally, Animal Transformation |
| Tome of Heroes | 91 | Ambush Chute, Armored Formation, Babble, Battle Mind |
| Warlock Zine | 43 | Abrupt Hug, Avert Evil Eye, Bardo, Battle Chant |
| **Total** | **1297** | |

### magic-item entities

*Verdict (uniform within category): fully typed — `rarity_ref`, `requires_attunement`, `is_cursed`, `is_sentient`, `activation`, structured `effects` populated for 1063/1063. Attunement *prerequisites* (e.g. “requires attunement by a wizard”) are not modelled as an enforced gate. **Clean (structured), minor: attunement-prereq not enforced***

| Pack | Count | Representative cards |
|---|---:|---|
| Vault of Magic | 1063 | Aberrant Agreement, Accursed Idol, Adamantine Spearbiter, Agile Breastplate |
| **Total** | **1063** | |

### adventuring-gear entities

*Verdict (uniform within category): typed `cost_cp`/`weight_lb`/`consumable`/`is_focus`. **Clean***

| Pack | Count | Representative cards |
|---|---:|---|
| Adventurer's Guide | 44 | Holy Symbol, Common Clothes, Robe, Prayer Book |
| Dungeon Delver’s Guide | 9 | Chalk, Traveler's Clothes, Hunting Traps, Cartographers' Tools |
| Gate Pass Gazette | 10 | Days Of Rations, Person Tent, Traveler's Clothes, Days Worth Of Rations |
| Open5e Originals | 8 | Fine Clothes, Disguise Kit, Tools For Your Typical Con, Pouch Containing |
| Tal'dorei Campaign Setting | 13 | Dark Common Clothes Including A Hood, Tools To Match Your Choice Of Tool Proficiency, Belt Pouch Containing 10g, Staff |
| Tome of Heroes | 75 | Artisan's Tools, Unique Piece Of Jewelry, Fine Clothes, Handcrafted Pipe |
| **Total** | **159** | |

### trait entities

*Verdict (uniform within category): `trait_kind` + `description` only; no `effects` rows — monster/creature trait mechanics are descriptive text (acceptable for stat-block display, no character-side hook). **Descriptive-by-design***

| Pack | Count | Representative cards |
|---|---:|---|
| Monstrous Menagerie | 829 | Amphibious, Innate Spellcasting, Sea Changed, Camouflage |
| Black Flag SRD | 776 | Aberrant Resilience, Amphibious, Legendary Resistance (3/Day), Probing Telepathy |
| Creature Codex | 921 | Charge, Know Thoughts, Magic Resistance, Shapechanger |
| Tal'dorei Campaign Setting | 11 | Flameform, Spellcasting, Evasion, Flyby |
| Tome of Beasts | 1039 | Dual State, Infecting Telepathy, Nihileth's Lair, Regional Effects |
| Tome of Beasts 1 (2023 Edition) | 1021 | Burning Touch, Cursed Existence, Sand Shroud, Undead Nature |
| Tome of Beasts 2 | 1014 | Fear of Fire, Hold Breath, Icy Slime, Amphibious |
| Tome of Beasts 3 | 812 | Armored Berserker, Dual Shields, Poor Depth Perception, Construct Nature |
| **Total** | **6423** | |

### creature-action entities

*Verdict (uniform within category): typed attack math (`attack_bonus`/`attack_kind`/`damage_dice`/`reach_ft`/`range_*`/`recharge_*`/`uses_per_day`); rider effects within text. **Clean (combat fields typed)***

| Pack | Count | Representative cards |
|---|---:|---|
| Monstrous Menagerie | 1657 | Baleful Charm, Move, Multiattack, Slimy Cloud |
| Black Flag SRD | 1339 | Detect, Multiattack, Psychic Bolt, Psychic Torrent |
| Creature Codex | 1148 | Bulwark, Detect, Gore, Gore (Aatxe) |
| Tal'dorei Campaign Setting | 10 | Flamecharm, Scimitar, Multiattack, Skysail Staff |
| Tome of Beasts | 1303 | Detect, Enslave, Form Swap, Multiattack |
| Tome of Beasts 1 (2023 Edition) | 1658 | Blinding Gaze, Deafening Voice, Multiattack, Slam |
| Tome of Beasts 2 | 1209 | Bite, Grasping Claw, Multiattack, Strangle |
| Tome of Beasts 3 | 291 | Iron Axe, Multiattack, Cast a Spell, Discern |
| **Total** | **8615** | |

### monster entities

*Verdict (uniform within category): fully typed stat block (`ac`/`hp_*`/`speed_*`/`cr`/`xp`/`proficiency_bonus`/`stat_block`). **Clean***

| Pack | Count | Representative cards |
|---|---:|---|
| Monstrous Menagerie | 586 | Aboleth, Aboleth Thrall, Abominable Snowman, Accursed Guardian Naga |
| Black Flag SRD | 360 | Aboleth, Acolyte, Adult Black Dragon, Adult Blue Dragon |
| Creature Codex | 356 | Aatxe, Acid Ant, Adult Light Dragon, Adult Wasteland Dragon |
| Tal'dorei Campaign Setting | 4 | Firetamer, Skydancer, Stoneguard, Waverider |
| Tome of Beasts | 391 | Aboleth, Nihilith, Abominable Beauty, Accursed Defiler, Adult Cave Dragon |
| Tome of Beasts 1 (2023 Edition) | 408 | Abominable Beauty, Accursed Defiler, Adult Cave Dragon, Adult Flame Dragon |
| Tome of Beasts 2 | 383 | A-mi-kuk, Aalpamac, Abbanith Giant, Adult Boreal Dragon |
| Tome of Beasts 3 | 397 | Abaasy, Ahu-Nixta Mechanon, Akanka, Akkorokamui |
| **Total** | **2885** | |

---

# Part B — Built-in SRD 5.2.1 core (~2,260 hand-authored cards)

Emitted by typed Dart builders in
`flutter_app/lib/domain/entities/schema/builtin/srd_core/`. Unlike the imported
Open5e packs, these builders **do** use the structured grant DSL, so the SRD
core is the reference for what the schema supports.

| Builder | Cards (approx.) | Verdict |
|---|---:|---|
| `subclasses.dart` | 12 | **Clean** — uses structured `features` rows with `granted_action_refs` / `granted_trait_refs` / `granted_feat_refs` / `granted_reaction_refs`, plus `granted_at_level` and `bonus_skill_pick_count`. Per-level features are auto-granted by the resolver (the model the 101 imported subclasses fail to use). |
| `classes.dart` | 12 | **Clean** — hit-die, saves, proficiencies, caster progression and structured `features` rows present. |
| `feats.dart` (62) · `feats_class.dart` (auto-grant traits) | ~80 | Mostly **Clean** — feats built with `effect()`/`predicate()` DSL (9+ `rule_effects` builders) and typed `prereq_*` fields. Prereqs still **UI-filtered, not apply-time validated** (same system gap as official feats). |
| `backgrounds.dart` | 16 | **Clean** — `granted_skill_refs`, `granted_tool_refs`, `ability_score_options`, `origin_feat_ref`, `equipment_choice_groups` typed. Note the same `granted_language_count` consumption gap applies system-wide. |
| `species.dart` (9) · `subspecies.dart` | ~10 | **Clean** — structured grants (`granted_modifiers`, senses, speeds, spell refs) applied by resolver Pass 5. |
| `spells.dart` | ~342 | **Missing Mechanic (system-wide)** — casting metadata typed, but no structured spell-effect resolution exists; damage/scaling in `description`. |
| `magic_items.dart` | ~287 | **Clean** — typed rarity/attunement/activation/effects. |
| `traits.dart` (~239) · `creature_actions.dart` (~529) | ~768 | Combat/stat-block fields typed; trait riders descriptive-by-design. |
| `monsters.dart` (248) · `animals.dart` (97) · `mounts`/`vehicles` | ~390 | **Clean** — full typed stat blocks. |
| `gear`/`weapons`/`armor`/`tools`/`ammunition`/`packs` | ~80 | **Clean** — typed cost/weight/properties. |

**Net:** the SRD core demonstrates the schema already supports structured
subclass features, typed feat effects, and species grants. The deficiencies in
Part A are therefore *content-pipeline / importer* gaps (the Open5e mapper does
not populate these structured fields) layered on top of three genuine
*system-level* gaps: feat-prerequisite apply-time validation, background
language-slot consumption, and spell-effect resolution.

---

## Closing tally

| Source | Cards | Clean | With ≥1 finding |
|---|---:|---:|---:|
| Official feats | 73 | 9 | 64 |
| Official backgrounds | 53 | 0 | 53 |
| Official subclasses | 101 | 0 | 101 |
| Official classes | 2 | 0 | 2 |
| Official species | 11 | 10 | 1 |
| Official subspecies | 30 | 27 | 3 |
| Official spells | 1,297 | 0 | 1,297 |
| Official magic items | 1,063 | 1,063 | 0 (minor: attunement-prereq) |
| Official gear | 159 | 159 | 0 |
| Official traits | 6,423 | n/a (descriptive) | — |
| Official creature-actions | 8,615 | 8,615 | 0 |
| Official monsters | 2,885 | 2,885 | 0 |
| **Official total** | **20,712** | — | — |
| SRD 5.2.1 core | ~2,260 | (per-builder, see Part B) | spells only |

See [`system_mechanics_roadmap.md`](system_mechanics_roadmap.md) for the
prioritized engineering work these findings imply.
