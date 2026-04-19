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

### 2026-04-20 — Doc 42 main.dart wiring + LegacyDbBackup helper (🟣) — Phase A bootstrap close-out (Task 3 of 3)

Closes the third leg of the Phase A structural unblock by wiring the existing `V5ResetBootstrap` (purger glue, shipped earlier) into the live `_BootstrapGate` boot sequence and ships the `_backupV4DbBeforeReset` helper that the strategy plan called out as the gating dependency. After this batch, a launch on a v4 install: (1) backs up the v4 SQLite file to a sibling `.v4.backup.sqlite` *before* anything destructive runs, (2) purges the legacy template/rule caches + prefs keys, (3) marks the reset complete in `shared_preferences`, (4) posts the `V5UpgradeNoticeDialog` once on the first frame, surfacing the backup path to the user. Doc 04 Step 5 (delete `lib/domain/entities/schema/`) and Step 7 (drop legacy v5 tables in drift `onUpgrade` v9) are deliberately *not* in this batch — Step 5 alone touches 33 importer files spanning data + application + presentation + tests, which is several turns of focused refactor; bundling it here would balloon scope and risk a half-shipped state. Tasks 1–2 remain queued.

Files added:
- `lib/data/storage/legacy_db_backup.dart` — `LegacyDbBackup.backup(dbPath)` static helper. Copies `dbPath` to `<basename>.v4.backup.sqlite` in the same directory. Returns the backup path on success, `null` if the source doesn't exist, the backup already exists (idempotent — never overwrites), or any I/O step fails. All errors swallowed because startup must never fail because a backup attempt couldn't complete (locked file on Windows, ENOSPC, permission denied). Pure — no globals — caller owns the path.
- `lib/application/providers/v5_reset_provider.dart` — `v5ResetOutcomeProvider` (`StateProvider<V5ResetOutcome?>`), seeded once via `ProviderScope` override at `DungeonMasterApp` construction time using the outcome that `_BootstrapGate._bootstrap()` captured. Surfacing as a provider rather than firing the dialog inline lets test code read the value directly without a UI pump and lets future debug surfaces (e.g. a Settings "Last v4→v5 reset" panel) read the same value.
- `test/data/storage/legacy_db_backup_test.dart` — four tests. (1) Returns `null` when source DB absent; no backup created. (2) Copies bytes 1:1 to the sibling `.v4.backup.sqlite` path. (3) Idempotent — second call returns the same path *without* overwriting (verified by mutating the source between calls and reading the backup back). (4) Returns `null` and does not throw when the path is invalid (NUL byte injected so `dart:io` rejects it cleanly).

Files changed:
- `lib/data/storage/v5_reset_bootstrap.dart` — three additions on top of the existing class. (1) `V5ResetOutcome.backupPath: String?` field carrying the location of the v4 DB copy when one was made. (2) `V5ResetBootstrap.legacyDbPath: String?` — when set, the v4 SQLite file at that location is backed up before the purger runs. (3) `V5ResetBootstrap.backupV4Db: Future<String?> Function(String)` — injectable backup function, defaults to `LegacyDbBackup.backup`, lets tests assert call ordering and arguments without touching disk. The backup runs *only* on the path where the purger actually fires (i.e. `prefs.getBool(resetCompleteFlag) != true`), so re-launches don't repeat the copy work.
- `lib/main.dart` — `_BootstrapGateState` gains a `V5ResetOutcome? _v5ResetOutcome` field, and `_bootstrap()` runs `V5ResetBootstrap(cacheRoot: AppPaths.dataRoot, legacyDbPath: <dataRoot>/db/dmt.sqlite).runIfNeeded()` immediately after `AppPaths.initialize()` and before any of Supabase / SoLoud / window manager init. Wrapped in its own try/catch so a backup or purger failure logs to `LogBuffer` and continues — the flag stays unset so the next launch retries. `ProviderScope` overrides now include `if (_v5ResetOutcome != null) v5ResetOutcomeProvider.overrideWith((_) => _v5ResetOutcome)` so the seeded outcome is visible to the dialog dispatcher in `DungeonMasterApp`. New imports: `package:path/path.dart`, `application/providers/v5_reset_provider.dart`, `data/storage/v5_reset_bootstrap.dart`.
- `lib/app.dart` — `DungeonMasterApp` flips from `ConsumerWidget` to `ConsumerStatefulWidget` so it can run an `initState`-scheduled `addPostFrameCallback` that reads `v5ResetOutcomeProvider`, checks `shouldShowUpgradeNotice + !_v5DialogShown`, and calls `V5UpgradeNoticeDialog.show(scaffoldMessengerKey.currentContext, backupPath: outcome.backupPath)`. The `_v5DialogShown` flag prevents re-show on hot reload / rebuild. The existing SRD bootstrap snackbar listener stays in `build()` unchanged; only the wrapping widget shape changed.
- `test/data/storage/v5_reset_bootstrap_test.dart` — three new tests on top of the existing four. (1) `legacyDbPath` triggers backup before purge — uses an injected fake `backupV4Db` to capture the call and confirm it received the right path; outcome carries the returned backup path. (2) No `legacyDbPath` = no backup attempt — fake function asserted *not* called; `outcome.backupPath` is null. (3) `alreadyComplete` short-circuit skips backup — even with `legacyDbPath` set, if the flag is true the backup function never runs (wasteful work avoided on every cold launch).

