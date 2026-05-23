# Release Notes

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
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.
- **Online play is experimental** — Expect occasional desync; report cases via Settings → Report a bug.