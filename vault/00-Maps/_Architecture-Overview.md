---
type: moc
domain: architecture
updated: 2026-06-09
tags: [moc, architecture]
---

# Architecture Overview — Master Map

> [!summary] The whole system in one note
> Flutter client (clean architecture, offline-first) ⇄ Supabase Postgres mirror (realtime CDC) + Cloudflare R2 worker (media/catalog). Content is built offline from Open5e by a Dart pipeline and shipped as packages. Multi-platform: desktop / mobile / web + a second-screen projection target.

## Clean-architecture layers
The Flutter app (`flutter_app/lib/`) is layered; dependencies point inward.

| Layer | Dir | Holds |
|---|---|---|
| **presentation** | `lib/presentation/` | screens, widgets, theme, router, dialogs |
| **application** | `lib/application/` | Riverpod providers, services (orchestration), character_creation |
| **domain** | `lib/domain/` | entities, schema, pure services ([[character_resolver]]), repositories (interfaces) |
| **data** | `lib/data/` | Drift database (DAOs/tables), repositories (impl), datasources, network |
| **core** | `lib/core/` | logging, perf probes, shared utils |

Backend lives outside `lib/`: `supabase/` (SQL migrations, RLS, RPC, edge fns) and `cloudflare/` (TS worker). Offline tooling in `flutter_app/tool/`. Built-in content in `lib/domain/entities/schema/builtin/`.

## Domain index
See [[Home]] for the full table. The 11 domains and their lead notes:
[[Sync-and-Realtime]] · [[Character-System]] · [[Combat-and-VTT]] · [[Projection-Second-Screen]] · [[World-and-Content]] · [[Multiplayer-and-Online]] · [[Media-and-Assets]] · [[Backend-Infra]] · [[Content-Pipeline]] · [[Data-Layer]] · [[Deployment-and-Ops]]

## The connection map

> [!note] Link rules (how this vault is wired)
> 1. **Vertical** — every file note ⇄ its domain MoC.
> 2. **Lateral** — file note → direct deps & callers.
> 3. **System** — `20-Systems/` deep-dives ⇄ every participating file note.
> 4. **Cross-domain** — MoCs link to adjacent MoCs.
> 5. **Reference** — spec-implementing notes → `40-Reference/`.
> 6. **Docs bridge** — notes → matching `flutter_app/docs/*`.

**Cross-domain adjacency (the high-traffic edges):**
```
Character-System ──uses──> Data-Layer ──mirrors──> Backend-Infra
       │                       ▲                        │
       │                       │                        ▼
   Combat-and-VTT          Sync-and-Realtime ──CDC──> Multiplayer-and-Online
       │                       │                        │
       ▼                       ▼                        ▼
 Projection-Second-Screen   World-and-Content       Media-and-Assets
                                │
                                ▼
                          Content-Pipeline ──builds──> packages ──install──> World-and-Content
```

- **Sync-and-Realtime** is the spine: it drains the [[sync_outbox_dao|outbox]] in [[Data-Layer]] and mirrors to [[Backend-Infra]] (Supabase CDC), feeding [[Multiplayer-and-Online]].
- **Content-Pipeline** builds packages offline ([[Pack-Build-Two-Pass-Refgraph]]) that [[World-and-Content]] installs; [[Character-System]] resolves them at read-time via [[Effect-DSL-Resolution]].
- **Projection** snapshots state from [[Combat-and-VTT]] and [[World-and-Content]], applying [[Fog-of-War-and-Visibility]] before output.

## Key cross-cutting flows
- [[CDC-Sync-Flow]] — 12-step local-edit → Postgres → peer apply.
- [[Effect-DSL-Resolution]] — descriptive content → typed EffectiveCharacter.
- [[Media-Storage-Tiers]] — free (Supabase) vs counted (R2) vs transient (R2 LRU).

## Source docs (design history)
`flutter_app/docs/`: `open5e_import_roadmap.md`, `chargen_mechanics_wiring.md`, `online_second_screen_architecture_may21.md`, `security_media_supabase_r2_audit_may21.md`, plus the dated sync/perf redesign docs.
