# Release Notes

## Dungeon Master Tool v8.4.0 — Online Second Screen, Free vs. Counted Cloud Media, Beta-Leave Purge (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v8.4.0) · [elymsyr.github.io](https://elymsyr.github.io/)

A feature release on top of v8.3.1. Online worlds gain a second screen: the DM projects entity cards, images, the world map, and the battle map to every remote player's client, not just a local window. Cloud media is split into *free* (uncounted) and *counted* tiers so portraits and covers no longer eat your storage quota, with per-kind size limits, a per-entity image cap, online count limits, and transient sharing when storage is full. Leaving the beta now purges all of your online data, two storage-security holes are closed, and the standalone Media Gallery is retired. Eight cloud migrations (053–060) and a Cloudflare Worker redeploy are required.

### Highlights

#### Online second screen

- **Project to remote players** — The DM can broadcast the active projection (entity card, image, world map, or battle map) to every connected client in an online world, not just a local second window. A new `world_projection` manifest table holds one row per world (`state_json` = `ProjectionState`) and replicates "what's on screen" via change-data-capture, so a late-joining or reconnecting player catches up the moment they subscribe.
- **Player Second Screen tab** — The player tab now renders whatever the DM is projecting and shows a "Waiting for DM" placeholder when nothing is shared.
- **Multi-output fan-out** — One `ProjectionController` drives a local second window and remote players at the same time; a DM-only online broadcast toggle in the projection panel turns the online output on or off.
- **AssetRef image bridge** — Projection views (image, entity card, battle map) resolve images through `AssetRef` instead of raw file paths, so remote players can fetch counted (R2), free (Supabase), or transient images. This also fixes character portraits showing broken on a second device.
- **World map projection** — The world map's active-epoch background can be projected; the map provider eagerly uploads the image so remote players resolve it.

#### Cloud media storage redesign

- **Free vs. counted media** — Character portraits and world/package cover images now upload to a public Supabase `free-media` bucket and **do not count** against your cloud storage quota. Entity images, battle maps, and mind-map images stay *counted* media in Cloudflare R2.
- **Per-kind size limits** — Each media kind has its own ceiling — 2 MB for portraits, covers, and entity images; 5 MB for battle maps — enforced by the Cloudflare Worker through a new `X-Asset-Kind` header.
- **Per-entity image cap** — Up to 5 images per entity, applied to both the portrait gallery and each schema-defined image field.
- **Online count limits** — 10 online characters per user, 10 online worlds per user, 10 characters per world, and 10 online packages per user, enforced server-side via triggers and publish RPCs.
- **Transient sharing** — When your cloud storage is full, projecting or sharing an image still works: the image is written to a short-lived `transient/` R2 path that skips the quota and is auto-deleted by an R2 lifecycle rule. Players who already have the image cached (matched by SHA-256) transfer nothing.
- **Quota-aware feedback** — New messages when the quota is full, an image exceeds its size limit, or an entity hits the image cap; the image is kept on the device but not backed up to the cloud.
- **Media Gallery retired** — The standalone Media Gallery dialog is removed. Media now lives directly on entities and projections.
- **Entity media cleanup** — Deleting a character, world, or package now removes its cloud images automatically; the local cache is kept.

#### Marketplace cover refresh

- **Refreshable listing covers** — When a published item's cover or portrait changes, its marketplace banner now updates without re-publishing. The downloadable content snapshot stays frozen — `content_hash` and `payload_path` are unchanged — and only the inline `cover_image_b64` banner is mutable, refreshed through the owner-scoped `update_listing_cover` RPC.
- **Delete warnings** — Deleting a world, package, or character that still has marketplace listings now warns that those listings will be permanently removed.

#### Beta-leave full purge

- **`leave_beta` purges all online data** — Leaving the beta now deletes every piece of your online content: online worlds, personal packages, and characters; marketplace listings and their images; free-media images and transient shares. (Worlds, cloud backups, and community assets were already covered in v8.3.)
- **Beta-gated publishing** — Publishing marketplace listings and personal packages is now locked behind active beta membership, with hardened row-level security on `marketplace_listings`, `personal_packages`, and orphan `world_characters` inserts.
- **Community untouched** — Posts, game listings, conversations, messages, profiles, and follows are deliberately left intact, so leaving the beta keeps your community presence. The leave-beta confirmation copy now spells out exactly what is deleted versus kept.

#### Security & access fixes

- **Owner-scoped bucket listing** — The public image buckets (`free-media`, `avatars`, `post-images`) had bucket-wide SELECT policies that let any authenticated client enumerate every object and harvest uploader UUIDs. SELECT is now scoped to the caller's own folder. Image display is unaffected — file contents are still served RLS-free through the public URL endpoint.
- **Shared-world asset access** — Counted R2 images on shared or projected entity cards returned 403 for players because access was uploader-only. `get_asset_access` now also grants access when the requester and the uploader share a world, matching transient access.
- **Worker transient access** — The Cloudflare Worker validates `transient/` downloads against shared-world membership and enforces the per-kind upload limits.

### Upgrade notes

- **App version bump:** `8.3.1` → `8.4.0`.
- **SRD core pack:** `1.0.1`, unchanged. No re-seed.
- **Local DB:** schema v12, unchanged. No migration.
- **Cloud migrations:** **8 new — `053`–`060`.** Apply them in order via the Supabase SQL editor:
  - `053_free_media_bucket` — `free-media` bucket + `free_media_assets` table.
  - `054_transient_share` — `transient_shares` table + `get_transient_access`.
  - `055_online_count_limits` — per-user / per-world count limits.
  - `056_marketplace_cover_mutable` — refreshable listing covers.
  - `057_leave_beta_full_purge` — full online-data purge + beta gating.
  - `058_storage_select_owner_scoped` — owner-scoped bucket SELECT.
  - `059_online_projection_manifest` — `world_projection` manifest table.
  - `060_asset_access_shared_world` — shared-world counted-asset access.
- **Cloudflare Worker:** redeploy required — adds transient access checks, the `X-Asset-Kind` header, and per-kind upload limits.
- **R2 lifecycle:** add a lifecycle rule that auto-deletes objects under the `transient/` prefix.
- Until the migrations and Worker are deployed, clients graceful-degrade: media stays local instead of syncing to the cloud.

### Known issues

- **Battle map collaboration (second screen Phase D–F)** — Player drawing (rulers, circles, free draw) and turn-gated token movement on the projected battle map are still pending; players currently see the battle map read-only.
- **Media redesign client tails** — Gallery-side and a few transient/count pre-check client paths (Phase 5, 6-client, 7-client) are still in progress.
- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Remaining SRD effect gaps** — Drow 120 ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.

---

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