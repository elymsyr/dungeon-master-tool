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
| 15 | [`15-srd-core-package.md`](./15-srd-core-package.md) | SRD 5.2.1 shipped as a package (assets build step + auto-install flow). Defines the whitelisted `CustomEffect` registry. | 01, 14 | ⚪ |

## Phase 2: Game Feature Specs (Sprint 2-4)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 10 | [`10-character-creation-flow.md`](./10-character-creation-flow.md) | 5-step wizard. State machine, per-step validation, level-1 vs higher-level paths. | 00, 01, 15 | ⚪ |
| 11 | [`11-combat-engine-spec.md`](./11-combat-engine-spec.md) | Manual combat tracker (MVP): initiative, turn state, action economy, condition expiration. Auto-resolve = future. | 00, 01 | ⚪ |
| 12 | [`12-spell-system-spec.md`](./12-spell-system-spec.md) | Slot tables, multiclass calculator, Pact Magic, concentration, AoE geometry. | 00, 01 | ⚪ |
| 13 | [`13-damage-resolver-spec.md`](./13-damage-resolver-spec.md) | Attack pipeline: crit, resistance/vuln/immunity, save-half, temp HP, concentration check. | 00, 01, 11 | ⚪ |
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
| 42 | [`42-fresh-start-db-reset.md`](./42-fresh-start-db-reset.md) | Drift v5 = drop+recreate. User-facing notice. Optional backup. | 03 | ⚪ |
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

### Current test totals

`flutter analyze`: 0 issues. `flutter test`: **545 / 545 passing, 1 skipped** (was 516 at end of Doc 03; +29 Doc 14 package-system tests added).
