# Known Issues

Living list of what is deferred, broken-on-purpose, or a real bug still being tracked.
**This file is the source of truth** — the `### Known issues` section of each release note
in [RELEASE_NOTES.md](RELEASE_NOTES.md) is filled in from here at release time (copy the
items that are still open on the release date; do not edit past releases afterwards).

**Last reviewed:** September 2026 (v15.1.1)

---

## Open

- **Portraits are not carried over when you create an account** — Characters created
  before signing up keep their data but lose their portrait images after the account is
  created; re-attach the image manually.
- **Bundled world references stay soft** — Species and class references on imported player
  characters are not linked to local entities; sheets display the recorded name rather than
  a live link. Deferred by design for now.

## Resolved

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
