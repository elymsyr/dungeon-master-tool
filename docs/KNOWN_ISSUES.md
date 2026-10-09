# Known Issues

Living list of what is deferred, broken-on-purpose, or a real bug still being tracked.
**This file is the source of truth** — the `### Known issues` section of each release note
in [RELEASE_NOTES.md](RELEASE_NOTES.md) is filled in from here at release time (copy the
items that are still open on the release date; do not edit past releases afterwards).
Anything fixed in an earlier release lives in that release's notes, not here.

**Last reviewed:** 9 October 2026 (v19.1.1: *Copying a world empties the original* resolved, *Copying a package leaves its mentions pointing at the source package* added; v19.1.0, no changes; v19.0.0: *Map pin labels and the combat log are not translated* added; *3D dice roller is slow on phones* added in v18.1.0). The
v17.0.0 baseline (14 September 2026): `flutter test` 1509 passing / 0 failing, `flutter analyze`
0 errors / 0 warnings, worker `npm run typecheck` clean.

---

## Open

- **Worker JWT check accepts a token with no `iss`** — [jwt.ts](../cloudflare/src/jwt.ts)
  rejects a wrong issuer but lets a missing one through, and never checks `aud` or `role`.
  Low risk: the signature is still verified against Supabase's JWKS and a token without
  `sub` is refused, so forging one needs Supabase's signing key. The fix is one line —
  `if (payload.iss !== expectedIss)`. (September 2026 audit §6.)
- **Copying a package leaves its mentions pointing at the source package** — package copy
  gives every card a fresh id but only rewrites ids that are a whole string value
  (`PackageRepositoryImpl._remapRefs`); a mention inside text (`@[Name](entity:<id>)`) keeps the
  source package's id and is a broken link in the copy. `remapIdsJson` (`core/utils/deep_copy.dart`)
  already handles mentions; switching package copy to it is a one-line change.
- **A player's mind map does not reach their second device** — the player's own mind map
  in a world stays on the device it was made on. Deferred to the next sync phase (5.5c in
  [online-sync-redesign.md](online-sync-redesign.md)).
- **Battle map display toggles are inconsistent** — view helpers such as *Show all HP* and
  *Clean tokens* (`bmShowAllHp`, `bmCleanTokens`) each behave in their own way. They will be
  moved to a single standard.
- **3D dice roller is slow on phones (release build)** — reported on v18.1.0: the first menu
  open freezes and the throw animation runs at a low frame rate. Two causes found and
  mitigated in `b4900cf7`, **not yet verified on a device**:
  - *First-open freeze:* `Texture2D.fromImage` built each number atlas's mip chain on the UI
    isolate with sRGB `pow()` per texel (~5M px over 8 atlases; 982 ms desktop AOT). The atlases
    now use `TextureContent.data` (plain byte average, 62 ms).
  - *Low FPS:* the full-screen `ShadowCatcherMaterial` floor runs a 16-tap shadow lookup on every
    pixel, so phones are fill-bound. `pixelRatio` is now capped at 1.25 on Android/iOS
    (`_maxPixelRatio` in [dice_roll_view.dart](../flutter_app/lib/presentation/widgets/dice/dice_roll_view.dart)),
    2 on desktop. If dice look soft, raise it to 1.5; if it still stutters, profile with
    `flutter run --profile` (UI vs raster time) before trying further cuts (FXAA, smaller atlas).
  - *Follow-up (pixelRatio alone barely helped):* measured with a profile harness on an AMD iGPU,
    saturating the GPU so frame time = GPU time. Shadow map + full-screen catcher ≈ 50% of GPU
    time, clearcoat ≈ 35% more with 30 dice, MSAA ≈ 16%. Phones now skip shadows and clearcoat
    and draw a blob shadow per die (`_phone` in `dice_roll_view.dart`): −53% (1 die) / −65%
    (30 dice) GPU time on that iGPU. **Still not verified on a phone**; if it still stutters,
    profile on device (`flutter run --profile`, UI vs raster) — not yet measured: the app under
    the non-opaque dice route is re-rasterized every frame (Impeller has no raster cache).
  - Still open: a direct roll from the proficiency table without opening the menu first pays the
    `DiceKit` build and shader warm-up at throw time, so that first throw can stall briefly.
- **Map pin labels and the combat log are not translated** — with the SRD content language
  set to Turkish, a map pin keeps the name it had when it was placed (the label is written into
  the data and the DM edits it), and combat log lines stay in English. Left out on purpose in
  the SRD-TR work ([docs/srd-tr/ROADMAP.md](srd-tr/ROADMAP.md) Faz 6).
