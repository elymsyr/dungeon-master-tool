# Known Issues

Living list of what is deferred, broken-on-purpose, or a real bug still being tracked.
**This file is the source of truth** — the `### Known issues` section of each release note
in [RELEASE_NOTES.md](RELEASE_NOTES.md) is filled in from here at release time (copy the
items that are still open on the release date; do not edit past releases afterwards).

**Last reviewed:** September 2026 (v15.10.0)

---

## Open

- **Third-party subclass features are name-only** — Subclasses from the bundled Open5e packs
  now put every named feature on the sheet as a class-feature card, but the card carries the
  upstream prose and no typed mechanic, so nothing is rolled or added automatically. "Path of
  Hellfire" ships no features at all upstream and still grants nothing.

- **Aegis: Mühür Kalkanı has the wrong artwork** — The action card shows a shield-bearing
  turtle that does not match the ability. There is no correct sibling image to point at, so
  it waits on a new drawing.

- **`creature-action.uses_per_day` is never read** — The field exists in the schema but no
  screen renders a counter for it, so a per-day limit authored on a creature action is
  invisible. Use a resource pool on a trait or feat card instead.

- **59 tests fail on `main`** — As of v15.10.0 `flutter test` reports 1424 passing and 59
  failing. None of them are caused by the version bump; they are fallout from the content
  and schema changes in v15.10.0 that the tests were not updated for:
  `combat_provider_test` (42), `account_gate_test` (6), `srd_core/species_test` (5),
  `default_schema_test` (3, expects 19 categories but the schema now generates 18),
  `content_store_test` (2) and `guest_promotion_service_test` (1). `flutter analyze` is
  clean apart from 27 pre-existing info-level lints.

- **Official catalog packages ship without their card art** — Installing `cairn-2e-core` or
  `cairn-community` from the store leaves every card image blank. The installer asks for
  `catalog/art-bundle/{slug}@{version}.zip` in R2, but no tool in the repo builds or uploads
  that zip (`publish_catalog.dart` sends payloads, world media and the manifest only), and
  `FirstPartyArtService` has no per-file fallback. The SRD pack is unaffected because its
  1247 images ship inside the app bundle; Cairn's 653 do not. The 404 is only `debugPrint`ed
  and `prefetchBundle`'s return value is ignored, so the install still reports success.

- **Downloaded card art is never cleaned up** — Card images downloaded with an official
  package stay in the app's cache after the package is removed, and there is no size cap on
  that cache. Deliberate for now: the images are small individually and re-downloading them
  costs a full install. Clearing the app's cache removes them.

- **Deleted marketplace listings leave their images in R2** — When the publisher deletes a
  world they shared on the marketplace, the listing goes away but the uploaded media under
  `pub/` in R2 is not removed, so the objects stay and keep costing storage. No user-visible
  effect; needs a cleanup pass (or delete-time media removal).

## Resolved

- **Most third-party subclasses granted nothing** — Fixed in v15.10.0: 82 of the 117 bundled
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
