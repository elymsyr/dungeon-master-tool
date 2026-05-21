# Release Notes

## Dungeon Master Tool v8.3.1 — SRD Armor Mechanics, Derived Combat Stats, Per-World DB Filters (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v8.3.1) · [elymsyr.github.io](https://elymsyr.github.io/)

A maintenance release on top of v8.3.0. The character editor now resolves armor consequences from the SRD 5.2.1 rules instead of leaving them to the DM, the combat-stats grid shows live derived values for level and AC, and the database sidebar remembers its filters per world. Several bugs around equipped armor, image decoding, and shared-entity sync are fixed. No database or cloud migrations.

### Highlights

- **SRD armor consequences** — The character resolver now derives the rule consequences of worn armor: an untrained-armor penalty (Disadvantage on STR/DEX D20 Tests + no spellcasting), a Speed −10 ft cut when STR is below the armor's requirement, and Stealth disadvantage. `EffectiveCharacter` carries a new `armorNotes` list and the combat-stats field renders them as an amber warning banner above the grid.
- **Derived combat stats** — The `combat_stats` grid's **Level** and **AC** cells are now read-only and track live derived values — root `level` (kept current by level-up) and resolver-computed armor class (equipped armor + Dex + shield) — instead of stale manually-stored entries. Monsters/NPCs with no root level or resolver AC keep the editable stored value.
- **One suit + one shield** — Equipping a piece of armor now auto-unequips any other equipped armor in the same slot (body / shield), enforcing the SRD "one suit of armor and one shield at a time" rule.
- **Equipped-armor detection fix** — `_equippedArmor` / `_hasEquippedShield` resolved the wrong field (`armor_category_ref`) and could pick up non-armor rows. They now read `category_ref` and require `categorySlug == 'armor'`, so AC, shield bonus, and armor-training checks resolve correctly.
- **Live AC on the stat-chip strip** — The character header's AC chip resolves off the live working copy, so equipping armor refreshes it immediately instead of lagging behind the persisted character.
- **Magic-item text corrections** — Weapon +1, Armor +1/+2/+3, and Shield +1 effect text rewritten to the SRD 5.2.1 wording. Armor +2 rarity corrected Rare → Very Rare and Armor +3 Very Rare → Legendary.
- **Version-aware SRD pack re-seed** — `SrdCorePackageBootstrap` now re-seeds the built-in pack whenever the code's `pack_version` differs from the stored copy, so content fixes land without a manual reinstall. SRD core pack bumped `1.0.0` → `1.0.1`.
- **Standard Array swap** — Picking an array value already held by another ability now swaps the two abilities instead of disabling the option, so the array always stays a valid permutation (no duplicate, none dropped). Every value stays selectable.
- **Manual ability-score focus fix** — The manual ability-score field uses a stable widget key so typing no longer rebuilds the field and drops keyboard focus.
- **Per-world database filters** — The database sidebar's category, source, share-mode, and sort selections are now persisted per world instead of in one global list, so filters no longer leak across worlds and survive exit/re-entry. (The legacy global filter resets once on upgrade.)
- **Sidebar filter jank fix** — The filter/sort cache key switched from an identity hash of the shared-entity set to a value-based hash, so a keyboard relayout no longer forces a full ~7 K-entity filter+sort re-run.
- **Single-axis image decode** — Character portraits and `AssetRefImage` now decode on one axis only. Passing both `cacheWidth` and `cacheHeight` made `ResizeImage` stretch the bitmap to those exact dimensions, distorting the image before `BoxFit` could crop it.
- **Shared-entity sync catch-up** — `applyInitialState` now invalidates the world entity-shares cache on reconnect / world re-entry. `entity_shares` CDC isn't replayed across a disconnect, so shares made while offline were filtered out by a stale list and the card never opened.
- **Minor UI fixes** — The "Character not found" screen gained a back button; the editor's Edit/View toggle icon was swapped to match its action; armor `base_ac` minimum lowered 10 → 0 so the Shield row (base_ac 2) is accepted in the content editor.

### Upgrade notes

- **App version bump:** `8.3.0` → `8.3.1`.
- **SRD core pack:** `1.0.0` → `1.0.1` — re-seeds automatically on first launch; no manual reinstall.
- **Local DB:** schema v12, unchanged. No migration.
- **Cloud migrations:** none.
- **No user action required.**

### Known issues

- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Row-level save+sync** — F0 (repo API) shipped in v8.0; F1–F6 (per-row outbox, change-bus apply, CDC row-merge) still pending.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.

## Dungeon Master Tool v8.3.0 — Graceful Offline, CDC Event Batching, entity_shares Un-Share Fix (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v8.3.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Follow-up to v8.2 focused on offline behavior, realtime correctness, and long-session memory. Network-backed screens now collapse a dropped connection into a single clean "You're offline" placeholder instead of infinite spinners or scattered errors, and recover on their own when connectivity returns. Realtime CDC events are now coalesced into short batches so a multi-player event flood no longer triggers a rebuild storm, and un-sharing an entity finally reaches player clients (the DELETE event was being silently dropped). Several unbounded caches gained ceilings so long sessions stay within a predictable memory budget.

