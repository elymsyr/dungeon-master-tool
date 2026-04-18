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
- ⚪ **Not Started** — planned

---

## Phase 1: Foundation (Sprint 0-1) — blocking everything

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 00 | [`00-dnd5e-mechanics-reference.md`](./00-dnd5e-mechanics-reference.md) | Normative SRD 5.2.1 mechanics reference. Source of truth for all engine behavior. | — | 🟢 |
| 01 | [`01-domain-model-spec.md`](./01-domain-model-spec.md) | Typed Dart classes for Character, Monster, Spell, Item (sealed), Feat, Background, Species, CharacterClass, Subclass, Encounter, Combatant, Effect, etc. with invariants. | 00 | 🟡 |
| 02 | [`02-game-system-abstraction.md`](./02-game-system-abstraction.md) | `GameSystem` interface for future Pathfinder/CoC modularity. Stub Pathfinder example. | 01 | 🟡 |
| 03 | [`03-database-schema-spec.md`](./03-database-schema-spec.md) | Drift v5: drop `world_schemas` + template_* columns; add typed tables. Fresh-start reset (doc 42). | 01 | 🟡 |
| 04 | [`04-template-removal-checklist.md`](./04-template-removal-checklist.md) | ~40-file deletion order; dependency graph; per-step regression test plan. | 01, 03 | 🟡 |
| 05 | [`05-rule-engine-removal-spec.md`](./05-rule-engine-removal-spec.md) | Removal of RuleV2/RuleEngineV2; replacement pattern (effects as pure functions). | 01 | 🟡 |

## Phase 1.5: Mechanics / Content Decoupling — blocks Phase 2 implementation

The built-in dnd5e module ships **mechanics only** (rules engine, typed shapes, effect DSL). All concrete content (conditions, spells, monsters, classes, damage types, …) arrives via packages — including the SRD bundle. Docs 01/02/05/14 were revised; Doc 15 is new.

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 15 | [`15-srd-core-package.md`](./15-srd-core-package.md) | SRD 5.2.1 shipped as a package (assets build step + auto-install flow). Defines the whitelisted `CustomEffect` registry. | 01, 14 | 🟡 |

## Phase 2: Game Feature Specs (Sprint 2-4)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 10 | [`10-character-creation-flow.md`](./10-character-creation-flow.md) | 5-step wizard. State machine, per-step validation, level-1 vs higher-level paths. | 00, 01, 15 | 🟡 |
| 11 | [`11-combat-engine-spec.md`](./11-combat-engine-spec.md) | Manual combat tracker (MVP): initiative, turn state, action economy, condition expiration. Auto-resolve = future. | 00, 01 | 🟡 |
| 12 | [`12-spell-system-spec.md`](./12-spell-system-spec.md) | Slot tables, multiclass calculator, Pact Magic, concentration, AoE geometry. | 00, 01 | 🟡 |
| 13 | [`13-damage-resolver-spec.md`](./13-damage-resolver-spec.md) | Attack pipeline: crit, resistance/vuln/immunity, save-half, temp HP, concentration check. | 00, 01, 11 | 🟡 |
| 14 | [`14-package-system-redesign.md`](./14-package-system-redesign.md) | DnD5e-native typed package format (v2). Catalog content types, id namespacing, `requiredRuntimeExtensions`. | 01 | 🟡 |

## Phase 3: Online Multiplayer Specs (Sprint 5-7)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 20 | [`20-supabase-schema.md`](./20-supabase-schema.md) | Tables, RLS policies, indexes for game sessions. | 01 | 🟡 |
| 21 | [`21-realtime-protocol.md`](./21-realtime-protocol.md) | Channel naming, event envelope, sequence numbers, snapshot vs delta. | 20 | 🟡 |
| 22 | [`22-online-game-flow.md`](./22-online-game-flow.md) | Game code generation, DM/player join, lobby, role assignment, disconnect handling. | 20, 21 | 🟡 |
| 23 | [`23-battlemap-sync-protocol.md`](./23-battlemap-sync-protocol.md) | DM↔player fog/draw/token sync. DM authority model, bandwidth budget. | 21 | 🟡 |
| 24 | [`24-player-action-protocol.md`](./24-player-action-protocol.md) | Player visual AoE marker. MVP: no auto-resolve. | 12, 21 | 🟡 |
| 25 | [`25-second-screen-integration.md`](./25-second-screen-integration.md) | ProjectionOutput → fan-out (local + Supabase). | 21 | 🟡 |

## Phase 4: UI/UX Design Specs (Sprint 6-8, parallel with Phase 3)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 30 | [`30-responsive-design-system.md`](./30-responsive-design-system.md) | Breakpoints, adaptive widget pattern, touch vs mouse vs stylus. | — | 🟡 |
| 31 | [`31-ui-component-library.md`](./31-ui-component-library.md) | 24 DnD5e-specific reusable widgets. | 01, 30 | 🟡 |
| 32 | [`32-character-sheet-views.md`](./32-character-sheet-views.md) | DM vs player views, field visibility matrix, mobile/tablet/desktop layouts. | 01, 30, 31 | 🟡 |
| 33 | [`33-battlemap-interaction-spec.md`](./33-battlemap-interaction-spec.md) | Pan/zoom, token drag, drawing tools, measurement, AoE placement, fog brushes. | 23, 30 | 🟡 |

## Phase 5: Quality & Operations (Sprint 8+)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 40 | [`40-testing-strategy.md`](./40-testing-strategy.md) | Unit/widget/golden/integration/network test layers. Coverage targets. | 00-33 | 🟡 |
| 41 | [`41-security-and-privacy.md`](./41-security-and-privacy.md) | Threat model, RLS audit, anti-cheat policy (trust-based), PII. | 20-22 | 🟡 |
| 42 | [`42-fresh-start-db-reset.md`](./42-fresh-start-db-reset.md) | Drift v5 = drop+recreate. User-facing notice. Optional backup. | 03 | 🟡 |
| 43 | [`43-i18n-localization-spec.md`](./43-i18n-localization-spec.md) | `intl` setup, `.arb` files (en/tr). SRD content English-only. | 30 | 🟡 |

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
2. Mark Status as 🟠 Drafting in this README via PR.
3. Author content; iterate.
4. PR review: domain expert + at least one engineer.
5. Merge → mark 🟡 In Review for 1 week → 🟢 Complete.
6. Doc enters maintenance: minor updates as code evolves; major rewrite triggers version bump.