- **Banning is not possible** — a DM cannot hide SRD content from players ("there is no
  Fireball in this world"); sharing marks only add, they do not take away.

## Resolved

- **Downloading the same marketplace package twice emptied the first download** — fixed 9
  October 2026. The payload carries the publisher's `package_id` and card ids; `packages` and
  `package_entities` are keyed by `id` alone, so the second download took over the first
  package's row (renamed it) and moved its cards. `PackageRepositoryImpl.save` now gives a new
  package a fresh id when the payload's id belongs to another package, and gives fresh ids to
  cards owned by another package, rewriting in-package refs and mentions (`_claimEntityIds`).
  This also covers installing a catalog package as a copy. Regression test:
  `test/data/repositories/package_save_ids_test.dart`.
- **Card edits sometimes lost; an edited SRD/package card's source went back to the original**
  — fixed 9 October 2026. Two causes in the card's 300 ms save delay: (1) a second edit inside
  the window replaced the first instead of adding to it (`EntityCard._debouncedProviderUpdate`
  now composes the edits); (2) an edit that reached the original id just after the
  `Homebrew` copy was forked was written over the copy as "original + this edit", dropping the
  copy's first edit and its `Homebrew` source (`EntityNotifier._rebaseOnFork` now carries only
  what changed). Regression test: `test/application/providers/entity_fork_edit_test.dart`.
- **Copying a world emptied the original** (data loss, cards and sessions) — fixed 9 October
  2026: `WorldRepositoryImpl.copy` gives every card and session a fresh id and rewrites every
  in-world reference to it, mentions in text included (built-in SRD forks move to the copy's own
  synth id). It copies the source world's whole folder (images, PDFs, attachments, images
  embedded in markdown) and points the copy's paths at it, and copies the package links.
  Regression test: `test/data/repositories/world_copy_test.dart`.
- **A world payload carrying another world's ids moved rows** — fixed 9 October 2026.
  `world_entities` and `world_sessions` have a global primary key (`{id}`), and the upsert used
  to *move* a row whose id belonged to another world. Two layers now:
  - the four upsert methods of `WorldEntitiesDao` / `WorldSessionsDao` only update a conflicting
    row of the **same** world; another world's row stays where it is;
  - every path that opens a new world from content that came from somewhere else first calls
    `CampaignRepository.claimIds`, which gives fresh ids to cards and sessions already held by
    another world and rewrites the references. That covers copying, marketplace download (the
    same listing twice, or your own world) and official catalog download (the same world twice
    — its card ids are deterministic).
  Widening the primary key to `{worldId, id}` is no longer planned: the cloud tables are keyed
  by `id` alone too, so ids have to stay unique across worlds anyway. A new path that writes
  foreign ids without `claimIds` loses those rows in the new world instead of taking them from
  the old one.
- **Markdown images in a `.dmtz` world broke on a device with another data root** — fixed
  9 October 2026: the import's path rewrite (`ContentCodec.rewriteRoots`, now
  `LocalMediaLocalizer.rebase`) only matched whole string values, and an image embedded in
  markdown (`![](dmt-img:<encoded path>)`) is part of a longer, percent-encoded string. It is
  decoded, rewritten and re-encoded now.
- **The 12 September 2026 audit (60 failing tests)** — fixed 14 September 2026:
  - Guest promotion dropped a guest package that shared a name with an account package
    (data loss). The built-in SRD is now mapped onto the account's copy by name; any other
    clash comes over as "Name (2)", because `idx_packages_name` is UNIQUE.
  - `ContentStore._touch` and `FirstPartyArtService.sweepUnreferenced` are best-effort again:
    a failure no longer escapes, and a committed world/package delete is not reported as failed.
  - Stale tests, not product bugs: `combat_provider_test` (the helper passed `null` campaign
    data), `account_gate_test` (`localSync` needs no account), `srd_core/species_test`
    (subspecies are their own entities), `default_schema_test` (`player` category removed).
    `content_store_test`'s `tearDown` raced an unawaited touch; it now retries the delete.
  - The worker typechecks again (`jwt.ts` uses `@cloudflare/workers-types`' own
    `SubtleCrypto*` types), and `assets/first_party/manifest.json` was regenerated.
  - [analyze-test.yml](../.github/workflows/analyze-test.yml) now fails on errors, warnings,
    failing tests or a worker type error. It stays manual (`workflow_dispatch`) by choice.
- **Hard-coded UI strings** — `lib/presentation/` reads from the `.arb` files (1503 keys ×
  4 languages). Literal on purpose: language names, brand names and URLs, rules abbreviations
  (`HP`, `AC`, `CR 5`), defaults stored as data, the pop-out player window (no localization
  delegates), and a few context-free helper labels.
- **A joined world had no schema, so shared cards showed only name, description and image** —
  a world with no schema snapshot now falls back to the built-in v2 schema and the join writes
  `templateId`. A DM's own Tier-2 categories still do not reach players: sending the DM's
  schema is a sharing decision, not a bug fix.
- **Deleted marketplace listings left their images in R2** — owner and moderator deletes both
  release the refs and the worker's cron evicts orphaned objects. The owner-side release is
  best-effort, so a network error there can still strand one listing's media.
- **Downloaded card art was never cleaned up** — deleting a package or world sweeps
  unreferenced files under `cacheDir/art/`.

### By design

- **Third-party feature cards are narrative** — the 559 Open5e class/subclass feature cards
  carry prose only; nothing is granted automatically from free text. "Path of Hellfire" ships
  no features upstream.
- **`creature-action.uses_per_day` has no counter** — the value is editable; per-use tracking
  belongs to `resource_pool_grants` on a trait or feat card.
- **`libsqlite3.so` missing on a dev machine** — Drift-backed tests fail to load without
  `libsqlite3-dev` (18 extra failures). `sudo apt install libsqlite3-dev`; CI installs it.