Decisions:
- **Backup is best-effort, errors swallowed** — a `dart:io` failure mid-copy must not block startup. The user gets into the app and the next launch retries (flag still unset on backup failure paths because the purger may also have failed, or by the time the purger ran the backup-or-not state is already moot). The fact that `_bootstrap()` wraps the whole thing in try/catch + `LogBuffer.recordError` doubles as a tripwire for the next session.
- **Backup before purge, not after** — the purger doesn't touch the SQLite file today, but it *does* delete `templates/`/`package_cache_v4/`/`rule_eval_cache/` subdirs. Doing the backup first matches the principle "reverse order of restore" — destructive things go later, recoverability snapshots go earlier. This also means when Doc 04 Step 7 lands the destructive v8→v9 `onUpgrade` (drops legacy tables), the same backup path is already in place; only `onUpgrade` integration changes.
- **Idempotent backup — never overwrites** — second call returns the path of the *original* backup. The risk you avoid: a first-launch backup happens, the user uses the app for a session (mutating data), then a second-launch backup *would* overwrite the snapshot that captured the user's actual upgrade-time state. The fix-or-investigate value of the backup is the moment-of-upgrade state; preserving that means the second call must be a no-op.
- **`legacyDbPath` is opt-in (nullable)** — tests can construct a `V5ResetBootstrap` without a DB path and get the old purger-only behavior, no fake backup function needed. Production code passes the real path. The injection seam for `backupV4Db` lets tests prove "backup ran with these args" without touching disk.
- **Provider seeded by `ProviderScope` override, not driven by the gate widget** — `_BootstrapGate` has captured the outcome by the time it constructs `ProviderScope`, so the override is the natural seeding point. Alternative (have `DungeonMasterApp` re-run the bootstrap) was rejected because the bootstrap is one-shot and the file system check it does is mutating; running it twice is wrong, not just wasteful.
- **`addPostFrameCallback` in `initState`, not `ref.listen` in `build`** — the override seeds the value *before* the first frame, so a `ref.listen` would never see a transition from `null` → outcome (no listen-on-init in Riverpod's StateProvider). `ref.read` in `initState` + post-frame schedule correctly delays the dialog push until after `MaterialApp.router` has built and `scaffoldMessengerKey.currentContext` is non-null.
- **`_v5DialogShown` flag prevents re-fire** — hot reload / parent rebuild would otherwise re-run `initState` on a fresh state object; the bool guard is per-instance so this is enough. A duplicate-show on hot reload is harmless (`barrierDismissible: false` + `Understood` button) but visually noisy in dev.
- **`scaffoldMessengerKey.currentContext` is the dialog anchor** — the listener is in `DungeonMasterApp` build subtree but the actual `Scaffold` lives inside the router-rendered child. The global key was already added in the prior batch (for the SRD snackbar listener) and is the one context guaranteed to be attached after the first `MaterialApp.router` build.
- **Tasks 1+2 split off** — Doc 04 Step 5 deletes `lib/domain/entities/schema/` (29 files) which forces refactoring 33 consumers across data + application + presentation + tests. Doc 04 Step 7 drops legacy v5 tables in `onUpgrade` v9, which forces refactoring `CampaignDao`/`PackageDao` + their repository impls because their queries hit `worldSchemas`/`packages`/`packageSchemas`/`packageEntities`. Each is its own multi-turn slice; bundling them with the bootstrap wiring would have produced a half-shipped state with broken UI / failing tests for the whole intermediate window. Splitting keeps every batch shippable.
- **Wiring before Supabase + SoLoud + window manager init** — the v4 reset is purely local I/O and is the cheapest blocker to unblock. Running it first means the rest of `_bootstrap()` operates on a known-clean state (no stale template caches confusing later steps). It's also the right order for the eventual destructive `onUpgrade` — the backup is in place before any other code path can touch the DB.

Verification: `flutter analyze` 0 issues, `flutter test` 1437/1437 pass + 1 skipped (1430 → 1437, +7 — four `LegacyDbBackup` tests + three new `V5ResetBootstrap` tests).

Next up:
- **Doc 04 Step 5: delete `lib/domain/entities/schema/`** — multi-turn refactor. 29 schema files + 33 consumers across data (5) / application (9) / presentation (13) / tests (6). Probably split per layer: data layer first (repository writes/reads must move to typed catalog tables), then providers (rebuild on top of typed reads), then presentation (builds against new providers).
- **Doc 04 Step 7: drop legacy v5 tables in drift `onUpgrade` v9** — depends on Doc 04 Step 5 finishing, because the surviving consumers must already not need `worldSchemas`/`packages`/`packageSchemas`/`packageEntities`. Mechanically the migration is a 4-line `if (from < 9) { drop... }` block; the test surface to refactor is large.
- **Per-user `srd_core.installed_version` `shared_preferences` key** — small, ~30 min.
- **`CustomEffect.compile(parameters)` runtime hook** — depends on Doc 05 rule-engine compile surface.
- **i18n the AboutScreen + SRD bootstrap snackbar + V5UpgradeNotice strings** — Doc 43 sweep.

### 2026-04-20 — Doc 15 CC BY 4.0 attribution UI + SRD bootstrap snackbar (🟣) — Phase B legal close-out

Closes the legal blocker that was gating SRD content reaching users: the bundled `srd_core` package is redistributed under CC BY 4.0, and the license itself requires that attribution be visible to recipients. This batch adds (1) persistent attribution columns on `installed_packages` so author/license/description survive across launches, (2) an `installedAttributionsProvider` view-model, (3) a dedicated About & Attributions screen wired into Settings, and (4) an app-level Snackbar listener that surfaces SRD bootstrap completion / failure exactly once per outcome write. Together these discharge the licence obligation in-app and give the user a quiet signal when a fresh install lands or fails.

Files added:
- `lib/application/providers/installed_packages_provider.dart` — `InstalledPackageAttribution` POD plus `installedAttributionsProvider` (`FutureProvider<List<InstalledPackageAttribution>>`). Reads `installed_packages` rows from the active user's DB, sorted by `name`. Watching `appDatabaseProvider` means the list automatically rebuilds when the user switches; the typed POD keeps the screen decoupled from the Drift row class so the screen can be reused for a future "marketplace listing detail" surface that synthesizes an `InstalledPackageAttribution` from a remote row.
- `lib/presentation/screens/about/about_screen.dart` — `AboutScreen` consumer widget. App header (`Dungeon Master Tool` + `Version $appVersion` from `core/constants.dart`), then a list of `_AttributionCard`s. Each card shows: name, version, author, license, game system, slug, install timestamp, optional description, plus a copy-to-clipboard button that emits a single attribution line `"<name> v<version> — <author>. <license>."`. Renders empty state ("No packages installed yet.") if no rows. Uses the existing `DmToolColors` palette so it matches every theme.
- `test/application/providers/installed_packages_provider_test.dart` — two tests. (1) Empty DB returns `isEmpty`. (2) Two seeded rows (one with description, one without) return sorted by name with every attribution field populated, and the row without a description carries `null`. Uses an in-memory `AppDatabase.forTesting` and `appDatabaseProvider.overrideWithValue` for isolation.

Files changed:
- `lib/data/database/tables/installed_packages_table.dart` — three new columns: `authorName text not null default ''`, `sourceLicense text not null default ''`, `description text nullable`. Defaults of empty string (rather than nullable) for author/license keep the screen rendering logic simple — the card shows `'—'` when blank, no extra null check at the layer above.
- `lib/data/database/app_database.dart` — `schemaVersion` 7 → 8 + `onUpgrade` `if (from < 8)` block calling `m.addColumn` three times. The `withDefault('')` on the columns means existing rows in already-installed databases get sensible defaults without a backfill query — the rows just say `'—'` until their package is reinstalled with the new importer.
- `lib/application/dnd5e/package/dnd5e_package_importer.dart` — the `installed_packages` insert now also writes `authorName: Value(pkg.authorName)`, `sourceLicense: Value(pkg.sourceLicense)`, `description: Value(pkg.description)`. The `Dnd5ePackage` already carried these fields per Doc 14; this just persists them.
- `lib/app.dart` — three additions. (1) Top-level `scaffoldMessengerKey` so app-level listeners can post snackbars without sitting under a router-supplied `Scaffold`. (2) `MaterialApp.router` now wires `scaffoldMessengerKey: scaffoldMessengerKey`. (3) Inside `DungeonMasterApp.build`, a `ref.listen<SrdBootstrapOutcome?>(srdBootstrapOutcomeProvider, ...)` posts `'SRD Core <version> installed.'` on `SrdBootstrapInstalled`, posts `'SRD Core install failed: <message>'` (with the error color background) on `SrdBootstrapError`, and is silent on `SrdBootstrapAlreadyInstalled` (a routine launch isn't worth interrupting the user for).
- `lib/presentation/router/app_router.dart` — adds `GoRoute(path: '/about', ...)` for the `AboutScreen`.
- `lib/presentation/screens/hub/settings_tab.dart` — adds an "About" section above the Trash list with a one-line blurb and an `OutlinedButton.icon` that calls `context.push('/about')`. Sits at the bottom of Settings rather than the top because attribution is reference info, not a frequently-accessed control.
- `test/application/dnd5e/package/dnd5e_package_importer_test.dart` — adds an `attribution fields persist on installed_packages row` test: imports a package with explicit `authorName: 'Wizards of the Coast'`, `sourceLicense: 'CC BY 4.0'`, `description: '…'`, asserts all three round-trip through the row.
- `test/data/database/doc03_schema_test.dart` — `schemaVersion = 7` assertion → `8`, kept as a single test that fails loudly when the schema is bumped without intentionally updating this guard.

Decisions:
- **Persist attribution on `installed_packages`, don't re-read source assets** — the alternative was to keep the table lean and re-decode the bundled monolith every time the screen renders. Cheap for SRD, but for user-imported third-party packages there's no guarantee the source file is still on disk (the importer doesn't keep a copy after extracting catalog/content rows). Persisting in the DB is the only shape that survives uninstalling the source file.
- **Three columns, not one `metadataJson` blob** — three nullable text columns are queryable + indexable + visible in any DB browser. A JSON blob would force every consumer through `jsonDecode` and bury the legal-attribution-relevant fields in opaque text. The cost is one schema bump; the benefit is forever-after grep-ability.
- **Defaults of empty string, not null, for `authorName` + `sourceLicense`** — these fields always *exist* in the package format (they're declared on `Dnd5ePackage` with `String` not `String?`), so the column shape should match. Empty string means "not set"; `null` would be a fourth state with no meaning. `description` is nullable because `Dnd5ePackage.description` is nullable.
- **Schema bump 7 → 8 with `addColumn`, not a recreate-and-copy migration** — Drift's `addColumn` is the simple-and-safe path when columns have defaults or are nullable. No data loss risk; existing rows get the column defaults; reads against the new shape work immediately. The doc03_schema_test assertion update is the deliberate friction that catches future "I forgot to bump this" mistakes.
- **`installedAttributionsProvider` is `FutureProvider`, not `StreamProvider`** — installs are infrequent (user-driven imports + first-launch SRD) and the screen is reached on-demand. A stream would re-rebuild cards on every unrelated DB write; a `FutureProvider` re-fires on `appDatabaseProvider` invalidation (user switch) or explicit `ref.invalidate`. The importer pages can call `ref.invalidate(installedAttributionsProvider)` after a successful import if real-time refresh ever becomes important.
- **Card layout uses `_kv(label, value)` rows, not a `DataTable`** — `DataTable` is overkill for ≤6 fields and wraps badly on phone-width. The kv-row pattern scales to phone naturally and matches the visual density of the surrounding Settings pane.
- **Copy button emits a one-line attribution string, not the full card** — multi-line clipboard content rarely pastes well into chat / forum / docs. The single line `"<name> v<version> — <author>. <license>."` is the *attribution* per CC BY 4.0 §3(a)(1) ("identification of the creator(s) … and any others designated to receive attribution"); description and install date are decorative. If a user wants the full card they can screenshot.
- **Snackbar listener at the `DungeonMasterApp` level, not `_BootstrapGate`** — `_BootstrapGate` runs *before* `ProviderScope`, so it can't watch a Riverpod provider. `DungeonMasterApp` is the first widget that sees the scope; `ref.listen` here fires on every outcome write for the lifetime of the app. The global `scaffoldMessengerKey` is the trick that lets the listener post into a `MaterialApp.router` (which has no `Scaffold` ancestor for the listener subtree).
- **Silence on `SrdBootstrapAlreadyInstalled`** — every cold launch after the first would otherwise toast "SRD Core already installed", which is noise. The state provider value still flips to `AlreadyInstalled` so any future debug surface can render it; the snackbar just doesn't fire.
- **Snackbar only, no full upgrade banner** — a banner would compete with future onboarding banners (cloud-quota, beta-program, mobile-release) for screen real estate. The snackbar is unobtrusive, time-limited (3s success / 6s failure), and dismissible by user gesture; it's the right ergonomics for a once-per-install signal.
- **Settings entry at the bottom, not the top** — Subscriptions, Theme, Language, Volume, Sound Library, Data Path, Legacy Import are all *settable*; About is *informational*. Burying it below the actionable section follows the macOS/Windows convention (About is in the application menu, not the preferences pane).
- **Hardcoded English strings, not l10n keys** — the doc 43 i18n batch sweeps all UI strings into `.arb` files in one pass. Spreading partial l10n now would force two edits per string later. The screen ships with literal English strings flagged here as pending l10n.
- **No banner UI, no dismiss persistence** — both belong to a future onboarding/announcements system; building them piecemeal here would produce a single-purpose banner that can't be reused. Snackbar is the throwaway-equivalent that doesn't need persistence.

Verification: `flutter analyze` 0 issues, `flutter test` 1430/1430 pass + 1 skipped (1427 → 1430, +3 — importer attribution test, two provider tests, schema-version assertion bumped not added).

Next up:
- **Phase A structural unblock** — Doc 04 Step 5/7 + Doc 42 `main.dart` wiring. Still gated on `_backupV4DbBeforeReset`. Biggest single unblock when picked up: deletes legacy `schema/` directory references across ~40 UI/provider files + drops v5 legacy tables in `onUpgrade` + wires `V5UpgradeNoticeDialog` into the boot path.
- **`CustomEffect.compile(parameters)` runtime hook** — Doc 05 rule-engine compile-step dep. Today's 9 impls remain identity-only.
- **Per-user `srd_core.installed_version` `shared_preferences` key** — current global flag means switching users on the same device doesn't re-import the SRD into the new user's DB. Conceptually wrong but practically rare; tracked.
- **i18n the About screen + SRD bootstrap snackbar strings** — sweep-in pass with Doc 43 `intl` rollout (tracked, not blocking).

### 2026-04-19 — Doc 15 SRD bootstrap wired into user-session activate (🟣) — Phase B runtime closure

Closes the loop on the previous batch by tying `SrdBootstrapService` into the live user-session boot path. The service shipped in the prior turn was reachable from tests but not from the app itself; this batch adds the two Riverpod providers it needs and a fire-and-forget kickoff at the moment `UserSessionNotifier.activate(userId)` flips the active user. After this batch, signing into the app on a fresh install runs the SRD import in the background against the user-scoped DB, with the outcome surfaced through a state provider any UI surface can subscribe to.

Files added:
- `lib/application/providers/custom_effect_registry_provider.dart` — `customEffectRegistryProvider`, an app-wide `Provider<CustomEffectRegistry>` that eagerly calls `registerSrdCustomEffects(registry)` at construction. Registering at provider-construction (rather than on first import) means a startup-time guarantee that any package declaring `requiredRuntimeExtensions: ["srd:wish", …]` resolves immediately. The registry is one global singleton — there's no per-user reason for it to differ.
- `lib/application/providers/srd_bootstrap_provider.dart` — three provider/function exports. (1) `srdBootstrapServiceProvider` — `Provider<SrdBootstrapService>` watching `appDatabaseProvider` + `customEffectRegistryProvider`, so it rebuilds in lockstep with the user-scoped DB whenever `activeUserIdProvider` changes. Each user's session gets a service instance bound to *their* DB. (2) `srdBootstrapOutcomeProvider` — `StateProvider<SrdBootstrapOutcome?>`, the latest outcome for the active user. Defaults to `null` until the bootstrap has been run for this session. (3) `runSrdBootstrap(Ref ref)` — top-level `Future<SrdBootstrapOutcome>`-returning helper that reads the service, awaits `runIfNeeded()`, writes the result into `srdBootstrapOutcomeProvider.notifier.state`, and returns the outcome so callers can `await` and react. The function form (rather than another `FutureProvider`) is deliberate: bootstrap is a *side-effecting trigger*, not a *cached query*, and forcing every caller through `c.read(...).future` would obscure the semantics.
- `test/application/providers/srd_bootstrap_provider_test.dart` — six tests across all three exports. `customEffectRegistryProvider`: contains all 9 SRD ids; returns the same instance across reads (singleton invariant). `runSrdBootstrap`: first call installs and writes outcome to the state provider (verified by reading both the return value and `c.read(srdBootstrapOutcomeProvider)`); second call short-circuits to `SrdBootstrapAlreadyInstalled`; asset-load failure stores `SrdBootstrapError` without throwing (the swallow-and-report contract from the service holds across the provider boundary). `srdBootstrapServiceProvider`: default wiring binds `db: appDatabaseProvider`, `registry: customEffectRegistryProvider`, `assetPath: defaultSrdAssetPath`. Tests use a local `_triggerProvider` (`Provider<Future<SrdBootstrapOutcome> Function()>`) to capture a `Ref` and expose a callable so the same container can fire the bootstrap multiple times without re-instantiating overrides.

Files changed:
- `lib/application/providers/user_session_provider.dart` — `UserSessionNotifier.activate(userId)` now ends with `unawaited(runSrdBootstrap(_ref))` after `_invalidateAll() + state = true`. Order matters: `_invalidateAll()` cascade-invalidates `appDatabaseProvider` (via `activeUserIdProvider` change), so by the time `runSrdBootstrap` reads `srdBootstrapServiceProvider` the underlying `AppDatabase.forUser(userId)` is already bound to the just-activated user. Added `dart:async` import for `unawaited`. `deactivate()` does *not* fire the bootstrap — logout doesn't need an SRD reinstall — and the `srdBootstrapOutcomeProvider` value naturally goes stale until the next `activate()` re-fires.

Decisions:
- **Fire-and-forget, not awaited** — a fresh-install SRD import touches all 12 catalog tables + 8 content tables (123 catalog rows + 184 content rows on today's asset). On slower devices that's a non-trivial wall-clock chunk to add to user-session activation. Awaiting would block the post-activation navigation; fire-and-forget lets the user reach the hub immediately and observe completion via `srdBootstrapOutcomeProvider` if a UI surface subscribes. Errors don't escape — `SrdBootstrapService.runIfNeeded` returns `SrdBootstrapError` instead of throwing — so `unawaited(...)` is safe (no uncaught Future error).
- **Eager registration at provider construction** — `customEffectRegistryProvider` calls `registerSrdCustomEffects` synchronously inside its build function. Lazy-registration on first use would split the registration timing from the provider's identity (callers couldn't assume it was populated), and `Dnd5ePackageImporter` consults the registry inside its validator pre-import — any unregistered id would surface as a confusing "validation failure" rather than the real "you forgot to call registerSrdCustomEffects" bug.
- **`runSrdBootstrap` is a function, not a `FutureProvider`** — `FutureProvider` caches its result and re-emits on dependency change; bootstrap is a one-shot side-effect. Calling `c.read(provider.future)` would memoize the first call's outcome forever (or re-fire on every dependency invalidation, which is the wrong shape). The function form makes the trigger semantics explicit at every call site and lets the `StateProvider` be the single source of truth for the latest outcome.
- **`srdBootstrapOutcomeProvider` as `StateProvider<SrdBootstrapOutcome?>`, not `AsyncValue`** — the bootstrap has three meaningful states (not yet run / done / errored), and the existing sealed `SrdBootstrapOutcome` family already encodes done-vs-errored. Wrapping in `AsyncValue<SrdBootstrapOutcome>` would double-encode the error state and force every consumer through a `.when(...)` they don't need. Plain nullable `StateProvider` matches "did we run yet, and if so, what happened" exactly.
- **Service rebuilds with `appDatabaseProvider`** — `srdBootstrapServiceProvider` `watch`es `appDatabaseProvider`. Switching users (logout → log in as different user) tears down the current service + DB and constructs fresh ones, so the new user's `runIfNeeded` runs against the new user's DB with the new user's `shared_preferences` keying. This is the right shape for the multi-user goal even though current per-user `shared_preferences` still uses one global flag — when per-user prefs land, the service's `versionFlag` parameter accepts a user-scoped key without further changes.
- **`deactivate()` does not run bootstrap** — logout flips `activeUserIdProvider` to `null`, which makes `appDatabaseProvider` give back the global (no-user) DB. Importing the SRD into the global DB is wrong (the global DB is the pre-login scratch surface; nothing should accumulate there). The state provider naturally goes stale; the next `activate(userId)` rebuilds the service against the right DB and the bootstrap re-fires.
- **No banner UI in this batch** — the prior plan called out an "optional upgrade banner." Surfacing a UI listener belongs in the same batch as the CC BY 4.0 attribution UI (settings/about screen lives there too); shipping it here would force premature decisions about visual treatment + dismiss semantics that don't have user input yet.

Verification: `flutter analyze` 0 issues, `flutter test` 1427/1427 pass + 1 skipped (1421 → 1427, +6).

Next up:
- **CC BY 4.0 attribution UI** — small screen reachable from About / Settings, displays `sourceLicense` + `authorName` + `description` from the SRD package row in `installed_packages` (now actually populated on first launch). Same batch is a natural home for an optional upgrade banner reading `srdBootstrapOutcomeProvider` and showing a Snackbar on `SrdBootstrapInstalled` (first install only) or `SrdBootstrapError` (recoverable failure). Required by license before SRD content ships to users.
- **Phase A structural unblock** — Doc 04 Step 5/7 + Doc 42 `main.dart` wiring. Still gated on `_backupV4DbBeforeReset`. Big batch (~40 UI/provider files reference legacy `schema/` dir).
- **`CustomEffect.compile(parameters)` runtime hook** — Doc 05 rule-engine compile-step dep. Today's 9 impls are identity-only.
- **Per-user `shared_preferences` key for `srd_core.installed_version`** — the current global flag works for single-user-per-install, but conceptually the install is per-user (per the user-scoped DB binding). Tracked but low-priority while multi-user remains rare.

### 2026-04-19 — Doc 15 `SrdBootstrapService` + 9 `CustomEffect` impls + monolith asset committed (🟣) — Phase B runtime install path

Two-part Phase B closer that turns the built monolith from the previous batch into something the runtime actually installs. Lands the per-user import path (`SrdBootstrapService`), the nine whitelisted `CustomEffect` impls referenced by Doc 15 §"Whitelisted CustomEffect Implementations", and flips the monolith from gitignored derived artifact to committed asset bundled via `pubspec.yaml`. Wiring into `_BootstrapGate._bootstrap()` is intentionally *not* in this batch — it's gated on the user-session integration path (`AppDatabase.forUser(userId)` requires a known user before bootstrap can run), which belongs with the multi-user flow rather than this content-loader slice.

Files added:
- `lib/application/dnd5e/effect/srd_custom_effects.dart` — nine const-constructible identity classes (`WishImpl`, `WildShapeImpl`, `PolymorphImpl`, `AnimateDeadImpl`, `SimulacrumImpl`, `SummonFamilyImpl`, `ConjureFamilyImpl`, `ShapechangeImpl`, `GlyphOfWardingImpl`) implementing `CustomEffectImpl` with the canonical `srd:<name>` ids from Doc 15. Top-level `srdCustomEffectImpls` const list pins the order to match the doc table; `registerSrdCustomEffects(registry)` is the one-call registration helper. Doc-comment on the file documents that these are identity placeholders satisfying `requiredRuntimeExtensions` lookup at package import — runtime semantics (`compile(parameters)`) get added when Doc 05 lands the rule-engine compile step.
- `lib/application/dnd5e/bootstrap/srd_bootstrap_service.dart` — `SrdBootstrapService` loads the monolith from a configurable asset path (default `assets/packages/srd_core.dnd5e-pkg.json`) via an injectable `Future<String> Function(String)` loader (defaults to `rootBundle.loadString`), decodes it through `Dnd5ePackageCodec`, reads the envelope's top-level `contentHash`, and runs `Dnd5ePackageImporter.import` with `expectedContentHash` set so any tamper/corruption fails the import. Idempotency is keyed on a `shared_preferences` string flag (`srd_core.installed_version`, default name): when the bundled monolith reports the version already stamped, `runIfNeeded()` returns `SrdBootstrapAlreadyInstalled` without touching the importer. Successful first-runs return `SrdBootstrapInstalled { version, report, contentHash }`; load failures, decode failures, hash mismatches, and importer-reported errors all return `SrdBootstrapError(message)` so the caller has one cohesive failure surface. Sealed outcome class with a `summary` getter on every variant for log-line formatting.
- `test/application/dnd5e/effect/srd_custom_effects_test.dart` — six tests. (1) The nine ids in `srdCustomEffectImpls` match the Doc 15 whitelist *exactly* in *order* (regression guard against silent renames). (2) Every id is namespaced under `srd:`. (3) Ids are unique within the list. (4) `registerSrdCustomEffects` populates a fresh registry with exactly those nine ids and `contains` returns true for each. (5) Double registration throws `StateError` via the existing `CustomEffectRegistry.register` duplicate guard — locks the fail-fast contract. (6) `WishImpl()` is const-constructible and identical across calls, confirming the const-list invariant.
- `test/application/dnd5e/bootstrap/srd_bootstrap_service_test.dart` — seven tests built around an injected JSON loader (no on-disk asset needed). (1) **First launch**: a 4-entry mini-package installs into a fresh in-memory DB; `SrdBootstrapInstalled` reports correct version + per-table counts + `sha256:`-prefixed hash; the version flag is stamped; namespaced rows (`srd:stunned`, `srd:fireball`) appear in the typed Drift tables. (2) **Second launch same version**: `SrdBootstrapAlreadyInstalled` short-circuits without re-running the importer. (3) **Version bump**: `1.0.0` then `1.1.0` runs the importer twice and updates the flag to `1.1.0`. (4) **Tampered hash**: overriding `contentHash` to a bogus value surfaces an `SrdBootstrapError` whose message contains `Content hash mismatch`, and crucially the version flag stays unset (so a retry with the correct hash will run). (5) **Asset load failure**: a loader that throws becomes an `SrdBootstrapError` with the underlying message preserved. (6) **Malformed JSON**: returns an `SrdBootstrapError` rather than crashing. (7) **`outcome.summary`**: human-readable string on every variant for log-line formatting.

Files changed:
- `flutter_app/.gitignore` — removes the `/assets/packages/srd_core.dnd5e-pkg.json` ignore, replaces with a comment explaining that the monolith is intentionally committed per Doc 15 §"Repo Location and Build" ("the build tool's output is committed — reviewer sees the exact bytes that ship"). Regen via `dart run tool/build_srd_pkg.dart`.
- `flutter_app/pubspec.yaml` — adds `assets/packages/srd_core.dnd5e-pkg.json` under `flutter.assets` so `rootBundle.loadString` finds it on every supported platform.
- `flutter_app/assets/packages/srd_core.dnd5e-pkg.json` (newly committed, 156531 bytes, `sha256:5d33061ef7f604a3a0da3986433385ef59c6b7b3f53b503b04dff3f2f4ff3d66`) — the built SRD monolith, generated from the split sources by the Phase B builder CLI from the previous batch.

Decisions:
- **Identity-only impls, no compile step** — the `CustomEffectImpl` interface in `domain/dnd5e/effect/custom_effect_registry.dart` only requires `String get id`. Adding a compile step now would commit to a runtime representation that Doc 05 hasn't finalized; identity satisfies package-import validation today, and the impls grow a `compile(Map<String, Object?>)` extension when Doc 05 lands without rewriting the registration sites. The doc-comment in `srd_custom_effects.dart` makes this explicit so future-me (or a reader) doesn't misread the placeholders as load-bearing logic.
- **Const list order matches Doc 15 table order** — the test asserts `[wish, wild_shape, polymorph, animate_dead, simulacrum, summon_family, conjure_family, shapechange, glyph_of_warding]` *as an ordered list*, not just as a set. Order has no functional meaning at runtime, but freezing it pins the doc/code correspondence so a casual reorder of the doc table can't drift away from the code without the test catching it.
- **Bootstrap takes an injectable loader, not an `AssetBundle`** — `Future<String> Function(String path)` keeps the service decoupled from `flutter_test` bundle plumbing. `rootBundle.loadString` matches that signature naturally; tests pass in a closure that returns a fixture string built with `Dnd5ePackageCodec.encode` + `computeContentHash`, no `TestAssetBundle` infrastructure required.
- **Idempotency keyed on the package's reported version, not the contentHash** — a content-hash key would force a re-import on every dev rebuild that touches a single body field, which is wasteful and noisy. Version is the user-visible upgrade unit and matches Doc 15 §"Versioning and Upgrades": "When a user's installed SRD version is older than the bundled one, a one-tap upgrade flow uses the standard same-source `overwrite` conflict path." The contentHash still gets verified per-install (via `expectedContentHash`) for tamper detection — it just isn't the install-skip key.
- **`onConflict: ConflictResolution.overwrite`** — a version-bumped re-run wipes the prior `srd:`-namespaced rows and re-installs cleanly. The user has not authored anything under `srd:`; the slug is reserved for SRD content and the importer's per-slug delete is the right semantic. `skip` would leave stale older content in the DB; `duplicate` requires a fresh slug which isn't applicable here.
- **`SrdBootstrapError` swallows + reports rather than rethrowing** — the bootstrap path runs during launch; an exception that propagates would be a startup crash. Returning a typed error variant lets the eventual `_BootstrapGate` integration log + show a non-fatal upgrade-failed banner while the user still gets into the app (their existing data isn't blocked by an SRD reinstall failure).
- **Hash mismatch leaves the version flag unset** — explicit guarantee: a tampered or corrupted bundled asset MUST NOT be marked as installed, so the next launch retries automatically once the corruption is fixed. Test #4 locks this.
- **Outcome class has a `summary` getter on every variant** — log lines and a future settings-screen "Last bootstrap result" surface both want one short string. Putting it on the sealed type keeps the formatting next to the data and avoids stringly-typed switch-by-runtime-type at the call sites.
- **Bootstrap *not* wired into `_BootstrapGate` yet** — the service requires an `AppDatabase.forUser(userId)` instance, which means it can only run after the user-switch flow has identified the active user. Today's `_BootstrapGate._bootstrap()` runs before any user provider is initialized. Threading the bootstrap through the user-session change flow is its own batch, and bundling it here would either force premature decisions about the user-session UX or stuff a `null`-user code path into `appDatabaseProvider` that doesn't actually match the production wiring. Documented as next-up below.
- **Monolith committed (gitignore reverted)** — Doc 15 §"Repo Location and Build" is explicit: "the build tool's output is committed (reviewer sees the exact bytes that ship)." The previous batch deferred this on the (correct, at the time) read that the asset wasn't yet bundled. With pubspec now bundling it and `SrdBootstrapService` reading it, the reasons to defer are gone. The 156 KB diff is a one-time cost — subsequent rebuilds only diff when the SRD content actually changes (`computeContentHash` is stable).

Verification: `flutter analyze` 0 issues, `flutter test` 1421/1421 pass + 1 skipped (1408 → 1421, +13). `dart run tool/build_srd_pkg.dart` regenerates the monolith deterministically (same `sha256:5d33061ef7f604a3a0da3986433385ef59c6b7b3f53b503b04dff3f2f4ff3d66` as the previous build).

Next up:
- **Wire `SrdBootstrapService` into the user-session boot path** — when `activeUserIdProvider` flips to a non-null id, run `SrdBootstrapService(db: ref.read(appDatabaseProvider), registry: <app-wide registry>).runIfNeeded()` in a fire-and-forget Future, surface result via a provider for an optional banner. Needs an app-wide `CustomEffectRegistry` provider and `registerSrdCustomEffects` called once at app start.
- **CC BY 4.0 attribution UI** — small screen reachable from About / Settings, displays `sourceLicense` + `authorName` + `description` from the loaded SRD package row in `installed_packages`. Required by the license itself.
- **Phase A structural unblock** (Doc 04 Step 5/7 + Doc 42 `main.dart` wiring) — still gated on `_backupV4DbBeforeReset`. Biggest single unblock when picked up: deletes legacy `schema/` directory references across ~40 UI/provider files + drops v5 legacy tables in `onUpgrade`.
- **9 `CustomEffect` `compile(Map<String, Object?>)` step** — depends on Doc 05 rule-engine compile surface. Today's impls are identity-only; the runtime evaluation hooks are next.

### 2026-04-19 — Doc 15 SRD monolith builder CLI (🟣) — Phase B asset assembly

Phase B `tool:build_srd_pkg` CLI lands. Reads the 12 split catalog assets + 10 spell tier files + monsters/items/feats/backgrounds/species/lineages/subclasses/classes from `assets/packages/srd_core/`, namespaces every id under the `srd:` package slug, encodes via `Dnd5ePackageCodec`, computes the canonical `sha256:` content hash, and emits a single monolith JSON envelope at `assets/packages/srd_core.dnd5e-pkg.json`. This is the artifact `SrdBootstrapService` (next batch) will load from `rootBundle` on first launch.

Files added:
- `tool/build_srd_pkg.dart` — pure-Dart CLI. Public `buildSrdPackage({assetRoot})` returns a `BuildResult { package, contentHash, envelope }`; `main(args)` writes the pretty-printed envelope to `assets/packages/srd_core.dnd5e-pkg.json` (or the path passed as `args[0]`) and prints a per-table size report. Hard-coded package metadata (`id: 'srd-core-1'`, `slug: 'srd'`, `version: '1.0.0'`, `license: 'CC BY 4.0'`) lives at the top of the file.
- `test/tool/build_srd_pkg_test.dart` — 9 tests. Exercises the build function against the live assets: builds without throwing; all 12 catalogs populated; all 8 content lists populated; every entry id namespaced under `srd:`; intra-package refs (`spell.schoolId`, `subclass.parentClassId`) namespaced; per-table id uniqueness; `contentHash` is `sha256:`-prefixed and stable across two builds (determinism); envelope round-trips through `Dnd5ePackageCodec.decode`; envelope carries top-level `contentHash` field for the importer.

Files changed:
- `flutter_app/.gitignore` — adds `/assets/packages/srd_core.dnd5e-pkg.json` to the ignore list. The monolith is a derived artifact regenerable at any time via `dart run tool/build_srd_pkg.dart`. It will be committed (or built in CI) once `SrdBootstrapService` exists and pubspec bundles it.

CLI output on the current asset set:
- contentHash: `sha256:5d33061ef7f604a3a0da3986433385ef59c6b7b3f53b503b04dff3f2f4ff3d66`
- catalogs: 15 conditions, 13 damage types, 18 skills, 6 sizes, 14 creature types, 10 alignments, 19 languages, 8 spell schools, 10 weapon properties, 8 weapon masteries, 4 armor categories, 6 rarities (123 catalog rows total)
- content: 109 spells, 5 monsters, 8 items, 22 feats, 16 backgrounds, 14 species (incl. lineages folded into the species list per the existing package shape), 5 subclasses, 5 class progressions

Decisions:
- **Lineages folded into species** — `Dnd5ePackage` has no separate `lineages` list; the package shape only knows `species: List<NamedEntry>`. Both files concatenate into `species`. The bodies still carry `parentSpeciesId` so consumers can rebuild the hierarchy at use time. If a dedicated `lineages` content type is needed later, the codec + builder both grow at once.
- **Build is a tool, not a runtime step** — the runtime `SrdBootstrapService` (next batch) will load the pre-built monolith from `rootBundle`. Concatenating + namespacing on every cold start would be wasted work; the monolith is built once at dev/CI time and shipped as an asset.
- **`contentHash` written into the envelope** — the canonical hash is computed over a stable representation of the typed entries (per `computeContentHash`), then stamped into the wire envelope as a top-level field. Lets the importer verify integrity without re-reading the entire payload back into typed entries first.
- **Generated monolith gitignored, not committed** — keeps the diff size sane and avoids merge churn over the derived blob. When `SrdBootstrapService` lands and pubspec actually bundles the monolith, we'll either commit it (with regen-in-CI as a safety net) or generate at build time. That decision is part of the SrdBootstrapService batch, not this one.
- **CLI is library-importable** — `buildSrdPackage()` is exported as a top-level function so the test can call it without spawning a subprocess. `main()` is a thin wrapper that handles file IO + stdout reporting only.

Verification: `flutter analyze` 0 issues, `flutter test` 1408/1408 pass + 1 skipped (1399 → 1408, +9). CLI runs end-to-end (`dart run tool/build_srd_pkg.dart` succeeds, writes 156 KB monolith, prints the per-table report).

Next up:
- `SrdBootstrapService` — `Dnd5ePackageImporter.import(monolith)` on first launch in a per-user txn; flag in shared_prefs so subsequent launches no-op. Will need pubspec bundling of the monolith and a decision on commit-vs-CI-gen at that point.
- 9 `CustomEffect` impls — Wish, WildShape, Polymorph, AnimateDead, Simulacrum, SummonFamily, ConjureFamily, Shapechange, GlyphOfWarding. Register at startup so `requiredRuntimeExtensions` validation passes when a spell body declares an effect with `t: "custom", implementationId: "srd:wish"`.
- CC BY 4.0 attribution UI — small screen reachable from settings, displays `sourceLicense` + `authorName` from the loaded SRD package.
- Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 `main.dart` wiring) — still gated on `_backupV4DbBeforeReset`.

### 2026-04-19 — Doc 11 EncounterService lifecycle integration tests (🟣) — Phase C end-to-end event ordering

10-step batch locking down the multi-step event ordering of the lifecycle hook surface shipped in the previous turn. Per-method tests already cover individual emissions; this batch chains attack→damage→drop→advance→tick→condition flows through one `RecordingEncounterHook` and asserts the full event stream so future regressions in hook emission order, drop-guard semantics, or rotation/round interactions are caught at the integration boundary.

Files added (test):
- `test/application/dnd5e/combat/encounter_lifecycle_integration_test.dart` — 10 scenarios sharing one set of helpers (`_mc`, `_enc`, `_service`, `_hit`):
  1. **Damage→drop chain** — lethal hit on `b` emits `[DamageDealt, CombatantDropped]`; verifies `newCurrentHp == 0` on the damage event and combatant id on the drop.
  2. **Damage→break-concentration→advance** — damage with `autoFailSave: true` against a Bless-concentrating monster, then `advanceTurn`. Asserts full sequence `[DamageDealt, ConcentrationBroken, EndOfTurn, StartOfTurn]` and that the `spellId` survived from the pre-snapshot.
  3. **Two-round wrap** — two consecutive `advanceTurn` calls emit `[End, Start, End, RoundAdvanced, Start]`; verifies `previousRound: 1, round: 2` and that the post-wrap start lands on `'a'`.
  4. **Two-tick expiry** — `applyCondition(durationRounds: 2)` then `tickConditions` twice. First tick decrements silently (no expiry event); second tick fires `ConditionExpired`. Full stream is `[ConditionAdded, ConditionExpired]` — no spurious events between.
  5. **Round wrap is not auto-tick** — apply duration-1 condition, advance turn so the round wraps. No `ConditionExpired` fires from the round advance — caller must invoke `tickConditions` explicitly. The follow-up tick then fires the expiry. Locks the contract that round-tracking and condition-tracking are decoupled.
  6. **Sequential damage to two targets** — `applyDamage` to `b`, then to `c`. `of<DamageDealtEvent>` returns both in emission order with the right `targetId` + `amountAfterMitigation`; no drops.
  7. **Apply→remove→re-apply** — emits `[Added, Removed, Added]`; the two `Added` events carry distinct `durationRounds` (10, 5).
  8. **Drop guard across two hits** — first hit drops `b`, second hit at 0 HP emits only `DamageDealt` (no second `Dropped`). Full stream: `[Damage, Dropped, Damage]` — exactly two damage events, exactly one drop event.
  9. **Composite hook fan-out** — wraps two `RecordingEncounterHook`s in `CompositeEncounterHook`, runs damage + advance, asserts both recorders receive the same length-5 stream `[Damage, Dropped, End, RoundAdvanced, Start]`. The round-advance comes from rotation skipping the dropped `b`, which surfaces a non-obvious interaction worth pinning: a drop during `applyDamage` then `advanceTurn` wraps because the only other combatant is now skip-eligible.
  10. **`of<T>()` filters across mixed sequence** — apply condition to `c`, damage `b` to 0, advance, tick. Asserts per-type counts (1 each of `ConditionAdded`, `DamageDealt`, `CombatantDropped`, `EndOfTurn`, `StartOfTurn`, `ConditionExpired`), total event count equals the sum (6 — no event dropped by filtering), final event is the explicit-tick expiry.

Decisions:
- **Helpers duplicated, not shared, with `encounter_service_lifecycle_test.dart`** — both files are consumers of the same surface; sharing helpers via a test-utility file would couple their evolution. Per-method tests assert one event at a time; integration tests assert the whole stream — different contracts, different setups.
- **Closure-based `_hit(amount, {concentration, autoFailSave})`** — collapses the verbose `buildInput` for plain damage cases so each scenario stays under ~20 lines and scenario intent reads at the call site.
- **Step 9 expectation pinned at 5 events, not 4** — initially expected `[Damage, Dropped, End, Start]` (4 events). The actual stream is 5: `TurnRotationService` skips dropped `b` and wraps to `a`, surfacing an extra `RoundAdvancedEvent`. This is a real and useful behavior to lock — it documents that drops during the active actor's damage step affect the immediate next `advanceTurn`'s rotation arithmetic.
- **No new lib code** — all 10 scenarios exercise the surface from the previous turn unchanged. If a scenario needed a new hook event or service method, it would belong in a separate batch (the lifecycle hook design is now considered closed for this slice).

Verification: `flutter analyze` 0 issues, `flutter test` 1399/1399 pass + 1 skipped (1389 → 1399, +10).

Next up:
- Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 `main.dart` wiring) — still gated on `_backupV4DbBeforeReset`.
- Doc 31 component lib (precondition for Doc 10/32/33 UI work).
- Phase B SRD content authoring continuation (8 catalogs remaining: armor_categories, weapon_masteries, rarities, spell_schools, alignments, creature_types, weapon_properties, languages).

### 2026-04-19 — Doc 11 EncounterService lifecycle hooks (🟣) — Phase C event surface

10-step batch wrapping the EncounterService composer with an event/observer layer so UI, AI cues, session journal, and tests can react to combat lifecycle moments without diffing snapshots themselves. Hooks are pure observers — they cannot mutate the encounter (state changes still go through service methods), and the service is the only thing that emits events.

Files added (lib):
- `lib/application/dnd5e/combat/encounter_event.dart` — sealed `EncounterEvent` family (9 variants): `StartOfTurnEvent`, `EndOfTurnEvent`, `RoundAdvancedEvent`, `DamageDealtEvent` (with previous/new HP snapshot, attackerId, damage type, dropsToZero, instantDeath flags), `CombatantDroppedEvent` (transition-to-0 only — no spam if hit at 0), `ConcentrationBrokenEvent` (carries the spellId from the pre-check `Concentration` since the post-check value is null), `ConditionAddedEvent` / `ConditionRemovedEvent` / `ConditionExpiredEvent` (the latter only fired by the round tick — explicit removal vs natural expiration are distinguishable downstream).
- `lib/application/dnd5e/combat/encounter_hook.dart` — `EncounterHook` abstract class with no-op default `on(event)` (subclasses override only what they care about via pattern match in one method) + `CompositeEncounterHook` fan-out (preserves order, unmodifiable list, `.empty()` const ctor used as `EncounterService` default).
- `lib/application/dnd5e/combat/recording_encounter_hook.dart` — `RecordingEncounterHook` journaling helper. `events` exposes an unmodifiable snapshot, `of<T>()` filters by event subtype for ergonomic test assertions, `clear()` resets between scenarios.

Files changed (lib):
- `lib/application/dnd5e/combat/encounter_service.dart`:
  - New `hook` field (defaults to `CompositeEncounterHook.empty()` so existing callers compile unchanged).
  - `applyDamage` now snapshots `previousHp` + `previousConcentration` before the pipeline run, then emits `DamageDealtEvent` always, `CombatantDroppedEvent` only when `previousHp > 0` and `dropsToZero || instantDeath`, and `ConcentrationBrokenEvent` when the concentration check returned `broken`.
  - `advanceTurn` snapshots prior actor + prior round, then emits `EndOfTurnEvent` (with prior round), `RoundAdvancedEvent` (only when round number changed), `StartOfTurnEvent` (with new round).
  - `tickConditions` emits one `ConditionExpiredEvent` per `(combatant, expiredConditionId)` pair returned by `ConditionTickService.tickAll`.
  - New `applyCondition({encounterId, combatantId, conditionId, durationRounds?})` returning `EncounterConditionMutationOutcome { encounter, changed }`. Same-condition+same-duration is a no-op (no event, no save). Different duration overwrites and emits. Null `durationRounds` removes any tracked counter (open-ended condition).
  - New `removeCondition({encounterId, combatantId, conditionId})` mirror with `ConditionRemovedEvent`. Removing an absent condition is a no-op.
  - New `_writeConditions(c, ids, durations)` sealed switch helper paralleling `_writeHp`.

Files added (test): one parallel test file per lib file (`encounter_event_test.dart`, `encounter_hook_test.dart`, `recording_encounter_hook_test.dart`) plus `encounter_service_lifecycle_test.dart` covering the seven service-level wirings end-to-end. +30 tests total. Highlights:
- `encounter_event_test.dart` — exhaustive sealed-switch coverage of all 9 variants.
- `encounter_hook_test.dart` — empty composite drops events silently, fan-out preserves order, subclass-filtered hook ignores non-matching events, hook list unmodifiable.
- `recording_encounter_hook_test.dart` — `of<T>()` filters by subtype across mixed event streams.
- `encounter_service_lifecycle_test.dart` — DamageDealt with full HP snapshot; CombatantDropped on transition only (hit-at-0 emits no drop); ConcentrationBroken via `autoFailSave: true` on a Bless-concentrating monster; advanceTurn End→Start with no Round when not wrapping; advanceTurn End→Round→Start when wrapping (uses `InitiativeOrder.advance()` to start mid-order); tickConditions emits one event per expired pair across multiple combatants; applyCondition no-op when same duration, open-ended path with null duration; removeCondition no-op when absent.

Decisions:
- **Hooks are pure observers, not state machines** — the only way to mutate the encounter is through service methods. Hooks that need to trigger follow-up changes (e.g. an AI cue queue) must do that out-of-band. This keeps the event flow strictly downstream and removes the ambiguity of "did the hook's reaction fire before or after the next service call?"
- **`previousCurrentHp` carried on the event, not derived** — saves every listener from re-loading the encounter or diffing snapshots themselves. The DamageOutcome already gives `dropsToZero`, but UI also wants the absolute starting HP for the "10 → 6" toast.
- **`CombatantDroppedEvent` requires `previousHp > 0`** — without this guard, a hit on an already-0-HP target re-emits the drop event every round. PCs at 0 HP are unconscious, not dropping repeatedly; the second hit is for death-save failures (separate event family, future work).
- **`ConcentrationBrokenEvent.spellId` is captured pre-check** — `ConcentrationCheckOutcome.concentrationAfter` is null on break, so the post-check value carries no spell id. The service snapshots `target.concentration` before the pipeline runs.
- **`applyCondition` no-op semantics** — same condition + same duration returns `changed: false` and emits nothing. Different duration *does* emit (fresh stack), since the duration-rebase is a meaningful re-application. Null vs explicit duration are distinguishable.
- **Default hook is `CompositeEncounterHook.empty()`, not nullable** — keeps the call sites flat (`hook.on(...)` always works, no `?.`) and existing constructor calls still compile because the field has a `const` default.
- **No `OnConditionApplied` lifecycle distinct from `ConditionAddedEvent`** — the docstring originally tracked these as separate concepts but they collapsed: any add path goes through `applyCondition` and fires the same event. If a condition needs an "on-apply" trigger that runs effect resolution (e.g. Bless's bonus to attack rolls), that's effect-source / accumulator territory, not lifecycle.

Verification: `flutter analyze` 0 issues, `flutter test` 1389/1389 pass + 1 skipped (1359 → 1389, +30).

Next up:
- Lifecycle integration tests at the encounter level (multi-step combat scenario combining attack → damage → drop → tick → expire flowing through one RecordingHook) to lock the end-to-end ordering.
- Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 main.dart wiring) — still gated on `_backupV4DbBeforeReset`.
- Doc 31 component lib (precondition for Doc 10/32/33 UI work).

### 2026-04-19 — Doc 11 EncounterService composition slice (🟣) — Phase C effect-modifier dispatch end-to-end

10-step batch shipping every layer between the just-landed `EffectAccumulator` and the encounter aggregate. Pure pipelines fold descriptor effects into the existing resolvers; a top-level `EncounterService` plumbs them through the repository boundary using `Combatant.copyWith` for write-back.

Files added (lib):
- `lib/application/dnd5e/effect/combatant_effect_source.dart` — `CombatantEffectSource` walks a [Combatant]'s active conditions plus an optional `inherentEffects` callback, producing a flat `List<EffectDescriptor>` (inherent first, then conditions in insertion order). Both lookups are typedef'd (`ConditionEffectsLookup`, `InherentEffectsLookup`) so the SRD content registry can plug in later.
- `lib/application/dnd5e/effect/effect_context_builder.dart` — `EffectContextBuilder` flattens [Combatant] state into [EffectContext]. Three constructors: `forAttack(attacker, target, reach, …)`, `forDamage(attacker, target, damageTypeId, …)`, `forSelfSave(saver, …)`. On a self-save the saver's conditions populate the `attackerConditions` slot since that slot reads as "carrier of this side of the effect".
- `lib/application/dnd5e/combat/attack_pipeline.dart` — `AttackPipeline { effectSource, accumulator, contextBuilder, resolver }`. Collects descriptors on both sides, builds the context, accumulates `appliesTo: attacker` and `appliesTo: targeted` separately, sums their `flatBonus` with the caller's `weaponBonus`, combines their advantage states, and runs [AttackResolver]. Returns `AttackPipelineResult { roll, attackerContribution, targetContribution, extraAttackDice }`. Extra dice are surfaced for the damage step but **not** rolled here.
- `lib/application/dnd5e/combat/damage_pipeline.dart` — `DamagePipeline { effectSource, accumulator, contextBuilder, applyPipeline }`. Folds attacker-side `ModifyDamageRoll.flatBonus` into a base `DamageInstance`, applies `damageTypeOverride` (last-wins per `EffectAccumulator` contract), then delegates to `ApplyDamagePipeline` for resistance/concentration. Surfaces `extraDice`/`extraTypedDice` via `DamagePipelineResult.contribution` — caller rolls them and runs additional pipeline calls per type so per-type resistances apply (Doc 11 §Multi-Type).
- `lib/application/dnd5e/combat/save_pipeline.dart` — `SavePipeline { effectSource, accumulator, contextBuilder, resolver }`. Folds matching `ModifySave` `flatBonus`, combines descriptor `advantage` with caller-provided `baseAdvantage`, surfaces both auto-flags raw so [SaveResolver]'s `autoFail`-wins precedence applies in one place.
- `lib/application/dnd5e/combat/turn_rotation_service.dart` — `TurnRotationService { skip }`. Pure rotation layered on `Encounter.advanceTurn`: walks forward until the active combatant fails the skip predicate (default: `currentHp == 0`). All-skip case (TPK) returns one-step advance — caller decides idle-round semantics.
- `lib/application/dnd5e/combat/condition_tick_service.dart` — `ConditionTickService` decrements every `conditionDurationsRounds` entry by 1; entries hitting 0 are removed from both the duration map and the active condition set. Open-ended conditions (in the set, no duration entry) untouched. Returns `ConditionTickResult { combatant, expiredConditionIds }`. Sealed switch on `Combatant` to call the right `copyWith`.
- `lib/application/dnd5e/combat/encounter_mutator.dart` — `EncounterMutator { replaceCombatant, replaceAll }`. Pure helpers; preserves id/name/order/round on every rebuild. `replaceCombatant` throws `StateError` for unknown id.
- `lib/application/dnd5e/combat/encounter_repository.dart` — `EncounterRepository` interface (`findById` / `save` / `delete` / `listAll`) + `InMemoryEncounterRepository`. The map-backed impl unblocks service-layer tests and offline-mode bring-up before the Drift schema for combatants lands.
- `lib/application/dnd5e/combat/encounter_service.dart` — `EncounterService` composer wiring: `runAttack(encounterId, attackerId, targetId, buildInput)`, `applyDamage(...)` (writes new HP back through `Combatant.copyWith` — `MonsterCombatant.instanceCurrentHp` direct, `PlayerCombatant.character.hp` via rebuilt [HitPoints]), `requestSave(...)`, `advanceTurn(...)` (delegates to `TurnRotationService`), `tickConditions(...)` (delegates to `ConditionTickService` + `EncounterMutator.replaceAll`). All throw `StateError` for missing encounter/combatant. Builders are caller-supplied closures so the service stays oblivious to ability-mod sourcing — that's the encounter UI's job once it lands.

Files added (test): one parallel test file per lib file, +57 tests total. Highlights:
- `attack_pipeline_test.dart` — bless flatBonus path, target-side `appliesTo: targeted`, advantage cancellation across sides, extraDice ordering, inherent-effect path.
- `damage_pipeline_test.dart` — base passthrough, ModifyDamageRoll +N folded pre-mitigation, `damageTypeOverride` reroutes through resistance check on the new type, extra dice surfaced not rolled.
- `save_pipeline_test.dart` — matching ability filter, autoFail beats autoSucceed when both surface, descriptor advantage combines with baseAdvantage.
- `turn_rotation_service_test.dart` — default skip-at-0-hp, round increments only on wrap, TPK no-infinite-loop guarantee, custom predicate.
- `condition_tick_service_test.dart` — duration decrement, 1→expire flow, open-ended conditions untouched.
- `encounter_service_test.dart` — runAttack/applyDamage/requestSave/advanceTurn/tickConditions happy paths, StateError for missing ids, end-to-end attacker-effect flow through `applyDamage`.

Decisions:
- **Three pipelines instead of one polymorphic `runEffect`** — attack/damage/save have disjoint inputs (AC vs DC, ability filter vs not, target side vs not). Splitting matches the existing `AttackResolver`/`DamageResolver`/`SaveResolver` boundary one-to-one.
- **`extraDice` not rolled inside the pipeline** — surfacing them lets the caller decide damage type per die (e.g. Sneak Attack rides the weapon damage type; Hexblade's Curse adds necrotic). Forcing rolls here would either need a second pass for typing or an opinionated default.
- **`damageTypeOverride` applied before ApplyDamagePipeline** — resistance check needs to see the post-override type. Last-wins matches `EffectAccumulator` contract.
- **TurnRotationService default skips at 0 HP, not per-condition** — keeping `unconscious` / `incapacitated` / `paralyzed` in scope here would couple to the SRD content registry. Caller can pass a custom predicate that consults a registry once it lands.
- **`EncounterRepository` interface even though only one impl exists** — the Drift impl is genuinely separate work (blocked on Doc 03 row shapes for combatants). Splitting now keeps the seam visible.
- **`EncounterService.buildInput` callbacks** — the service has no opinion on ability-mod sourcing (PC: derived from class/ability scores; monster: from stat block + actions list). Closures push that to the caller, which today is tests and tomorrow is the encounter UI.
- **PC HP write-back rebuilds [HitPoints] rather than `withCurrent`** — no `withCurrent` exists; rebuild via factory preserves max + temp and re-runs invariants.
- **Single switch on `Combatant` in `_writeHp` / `ConditionTickService.tick`** — sealed family means exhaustive; better than an abstract method on `Combatant` because the differing fields (`instanceCurrentHp` vs `character.hp`) belong on the concrete cases.

Verification: `flutter analyze` 0 issues, `flutter test` 1359/1359 pass (1 skipped). +57 tests this turn (10-step batch).

Next candidates: full `Doc 11 EncounterService` doc cross-check + lifecycle hook design (start-of-turn, end-of-turn, on-condition-apply); UI wiring (Doc 31 component lib needed first). Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 main.dart) still gated on `_backupV4DbBeforeReset`.

### 2026-04-19 — Doc 11 Combatant.copyWith sweep (🟣) — Phase C foundation for EncounterService writes

Added `copyWith` to both `PlayerCombatant` and `MonsterCombatant`. Foundation work — no behavior change yet, but unblocks the future `EncounterService` boundary where per-combatant state (HP, conditions, concentration, position, turn state) is mutated and written back through the repository layer.

Files changed:
- `lib/domain/dnd5e/combat/combatant.dart` — `PlayerCombatant.copyWith({character, initiativeRoll, conditionIds, conditionDurationsRounds, concentration, clearConcentration, turnState, mapPosition, clearMapPosition})` and parallel `MonsterCombatant.copyWith({instanceMaxHp, instanceCurrentHp, initiativeRoll, conditionIds, conditionDurationsRounds, concentration, clearConcentration, turnState, mapPosition, clearMapPosition})`. Both delegate to the existing factory so all factory invariants (HP range, content-id shape, etc.) re-run on every copy.
- `test/domain/dnd5e/combat/combatant_test.dart` — 14 tests in 2 groups covering: identity copy preserves all fields; per-field overrides; HP delegation through replaced `Character`; `clearConcentration` / `clearMapPosition` semantics (including precedence over a non-null param in the same call); factory validation re-runs (out-of-range `instanceCurrentHp` rejected); immutability (`identical` is false; original untouched); `MonsterCombatant.definition` and `id` not exposed as overridable params (instance-identity preserved).

Decisions:
- **Convention for nullable fields**: explicit `clearConcentration` / `clearMapPosition` boolean params instead of a sentinel object. Standard Dart convention, no precedent for sentinels in this codebase.
- **`MonsterCombatant.definition` and `id` not in `copyWith` signature**: a `MonsterCombatant` *is* an instance of one definition with a stable per-instance id. Replacing either would create a different combatant, not copy this one. Encoding this in the API prevents accidental swap.
- **Factory re-runs validation**: `copyWith(instanceCurrentHp: -1)` throws, matching factory behavior. Avoids drift between construction and mutation paths.
- **`Set`/`Map` parameters take pre-validated content ids (no re-walk)**: factory calls `validateContentId` on every entry — copyWith inherits this for free since it goes through the factory.

Verification: `flutter analyze` 0 issues, `flutter test` 1302/1302 pass (1 skipped). +14 tests this turn.

Next candidates: now that `Combatant.copyWith` exists, the `EncounterService` boundary work for Doc 11 can proceed (collects active `EffectDescriptor`s per combatant, runs the resolver chain, writes back via `copyWith`). Alternatively the Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 wiring).

### 2026-04-19 — Doc 13 EffectAccumulator (🟣) — Phase C reducer over EffectDescriptor

Second slice of the EffectDescriptor dispatch layer. Consumes the just-shipped `PredicateEvaluator` to fold a `List<EffectDescriptor>` into three structured contribution buckets that downstream resolvers (`AttackResolver` / `DamageResolver` / `SaveResolver`) consume.

Files added:
- `lib/application/dnd5e/effect/effect_accumulator.dart` — three reducer methods on `EffectAccumulator` plus three contribution structs:
  - `accumulateAttack(descriptors, ctx, {appliesTo})` → `AttackContribution { flatBonus, advantage, extraDice }`. Filters `ModifyAttackRoll` only; respects `appliesTo` (attacker vs targeted side); combines `AdvantageState` via `combine` (SRD cancellation rule).
  - `accumulateDamage(descriptors, ctx)` → `DamageContribution { flatBonus, extraDice, extraTypedDice, damageTypeOverride }`. Filters `ModifyDamageRoll`; concatenates `extraDice`/`extraTypedDice`; `damageTypeOverride` is the last non-null override in iteration order.
  - `accumulateSave(descriptors, ctx, {required ability})` → `SaveContribution { flatBonus, advantage, autoSucceed, autoFail }`. Filters `ModifySave` matching the requested ability. Both auto-flags surfaced — precedence is the resolver's job (`SaveResolver` already prefers autoFail).
  - All three skip descriptors where `evaluator.evaluate(when, ctx)` is false.
- `test/application/dnd5e/effect/effect_accumulator_test.dart` — 15 tests in 4 groups: attack (empty, sum, advantage cancel, when-gating, appliesTo filter, extraDice order), damage (empty, sum + extras, override last-wins, when-gating), save (empty, ability filter, both auto flags, advantage cancel, when-gating), non-modify descriptors ignored across all three accumulators.

Decisions:
- **Three reducer methods, not one polymorphic one** — each contribution shape is genuinely different (advantage vs not, ability filter vs not). Splitting keeps callers from passing junk parameters.
- **`damageTypeOverride` last-wins, not first-wins or throw** — matches "later descriptor wins" intuition for layered effects (e.g. Elemental Adept on top of weapon damage type). Documented in the dartdoc; content authors who care about determinism order their lists.
- **Both `autoSucceed` and `autoFail` surfaced when present from different descriptors** — accumulator is dumb folder, resolver decides. Avoids duplicating the precedence rule in two places.
- **Non-modify descriptors silently ignored** (`Heal`, `GrantCondition`, `GrantProficiency`, …) — they have different lifecycle hooks (heal at end of turn / spell cast, grant on apply, …). Throwing here would force callers to pre-filter; ignoring lets them pass the unfiltered descriptor list straight from the entity.
- **`PredicateEvaluator` injected via constructor with `const` default** — accumulator and evaluator both stateless, but the seam is there for tests that want to mock predicate evaluation without building real `EffectContext`s.

Verification: `flutter analyze` 0 issues, `flutter test` 1288/1288 pass (1 skipped). +18 tests this turn.

Next candidates: wire `EffectAccumulator` into `AttackResolver`/`DamageResolver`/`SaveResolver` call sites at the `EncounterService` boundary (needs `Combatant.copyWith` sweep first, since the service is the one collecting active descriptors per combatant), `Combatant.copyWith` sweep itself, or the Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 wiring — still gated on `_backupV4DbBeforeReset`).

### 2026-04-19 — Doc 13 PredicateEvaluator (🟣) — Phase C effect-dispatch foundation

First slice of the EffectDescriptor dispatch layer. Pure recursive evaluator over the sealed `Predicate` family — the `when:` field on every `ModifyAttackRoll` / `ModifyDamageRoll` / `ModifySave` / `ModifyAc` will run through this. No live combatant references; caller flattens state into `EffectContext`.

Files added:
- `lib/application/dnd5e/effect/effect_context.dart` — value type with `attackerConditions`/`targetConditions` (Sets of `ContentReference<Condition>`), `attackReach` (`enum AttackReach { none, melee, ranged }`), `attackAbility`, `weaponProperties`, `damageTypeId`, `isCritical`, `hasAdvantage`, `activeEffectIds`. All sets `Set.unmodifiable` at construction. Defaults are conservative (`none` reach, false flags, empty sets) so non-attack contexts can omit attack fields.
- `lib/application/dnd5e/effect/predicate_evaluator.dart` — `const PredicateEvaluator()` with single `bool evaluate(Predicate, EffectContext)` method. Sealed `switch` covers all 12 predicate cases. `Always` true, `Not` flips, `All` vacuously true on empty list, `Any` false on empty list.
- `test/application/dnd5e/effect/predicate_evaluator_test.dart` — 17 tests in 5 groups: atoms (`Always`/`IsCritical`/`HasAdvantage`), combinators (`Not`/`All`/`Any` plus empty-list edge cases plus nested combinator), attacker/target conditions (id match, attacker conditions don't satisfy target predicate), attack-shape (`AttackIsMelee`/`AttackIsRanged` reach gating, `AttackUsesAbility` ability match), weapon/damage/effect (`WeaponHasProperty`/`DamageTypeIs`/`EffectActive` id match).

Decisions:
- **Three-state attack reach (`none`/`melee`/`ranged`)** — neither `AttackIsMelee` nor `AttackIsRanged` should fire when the predicate is evaluated outside an attack (e.g. a passive feature checking carrier conditions). A nullable bool would have collapsed to `false` and silently behaved the same, but the enum makes the third state explicit at the call site.
- **`damageTypeId` nullable** — only set during a damage roll. `DamageTypeIs` returns false on null context, matching the "don't fire outside a damage roll" intent.
- **Empty `All` is true, empty `Any` is false** — the standard fold identities. Avoids a special-case for "no constraints" lists since codecs may emit empty `All`/`Any` from empty JSON arrays.
- **No registry lookups in the evaluator** — `EffectActive(effectId)` checks against pre-flattened `activeEffectIds`. The caller (combat service) is the one that knows the active effect set; the evaluator stays a pure function of its two arguments.

Verification: `flutter analyze` 0 issues, `flutter test` 1270/1270 pass (1 skipped). +18 tests this turn.

Next candidates: `EffectAccumulator` (consumes `PredicateEvaluator` to reduce a `List<EffectDescriptor>` into `AttackContribution`/`DamageContribution`/`SaveContribution` for `AttackResolver`/`DamageResolver`/`SaveResolver`), `Combatant.copyWith` sweep (still the biggest single unblock for `EncounterService`), or the Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 wiring).

### 2026-04-19 — Doc 12 SpellCastValidator + Service: Pact Magic (🟣) — Phase C Warlock support

Extends the already-shipped `SpellCastValidator` + `SpellCastService` + `CastOutcome` trio with Warlock pact-magic casting. Pact slots live in their own table (`PactMagicSlots`: single level, refresh on short rest), so the validator/service must branch on which pool to spend.

Files changed:
- `lib/application/dnd5e/spell/spell_cast_validator.dart` — adds `PactMagicSlots? pactSlots, bool usePactSlot = false` parameters. New branch fires after cantrip + ritual paths: requires `pactSlots != null`, `current ≥ 1`, `slotLevel ≥ spell.level`, and (if `slotLevelChosen` non-null) `slotLevelChosen == pactSlots.slotLevel`. Prepared check still applies.
- `lib/application/dnd5e/spell/spell_cast_service.dart` — same params; on success spends pact slot instead of regular slot, sets `pactCastLevel = pactSlots.slotLevel`, threads it into the `Concentration.castAtLevel` so concentration upcasting tracks the actual pact level.
- `lib/application/dnd5e/spell/cast_outcome.dart` — adds `PactMagicSlots? pactSlots` field (mirrors `slots`: input on failure/no-spend, decremented when pact slot spent) and `bool pactSlotConsumed` (mutually exclusive with `slotConsumed`). `CastOutcome.error` and `CastOutcome.success` factories both accept the new field.
- `test/application/dnd5e/spell/spell_cast_validator_test.dart` — +7 tests in a `pact magic` group: happy path, no pactSlots, no slots remaining, spell level above pact level, mismatched chosen slot, equal chosen slot, not prepared, cantrip ignores `usePactSlot`.
- `test/application/dnd5e/spell/spell_cast_service_test.dart` — +4 tests: pact spend decrements pactSlots not regular, failed cast echoes pactSlots unchanged, pact concentration cast records pact level as `castAtLevel`, cantrip with `usePactSlot` does not spend pact slot.

Decisions:
- **Explicit `usePactSlot` rather than auto-detect** — Warlock multi-classed with another caster could choose either pool (per SRD). Letting the caller (UI/notifier) state intent keeps the validator/service honest and avoids hidden policy.
- **`slotLevelChosen` optional on pact path** — pact slots only have one valid level, so passing `null` is the natural call. If the UI sends a non-null value, it must match the pact level (else error) — protects against the UI showing a level picker by accident.
- **`CastOutcome.pactSlots` mirrors `slots`** — same input/output contract: present and unchanged on failure or non-pact cast, decremented on pact spend. Keeps the consumer code symmetric (write back both fields, no special-casing).
- **`pactCastLevel` overrides `slotLevelChosen` for concentration** — when pact slot was spent, `Concentration.castAtLevel` reflects the pact level, not whatever was passed in `slotLevelChosen`. Matches "the spell was actually cast at level X" semantics needed by upcast scaling.

Verification: `flutter analyze` 0 issues, `flutter test` 1252/1252 pass (1 skipped). +11 tests this turn.

Next candidates: `Combatant.copyWith` sweep (still the biggest single unblock for `EncounterService` repo writes — non-trivial because PlayerCombatant.HP delegates through Character.hp), `SpellEffectDispatcher` (Doc 13 — wires `CastOutcome.success` to compiled `EffectDescriptor` registry), or the Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 wiring — still gated on `_backupV4DbBeforeReset`).

