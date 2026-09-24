---
type: moc
domain: architecture
updated: 2026-09-23
tags: [moc, architecture]
---

# Architecture Overview — Master Map

> [!summary] The whole system in one note
> Flutter client (clean architecture, **local-first**) + Supabase (auth, membership, marketplace, DM'in paylaşım kanalı) + Cloudflare R2 worker (media/catalog). Content is built offline from Open5e by a Dart pipeline and shipped as packages. Multi-platform: desktop / mobile / web + a second-screen projection target.
>
> Yerel Drift kaynak-doğru. Cihazdan cihaza taşıma "Online yap" denen dünya/paket için bulut aynasının ([[cloud_push_service]] / [[cloud_pull_service]]), hesapsız ve internetsiz ise `.dmtz` dosya aktarımının işi; oyuncuya giden yalnızca DM'in bilinçli paylaşımları. LAN sync Faz 6'da (2026-09-24) silindi.
>
> **Dünyanın kimliği `worldId`** (2026-09-21): isim salt etiket. Repository, aktif dünya provider'ı, medya klasörü (`worlds/<id>/`) ve UI durumu id ile anahtarlı — aynı dünya iki cihazda aynı kimliği taşısın diye. Bkz. [[World-and-Content]]. Paketler hâlâ adla anahtarlı.

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

- **Sync-and-Realtime** has three independent arms: bulut aynası ([[cloud_push_service]] / [[cloud_pull_service]]), `.dmtz` dosya aktarımı ([[content_archive]] — hesapsız, internetsiz, [[content_codec]]) ve DM'in paylaşım yayını (Supabase Realtime üzerinden [[Backend-Infra]]'ya, oradan [[Multiplayer-and-Online]]'a).
- **Content-Pipeline** builds packages offline ([[Pack-Build-Two-Pass-Refgraph]]) that [[World-and-Content]] installs; [[Character-System]] resolves them at read-time via [[Grant-Resolution]]. Packages may [[Package-Links|link]] each other instead of duplicating content.
- **Projection** snapshots state from [[Combat-and-VTT]] and [[World-and-Content]], applying [[Fog-of-War-and-Visibility]] before output.

## Key cross-cutting flows
- [[Share-Broadcast-Flow]] — DM'in paylaştığı → oyuncuda canlı. Beş tablo, doğrudan yazma.
- Bulut aynası — LAN eşlemesinin yerine (LAN `online-again` Faz 6'da silindi) tam online: bulut şeması 094 ile kuruldu ([[migrations-cloud-mirror]]), istemcinin giden yolu Faz 4a–4b'de bağlandı ([[cloud_push_service]]: Drift **v13** + watermark taraması; dünya, karakter ve paket kapsamları), dünyanın geri okuması Faz 5a'da ([[cloud_pull_service]], migration 096), canlı sinyal ve sunucu tarafı "son düzenleyen kazanır" Faz 5b'de (migration 097), ikinci cihazın ilk senkronu ve paket pull'u Faz 5c'de (migration 098).
- [[Grant-Resolution]] — descriptive content → typed EffectiveCharacter.
- [[Media-Storage-Tiers]] — free (Supabase) vs dünya medyası (R2 `worlds/{worldId}/`, multiplayer dünyanın tamamı, kişi başı 1 GB — Faz 5d) vs pinned (R2 `pub/`, refcount); `worlds/` + `pub/` tek 9 GB tavan. Sayılan katman emekli (Phase D), transient kalktı (5d).
- [[Package-Links]] — one package borrows another's content; links follow it into worlds and downloads.

## Source docs (design history)
- `flutter_app/docs/`: `open5e_import_roadmap.md`, `security_media_supabase_r2_audit_may21.md`, `email_confirmation_setup.md`.
- `docs/content-audit/`: `entity_audit_log.md` + `system_mechanics_roadmap.md` — Jun 2026 full-pack audit (19 packs, 20 712 cards).
- `docs/new_system/`: `master-roadmap.md`, `the-template-system.md`, `content-convert.md` — [[Template-System]] initiative (approved 2026-06-10).
- `docs/TEMPLATE_RELEASE_NOTE.md` — release note style guide.
