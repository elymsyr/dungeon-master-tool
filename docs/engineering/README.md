# Engineering Documentation Roadmap

> Living index of all technical specs for the Dungeon Master Tool D&D 5e re-architecture.
> Update Status column as documents move through `Not Started → Drafting → In Review → Complete`.

## Mission Context

The current Template-based JSON schema system is being **removed** and replaced with **code-level native D&D 5e** integration. The same code base will gain optional **online multiplayer** via Supabase. The architecture remains modular so future systems (Pathfinder, Call of Cthulhu) can plug in.

### Resolved Scope Decisions

| Decision | Choice |
|---|---|
| RuleEngineV2 | **Remove entirely.** Effects implemented as Dart pure functions. |
| User data migration | **Fresh start.** No automated migration from old template-derived data. |
| Auto-resolve combat | **Out of MVP scope.** Manual combat tracker + visual player AoE markers only. |
| Internationalization | **TR + EN.** `intl` + `.arb` files. SRD content stays English (CC BY 4.0). |

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
| 01 | `01-domain-model-spec.md` | Typed Dart classes for Character, Monster, Spell, Item (sealed), Feat, Background, Species, CharacterClass, Subclass, Encounter, Combatant, Effect, etc. with invariants and serialization plan. | 00 | ⚪ |
| 02 | `02-game-system-abstraction.md` | `GameSystem` interface for future Pathfinder/CoC modularity. Defines what is "DnD5e-specific" vs "system-agnostic." Stub Pathfinder example. | 01 | ⚪ |
| 03 | `03-database-schema-spec.md` | Drift v5: drop `world_schemas` and template_* columns; add typed tables (`characters`, `monsters`, `spells`, `items`, `feats`, `backgrounds`, `species`, `subclasses`, `class_progressions`, `encounters`, `combatants`, etc.). Fresh-start reset note (see doc 42). | 01 | ⚪ |
| 04 | `04-template-removal-checklist.md` | ~40-file deletion order; dependency graph; per-step regression test plan. Lists every file in `domain/entities/schema/`, `application/services/template_*`, `application/providers/template_provider.dart`, `presentation/screens/templates/`, etc. | 01, 03 | ⚪ |
| 05 | `05-rule-engine-removal-spec.md` | Removal of RuleV2 / RuleEngineV2; replacement pattern (effects as pure functions on `Combatant` / `Character`). Migration guidance for currently-rule-driven features. | 01 | ⚪ |

## Phase 2: Game Feature Specs (Sprint 2-4)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 10 | `10-character-creation-flow.md` | 5-step wizard (Class → Origin → Scores → Alignment → Details). State machine, per-step validation, level-1 vs higher-level paths. UX for ability score generation methods. | 00, 01 | ⚪ |
| 11 | `11-combat-engine-spec.md` | Manual combat tracker (MVP): initiative roll, turn state, action/bonus/reaction tracking, condition expiration. Auto-resolve in "Future Work" section. | 00, 01 | ⚪ |
| 12 | `12-spell-system-spec.md` | Spell slot table, multiclass slot calculator, concentration manager, upcasting rules, AoE geometry math (Cone/Cube/Cylinder/Emanation/Line/Sphere) for both rendering and target selection. | 00, 01 | ⚪ |
| 13 | `13-damage-resolver-spec.md` | Attack roll → crit detection → damage roll → resistance/vuln/immunity pipeline → save-half rule → AoE single-roll rule. Pure function signatures with test fixtures. | 00, 01, 11 | ⚪ |
| 14 | `14-package-system-redesign.md` | DnD5e-native typed package format (`SpellPack`, `MonsterPack`, `ItemPack`, `SubclassPack`, `BackgroundPack`, `SpeciesPack`). Import/merge rules, UUID remap, conflict resolution. Replaces JSON schema-based packages. | 01 | ⚪ |