### 2026-04-19 — Doc 13 AoEDamageOrchestrator (🟣) — Phase C area-of-effect

Single-roll multi-apply per SRD §11.6: damage rolled once, broadcast to every target inside the AoE coverage. Composes existing `AreaOfEffect.coverage` (geometry) + `SaveResolver` (per-target spell save) + `ApplyDamagePipeline` (damage + concentration). Pure — no Combatant mutation.

Files added:
- `lib/application/dnd5e/combat/aoe_target.dart` — per-target input bundle: `{id, position, defenses, spellSaveAbilityMod/ProfBonus/Advantage/auto…, concentration?, conMod, concentrationSaveProfBonus/Advantage/auto…}`. Flat record; orchestrator never reads `Combatant`.
- `lib/application/dnd5e/combat/aoe_target_outcome.dart` — per-target result: `{spellSave: SaveResult?, damage: ApplyDamageOutcome}`. `spellSave` null when the spell offers no save.
- `lib/application/dnd5e/combat/aoe_damage_orchestrator.dart` — `apply({area, origin, direction, targets, damageAmount, damageTypeId, saveAbility?, saveDc?, isCritical, sourceSpellId})` returning `Map<id, AoETargetOutcome>`. Filters by `area.coverage(origin, direction)` first; for each survivor rolls the spell save (if `saveDc` non-null), builds `DamageInstance(fromSavedThrow: saveDc != null, savedSucceeded: …)`, runs the pipeline.
- `test/application/dnd5e/combat/aoe_damage_orchestrator_test.dart` — 9 tests across coverage filter (out-of-area skipped, only in-area resolved), save-for-half (success halves, fail full, null saveDc skips spell save, save+ability paired-or-neither, resistance after save halving), concentration in AoE (damaged concentrator rolls conc save post-spell-save, non-concentrator skips), input validation (negative damage rejected).

