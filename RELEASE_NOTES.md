# Release Notes

## Dungeon Master Tool v8.2.0 — Player Auto-Sync, Reconnect Catch-Up, Claim/Unclaim Fixes (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v8.2.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Follow-up to v8.1 focused on online-world realtime reliability. Players now get the same automatic realtime subscribe + initial-state seed that DMs already had — no manual Sync button required. Both the world and per-user realtime channels recover from connection drops on their own: every reconnect triggers a full catch-up (`postgres_changes` does not replay events missed during an outage), and failed channels resubscribe with exponential backoff instead of silently dying. Owner characters now sync live across a player's devices even while the world is closed. Several claim/release/assign bugs are fixed, including a character name reverting to the SRD package name after an ownership change.

### Highlights

- **Player auto-sync** — `worldMirrorApplierProvider` is now watched in `MainScreen` *before* the role branch, so `PlayerMainScreen` gets the same automatic realtime subscribe + `applyInitialState` seed that the DM view had. Players no longer need to press Sync to see live updates; the Sync button is now a manual "Retry" only.
- **Player exit flushes pending writes** — Player exit-to-hub now shows the `Saving...` overlay while flushing the `PendingWriteBuffer` and, when online, calling `syncEngine.forceTick()` — debounced character edits no longer get dropped at the navigation boundary.
- **Reconnect catch-up** — `WorldSyncService` and `PersonalSyncService` now fire their `SUBSCRIBED` callback on *every* connect, not just the first. Each reconnect re-runs `applyInitialState` + roster refresh so events missed during a connection drop are recovered without the user manually leaving and re-entering the world.
- **Resubscribe with backoff** — On `channelError` / `timedOut`, both sync services rebuild the channel from scratch with exponential backoff (1, 2, 4, 8, 16, 30s cap). A failed join no longer leaves a permanently dead channel.
- **Rebuild-storm fix** — `worldMirrorApplierProvider` switched from `.future` to `selectAsync` for `worldId` / `role`. `.future` minted a new Future every recompute, so `applyInitialState`'s `_bumpRevision` retriggered the provider in an infinite loop (rebuild storm, tooltip-ticker spam). `selectAsync` stays quiet when the resolved value is unchanged.
- **Owner characters sync while world is closed** — `PersonalSyncService` now also listens to `world_characters` rows where `owner_id = uid`. An owner's online-world character syncs live to all their devices (hub Characters tab) even when the world itself isn't open. Apply logic is shared with the world channel via the new `WorldMirrorApplier.applyCharacterCdc`.
- **Claim/unclaim name fix** — Metadata-only updates (claim / release / assign) don't put the large `payload_json` TOAST column in the Postgres WAL, so CDC delivered it as `null` and the character name fell back to the SRD package name. The CDC applier now resolves a fallback payload from the existing in-memory row before decoding.
- **Ownership-leaves cleanup** — Releasing or reassigning a character now drops it from your hub Characters tab and local Drift via the new `dropMirror` / `dropLocal` path — without a trash snapshot and without a cloud delete. The canonical `world_characters` row stays in the world (shown as unclaimed), and a later re-claim isn't blocked by the trash guard.
- **Optimistic release fix** — Optimistic owner clear used `copyWith(ownerId: null)`, which `?? this.ownerId` quietly ignored. A new `clearOwner: true` flag actually nulls the owner.
- **Owner label from canonical column** — The character `User` chip now resolves the owner from the canonical `owner_id` column (`resolveOwnerLabelById`) instead of the `ownerId` embedded in `payload_json`, which goes stale after a claim/release/assign RPC.
- **SRD core link self-heal** — `SrdCoreBootstrap` now keys idempotency on the device-local `installed_packages` link, not the `_srdCoreImportedAt` settings flag. That flag rides in synced `world_settings`, so a player joining a world inherited the DM's flag and never created their own link. Checking the link directly self-heals any world missing it.
- **Disposed-applier guards** — `WorldMirrorApplier` now sets a `_disposed` flag on `stop()`; in-flight async events bail before touching a stale `ref` after a provider rebuild/dispose, and `_bumpRevision` is wrapped against the dependency-change window.
- **Session-notes notifier re-capture** — `combatProvider` rebuilds on campaign/revision change, swapping the `CombatNotifier` instance. `session_screen` now re-captures the notifier every `build()` (instead of once in `initState`) so the dispose-time session-notes flush hits the live notifier, guarded by a `mounted` check.
- **Theme-token cleanup** — Hardcoded `BorderRadius.circular(...)` and literal colors across the session screen, player screen, battle-map toolbars, entity card, and projection view replaced with palette tokens (`palette.br` / `cbr` / `chr`, `cardBorderRadius`, `tabIndicator`, `sidebarDivider`, `dangerBtnBg`, `tokenBorderActive`). `tabIndicator` added to the palettes that were missing it. The redundant "PLAYER" badge was removed from the player screen header.

### Upgrade notes

- **App version bump:** `8.1.0` → `8.2.0`.
- **Local DB:** schema v12, unchanged. No migration.
- **Cloud migrations:** none in this release.
- **No user action required.** The SRD core link self-heal runs automatically on next world open for any world missing its device-local `installed_packages` link.

### Known issues

- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Row-level save+sync** — F0 (repo API) shipped in v8.0; F1–F6 (per-row outbox, change-bus apply, CDC row-merge) still pending.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.

---

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