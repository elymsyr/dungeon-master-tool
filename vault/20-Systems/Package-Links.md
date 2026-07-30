---
type: system
domain: world-content
updated: 2026-07-30
tags: [system]
---

# Package Links — one copy of the content, borrowed everywhere

> [!summary] What this is
> A package can **link** other packages. The two stores stay separate — nothing
> is copied — but the linked package's entities become visible inside the
> linking package, and they follow it into every world it is imported into and
> every catalog install that pulls it down. The answer to "the built-in pack and
> the official packs ship the same races/classes/items/spells twice". Owned by
> [[World-and-Content]].

## Why

Before this, sharing content between packages had exactly one implementation and
it was hard-coded: [[builtin_package_provider]]'s `srdReferenceEntitiesProvider`
overlaid the built-in SRD pack into every *other* package's editing view, and
[[srd_core_bootstrap]] linked SRD into every new world. The idea worked; it just
could not be pointed at anything but SRD. Package links generalise it.

Note this is the **mechanism** only. The official Open5e packs still carry their
own copies of SRD-overlapping content — measured 2026-07-30 by [[dupe_census]] at
**4,331 of 20,712 bundled entities (20.9%)**, and every pack still emits
`requires: []`. Deduplicating them is separate work that this unblocks; the plan
is `flutter_app/docs/open5e_content_audit.md` §2 + Stage L.

**Declaring a link in a built pack takes both keys.** A `metadata.links` entry is
read by two different consumers that look at different fields:
`build_catalog._requiredSlugs` reads `slug ?? package_id ?? name` and needs the
**catalog slug** (`open5e-toh`), while `PackageLink.fromJson` ignores `slug`
entirely and needs the **installed local name** — which is the target's
`metadata.title` (`Tome of Heroes`), because [[package_payload_importer]] names
the row after the title. Emit `{"slug": …, "name": …}`; either key alone fails
silently on one side. No link to the built-in pack is needed or wanted: it is in
scope everywhere already (below), and the catalog has no entry for it.

## Participants

- [[package_link]] — `PackageLink({packageId, name})`, the persisted soft ref.
- [[package_link_service]] — read/write, closure, cycle guard, reverse index.
- `package_link_provider.dart` — Riverpod surface + `packageReferenceOverlayProvider`.
- [[world_package_installer]] — closure install + cross-package ref remap.
- [[package_sync_service]] — gained `foreignRefs`.
- [[link_package_dialog]] — the UI (package screen AppBar, edit mode only).

## Storage — no table

Links live in `packages.state_json['links']`:

```json
"links": [ {"package_id": "…", "name": "Adventurer's Guide"} ]
```

Two reasons, both decisive:

1. **It syncs and exports for free.** `PackageRepositoryImpl._saveToDb` routes
   every non-typed top-level key into `state_json` and `_loadFromDb` spreads it
   back, so export, marketplace payloads, personal cloud sync and trash-restore
   all carry links with no extra code. Writes go through `saveStatePatch`, which
   merges the single key.
2. **A Drift table would cost every user their data.** Adding one bumps
   `schemaVersion` past 12, and the v12 fresh cut renames any older DB to
   `dmt.sqlite.legacy.<ts>` rather than migrating it.

The SRD core pack is the root of the graph and holds no links —
`PackageRepositoryImpl.save`/`saveStatePatch` are no-ops for it (it is
regenerated from code on every boot), and the UI hides the action for it.

## Resolution — soft, like every other cross-package ref

`package_id` first, human `name` as the fallback. The fallback is what makes a
link survive a marketplace download or a "Copy" (both mint a fresh local id
while keeping the title). Neither resolves → the link is **dangling**: skipped
in traversal, shown as "Not installed" in the dialog, never an error. Same
contract as [[Ref-Resolution-Hard-vs-Soft]].

## Closure

`PackageLinkService.closure(name)` is a post-order DFS over the whole `packages`
row set loaded once: **dependencies first, the package itself last**. That order
is the install order and the id-collision precedence (later wins). A visited set
breaks cycles (A→B→A terminates, each package emitted once) and self-links are
skipped, so a malformed graph degrades instead of hanging.

## The three cascades

