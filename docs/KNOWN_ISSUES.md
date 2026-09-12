# Known Issues

Living list of what is deferred, broken-on-purpose, or a real bug still being tracked.
**This file is the source of truth** — the `### Known issues` section of each release note
in [RELEASE_NOTES.md](RELEASE_NOTES.md) is filled in from here at release time (copy the
items that are still open on the release date; do not edit past releases afterwards).

**Last reviewed:** September 2026 (v15.10.0)

---

## Open

- **59 tests fail on `main`** — As of v15.10.0 `flutter test` reports 1424 passing and 59
  failing. None of them are caused by the version bump; they are fallout from the content
  and schema changes in v15.10.0 that the tests were not updated for:
  `combat_provider_test` (42), `account_gate_test` (6), `srd_core/species_test` (5),
  `default_schema_test` (3, expects 19 categories but the schema now generates 18),
  `content_store_test` (2) and `guest_promotion_service_test` (1). `flutter analyze` is
  clean apart from 27 pre-existing info-level lints.

## Resolved

- **Deleted marketplace listings left their images in R2** — Fixed: the release chain is
  complete end to end. The owner's delete calls `pub_asset_release(listingId)` right after
  `delete_listing` (`marketplace_listings_remote_ds.dart`, `marketplace_listing_provider.dart`);
  dropping the last row in `pub_asset_refs` fires `trg_drop_orphan_pub_asset` (migration 089),
  which queues `pub/{sha}{ext}` into `transient_evict_queue`; the worker's hourly cron
  (`wrangler.toml` `crons`) runs `sweepEvictQueue` and deletes the object from R2. Objects are
  content-addressed and shared, so a sha another listing still references is left alone, and a
  direct `DELETE pub/...` is refused (`pinned_delete_forbidden`) — refcount alone decides.
  Moderator deletes were the remaining leak and migration 091 closed it: `pub_asset_release`
  filters on `auth.uid()`, so `admin_delete_marketplace_listing` now drops the refs directly.
  Residual: the owner-side release is best-effort (its failure is caught and logged), so a
  network error there can still strand one listing's media in the pool.

- **Third-party feature cards are narrative, by design** — The 559 class/subclass feature
  cards minted from the bundled Open5e packs (519 subclass, 40 class, across 100 subclasses)
  carry the upstream prose in `benefits` and no typed mechanic, so nothing is rolled, granted
  or counted automatically: a feature that reads "you gain darkvision out to 60 feet" prints
  that sentence but does not touch the senses list. Deliberate — deriving a `granted_senses`
  or a `resource_pool_grants` from free text would silently produce wrong grants, which is
  worse than a sentence the player applies themselves. Typing the few high-frequency
  one-liners (languages, darkvision, swim speed) is the upgrade path if it ever earns itself.
  "Path of Hellfire" is the one subclass with no features at all: it ships none upstream, so
  there is not even prose to show.

- **The SRD Barbarian class card had no artwork** — Fixed: the missing
  `eb131956-8e5f-5be1-ab00-a0ea8b3db774.webp` was generated from its existing `art_jobs.jsonl`
  job (`generate.py --types class`) and encoded into the bundle with `bundle_srd_art.py`.
  `dnd5e-srd` now has all 1259 `dmt-art://` refs backed by a file in `assets/art/srd/`. No R2
  re-upload needed — SRD art ships in the app bundle, not in a catalog art zip.

- **Downloaded card art was never cleaned up** — Fixed: deleting a package (or a world whose
  packages have no other home) now runs `FirstPartyArtService.sweepUnreferenced`, which drops
  every file under `cacheDir/art/` that nothing live still points at (`image_path` in
  `package_entities` / `world_entities`, plus `trash_items` and `world_characters`
  payloads — deletion is a 30-day soft delete, so a trashed package's art has to survive
  until "Undo" is gone). A package's art bundle is ~50 MB, so the leak was the
  whole install. No refcount table: one scan per delete, which also clears garbage left by
  earlier versions. Deleted files are not lost — a reinstall re-extracts the zip and bundled
  SRD art is re-copied on first render.

- **`creature-action.uses_per_day` has no counter** — Not a bug, by design: the field is
  visible and editable as "Uses / Day" on the action card, it just has no automatic tracker.
  Per-use tracking belongs to `resource_pool_grants` on a trait or feat card, which renders a
  real counter on the sheet; on a creature action the player tracks the limit themselves.

- **Open5e art bundles in R2 were stale** — Fixed: the card-art refs that `b664fe83` dropped
  from the 19 Open5e packs are restored (guarded by `test/tool/pack_art_refs_test.dart`), and
  all 21 `catalog/art-bundle/{slug}@{ver}.zip` objects were rebuilt at the current pack
  versions and re-uploaded. Building and uploading them is no longer a separate manual step:
  `publish_catalog.dart` runs `pack_art_bundles.py` itself before the manifest goes up.
- **Most third-party subclasses granted nothing** — Fixed in v15.10.0: 100 of the 101 bundled
  Open5e subclasses (and the Marshal and Mechanist base classes) carried only descriptive
  level tables, so picking one put nothing on the sheet. Their features are now minted as
  class-feature cards and granted at the level they first appear. See the open item above for
  what is still missing.
- **Resource pools were labelled by their machine key** — Fixed in v15.10.0: pools showed
  slugs like "Hunters Mark No Slot Uses"; they now carry an authored display name.
- **Aegis: Salgı Püskürtmesi had no counter** — Fixed in v15.10.0: the level 11 row now hangs
  off a trait card, so the free long-rest use shows as a counter on the sheet.
- **Bundled world references stayed soft** — Fixed: species and class on an imported player
  character now resolve to the installed entity, so the sheet shows the live card's name
  and the lineage (subspecies) picker appears for these characters too. A reference to
  content that is not installed still falls back to the recorded name, by design.
- **Portraits are not carried over when you create an account** — Characters created
  before signing up keep their data but lose their portrait images after the account is
  created; re-attach the image manually.
- **Deleting a world bricked its characters** — Fixed: world deletion now actually clears
  the characters' world link, so they survive as ordinary characters and open normally.
  A character still pointing at a world that is gone repairs itself the next time it is
  opened.
- **Signed-out users could get stuck on a claimed character** — Fixed with the item above:
  once the dead world link is cleared, the character opens and can be released or deleted
  again.
- **Marketplace downloads failed on release builds** — Fixed in v15.1.1: the asset server
  address now has a built-in default instead of depending on a build-time setting, so
  release builds no longer list content they cannot download.
- **Marketplace never showed banner images** — Fixed in v15.1.1, same cause as above.
- **Drow 120 ft superior darkvision** — Fixed: the resolver keeps the largest granted range
  per sense, so Superior Darkvision 120 correctly beats the base 60.
