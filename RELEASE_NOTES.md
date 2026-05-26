# Release Notes

## Dungeon Master Tool v9.2.0 — Era Timeline Overhaul, Per-Location Maps, Beta Merge Hardening (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.2.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v9.1.0. World map era timeline becomes a full drill-in system: each location can carry its own nested pin/timeline data per era, with a fresh background image per era resolved straight off the location entity. Beta-enter no longer overwrites offline-only work with stale cloud rows — a dedicated merge service pushes local content cloud-first on first enter, gated by a per-user sentinel. Level-up dialog stops auto-committing on dismiss. Entity card stops crushing the name field next to the portrait on phones. Battle map background can be reused from a location's already-uploaded `battlemaps` field without re-uploading to R2.

### Highlights

#### World map & timeline

- **Epoch → Era rename, drill-in nested maps** — `MapEpoch` / `EpochWaypoint` renamed to `MapEra` / `EraWaypoint`. New `LocationMapData` holds per-location nested pin + timeline collections inside each era, so a location entity can have its own zoomed-in map with its own pins per era. Background image for the nested view comes from the location entity's `map_per_era[eraId]` (falls back to `map`), keeping image storage on the entity instead of duplicated in map state.
- **New `imagePerEra` field type** — Schema-driven image-per-era widget on location entities. DM uploads a different map image for each era and the world map picks the right one automatically when entering the era. New `_FB.image` / `_FB.imagePerEra` schema helpers with `mediaKindWire` plumbed through, so per-era map images count under the correct media quota kind.
- **Per-scope merge strategy on waypoint delete** — `DeleteWaypointDialog` now lists every scope that holds pin data (root world map + each location whose drilled map has pins in either era) so the DM picks merge / keep-left / keep-right independently per scope instead of forcing one strategy across the whole world.
- **Map breadcrumb + location pin preview** — New `map_breadcrumb_bar` and `location_pin_preview_card` widgets surface the current era + drill path and give pins a hover/tap preview before entering. `era_scroll_bar` replaces the old `epoch_scroll_bar`.
- **Battle map "From location" picker** — New `battlemap_picker_flow` lets the DM pick a battle map background from either a fresh device file *or* a location entity's `battlemaps` field. Location refs skip re-upload because they are already `dmt-asset://` refs counted under `MediaKind.battleMap`; `applyMapImage` is shared between the two sources so reused refs flow through the same decode/state pipeline.

#### Characters

- **Level-up dialog stops auto-committing on dismiss** — Previously any exit path (barrier tap, system back, X icon) committed the level up via `PopScope.onPopInvokedWithResult`. Now only the **Apply** button commits; barrier tap / back gesture / new **Cancel** button discard the staged choices and leave the character untouched.
- **Entity selector picks up bundled SRD rows** — Char-sheet relation fields (inventory, equipment) couldn't pick from the bundled SRD 5.2.1 Core rows (longsword, leather armor, …) because those rows live in the in-memory `builtinSrdEntitiesProvider`, not `entityProvider`. New `includeBuiltinSrd: true` flag merges them in for char-sheet pickers (map/session/mindmap pickers default to false to keep the ~7K SRD rows out of those lists). `EntityNameText` also falls back to the SRD map, so previously-picked SRD rows render with their real name instead of a raw UUID.
- **Entity card mobile layout** — On phones, the portrait gallery now stacks above the name/subtitle/description column instead of sitting beside it. The 200 px portrait was crushing the name field on narrow screens; tablet+ layouts are unchanged. The same vertical-stack pattern lands in the projection view.

#### Sync, beta & storage

- **Beta-enter merge service (PR-B1..B6)** — First-time beta-enter on a device used to race the cloud appliers: a stale cloud row from a prior beta session could land before local writes and silently wipe offline work (the "Aleseus" content-loss case). New `BetaEnterMergeService` pushes every piece of owned local content (worlds + their granular tables, orphan characters, personal packages) to the cloud *before* any cloud→local applier runs, with **local-wins** conflict policy on first enter. Gated by a per-user `BetaEnterGate` sentinel; `leaveBeta` clears the sentinel so a re-enter re-runs the merge.
- **Wipe guards in cloud appliers** — `CloudCatchupService`, `PersonalMirrorApplier`, `WorldReconciler` and the world / package repositories now consult the gate and skip applying empty/stale cloud snapshots while a merge is pending, so a partial sync race can no longer publish empty defaults that fan out to other devices.
- **`_saveToDb` merge-mode** — Repository save paths honour the gate too, shallow-merging cloud-derived rows onto local state during the merge window instead of overwriting.
- **`StartupSyncGate` reconciles before splash closes** — Already shipped in v9.1.0 for the worlds tab; v9.2.0 extends it to invalidate hub list providers after merge so a fresh sign-in lands on a populated hub without a manual refresh.
- **Migration 068 — beta quota actually at 100 MB** — `062_double_media_limits.sql` updated the wrong function (`get_beta_quota_bytes`) while every real caller reads `beta_user_quota_bytes()`, so the admin panel and storage checks were stuck at 50 MB. Migration 068 fixes `beta_user_quota_bytes()` to return 100 MB and drops the orphan function.

