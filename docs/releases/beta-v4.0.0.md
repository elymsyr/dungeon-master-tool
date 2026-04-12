# Beta v4.0.0 - Marketplace Snapshots & Hub Polish

Second major beta. Replaces the flat public/private toggle with a versioned **snapshot + lineage** marketplace, ships in-app help for every hub tab, and lands a large UX polish pass across the sidebar, feed, and settings dialogs. **Beta** release -- feedback welcome via [GitHub Issues](https://github.com/elymsyr/dungeon-master-tool/issues).

---

## Downloads

| Platform | File | Notes |
| :--- | :--- | :--- |
| Android | `DungeonMasterTool-Android.apk` | Enable "Install from unknown sources" if prompted |
| iOS | `DungeonMasterTool-iOS.ipa` | Unsigned -- sideload via Xcode or AltStore |
| Windows | `DungeonMasterTool-Windows.zip` | Extract and run `dungeon_master_tool.exe` |
| Linux | `DungeonMasterTool-Linux.zip` | Extract and run `./bundle/dungeon_master_tool` |
| macOS | `DungeonMasterTool-MacOS.zip` | See [macOS installation guide](https://github.com/elymsyr/dungeon-master-tool#macos-installation) |

---

## Highlights

### Marketplace: immutable snapshots with lineage

The old "public/private toggle" model is gone. Publishing a world, template or package now produces an **immutable snapshot** -- a frozen, versioned copy that can never be mutated after the fact. Every snapshot you publish from the same local item is linked through a shared **lineage**, so readers who downloaded an earlier version are notified when the owner ships a new one.

- **Publish Snapshot dialog** -- title, description, language, tags and an optional changelog. A "Start fresh lineage" toggle lets owners break the chain and publish a brand-new standalone listing instead of superseding their previous current snapshot.
- **My Snapshots panel** -- per-item history view inside settings dialogs. Shows all published versions, marks the current one, and lets owners delete historical snapshots (current snapshots can only be deleted if there are no downloaders).
- **Update prompts** -- when a downloaded item has a newer upstream snapshot, the UI surfaces a prompt with the new changelog and two actions: **replace local copy** (keeps the same local ID) or **download as new copy** (forks the lineage locally).
- **Mute updates / dismiss version** -- don't want to be nudged about a specific lineage? Mute it. Want to skip just one version? Dismiss it.
- **Drift banners** -- local edits after importing a snapshot show an "imported from @owner" banner so you always know where a copy originated.
- **No-op publish detection** -- publishing an unchanged item raises a friendly "no changes since last snapshot" message instead of creating a duplicate row.

### In-app help per tab

Every top-level Hub tab (Social, Settings, Worlds, Templates, Packages) now has a **"?" button** in the top-right of the AppBar that opens a localized dialog explaining what the section is for and how to use it. New `HelpIconButton` widget, fully translated in EN / TR / DE / FR.

### Hub UI polish

- **Narrower sidebar** -- the desktop left rail is now 56 dp (down from Material's 72 dp default), with square hover highlights and more vertical breathing room between icons. Custom `_HubSideRail` replaces `NavigationRail` to get the indicator shape and spacing right.
- **Apply button on game listings** -- the Apply / Applied button now lives on its own row, anchored to the **bottom-right corner** of each game listing card in the Feed.
- **MarketplacePanel owner section stacked** -- the "Not yet shared" text and the "Share to Marketplace" button now stack vertically in item settings dialogs, instead of fighting for horizontal space.
- **Publish button fix** -- a silent-disable bug (tags were secretly required with no UI hint) is fixed: the button is always clickable and validation surfaces missing fields via a localized SnackBar.

### Localization catch-up

~80 new l10n keys added across all four supported locales (`app_en.arb`, `app_tr.arb`, `app_de.arb`, `app_fr.arb`). Covers the entire marketplace snapshot system, update prompts, my-snapshots panel, help dialogs, and lingering English strings from the 3.0 sprint. No fallback placeholders -- every key has a full translation.

---

## Backend changes

New Supabase migration `006_marketplace_listings.sql`:

- Drops the old `shared_items` table (beta-sprint clean break -- existing public items are reset).
- New `marketplace_listings` table with `lineage_id`, `is_current`, `superseded_by` columns, plus indexes for "current listings per lineage" and "by owner / by type" queries.
- `publish_marketplace_snapshot` RPC that atomically inserts the new snapshot, updates the previous current row's `superseded_by`, and flips `is_current`.
- Row-level security: public read on current snapshots, owner-only writes.
- Storage bucket `shared-payloads` (from 3.0) is reused for gzipped snapshot payloads.

---

## Technical Details

- **Framework:** Flutter 3.41 / Dart 3.11
- **Architecture:** Clean Architecture (Domain / Data / Application / Presentation)
- **State Management:** Riverpod
- **Database:** Drift SQLite (local) + Supabase Postgres (online)
- **Realtime:** Supabase channels for chat (unchanged from 3.0)
- **Models:** Freezed + json_serializable
- **New domain entity:** `MarketplaceListing` with lineage fields
- **New providers:** `marketplaceListingNotifierProvider`, `mySnapshotsProvider`, `marketplaceUpdatePromptProvider`

---

## Upgrading from 3.0.0

1. Apply `supabase/migrations/006_marketplace_listings.sql` on your Supabase project. **Note:** this drops the old `shared_items` table -- all previously-published public items will be wiped. Owners will need to re-publish them as snapshots.
2. No local DB migration required -- the Drift schema is unchanged. Local items retain their IDs; the lineage link is established on the first `publishSnapshot` call.
3. Rebuild the app.

---

## Fixed

- Publish button on the Share to Marketplace dialog was silently disabled when no tags were entered, with no hint why ([#publish-button]).
- "Not yet shared" text and Share button in item settings were cramped side-by-side instead of stacked.
- Apply button on game listing cards was colliding with the seats/schedule row.
- Several marketplace-related widgets still contained hard-coded English strings from the 3.0 sprint.

---

## What's Next

See [TODO.md](https://github.com/elymsyr/dungeon-master-tool/blob/main/TODO.md) for the roadmap.

---

## License

[CC BY-NC 4.0](https://github.com/elymsyr/dungeon-master-tool/blob/main/LICENSE)