Decisions:
- **Save inside, damage outside** — orchestrator owns the per-target spell save (it's an AoE-specific concern: same DC + ability across targets, but each target rolls its own d20). Damage roll comes in pre-rolled by the caller per the SRD "rolled once" rule, so the orchestrator stays free of dice for the damage value itself.
- **`saveDc + saveAbility` paired** — both null = no save spell (Magic Missile-style); both set = save-for-half. Mixed = ArgumentError. Avoids the silent bug where a caller sets DC but forgets the ability.
- **Concentration check delegated to `ApplyDamagePipeline`** — keeps the orchestrator focused on AoE-specific concerns; concentration math is universal and already lives in the pipeline. Per-target conc params flow through the `AoETarget` bundle.
- **Pre-rolled damage value, not a `DamageRollResult`** — the existing pipeline takes a flat `int amount`. Following that convention rather than introducing a new value type for "the AoE rolled this once."

Verification: `flutter analyze` 0 issues, `flutter test` 1241/1241 pass (1 skipped). +9 tests this turn.

Next candidates: `Combatant.copyWith` sweep (unblocks `EncounterService` repo writes — non-trivial because PlayerCombatant.HP delegates through Character.hp), `SpellEffectDispatcher` (Doc 13 — wires `CastOutcome.success` to compiled `EffectDescriptor` registry), or the Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 wiring — still gated on `_backupV4DbBeforeReset`).

