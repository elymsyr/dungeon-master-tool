# Known Issues

Living list of what is deferred, broken-on-purpose, or a real bug still being tracked.
**This file is the source of truth** — the `### Known issues` section of each release note
in [RELEASE_NOTES.md](RELEASE_NOTES.md) is filled in from here at release time (copy the
items that are still open on the release date; do not edit past releases afterwards).

**Last reviewed:** September 2026 (v15.1.0)

---

## Open

- **Marketplace package download fails with "Bad state: Catalog payload unavailable"** —
  Downloading a package (e.g. open5e-a5e-ag) from the marketplace throws
  `Bad state: Catalog payload unavailable`. Reproducible on GitHub release builds and dev
  builds alike (`flutter run -d` included). Needs investigation.
- **Marketplace world download silently fails on GitHub builds** — When downloading a world
  from the marketplace on a GitHub release build, no error is shown but the world does not
  download; the UI says "retry". Same flow on `flutter run -d` works fine. Likely a
  build-mode or routing difference.
- **Deleting a world bricks its characters** — A character claimed from an installed world
  can no longer be opened once that world is deleted; the sheet fails to load instead of
  simply losing its world link. Characters should survive world deletion and stay
  openable — only their tie to the world should break.
- **Signed-out users can get stuck on a claimed character** — Without an account, a
  character owned from a deleted world can be neither released nor opened, leaving no way
  back. Related to the item above.
- **Portraits are not carried over when you create an account** — Characters created
  before signing up keep their data but lose their portrait images after the account is
  created; re-attach the image manually.
- **Bundled world references stay soft** — Species and class references on imported player
  characters are not linked to local entities; sheets display the recorded name rather than
  a live link. Deferred by design for now.

## Resolved

- **Drow 120 ft superior darkvision** — Fixed: the resolver keeps the largest granted range
  per sense, so Superior Darkvision 120 correctly beats the base 60.