## Phase 3: Online Multiplayer Specs (Sprint 5-7)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 20 | `20-supabase-schema.md` | Tables: `game_sessions`, `session_participants`, `shared_battle_maps`, `player_actions`, `player_drawings`, `combat_state` (broadcast snapshot only — authoritative state local). RLS policies. Indexes. | 01 | ⚪ |
| 21 | `21-realtime-protocol.md` | Broadcast channel naming (`session:{code}:battlemap`, `:combat`, `:projection`, `:presence`). Event envelope schema. Delta vs snapshot heuristic. Reconnection / sequence number / conflict strategy. | 20 | ⚪ |
| 22 | `22-online-game-flow.md` | Game code generation (entropy, collision avoidance), DM/player join, role assignment, disconnect/reconnect handling, persistent vs ephemeral state distinction. | 20, 21 | ⚪ |
| 23 | `23-battlemap-sync-protocol.md` | DM↔player fog/draw/token sync. DM is source of truth; players can draw (their own strokes) and DM can erase any stroke. Bandwidth budget per event class. | 21 | ⚪ |
| 24 | `24-player-action-protocol.md` | Player visual AoE marker flow: select spell/action → preview valid range + AoE shape → confirm → broadcast marker → DM resolves manually. MVP: no auto-spell-slot decrement, no auto-damage. | 12, 21 | ⚪ |
| 25 | `25-second-screen-integration.md` | `ProjectionOutput` extension to online mode. Single DM → fan-out pipeline (local window + screencast + remote players). Reuse `BattleMapSnapshot` and `EntitySnapshot`. | 21 | ⚪ |

## Phase 4: UI/UX Design Specs (Sprint 6-8, parallel with Phase 3)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 30 | `30-responsive-design-system.md` | Breakpoints (mobile <600w, tablet 600-1200w, desktop >1200w). Adaptive widget pattern: `LayoutBuilder` + `MediaQuery`. Touch vs mouse vs stylus interaction matrix. Platform conventions (BottomNav / NavigationRail / Sidebar). | — | ⚪ |
| 31 | `31-ui-component-library.md` | DnD5e-specific reusable widgets: `AbilityScoreInput`, `DiceRoller`, `SpellSlotTracker`, `HPTracker`, `ConditionBadge`, `StatBlockCard`, `AoEMarkerOverlay`, `WeaponMasteryChip`, `RestPanel`. | 01, 30 | ⚪ |
| 32 | `32-character-sheet-views.md` | DM vs player view, private/public field split (e.g., DM sees monster HP exact; players see Bloodied only). Mobile/tablet/desktop layouts. Print-friendly export mode. | 01, 30, 31 | ⚪ |
| 33 | `33-battlemap-interaction-spec.md` | Pan/zoom (touch + mouse + trackpad), token drag with speed-limit visualization, drawing tools (line/freehand/shape), measurement tools (ruler/circle), AoE placement with snap-to-grid, fog brushes. Touch vs mouse gesture matrix. | 23, 30 | ⚪ |

## Phase 5: Quality & Operations (Sprint 8+)

| # | Filename | Purpose | Deps | Status |
|---|---|---|---|---|
| 40 | `40-testing-strategy.md` | Unit (rules — 100+ scenarios per attack/save/damage), widget (UI components), integration (combat scenarios end-to-end), golden (stat block / character sheet rendering), network (Supabase mock). Coverage targets per layer. | 00-33 | ⚪ |
| 41 | `41-security-and-privacy.md` | Game code entropy (8+ char alphanumeric), Supabase RLS audit, player PII handling, anti-cheat policy (trust-based — no server-side dice; rely on accountability). | 20-22 | ⚪ |
| 42 | `42-fresh-start-db-reset.md` | Drift v5 = drop+recreate. No migration script provided. User-facing release notice. Backup recommendation prior to upgrade. | 03 | ⚪ |
| 43 | `43-i18n-localization-spec.md` | `intl` package setup, `.arb` files (en, tr), key naming conventions, language switcher UX, SRD content English-only justification (CC BY 4.0 attribution must remain unmodified for licensed text). | 30 | ⚪ |

---

## Dependency Graph (Quick Reference)

```
00 ──┬── 01 ──┬── 02
     │        ├── 03 ── 04
     │        │        ├── 42
     │        ├── 05
     │        ├── 10
     │        ├── 11 ── 13
     │        ├── 12 ──┐
     │        ├── 14   │
     │        └── 20 ──┴── 21 ──┬── 22
     │                          ├── 23 ── 33
     │                          ├── 24
     │                          └── 25
     │
     └── 30 ──┬── 31 ── 32
              ├── 33
              └── 43

40, 41 cross-cut all docs.
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
