# Known Issues

Living list of what is deferred, broken-on-purpose, or a real bug still being tracked.
**This file is the source of truth** — the `### Known issues` section of each release note
in [RELEASE_NOTES.md](RELEASE_NOTES.md) is filled in from here at release time (copy the
items that are still open on the release date; do not edit past releases afterwards).

**Last reviewed:** September 2026 (v15.9.0)

---

## Open

- **Most third-party subclasses have no mechanical grants** — Of the 117 subclasses across the
  bundled Open5e packs, 82 carry only descriptive text: their level tables list the feature
  names but no granted trait, feat, action or spell, so picking one grants nothing on the
  sheet. Worst affected are Tome of Heroes (63 of 76), Open5e Original (12 of 17), Tal'Dorei
  (3 of 4), Level Up Adventurer's Guide (3 of 3) and Black Flag (1 of 1); "Path of Hellfire"
  has no level table at all. The source data has no mechanical fields to import, so this
  needs the importer to derive grants from the feature text. The built-in SRD (12 subclasses)
  and the bundled Aegis world are unaffected — their grants resolve in full.

- **Downloaded card art is never cleaned up** — Card images downloaded with an official
  package stay in the app's cache after the package is removed, and there is no size cap on
  that cache. Deliberate for now: the images are small individually and re-downloading them
  costs a full install. Clearing the app's cache removes them.

- **Deleted marketplace listings leave their images in R2** — When the publisher deletes a
  world they shared on the marketplace, the listing goes away but the uploaded media under
  `pub/` in R2 is not removed, so the objects stay and keep costing storage. No user-visible
  effect; needs a cleanup pass (or delete-time media removal).

## Resolved

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
