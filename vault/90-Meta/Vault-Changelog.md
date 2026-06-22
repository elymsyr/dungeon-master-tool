---
type: meta
domain: meta
updated: 2026-06-22
tags: [meta, changelog]
---

# Vault Changelog

> [!note] Append-only log of vault structural changes. Newest first.

- **2026-06-22** — Docs reorganization + vault gap fill. **flutter_app/docs/**: deleted 4 completed docs (`chargen_mechanics_wiring.md`, `online_second_screen_architecture_may21.md`, `second_screen_dm_player_view_spec_may21.md`, `media_redesign_test_plan_may21.md`). **docs/**: created `content-audit/` subfolder, moved `entity_audit_log.md` + `system_mechanics_roadmap.md` into it. **Vault**: stripped 8 stale source-doc references across `_Architecture-Overview`, `Projection-Second-Screen`, `Character-System`, `Content-Pipeline`, `Combat-and-VTT`, `Fog-of-War-and-Visibility`, `Effect-DSL-Resolution`, `Ref-Resolution-Hard-vs-Soft`, `mapper_chargen`. Added `[[Combat-and-VTT]]` VTT Phase 1 shipped note (token HUD, hidden flag, context menu). New `[[Template-System]]` deep-dive in `20-Systems/`.
- **2026-06-10** — Template System initiative approved (`docs/new_system/master-roadmap.md`). Rules Engine frozen (R7 cancelled). No vault note existed until 2026-06-22.
- **2026-06-02** — VTT upgrade Phase 1 shipped: token HUD (DM+player), hidden flag end-to-end, damage/heal/hide context menu. [[Combat-and-VTT]] + [[Fog-of-War-and-Visibility]] affected; no vault structural change at time.
- **2026-06-01 to 06-09** — Multiple content-pipeline completions: chargen mechanics wiring C1-C7+D1-D9 done; subspecies first-class category; official pkg parity + chargen rules; pack consolidation (merged 2→1, dropped SRD 5.1/5.2 packs). [[Content-Pipeline]], [[Character-System]], [[World-and-Content]] file notes updated in-session.
- **2026-06-09** — SRD reference overlay feature. New `srdReferenceEntitiesProvider` in [[builtin_package_provider]] (new tracking note, wired into [[World-and-Content]]); `EntityNotifier` ([[entity_provider]]) gains `overlaySrdReference` to show the built-in SRD pack's entities as read-only, non-persisted reference rows in every other package's editing view. Touches [[package_screen]] (override flag).
- **2026-06-09** — Vault initialized. Bespoke structure for dungeon-master-tool: **154 notes total** = 32 scaffold (Home + 11 domain MoCs under [[_Architecture-Overview]] + 6 system deep-dives + 4 platform + 4 reference + 3 templates + [[SOP]] + this changelog) + **122 per-file tracking notes** under `10-Files/` (Hybrid granularity, seeded via 11-domain Workflow fan-out). Link verify: 9 dead links fixed, 0 orphans, 0 rendered dead links remain. SOP installed into project `CLAUDE.md` + `vault-sop` memory. `Welcome.md` removed.