| Where | What happens |
|---|---|
| **Package editor** | `packageReferenceOverlayProvider(name)` = SRD entities ∪ closure entities. `EntityNotifier(referenceOverlayFor: name)` injects them read-only; `_referenceEntityIds` keeps them out of every write path, so editing one forks a homebrew copy exactly as an SRD row does. |
| **World import** | [[world_package_installer]] installs the whole closure, dependencies first. |
| **Catalog download** | `CatalogEntry.requires` (emitted by [[build_catalog]] from the pack's `metadata.links`) is resolved transitively by `FirstPartyInstallNotifier` before the requested entry. [[package_payload_importer]] carries `links` across the re-install that would otherwise replace `state_json`. |
| **Character creation** | `expandedPackageNames` widens the player's picked packages to their closure, so a class borrowed from a linked pack dereferences in the wizard, the resolver, the header chips and the editor. |

## Cross-package ref remap — the sharp edge

Authoring against the overlay means a card can hold a **foreign pack-entity id**.
[[package_sync_service]] used to build `packToWorld` from only the package being
synced, so such a ref kept its pack-side id and dangled in the world.

`sync(foreignRefs:)` fixes it. `WorldPackageInstaller.buildForeignRefIndex`
supplies `packageEntityId → world id` for everything already in the world:

1. the built-in pack via `synthBuiltinEntityId(worldId, packEntityId)` — its rows
   are synthesised at read time, never materialised ([[builtin_synth]]);
2. every real `world_entities` row carrying a `package_entity_id`, including
   dependencies synced moments earlier in the same closure run. These win.

The index is rebuilt between packages in a closure, which is why order matters.
This also closed a pre-existing hole: a ref picked from the SRD overlay dangled
on world import even before links existed.

## Uninstall does NOT cascade

Removing package A from a world removes only A; B and C stay installed. There is
no "installed as a dependency" column on `installed_packages` and adding one
would bump the Drift schema (see above), so provenance is simply not tracked —
better than guessing and silently deleting a package the user installed on
purpose.

Deleting a linked-to package from the hub is likewise **allowed**: the Packages
tab warns which packages link it (`PackageLinkService.reverseLinks`) and the
links go dangling.

> The official-catalog install path ([[first_party_catalog_provider]]) resolves
> `requires` on the way *in* but has no equivalent on the way *out* — that warning
> is not wired there. It becomes load-bearing the moment the official packs stop
> duplicating content and start linking one owner (audit phase L2/D2).

## What links do **not** solve — content ownership

The mechanism is finished; deciding *which* pack owns a shared name is content
work, and the 2026-07-30 audit pass found the obvious heuristic wrong. A
`(slug, name)` collision is a collision the resolver faces, **not** evidence the
two cards say the same thing:

- 90.3% of cross-pack shared `creature-action` / `trait` names carry different
  text ("Multiattack" = 8 copies, 8 texts; "Amphibious" = 7 copies, 5 texts).
- Those rows are **owned children**: a monster hard-`_ref`s them via
  `action_refs` / `trait_refs`. There is nothing to link — collapsing them by name
  moves another creature's text onto this creature.
- Publishers restat deliberately (Level Up A5E vs SRD; Tome of Beasts 2016 vs the
  2023 edition), so "same name" across documents is often "different game".

Rule of thumb: link **library** content a pack genuinely re-ships (gear, spells,
backgrounds, feats); never link, and never dedup, content a statblock owns. See
`flutter_app/docs/open5e_content_audit.md` §2.5 and [[dupe_census]].

## Key Constants / Invariants

- Closure order = dependency order = install order = collision precedence.
- A package never links itself; a cycle never loops.
- Overlay entities are never persisted into the linking package.
- Dangling is a warning, never a failure — at read, install and download alike.
- `packageLinkRevisionProvider` is bumped on every mutation; the family providers
  watch it, because a link edit changes the closure of every package upstream of
  the target and Riverpod families cannot be invalidated wholesale.

## Related

- MoCs: [[World-and-Content]], [[Content-Pipeline]], [[Character-System]]
- Systems: [[Ref-Resolution-Hard-vs-Soft]], [[CDC-Sync-Flow]]
- Tests: `test/application/services/package_link_service_test.dart`,
  `test/application/services/world_package_installer_test.dart`
