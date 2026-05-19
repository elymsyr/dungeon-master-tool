# Release Notes

## Dungeon Master Tool v8.0.0 — Row-Level Sync, Built-in Pack Link-Only, Map & Combat Overhaul (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v8.0.0) · [elymsyr.github.io](https://elymsyr.github.io/)

The sync-correctness and canvas release. v8.0 lands the first phase of the row-level save+sync rewrite (F0): personal packages now sync per entity instead of as a single blob, the SRD core pack stops shipping per-user duplicates and is referenced by link, and world children correctly bump their parent so cross-device reconciliation no longer misses edits. On top of that, the world map and mind map canvases were split into focused widgets, the combat provider was tightened across the session/editor/sidebar surfaces, and several big screen files (main_screen, world_map_screen, landing_screen, player_main_screen, save_sync_indicator, character_editor) were decomposed.

> **Heads-up — local DB schema is unchanged from v7.** No client-side migration; existing data loads in place.

> **Heads-up — Supabase migrations 045–051 ship in this release.** Built-in world entities are dropped server-side (replaced by link-only references), the `is_builtin` column goes away, world children get bump-parent triggers, and `world_members` flips to `REPLICA IDENTITY FULL` so realtime member updates carry the full row.

### Highlights

- **Personal packages — per-entity sync** — Migration 046 splits personal packages into row-per-entity storage; package edits propagate one entity at a time instead of a full blob rewrite. First step of the row-level save+sync roadmap (F0).
- **Built-in pack is link-only** — `srd_core_bootstrap` no longer materializes SRD entities per user/world; built-in content is synthesized on demand from `builtin_synth` and referenced by link. Migration 045 drops legacy built-in world entities, migration 047 retires the `is_builtin` flag entirely.
- **World children bump parent on edit** — Migration 048 adds bump-parent triggers across world sub-tables so child writes update the world's `updated_at`; migrations 049/050 fix cascade/skip semantics so deletes don't double-fire.
- **Realtime member updates carry full rows** — Migration 051 sets `world_members` to `REPLICA IDENTITY FULL` so CDC events on the player tab include every column, not just the primary key.
- **Cloud-delete propagation fix** — `world_mirror_applier` + `world_reconciler` now correctly apply remote deletes that originated on another device (previously left orphan rows locally).
- **World map split** — `world_map_screen` decomposed (530+ lines extracted): pin editing moves to `pin_edit_dialog`, timeline editing to `timeline_entry_dialog`, infinite-canvas scaffolding to `unbounded_stack`. Notifier gains explicit selection + viewport plumbing.
- **Mind map overhaul** — Painter, canvas, notifier, and screen refactored for cleaner state ownership; level-of-detail and connection rendering hardened against large workspaces.
- **Combat provider tightened** — Several rounds of cleanup across `combat_provider`, `session_screen`, `character_editor_screen`, and `characters_sidebar` to keep initiative, HP, and turn state consistent when characters claim/release in online worlds.
- **Sync engine tiers + startup gate** — New `sync_tier` classification, `startup_sync_gate` to block UI until first reconciliation completes, and `pending_write_buffer` extracted into its own service so editor writes survive transient outages.
- **Save/Sync indicator decomposed** — `save_sync_indicator` split into `save_sync_shared` primitives and a thinner widget; same visual contract, much less duplication across the editor surfaces.
- **Hub & player screens slimmed** — `main_screen` (+335/-90), `landing_screen`, `player_main_screen`, `database_screen`, `packages_tab`, and `session_screen` all decomposed into smaller widgets; UI state provider grows explicit tab/selection slots.
- **Built-in content synthesizer** — New `builtin_synth` utility renders built-in entities for cards/lists without persisting them, replacing the bootstrap-time write loop.
- **Localization sweep round 2** — ~165 new l10n keys covering landing, hub (worlds/characters/packages), session, main, campaign selector, and player main screens; full EN / TR / DE / FR coverage. Most remaining hardcoded UI strings are gone.
- **Mobile responsiveness fixes (F-M1/M2)** — Landing screen no longer rebuilds the entire stack on every keyboard animation frame (tagline isolated into its own widget, viewInsets read locally). Mention overlay in `markdown_text_area` now repositions when the soft keyboard shows/hides via `WidgetsBindingObserver`. Marketplace panel layout reworked for narrow widths.
- **Mobile responsiveness audit doc** — `flutter_app/docs/mobile_responsiveness_audit_may19.md` captures the May 19 sweep: K1–K5 keyboard items, M1–M2 mention overlay, plus the deferred O1–O14 layout findings.

### Upgrade notes

- **App version bump:** `7.0.0` → `8.0.0`.
- **Local DB:** schema v12, unchanged from v7. No client migration.
- **Cloud migrations:** Supabase migrations `045`–`051` ship in this release. Run them in order before launching v8 against existing cloud data.
- **Built-in content:** users with cloud-mirrored built-in entities will see them removed server-side by migration 045 and re-rendered from local synth on next open.

### Known issues

- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Row-level save+sync** — F0 (repo API) shipped; F1–F6 (per-row outbox, change-bus apply, CDC row-merge) still pending.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.