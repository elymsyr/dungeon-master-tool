---
type: moc
domain: architecture
updated: 2026-08-24
tags: [moc, architecture]
---

# Architecture Overview — Master Map

> [!summary] The whole system in one note
> Flutter client (clean architecture, **local-first**) + Supabase (auth, membership, marketplace, DM'in paylaşım kanalı) + Cloudflare R2 worker (media/catalog). Content is built offline from Open5e by a Dart pipeline and shipped as packages. Multi-platform: desktop / mobile / web + a second-screen projection target.
>
> Yerel Drift kaynak-doğru. Buluta dünya kopyalanmaz; cihazdan cihaza taşıma LAN sync'in işi, oyuncuya giden ise yalnızca DM'in bilinçli paylaşımları.

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
   Combat-and-VTT          Sync-and-Realtime ─shares─> Multiplayer-and-Online
       │                       │                        │
       ▼                       ▼                        ▼
 Projection-Second-Screen   World-and-Content       Media-and-Assets
                                │
                                ▼
                          Content-Pipeline ──builds──> packages ──install──> World-and-Content
```

- **Sync-and-Realtime** has two independent arms: LAN (cihazdan cihaza, bulutsuz) ve DM'in paylaşım yayını (Supabase Realtime üzerinden [[Backend-Infra]]'ya, oradan [[Multiplayer-and-Online]]'a).
- **Content-Pipeline** builds packages offline ([[Pack-Build-Two-Pass-Refgraph]]) that [[World-and-Content]] installs; [[Character-System]] resolves them at read-time via [[Grant-Resolution]]. Packages may [[Package-Links|link]] each other instead of duplicating content.
- **Projection** snapshots state from [[Combat-and-VTT]] and [[World-and-Content]], applying [[Fog-of-War-and-Visibility]] before output.

## Key cross-cutting flows
- [[Share-Broadcast-Flow]] — DM'in paylaştığı → oyuncuda canlı. Beş tablo, doğrudan yazma.
- [[LAN-Sync-Flow]] — aynı ağdaki iki cihaz arasında manuel, buluta uğramayan eşleme.
- [[Grant-Resolution]] — descriptive content → typed EffectiveCharacter.
- [[Media-Storage-Tiers]] — free (Supabase) vs counted (R2) vs transient (R2 LRU).
- [[Package-Links]] — one package borrows another's content; links follow it into worlds and downloads.

## Source docs (design history)
- `flutter_app/docs/`: `open5e_import_roadmap.md`, `security_media_supabase_r2_audit_may21.md`, `email_confirmation_setup.md`.
- `docs/content-audit/`: `entity_audit_log.md` + `system_mechanics_roadmap.md` — Jun 2026 full-pack audit (19 packs, 20 712 cards).
- `docs/new_system/`: `master-roadmap.md`, `the-template-system.md`, `content-convert.md` — [[Template-System]] initiative (approved 2026-06-10).
- `docs/TEMPLATE_RELEASE_NOTE.md` — release note style guide.
