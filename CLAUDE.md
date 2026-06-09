# CLAUDE.md — dungeon-master-tool

Flutter/Dart D&D 5e app (clean architecture) + Supabase backend + Cloudflare R2 worker + offline Open5e content pipeline.

## Obsidian Vault SOP (knowledge base at `vault/`)

A curated knowledge base lives in [vault/](vault/). It is the **map of the codebase** — consult it instead of re-reading raw source. Start at `vault/Home.md` → `vault/00-Maps/_Architecture-Overview.md`. Full rules in `vault/90-Meta/SOP.md`.

These three rules are binding every session:

1. **Consult First.** Before modifying existing logic or writing new code in an area, read the matching `vault/10-Files/<basename>.md` (or the domain MoC in `vault/00-Maps/`). Treat its *Inputs/Outputs* + *Key Logic* as the contract; open raw source only if the note is missing, stale, or insufficient.

2. **Auto-Update.** When you create a new source file, immediately create its tracking note from `vault/90-Meta/Templates/File-Tracking-Note.md`, file it under the right `vault/10-Files/<domain>/`, fill all sections, and wire it in: link up to its domain MoC, lateral to deps/callers, and add it to the MoC's Key Files list. When you change a file's behavior, update its note's *Key Logic* and `updated:` date.

3. **Maintain Context.** When the environment/architecture changes (new Supabase migration, new worker route, schema/version bump, new domain or platform target), update the affected MoC + frontmatter and append a line to `vault/90-Meta/Vault-Changelog.md`.

**Conventions:** note name = source basename without extension (`sync_engine.dart` → `[[sync_engine]]`); grouped notes use descriptive names (`[[migrations-online-worlds]]`). Hybrid granularity — notes for architecturally significant files only (services, DAOs, resolvers, mappers, worker modules, logic providers, schema cores, CI/config); skip trivial models, generated `*.g.dart`/`*.freezed.dart`, pure-layout widgets, l10n.

## Domains (11)
Sync & Realtime · Character System · Combat & VTT · Projection/Second-Screen · World & Content · Multiplayer & Online · Media & Assets · Backend Infra · Content Pipeline · Data Layer · Deployment & Ops. Each has a Map of Content under `vault/00-Maps/`.

## Tests
Per user preference, `flutter test` is skipped — `flutter analyze` is the gate.
