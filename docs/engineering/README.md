# Engineering Documentation Roadmap

> Living index of all technical specs for the Dungeon Master Tool D&D 5e re-architecture.
> Update Status column as documents move through `Not Started → Drafting → In Review → Complete`.

## Mission Context

The current Template-based JSON schema system is being **removed** and replaced with **code-level native D&D 5e** integration. The same code base will gain optional **online multiplayer** via Supabase. The architecture remains modular so future systems (Pathfinder, Call of Cthulhu) can plug in.

## Project Vision & Objectives

### Why We Are Doing This

The existing Template system was designed to let users integrate arbitrary tabletop systems (beyond D&D 5e) through JSON schemas. In practice, neither the rule expressiveness nor the JSON shape is sufficient to model real TTRPG mechanics (spell slots, concentration, AoE geometry, condition interactions, multiclass spellcasting, etc.). We are therefore **removing the Template abstraction in its entirety** — from the marketplace, the main menu, the database, and every touchpoint in the app — and replacing it with a **first-class, code-level D&D 5e implementation**. JSON as a rule-definition language is dropped. Rules live in Dart. Content (spells, monsters, items, classes, conditions) ships through a new typed **Package** format. Modularity is preserved at the `GameSystem` interface boundary so future settings (Pathfinder, Call of Cthulhu, …) can be added as sibling modules reusing the same engine primitives.

### Two Coexisting Modes: Offline & Online

The app runs in two modes sharing the same UI shell and domain model:

- **Offline mode** — mirrors today's behavior. The DM keeps campaign notes, builds and manages worlds, tracks combat, and uses the **second-screen** feature to project battlemaps, notes, entity cards, and images to players. Existing offline flows are preserved; nothing the DM does today should regress.
- **Online mode** — players join a DM's game via a **game code**, bringing either their own character or one the DM assigns them. There is **no interface distinction** between "DM" and "player" accounts: anyone can be either role in different sessions. When a user joins as a player, the familiar World UI opens but restricted to four tabs: **Character**, **Battlemap**, **Mind Map**, and **Player Screen**. Realtime sync runs on **Supabase**.

### Player-Side Online Capabilities

- **Battlemap tab** — shows the map the DM is currently sharing. DM's fog, drawings, tokens, and every edit replicate in realtime. Players can pan/zoom freely, draw (DM can erase), and move their own token within movement-speed bounds on their turn.
- **Spell/action use from the battlemap** — when a player uses, e.g., a 3m-radius Fireball with 30m range, the app highlights the legal targeting area and the effect area on the map; every participant sees it. The mechanical side also fires: the spell slot is consumed, damage is auto-rolled, and affected enemies lose HP via the damage resolver. This same flow is also available from the Character tab.
- **Character tab** — full character data, spell list, action list, resources. Can cast/act here too.
- **Player Screen tab** — mirrors whatever the DM broadcasts (notes, images, handouts). **PDF** and **Soundmap** sidebars are available to players; in Soundmap players can see the currently playing tracks and adjust per-player volume, but cannot start/stop sounds.

From the DM's perspective, online and offline modes are nearly identical — online simply adds the sync layer. Players get a stripped-down, consumption-oriented surface over the same world.

### Three Play Scenarios (Priority Order)

1. **In-person play, players roll their own dice, only the DM uses the app.** ← MVP target
2. **In-person play, players roll their own dice, both DM and players use the app.** ← MVP target
3. **Fully online play, dice/combat resolved by the app.** ← future scope

Because scenarios (1) and (2) dominate the MVP, **auto-resolve combat is optional and deferred**. MVP ships a manual combat tracker plus visual player AoE markers. When auto-combat is off (MVP default), the DM is the sole authority over the battlemap state; players can still watch and draw, and the DM can erase player drawings. Auto-combat (damage auto-applied, saves auto-prompted, etc.) is a Phase-3+ feature.

### What Stays the Same

- **Packages** remain the content distribution mechanism, now **typed and D&D-5e-native** instead of JSON-schema-driven. Users can still publish, e.g., a custom spell pack, via the marketplace.
- **Worlds** remain the core authoring unit — a user builds a world on top of the D&D 5e ruleset and can share it.
- **Second-screen** projection remains and is extended: online sessions fan the projection out to connected players as well as local displays.

### Character Creation

Character creation is re-designed as a **guided, multi-step flow** native to D&D 5e (species → class → background → ability scores → equipment/spells), replacing the current template-driven form. Level-1 and higher-level entry paths are both supported. See [`10-character-creation-flow.md`](./10-character-creation-flow.md).

### Platform & Design Constraints

The app must remain fully usable on **mobile/tablet (Android, iOS)** and **desktop (Windows, macOS, Linux)**. Every UI spec in Phase 4 treats responsiveness and input-mode adaptation (touch / mouse / stylus) as a hard requirement, not a nice-to-have.

### Non-Goals (MVP)

- Automated migration of existing user data from the Template-based schema — we take a fresh-start approach (see [`42-fresh-start-db-reset.md`](./42-fresh-start-db-reset.md)).
- Auto-resolve combat in online play.
- Non-D&D-5e rulesets (the `GameSystem` seam exists, but no second system ships in MVP).

### Resolved Scope Decisions

| Decision | Choice |
|---|---|
| RuleEngineV2 | **Remove entirely.** Effects implemented via serializable `EffectDescriptor` DSL compiled to `CompiledEffect`. |
| User data migration | **Fresh start.** No automated migration from old template-derived data. |
| Auto-resolve combat | **Out of MVP scope.** Manual combat tracker + visual player AoE markers only. |
| Internationalization | **TR + EN.** `intl` + `.arb` files. SRD content stays English (CC BY 4.0). |
| Mechanics vs content | **Built-in dnd5e module ships mechanics only.** All concrete content (conditions, spells, monsters, classes) arrives via packages; SRD ships as `srd_core.dnd5e-pkg.json` (see Doc 15). |
| `CustomEffect` escape hatch | **Allowed, whitelisted.** SRD ships ~9 Dart-backed impls (Wish, Wild Shape, Polymorph, …). Registry gated at package import. |
| Catalog id namespacing | **`<packageSlug>:<localId>`** (e.g. `srd:stunned`). Cross-package collisions impossible by construction. |

### Game Mode Priorities (per user)

1. **In-person play, players roll own dice, only DM uses app** ← MVP target
2. **In-person play, both DM and players use app** ← MVP target
3. **Fully online play** ← future scope (auto-combat included here)

---

## Status Legend

- 🟢 **Complete** — merged, authoritative
- 🟡 **In Review** — drafted, awaiting feedback
- 🟠 **Drafting** — actively being written
- 🔵 **Implementation In Progress** — code work started
- 🟣 **Implementation Partial / Blocked** — partially implemented, remainder blocked on dependency
- ⚪ **Not Started** — planned

---

## Phase 1: Foundation (Sprint 0-1) — blocking everything

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 00 | [`00-dnd5e-mechanics-reference.md`](./00-dnd5e-mechanics-reference.md) | Normative SRD 5.2.1 mechanics reference. Source of truth for all engine behavior. | — | ⚪ |
| 01 | [`01-domain-model-spec.md`](./01-domain-model-spec.md) | Typed Dart classes for Character, Monster, Spell, Item (sealed), Feat, Background, Species, CharacterClass, Subclass, Encounter, Combatant, Effect, etc. with invariants. | 00 | 🟢 |
| 02 | [`02-game-system-abstraction.md`](./02-game-system-abstraction.md) | `GameSystem` interface for future Pathfinder/CoC modularity. Stub Pathfinder example. | 01 | 🟣 |
| 03 | [`03-database-schema-spec.md`](./03-database-schema-spec.md) | Drift v5: drop `world_schemas` + template_* columns; add typed tables. Fresh-start reset (doc 42). | 01 | 🟣 |
| 04 | [`04-template-removal-checklist.md`](./04-template-removal-checklist.md) | ~40-file deletion order; dependency graph; per-step regression test plan. | 01, 03 | 🟣 |
| 05 | [`05-rule-engine-removal-spec.md`](./05-rule-engine-removal-spec.md) | Removal of RuleV2/RuleEngineV2; replacement pattern (effects as pure functions). | 01 | 🔵 |

## Phase 1.5: Mechanics / Content Decoupling — blocks Phase 2 implementation

The built-in dnd5e module ships **mechanics only** (rules engine, typed shapes, effect DSL). All concrete content (conditions, spells, monsters, classes, damage types, …) arrives via packages — including the SRD bundle. Docs 01/02/05/14 were revised; Doc 15 is new.

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 15 | [`15-srd-core-package.md`](./15-srd-core-package.md) | SRD 5.2.1 shipped as a package (assets build step + auto-install flow). Defines the whitelisted `CustomEffect` registry. | 01, 14 | 🟣 |

## Phase 2: Game Feature Specs (Sprint 2-4)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 10 | [`10-character-creation-flow.md`](./10-character-creation-flow.md) | 5-step wizard. State machine, per-step validation, level-1 vs higher-level paths. | 00, 01, 15 | 🟣 |
| 11 | [`11-combat-engine-spec.md`](./11-combat-engine-spec.md) | Manual combat tracker (MVP): initiative, turn state, action economy, condition expiration. Auto-resolve = future. | 00, 01 | 🟣 |
| 12 | [`12-spell-system-spec.md`](./12-spell-system-spec.md) | Slot tables, multiclass calculator, Pact Magic, concentration, AoE geometry. | 00, 01 | 🟣 |
| 13 | [`13-damage-resolver-spec.md`](./13-damage-resolver-spec.md) | Attack pipeline: crit, resistance/vuln/immunity, save-half, temp HP, concentration check. | 00, 01, 11 | 🟣 |
| 14 | [`14-package-system-redesign.md`](./14-package-system-redesign.md) | DnD5e-native typed package format (v2). Catalog content types, id namespacing, `requiredRuntimeExtensions`. | 01 | 🟣 |

## Phase 3: Online Multiplayer Specs (Sprint 5-7)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 20 | [`20-supabase-schema.md`](./20-supabase-schema.md) | Tables, RLS policies, indexes for game sessions. | 01 | ⚪ |
| 21 | [`21-realtime-protocol.md`](./21-realtime-protocol.md) | Channel naming, event envelope, sequence numbers, snapshot vs delta. | 20 | ⚪ |
| 22 | [`22-online-game-flow.md`](./22-online-game-flow.md) | Game code generation, DM/player join, lobby, role assignment, disconnect handling. | 20, 21 | ⚪ |
| 23 | [`23-battlemap-sync-protocol.md`](./23-battlemap-sync-protocol.md) | DM↔player fog/draw/token sync. DM authority model, bandwidth budget. | 21 | ⚪ |
| 24 | [`24-player-action-protocol.md`](./24-player-action-protocol.md) | Player visual AoE marker. MVP: no auto-resolve. | 12, 21 | ⚪ |
| 25 | [`25-second-screen-integration.md`](./25-second-screen-integration.md) | ProjectionOutput → fan-out (local + Supabase). | 21 | ⚪ |

## Phase 4: UI/UX Design Specs (Sprint 6-8, parallel with Phase 3)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 30 | [`30-responsive-design-system.md`](./30-responsive-design-system.md) | Breakpoints, adaptive widget pattern, touch vs mouse vs stylus. | — | ⚪ |
| 31 | [`31-ui-component-library.md`](./31-ui-component-library.md) | 24 DnD5e-specific reusable widgets. | 01, 30 | ⚪ |
| 32 | [`32-character-sheet-views.md`](./32-character-sheet-views.md) | DM vs player views, field visibility matrix, mobile/tablet/desktop layouts. | 01, 30, 31 | ⚪ |
| 33 | [`33-battlemap-interaction-spec.md`](./33-battlemap-interaction-spec.md) | Pan/zoom, token drag, drawing tools, measurement, AoE placement, fog brushes. | 23, 30 | ⚪ |

## Phase 5: Quality & Operations (Sprint 8+)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 40 | [`40-testing-strategy.md`](./40-testing-strategy.md) | Unit/widget/golden/integration/network test layers. Coverage targets. | 00-33 | ⚪ |
| 41 | [`41-security-and-privacy.md`](./41-security-and-privacy.md) | Threat model, RLS audit, anti-cheat policy (trust-based), PII. | 20-22 | ⚪ |
| 42 | [`42-fresh-start-db-reset.md`](./42-fresh-start-db-reset.md) | Drift v5 = drop+recreate. User-facing notice. Optional backup. | 03 | 🟣 |
| 43 | [`43-i18n-localization-spec.md`](./43-i18n-localization-spec.md) | `intl` setup, `.arb` files (en/tr). SRD content English-only. | 30 | ⚪ |

---

## Dependency Graph (Quick Reference)

