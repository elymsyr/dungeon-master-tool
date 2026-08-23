# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code search (codebase-memory MCP)

This workspace is indexed as **one** project, indexed `full`: the Flutter app (`flutter_app/lib/`, `tool/`, `test/`), the Supabase surface (`supabase/migrations/` + edge functions), the Cloudflare worker (`cloudflare/src/`), and the `vault/` markdown. Gitignored generated files (`*.g.dart`/`*.freezed.dart`) and large binary assets are not in the index.

The `project` name is derived from the repo path, so it **differs per machine** — get this machine's name with `list_projects` (the one ending in `-dungeon-master-tool`) and pass that to every tool.

**Use the graph before grep/find.** codebase-memory is the primary way to understand and navigate code — its results are deduplicated and structure-aware, and far cheaper in tokens than raw grep + Read. If the tools are listed but deferred, load them by name via tool search (`select:mcp__codebase-memory__search_code,...`).

- **Find symbols** — `search_graph` (natural-language `query`, `name_pattern`, or `semantic_query` for vocabulary-bridging). Use it INSTEAD of grep to locate definitions.
- **Read code** — `get_code_snippet` fetches a single symbol's source INSTEAD of Reading whole files; `include_neighbors` shows callers/callees.
- **Text search** — `search_code` is grep augmented by the graph (matches deduplicated into containing functions, definitions ranked first). Prefer it over raw Grep.
- **Callers / impact** — `trace_path` (inbound/outbound) before editing or removing a function.
- **Overview / cross-cutting** — `get_architecture` for the layer/cluster layout; `query_graph` (Cypher) for dead code, hot paths, unused symbols; `get_graph_schema` for node/edge kinds.
- **Architecture decisions** — `manage_adr` to read/record ADRs in the graph.
- **Index health** — `index_status` tells whether the index is behind HEAD; `detect_changes` shows what drifted after edits. If stale, offer (don't run unasked) `index_repository(repo_path=..., mode="full")` — it is incremental (~2s). Use `mode="full"`, not `moderate`: moderate drops the `vault/` docs and `test/`/`tool/` code.

## Read the vault only needed

`vault/` is a curated Obsidian knowledge base covering this codebase — **consult it before reading raw source.** It is maintained as a trustworthy substitute for source-diving, and keeping it current is part of the work.

Its rules (mirrored from [vault/90-Meta/SOP.md](vault/90-Meta/SOP.md)):

1. **Consult first if needed more detailed information** — before modifying logic or writing new code in an area, read the matching `vault/10-Files/<domain>/<basename>.md` (note name = source basename, e.g. `sync_engine.dart` → `vault/10-Files/sync/sync_engine.md`) or the domain Map-of-Content in `vault/00-Maps/`. Treat the note's Inputs/Outputs + Key Logic as the contract; open raw source only when the note is missing, stale, or insufficient.
2. **Auto-update** — creating a new architecturally significant source file means creating its tracking note from `vault/90-Meta/Templates/File-Tracking-Note`, filing it in the right `10-Files/<domain>/`, and wiring links up to the domain MoC and laterally to deps/callers (bidirectional). Modifying a file enough to change behavior means updating its note's Key Logic + `updated:` date.
3. **Maintain context** — new Supabase migration, new worker route, schema/version bump, or new domain → update the affected MoC and `vault/00-Maps/_Architecture-Overview.md`, and always append a line to `vault/90-Meta/Vault-Changelog.md`.

Granularity is hybrid: notes exist for services, DAOs, resolvers, mappers, worker modules, logic providers, schema cores, and CI/config — not for trivial models, generated `*.g.dart`/`*.freezed.dart`, pure-layout widgets, or l10n.

Start at [vault/Home.md](vault/Home.md) → [vault/00-Maps/_Architecture-Overview.md](vault/00-Maps/_Architecture-Overview.md).

## Commands

All Flutter commands run from `flutter_app/`.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # REQUIRED — generated files are gitignored
dart run build_runner watch --delete-conflicting-outputs   # during active model/provider work

flutter analyze
flutter test
flutter test test/domain/services/grant_contract_test.dart  # single file
flutter test --plain-name "resolves multiclass slots"       # single test by name

flutter gen-l10n                                            # after editing .arb files
flutter run -d linux            # or macos / windows / android / ios / chrome
```

Nothing compiles before `build_runner` — Freezed, Riverpod, Drift, and json_serializable output is not committed. Re-run it after touching any annotated class.

Online features need compile-time config; without it the app runs fully offline and Supabase is never initialized:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=DMT_WORKER_URL=https://dmt-assets.<acct>.workers.dev
```

Release builds take the same three defines (see [.github/workflows/build.yml](.github/workflows/build.yml)): `flutter build apk|windows|linux|macos --release`, `flutter build ios --release --no-codesign`.

### Content pipeline tools

```bash
dart run tool/open5e_import/bin/build_packs.dart --data <open5e-api-staging/data> --out assets/open5e_packs
dart run tool/catalog_publish/bin/build_catalog.dart      # → assets/first_party/manifest.json
dart run tool/catalog_publish/bin/publish_catalog.dart --worker <url> [--dry-run]
dart run tool/migrate_pack_assets.dart [--dry-run]        # rewrite bundled .pkg.json off retired DSLs
```

`build_packs` exits non-zero on any unresolved `_ref`, so a broken pack can never ship.

### Testing caveat

A full `flutter test` run has a sizable set of environmental failures unrelated to any given change (empty-state results in `test/application/combat_provider_test.dart`, `test/application/services/content_store_test.dart`, `test/data/network/asset_service_test.dart` and a few others). Before attributing failures to your work, capture the failing set on a clean tree (`git stash`) and treat only the difference as a regression. Targeted runs of the files you touched are the reliable signal.

## Repository layout

| Path | What |
|---|---|
| `flutter_app/` | The app — Flutter/Dart, all five platforms |
| `flutter_app/tool/` | Offline Dart CLIs: Open5e importer, catalog build/publish, pack migration |
| `supabase/` | SQL migrations (idempotent, numbered), RLS policies, RPCs, edge functions |
| `cloudflare/` | TypeScript Worker fronting a private R2 bucket (JWT verify → RLS check → rate limit → stream) |
| `vault/` | Knowledge base — read before source |
| `docs/`, `flutter_app/docs/` | Design history, audits, roadmaps |

## Architecture

Clean architecture inside `flutter_app/lib/`; dependencies point inward.

| Layer | Dir | Holds |
|---|---|---|
| presentation | `lib/presentation/` | screens, widgets, theme, go_router, dialogs, l10n |
| application | `lib/application/` | Riverpod providers, orchestration services, `character_creation/` |
| domain | `lib/domain/` | entities, schema, pure services, repository interfaces |
| data | `lib/data/` | Drift DB (tables/DAOs), repository impls, datasources, network |
| core | `lib/core/` | config, logging, perf probes, shared utils |

Keep `domain/` free of Flutter and third-party imports. All database access goes through Drift DAOs — no raw SQL outside a DAO (the DDL blocks in `app_database.dart` are the deliberate exception).

### Schema-driven entities

Nothing about a "monster" or a "spell" is a Dart class. `Entity` ([lib/domain/entities/entity.dart](flutter_app/lib/domain/entities/entity.dart)) is a generic record whose type-specific data lives in an untyped `fields` map; a `WorldSchema` of `EntityCategorySchema` → `FieldSchema` describes what those keys mean and how they render. `FieldType` ([lib/domain/entities/schema/field_schema.dart](flutter_app/lib/domain/entities/schema/field_schema.dart)) enumerates every widget type, and each variant's doc comment is the authoritative spec for its value shape — read it before touching a field's data.

Adding a field type means: a `FieldType` enum entry with its shape documented, a case in `lib/presentation/widgets/field_widgets/field_widget_factory.dart` (or `structured_list_field_widgets.dart` for list-shaped types), and the schema-side declaration in `lib/domain/entities/schema/builtin/`.

The built-in D&D 5e template and the hand-authored SRD 5.2.1 pack live in `lib/domain/entities/schema/builtin/` (`builtin_dnd5e_v2_schema.dart` + `lookups.dart` for categories and Tier-0 seeds; `srd_core/` for the content). `srdCorePackVersion` in `srd_core/srd_core_pack.dart` must be bumped when that content changes.

### Grant resolution — "one mechanic, one field"

`CharacterResolver` ([lib/domain/services/character_resolver.dart](flutter_app/lib/domain/services/character_resolver.dart)) is a pure, stateless read-time function folding a `Character`'s raw choices plus its source cards into an `EffectiveCharacter`. Cards declare mechanics in **plainly named fields** — there is deliberately no effect DSL, no kind registry, and no predicate language (both DSLs were removed 2026-07-28; `data/schema/rule_effects_migration.dart` converts legacy data).

`CharacterResolver.grantFieldKeys` is the complete closed contract, and `applyGrantsFrom` is its single reader. **Adding a mechanic requires four coordinated edits** — a key in `grantFieldKeys`, a line in `applyGrantsFrom`, a field in `_FB.grantBlock` (`builtin/content.dart`), and an isolation case — and the guards in `test/domain/services/grant_contract_test.dart` and `grant_field_isolation_test.dart` fail until all four exist. Class, Subclass, and Background deliberately do *not* carry the grant block; their grants have typed homes read by dedicated resolver passes, and the contract test asserts no card ever declares both names of a synonym pair.

Details and the full key table: [vault/20-Systems/Grant-Resolution.md](vault/20-Systems/Grant-Resolution.md).

### Refs: hard vs soft

Hard refs (`*_ref` → uuidv5) resolve inside a package at build time via the two-pass refgraph and **cannot dangle** — the build gates on it. Soft refs (`{slug, name}`) resolve lazily at read time across installed packages; a missing target is silently dropped and surfaced as a warning on `EffectiveCharacter`, never a failure. See [vault/20-Systems/Ref-Resolution-Hard-vs-Soft.md](vault/20-Systems/Ref-Resolution-Hard-vs-Soft.md).

### Offline-first sync

Local Drift SQLite is the source of truth; Supabase Postgres is a row-for-row mirror; CDC replicates back. A local edit flows: `PendingWriteBuffer.schedule` (750–2000 ms debounce per `WriteKind`) → `SyncEngine.enqueue*` → `SyncOutboxDao.enqueueCoalesced`, where rows with a matching `(target_table, target_pk, op_type)` **overwrite** each other. Drain order is `(nextAttemptAt ASC, createdAt ASC)`, which preserves dependency order; retries back off exponentially to 5 min and dead-letter at 50 attempts. Inbound CDC lands via `world_mirror_applier` with a 3 s per-entity echo-suppression window. Fast tier (world-scoped data) drains immediately; slow tier (personal packages, worldless characters) carries a delay so coalescing can batch.

Full step-by-step: [vault/20-Systems/CDC-Sync-Flow.md](vault/20-Systems/CDC-Sync-Flow.md).

### Drift schema v12

`schemaVersion` is 12 and it is a **fresh cut** — all v1–v11 migration steps were deleted. Any pre-v12 DB found on disk is renamed to `dmt.sqlite.legacy.<ts>` (kept 30 days) and a fresh v12 file is created; `onUpgrade` should never run. The database is per-user (`AppPaths.dataRoot/users/{userId}/db/dmt.sqlite`). Four side tables (`asset_refs`, `sync_telemetry`, `migration_progress`, `bm_mark_ops_local`) are managed with idempotent raw DDL in `beforeOpen` to avoid codegen, so they do not bump the schema version. `foreign_keys = OFF` is intentional — it lets CDC apply events out of order, with parent-exists checked at the app level.

### Second screen / projection

The DM can project to a pop-out desktop window (`desktop_multi_window`, driven by IPC), a screencast target, or every connected online player. `main()` branches on `args.first == 'multi_window'` *before* any heavy initializer — the sub-window is a pure rendering slave. A sub-window must never close itself (`windowManager.destroy()` from inside crashes on Linux); it signals the DM process, which closes it from outside.

## Conventions

- **Riverpod** for state (`@riverpod` where possible), **Freezed** for immutable models, **Drift** for persistence.
- `snake_case` files, `PascalCase` classes. Lints in [flutter_app/analysis_options.yaml](flutter_app/analysis_options.yaml) promote `use_build_context_synchronously`, `cancel_subscriptions`, and `close_sinks` to warnings.
- **Every user-facing string is localized.** Add the key to `lib/presentation/l10n/app_en.arb` first, then `app_tr.arb`, `app_de.arb`, `app_fr.arb`; read it as `L10n.of(context)!.keyName`.
- Comments and prose in this repo are a mix of Turkish and English — match the surrounding file.
- Admin identity is never in source: it lives in the `app_admins` table and the client only learns a bool via the `is_admin()` RPC.
- Branch from `main` (`feature/…`, `fix/…`), run `flutter analyze && flutter test` before pushing, address review with new commits rather than force-pushes.