### 2026-04-19 — Doc 11 ApplyDamagePipeline (🟣) — Phase C combat composition

Composes the just-shipped `ConcentrationCheckResolver` with the existing `DamageResolver` so the EncounterService apply-damage flow becomes a single pure call. No `Combatant.copyWith` dependency yet — the pipeline returns a value and the caller writes back.

Files added:
- `lib/application/dnd5e/combat/apply_damage_outcome.dart` — `{damage: DamageOutcome, concentration: ConcentrationCheckOutcome?}` plus a `concentrationBroken` convenience getter. `concentration` is null when no save was rolled (no current concentration, immune/zero damage, or instant death).
- `lib/application/dnd5e/combat/apply_damage_pipeline.dart` — `apply({target, damage, concentration?, conMod, saveProfBonus, saveAdvantage, autoSucceedSave, autoFailSave})`. Skips the concentration save when `instantDeath` (caller treats death as ending concentration without rolling).
- `test/application/dnd5e/combat/apply_damage_pipeline_test.dart` — 9 tests across two groups: concentration gating (no concentration → no save, immune target → no save, instant death → no save) and save pipeline (pass keeps, fail breaks, resistance halves before DC, advantage picks higher d20, autoFail breaks regardless of mod, prof bonus added).

Decisions:
- **Skip-on-instant-death** — even though `concentrationCheckTriggered` is true on a killing blow, rolling the save is meaningless (the target is dead). Pipeline returns `concentration = null` in that case; callers reading `concentrationBroken` won't see a misleading "save passed" on a corpse.
- **Save inputs flow through, not derived** — `conMod`, `saveProfBonus`, `saveAdvantage`, `autoFail`/`autoSucceed` are all caller-supplied. The pipeline doesn't read `Combatant` so it stays usable from preview UI ("if a Fireball lands, do I still keep Bless?").
- **MVP scope is damage-driven only** — incapacitation breaks and "killed by other means" still belong to `EncounterService` / condition-tick code per Doc 12.