### Upgrade notes

- **App version bump:** `9.1.0` → `9.2.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **Cloud migration:** `068_fix_beta_quota_100mb.sql` — required to surface the correct 100 MB quota in the admin panel and storage checks. No data change beyond the function body.
- **No new Edge Function or Worker deploys** required for this release; v9.1.0's `beta_purge_with_cleanup` deploy is still the gate for full R2 + Supabase Storage cleanup on beta exit / admin revoke.
- **Stored map data** is forward-compatible: the JSON keys for `MapEra` / `EraWaypoint` / `LocationMapData` are new; old `MapEpoch` / `EpochWaypoint` worlds still load via the rename.

### Known issues

- Carry-over from v9.1.0: full WYSIWYG custom-content editors still deferred; remaining SRD effect gaps (Drow 120 ft superior darkvision, Tier-4 combat-tracker-dependent effects); D7 Drift v12 round-trip test harness pending.
- `imagePerEra` field type is only wired into the location entity schema; custom packages cannot yet declare their own per-era image fields through the JSON editor.

---

## Dungeon Master Tool v9.1.0 — Cross-Device Sync Hardening, Storage Cleanup, Map Persistence (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.1.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release focused on cross-device reliability and storage hygiene on top of v9.0.0. Online worlds opened from a second device now populate Session, Mind Map and World Map tabs correctly; empty-state clobbers during the initial sync race no longer wipe cloud state; world map data persists across reopens via granular Drift mirrors; beta exit and admin revoke now fully purge Cloudflare R2 and all Supabase Storage buckets, not just DB rows.

### Highlights

#### Cross-device sync

- **Tabs no longer empty on second-device open** — Cloud settings blob was being stuffed under `data['settings']` while screens read top-level keys (`combat_state`, `mind_maps`, `map_view`, …). `_applySettingsRow` / `_applyWorldsEvent` now spread cloud subkeys to top-level with a blocklist for granular-table owners (entities/sessions/map_data) and identity fields. Pending-write merges are preserved subkey-by-subkey.
- **Screens re-initialise after cloud arrives** — `MindMapScreen` gained a `_consumedRealData` flag and `WorldMapNotifier` exposes `hasContent`. If first init happened against an empty Drift snapshot and the user has not edited yet, a revision bump now triggers re-init; user edits or real data still block clobber. `applyInitialState` early-return widened to also continue when only `mapData`/`sessions`/`settings` are populated.
- **Empty-state clobber guard** — A cross-device open used to surface empty defaults before cloud sync, and the first auto-save would write that empty state back to the cloud and fan it out. Three gates added: (1) `combatProvider._loaded` now requires either real `combat_state` or a `worldInitialSyncSettledProvider` signal so `session_screen`'s auto-create-encounter cannot publish a phantom "Encounter 1"; (2) `WorldMapNotifier.syncToCampaignData` only writes when init had real data or the user added content; (3) `MindMapScreen.deactivate` skips save when init was empty and the notifier is still empty.
- **Worlds tab populates on startup** — `StartupSyncGate` now runs `worldReconciler.reconcile()` after beta/auth ready and invalidates the three hub list providers (worlds, packages, characters) before the splash closes, so sign-in / cache-wipe / new-device opens no longer require a manual hub refresh. Stays inside the 8 s startup ceiling.

#### Storage & persistence

- **World map + sessions persist locally** — `world_map_data` and `world_sessions` have had Drift tables for a while but the campaign load path was only reading the `settings_json` dual-write, so a force-close or partial sync could lose the battle map image. `CampaignRepository` now exposes `saveMapData`, `saveSessions`, `saveSession`, `deleteSession` against the typed DAOs; `_loadFromDb` overlays the typed rows on top of `settings_json` (granular = source of truth); cloud appliers (`_applyMapDataRow`, `_applySessionEvent`, `_applySessionsList`) write through to disk too.
- **Full R2 + Supabase Storage cleanup on beta exit & admin revoke** — Previously the admin "Revoke" button only called `admin_revoke_beta`, leaving Supabase Storage (`campaign-backups`, `free-media`, `shared-payloads`) and Cloudflare R2 (`{userId}/`, `transient/{userId}/`) orphaned. Self-exit cleaned Supabase Storage but couldn't touch R2 from the client. Three-tier fix: (1) new Cloudflare Worker endpoint `POST /admin/purge-user` does cursor-paginated list + batch delete of both prefixes behind `ADMIN_TOKEN`; (2) new Supabase Edge Function `beta_purge_with_cleanup` orchestrates everything — verifies caller JWT, picks self-exit vs. admin-gate path, runs the corresponding RPC, sweeps the three Storage buckets with the service role, then calls the Worker; (3) Flutter `admin_beta_requests_remote_ds.revoke` and `beta_provider.leaveBeta` route through the Edge Function, with a legacy fallback on self-exit when the function is not deployed.

### Upgrade notes

- **App version bump:** `9.0.0` → `9.1.0`.
- **Local DB:** schema v12, unchanged.
- **No new SQL migrations.**
- **Deploy required for full beta-exit cleanup:** `wrangler deploy` (Worker) + `supabase functions deploy beta_purge_with_cleanup`. Edge Function secrets `R2_WORKER_URL` and `R2_ADMIN_TOKEN` must match the Worker's `ADMIN_TOKEN`. Without the deploy, self-exit still works via the legacy fallback but leaves R2 objects behind.

### Known issues

- Carry-over from v9.0.0: full WYSIWYG custom-content editors still deferred; remaining SRD effect gaps (Drow 120 ft superior darkvision, Tier-4 combat-tracker-dependent effects); D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v9.0.0 — Online Play, Second Screen, Free Session Media, Admin-Gated Beta (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.0.0) · [elymsyr.github.io](https://elymsyr.github.io/)

The biggest release since v8.0. The closed beta now powers full online play: every character of a beta member becomes online, worlds and packages can be published, and **only the DM needs a beta slot** for the whole table to play together. The DM second screen is live for all connected players (entity cards, world map, battle map, images) and players can now mark up the projected battle map. Cloud media is split into free vs. counted kinds and a shared transient pool means images and battle maps shared in a live session no longer count against your save quota. Beta enrolment moved to admin-reviewed requests with a slot cap of 90.

### Highlights

#### Online play (experimental)

- **All-characters-online on beta join** — Joining the beta auto-mirrors every character you own to your cloud account and unlocks "Publish online" on worlds and packages. Leaving the beta hydrates the rows back into local-only storage instead of dropping them, so a beta exit no longer destroys work (migration 057 + 064).
- **DM-only beta requirement** — Only the DM has to be a beta member. Players connect, claim characters, see live updates, and use the projected second screen without their own beta slot.
- **DM-driven second screen for every player** — The DM's projection output (entity cards, images, world map, battle map) replicates to every connected player's client. A per-world manifest stores the active view so a late-joining or reconnecting player catches up instantly. Player tab gained a "second screen" view that mirrors what the DM is projecting (migrations 059, 061, 062).
- **Player marks on battle map** — Players can now place rulers, circles and free strokes on the DM-projected battle map (battlemap_marks_protocol). Marks stream through CDC with optimistic ghost + 50 ms debounce.
- **Row-level online sync, F1–F12** — Outbox + change-bus + per-row CDC apply replaces the legacy blob mirror for worlds, characters, packages and projection state. Schema versioning, reference graph, LRU sweeper, prefetch/prewarm, fog externalisation, raw-path migrator and telemetry shipped together.
- **Shared real-time visibility** — World members see each other's character changes live; member CDC + character CDC use granular notifiers; MembersStrip surfaces who's online on the player tab.

#### Media & storage

- **Free vs. counted media** — Character portraits and world/package cover art now sync free of your beta quota. Entity images and battle map media count against it, with per-kind size limits and a separate counted-asset bucket (migrations 053, 058, 060).
- **Free session-media pool** — Images and battle maps shared during a live online session use a shared transient pool (100 MB/user, 10 GB global LRU). Sharing live content with players no longer eats into your personal cloud save (migration 065 + worker evict-sweep + admin-purge).
- **Doubled cloud media limits** for paid kinds (migration 062).
- **Marketplace cover updates** — Cover images on marketplace listings are now mutable and re-encoded with a dedicated cover-sync service (migration 056).
- **Cloud media cleanup on delete** — Deleting a character, world or package now sweeps the associated cloud images server-side (`EntityMediaCleanupService`); local cache is preserved.

#### Beta program

- **Admin-reviewed beta requests** — Beta enrolment is now a request → admin review → approve/reject flow with a "Beta Requests" admin tab. Slot cap raised to 90 (migrations 063, 066, 067).
- **Hard reset path** — Mass beta wipe is available to admins for emergency resets (migration 064).
- **Beta exit preserves your data** — `BetaExitPreserveService` hydrates owned worlds, orphan characters and personal packages into offline-only storage on leave, with CDC purge guards and a summary dialog of what stayed local vs. what was uploaded.

#### Characters & SRD

- **"~3 HP at level 1" bug fix** — Wizard wrote HP to `combat_stats` while editor/rest/level-up paths read top-level fields, so newly-created characters showed 0/0 and the first level-up landed them in the 3–6 band. HP now uses `combat_stats.{hp,max_hp}` as the single source of truth via `_readHp`/`_writeHp` helpers; level-up, short rest, long rest and damage flows are all aligned.
- **Locked HP, new Extra HP field** — `combat_stats.hp` / `combat_stats.max_hp` are now read-only in the character editor (mid-session damage/heal still goes through the combat tracker and rest buttons). A new top-level **Extra HP** field above Death Save Successes accepts a signed value (`+5`, `-3`, `0`) and propagates the delta to `max_hp` + current HP atomically.
- **Subclass skill picks** — `bonus_skill_pick_count` / `bonus_expertise_pick_count` on subclasses now seed the wizard's pending-choice pipeline (e.g. College of Lore L3 → 3 skill picks at higher-level start). Subclass auto-grants are gated by parent class level, so a level-3 subclass selection no longer fires its L6 features.
- **Berserker Mindless Rage as a mechanical grant** — L6 Mindless Rage now grants both the narrative trait and the `Mindless Rage` feat so the resolver actually walks its effects; condition-immunity-while-raging surfaces in ResolvedGrantsCard instead of staying narrative-only.
- **Higher-level start gold (SRD §1 "Starting at Higher Levels")** — Wizard now auto-adds the SRD higher-level GP bundle when starting above L1 (L5–10 +500, L11–16 +5 000, L17+ +20 000, plus 1d10×25/L5+ avg-fixed) instead of leaving it as advisory-only text.
- **Template re-apply preserves combat_stats subfields** — `applyTemplateUpdate` now shallow-merges Map fields so re-running a template against an existing character doesn't wipe HP/AC sub-values back to defaults.

#### App-wide

- **Unified debounce + tier-1 perf wins** — 5-tier SyncTier classifier, batched package_sync upsert+delete, combat event log capped at 500, startup AppIconImage swap, CDC race guard.
- **Offline guard** — Network-backed screens (feed, marketplace, messages, profiles, game listings) render a single "You're offline" placeholder via the new `OfflineGuard` widget + `guardedNetwork` helper instead of infinite spinners. Auto-recovers on reconnect; outbox writes hold and flush.
- **Mobile responsiveness** — Keyboard relayout fixes (K1/K3/K4), mention input fix (M1/M2), single-axis image decode for portraits and `AssetRefImage`.
- **Workspace + map fixes** — Battle-map snapshot + snapshot builder reworked; mind-map node rebuilds reduced; world-map notifier streamlined.
- **Soundpad sidebar rebuilt** — Layout and theming overhaul (≈670 LoC churn).

### Upgrade notes

- **App version bump:** `8.4.0` → `9.0.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **Cloud migrations 053 → 067** — All required, in order. Run via `supabase/migrations/`.
- **Beta members re-enrolled via request flow** — Existing beta slots are preserved; new members go through the admin-reviewed request.
- **No user action required for offline players** — Players connecting to a DM's world don't need a beta slot.

### Known issues

- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision still needs resolver `sense_grant range_ft` wiring; Tier-4 combat-tracker-dependent effects (aura predicates, advantage/disadvantage grants, on-hit extra damage, condition writers, pool spending automation) remain unimplemented.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.
- **Online play is experimental** — Expect occasional desync; report cases via Settings → Report a bug.