```
00 ──┬── 01 ──┬── 02
     │        ├── 03 ── 04
     │        │        ├── 42
     │        ├── 05
     │        ├── 14 ── 15 ── 10
     │        ├── 11 ── 13
     │        ├── 12 ──┐
     │        │        │
     │        └── 20 ──┴── 21 ──┬── 22
     │                          ├── 23 ── 33
     │                          ├── 24
     │                          └── 25
     │
     └── 30 ──┬── 31 ── 32
              ├── 33
              └── 43

40, 41 cross-cut all docs. 15 blocks all Phase 2 implementation because
character creation, spells, combat, and items all reference SRD content.
```

## Authoring Conventions

- **Language:** English. Code identifiers always English. SRD references inline as `(SRD p. N)`.
- **Format:** Markdown, GitHub-flavored. Use tables and code fences. Inline diagrams via Mermaid acceptable.
- **Length target:** 5-20 pages each. Spec docs can be longer if necessary.
- **Versioning:** `Last updated: YYYY-MM-DD` at top. Significant rewrites bump a `v2.0` etc. tag.
- **References:** link to other docs by filename (e.g., `[10-character-creation-flow](./10-character-creation-flow.md)`). Link to code files in `flutter_app/` using relative paths.
- **Open questions:** maintain an `## Open Questions` section per doc; resolve during review.

## Workflow

1. **Pick a doc** with all dependencies marked 🟢 (or accept partial deps with caveat).
2. Mark Status as ⚪ Drafting in this README via PR.
3. Author content; iterate.
4. PR review: domain expert + at least one engineer.
5. Merge → mark ⚪ In Review for 1 week → 🟢 Complete.
6. Doc enters maintenance: minor updates as code evolves; major rewrite triggers version bump.

## Implementation Log

### 2026-04-19 — Doc 15 SRD weapon properties asset (🟣) — Tier 1 catalogs COMPLETE

