# Known Issues

Living list of what is deferred, broken-on-purpose, or a real bug still being tracked.
**This file is the source of truth** — the `### Known issues` section of each release note
in [RELEASE_NOTES.md](RELEASE_NOTES.md) is filled in from here at release time (copy the
items that are still open on the release date; do not edit past releases afterwards).
Anything fixed in an earlier release lives in that release's notes, not here.

**Last reviewed:** 21 September 2026 — world-copy entry added; everything else unchanged
since v17.0.0 (14 September 2026), when `flutter test` was 1509 passing / 0 failing,
`flutter analyze` 0 errors / 0 warnings and the worker `npm run typecheck` clean.

---

## Open

- **Worker JWT check accepts a token with no `iss`** — [jwt.ts](../cloudflare/src/jwt.ts)
  rejects a wrong issuer but lets a missing one through, and never checks `aud` or `role`.
  Low risk: the signature is still verified against Supabase's JWKS and a token without
  `sub` is refused, so forging one needs Supabase's signing key. The fix is one line —
  `if (payload.iss !== expectedIss)`. (September 2026 audit §6.)
- **Copying a world empties the original** (data loss) — `WorldRepositoryImpl.copy`
  ([world_repository_impl.dart:372](../flutter_app/lib/data/repositories/world_repository_impl.dart#L372))
  reuses the source payload verbatim, so every entity keeps its **source id**. `world_entities`
  has a global primary key (`{id}`, not `{worldId, id}`) and `worldEntitiesDao.upsertAll` runs
  `insertAllOnConflictUpdate`, so each row is *updated in place* with the new `world_id` instead
  of being inserted alongside the old one. Verified: a source world with one card ends the copy
  with **0 cards**, the copy with 1.
  The same trap applies to **any** path that writes a world payload carrying another world's
  entity ids — notably downloading a marketplace world you already own locally. It is also why
  the "duplicate instead of merge" option was cut from `.dmtz` import
  ([online-sync-redesign.md](online-sync-redesign.md) §4.5).
  Fix: remap entity ids (and every intra-world reference to them) while copying, or widen the
  primary key to `{worldId, id}` — the latter is a schema change, so it rides with the next
  Drift version bump. Copying also leaves the new world's image paths pointing into the *source*
  world's media folder, so deleting the source orphans the copy's art.
- **Banning is not possible** — a DM cannot hide SRD content from players ("there is no
  Fireball in this world"); sharing marks only add, they do not take away.

## Resolved

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
