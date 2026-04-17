# Release Notes

## v5.0.0 — Social & Marketplace Overhaul

**Release date:** April 2026

This is a major release. The social layer has been rebuilt around a single, unified card design; the marketplace now supports character sharing and cover images; editor flows no longer pester you with save prompts; and your profile is now the central place to manage everything you publish. Several database migrations ship with this release — be sure to apply them before rolling the app out to users.

> **Heads-up for self-hosted deployments:** migrations `020`, `021`, and `022` must be applied. Without them, character sharing, cover images, and the updated immutability rules will fail with constraint or trigger errors.

---

### Highlights

- **Share your characters on the Marketplace** — characters join worlds, templates, and packages as a first-class publishable item.
- **Cover images travel with your snapshots** — the banner photo you see in the hub now follows the item into the marketplace, the feed, and every preview dialog.
- **One consistent card, everywhere** — the marketplace, feed attachments, and profile lists all use the same banner-style card so your eyes don't have to re-learn three layouts.
- **Game Listings got its own tab** — no more hunting inside the Feed scope toggle; it sits between Messages and Marketplace in the top bar.
- **Discover moved into the Feed** — people search is now just another Feed scope ("Discover") alongside All and Following, trimming the top-level tab count.
- **Silent save & exit** — world, character, and package editors now save quietly when you leave; the old "Save changes?" dialog is gone.
- **Edit your publications from your profile** — change the description, language, tags, or changelog on your marketplace items and game listings long after they're live.

---

### Marketplace

#### Characters are now publishable
You can publish a character to the Marketplace just like worlds, templates, and packages. Open a character from the Characters tab → **Settings** → **Share on Marketplace**. When another user downloads your character, it lands in their library as an orphan (no world attached) — they can link it to one of their own worlds after import. Existing filters, tag search, and preview dialogs all understand the new `character` item type.

#### Cover images (banner photos) ship with listings
Every marketplace listing now carries the cover image that was set on the source item at publish time. The image is embedded inline with the listing record (base64), so the marketplace browse view renders banners without a second round-trip. A few implementation details worth knowing:

- The image is resized to ~480 px wide before upload and capped at ~2 MB encoded. Oversized photos fall back to the type icon.
- The cover is **part of the snapshot** — changing the world's banner afterwards does not affect already-published listings.
- We resolve covers from both the campaign's top-level metadata *and* the nested world-schema metadata, so historical worlds save their cover no matter which save path wrote them.

#### Metadata stays immutable
Migration `020` briefly opened up title/description/language/tags/changelog for editing. We reversed that decision in `021` — snapshots are snapshots. The only marketplace fields that can change after publish are `download_count` (automatic) and `changelog` (owner, via the edit flow on listings you still own locally). If you need to correct a typo, publish a fresh snapshot.

#### Unified banner card
`_MarketplaceCard`, `_FeedListingCard`, `_UserListingCard`, and `_OwnerListingCard` have all been consolidated into a single `ListingBannerCard` widget with three variants: `.marketplace()`, `.game()`, and `.compact()` (for inline post attachments). The marketplace card now shows a 120 px top banner, title + type pill, 2-line description, `@owner · date · 📥 count` on the left, and language + tag chips pinned to the right edge.

### Social shell

The top-level social bar has been rebalanced:

**Before (v4.6):** Feed / Messages / Marketplace
**After (v5.0):** Feed / Messages / **Game Listings** / Marketplace

**Game Listings** was previously a sub-scope under Feed. It now has its own tab with the same filter bar (language / system / tag) and listing cards — just without being buried behind a scope toggle.

**Discover** (people search) used to be its own top-level tab in earlier versions. It's now a scope *inside* Feed, alongside **All** and **Following**. The Feed scope toggle therefore went from four options to three: All / Following / Discover.

### Editors — silent exit & unified back button

The world, character, and package editor screens have been aligned:

- The **back arrow is now top-left** on every editor screen, matching the package screen's original layout.
- The "Quit to hub" button in the top-right (and in the phone overflow menu) has been removed.
- **Leaving no longer prompts "Save changes?"** — your edits are saved automatically and you're returned to the hub. This applies to worlds, characters, and packages.

If you prefer the discipline of an explicit save prompt, your muscle memory gets a brief retraining period; the save itself happens every time, just without the interruption.

### Profile

Your profile now has three tabs:

1. **Posts** — the existing feed-post history.
2. **Items** — your marketplace listings (worlds, templates, packages, characters). Listings you own get an edit/delete kebab; other users' profiles show the same cards read-only.
3. **Listings** *(new)* — your game listings. Owners can create (**New Listing** button), edit, close, or delete; other users see only your currently-open listings.

Edit dialogs pre-fill with the current values so you can make small adjustments without re-typing everything. For marketplace items, remember: metadata edits are disabled in v5.0 — the panel is there for fields that *can* change (currently just the changelog for draft snapshots).

---

### Smaller improvements

- **Marketplace card layout** — language chip and tag chips are now pinned to the **bottom-right** of the card, in line with the `@user · date · 📥` row on the left.
- **Character editor header** — the RenderFlex overflow that appeared the first time you opened a character is gone. The header layout was switched from an `IntrinsicHeight + Row(stretch)` to a `Stack + Positioned` so the portrait stretches to match the text block height without off-by-eight rendering glitches.
- **Tag chips cap at 3** on marketplace cards to prevent wrap-around on narrow cards.
- **Silent-fail diagnostics** — the cover-image upload path now logs via `debugPrint` at every branch where it previously silently gave up (missing file, encoded blob too large, etc.), making it easier to diagnose "why is my banner blank" reports.
- **Legacy import cleanup** — `FeedScope.gameLists` was removed from the enum since it's no longer reachable from the UI.
- **l10n** — new key `socialTabGameListings` added for English, Turkish, German, and French.

---

### Deprecations & removals

- **Feed sub-scope "Game Lists"** — removed (moved to its own shell tab).
- **Top-level social tab "Discover"** — removed (moved into Feed scope).
- **Top-level social tab "Players"** — removed in an earlier iteration; the content lives inside profile lists.
- **"Quit to hub" button** in editor app bars — removed; use the top-left back arrow.
- **"Save changes?" confirmation dialog** on editor exit — removed; saves are automatic.

---

### Database migrations

Run these in order against your Supabase project:

| Migration | What it does |
|-----------|---------------|
| `020_marketplace_character_and_editable.sql` | Adds `character` to the allowed `item_type` values; temporarily loosens the immutability trigger. |
| `021_marketplace_immutable_restore.sql` | Re-tightens the immutability trigger — `title`, `description`, `language`, `tags` are locked again; only `download_count` and `changelog` mutate. |
| `022_marketplace_cover_image.sql` | Adds `cover_image_b64 TEXT` column and includes it in the immutability lock. |

---

### Upgrade notes

- **App version bump:** `4.6.1` → `5.0.0`.
- **No data migration required in-app** — your local campaigns, characters, and worlds are unchanged by this release.
- **Supabase required for social features** — the marketplace, feed, messages, and game listings all require Supabase to be configured, as before. Purely-local usage is unaffected.
- **Published listings pre-dating this release** have no cover image; they'll keep rendering the type icon fallback until you re-publish them with this build.

---

### Known issues

- **No cover re-publish shortcut** — if you want an existing listing to pick up the new cover-image support, you need to publish a fresh snapshot; there's no in-place "update cover" action (by design — snapshots are immutable).
- **Discover state is scope-local** — when you leave the Discover scope inside Feed, the search query is cleared the next time you return. This is intentional for v5.0 but may be persisted in a later release if feedback warrants it.

---

*Thanks for playing. Roll well.*
