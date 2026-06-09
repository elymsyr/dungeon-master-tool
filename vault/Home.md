---
type: home
updated: 2026-06-09
tags: [home, moc]
---

# Dungeon Master Tool — Knowledge Vault

> [!info] What this is
> Curated map of the **dungeon-master-tool** codebase: a Flutter/Dart D&D 5e app (clean architecture) + Supabase backend + Cloudflare R2 worker + offline Open5e content pipeline. Consult these notes **before** reading raw source. See [[SOP]] for the operating rules.

## Start here
- [[_Architecture-Overview]] — master map: clean-arch layers, domain index, the connection map.
- [[SOP]] — how we keep this vault current (consult / auto-update / maintain-context).
- [[Glossary]] — CDC, MoC, Tier-0/Tier-1, EffectiveCharacter, coalescing, echo-suppression.

## Domains (Maps of Content)
| Domain | Owns |
|---|---|
| [[Sync-and-Realtime]] | Offline-first CDC sync — outbox, tiers, mirror, reconcile |
| [[Character-System]] | Chargen wizard, level-up, effect resolution |
| [[Combat-and-VTT]] | Initiative, battle map grid, tokens, fog |
| [[Projection-Second-Screen]] | DM→player output: window / screencast / online |
| [[World-and-Content]] | Worlds, entities, packages, schema, marketplace |
| [[Multiplayer-and-Online]] | Membership, invites, roles, auth, presence |
| [[Media-and-Assets]] | 3-tier media storage, soundpacks, image upload/GC |
| [[Backend-Infra]] | Supabase (migrations/RLS/RPC) + Cloudflare R2 worker |
| [[Content-Pipeline]] | Open5e import tool, pack build, catalog publish |
| [[Data-Layer]] | Drift schema, tables, DAOs, repositories |
| [[Deployment-and-Ops]] | CI, build, wrangler, dart-define, Docker |

## System deep-dives
- [[CDC-Sync-Flow]] · [[Effect-DSL-Resolution]] · [[Ref-Resolution-Hard-vs-Soft]]
- [[Media-Storage-Tiers]] · [[Fog-of-War-and-Visibility]] · [[Pack-Build-Two-Pass-Refgraph]]

## Platform integration
- [[Multi-Window-IPC]] · [[Screencast-Presentation-API]] · [[Platform-Targets]] · [[Audio-SoLoud]]

## Reference
- [[SRD-5.2.1]] · [[Open5e-API]] · [[Content-Licenses]] · [[Glossary]]

## Meta
- [[Vault-Changelog]] — what changed in the vault and when.
