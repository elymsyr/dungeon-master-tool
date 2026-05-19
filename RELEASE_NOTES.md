# Release Notes

## Dungeon Master Tool v8.1.0 — Save/Sync Correctness, Viewport Split, Persistent Measurements (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v8.1.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Follow-up to v8.0 focused on save/sync correctness, viewport semantics, and a handful of UX cleanups. The combat provider now refuses to write back during the world-swap transient window (fixes the bug where the auto-create-encounter post-frame could clobber persisted state with an empty payload), session notes ride the same combat_state path with cross-tab sync, and pan/zoom on world/mind maps was split into a sibling `map_view` / `mind_map_views[mapId]` settings subkey that stays local-only. Battlemap circles and rulers are now persisted as vector JSON so individual marks remain deletable. Local debounce no longer multiplies by sync tier (the multiplier was dead code), and the CDC applier guards every remote-apply path against in-flight local edits via a new `PendingWriteBuffer.isPending` check.

> **Heads-up — local DB schema is unchanged from v8.0.** Encounter gains a new optional `measurementsData` field but it is stored in the existing settings JSON blob; no migration.

> **Heads-up — no new Supabase migrations.** v8.1 is client-only on the cloud side. `map_view` and `mind_map_views[mapId]` are intentionally local-only — they never enter the world settings cloud mirror.

### Highlights

- **Combat load-gate fix** — `CombatNotifier` no longer writes back during the `beginLoad → completeLoad` transient. Without this, the auto-create-encounter post-frame in `session_screen` could land a bogus "Encounter 1" + empty event log into `combat_state` before the real campaign data arrived via revision bump.
- **Session notes — cross-tab sync** — Free-form Notes pane now persists into `combat_state.session_notes`, debounced 300ms and routed through the existing `combatTick` (500ms) tier. Listener on the controller flushes on `dispose`; provider listen keeps the controller text in lockstep when another device edits the world.
- **Viewport split (world map)** — Pan/zoom moved out of `map_data` into a sibling `map_view` settings key written via the new `saveSettingsPatchLocalOnly` path — local Drift only, never enqueued to the outbox. Reset-on-edit 2s debounce (`WriteKind.viewport`). DM pan no longer jumps remote clients or other devices.
- **Viewport split (mind map)** — Same treatment: viewport per-map lives in `mind_map_views[mapId]`, content (nodes/edges) stays in `mind_maps[mapId]`. Legacy nested `scale/pan_x/pan_y` keys are still read for worlds saved before the split.
- **Persistent battlemap measurements** — Circles and rulers placed with the "persistent" tool now serialize to vector JSON in `Encounter.measurementsData` instead of being flattened into the annotation PNG. Individual marks stay deletable after reload; `clearMeasurements` and the nearest-mark tap-delete now both trigger the debounced auto-save.
- **Battlemap auto-save coalesced** — Fog stroke / token drag / grid toggle no longer fire one outbox push per edit. `_debouncedAutoSave` now schedules under `combatTick` (500ms) — multiplayer fog remains snappy without saturating the push pipeline on mobile.
- **CDC race guard** — `PendingWriteBuffer` exposes `isPending(key)` / `hasPendingPrefix` / `pendingKeysWithPrefix`. `world_mirror_applier` now refuses to apply remote entity, character, map_data, or world_settings updates while a local edit is pending on the same key; for `settings_json` it merges subkey-by-subkey so `map_view` / `combat_state` / `mind_maps` no longer clobber each other.
- **Local debounce simplification** — `SyncTier.debounceMultiplier` removed (dead code: no call site ever passed `tier:`). `WriteKind.window` is now authoritative for local debounce. `SyncTier.slow.cloudDelay` cut from 30s → 10s so personal package + worldless character edits hit the cloud faster.
- **Exit "Saving..." overlay** — Character editor close, world exit, and package exit now show a `globalLoading` overlay while flushing pending writes; if online they also call `syncEngine.forceTick()` so slow-tier rows don't sit in the outbox past the navigation boundary.
- **Local-only key preservation in CDC** — Full `worlds` row apply (`_applyWorldsEvent`) now restores `map_view` and `mind_map_views` after the in-memory `decoded.clear() + addAll` so the viewport doesn't snap back to default whenever a remote settings event lands.
- **Theme parity for mobile toolbar** — Global `checkboxTheme`, `switchTheme`, and `bottomSheetTheme` in `palettes.dart`; battlemap mobile toolbar `_SwitchRow` reworked to use `Checkbox + InkWell` matching the desktop control pattern.
- **World map canvas long-press menu** — Restored canvas-level `onLongPressStart` for the context menu (regression from v8 pin-gesture rework). Pin long-press still wins via gesture arena.

### Upgrade notes

- **App version bump:** `8.0.0` → `8.1.0`.
- **Local DB:** schema v12, unchanged. `Encounter.measurementsData` rides the existing settings JSON blob.
- **Cloud migrations:** none in this release.
- **Local-only viewport keys:** existing `map_data.{scale,pan_x,pan_y}` and `mind_maps[mapId].{scale,pan_x,pan_y}` are read as fallback on load; new writes go to the sibling `map_view` / `mind_map_views[mapId]` keys. No user action required.

### Known issues

- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Row-level save+sync** — F0 (repo API) shipped in v8.0; F1–F6 (per-row outbox, change-bus apply, CDC row-merge) still pending.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.