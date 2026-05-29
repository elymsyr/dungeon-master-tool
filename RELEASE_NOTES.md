# Release Notes

## Unreleased — Soundpack Marketplace

**No version bump.** Additive client feature on top of v9.5.0; no schema, migration, or dependency changes.

Adds a curated **Soundpack** catalog so users can download ready-made audio into the existing Soundpad instead of starting from empty asset folders. No user sharing yet — the catalog is a read-only list fetched from a manifest hosted in the GitHub repo, so new packs can be added without an app release.

### Highlights

- **Soundpacks marketplace item** — A new **Soundpacks** filter in the Marketplace tab and a "Download soundpacks" section in Settings → Soundpad both render the catalog. Each pack shows name, description, size, and a **Get → Downloading… → Installed** action.
- **Two pack kinds** — `theme` packs install as a self-contained theme folder (`theme.yaml` + audio) under the soundpad root and are auto-discovered by `loadAllThemes`; `library` packs download ambience/SFX audio and merge their entries into `soundpad_library.yaml`. Downloaded music themes, ambience, and SFX appear in the Soundpad sidebar immediately (theme/library providers are invalidated on install).
- **Catalog source** — Manifest at `soundpacks/manifest.json` in the repo lists each pack (`id`, `kind`, `name`, `baseUrl`, `files`, optional `entries`). The bundled launch catalog ships three music themes (Samurai, Medieval Meditation, Salute), four ambience packs (Rain, Crowd, Fireplace, Dungeon), and three SFX packs (Sword Slice, Arrow Swish, Door Creak).
- **Resilient fetch** — Downloads use the native `HttpClient` with a path-traversal guard and atomic `.tmp`→rename writes; a failed download rolls back its files. A missing manifest (404) shows an empty catalog rather than a false "you're offline" state, which is reserved for genuine network failures.

### Upgrade notes

- **No app version change**, no local DB migration, no new cloud migrations, no new dependencies.
- The soundpack catalog requires `soundpacks/manifest.json` to be present on the repo's default branch; the referenced audio already lives under `assets/soundpad/`.

### Known limitations

- No publishing/sharing of user soundpacks (curated catalog only).
- No in-catalog uninstall; remove installed themes from the Soundpad sidebar as before.

---

## Dungeon Master Tool v9.5.0 — Admin Broadcast Notifications, Involuntary Beta-Loss Data Guard, 14-Day Inactivity Window (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.5.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v9.4.0. Adds an admin-to-everyone broadcast notification system with interactive content, hardens the beta program against silent data loss when access is lost involuntarily, and doubles the beta inactivity grace period from 7 to 14 days.

### Highlights

#### Notifications

- **Admin broadcast notifications** — Admins compose a notification (title + ordered content blocks) from a new "Notifications" admin tab and publish it to every user. Three block types: `markdown` (rendered rich text), `poll` (single- or multi-select question), and `input` (free-text prompt, multiline by default). Backed by new `notifications`, `notification_responses`, and `notification_reads` tables (migration 069). Writes go only through `SECURITY DEFINER` RPCs; RLS lets every user read published notifications while clients cannot write directly.
- **Inbox + unread badge** — A notification icon button with an unread-count badge sits in the hub. Users open an inbox dialog to read notifications and answer polls / inputs inline; one response row per user per notification, upsert-on-edit. Read tracking drives the badge.
- **Admin response viewer** — Admins open a per-notification responses dialog to see aggregated poll tallies and individual free-text answers. `notifications` + `notification_responses` are added to the realtime publication so the inbox and the response viewer update live.

#### Beta program

- **Involuntary beta-loss data guard (`BetaLossGate`)** — When a user loses beta access *involuntarily* (server-side inactivity sweep or admin revoke) rather than via the voluntary exit flow, the server-side cascade DELETE events arriving over realtime (or replayed on cold start) would previously wipe the owner's offline Drift copy of their own worlds. A per-user sentinel now marks the involuntary-loss state and makes CDC DELETE appliers skip purge/trash for rows the user *owns* (`owner_id == uid`). Worlds the user merely plays in (non-owner) are still purged normally on membership removal. Set the instant a `wasActive && !nowActive` transition is detected; cleared on successful beta re-enter.
- **Inactivity window 7 → 14 days** — `beta_inactivity_days()` now returns 14 (migration 070). The single `CREATE OR REPLACE` flows through both the daily `sweep_inactive_beta()` purge cutoff and the client-facing `get_beta_status().inactivity_days`; sweep scope, cron, and RPCs are otherwise unchanged.

### Upgrade notes

