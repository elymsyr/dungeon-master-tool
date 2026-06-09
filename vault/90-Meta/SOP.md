---
type: meta
domain: meta
updated: 2026-06-09
tags: [meta, sop]
---

# Vault SOP — Standard Operating Procedure

> [!important] This is the contract
> These rules keep the vault a trustworthy substitute for reading raw source. Mirrored into the project `CLAUDE.md` so they apply every session.

## 1. Consult First
Before modifying existing logic or writing new code in an area, **read the matching `vault/10-Files/<file>.md`** (or the domain MoC in `00-Maps/`). Treat the note's Inputs/Outputs + Key Logic as the contract; only open raw source if the note is missing, stale, or insufficient.

## 2. Auto-Update
When **creating a new source file**, immediately create its tracking note from [[File-Tracking-Note]]:
- File in the correct `10-Files/<domain>/` folder.
- Fill all template sections (frontmatter + Inputs/Outputs + Dependencies + Key Logic).
- Wire it in: link **up** to the domain MoC, **lateral** to its deps/callers, and add it to the MoC's Key Files list (bidirectional).

When **modifying** a file enough to change its behavior, update its note's Key Logic + `updated:` date.

## 3. Maintain Context
When environments / architecture change, update the affected map and log it:
- New Supabase migration → update [[Backend-Infra]] grouped migration note + [[Data-Layer]] if tables change.
- New worker route → update [[worker]] note + [[Backend-Infra]].
- Schema/version bump, new domain, new platform target → update [[_Architecture-Overview]] + the relevant MoC.
- Always append a line to [[Vault-Changelog]].

## Conventions
- **Note name = source basename** without extension (`sync_engine.dart` → `[[sync_engine]]`). Grouped notes use descriptive names (`[[migrations-online-worlds]]`, `[[srd-pack-content]]`).
- **Granularity = Hybrid:** notes for architecturally significant files only (services, DAOs, resolvers, mappers, worker modules, logic providers, schema cores, CI/config). Skip trivial models, generated `*.g.dart`/`*.freezed.dart`, pure-layout widgets, l10n. Migrations grouped by family.
- **Frontmatter is queryable** — keep `domain`/`layer`/`status` accurate for Bases/Dataview.

## Templates
- [[File-Tracking-Note]] · [[Domain-MoC]] · [[System-Deep-Dive]]