Verification: `flutter analyze` 0 issues, `flutter test` 1233/1233 pass (1 skipped). +9 tests this turn.

Next candidates: `Combatant.copyWith` sweep (unblocks `EncounterService` repository writes + the spec's `ConcentrationManager`), `SpellEffectDispatcher` (Doc 13 — wires `CastOutcome.success` to compiled `EffectDescriptor` registry), or the Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 wiring — still gated on `_backupV4DbBeforeReset`).

### 2026-04-19 — Doc 12 ConcentrationCheckResolver (🟣) — Phase C damage→save→break/keep

Pure damage-driven concentration check, decoupled from `Combatant`. Composes existing `ConcentrationDc.forDamage` (DC formula, capped at 30) with the existing `SaveResolver` (advantage / autoFail / autoSucceed mechanics), so the formula and the save mechanics stay in one place each.

Files added:
- `lib/application/dnd5e/spell/concentration_check_outcome.dart` — `{damage, dc, save: SaveResult, concentrationAfter: Concentration?}`. `concentrationAfter` is the same `Concentration` on success / null on break, so callers can write the value back to the snapshot unconditionally. `broken` / `maintained` getters for ergonomics.
- `lib/application/dnd5e/spell/concentration_check_resolver.dart` — `check({current, damage, conMod, saveProfBonus, advantage, autoSucceed, autoFail})`. CON ability hard-coded (per SRD); `saveProfBonus` is a flat number so the caller decides whether the concentrator is proficient.
- `test/application/dnd5e/spell/concentration_check_resolver_test.dart` — 11 tests across two groups: DC formula (floor at 10, mid-range floor(d/2), cap at 30, negative damage rejected) and save outcomes (pass keeps, fail breaks, prof bonus added, advantage picks higher d20, autoFail breaks regardless of mod, autoSucceed keeps regardless of damage).

Decisions:
- **One save per damage instance** — Doc 12 spec calls out the SRD rule that multi-instance damage triggers separate saves. Encoded as a doc-comment expectation on `check`, not as a batch API: keeps the resolver pure and lets the caller decide instance boundaries.
- **No `Combatant.copyWith` yet** — Doc 12 §"Concentration Manager" wants `combatant.copyWith(concentration: null)` after a break, but the sealed `Combatant` family has no copyWith and adding one is a separate sweep. The resolver returns the post-state value; whoever owns the combatant snapshot writes it back.
- **CON modifier is the caller's input**, not derived from a passed-in `Combatant` — keeps the resolver usable from pre-combat preview UI ("if a 25-damage hit lands, what's the chance you keep concentration?").

Verification: `flutter analyze` 0 issues, `flutter test` 1224/1224 pass (1 skipped). +11 tests this turn.

Next candidates: `EncounterService` (Doc 11 — turn rotation + condition ticking + integrates DamageResolver + ConcentrationCheckResolver into one apply-damage pipeline), `SpellEffectDispatcher` (Doc 13 — wires `CastOutcome.success` to compiled `EffectDescriptor` registry), or the Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 wiring).

### 2026-04-19 — Doc 12 SpellCastService (🟣) — Phase C composition layer

Wraps the just-shipped `SpellCastValidator` with the deterministic state transitions a successful cast triggers: slot consumption + concentration start/replace. Pure — returns a `CastOutcome` value the caller persists; no dice, no effect dispatch, no Combatant mutation.

Files added:
- `lib/application/dnd5e/spell/cast_outcome.dart` — result value with `slots`, `concentration`, `droppedConcentration`, `slotConsumed`, `error`. Failures preserve prior concentration so callers can pass the outcome through unconditionally.
- `lib/application/dnd5e/spell/spell_cast_service.dart` — `cast(...)` composes `validator.validate(...)` with `SpellSlots.spend(level)` and a switch over `SpellDuration` to detect concentration spells.
- `test/application/dnd5e/spell/spell_cast_service_test.dart` — 11 tests across three groups: failure passthrough (validator error short-circuits without touching slots; prior concentration preserved on failure), slot accounting (normal cast spends one at chosen level, upcast spends at slot level not spell level, cantrip + ritual never spend), concentration transitions (non-conc spell preserves prior conc, conc spell starts at slot level, new conc drops old, ritual conc spell tracks at base spell level).

Decisions:
- **Concentration detection lives on the service**, not on `Spell`, because `SpellDuration` already encodes the flag on three of its variants (`SpellRounds`/`SpellMinutes`/`SpellHours`). A `Spell.requiresConcentration` getter would just duplicate that switch and risk drift.
- **`castAtLevel` for ritual = base spell level**, since rituals don't expend a slot. For normal cast, `castAtLevel = slotLevelChosen` so upcast Hold Person at level 3 records `castAtLevel = 3` (matters when something dispels lower-level spells).
- **No effect dispatch yet** — the next slice (`EncounterService` per Doc 11, or a `SpellEffectDispatcher` per Doc 13) will consume `CastOutcome.success` and route to attack/save resolvers.

Verification: `flutter analyze` 0 issues, `flutter test` 1213/1213 pass (1 skipped). +11 tests this turn.

Next candidates: `EncounterService` (Doc 11 — turn rotation + condition ticking + applies damage outcomes), `SpellEffectDispatcher` (Doc 13 — wires `SpellCastOutcome` to compiled `EffectDescriptor` registry), or the Phase A structural unblock (Doc 04 Step 5/7 + Doc 42 wiring — still gated on `_backupV4DbBeforeReset`).

### 2026-04-19 — Doc 12 SpellCastValidator (🟣) — Phase C service wiring kickoff

First Phase C deliverable now that placeholder content exists for every Tier 2 codec. Pure pre-cast validator following Doc 12 §"Spell Casting Validator". Decoupled from `Combatant`/`Inventory` via a small `CasterContext` value type so it works equally well from combat services and pre-combat UI preview.

- New: `flutter_app/lib/application/dnd5e/spell/spell_cast_validator.dart` — `SpellCastValidator.validate(...)` returns `null` when the cast may proceed, otherwise a single human-readable error. Pure: spends no slot, mutates no state.
- New: `flutter_app/lib/application/dnd5e/spell/casting_method.dart` — enum `{normal, ritual}`. `alwaysPrepared` from the spec collapses into `normal` since the validator only cares about prepared-or-not, not the source.
- New: `flutter_app/lib/application/dnd5e/spell/caster_context.dart` — `{silenced, hasFreeHand, hasFocus, hasComponentPouch, heldMaterialDescriptions}`. Specific-material check matches `MaterialComponent.description` verbatim, which keeps the validator data-driven (no enum of focus types).

Branching:
- Cantrip path: skips slot/prepared rules, still enforces components.
- Ritual path: requires `Spell.ritual == true` + spell prepared OR present in `ritualBookSpellIds`. No slot expended.
- Normal path: slot level non-null, slot level in `[spell.level, 9]`, slot available at chosen level, spell prepared, components valid.
- Component sub-path (shared): V → reject if silenced; S → reject if no free hand; M consumed → require specific item in `heldMaterialDescriptions` (focus/pouch don't substitute); M non-consumed → focus OR pouch OR specific item.

Tests: `test/application/dnd5e/spell/spell_cast_validator_test.dart` — 19 tests across 4 groups (cantrip/normal/ritual/components) covering happy path, every error message, ritual-from-book vs ritual-from-prepared, upcast at higher slot, and consumed-vs-non-consumed material rules.

`flutter analyze`: 0 issues. Tests: 1202/1202 pass, 1 skipped (1182 → 1202, +20 from this file).

DSL gap reminder: validator currently does not enforce one-leveled-spell-per-turn (needs `TurnState.appliedThisTurn`) — will land alongside `EncounterService` in next Doc 11 turn. Concentration override (replacing prior concentration when starting a new one) belongs to `SpellCastService`/`ConcentrationManager`, not the validator.

Next candidate: `SpellCastService` (composes validator + `SpellSlots.spend` + `ConcentrationManager` + effect dispatch), or `EncounterService` (Doc 11 — wraps damage/death-save resolvers with turn rotation and condition ticking).

### 2026-04-19 — Doc 15 placeholder SRD content batch (🟣) — Phase B coverage stubs across all remaining Tier 2 categories

Per user direction: ship 3-5 sample entries per remaining `srd_core` category instead of full SRD authoring. Goal: end-to-end exercise of every Tier 2 codec on disk while deferring exhaustive content authoring until the app is functional. Files added under `flutter_app/assets/packages/srd_core/`:

- `feats_general.json` (3) — Mobile, Sentinel, Skill Expert; all `category=general` with Level 4+ prereq strings.
- `feats_fighting_style.json` (4) — Defense, Dueling, Great Weapon Fighting, Two-Weapon Fighting; `category=fightingStyle`. Ids prefixed `fs_` to keep them distinct from class features that may share names.
- `feats_epic_boon.json` (3) — Boon of Combat Prowess, Boon of Dimensional Travel, Boon of Skill; `category=epicBoon` with Level 19+ prereq.
- `classes.json` (5) — Barbarian (d12, none), Cleric (d8, full, WIS), Fighter (d10, none), Rogue (d8, none), Wizard (d6, full, INT). Saving-throw pairs match SRD. Each carries 1-2 sample feature rows with namespaced `srd:<feature>` ids; effects-empty (DSL gap as expected).
- `subclasses.json` (5) — Path of the Berserker → barbarian, Life Domain → cleric, Champion → fighter, Thief → rogue, Evoker → wizard. Each lists 3-4 sample feature rows at canonical SRD subclass-feature levels (3/6/10/14 for barbarian/rogue, 3/6/17 for cleric, 3/7/15/18 for fighter, 3/10/14 for wizard). Codec-required `parentClassId` cross-references the 5 sample classes above.
- `monsters.json` (5) — Goblin (CR 1/4), Wolf (CR 1/4), Orc (CR 1/2), Skeleton (CR 1/4), Adult Red Dragon (CR 17, legendary). Exercises every `MonsterAction` variant: `attack` (all 5), `multiattack` (Dragon), `save` (Dragon Fire Breath, Wing Attack), `special` (Goblin Nimble Escape, Orc Aggressive). Adult Red Dragon ships 3 legendary actions with `legendaryActionSlots: 3` to satisfy the `Monster` factory invariant. Skeleton exercises damage vulnerabilities/immunities/condition immunities. Dragon exercises `savingThrows` map (DEX/CON/WIS/CHA), `skills` map with Expertise (Perception), damage immunity (Fire), senses (blindsight 60 + darkvision 120), languages.
- `items.json` (8) — covers all 7 sealed `Item` variants in one file: Longsword (Weapon, martial melee, versatile), Longbow (Weapon, martial ranged, range pair 150/600), Chain Mail (Armor, heavy, STR 13), Shield, Backpack (Gear), Thieves' Tools (Tool, with `proficiencyId`), Arrow (Ammunition, qty 20), Longsword +1 (MagicItem with `baseItemId: srd:longsword`, no attunement). Weapon mastery refs (`srd:sap`, `srd:slow`) and property refs (`srd:versatile`, `srd:ammunition`, `srd:heavy`, `srd:two_handed`) cross-link to the existing catalogs.
- `spells_2.json` (4) — Aid, Hold Person, Misty Step, Web.
- `spells_3.json` (4) — Counterspell, Fireball, Fly, Revivify.
- `spells_4.json` (4) — Banishment, Greater Invisibility, Polymorph, Wall of Fire.
- `spells_5.json` (4) — Animate Objects, Cone of Cold, Hold Monster, Raise Dead.
- `spells_6.json` (4) — Chain Lightning, Disintegrate, Heal, True Seeing.
- `spells_7.json` (4) — Finger of Death, Plane Shift, Reverse Gravity, Teleport.
- `spells_8.json` (4) — Antimagic Field (uses `emanation` AoE with `distanceFt` per codec, not `radiusFt`), Dominate Monster, Power Word Stun, Sunburst.
- `spells_9.json` (4) — Meteor Swarm, Power Word Kill, Time Stop, Wish.

Spell tranches collectively exercise: every casting-time tag (`action`, `bonusAction`, `reaction` with trigger string for Counterspell, `hours:1` for Raise Dead), every range tag (`self`, `touch`, `feet`, `miles` for Meteor Swarm), every duration tag (`instantaneous`, `minutes` + concentration, `hours` + concentration, `untilDispelled` not needed at this scope), every AoE shape (`cone`, `cube`, `cylinder`, `emanation`, `line`, `sphere`), and material costs via `costCp` (Revivify 300gp consumed, Raise Dead 500gp consumed, True Seeing 25gp consumed, Plane Shift 250gp). All spells `effects: []` per existing DSL gap policy.

- New tests: 7 new asset test files plus a parametric `spells_levels_asset_test.dart` that loops levels 2-9, each verifying parse, namespaced + unique ids, level-matches-file invariant, schoolId in 8-school set, classListIds in 8-class set, non-empty description + components, effects-empty invariant.
- Bug caught + fixed in same turn: initial `spells_8.json` Antimagic Field used `radiusFt` for emanation; codec requires `distanceFt`. Fixed.
- `flutter analyze`: 0 issues. Tests: 1182/1182 pass, 1 skipped (1091 → 1182, +91 from 16 new asset files via 9 test files).
- These placeholders unblock end-to-end pipeline tests: `Dnd5ePackageImporter` can now ingest a non-trivial spread of every Tier 2 type in one shot. Replace with full canonical content once UI/service wiring lands.
- Next candidate: Phase A structural unblock — Doc 04 Step 5/7 + Doc 42 wiring bundle (gated on `_backupV4DbBeforeReset`); or Phase C service wiring (Doc 10 Notifier, Doc 11 EncounterService) now that sample content exists for every Tier 2 type.

### 2026-04-19 — Doc 15 SRD level-1 spells asset (🟣) — Phase B Tier 2 spell tranche 2

Shipped `flutter_app/assets/packages/srd_core/spells_1.json` with 50 2024 PHB SRD level-1 spells: Alarm, Animal Friendship, Bane, Bless, Burning Hands, Charm Person, Chromatic Orb, Color Spray, Command, Comprehend Languages, Create or Destroy Water, Cure Wounds, Detect Evil and Good, Detect Magic, Detect Poison and Disease, Disguise Self, Divine Favor, Entangle, Expeditious Retreat, Faerie Fire, False Life, Feather Fall, Find Familiar, Fog Cloud, Goodberry, Grease, Guiding Bolt, Healing Word, Hellish Rebuke, Heroism, Hideous Laughter, Hunter's Mark, Identify, Inflict Wounds, Jump, Longstrider, Mage Armor, Magic Missile, Protection from Evil and Good, Purify Food and Drink, Ray of Sickness, Sanctuary, Shield, Shield of Faith, Silent Image, Sleep, Speak with Animals, Thunderwave, Unseen Servant, Witch Bolt. Body shape matches `spell_json_codec` (identical to cantrips tranche). 2024 schools reflect: Cure Wounds / Healing Word / Mage Armor / Protection from Evil and Good / Sanctuary / Shield / Shield of Faith → Abjuration (recategorized in 2024 from Evocation). Casting-time distribution: 35× `action`, 7× `bonusAction` (Divine Favor, Expeditious Retreat, Healing Word, Hunter's Mark, Sanctuary, Shield of Faith, Divine Favor), 3× `reaction` (Shield, Feather Fall, Hellish Rebuke — each carries trigger string), 2× `minutes:1` (Alarm, Identify), 1× `hours:1` (Find Familiar). Range distribution uses the sealed union — `self` (16 × self-origin AoE + personal buffs), `touch` (8 — Cure Wounds, Heroism, Inflict Wounds, Jump, Longstrider, Mage Armor, Protection from Evil and Good, Identify), remainder feet (10-120 ft). 9 rituals match canonical SRD subset: Alarm, Comprehend Languages, Detect Magic, Detect Poison and Disease, Find Familiar, Identify, Purify Food and Drink, Speak with Animals, Unseen Servant. 18 concentration spells match canonical SRD subset per duration flag: Bane, Bless, Detect Evil and Good, Detect Magic, Detect Poison and Disease, Divine Favor, Entangle, Expeditious Retreat, Faerie Fire, Fog Cloud, Heroism, Hideous Laughter, Hunter's Mark, Protection from Evil and Good, Shield of Faith, Silent Image, Sleep, Witch Bolt. Material components with cost flagged via `costCp`: Find Familiar (10 gp charcoal/incense/herbs, consumed), Identify (100 gp pearl + owl feather, not consumed), Chromatic Orb (50 gp diamond, not consumed). Area geometry uses tagged union: cone (Burning Hands 15ft, Color Spray 15ft), cube (Alarm 20ft, Create or Destroy Water 30ft, Entangle 20ft, Faerie Fire 20ft, Grease 10ft, Silent Image 15ft, Thunderwave 15ft), sphere (Fog Cloud 20ft, Purify Food and Drink 5ft, Sleep 5ft). AoE-origin-point vs single-target targeting encoded via `SpellTarget.aoeOriginPoint` enum. `classListIds` forward-references `srd:<class>` ids covering all 8 canonical casters (bard/cleric/druid/paladin/ranger/sorcerer/warlock/wizard). All 50 ship `effects: []` — same DSL gaps as cantrips tranche (SpellAttack / SaveOrDamage / AoE SaveOrDamage / StatIncreaseTemp like Shield's +5 AC trigger / THP-grant for False Life + Heroism / AC-override for Mage Armor / ConditionOnSaveFail like Prone / MovementModifier like Longstrider / DashGrant like Expeditious Retreat). Hideous Laughter uses SRD id `srd:hideous_laughter` (SRD 5.2.1 dropped the "Tasha's" prefix). 2024 Smite spells (Wrathful Smite, Searing Smite) deliberately omitted — recategorized as class-feature triggers in 2024 PHB Paladin; will land with Paladin class + Divine Smite wiring. Spells authored as per-level file `spells_1.json` — `tool:build_srd_pkg` CLI will concatenate `spells_cantrips.json` + `spells_1.json` + later per-level files into the monolith.