- **App version bump:** `9.4.0` → `9.5.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **New cloud migrations:** `069_notifications.sql` (notification tables + RLS + RPCs + realtime publication) and `070_beta_inactivity_14d.sql` (inactivity threshold). Apply via Supabase Dashboard → SQL Editor before / alongside the client rollout.
- **Pure additive schema.** Existing tables and data are unaffected.

### Known issues

- Carry-over from v9.4.0: full WYSIWYG custom-content editors still deferred; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v9.4.0 — Thirteen New Themes, Google Fonts Per-Theme, Dynamic App Version, Heartbeat Service Refactor (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.4.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v9.3.0. Theme catalog nearly doubles: 13 new palettes ship alongside `google_fonts` integration so themes can pin their own typeface. `appVersion` is now resolved at runtime from the bundled pubspec via `package_info_plus`, so the admin heartbeat always reflects the real installed build instead of a hand-edited constant. Heartbeat itself moves out of `main.dart` into a dedicated service that pings on boot, on every `signedIn` / `tokenRefreshed` / `userUpdated` auth event, and on a 15-minute foreground timer (paused while backgrounded).

### Highlights

#### Theming

- **13 new theme palettes** — `obsidian` (volcanic glass, near-black slate + crimson edge), `sunset` (coral + amber on smoky plum), `nord` (arctic polar night + frost cyan), `rose` (cream pink + magenta pill chips, light theme), `neon` (cyberpunk hot magenta + cyan on near-black), `terminal` (green-on-black CRT), `scroll` (warm parchment + ink, light theme), `terra` (earthy clay), `goldenrod` (heraldic gold + ivory), `jade` (deep jade + bone), `vapor` (synthwave purple/pink), `mono` (pure greyscale), `carmine` (oxblood + cream). Brings the in-app palette picker count from 11 to 24.
- **Google Fonts per theme (`fontFamily`)** — `DmToolColors` gains an optional `fontFamily` field. When set, the theme builder resolves the family via `google_fonts` instead of falling back to the binary `useSerif` toggle, so palettes can ship distinct typefaces (e.g. monospace for `terminal` / `mono`, condensed serif for `scroll`).

#### Admin telemetry

- **Dynamic `appVersion` via `package_info_plus`** — `appVersion` was a hand-edited `const String` in `constants.dart`; every release required a code edit just to keep the admin panel honest. New `initAppVersion()` resolves the bundled pubspec version (Android/iOS/desktop) or the web build's `info.json` and overwrites the fallback before Supabase init, so `user_heartbeat` RPC carries the real installed build on the first ping.
- **`HeartbeatService` refactor** — Old inline `user_heartbeat` RPC in `_initSupabase()` only fired once at boot, missed late sign-ins, and would have paged the radio on backgrounded mobile sessions. New singleton `HeartbeatService` (instance API: `start()` / `stop()` / `send()`) subscribes to the Supabase auth stream and re-pings on `signedIn` / `tokenRefreshed` / `userUpdated`, runs a 15-min foreground timer via `WidgetsBinding` lifecycle observer, and cancels the timer when the app is paused/inactive so it doesn't wake the network for an idle heartbeat. `profiles.last_active_at` / `app_version` / `platform` stay populated across long sessions, late auth, and token refresh boundaries.

### Upgrade notes

- **App version bump:** `9.3.0` → `9.4.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **No new cloud migrations.** Pure client-side theme + telemetry work.
- **New runtime deps:** `google_fonts: ^6.2.1`, `package_info_plus: ^8.0.2`. `flutter pub get` required after upgrade.
- **`appVersion` is no longer `const`** — Code that imported it expecting a compile-time constant must treat it as a mutable `String` populated by `initAppVersion()` during bootstrap.

### Known issues

- Carry-over from v9.3.0: full WYSIWYG custom-content editors still deferred; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.
- Google Fonts at runtime fetch on first use when a system copy is not bundled; first launch on a fresh install may briefly render the fallback family before the network resolve completes.

---

## Dungeon Master Tool v9.3.0 — Class Tool Proficiencies, Weapon Mastery Picker Fix, Silent Auto-Grant Resolver Bugs, Drow 120 ft Darkvision, Formula-Driven Resource Pools (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.3.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v9.2.0. SRD 5.2.1 class tool proficiencies are finally wired through (Bard / Druid / Monk / Rogue), and three character-creation resolvers — Weapon Mastery, Extra Attack, resource pool grants (Rage, Bardic Inspiration, Ki, …) — get a silent-failure fix that had been hiding **all** auto-granted class effects on built-in SRD content. The two remaining SRD effect gaps close in this release as well: Drow Superior Darkvision now actually overrides the base 60 ft to 120 ft, and `count_formula` resource pool grants (Paladin Lay on Hands, Monk Ki, Cleric Channel Divinity, …) are evaluated end-to-end. Net effect: Barbarian / Fighter / Paladin / Ranger / Rogue L1 now show the Weapon Mastery picker, Fighter L5 shows the correct extra-attack count, Rage / Bardic Inspiration / Ki / Lay on Hands / Channel Divinity uses populate on the PC card with the right per-level max, and Drow PCs render with 120 ft darkvision.