> **Heads-up — one new Supabase migration.** `052_entity_shares_replica_full.sql` sets `REPLICA IDENTITY FULL` on `entity_shares`. It is metadata-only — no data change — but it must be applied for un-share to propagate to players.

### Highlights

- **Graceful offline** — New `OfflineGuard` widget wraps network-dependent subtrees and renders a single `ConnectionErrorView` ("You're offline" + Retry) when the device is offline, so inner network providers never mount, fire, or spin. Auto-recovers: connectivity returns → the subtree remounts and refetches.
- **`guardedNetwork` pre-check** — Network fetches across feed, marketplace, messages, profiles, suggested users, and game listings now route through `guardedNetwork`, which throws `OfflineException` immediately when offline and applies a 12s hard timeout so a provider never hangs on an infinite spinner (the "connectivity reports up but no real internet" case).
- **Wider offline-error detection** — `isOfflineError` now recognizes `OfflineException`, Supabase `AuthRetryableFetchException`, and additional message signatures (`failed to fetch`, `socketexception`, `connection timed out`, `xmlhttprequest`) so web and auth-layer failures collapse into the same clean message.
- **SyncEngine skips offline ticks** — `_tick()` bails when offline; outbox rows stay in SQLite and the offline→online listener re-triggers the drain on reconnect. Offline push failures log a one-line `↻ retry queued` breadcrumb instead of a full stack trace.
- **Offline log breadcrumbs** — `WorldMirrorService`, the `am_i_banned` auth check, and the GitHub release check now downgrade offline failures to a single `skipped: offline` line; real errors still print in full.
- **CDC event batching — rebuild-storm fix** — `WorldMirrorApplier` now feeds CDC events through an `_EventBatcher` (16ms window). Idempotent row events are coalesced per primary key (last write wins), the batch applies sequentially over the shared `data` map, and a single `_bumpRevision()` fires at the window close instead of one per event. A multi-player event flood no longer spams rebuilds.
- **entity_shares un-share fix** — Migration 052 sets `REPLICA IDENTITY FULL` on `entity_shares`. The default identity only carries PK columns in DELETE payloads, so the realtime `world_id` filter never matched an un-share and the event was dropped — players kept seeing un-shared cards. (Same class of bug migration 051 fixed for `world_members`.)
- **Shared-entity fetch injection** — When a DM shares an entity, the `world_entities` row itself doesn't change, so no CDC fires for it. The applier now explicitly fetches the newly shared entity via `WorldMirrorService.fetchEntity` and injects it into the local blob, so the card actually appears on the player client.
- **Realtime channel cap** — `WorldSyncService` caps concurrent CDC channels at 6, evicting the oldest on overflow — a defensive net against channel leaks while world-hopping in a long session.
- **Bounded caches** — `ImageCache` is now explicitly capped (128MB / 1500 entries); the mind-map painter clears its label/arrow/dashed-rect caches past 600 entries; the world-map timeline painter caps its per-color `Paint` cache at 256. Long sessions stay within a predictable memory budget.
- **Main-shell rebuild trim** — `MainScreen` switched its keep-alive watches (`worldMirrorApplier`, `activeCampaignSync`, projection sync providers) to `.select((_) => 0)` and resolves `role` via `.select`, so provider resolve/emit churn no longer rebuilds the whole shell.
- **Characters tab selection perf** — Hub Characters tab selection moved to a `ValueNotifier`; picking a row now rebuilds only the affected row + action panel via `ValueListenableBuilder` instead of the whole tab (matters at 100+ characters). Stat-chip work is hoisted out of the per-selection builder.
- **Profile load waterfall removed** — `ProfileScreen` pre-warms the default Posts tab data in parallel with the profile fetch, killing the double-spinner waterfall.
- **Touch scroll fix** — Markdown bodies (reference lists, entity markdown areas, the version-indicator changelog) disable text selection on Android/iOS, where the selection gesture swallowed vertical drag and blocked the parent scroll view.
- **Player role gating** — The entity-card "cast to player screen" button and the entity-sidebar "Create" button are now hidden for the player role (still available to DMs and offline/local use). Phone entity cards force a single column — multi-column layouts overflowed in edit mode on narrow widths.
- **World character open gate** — In the world characters view, only owners (own card), the DM (any card), and unclaimed rows (read-only) can open a character; rows claimed by another player are no longer tappable.

### Upgrade notes

- **App version bump:** `8.2.0` → `8.3.0`.
- **Local DB:** schema v12, unchanged. No migration.
- **Cloud migrations:** `052_entity_shares_replica_full.sql` — `ALTER TABLE entity_shares REPLICA IDENTITY FULL`, metadata-only, no data change. Apply it so un-share DELETE events reach players.
- **No user action required** beyond applying the migration on the cloud side.

### Known issues

- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Row-level save+sync** — F0 (repo API) shipped in v8.0; F1–F6 (per-row outbox, change-bus apply, CDC row-merge) still pending.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.