- New assets: `flutter_app/assets/packages/srd_core/spells_1.json`.
- New tests: `flutter_app/test/assets/packages/srd_core/spells_1_asset_test.dart` (11 tests: parse, namespace uniqueness, canonical 50-spell set match, level==1 invariant, schoolId ∈ 8 SRD schools, non-empty description, classListIds ⊂ 8 canonical PHB class set, effects-empty invariant, ritual subset match (9 rituals), concentration subset match (18 concentration spells), components non-empty).
- `flutter analyze`: 0 issues. Tests: 1091/1091 pass, 1 skipped (1080 → 1091, +11).
- DSL gaps reinforced: beyond cantrip primitives, level-1 batch exposes AC-override (Mage Armor sets base to 13+Dex), AC-bonus-for-duration (Shield +5, Shield of Faith +2), THP-grant (False Life 1d4+4, Heroism per-turn mod), speed-delta (Longstrider +10ft), dash-on-BA (Expeditious Retreat), MM-immunity rider (Shield), attack-roll-and-save-penalty (Bane −1d4), attack-roll-bonus (Bless, Divine Favor +1d4), on-hit-extra-damage (Hunter's Mark 1d6), ongoing-auto-damage (Witch Bolt 1d12/turn), chained-attack-on-matched-dice (Chromatic Orb). A future EffectDescriptor extension turn should at minimum cover: `SpellAttackDamage`, `SaveForDamage` (AoE + single-target), `GrantAcBonus`, `SetBaseAc`, `GrantThp`, `ModifyAttackRoll`, `ModifySavingThrow`, `ModifyOnHitDamage`, `MovementSpeedBonus`, `SummonCreature` (Find Familiar, Unseen Servant).
- Phase B progress: Tier 2 assets shipped to date — species (9/9), lineages (5/5), backgrounds (16/16), feats (12/12 Origin), cantrips (27/27), level-1 spells (50/~50). Catalog side: 12/12 complete. Tier 2 codec surface: 9/9 complete. Remaining Tier 2 assets: ~28 remaining feats, 12 classes + subclasses, ~284 level-2-thru-9 spells, ~320 monsters, ~300 items.
- Next candidate: either (a) level-2 spell tranche (~40 entries — Aid, Hold Person, Invisibility, Mirror Image, Misty Step, Scorching Ray, Spiritual Weapon, Web, etc.), or (b) class/subclass batch (12 classes + canonical subclasses; structural, unblocks class-feature effect dispatch), or (c) EffectDescriptor DSL extension turn (adds the ~10 spell primitives enumerated above — would retroactively let cantrips + level-1 spells carry live effects). Alternatively pull Doc 04 Step 5/7 + Doc 42 wiring if user prefers structural unblock over content.

### 2026-04-19 — Doc 15 SRD cantrips asset (🟣) — Phase B Tier 2 spell tranche 1

Shipped `flutter_app/assets/packages/srd_core/spells_cantrips.json` with the 2024 PHB SRD cantrip set — 27 entries: Acid Splash, Dancing Lights, Druidcraft, Eldritch Blast, Fire Bolt, Guidance, Light, Mage Hand, Mending, Message, Minor Illusion, Poison Spray, Prestidigitation, Produce Flame, Ray of Frost, Resistance, Sacred Flame, Shillelagh, Shocking Grasp, Spare the Dying, Starry Wisp, Thaumaturgy, Thorn Whip, Toll the Dead, True Strike, Vicious Mockery, Word of Radiance. Body shape matches `spell_json_codec`: `{level, schoolId, castingTime, range, components, duration, targets?, area?, effects?, ritual?, classListIds?, description?}`. Every entry is `level: 0`. `castingTime` is `{t:"action"}` for all except Shillelagh (`bonusAction`) and Mending (`{t:"minutes",minutes:1}`). `range` uses the sealed union (`feet`/`touch`/`self`). `components` array carries V/S/M entries with full material descriptions (phosphorus for Dancing Lights, copper wire for Message, mistletoe+shamrock+club for Shillelagh, weapon ≥1sp for True Strike, holy symbol for Word of Radiance, etc.). `duration` uses the instantaneous / rounds / minutes / hours tagged union with `concentration: true` flag where applicable (Dancing Lights, Guidance, Resistance). `targets` uses `SpellTarget.name` enum values (oneCreature / oneCreatureOrObject / oneObject / point / self / aoeOriginPoint). Word of Radiance is the only AoE cantrip — `{t:"emanation", distanceFt:5}` on self. `classListIds` uses forward-referenced `srd:<class>` ids (bard/cleric/druid/sorcerer/warlock/wizard); `validateContentId` checks format only so these are legal today and will resolve once classes land. Magic Initiate (Cleric/Druid/Wizard) feat references to "the Cleric spell list" / "Druid spell list" / "Wizard spell list" are now backed by at least 2 cantrips per tradition. All 27 ship `effects: []`: the DSL has no SpellAttack / SaveOrDamage / ConditionOnAttackMiss primitives, so direct-damage cantrips (Fire Bolt, Sacred Flame, Toll the Dead, etc.), utility cantrips (Mage Hand, Mending, Prestidigitation), and rider cantrips (Guidance, Resistance) all keep mechanics in description prose for now. Same DSL-gap story as feats.json. Cantrip Upgrade scaling, cover-piercing (Sacred Flame), Advantage-on-metal-armor (Shocking Grasp), pull-10ft (Thorn Whip), missing-HP escalation (Toll the Dead d8→d12), and Disadvantage-on-next-attack (Starry Wisp, Vicious Mockery) are all captured textually. Spells authored as separate file `spells_cantrips.json` so each level batch stays self-contained — `tool:build_srd_pkg` CLI will later concatenate `spells_*.json` into the monolith.

- New assets: `flutter_app/assets/packages/srd_core/spells_cantrips.json`.
- New tests: `flutter_app/test/assets/packages/srd_core/spells_cantrips_asset_test.dart` (10 tests: parse, namespace uniqueness, canonical 27-cantrip set match, level==0 invariant, schoolId ∈ 8 SRD schools, non-empty description, classListIds ⊂ 8 canonical PHB class set, effects-empty invariant, Magic-Initiate cantrip-coverage check (≥2 per Cleric/Druid/Wizard), ritual==false invariant).
- `flutter analyze`: 0 issues. Tests: 1080/1080 pass, 1 skipped (1070 → 1080, +10).
- DSL gaps reinforced: SpellAttack (Fire Bolt, Eldritch Blast, Shocking Grasp, Starry Wisp, Thorn Whip, True Strike, Produce Flame attack), SaveOrDamage (Acid Splash, Poison Spray, Sacred Flame, Toll the Dead, Vicious Mockery, Word of Radiance), ConditionOnAttackMiss / Disadvantage-rider, Advantage-vs-metal-armor trigger, creature-pull (Thorn Whip), 0-HP-stabilize (Spare the Dying), ability-check-bonus-d4 (Guidance), save-bonus-d4 (Resistance). EffectDescriptor needs at minimum a `SpellDirectDamage` primitive (attack-or-save-for-damage with Cantrip Upgrade scaling) to automate cantrip behavior.
- Phase B progress: Tier 2 assets shipped to date — species (9/9), lineages (5/5), backgrounds (16/16), feats (12/12 Origin), cantrips (27/27). Catalog side: 12/12 complete. Tier 2 codec surface: 9/9 complete. Remaining Tier 2 assets: ~28 remaining feats, 12 classes + subclasses, ~334 level-1-thru-9 spells, ~320 monsters, ~300 items.
- Next candidate: either (a) level-1 spell tranche (~40 entries — Bless, Cure Wounds, Magic Missile, Shield, Mage Armor, Healing Word, Sleep, etc. — biggest payload for caster classes), or (b) start the class/subclass batch (12 classes + canonical subclasses — structural; unblocks class-feature effect dispatch). Alternatively pull Doc 04 Step 5/7 + Doc 42 wiring if user prefers structural unblock over content.

### 2026-04-19 — Doc 15 SRD Origin feats asset (🟣) — Phase B Tier 2 content authoring continues

Shipped `flutter_app/assets/packages/srd_core/feats.json` with the 2024 PHB SRD Origin-category feat set — 12 entries: Alert, Crafter, Healer, Lucky, Magic Initiate (Cleric), Magic Initiate (Druid), Magic Initiate (Wizard), Musician, Savage Attacker, Skilled, Tavern Brawler, Tough. Body shape matches `feat_json_codec`: `{category, repeatable?, prerequisite?, effects?, description?}`. Every entry is `category: "origin"`; Magic Initiate variants + Skilled carry `repeatable: true`; no Origin feat has a prerequisite. Magic Initiate splits into three separate feat ids (`srd:magic_initiate_cleric` / `_druid` / `_wizard`) so `backgrounds.json` can reference specific tradition variants via distinct namespaced ids — matches how Acolyte references Cleric, Guide references Druid, Sage references Wizard. All 12 ship `effects: []` (omitted on encode): the DSL has no `GrantCantrip` / `GrantSpell` / HP-boost / reroll-trigger / initiative-modifier / luck-point primitives yet, and candidates like Crafter (3 choice Artisan's Tools), Skilled (3 choice skills-or-tools), and Musician (3 choice Musical Instruments) are all choice-driven so would not serialize as static `GrantProficiency` even if Origin feats otherwise had clean tool grants. Mechanics live in description prose verbatim from SRD 5.2.1 CC BY 4.0. Asset test cross-references every feat named in `backgrounds.json` to assert structural integrity between the two authoring passes.

- New assets: `flutter_app/assets/packages/srd_core/feats.json`.
- New tests: `flutter_app/test/assets/packages/srd_core/feats_asset_test.dart` (9 tests: parse, namespace uniqueness, canonical 12-feat set match, category==origin invariant, non-empty descriptions, repeatable partition (4 repeatable vs 8 not), prerequisite null invariant, background→feat cross-reference coverage, effects-empty invariant).
- `flutter analyze`: 0 issues. Tests: 1070/1070 pass, 1 skipped (1061 → 1070, +9).
- DSL gaps surfaced: `GrantCantrip`/`GrantSpell` (Magic Initiate + most spellcaster feats), HP-max boost (Tough), weapon-damage reroll (Savage Attacker, Tavern Brawler), initiative bonus + swap (Alert), luck-point pool (Lucky), inspiration grant (Musician). Same gaps will block the bulk of General and Fighting Style feats when those batches land. Consider pulling an EffectDescriptor extension turn before Phase B continues into General feats if cantrip/spell grants become blocking for class features as well.
- Phase B progress: Tier 2 assets shipped to date — species (9/9), lineages (5/5), backgrounds (16/16), feats (12/12 Origin; ~28 General + Fighting Style + Epic Boon remain). Catalog side: 12/12 complete. Tier 2 codec surface: 9/9 complete. Remaining Tier 2 assets: ~28 remaining feats, 12 classes + subclasses, ~361 spells, ~320 monsters, ~300 items.
- Next candidate: either (a) start the class/subclass batch (12 classes + canonical subclasses — structural; unblocks class-feature effect dispatch) or (b) begin spell tranche 1 (~50 spells starting at cantrips) — lets typed Spell populate for Doc 12 `SpellCastValidator` wiring. Alternatively pull Doc 04 Step 5/7 + Doc 42 wiring if user prefers structural unblock over content.

### 2026-04-19 — Doc 15 SRD backgrounds asset (🟣) — Phase B Tier 2 content authoring continues

Shipped `flutter_app/assets/packages/srd_core/backgrounds.json` with the 2024 PHB SRD 16-background set — Acolyte, Artisan, Charlatan, Criminal, Entertainer, Farmer, Guard, Guide, Hermit, Merchant, Noble, Sage, Sailor, Scribe, Soldier, Wayfarer. Body shape matches `background_json_codec`: `{effects?, description?}`. Each background's two fixed skill proficiencies encoded as `GrantProficiency{kind: skill, targetId: srd:<skill>}`. Eleven backgrounds with a fixed tool (Acolyte/Charlatan/Criminal/Farmer/Guide/Hermit/Merchant/Sage/Sailor/Scribe/Wayfarer) also ship a `GrantProficiency{kind: tool, targetId: srd:<tool>}` effect — tool ids use namespaced form even though no `tools.json` catalog exists yet (`validateContentId` checks format, not existence; future tool catalog will backfill). Five backgrounds where 2024 PHB leaves the tool choice open (Artisan = any artisan's tools, Entertainer = any musical instrument, Guard/Noble/Soldier = any gaming set) carry no static tool effect — the choice resolves at character creation and will attach its own `GrantProficiency` then. Origin Feat (Magic Initiate variants, Crafter, Skilled, Alert, Tough, Healer, Lucky, Savage Attacker, Tavern Brawler, Musician) stays in description prose: no `GrantFeat` effect exists in the descriptor DSL yet, and Doc 10 treats Origin Feat as a parallel character-creation step (+3 ability-score bonus variant per `ability_score_method.dart:83`). Starting Equipment lists also in description until an inventory-grant effect exists.

- New assets: `flutter_app/assets/packages/srd_core/backgrounds.json`.
- Tests: 11 new (`test/assets/packages/srd_core/backgrounds_asset_test.dart`) — parse all 16 via `backgroundFromEntry`, namespace uniqueness, canonical 16-background set match, non-empty descriptions, every background grants exactly 2 skill proficiencies, skill target ids namespaced + belong to the 18 SRD skills, fixed-tool vs choice-tool partition (11 vs 5, union = all 16) with tool-grant count invariant, spot-checks on Acolyte (Insight+Religion+Calligrapher's Supplies), Criminal (Sleight of Hand+Stealth+Thieves' Tools), Sage (Arcana+History).
- Result: `flutter analyze` clean, 1061/1061 tests pass (1050 → 1061, +11).
- Phase B status: Tier 1 catalogs 12/12 ✓. Tier 2 entity codecs 9/9 ✓. Tier 2 assets: species ✓, lineages ✓, **backgrounds ✓** (new). Still pending: ~40 feats, 12 classes + subclasses, ~361 spells, ~320 monsters, ~300 items.
- Next: first batch of `feats.json` — 2024 PHB Origin Feats (~10 entries: Alert, Crafter, Healer, Lucky, Magic Initiate [Cleric/Druid/Wizard = 3 variants], Musician, Savage Attacker, Skilled, Tavern Brawler, Tough). Each body `{category, repeatable?, prerequisite?, effects?, description?}` per `feat_json_codec`; Origin category maps to `FeatCategory.origin`. Some feats (Lucky, Alert, Savage Attacker, Tavern Brawler) translate to effects cleanly; others (Magic Initiate, Crafter, Skilled) are choice-driven and land mostly as description for now.

### 2026-04-19 — Doc 15 SRD lineages asset (🟣) — Phase B Tier 2 content authoring continues

Shipped `flutter_app/assets/packages/srd_core/lineages.json` with the 2024 PHB SRD 5-lineage set — Drow, High Elf, Wood Elf (parent `srd:elf`) + Forest Gnome, Rock Gnome (parent `srd:gnome`). 2024 PHB retired Dwarf and Halfling subraces, so the catalog is exactly these five. Body shape matches `lineage_json_codec`: `{parentSpeciesId, effects?, description?}`. The only statically-encodable mechanical grant is Drow's Superior Darkvision 120 (overrides the Elf baseline of 60) — shipped as `GrantSenseOrSpeed{darkvision, 120}`. Everything else (High Elf wizard-cantrip-of-choice, Wood Elf Fleet of Foot +5 speed + Druidcraft, Forest Gnome Minor Illusion + Speak with Small Beasts, Rock Gnome Mending/Prestidigitation + Tinker, and every lineage's 3rd/5th-level innate-spell ladder) depends on a build-time choice, a cantrip-grant we don't yet model in `EffectDescriptor`, or a speed-override semantics that would conflict with `Species.baseSpeedFt`. All of that lives in description prose and will attach via class-feature pure fns / custom effects once the character-creation notifier is live.