### Highlights

#### Characters & SRD

- **Class tool proficiencies (SRD §1.5)** — Four classes finally pick up the tool proficiencies the SRD grants them. Bard L1 picker offers all musical instruments (cap 3), Monk L1 picker offers artisan's tools + musical instruments (cap 1), Druid L1 auto-grants Herbalism Kit, Rogue L1 auto-grants Thieves' Tools. Wizard step already had the picker UI; the data side was empty on every class until now. Resolver `Pass 8` extended to walk class-side `granted_tool_refs` (previously background-only). Wizard `buildSeedFields()` extended to seed class granted tools so the PC entity's `tool_proficiencies` list opens populated.
- **Weapon Mastery picker now appears for Barbarian / Fighter / Paladin / Ranger / Rogue at L1** — Two layered bugs were hiding the picker. (1) `_passesMasteryFilter` in [proficiencies_step.dart](flutter_app/lib/presentation/screens/characters/wizard/steps/proficiencies_step.dart) only handled Map-shape `category_ref`; the SRD pack-build's `_resolveRefs` rewrites `{_ref, name}` placeholders to String UUIDs before the resolver ever sees them, so every weapon failed the filter → `masteryWeaponIds` was empty → picker hidden. Filter now accepts either shape. (2) Even with the filter fixed, `masteryCap` was still 0 because the resolver's `_isAutoGranted` check matched only Map-shape `source_ref` — same shape mismatch, same silent failure.
- **Silent auto-grant resolver bug fixed across 3 resolvers** — `weapon_mastery_resolver`, `extra_attack_resolver`, and `resource_pool_resolver` all carried the same Map-only `source_ref` check, so every class auto-grant on built-in SRD content was invisible. The pack-build's two-pass `_resolveRefs` pipeline turns `{_ref, name}` placeholders into String UUIDs; resolvers now look up entities by UUID in addition to the legacy Map form. Side-effect fixes: Fighter L5 / L11 / L20 Extra Attack count now resolves to 2 / 3 / 4 as it should, and resource pools (Rage uses, Bardic Inspiration, Channel Divinity, Ki / Focus Points, Wild Shape, Lay on Hands, …) populate on the PC card at the right levels instead of staying blank until manual edit.
- **Drow Superior Darkvision (120 ft) now applies** — `_modifierAsEffect()` in [character_resolver.dart](flutter_app/lib/domain/services/character_resolver.dart) only forwarded a small whitelist of `granted_modifiers` kinds to `applyEffect`; `sense_grant` (plus `truesight_grant`, `blindsight_grant`, `condition_immunity_grant`, and the three `damage_*_grant` kinds) fell through to default and were silently dropped. Drow's subspecies modifier (`sense_grant` with `range_ft: 120`) now reaches the resolver's existing max-wins range logic, so Drow PCs render with 120 ft darkvision instead of the base 60 ft.
- **`count_formula` resource pool grants are now evaluated** — Paladin Lay on Hands (`paladin_level_x5`), Monk Ki / Focus Points (`monk_level`), Cleric Channel Divinity (`cha_mod_min_1`), and any other pool with a formula instead of a literal `count` / scaling table now resolve to the correct max in the level-up plan and on the PC card. The token evaluator (`paladin_level_x5`, `cha_mod_min_1`, `pb`, …) was already complete in `CharacterResolver` for full character resolution but the planner-side `resource_pool_resolver` intentionally skipped it for lack of context. Extracted the evaluator to a shared `count_formula.dart`, threaded `abilities` + `classLevels` through `planLevelUp` from the character editor and wizard, and per-side `classLevels` snapshots so prev/new deltas are correct (e.g. Paladin 4 → 5 shows Lay on Hands 20 → 25).

### Upgrade notes

- **App version bump:** `9.2.0` → `9.3.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **No new cloud migrations.** Pure client-side data + resolver fixes.
- **Existing characters are unaffected** until they are re-resolved (level-up, edit, re-open). The tool proficiency picker only fires on character creation; existing PCs without the granted tools can add them manually via the editor.

### Known issues

- Carry-over from v9.2.0: full WYSIWYG custom-content editors still deferred; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

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