Shipped `flutter_app/assets/packages/srd_core/weapon_properties.json` with the 10 canonical 2024 PHB weapon properties — Ammunition, Finesse, Heavy, Light, Loading, Range, Reach, Thrown, Two-Handed, Versatile. Body is `{"flags": [<PropertyFlag.name>...], "description": String?}`. Each property carries exactly the matching `PropertyFlag` from `weapon_property_flag.dart` so engine dispatch works on the flag rather than the id (homebrew "arcane:graceful" with `finesse` flag behaves identically to `srd:finesse`). Count is 10 (not plan's "~14" estimate); material/imbue flags (`silvered`, `magical`, `appliesToSneakAttack`) are not PHB weapon properties — they attach at item level.

- New assets: `assets/packages/srd_core/weapon_properties.json`.
- Tests: 7 new (`test/assets/packages/srd_core/weapon_properties_asset_test.dart`) — parse all 10, namespace + uniqueness, canonical 10-set, flag mapping per property, non-empty descriptions, Reach description mentions "5 feet", `two_handed` carries `twoHanded` camelCase flag.
- Result: `flutter analyze` clean, 985/985 tests pass (978 → 985, +7).
- **Phase B Tier 1 catalogs are now COMPLETE** (12/12): conditions, damage_types, skills, sizes, creature_types, alignments, armor_categories, rarities, weapon_masteries, spell_schools, languages, weapon_properties.
- Next: Tier 2 entity authoring starts — spells (~361), monsters (~320), items (~300), classes (12 + subclasses), species (9), backgrounds (16), feats (~40). Recommended batch cadence: ~50 per turn for spells/monsters/items.

### 2026-04-19 — Doc 15 SRD languages asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/languages.json` with 19 SRD 5.2.1 languages — 9 Standard (Common, Common Sign Language, Dwarvish, Elvish, Giant, Gnomish, Goblin, Halfling, Orc), 9 Rare (Abyssal, Celestial, Deep Speech, Draconic, Druidic, Infernal, Primordial, Sylvan, Undercommon), plus Thieves' Cant. Body is `{"script": String?}`. Scripts follow classic D&D lore (e.g. Dwarvish → Dwarvish runes; Elvish → Elvish; Goblin uses Common; Orc uses Dwarvish). Three entries have `null` script for unwritten/gestural/secret forms: Common Sign Language, Deep Speech, Thieves' Cant.

- New assets: `assets/packages/srd_core/languages.json`.
- Tests: 7 new (`test/assets/packages/srd_core/languages_asset_test.dart`) — parse all 19, namespace + uniqueness, canonical 19-set, non-empty scripts when present, unwritten langs have null, Common/Draconic specific script assertions.
- Result: `flutter analyze` clean, 978/978 tests pass (971 → 978, +7).
- Next: weapon properties (~14) — last remaining Tier 1 catalog.

### 2026-04-19 — Doc 15 SRD spell schools asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/spell_schools.json` with the 8 canonical SRD schools — Abjuration, Conjuration, Divination, Enchantment, Evocation, Illusion, Necromancy, Transmutation. Body is `{"color": String?}`. Picked a distinct `#RRGGBB` hex per school for UI tinting (the domain `_isHex` regex enforces the format). Colors are advisory — engine only reads `id`/`name`.

- New assets: `assets/packages/srd_core/spell_schools.json`.
- Tests: 5 new (`test/assets/packages/srd_core/spell_schools_asset_test.dart`) — parse all 8, namespace + uniqueness, canonical 8-set, `#RRGGBB` format per school, colors distinct.
- Result: `flutter analyze` clean, 971/971 tests pass (966 → 971, +5).
- Next: languages (~16) or weapon properties (~14).

### 2026-04-19 — Doc 15 SRD weapon masteries asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/weapon_masteries.json` with the 8 canonical 2024 PHB weapon masteries — Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex. Body is `{"description": String}`. Count follows the PHB (8) rather than the Phase B plan's earlier "5 masteries" estimate; descriptions paraphrase the 2024 PHB mastery table. Behavior attaches at the Weapon level via `EffectDescriptor`s (per `weapon_mastery.dart`) — catalog entries here only carry the reference data.

- New assets: `assets/packages/srd_core/weapon_masteries.json`.
- Tests: 6 new (`test/assets/packages/srd_core/weapon_masteries_asset_test.dart`) — parse all 8, namespace + uniqueness, canonical 8-set, non-empty descriptions, Topple names Constitution save, Push distance 10 ft.
- Result: `flutter analyze` clean, 966/966 tests pass (960 → 966, +6).
- Next: spell schools (8), languages (~16), or weapon properties (~14).

### 2026-04-19 — Doc 15 SRD rarities asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/rarities.json` with 6 SRD magic-item rarities — Common, Uncommon, Rare, Very Rare, Legendary, Artifact. Body is `{"sortOrder": int, "attunementTierReq": int?}`. `sortOrder` runs 0..5 to give a stable rank across installed packages. `attunementTierReq` follows the DMG level guideline (Common/Uncommon 1+, Rare 5+, Very Rare 11+, Legendary 17+); Artifact is `null` — one-of-a-kind items handed out at DM discretion, no level floor.

- New assets: `assets/packages/srd_core/rarities.json`.
- Tests: 6 new (`test/assets/packages/srd_core/rarities_asset_test.dart`) — parse all 6, namespace + uniqueness, canonical 6-set, `sortOrder` monotonic 0..5, per-rarity attunement tiers, Artifact has null tier.
- Result: `flutter analyze` clean, 960/960 tests pass (954 → 960, +6).
- Next: weapon masteries (5), spell schools (8), languages (~16), or weapon properties (~14).

### 2026-04-19 — Doc 15 SRD armor categories asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/armor_categories.json` with 4 SRD armor categories — Light, Medium, Heavy, Shield. Body is `{"stealthDisadvantage": bool, "maxDexCap": int?}`. Canonical values: Light `null`/`false` (Dex uncapped, no stealth penalty), Medium `2`/`false` (+2 Dex cap, per-armor override for stealth), Heavy `0`/`true` (Dex contributes nothing, stealth disadvantage), Shield `null`/`false` (shields don't cap Dex — they add flat AC, modeled separately at item level). Count follows `armor_category.dart` dartdoc (4) rather than the plan table (3); Shield is a first-class category because it composes orthogonally with body armor.

- New assets: `assets/packages/srd_core/armor_categories.json`.
- Tests: 7 new (`test/assets/packages/srd_core/armor_categories_asset_test.dart`) — parse all 4, namespace + uniqueness, canonical 4-set, per-category dex-cap + stealth flag checks.
- Result: `flutter analyze` clean, 954/954 tests pass (947 → 954, +7).
- Next: rarities (6), weapon masteries (5), spell schools (8), or larger: languages (~16), weapon properties (~14).

### 2026-04-19 — Doc 15 SRD alignments asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/alignments.json` with the 10 SRD alignments — the 3×3 L/N/C × G/N/E grid plus Unaligned. Body is `{"lawChaos": <LawChaosAxis.name>, "goodEvil": <GoodEvilAxis.name>}`. True Neutral keeps the SRD display name "Neutral" with id `srd:true_neutral` to avoid a namespace clash on the neutral axis values. Unaligned maps both axes to `unaligned` (Tier 0 enum fourth variant) — monsters like oozes and non-sentient beasts use this.

- New assets: `assets/packages/srd_core/alignments.json`.
- Tests: 8 new (`test/assets/packages/srd_core/alignments_asset_test.dart`) — parse all 10, namespace + uniqueness, canonical 10-set, 3×3 grid coverage check, per-corner value check (LG, CE), True Neutral name + axes, Unaligned uses `unaligned` enum value on both axes.
- Result: `flutter analyze` clean, 947/947 tests pass (939 → 947, +8).
- Next: armor categories (3), rarities (6), or weapon masteries (5).

### 2026-04-19 — Doc 15 SRD creature types asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/creature_types.json` with the 14 SRD creature types (Aberration, Beast, Celestial, Construct, Dragon, Elemental, Fey, Fiend, Giant, Humanoid, Monstrosity, Ooze, Plant, Undead). Body is the empty object `{}` — creature types carry no domain fields beyond id/name; monsters reference them by id for tagging/filtering + tags-to-effects interaction (e.g. Radiant bonus vs Undead/Fiends).

- New assets: `assets/packages/srd_core/creature_types.json`.
- Tests: 4 new (`test/assets/packages/srd_core/creature_types_asset_test.dart`) — parse all 14, namespace + uniqueness, canonical 14-set match, names Title Case.
- Result: `flutter analyze` clean, 939/939 tests pass (935 → 939, +4).
- Next: alignments (10, two enum axes) or armor categories (3).

### 2026-04-19 — Doc 15 SRD sizes asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/sizes.json` with the 6 SRD creature sizes (Tiny, Small, Medium, Large, Huge, Gargantuan). Body carries the two `Size` domain fields — `spaceFt` (square side the creature occupies) and `tokenScale` (multiplier relative to a 1×1 Medium token). Canonical values: Tiny 2.5ft/×0.5, Small 5ft/×1, Medium 5ft/×1, Large 10ft/×2, Huge 15ft/×3, Gargantuan 20ft/×4 (per SRD 5.2.1 + doc 00 §Glossary).

- New assets: `assets/packages/srd_core/sizes.json`.
- Tests: 7 new (`test/assets/packages/srd_core/sizes_asset_test.dart`) — parse all 6, namespace + uniqueness, canonical 6-size set, Tiny fractional values, Small/Medium share 5ft/×1, per-size value check for Large/Huge/Gargantuan, `spaceFt` monotonic across the canonical ordering.
- Result: `flutter analyze` clean, 935/935 tests pass (928 → 935, +7).
- Next: creature types (14 entries) or alignments (10). Both small, pick either.

### 2026-04-19 — Doc 15 SRD skills asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/skills.json` with all 18 SRD 5.2.1 skills, each tagged with governing ability: 1 STR (Athletics), 3 DEX (Acrobatics, Sleight of Hand, Stealth), 5 INT (Arcana, History, Investigation, Nature, Religion), 5 WIS (Animal Handling, Insight, Medicine, Perception, Survival), 4 CHA (Deception, Intimidation, Performance, Persuasion). Multi-word ids use snake_case (`srd:sleight_of_hand`, `srd:animal_handling`).

- New assets: `assets/packages/srd_core/skills.json`.
- Tests: 8 new (`test/assets/packages/srd_core/skills_asset_test.dart`) — parse all 18, namespace + uniqueness, ability distribution (1/3/5/5/4), STR single-skill = Athletics, exact DEX/WIS/CHA subsets, canonical 18-skill set match.
- Result: `flutter analyze` clean, 928/928 tests pass (920 → 928, +8).
- Next: sizes (6 entries) or creature types (14).

### 2026-04-19 — Doc 15 SRD damage types asset (🟣)

Shipped `flutter_app/assets/packages/srd_core/damage_types.json` with the canonical 13 SRD 5.2.1 damage types (acid, bludgeoning, cold, fire, force, lightning, necrotic, piercing, poison, psychic, radiant, slashing, thunder). `physical=true` on the three weapon types (bludgeoning / piercing / slashing); rest default false. Doc 15 table said 14 — SRD 5.2.1 has 13 (see doc 00 §11.2 + §Glossary row `Damage Types | 13 named types`); table correction pending.

- New assets: `assets/packages/srd_core/damage_types.json`.
- Tests: 5 new (`test/assets/packages/srd_core/damage_types_asset_test.dart`) — parses all 13, ids namespaced + unique, physical flag set on b/p/s, other 10 default false, exact set match.
- Result: `flutter analyze` clean, 920/920 tests pass (915 → 920, +5).
- Next: skills catalog (18 entries).

### 2026-04-19 — Doc 15 SRD conditions asset (Phase B start) (🟣)

First SRD content asset shipped: `flutter_app/assets/packages/srd_core/conditions.json` with all 15 SRD 5.2.1 conditions (Blinded, Charmed, Deafened, Exhaustion, Frightened, Grappled, Incapacitated, Invisible, Paralyzed, Petrified, Poisoned, Prone, Restrained, Stunned, Unconscious). Authoring format is human-readable (`body` inline as object); the build step (future) stringifies to wire shape. Each entry encodes SRD description + representable mechanical flags via `ConditionInteraction` (incapacitated, speedZero, autoFailSavesOf, imposedAdvantageOnAttacksAgainst, attacksHaveDisadvantage, cannotTakeActions, cannotTakeReactions, grappled, invisibleToSight). Restrained adds a rider `ModifySave` for DEX disadvantage. Petrified's "resistance to all damage" + auto-crit-within-5ft on Paralyzed/Unconscious remain text-only (no DSL surface).

- New assets: `flutter_app/assets/packages/srd_core/conditions.json`.
- Tests: 13 new (`test/assets/packages/srd_core/conditions_asset_test.dart`) — setUpAll loads + namespaces under `srd:` + stringifies body + parses through `conditionFromEntry`; then per-condition flag assertions.
- Result: `flutter analyze` clean, 915/915 tests pass (902 → 915, +13).
- Marks start of **Phase B** (SRD content authoring). No longer codec-blocked.
- Next: damage types catalog (14 entries) or skills catalog (18 entries). Smaller first.

### 2026-04-19 — Doc 15 Subclass codec (🟣)

Tier 1 Subclass JSON codec in `domain/dnd5e/character/subclass_json_codec.dart`: top-level `subclassFromEntry`/`subclassToEntry` with body shape `{parentClassId, featureTable?, description?}` and nested `ClassFeatureRow` shape `{level, featureIds?, effects?}`. Rows emitted sorted by level for deterministic output; empty `featureIds` / `effects` elided. Row `effects` route through `EffectDescriptor` codec (reused — no duplication of the 11 variant switch).

- New: `subclass_json_codec.dart` (~130 lines).
- Tests: 12 new (`test/domain/dnd5e/character/subclass_json_codec_test.dart`) — minimal + full (School of Evocation with `ModifySave` at lvl 6), row sort stability regardless of input order, empty-field elision, non-object body / missing parentClassId / non-array featureTable / missing row level / non-string featureId / non-object row rejection with entry-id-prefixed messages.
- Result: `flutter analyze` clean, 902/902 tests pass (890 → 902, +12).
- Unblocks: SRD subclass authoring (all 12 base-class subclasses) — last remaining Tier 2 content codec. **Codec surface for Doc 15 is now complete.**
- Next: SRD content authoring (Phase B) or Doc 04 Step 5/7 + Doc 42 wiring bundle.

### 2026-04-19 — Doc 15 Item codec (🟣)

Tier 2 Item JSON codec in `domain/dnd5e/item/item_json_codec.dart`: top-level `itemFromEntry`/`itemToEntry` dispatching on sealed `Item` variant tag (`weapon`/`armor`/`shield`/`gear`/`tool`/`ammunition`/`magicItem`) plus nested `AttunementPrereq` codec (4 variants — byClass, bySpecies, byAlignment, bySpellcaster). Base `id`/`name` on `CatalogEntry`; body carries `rarityId`, optional `weightLb`/`costCp` (elided when default 0), variant-specific fields, and `MagicItem.effects` routed through `EffectDescriptor` codec.

- New: `item_json_codec.dart` (~380 lines).
- Tests: 24 new (`test/domain/dnd5e/item/item_json_codec_test.dart`) — full weapon profile (melee + ranged with `RangePair`), sorted `propertyIds` output, Armor with strength requirement, default Shield acBonus=2 elision, Gear description, Tool proficiency, default Ammunition quantityPerStack=1 elision, all 4 AttunementPrereq variants, Ring-of-Protection integration with ModifyAc + ModifySave nested effects, unknown-tag / missing-field / non-object-body rejection with entry-id-prefixed messages.
- Result: `flutter analyze` clean, 890/890 tests pass (866 → 890, +24).
- Unblocks: SRD ~300 item authoring (weapons, armor, adventuring gear, tools, magic items).
- Remaining Doc 15 codec surface: `Subclass` (class-feature wrapper). Tier 2 content codec surface otherwise complete.

### 2026-04-19 — Doc 15 Monster codec + StatBlock / MonsterAction / LegendaryAction (🟣)

Tier 2 Monster JSON codec in `domain/dnd5e/monster/monster_json_codec.dart`: top-level `monsterFromEntry`/`monsterToEntry` plus sub-codecs for `StatBlock` (incl. `MonsterSpeeds`, `MonsterSenses`, ability-score map, saving-throw map keyed on `Ability.name`, skill map, sorted damage/condition immunity sets, `ChallengeRating` canonical string), sealed `MonsterAction` (Attack/Multiattack/Save/Special — tagged on `"t"`), and `LegendaryAction` wrapper. Nested `traits` / `SpecialAction.effects` route through `EffectDescriptor` codec.

- New: `monster_json_codec.dart` (~430 lines).
- Tests: 21 new (`test/domain/dnd5e/monster/monster_json_codec_test.dart`) — per-action round-trips, default elision (reachFt=5, halfOnSave=true, multiattack default name, legendary cost=1), empty-senses elision, sorted-output determinism for string sets + saving-throw maps + skill maps, full Adult-Red-Dragon integration test (alignment, HP formula, multi-line speeds, traits, multiattack + attack + save actions, 2 legendary actions, languages), missing/invalid-CR/non-object-senses rejection.
- Result: `flutter analyze` clean, 866/866 tests pass (845 → 866, +21).
- Unblocks: SRD ~320 monster authoring. Doc 15 Tier 2 content codec surface now covers Condition + Spell + Monster; remaining picks are Item (smallest) and Subclass.

### 2026-04-19 — Doc 15 Spell codec + sub-codecs (🟣)

Full Tier 2 Spell JSON codec in `domain/dnd5e/spell/spell_json_codec.dart`: top-level `spellFromEntry`/`spellToEntry` plus sealed-family sub-codecs for `CastingTime` (5 variants), `SpellRange` (6), `AreaOfEffect` (6 — Sphere/Cone/Cube/Cylinder/Emanation/Line), `SpellDuration` (7), `SpellComponent` (V/S/M w/ cost + consumed). Spell body: `{level, schoolId, castingTime, range, components, duration, targets?, area?, effects?, ritual?, classListIds?, description?}`. Optional fields elided on encode; `effects` nests the existing `EffectDescriptor` codec.

- New: `spell_json_codec.dart` (390 lines).
- Tests: 33 new (`test/domain/dnd5e/spell/spell_json_codec_test.dart`) — per-variant round-trips, default elision, integration test for a full Fireball (L3 evocation, V/S/M, 150ft range, 20ft sphere, GrantCondition effect), Cure Wounds with Heal effect, Detect Magic with ritual + concentration duration, unknown-tag / missing-field / bad-enum rejection.
- Result: `flutter analyze` clean, 845/845 tests pass (812 → 845, +33).
- Unblocks: SRD ~361 spell authoring. Spell catalog entries now ship through the same `{id, name, bodyJson}` package shape as Tier 1 catalogs.

### 2026-04-19 — Doc 15 Condition.effects wired to EffectDescriptor codec (🟣)

`conditionToEntry` / `conditionFromEntry` now serialize `Condition.effects` through the Tier 2 `encodeEffect`/`decodeEffect` bridge. `effects` key omitted when list empty; non-array and unknown-tag payloads rejected with `<entry.id>:`-prefixed `FormatException`.

- Edited: `domain/dnd5e/catalog/catalog_json_codecs.dart` — added `_decodeEffectList` helper; Condition bodyJson now carries `{"description": ..., "effects": [...]}`.
- Tests: 4 new (`catalog_json_codecs_test.dart` Condition group) — `ConditionInteraction` round-trip, empty-list elision, non-array rejection, unknown-tag rejection.
- Result: `flutter analyze` clean, 812/812 tests pass (808 → 812, +4).
- Unblocks: SRD authoring of the 17 conditions with their rule-engine riders (prone advantage/disadvantage on attacks, restrained speed-zero, stunned auto-fail STR/DEX, blinded invisibleToSight, etc.).

### 2026-04-19 — Doc 15 EffectDescriptor codec (🟣)

Tagged-union JSON codec for the Tier 2 sealed families: `EffectDescriptor` (11 variants), `Predicate` (14 variants), `EffectDuration` (6 variants), `AcFormula` (4 variants). Keyed on `"t"`; unknown tags fail fast with context-prefixed `FormatException`. Dice stored as canonical string (`DiceExpression.toString()`/`parse`), enums via `.name`, ContentReferences as-is. Defaults elided on encode; decoders fill them back in. Sorted id arrays for deterministic output (`ModifyResistances.add/remove`, `ConditionInteraction.autoFailSavesOf`).

- New: `domain/dnd5e/effect/effect_descriptor_codec.dart` with `encodeEffect`/`decodeEffect`/`encodePredicate`/`decodePredicate`/`encodeDuration`/`decodeDuration`/`encodeAcFormula`/`decodeAcFormula`.
- Tests: 45 new (`test/domain/dnd5e/effect/effect_descriptor_codec_test.dart`) covering each variant round-trip, default elision, sorted-output determinism, unknown-tag rejection, malformed field rejection, and predicate nesting inside effects.
- A0 verification: audited `DamageResolver` instant-death arithmetic vs SRD p.17 — `overkill = remainder - currentHp; instantDeath = hpAfter==0 && overkill >= maxHp` matches "remaining damage equals or exceeds HP max" across full-HP oneshot / at-0 max-HP-hit / partial-damage cases. Correct.
- Result: `flutter analyze` clean, 808/808 tests pass (763 → 808, +45).
- Unblocks: `Condition.effects` round-trip, every Tier 1/2 entity carrying effect bodies (Spell, Feat, MagicItem, Subclass, class features). Consumer wiring of the codec into catalog/content entry bodies is the next Doc 15 turn.

### 2026-04-19 — Doc 04 template removal partial (🟣)

Steps 1-4, 6, 8-10 landed. Steps 5 (schema dir deletion) + 7 (drift v5 drop+recreate) blocked on Doc 01 typed domain model — WorldSchema/EntityCategorySchema/FieldSchema still load-bearing for rendering and persistence.

- Removed: template UI (editor screen, templates_tab, hub route), TemplateSyncService, TemplateCompatibilityService, activeTemplateProvider, ActiveTemplateNotifier, templateLocalDsProvider, customTemplatesProvider, TemplateLocalDataSource, legacy_builtin_seed migration, RuleEngineV2, rule_provider, applyTemplateUpdate/dismissTemplateUpdate/muteTemplateUpdates on Campaign/Package/CharacterList notifiers, marketplace 'template' filter.
- Shimmed: `allTemplatesProvider` now returns `[generateDefaultDnd5eSchema()]` — no disk, no ActiveTemplateNotifier. Sufficient to keep entity_card / character_editor rendering until Doc 01 types land.
- Result: `flutter analyze` clean, 251/251 tests pass (33 RuleEngineV2 tests removed).

### 2026-04-19 — Doc 05 rule engine removal (🔵)

RuleEngineV2 + rule_provider + tests deleted. `_formulaFor` in entity_card now returns null until Doc 01 class-feature pure functions replace it. `computedFieldsProvider` gone; entity_card uses `const <String, dynamic>{}` for computed values.

### 2026-04-19 — Doc 01 domain model (🟢 COMPLETE)

Target layout per spec §Directory Layout — `flutter_app/lib/domain/dnd5e/`.

**Tier 0 (structural primitives) — COMPLETE.** 13 classes + 79 tests in `domain/dnd5e/core/`:

| File | Purpose | Tests |
|---|---|---|
| `ability.dart` | 6-member enum + `short` / `label` / `fromShort` | 4 |
| `ability_score.dart` | Value class [1,30] + SRD modifier formula | 4 |
| `ability_scores.dart` | 6-tuple + `byAbility` + `withBonus` (clamped) | 4 |
| `proficiency.dart` | enum {none, half, full, expertise} + `applyTo(PB)` | 4 |
| `proficiency_bonus.dart` | `forLevel(1..20)` + `forChallengeRating(0..30)` | 3 |
| `die.dart` | enum d4/d6/d8/d10/d12/d20/d100 + `averageFloor` + `fromSides` | 4 |
| `advantage_state.dart` | enum + `combine` + `fromFlags` (SRD cancellation) | 7 |
| `dice_expression.dart` | Parser for `NdS±K` + roll/max/min/averageFloor | 14 |
| `spell_level.dart` | [0,9] value class, cantrip detection | 4 |
| `challenge_rating.dart` | Canonical fraction string + XP table (0..30) | 8 |
| `hit_points.dart` | current/max/temp + takeDamage/heal/grantTemp/withMax | 11 |
| `death_saves.dart` | 0..3 tally + crit-failure doubles + isStable/isDead | 5 |
| `exhaustion.dart` | 0..6 track, -2×level D20 penalty (2024 SRD), gain/reduce | 5 |

Design choices locked in this tier:
- **No Freezed.** Manual `==`/`hashCode`/`copyWith` per spec §Conventions.
- **Factory guards** throw `ArgumentError` with specific message on invariant violations.
- **CR as canonical string** (`'1/4'`, `'5'`) not double — avoids float equality per spec §Open Questions Q2.
- **Temp HP** does not stack (max-wins), consumed before current HP on damage.
- **Exhaustion** uses 2024 SRD scaling (-2 × level) not 2014 six-step.

**Tier 1 (catalog classes) — COMPLETE.** 12 classes + shared helpers + 46 tests (1 skipped) in `domain/dnd5e/catalog/`:

| File | Purpose | Tests |
|---|---|---|
| `content_reference.dart` | `typedef ContentReference<T> = String` + `validateContentId` shape guard | 4 |
| `condition.dart` | `{id, name, description, effects: List<EffectDescriptor>}` | 6 (1 skip) |
| `damage_type.dart` | `{id, name, physical}` (physical true for BPS) | 4 |
| `skill.dart` | `{id, name, ability: Ability}` — Tier 0 ability enum | 4 |
| `size.dart` | `{id, name, spaceFt, tokenScale}` for map rendering | 3 |
| `creature_type.dart` | `{id, name}` — pure catalog | 3 |
| `alignment.dart` | `{id, name, lawChaos, goodEvil}` with Tier 0 axis enums (incl. unaligned) | 3 |
| `language.dart` | `{id, name, script?}` — script null for spoken-only langs | 3 |
| `spell_school.dart` | `{id, name, color?}` — color validated as `#RRGGBB` hex | 3 |
| `weapon_property_flag.dart` | Tier 0 `enum PropertyFlag` (finesse, heavy, light, …, silvered, magical) | — |
| `weapon_property.dart` | `{id, name, flags: Set<PropertyFlag>, description?}` + `hasFlag` | 4 |
| `weapon_mastery.dart` | `{id, name, description}` — 2024 PHB masteries (Cleave, Graze, …) | 3 |
| `armor_category.dart` | `{id, name, stealthDisadvantage, maxDexCap}` (null = no cap, 0 = Dex ignored) | 4 |
| `rarity.dart` | `{id, name, sortOrder, attunementTierReq: 1..20?}` | 3 |

Design choices locked in this tier:
- **Tier 2 stub shipped.** `effect/effect_descriptor.dart` is an empty `sealed class EffectDescriptor` so `Condition.effects` compiles before the full Tier 2 DSL lands.
- **Shared id validator.** `validateContentId(String)` in `catalog/content_reference.dart` enforces `<pkg>:<local>` shape for every catalog factory.
- **Equality by id.** All catalog classes use id-only `==`/`hashCode` — two entries with the same id from the same package are identical by construction.
- **Immutable collections.** `effects` / `flags` wrapped via `List.unmodifiable` / `Set.unmodifiable`.
- **Structural flags stay Tier 0.** `PropertyFlag`, `LawChaosAxis`, `GoodEvilAxis` are enums so the engine keys off flags not strings.

**Tier 2 (EffectDescriptor DSL) — COMPLETE.** 4 files + 39 tests in `domain/dnd5e/effect/`:

| File | Purpose | Tests |
|---|---|---|
| `duration.dart` | sealed `EffectDuration` (+ `Instantaneous`, `RoundsDuration`, `MinutesDuration`, `UntilRest`, `ConcentrationDuration`, `UntilRemoved`) + `RestKind` enum. Renamed from spec's `Duration` to avoid `dart:core` shadowing. | 6 |
| `predicate.dart` | sealed `Predicate` (+ `Always`, `All`, `Any`, `Not`, `AttackerHasCondition`, `TargetHasCondition`, `AttackIsMelee/Ranged`, `AttackUsesAbility`, `WeaponHasProperty`, `DamageTypeIs`, `IsCritical`, `HasAdvantage`, `EffectActive`). Structural equality on all 14 cases. | 8 |
| `effect_descriptor.dart` | sealed `EffectDescriptor` + 11 concrete cases (`ModifyAttackRoll`, `ModifyDamageRoll`, `ModifySave`, `ModifyAc`, `ModifyResistances`, `GrantCondition`, `GrantProficiency`, `GrantSenseOrSpeed`, `Heal`, `ConditionInteraction`, `CustomEffect`) + helpers `TypedDice`, `SaveSpec`, sealed `AcFormula` (`AcFlat`, `AcNaturalPlusDex`, `AcUnarmored`, `AcMageArmor`), enums `EffectTarget`, `ResistanceKind`, `ProficiencyKind`, `SenseOrSpeedKind`. | 21 |
| `custom_effect_registry.dart` | `abstract interface class CustomEffectImpl` + process-wide `CustomEffectRegistry` (register/byId/contains/clear). `compile` step deferred to Doc 05 (rule engine). | 4 |

Design choices locked in this tier:
- **Closed sealed families** — no runtime-evaluated strings, no reflection. Engine dispatches on case in `application/dnd5e/services/`.
- **Factory invariant guards** on every case that touches `ContentReference`s (id shape validated via `validateContentId`), on mutually exclusive flags (`ModifySave.autoSucceed` vs `autoFail`), and on numeric ranges.
- **Immutable collections** — `extraTypedDice`, `add/remove` damage-type sets, `autoFailSavesOf`, `parameters` all wrapped via `List`/`Set`/`Map.unmodifiable`.
- **Save proficiency exception** — `GrantProficiency.targetId` accepts raw Ability short codes (`'DEX'`) when `kind == ProficiencyKind.save`, namespaced ids otherwise. Codified in factory.
- **`Duration` renamed to `EffectDuration`** — Doc 01 uses the bare `Duration` name; the rename is mechanical and noted in the file header.
- **Structural equality on `Predicate`** — engine may use predicate sets as cache keys or deduplicate; leaf cases implement `==`/`hashCode`/`toString`. `EffectDescriptor` cases skip it (not yet needed; add when consumers demand).

**Larger entities — COMPLETE.** 34 files across `character/`, `spell/`, `item/`, `monster/`, `combat/`, `world/` + 82 new tests.

**`character/`** — `character.dart` (root; total-level cap 20, derived `proficiencyBonus`/`initiativeMod`/`passivePerception`), `character_class_level.dart`, `character_class.dart` + `ClassFeatureRow`, `subclass.dart`, `species.dart`, `lineage.dart`, `background.dart`, `feat.dart` + `FeatCategory` enum, `proficiency_set.dart` (saves by Ability, everything else by namespaced id, + `alertFeat` flag), `inventory.dart` + `InventoryEntry` + `EquipSlot` enum (3-item attunement cap enforced), `spell_slots.dart` (levels 1..9), `pact_magic_slots.dart` (Warlock; slot level 1..5), `hit_dice_pool.dart` (per-Die buckets, `recoverLongRest` = half total), `prepared_spells.dart` + `PreparedSpellEntry`.

**`spell/`** — `spell.dart` (Tier 1 root), `area_of_effect.dart` sealed (`Cone`/`Cube`/`Cylinder`/`Emanation`/`Line`/`Sphere`, each with `includesOrigin`), `casting_time.dart` sealed (`Action`/`Bonus`/`Reaction` with trigger text/`Minutes`/`Hours`), `spell_range.dart` sealed (`Self`/`Touch`/`Feet`/`Miles`/`Sight`/`Unlimited`), `spell_duration.dart` sealed (`Instantaneous`/`Rounds`/`Minutes`/`Hours`/`Days`/`UntilDispelled`/`Special`; concentration flag on duration cases), `spell_components.dart` sealed (`V`/`S`/`M` with cost-in-copper + consumed flag), `spell_target.dart` enum.

**`item/`** — `item.dart` sealed `Item` (`id`/`name`/`weightLb`/`costCp`/`rarityId`) + concrete `Weapon`/`Armor`/`Shield`/`Gear`/`Tool`/`Ammunition`/`MagicItem`, `WeaponCategory`/`WeaponType` Tier 0 enums, `RangePair` (long ≥ normal), sealed `AttunementPrereq` (`ByClass`/`BySpecies`/`ByAlignment`/`BySpellcaster`). Ranged weapons must declare `RangePair`; attunement prereq requires `requiresAttunement = true`.

**`monster/`** — `monster.dart` (Tier 1 root; legendary actions require slot budget ≥ 1), `stat_block.dart` (size/type/alignment refs, AC, HP, speeds, abilities, saves, skills, resistances/immunities/vulnerabilities, senses, languages, CR) + `MonsterSpeeds`/`MonsterSenses`, `monster_action.dart` sealed (`AttackAction`/`MultiattackAction`/`SaveAction`/`SpecialAction`), `legendary_action.dart`.

**`combat/`** — Tier 0 stateful machines `concentration.dart`, `action_economy.dart`, `turn_state.dart` (with `move`/`dash`/`reset`). `attack_resolution.dart` (`AttackRoll`/`DamageRoll`/`SaveRoll` value types). `combatant.dart` sealed (`PlayerCombatant` wraps `Character`, `MonsterCombatant` wraps `Monster` + per-instance HP + unique id for multiple-goblin scenarios). `TokenPosition`. `initiative.dart` (`InitiativeOrder` + stable `sortIds` helper). `encounter.dart` (non-empty combatants, unique ids, round auto-increments on order wrap).

**`world/`** — `world.dart` (installed-package registry, duplicate detection), `InstalledPackage`, `PackageVersion`, `campaign.dart` (narrative state; `lastPlayedAt` ≥ `createdAt`), `npc.dart` (tracked NPC with optional `monsterId` template reference).

Design choices locked in this tier:
- **Id-equality on all Tier 1 entities** — `Character`/`Spell`/`Monster`/`Item`/`World`/`Campaign`/`Npc` all `==` by namespaced id. Value types (`RangePair`, `TokenPosition`, `ActionEconomy`, `TurnState`, `TypedDice`, `SaveSpec`, `Concentration`) use field equality.
- **`Character.armorClassBase()` is a placeholder** — returns `10 + dex.mod`. Full armor/shield/effect-aware AC computation deferred to Doc 11 combat engine; callers that need accuracy must use the engine, not this shortcut. Documented in the method comment.
- **Sealed Item uses `implements`** — subclasses carry their own fields (no shared constructor), so `implements Item` beats `extends`. All subclasses in the same library so `sealed` still gates exhaustive switches.
- **`SpellDuration` separate from `EffectDuration`** — spell durations carry concentration as a sibling flag (not a wrapper) so the UI's "Concentration, up to 1 minute" pattern renders naturally.
- **`MonsterCombatant` carries its own id**, not the `Monster` definition's, so "Goblin #1" and "Goblin #2" share a definition but diverge in combat state.
- **3-item attunement cap** enforced at the `Inventory` factory — matches SRD.

**Blockers that auto-unblock now that Doc 01 has landed:**
- Doc 04 Step 5 (schema dir deletion) — replace `WorldSchema` / `EntityCategorySchema` / `FieldSchema` consumers with typed entities file-by-file.
- Doc 04 Step 7 (drift v5 drop+recreate) — needs Doc 03 typed tables.
- Docs 02 (GameSystem interface), 11 (combat engine), 12 (spell system), 13 (damage resolver), 14 (typed package format), 15 (SRD core package) can now begin — all reference the domain types that now exist.

### 2026-04-19 — Doc 02 GameSystem abstraction (🟣 partial)

Scope-narrowed first pass. Implementation landed:

| File | Purpose |
|---|---|
| [`domain/game_system/game_system.dart`](../../flutter_app/lib/domain/game_system/game_system.dart) | `abstract interface class GameSystem` — `id` / `displayName` / `version` / `autoInstallPackages` |
| [`domain/game_system/built_in_package.dart`](../../flutter_app/lib/domain/game_system/built_in_package.dart) | `BuiltInPackage` value type for bundled auto-install content |
| [`domain/game_system/game_system_registry.dart`](../../flutter_app/lib/domain/game_system/game_system_registry.dart) | in-process registry with `register` / `byId` / `contains` / `all` / `clear` + duplicate-id guard |
| [`domain/dnd5e/dnd5e_game_system.dart`](../../flutter_app/lib/domain/dnd5e/dnd5e_game_system.dart) | `Dnd5eGameSystem` metadata + SRD Core auto-install entry |
| [`domain/pathfinder/pathfinder_game_system.dart`](../../flutter_app/lib/domain/pathfinder/pathfinder_game_system.dart) | compile-test-only Pathfinder stub (NOT registered in prod) |
| [`application/providers/game_system_provider.dart`](../../flutter_app/lib/application/providers/game_system_provider.dart) | `gameSystemRegistryProvider` wiring only D&D 5e |

**Deliberately deferred to later docs** so the interface stays minimal until its consumers exist:
- `driftTables` getter — lands with Doc 03 typed Drift schema.
- `buildCharacterCreationFlow` / `buildCharacterSheet` / `buildCombatTracker` — land with Docs 10/11/32 as their UI arrives.
- `packageImporter` getter — lands with Doc 14 typed package format.
- `routes` getter — lands with the go_router migration.

The interface grows additively in those docs; Pathfinder stub tracks the same shape.

9 tests cover registry invariants, dnd5e SRD manifest, and Pathfinder stub conformance.

### 2026-04-19 — Doc 03 typed Drift schema (🟣 partial)

Additive first pass — new Doc 03 typed tables ship **alongside** the v5 entity/world_schema tables so existing consumers keep working until Doc 04 Step 5 lands. Schema version bumps **5 → 6**; on upgrade the new tables are `createTable`'d, nothing is dropped.

**New tables (20 total) — all empty on fresh install; populated by packages (Doc 14/15).**

- **12 Tier 1 catalog tables** — [`catalog_tables.dart`](../../flutter_app/lib/data/database/tables/catalog_tables.dart): `Conditions`, `DamageTypes`, `Skills`, `Sizes`, `CreatureTypes`, `Alignments`, `Languages`, `SpellSchools`, `WeaponProperties`, `WeaponMasteries`, `ArmorCategories`, `Rarities`. Shared shape via private `_CatalogTable` base: `id` (namespaced PK) + `name` + `bodyJson` + `sourcePackageId` + timestamps. Query by id/name in-memory after bulk load — catalogs are small (~17 conditions, ~14 damage types).
- **8 D&D 5e content tables** — [`dnd5e_content_tables.dart`](../../flutter_app/lib/data/database/tables/dnd5e_content_tables.dart): `Monsters` (with `statBlockJson` instead of bodyJson per spec), `Spells` (with typed `level` + `schoolId` columns for filter queries), `Items` (with `itemType` + optional `rarityId`), plus `Feats`, `Backgrounds`, `SpeciesCatalog` (Dart class name clashes with `Species` in generated mapper output — stored as SQL table `species` via `tableName` override), `Subclasses` (with `parentClassId` for parent-class FK), `ClassProgressions`.

Design choices locked in this pass:
- **JSON-blob over per-field columns** for read-mostly catalog data. Per Doc 03 §JSON-Blob Justification: whole entity loaded for display, no per-field SQL queries beyond id/name/level/school/itemType, schema evolves without DB migration.
- **`sourcePackageId` column** on every catalog/content table powers "uninstall package X deletes all its rows" via a single `DELETE WHERE sourcePackageId = ?`. Verified by test.
- **Additive migration** — the v4→v5 drop-everything-on-upgrade policy from the spec is deferred to the Doc 04 Step 7 pass when `entities` + `world_schemas` actually become removable. Doing both at once would mid-flight users' worlds.
- **`SpeciesCatalog` vs generated `Species`** — the Drift class name is `SpeciesCatalog` to avoid colliding with future Dart mappers named `Species`; the SQL table name stays `species` for spec compliance.

**Deliberately deferred to later passes:**
- `characters` + 7 character_* tables (needs consumer migration off `entities`).
- Reworked `encounters` / `combatants` / `combatant_conditions` / `combatant_concentration` (existing tables stay until combat engine rework — Doc 11).
- Drop `entities` + `world_schemas` + template_* columns on `campaigns` — Doc 04 Step 5/7.
- `game_system_id` column on `campaigns` — lands with Doc 02 campaign-creation wiring.
- Indexes listed in Doc 03 §Indexes — land with the repository layer that queries them.

10 tests cover: schema version, empty-on-create for all 20 tables, insert/select round-trips on distinctive shapes (Spells/Items/Monsters/SpeciesCatalog/Subclasses/Conditions), and uninstall-by-package cascade delete.

### 2026-04-19 — Doc 14 typed package format (🟣 partial)

First pass lands the in-memory package pipeline. JSON file parsing + export are deferred to Doc 15 when typed per-entity codecs get written alongside the SRD content.

**New code:**

| File | Purpose |
|---|---|
| [`domain/dnd5e/package/dnd5e_package.dart`](../../flutter_app/lib/domain/dnd5e/package/dnd5e_package.dart) | `Dnd5ePackage` container — metadata + 12 catalog lists + 8 content lists, all unmodifiable. `namespaced()` rewrites every local id + intra-package ref to `<slug>:<localId>`. |
| [`domain/dnd5e/package/catalog_entry.dart`](../../flutter_app/lib/domain/dnd5e/package/catalog_entry.dart), [`content_entry.dart`](../../flutter_app/lib/domain/dnd5e/package/content_entry.dart) | Transport shapes matching Doc 03 Drift columns — carry `bodyJson` verbatim so the importer writes what it gets. |
| [`domain/dnd5e/package/package_slug.dart`](../../flutter_app/lib/domain/dnd5e/package/package_slug.dart) | `[a-z][a-z0-9_]{0,31}` slug regex per Doc 14 §Validation. |
| [`domain/dnd5e/package/content_hash.dart`](../../flutter_app/lib/domain/dnd5e/package/content_hash.dart) | `computeContentHash` — sha256 over canonical content form (sorted by id within each table, metadata excluded). |
| [`domain/dnd5e/package/conflict_resolution.dart`](../../flutter_app/lib/domain/dnd5e/package/conflict_resolution.dart) | `ConflictResolution.{skip, overwrite, duplicate}` for same-source re-installs. |
| [`domain/dnd5e/package/import_report.dart`](../../flutter_app/lib/domain/dnd5e/package/import_report.dart) | `ImportReport` (per-table insert counts + warnings) + sealed `PackageImportResult.{success, error}`. |
| [`domain/dnd5e/package/package_validator.dart`](../../flutter_app/lib/domain/dnd5e/package/package_validator.dart) | Structural checks: formatVersion, gameSystemId, slug, duplicate local ids, spell level bounds, runtime-extension presence. |
| [`data/database/tables/installed_packages_table.dart`](../../flutter_app/lib/data/database/tables/installed_packages_table.dart) | Tracks installed packages (distinct from legacy v5 `packages`). Schema v6 → **v7** additive. |
| [`application/dnd5e/package/dnd5e_package_importer.dart`](../../flutter_app/lib/application/dnd5e/package/dnd5e_package_importer.dart) | Namespacing + validation + hash check + conflict handling + transactional catalog/content writes via `INSERT OR REPLACE`. |

**Behaviour locked:**
- **Idempotent namespacing** — already-namespaced ids (any `foo:bar`) pass through untouched, so `pkg.namespaced().namespaced()` equals `pkg.namespaced()`. Lets a package reference a dependency's already-installed catalog.
- **Canonical content hash** — sorted by id within each table; metadata (id, name, version, author, tags, …) is explicitly *not* hashed, matching Doc 14 §File Format. Result: content-equivalent packages hash identically even if authored in different order or repackaged with new metadata.
- **Conflict resolution on re-install** — match is by `sourcePackageId`, not slug (handles rename-on-duplicate correctly). `overwrite` deletes every catalog/content row tagged with the existing slug, then writes the new set. `skip` returns success with a warning. `duplicate` is an error because the caller must supply the fresh slug (e.g. `srd_2`) on the package itself — the importer does not invent one.
- **Transactional writes** — every catalog + content insert for one package runs inside `db.transaction`. Validation short-circuits before any write, so a package with duplicate local ids leaves the DB untouched (verified by test).
- **Runtime-extension gate** — `requiredRuntimeExtensions` must resolve against the process-wide `CustomEffectRegistry` (Doc 01 Tier 2) before import proceeds. Same-id handling fixes "user opens a package that needs `srd:wish` but the app doesn't ship it."

**Deferred:**
- **JSON file format** (`.dnd5e-pkg.json` parser/emitter) — lands with Doc 15 where typed codecs for Condition/Spell/Monster/etc. also arrive. Today's callers construct `Dnd5ePackage` in memory.
- **Zip bundling + images** — out of scope per Doc 14 §Open Questions.
- **Marketplace download + signature verification** — Doc 14 §Marketplace Integration, lands with Docs 20-25.
- **Dangling-reference validator** (`contentRegistryValidator`) — stubbed-out for now; proper check requires Doc 15 typed decoder to inspect effect-descriptor references inside `bodyJson`. Current validator catches duplicate-ids + slug + extensions only.

29 new tests (slug 3, hash 5, package 5, validator 8, importer 9) — namespacing idempotency, hash stability across order, hash excludes metadata, overwrite deletes prior rows, skip preserves them, duplicate errors without fresh slug, validator short-circuits before writes, runtime-extension enforced.

### 2026-04-19 — Doc 11 combat engine resolvers (🟣 partial)

First crisp-piece pass: damage + death-save pure resolvers + dice facade. The remaining Doc 11 surface (EncounterService state machine, UI tracker, player view, player-action protocol) is deferred — builds directly on these pure pieces but needs combatant HP/tempHp/resistance plumbing that lands with the repository layer.

**New code:**

| File | Purpose |
|---|---|
| [`application/dnd5e/combat/dice.dart`](../../flutter_app/lib/application/dnd5e/combat/dice.dart) | `Dice` facade wrapping `dart:math.Random` — `d4`/`d6`/`d8`/`d10`/`d12`/`d20`/`d100` + `roll('2d6+3')` via the existing `DiceExpression` parser. Seedable for deterministic replay. |
| [`application/dnd5e/combat/target_defenses.dart`](../../flutter_app/lib/application/dnd5e/combat/target_defenses.dart) | `TargetDefenses` read-only view (currentHp, maxHp, tempHp, resistances, vulnerabilities, damageImmunities, isPlayer) — lets the resolver stay pure without depending on the full `Combatant` sealed hierarchy. Validates HP bounds + namespaced damage-type ids. |
| [`application/dnd5e/combat/damage_instance.dart`](../../flutter_app/lib/application/dnd5e/combat/damage_instance.dart) | `DamageInstance` — amount + typeId + isCritical + fromSavedThrow/savedSucceeded + optional sourceSpellId. Factory guards `savedSucceeded ⇒ fromSavedThrow`. |
| [`application/dnd5e/combat/damage_outcome.dart`](../../flutter_app/lib/application/dnd5e/combat/damage_outcome.dart) | `DamageOutcome` — amountAfterMitigation, absorbedByTempHp, newCurrentHp, newTempHp, dropsToZero, concentration fields, instantDeath, deathSaveFailuresToAdd. |
| [`application/dnd5e/combat/damage_resolver.dart`](../../flutter_app/lib/application/dnd5e/combat/damage_resolver.dart) | `DamageResolver.resolve(TargetDefenses, DamageInstance) → DamageOutcome`. Pure function implementing Doc 11 §Damage Application Pipeline order: immunity zeroes → resistance halves → vulnerability doubles → save-for-half halves → temp HP absorbs → subtract from currentHp → concentration DC max(10, floor(amt/2)) capped 30 → PC Massive Damage → death-save failures. |
| [`application/dnd5e/combat/death_save_resolver.dart`](../../flutter_app/lib/application/dnd5e/combat/death_save_resolver.dart) | `DeathSaveResolver` — seedable roll + pure `apply(DeathSaves, roll) → DeathSaves`. Natural-20 regenerates 1 HP and clears state, natural-1 counts as two failures, 10+ success, 2..9 failure. |

**Behaviour locked:**
- **Resolver is pure** — no RNG, no Combatant mutation, no follow-up side effects. Callers write the outcome back and raise the concentration-save / death-save prompts. Makes the resolver trivially unit-testable + deterministic under replay.
- **Order-sensitive mitigation** — resistance before vulnerability before save-for-half. A Fire-resistant wizard in a failed-save Fireball takes `amt/2`; succeed-save on the same hit takes `amt/4`. Verified with a test.
- **Immunity short-circuits the whole pipeline** — no temp HP consumed, no concentration check fired, no death-save failure added. Prevents "0-damage hit still broke my wizard's concentration" regressions.
- **Dropping to 0 ≠ hit at 0** — a PC crossing from >0 to 0 HP gets Unconscious (handled by caller), *no* death-save failure. Subsequent hits while already at 0 add 1 failure (2 on crit per SRD). Verified.
- **Massive Damage** — `isPlayer && hpAfter == 0 && (remainder - currentHp) >= maxHp` triggers `instantDeath`. Monsters never trigger it (flag stays false).
- **DeathSaves encapsulates transitions** — resolver delegates stable/dead logic to the existing `DeathSaves` value class so state machine + resolver cannot disagree.

**Deferred (remainder of Doc 11):**
- EncounterService (`startCombat` / `nextTurn` / `applyDamage` / `applyCondition` / etc.) — needs repository layer + Combatant tempHp/resistance fields.
- Combat tracker UI + player read-only view — deferred to Docs 32/33/25.
- Condition duration ticking integration + compiled-tag lookups (`ConditionInteraction`) — needs Doc 15 SRD content.
- Turn-end hook + reaction refresh wiring on `Combatant.copyWith`.

42 new tests: Dice range + seed stability, TargetDefenses bounds + content-id validation, DamageInstance guards, DamageResolver pipeline (base + temp HP + concentration + dropsToZero + Massive Damage + death-save failures; 22 cases), DeathSaveResolver branches + apply folds (8 cases).

### 2026-04-19 — Doc 12 spell system foundations (🟣 partial)

First pass covers pure-logic pieces: slot-table math, Pact progression, concentration DC formula, AoE grid coverage. The cast service + rest service + validator (component/prepared/slot checks) + UI overlay are deferred — all consume the pieces shipped here.

**Extended:**

| File | Purpose |
|---|---|
| [`domain/dnd5e/character/caster_kind.dart`](../../flutter_app/lib/domain/dnd5e/character/caster_kind.dart) | New `CasterKind.{none, full, half, third, pact}` enum. |
| [`domain/dnd5e/character/character_class.dart`](../../flutter_app/lib/domain/dnd5e/character/character_class.dart) | Adds `casterKind` + `casterFraction` fields. Factory defaults `casterFraction` from kind (full→1.0, half→0.5, third→1/3, pact→0). Validates `fraction ∈ [0, 1]` and `kind == none ⇒ fraction == 0`. Additive — existing callers default to `none`. |

**New code:**

| File | Purpose |
|---|---|
| [`application/dnd5e/spell/spell_slot_progression.dart`](../../flutter_app/lib/application/dnd5e/spell/spell_slot_progression.dart) | Structural 20-row slot table from SRD §17.1. `slotsForCasterLevel(cl)` returns an unmodifiable 9-element list (level 1..9). `cl == 0` → all zeros. |
| [`application/dnd5e/spell/multiclass_slot_calculator.dart`](../../flutter_app/lib/application/dnd5e/spell/multiclass_slot_calculator.dart) | `combinedCasterLevel = floor(sum(level * casterFraction))`. Pact classes + non-casters excluded. Unknown class ids skipped (future dangling-ref pass warns separately). Takes a `String → CharacterClass?` resolver so tests and prod share math without a live `ContentRegistry`. |
| [`application/dnd5e/spell/pact_magic_table.dart`](../../flutter_app/lib/application/dnd5e/spell/pact_magic_table.dart) | `PactMagicTable.forLevel(1..20) → PactMagicEntry(slots, slotLevel)`. Separate progression for `casterKind == pact`; short-rest refresh handled by rest service, not here. |
| [`application/dnd5e/spell/concentration_dc.dart`](../../flutter_app/lib/application/dnd5e/spell/concentration_dc.dart) | `ConcentrationDc.forDamage(n) = min(30, max(10, n~/2))`. Shared formula — Doc 11 DamageResolver and Doc 12 concentration check cannot drift. |
| [`domain/dnd5e/spell/grid_cell.dart`](../../flutter_app/lib/domain/dnd5e/spell/grid_cell.dart) | `GridCell(col, row)` + `GridDirection.{north,south,east,west}`. Chebyshev distance helper + translate. 5 ft/cell constant. |
| [`domain/dnd5e/spell/area_of_effect.dart`](../../flutter_app/lib/domain/dnd5e/spell/area_of_effect.dart) | Adds `coverage(GridCell origin, GridDirection dir) → Set<GridCell>` to the sealed AoE hierarchy. |

**Coverage math locked:**
- **Sphere / Emanation / Cylinder** — Chebyshev disc: cells where `chebyshevTo(origin) <= radius / 5` per SRD §8.2. Radius rounds up (10 ft = 2 cells, 12 ft = 3). Cylinder collapses to sphere on 2D maps.
- **Cone** — width at distance d equals d. On the grid, row at k cells gets `2k + 1` cells wide centred on the cone's axis. Excludes origin. Direction rotates `(forward, side)` into cardinal `(dx, dy)`.
- **Cube** — N-cell-wide face flush with origin, extruded N cells in direction. Square footprint.
- **Line** — `length × width` rectangular strip starting one cell forward of origin. Excludes caster's square.
- **Direction helper** `_cellAt` is the single rotation point — cones, cubes, and lines share the same four-direction map so orientation cannot disagree between shapes.
- **Total-cover filtering is the caller's job** — Doc 12 §Total Cover. MVP: DM manually deselects. Raycast filtering lands with Doc 33 battlemap interaction.

**Multiclass math locked:**
- **Floor once at the end** — `floor(sum(level * fraction))`, not per-class. Paladin 5 + AT 7 = `floor(2.5 + 2.33) = 4`, not `2 + 2 = 4` by accident. Verified with a wizard-3 + paladin-5 + AT-3 test: `floor(3 + 2.5 + 1.0) = 6`.
- **Pact excluded** — Warlock levels never add to the multiclass sum; they read `PactMagicTable` independently. A Warlock 5 / Wizard 3 gets the Wizard-3 slot array plus Warlock-5 pact slots side by side.
- **Single-class collapses** — the calculator handles single-class casters without branching; callers never need two code paths.

**Deferred (remainder of Doc 12):**
- `SpellCastValidator` (component / prepared / slot-level / silenced / free-hand checks) + `SpellCastService` — need Tier 1 `Spell` typed decoder (Doc 15) and Combatant silenced state.
- `SpellSlotRefreshService` (short-rest pact refresh, long-rest full-caster refresh, Wizard Arcane Recovery interactive flow) — needs live character persistence.
- `ConcentrationManager.checkConcentration` — reads compiled `ConditionInteraction` tags (Doc 15 SRD content).
- AoE preview widget + battlemap overlay — Doc 33 surface.
- Total-cover raycast filter — Doc 33.
- One-leveled-spell-per-turn enforcement — `TurnState.appliedThisTurn` already exists; wiring lands with `SpellCastService`.

40 new tests: slot progression bounds + unmodifiability (6), multiclass calculator across single/half/third/pact/non-caster/empty/unknown combos (10), PactMagicTable endpoints + out-of-range (5), ConcentrationDc floor/cap/negative (4), AoE coverage for Sphere/Emanation/Cylinder/Cone/Cube/Line + GridCell helpers (15).

### 2026-04-19 — Doc 13 damage pipeline foundations (🟣 partial)

Pure-function pipeline pieces for the attack → damage → save flow. Builds on top of Doc 11's single-type `DamageResolver` + Doc 12's `ConcentrationDc` — adds advantage-aware d20 rolling, attack resolution with cover, multi-type damage bundling with per-type mitigation, and the saving-throw resolver.

**New code:**

| File | Purpose |
|---|---|
| [`application/dnd5e/combat/d20_roller.dart`](../../flutter_app/lib/application/dnd5e/combat/d20_roller.dart) | `D20Roller` + `D20Outcome` — one roll produces `{chosen, other}` so advantage/disadvantage UI can display both faces. Seedable. Shared by attack + save resolvers. |
| [`application/dnd5e/combat/attack_roll.dart`](../../flutter_app/lib/application/dnd5e/combat/attack_roll.dart) | `AttackRollInput` (abilityMod + pb + flatBonus + AC + coverAcBonus + advantage), `AttackRollResult`, `AttackResolver`. Pure. Natural 20 always crits; natural 1 always fumbles (SRD). Cover folds into `effectiveArmorClass`. |
| [`application/dnd5e/combat/typed_damage.dart`](../../flutter_app/lib/application/dnd5e/combat/typed_damage.dart) | `TypedDamage` — `Map<typeId, int>` bundle for weapon-with-rider + multi-element spells. Validates namespaced type ids + non-negative amounts + `savedSucceeded ⇒ fromSavedThrow` invariant. |
| [`application/dnd5e/combat/multi_type_damage_resolver.dart`](../../flutter_app/lib/application/dnd5e/combat/multi_type_damage_resolver.dart) | `MultiTypeDamageResolver.resolve(TargetDefenses, TypedDamage) → MultiTypeDamageOutcome`. Applies immunity/resist/vuln **per type**, sums, halves on successful save, absorbs temp HP, subtracts HP, emits concentration DC + Massive Damage + death-save failures. Returns per-type `TypedDamageBreakdownRow` for UI explanation toasts. |
| [`application/dnd5e/combat/save_resolver.dart`](../../flutter_app/lib/application/dnd5e/combat/save_resolver.dart) | `SaveResolver` + `SaveInput` + `SaveResult` + `SaveResolution.{rolled, autoSucceed, autoFail}`. Pure. Auto-fail wins when both auto-flags set (matches Doc 01 Tier 2 `ModifySave` invariant). |

**Behaviour locked:**
- **Per-type then total** — resist/vuln/imm applied inside each bundle entry; save-for-half halves the **sum** after per-type mitigation. Flametongue hit on a fire-resistant troll: slashing 7 full + fire 10 → 5 = 12 total (verified by test).
- **Immunity short-circuits per type** — resistance and vulnerability both become no-ops when immunity is set on the same type. `TypedDamageBreakdownRow.resisted/vulnerable` fields stay false in that case so the UI doesn't show confusing "resisted but immune" chips.
- **Shared d20 semantics** — attack + save both route through `D20Roller.roll(AdvantageState)`, which already exists in Doc 01 core. Advantage + disadvantage combine per SRD (cancel to normal on any mix).
- **Natural-20 attack bypasses mitigation math** — a nat 20 always hits regardless of the modifier total being less than effective AC. Natural 1 always misses, even with a +12 bonus against AC 5.
- **Auto-fail > auto-succeed** — prevents "Paralyzed (auto-fail STR/DEX) + Bless (no auto-succeed)" ambiguity. Matches the `ModifySave` descriptor's construction-time guard.
- **Massive Damage + death-save accrual reuse the Doc 11 formula** — the multi-type resolver emits the same `DamageOutcome` shape so downstream (EncounterService) handles both single-type and multi-type paths identically.

**Deferred (remainder of Doc 13):**
- **Feature-effect driven attack/damage modification** — `FeatureEffect.modifyAttackRoll` / `modifyDamageRoll` / `modifyAttackAgainst` — needs the compiled `EffectDescriptor` dispatch layer from Doc 05 rule-engine replacement work.
- **Weapon/spell damage builder** (assembles `DiceExpression[]` + mods + rider types from a Weapon/Spell definition, doubles dice on crit) — needs typed Weapon/Spell decoder from Doc 15.
- **AoE orchestrator** (one roll, multi-target save-for-half) — wraps `MultiTypeDamageResolver` over a target set from `AreaOfEffect.coverage` (already landed in Doc 12). Trivial follow-up once combatant positioning is wired.
- **ConditionInteraction auto-fail aggregation** (Paralyzed/Stunned auto-fail STR/DEX feeding into `SaveInput.autoFail`) — needs SRD conditions with compiled tags from Doc 15.
- **Concentration save wiring** (Dc from Doc 12 + roll via `SaveResolver` + break vs keep) — trivial stitch, lives in `ConcentrationManager` (Doc 12 deferred).

37 new tests: D20Roller advantage/disadvantage/normal + nat-20/nat-1 detection (4), AttackResolver hit/miss/crit/fumble/cover/advantage/flatBonus (8), TypedDamage guards (6), MultiTypeDamageResolver per-type mitigation + save-half + temp HP + drop-to-zero + Massive Damage + death-save accrual + concentration DC (13), SaveResolver pass/fail/auto-succeed/auto-fail precedence/advantage/flatBonus (7).

### 2026-04-19 — Doc 42 fresh-start reset primitives (🟣 partial)

Pure purger + bootstrap glue for the v4→v5 reset flow. All three primitives are shippable now; wiring into `main.dart::_BootstrapGate` is deferred until Doc 04 Step 7 (drift v5 drop+recreate) lands — otherwise the "your data has been removed" dialog would fire before the DB has actually been dropped.

**New code:**

| File | Purpose |
|---|---|
| [`data/storage/legacy_data_purger.dart`](../../flutter_app/lib/data/storage/legacy_data_purger.dart) | `LegacyDataPurger` — deletes `templates/` / `package_cache_v4/` / `rule_eval_cache/` under an injected `cacheRoot` and removes `template_*` / `rule_*` keys from an injected `SharedPreferences`. Returns a `PurgeReport` so callers can distinguish fresh-install from v4-upgrade. Best-effort: locked-file errors on Windows are swallowed rather than aborting startup. |
| [`data/storage/v5_reset_bootstrap.dart`](../../flutter_app/lib/data/storage/v5_reset_bootstrap.dart) | `V5ResetBootstrap.runIfNeeded` — idempotent wrapper. Checks `v5_reset_complete` flag; if already true → `alreadyComplete`. Otherwise runs the purger, sets the flag, and classifies the result as `freshInstall` (nothing removed) or `upgradedFromV4` (something removed → upgrade dialog should show). |
| [`presentation/dialogs/v5_upgrade_notice_dialog.dart`](../../flutter_app/lib/presentation/dialogs/v5_upgrade_notice_dialog.dart) | `V5UpgradeNoticeDialog.show(context, backupPath)` — one-time Material `AlertDialog` explaining the Template→native-D&D-5e switch. Optional `backupPath` slot surfaces the v4 DB copy when the optional backup step lands. |

**Behaviour locked:**
- **Fresh install vs upgrade disambiguated by purge report, not by Drift migration hook.** Before Doc 04 Step 7 lands, the Drift `from < 5` migration doesn't fire (schema already starts at v7 on fresh installs). The purger's removal count is the only reliable "this device had v4 data" signal available to the reset-flag path.
- **Prefs key `v5_reset_complete` is sticky.** Once set, subsequent launches skip the purger entirely — no repeated dialogs, no scanning of an empty cache dir.
- **Purger is injection-friendly.** Takes `cacheRoot` + `SharedPreferences` as constructor args so tests run on `Directory.systemTemp.createTemp` with `SharedPreferences.setMockInitialValues` — no `path_provider` plugin needed at test time.
- **Non-legacy prefs survive.** Only prefixes `template_` and `rule_` are touched; `welcome_seen`, theme, locale, and every other stored key is preserved.

**Deferred (remainder of Doc 42):**
- **Bootstrap wiring** — `_BootstrapGate._bootstrap()` should call `V5ResetBootstrap(cacheRoot: AppPaths.cacheDir).runIfNeeded()` after `AppPaths.initialize()`, stash the `V5ResetOutcome` in a provider, and have `DungeonMasterApp` consume it to show `V5UpgradeNoticeDialog` via `addPostFrameCallback`. Blocked on Doc 04 Step 7 so the dialog's "your data has been removed" copy is actually true.
- **Optional v4 DB backup** — `_backupV4DbBeforeReset` copies `dmt.sqlite` to `{appDocs}/backups/{timestamp}_v4_db.sqlite` before the Drift migration runs. Lives alongside the drift migration, so it also lands with Doc 04 Step 7.
- **Release notes copy** — content is authored in [`42-fresh-start-db-reset.md`](./42-fresh-start-db-reset.md); goes into the v5.0.0 `CHANGELOG.md` section once the release is cut.

9 new tests: `LegacyDataPurger` no-op on clean cache, removes legacy dirs but not siblings, removes legacy prefs keys but not siblings, `hasAnyRemovals` truthiness, idempotency (5). `V5ResetBootstrap` alreadyComplete short-circuit, freshInstall classification, upgradedFromV4 classification, sticky-flag on subsequent runs (4).

### 2026-04-19 — Doc 10 character creation state machine (🟣 partial)

Pure wizard foundations — state types + per-step validators that Doc 15's content tables can plug into without rewriting any of the core logic. UI widgets (Stepper / per-step panels / live preview) and the save-to-repository path are deferred until Doc 31 (UI component library) + Doc 15 (SRD Core catalog) land.

**New code:**

| File | Purpose |
|---|---|
| [`application/dnd5e/character_creation/ability_score_method.dart`](../../flutter_app/lib/application/dnd5e/character_creation/ability_score_method.dart) | `AbilityScoreGenerationMethod` enum + canonical `kStandardArray` multiset + `kPointBuyCosts` table (SRD §16.6) + `AbilityScoreValidator` (pure `validateStandardArray` / `validateRandom` / `validatePointBuy` / `validateBackgroundBonuses`). Background-bonus validator enforces the **2024 SRD Origin Feat +3 budget** (`+2/+1` on 2 listed OR `+1/+1/+1` on 3) — corrects Doc 10's stale "total +4" spec text. Cap-20 post-bonus enforced. |
| [`application/dnd5e/character_creation/hp_method.dart`](../../flutter_app/lib/application/dnd5e/character_creation/hp_method.dart) | `HpMethod` enum `{fixed, rolled}`. |
| [`application/dnd5e/character_creation/character_draft.dart`](../../flutter_app/lib/application/dnd5e/character_creation/character_draft.dart) | `CharacterDraft` value type + `DraftClassLevel`. Sentinel-based `copyWith` so callers can set a nullable field to `null` without losing the "field not touched" signal. Derived `totalLevel` getter. |
| [`application/dnd5e/character_creation/character_creation_step.dart`](../../flutter_app/lib/application/dnd5e/character_creation/character_creation_step.dart) | 7-step wizard enum + `next` / `previous` / `isFirst` / `isLast`. |
| [`application/dnd5e/character_creation/character_creation_state.dart`](../../flutter_app/lib/application/dnd5e/character_creation/character_creation_state.dart) | `CharacterCreationState` snapshot + `canAdvance` / `canGoBack` derived from the per-step validation map. Immutable `copyWith`. |
| [`application/dnd5e/character_creation/step_validator.dart`](../../flutter_app/lib/application/dnd5e/character_creation/step_validator.dart) | `CharacterDraftValidator` + `StepValidationContext`. Single `validate(step, draft, ctx)` entry point. Context fields are all nullable so partial content (pre-Doc-15) skips the relevant check instead of blocking — every catalog-derived constraint (subclass-choice level, required skill count, required language count, listed abilities, equipment option count) comes through the context and is opt-in. |

**Behaviour locked:**
- **Validator is pure.** No RNG, no DB, no content lookup. The Notifier (future work) pulls content hints out of the catalogs and hands them in via `StepValidationContext`. This keeps the rule set testable in isolation and lets the Notifier load classes/backgrounds/species lazily.
- **Partial-content degrades to fewer checks, not to crashes.** Missing a hint (e.g. `subclassChoiceLevel` null) → that sub-check is skipped. "Some validation is better than none" for the pre-Doc-15 interim.
- **Class-level total = starting level** enforced in Step 1 — caught before the user reaches Step 5 where HP depends on the sum.
- **Origin Feat SRD fix baked in.** Doc 10 spec text says "+4 total" but 2024 SRD says +3. The code matches SRD; the spec doc will be corrected in a follow-up.
- **Review step is always valid** — earlier steps enforce the invariants.

**Deferred (remainder of Doc 10):**
- **`CharacterCreationNotifier`** — Riverpod `StateNotifier` with per-field setters (`selectClass`, `selectBackground`, `setBaseScore`, …). Needs a content repository provider to look up subclass-choice level, skill count, background listed abilities, equipment options — blocked on **Doc 15**.
- **`_buildCharacter(draft)` save path** — assembles a concrete `Character` from the draft (applies class L1 features, species traits, background bonuses, computes HP/AC/passives/spell slots). Blocked on Doc 15 content + Doc 11/12/13 services (AC computation, spell slot initial state).
- **UI screens** — `CharacterCreationScreen` + mobile/tablet/desktop layouts + per-step widgets (`_StartModeStep` through `_ReviewStep`) + live preview panel. Blocked on **Doc 31**.
- **Higher-level start sub-flow** — ASI/feat picks per level, subclass at appropriate level, bonus equipment by tier. Blocked on Doc 15 + class-progression tables (already in Doc 03 schema, populated by Doc 15).
- **Character drafts persistence** — save/resume incomplete drafts (SRD §16 Open Question #2). Deferred per spec.

23 new tests: `AbilityScoreValidator` — Standard Array accept/reject-dupes/reject-missing (3), Point Buy accept-27/reject-overspend/reject-below-8/reject-above-15/cost-table (5), Random accept-[3,18]/reject-below-3/reject-above-18 (3), Background Bonus +2/+1 + +1/+1/+1 + non-listed reject + total-≠-3 + shape reject + cap-20 (6). `CharacterCreationStep` — ordering / isFirst-isLast / next-previous chain (3). `CharacterDraft` — empty defaults / copyWith sentinel / copyWith null clears / totalLevel / DraftClassLevel equality / DraftClassLevel subclass clear (6). `CharacterCreationState` — initial / canAdvance false / canGoBack / null-message-is-clean (4). `CharacterDraftValidator` — per-step positive + negative paths across all 7 steps (~30 scenarios, merged into the five method files above).

### 2026-04-19 — Doc 15 package file format codec (🟣 partial)

Serialize/deserialize `Dnd5ePackage` ↔ JSON. Unblocks Doc 14's file-format parser/emitter and the Doc 15 asset-to-package bootstrap path. SRD content authoring itself (17 conditions, 14 damage types, ~361 spells, ~320 monsters, ...) still deferred — this turn ships only the pipes, not the content.

**New code:**

| File | Purpose |
|---|---|
| [`domain/dnd5e/package/dnd5e_package_codec.dart`](../../flutter_app/lib/domain/dnd5e/package/dnd5e_package_codec.dart) | `Dnd5ePackageCodec.encode(pkg) → Map<String, Object?>` + `decode(map) → Dnd5ePackage`. Defines the wire shape: top-level metadata + `catalogs: {...}` + `content: {...}`. Per-entity `body` / `statBlock` ride along as opaque JSON strings — domain-object decoders for Tier 1 entities (Condition, Spell, Monster, Item, Subclass) land with later turns without touching this file. |
| [`application/dnd5e/package/package_json_reader.dart`](../../flutter_app/lib/application/dnd5e/package/package_json_reader.dart) | `PackageJsonReader.readJson(String)` / `readMap(Map)` — thin wrapper that calls `jsonDecode` then hands off to the codec. Pointed `FormatException` messages for malformed or wrong-type fields. `PackageJsonWriter.writeJson(pkg, pretty: ...)` emits the compact ship-form or the `build_artifacts/` pretty-printed diff copy (per Doc 15 Open Question 2). |

**Behaviour locked:**
- **Default-safe defaults.** `gameSystemId` defaults to `dnd5e`, `formatVersion` to `2`, `sourceLicense` to empty string, `tags` / `requiredRuntimeExtensions` / every catalog + content list to empty. A minimal payload with only the 6 required fields (`id`/`packageIdSlug`/`name`/`version`/`authorId`/`authorName`) decodes cleanly.
- **Required fields fail loud.** Missing or wrong-typed required field → `FormatException('Missing or non-string field "x".')`. Wrong-typed catalog/content list entries → `FormatException('Field "conditions"[2] must be a JSON object …')` with the offending index.
- **Bodies stay opaque.** `body` / `statBlock` fields round-trip as strings the same way the Doc 14 importer already writes them verbatim to Drift. Per-entity codecs (`Spell.fromJson`, `Monster.fromJson`, …) plug into these strings later without a wire-format break.
- **Encode is idempotent.** `decode(encode(decode(encode(pkg))))` emits the same map as `decode(encode(pkg))` — verified by test.
- **Optional vs. required disambiguated.** `description` is nullable (stays `null` when absent/null in JSON); `sourceLicense` defaults to empty string when absent. Matches the `Dnd5ePackage` constructor contract.

**Deferred (remainder of Doc 15):**
- **SRD content authoring** — `assets/packages/srd_core/` (manifest + 12 catalog JSONs + spells/monsters/items/classes/subclasses/species/backgrounds/feats split sources). Depends on domain-object JSON codecs landing first for each Tier 1 entity.
- **Per-entity codecs** — `Condition.fromJson` / `DamageType.fromJson` / `Spell.fromJson` / `Monster.fromJson` / `Item.fromJson` / `Subclass.fromJson`. These turn the opaque `body` strings into typed domain objects at install time and feed the UI.
- **`tool:build_srd_pkg` CLI** — concatenates the split sources into a committed monolith `assets/packages/srd_core.dnd5e-pkg.json` + computes its `contentHash`.
- **`SrdBootstrapService`** — reads the monolith from `rootBundle`, calls `Dnd5ePackageImporter.import` inside a per-user transaction on first launch. Shows in `World > Settings > Installed Packages`.
- **`CustomEffect` implementations** — 9 whitelisted impl classes (WishImpl, WildShapeImpl, PolymorphImpl, AnimateDeadImpl, SimulacrumImpl, SummonFamilyImpl, ConjureFamilyImpl, ShapechangeImpl, GlyphOfWardingImpl) + startup registration in the existing `CustomEffectRegistry`.
- **CC BY 4.0 attribution UI** — `About > Content Licenses` screen + per-package detail view surfaces `sourceLicense` + `license_notice`.
- **SRD upgrade flow** — one-tap `overwrite` on the installed-packages entry when the bundled monolith is newer than the installed version.

11 new tests: codec round-trip on realistic fixture (1), encode idempotency (1), minimal-payload defaults (1), missing-required-field FormatException (1), wrong-type list FormatException with field name (1), null description preserved (1). Reader JSON-string parse (1), malformed JSON rejected (1), non-object root rejected (1). Writer compact-mode single-line (1), pretty-mode round-trips through reader (1).

### 2026-04-19 — Doc 15 Tier 1 catalog per-entity codecs (🟣 partial)

Second Doc 15 landing. Bridges opaque `CatalogEntry.bodyJson` strings ↔ typed Tier 1 domain objects for all 12 catalog classes. Unblocks SRD content authoring (JSON → domain) and lets `CharacterDraftValidator` eventually consume the live catalog registry.

**New code:**

| File | Purpose |
|---|---|
| [`domain/dnd5e/catalog/catalog_json_codecs.dart`](../../flutter_app/lib/domain/dnd5e/catalog/catalog_json_codecs.dart) | Top-level `xxxFromEntry(CatalogEntry) → X` + `xxxToEntry(X) → CatalogEntry` pairs for Condition, DamageType, Skill, Size, CreatureType, Alignment, Language, SpellSchool, WeaponProperty, WeaponMastery, ArmorCategory, Rarity. Preconditions: entry ids are **already namespaced** (`srd:stunned`, not `stunned`) — caller handles via `CatalogEntry.namespaced(slug)`. |

**Wire shape per class** (`body` JSON object):
- Condition: `{"description": string}` — effects deferred
- DamageType: `{"physical": bool}`
- Skill: `{"ability": Ability.name}`  (`"strength"` … `"charisma"`)
- Size: `{"spaceFt": num, "tokenScale": num}`
- CreatureType: `{}`
- Alignment: `{"lawChaos": LawChaosAxis.name, "goodEvil": GoodEvilAxis.name}`
- Language: `{"script": string|null}`
- SpellSchool: `{"color": "#RRGGBB"|null}`
- WeaponProperty: `{"flags": [PropertyFlag.name, ...], "description": string|null}` — flags serialize sorted for stable output
- WeaponMastery: `{"description": string}`
- ArmorCategory: `{"stealthDisadvantage": bool, "maxDexCap": int|null}`
- Rarity: `{"sortOrder": int, "attunementTierReq": int|null}`

**Behaviour locked:**
- **FormatException prefix is the entry id.** Every decode error ships as `<entry.id>: <reason>`, e.g. `srd:stealth: field "ability" has unknown enum value "bogus".` Lets importer logs point at the offending entry without extra context.
- **Missing optionals take domain defaults** (Condition.description = '', DamageType.physical = false, …). Explicit `null` on a nullable field stays null.
- **Unknown keys ignored** for forward compatibility.
- **Enum values use `.name`** (not toString, not index) — stable wire vocabulary independent of declaration order.
- **WeaponProperty.flags sorted** on encode so the emitted body is deterministic regardless of Set iteration order.

**Deferred (still remainder of Doc 15):**
- **`Spell.fromJson` / `Monster.fromJson` / `Item.fromJson` / `Subclass.fromJson`** — Tier 2 content codecs. More involved (`CastingTime`, `SpellRange`, `AreaOfEffect`, full `StatBlock`, …). Separate turn.
- **`EffectDescriptor` codec** — Condition.effects and every other effect-carrying class (spells, weapons, feats) need this. Wide surface.
- Everything already listed in the Doc 15 file-format codec entry above (SRD content, build_srd_pkg, SrdBootstrapService, 9 CustomEffect impls, CC BY 4.0 UI, upgrade flow).

27 new tests: Condition (3), DamageType (2), Skill (3), Size (2), CreatureType (1), Alignment (2), Language (2), SpellSchool (2), WeaponProperty (4), WeaponMastery (1), ArmorCategory (2), Rarity (2), shared FormatException-prefix-is-entry-id (1).

### Current test totals

`flutter analyze`: 0 issues. `flutter test`: **763 / 763 passing, 1 skipped** (was 736 at end of Doc 15 file-format codec; +27 Tier 1 catalog codec tests added).

---

## Pre-Destructive-Migration Audit (2026-04-19)

SRD 5.2.1 PDF + current codebase + Doc 04/42 plan audited before landing the v5 drop+recreate migration. Goal: be sure the engine actually works end-to-end before any irreversible schema change.

### Verdict

**Safe to proceed with Phase A. NOT safe to run Doc 04 Step 7 today.** App is pre-1.0 alpha (pubspec `5.1.0`, no prod tags past `alpha-v0.6.3`, no `CHANGELOG.md`) so there are no App Store users to regress. But local/beta tester DBs are still at risk, and the domain model has silent-failure gaps that would propagate into authored SRD content if we ship now.

### Release & Migration Reality

| Fact | Source | Implication |
|---|---|---|
| Version `5.1.0` pre-release | [`pubspec.yaml:4`](../../flutter_app/pubspec.yaml#L4) | Pre-MVP; breaking DB change acceptable |
| Latest tag `alpha-v0.6.3` only | `git tag` | No prod users to regress |
| Current drift `schemaVersion = 7` | [`app_database.dart:95`](../../flutter_app/lib/data/database/app_database.dart#L95) | Doc 42 v5 drop not yet wired — migration still additive |
| `from < 5` / `< 6` / `< 7` branches are all additive (create new tables, drop nothing) | [`app_database.dart:100-157`](../../flutter_app/lib/data/database/app_database.dart#L100-L157) | Beta tester v4 data still intact today; Step 7 destroys it |
| No v4 DB backup implementation (Doc 42 spec §124 proposed, not coded) | [`legacy_data_purger.dart`](../../flutter_app/lib/data/storage/legacy_data_purger.dart) touches caches only | Botched migration = unrecoverable beta data loss |
| Legacy SQLite file copy on AppPaths move leaves `.moved_to_dataroot` marker + preserves source | [`app_database.dart:182-193`](../../flutter_app/lib/data/database/app_database.dart#L182-L193) | Partial manual recovery possible for technical testers |
| Supabase not built (only abstract `SessionManager` skeleton exists) | [`data/network/session_manager.dart`](../../flutter_app/lib/data/network/session_manager.dart) | No cloud restore path; local backup is the only safety net |

### Domain Model Coverage vs SRD 5.2.1 (~65%)

**High-risk gaps** — silent content-authoring failures waiting to happen:

| Gap | SRD ref | Consequence |
|---|---|---|
| **Split movement** — `ActionEconomy` has binary move flag, not feet-remaining budget | p.14 ("move → action → move") | Fighter Dash-Attack-Dash and rogue kite patterns desync from engine |
| **Multiclass prerequisites** — no STR/DEX/INT/etc. ≥ 13 check | p.25 | Invalid multiclass accepted silently |
| **Attunement cap** — `Inventory` factory enforcement needs verification vs 3-item rule | p.102 | Possible overflow |
| **Cover +AC bonus** — no cover modifier path in [`attack_roll.dart`](../../flutter_app/lib/application/dnd5e/combat/attack_roll.dart) | p.15 (Half +2 / Three-Quarters +5 / Total unhittable) | Attack math wrong whenever cover applies |
| **Weapon-property auto-wiring** — Light doesn't auto-permit off-hand attack; Heavy doesn't auto-disadvantage STR/DEX<13; Finesse is domain-enum-only | p.89-90 | Content authors must wire each rule manually; fragile |
| **ASI auto-schedule** — no enforcement at levels 4/8/12/16/19 | p.24 | Each class definition must remember to add ASI rows |
| **Instant-death overflow arithmetic** — flag exists in `DamageOutcome` but arithmetic needs test against SRD wording | p.17 (damage ≥ max HP at 0 = instant death) | Possible off-by-one; requires dedicated test |
| **Surprise** — no `surprised` condition nor initiative-disadvantage hook | p.13 | Encounter setup silently wrong when ambush happens |

**Content catalog gaps** — must be fixed before SRD JSON authoring begins:

- **No `Tool` catalog class.** SRD ships ~17 tools (9 Artisan + 8 Other) with `ability` + utilize DC + craft list. Current 12-catalog set covers no tool concept. **Decision needed**: add `Tool` as a Tier 1 catalog class, or tuck tools into `Item` via a `ToolItem` subclass carrying `abilityForCheck` + `utilizeDc` + `craftsItemIds`.
- **Adventuring gear mechanics as effects.** Caltrops (DC 15 DEX or speed 0), Ball Bearings (DC 10 DEX or prone), Manacles (grapple), Net (restrained), Oil (fire-reactive), Holy Water (radiant vs Fiend/Undead), Healer's Kit (stabilize). These are **Utilize-action effects** — a new surface the current `EffectDescriptor` cases do not cover (no `UtilizeAction` target).
- **Spell scroll constants** — creator-independent scrolls use attack bonus `+5` + save DC `13`. Needs either a constant or inline.
- **Mounts + vehicles** — `Mount` + `Vehicle` stat blocks absent (MVP-acceptable deferral per Phase 3 non-goals).
- **Lifestyle / hirelings / spellcasting services** — Gameplay Toolbox (p.101-103), MVP-deferrable.

### The Critical Unknown

**No integration test yet proves the effect DSL + resolvers actually model a real spell end-to-end.** All 763 tests are unit-level. The first time a `Fireball`-as-JSON → decoded `Spell` → cast validator → AoE coverage → per-target save → multi-type damage → concentration DC round trips through the full stack will be when SRD content lands. Design risk: `EffectDescriptor` cases may not cover every SRD effect shape (e.g. Hold Person's auto-crit-on-melee-within-5-ft, Sleep's HP-pool targeting, Wall of Force's shape-over-time). A **three-spell smoke test** (Fireball, Hold Person, Bless) must pass before committing to the content-authoring sprint.

### Revised Phase A Sequence (blocker-safe)

Supersedes the original Phase A in `nested-percolating-cookie.md`:

1. **A0** — Verify `DamageResolver` instant-death arithmetic against SRD p.17. Read [`damage_resolver.dart`](../../flutter_app/lib/application/dnd5e/combat/damage_resolver.dart) + add targeted test.
2. **A1** — `EffectDescriptor` codec + **three-spell integration smoke test**. Pick Fireball (AoE + save-half + fire), Hold Person (save-or-auto-fail-condition), Bless (advantage bonus). JSON → decode → execute through resolvers end-to-end. Proves the shape works before authoring 361 spells.
3. **A2** — Fix high-risk domain gaps surfaced above: multiclass prereq, attunement cap verification, split-movement `MovementBudget`, cover-to-AC, weapon-property auto-wiring, surprise condition. Small commits, tests each.
4. **A3** — Add `Tool` catalog class (or `ToolItem` subclass, decided during the turn). Required before any equipment JSON.
5. **A4** — Doc 04 Step 5: delete [`lib/data/schema/`](../../flutter_app/lib/data/schema/) after verifying `allTemplatesProvider` unused + refactoring `character_editor_screen.dart` + `worlds_tab.dart` off it.
6. **A5** — Implement `_backupV4DbBeforeReset` (Doc 42 §124). Default-ON. Write to `{appDocs}/backups/{ts}_v4_db.sqlite` + log SHA256.
7. **A6** — Doc 04 Step 7 + Doc 42 wiring bundled. **Only after A0-A5 pass analyze + full test suite + manual smoke on a beta device with a pre-populated v4 DB.**

### Pre-flight Checklist — Must Be Green Before Step 7 Commit

- [ ] `rg 'WorldSchema|EntityCategorySchema|FieldSchema|generateDefaultDnd5eSchema|allTemplatesProvider' flutter_app/lib --type dart --glob '!**/migration/**' --glob '!**/test/**'` → 0 hits
- [ ] `_backupV4DbBeforeReset` writes backup + verifies SHA256 before purger runs
- [ ] `V5ResetBootstrap` wired in `_BootstrapGate._bootstrap()`; outcome in a provider; `V5UpgradeNoticeDialog` shown via `addPostFrameCallback`
- [ ] Fireball + Hold Person + Bless integration smoke tests round-trip and resolve correctly
- [ ] `flutter analyze` → 0 + `flutter test` → all green
- [ ] Beta test run on Linux desktop + Android emulator with pre-populated v4 DB → backup file exists, upgrade dialog shows, typed tables populated
- [ ] `CHANGELOG.md` seeded with v5.0.0 "Fresh start DB reset" entry + migration notes
- [ ] Alpha testers pinged (Discord/whatever) with screenshot of reset dialog before the tag cut

### Recommended Immediate Next Turn

**A0 + A1 bundle** — verify instant-death arithmetic + start `EffectDescriptor` codec paired with a Fireball integration smoke test. Proves the system works end-to-end before any destructive migration. Two turns max.