- New assets: `flutter_app/assets/packages/srd_core/lineages.json`.
- Tests: 9 new (`test/assets/packages/srd_core/lineages_asset_test.dart`) — parse all 5 via `lineageFromEntry`, namespace uniqueness, canonical 5-lineage set match, parent-species id validity (only `srd:elf` / `srd:gnome` allowed), elven trio parents to `srd:elf`, gnomish pair parents to `srd:gnome`, non-empty description, Drow Superior Darkvision 120 present, non-Drow lineages carry no static effects.
- Result: `flutter analyze` clean, 1050/1050 tests pass (1041 → 1050, +9).
- Phase B status: Tier 1 catalogs 12/12 ✓. Tier 2 entity codecs 9/9 ✓. Tier 2 assets: species ✓, **lineages ✓** (new). Still pending: 16 backgrounds, ~40 feats, 12 classes + subclasses, ~361 spells, ~320 monsters, ~300 items.
- Next: `backgrounds.json` (16 entries, 2024 PHB SRD — each `{effects?, description?}` per codec; origin feat + 2 skill profs + tool prof encoded as `GrantProficiency` effects) or first slice of `feats.json` (~40 entries — chunk by category: Origin / General / Fighting Style / Epic Boon). Backgrounds recommended next — single-digit-turn size and they depend only on already-shipped `srd:poison` / skill / language catalogs.

### 2026-04-19 — Doc 15 SRD species asset (🟣) — Phase B Tier 2 content authoring start

Shipped `flutter_app/assets/packages/srd_core/species.json` with all 9 2024 PHB SRD species — Dragonborn, Dwarf, Elf, Gnome, Goliath, Halfling, Human, Orc, Tiefling. Body shape matches `species_json_codec`: `{sizeId, baseSpeedFt, effects?, description?}`. `sizeId` references `srd:medium` / `srd:small` (Halfling + Gnome only); `baseSpeedFt` = 30 for all except Goliath = 35. Effects carry only the statically-encodable mechanical grants: `GrantSenseOrSpeed{darkvision, 60}` for Dragonborn/Elf/Gnome/Tiefling, `GrantSenseOrSpeed{darkvision, 120}` for Dwarf/Orc, and `ModifyResistances{resistance, add: [srd:poison]}` for Dwarf. Traits that depend on a build-time choice (Dragonborn ancestry, Tiefling legacy, Elven/Gnomish lineage, Giant Ancestry) or a triggering predicate (Halfling Brave/Luck, Gnomish Cunning, Human Heroic Inspiration, Orc Relentless Endurance) are covered in the description and will attach via Lineage or character-creation wiring later. Goliath/Halfling/Human carry no static effects for this reason.

- New assets: `flutter_app/assets/packages/srd_core/species.json`.
- Tests: 10 new (`test/assets/packages/srd_core/species_asset_test.dart`) — parse all 9 via `speciesFromEntry`, namespace uniqueness, canonical 9-species set match, size-id validity against the 6 SRD sizes, Small-vs-Medium partition (halfling/gnome = small; rest = medium), speed table, non-empty description, darkvision distribution (60 vs 120) matches 2024 PHB, dwarf poison resistance asserted, goliath/halfling/human empty-effects invariant.
- Result: `flutter analyze` clean, 1041/1041 tests pass (1031 → 1041, +10).
- Phase B status: Tier 1 catalogs 12/12 ✓. Tier 2 entity codecs 9/9 ✓. Tier 2 assets: species ✓ (new), lineages / backgrounds / feats / classes / subclasses / spells / monsters / items still pending.
- Next (small-first path): `lineages.json` (Elven Drow/High/Wood + Gnomish Forest/Rock + any 2024 Fiendish Legacy ties to Tiefling — narrow scope matches Lineage domain), or `backgrounds.json` (16 entries, each `{effects?, description?}` — simple body), or first `feats.json` batch. Recommend lineages next since they immediately downstream of the just-shipped species.

### 2026-04-19 — Doc 15 CharacterClass codec (🟣) — Tier 2 entity codec #9 (codec surface COMPLETE)

Shipped `flutter_app/lib/domain/dnd5e/character/character_class_json_codec.dart` — `characterClassFromEntry(CatalogEntry)` + `characterClassToEntry(CharacterClass)`. Body shape `{"hitDie": String, "casterKind": String, "spellcastingAbility"?: String, "savingThrows"?: [String...], "featureTable"?: [<row>...], "casterFraction"?: num, "description"?: String}`. Each row: `{"level": int, "featureIds"?: [String...], "effects"?: [<effect>...]}`. All enums (`Die`, `CasterKind`, `Ability`) encoded via `.name`. `casterFraction` omitted when it equals the default for `casterKind` (0/1.0/0.5/1/3/0 for none/full/half/third/pact) — homebrew fractional casters still round-trip exactly. Feature rows sorted by level on encode for deterministic output, matching subclass codec pattern.

- New files: `domain/dnd5e/character/character_class_json_codec.dart`.
- Tests: 14 new (`test/domain/dnd5e/character/character_class_json_codec_test.dart`) — minimal non-caster round-trip (Fighter d10), full caster round-trip (Wizard d6 + INT saves + spellcasting ability + 2-row featureTable with GrantProficiency effect), per-CasterKind enum loop, per-Die enum loop, feature-table sort on encode, default-field omission, enum `.name` encoding (hitDie/casterKind/spellcastingAbility/savingThrows), non-default casterFraction emission, decode errors for missing hitDie / unknown Die / unknown CasterKind / unknown Ability in savingThrows / row missing level / malformed JSON.
- Result: `flutter analyze` clean, 1031/1031 tests pass (1017 → 1031, +14).
- Tier 2 content codec status: Spell ✓, Monster ✓, Item ✓, Subclass ✓, Species ✓, Background ✓, Feat ✓, Lineage ✓, **CharacterClass ✓** (new). **Phase A codec surface is now 100% complete** — every Tier 1/Tier 2 content type has a round-tripping JSON codec.
- Next: Phase B pivots fully to SRD asset authoring (Tier 2 entities: 9 species, 16 backgrounds, ~40 feats, 12 classes + subclasses, lineages, ~361 spells, ~320 monsters, ~300 items — batches of ~50 for the large sets). The `tool:build_srd_pkg` CLI + `SrdBootstrapService` is the non-blocking side track that makes per-asset tests unnecessary once the monolith builder exists.

### 2026-04-19 — Doc 15 Lineage codec (🟣) — Tier 2 entity codec #8

Shipped `flutter_app/lib/domain/dnd5e/character/lineage_json_codec.dart` — `lineageFromEntry(CatalogEntry)` + `lineageToEntry(Lineage)`. Body shape `{"parentSpeciesId": String, "effects"?: [<effect>...], "description"?: String}`. Engine merges parent Species effects with Lineage effects at character build time per `lineage.dart` doc comment — codec just passes `parentSpeciesId` as an opaque `ContentReference<Species>` string. Pattern mirrors `species_json_codec.dart` minus the sizeId/baseSpeedFt fields (those live on the parent Species).

- New files: `domain/dnd5e/character/lineage_json_codec.dart`.
- Tests: 7 new (`test/domain/dnd5e/character/lineage_json_codec_test.dart`) — minimal round-trip (High Elf → srd:elf), full round-trip with `GrantProficiency` effect, empty-field omission, valid-JSON structure check, decode errors for missing parentSpeciesId / non-array effects / malformed JSON.
- Result: `flutter analyze` clean, 1017/1017 tests pass (1010 → 1017, +7).
- Tier 2 content codec status: Spell ✓, Monster ✓, Item ✓, Subclass ✓, Species ✓, Background ✓, Feat ✓, **Lineage ✓** (new). Remaining: **CharacterClass** (last one — spellcasting table, features-by-level, subclass-gate).
- Next: CharacterClass codec closes the Tier 2 codec surface entirely; after that, Phase B transitions fully to SRD asset authoring.

### 2026-04-19 — Doc 15 Feat codec (🟣) — Tier 2 entity codec #7

Shipped `flutter_app/lib/domain/dnd5e/character/feat_json_codec.dart` — `featFromEntry(CatalogEntry)` + `featToEntry(Feat)`. Body shape `{"category": String, "repeatable"?: bool, "prerequisite"?: String, "effects"?: [<effect>...], "description"?: String}`. `category` encodes `FeatCategory.name` (origin / general / fightingStyle / epicBoon) per project convention of `.name` for enum wire format. `repeatable` omitted when false; `prerequisite` is free-form string for UI (machine-checked prereqs live inside effects as `Predicate`s per `feat.dart` doc comment).

- New files: `domain/dnd5e/character/feat_json_codec.dart`.
- Tests: 10 new (`test/domain/dnd5e/character/feat_json_codec_test.dart`) — minimal round-trip, full round-trip with all fields + `GrantProficiency` effect, per-category enum round-trip (all 4 values), default-field omission, category `.name` encoding, `repeatable=true` emission, decode errors for missing/unknown category, non-bool repeatable, malformed JSON.
- Result: `flutter analyze` clean, 1010/1010 tests pass (1000 → 1010, +10).
- Tier 2 content codec status: Spell ✓, Monster ✓, Item ✓, Subclass ✓, Species ✓, Background ✓, **Feat ✓** (new). Remaining: Lineage, CharacterClass.
- Next: CharacterClass codec (larger — spellcasting table, features by level), or Lineage codec (smaller), or begin SRD species / background / feat asset authoring.

### 2026-04-19 — Doc 15 Background codec (🟣) — Tier 2 entity codec #6

Shipped `flutter_app/lib/domain/dnd5e/character/background_json_codec.dart` — `backgroundFromEntry(CatalogEntry)` + `backgroundToEntry(Background)`. Body shape `{"effects"?: [<effect>...], "description"?: String}` — smallest Tier 2 body yet; `Background` carries only id/name/effects/description per 2024 SRD (proficiencies + origin feat encoded as effects, not top-level fields). Effects route through `effect_descriptor_codec`; empty effect list + empty description are omitted. Pattern mirrors `species_json_codec.dart`.

- New files: `domain/dnd5e/character/background_json_codec.dart`.
- Tests: 8 new (`test/domain/dnd5e/character/background_json_codec_test.dart`) — minimal round-trip, full round-trip with two `GrantProficiency` effects (skill + tool), empty-field omission, decode errors for non-object body / malformed JSON / non-string description / non-array effects (all carry `<entry.id>:` prefix + `Background` type name where applicable).
- Result: `flutter analyze` clean, 1000/1000 tests pass (992 → 1000, +8).
- Tier 2 content codec status: Spell ✓, Monster ✓, Item ✓, Subclass ✓, Species ✓, **Background ✓** (new). Remaining: Lineage, CharacterClass, Feat.
- Next: Feat or CharacterClass codec, or begin authoring SRD species / background assets now that both codecs exist.

### 2026-04-19 — Doc 15 Species codec (🟣) — Tier 2 entity codec #5

Shipped `flutter_app/lib/domain/dnd5e/character/species_json_codec.dart` — `speciesFromEntry(CatalogEntry)` + `speciesToEntry(Species)`. Body shape `{"sizeId": String, "baseSpeedFt": int, "effects"?: [<effect>...], "description"?: String}`. Effects route through `effect_descriptor_codec`; empty effect list + empty description are omitted for compact output. Pattern mirrors `subclass_json_codec.dart`. This opens the way for authoring 9 SRD species (Dragonborn, Dwarf, Elf, Gnome, Halfling, Human, Orc, Tiefling + one more) with real darkvision/resistance/ancestry effects in subsequent turns.

- New files: `domain/dnd5e/character/species_json_codec.dart`.
- Tests: 7 new (`test/domain/dnd5e/character/species_json_codec_test.dart`) — minimal round-trip, full round-trip with `GrantSenseOrSpeed` + `GrantProficiency` effects, empty-field omission on encode, decode errors for missing sizeId / non-int baseSpeedFt / malformed JSON (all carry `<entry.id>:` prefix + `Species` type name).
- Result: `flutter analyze` clean, 992/992 tests pass (985 → 992, +7).
- Tier 2 content codec status: Spell ✓, Monster ✓, Item ✓, Subclass ✓, **Species ✓** (new). Remaining: Lineage, CharacterClass, Background, Feat.
- Next: smallest-first path — author SRD species assets (9 entries), or ship Background / Feat codec (smaller bodies).

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
