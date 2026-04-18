# Release Notes

## v5.0.0 — Social & Marketplace Overhaul

**Release date:** April 2026

This is a major release. The social layer has been rebuilt around a single, unified card design; the marketplace now supports character sharing and cover images; editor flows no longer pester you with save prompts; and your profile is now the central place to manage everything you publish. Admin moderation got a proper home, the hardcoded D&D 5e built-in template is gone from the code, and local saves now survive app updates reliably on both Android and desktop. Several database migrations ship with this release — be sure to apply them before rolling the app out to users.

> **Heads-up for self-hosted deployments:** migrations `020`, `021`, `022`, and `023` must be applied. Without them, character sharing, cover images, the updated immutability rules, and admin moderation will fail with constraint or trigger errors.
>
> **Heads-up for existing Android users:** this is the first release signed with a persistent upload key. Installs from earlier builds were signed with per-run debug keys, so the v5.0.0 APK will **not** overwrite-install on top of them — uninstall the old build once, then install v5.0.0. From this release onward, future updates install cleanly over the top and keep your data.

---

### Highlights

- **Share your characters on the Marketplace** — characters join worlds, templates, and packages as a first-class publishable item.
- **Cover images travel with your snapshots** — the banner photo you see in the hub now follows the item into the marketplace, the feed, and every preview dialog.
- **One consistent card, everywhere** — the marketplace, feed attachments, and profile lists all use the same banner-style card so your eyes don't have to re-learn three layouts.
- **Game Listings got its own tab** — no more hunting inside the Feed scope toggle; it sits between Messages and Marketplace in the top bar.
- **Discover moved into the Feed** — people search is now just another Feed scope ("Discover") alongside All and Following, trimming the top-level tab count.
- **Silent save & exit** — world, character, and package editors now save quietly when you leave; the old "Save changes?" dialog is gone.
- **Edit your publications from your profile** — change the description, language, tags, or changelog on your marketplace items and game listings long after they're live.
- **Admin moderation v2** — bans now wipe published content, the admin panel has dedicated Users/Content/Built-ins/Audit tabs, and every moderator action is logged.
- **No more hardcoded built-in template** — the old D&D 5e "built-in" is gone from the code. Existing users keep it as a normal personal template; admins can now publish any world/template/character/package to the marketplace **as a built-in** in one step.
- **Updates keep your data** — Android APKs install over the top without losing anything, and desktop saves now live under one unified root that migrates automatically from the old split location.

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

### Admin moderation v2

The admin experience has been consolidated into a single panel with four tabs:

1. **Users** — search, promote/demote admins, ban/unban. Banning a user now also soft-deletes (or hard-deletes, per policy) everything they've published: marketplace listings, game listings, posts, and messages. Local data on the banned user's own device is untouched — the cleanup is server-side only.
2. **Content** — browse every marketplace listing in the system. From here an admin can mark **any** listing as built-in (or unmark it). This is the pre-existing path; the new "Publish as Built-in" button (see below) is the faster path for admin-owned content.
3. **Built-ins** — a filtered view of listings currently flagged `is_builtin = true`, for quick audit and rollback.
4. **Audit** — an append-only log of every admin action (ban, unban, promote, demote, mark built-in, unmark built-in), with actor, target, timestamp, and optional reason.

Non-admin accounts flagged `online_restricted` now hit hard guards on the publish path — they can still use the app locally, but every social/marketplace write is rejected server-side.

### Hardcoded built-in template, gone

Previous versions shipped a D&D 5e "built-in" template compiled into the Dart bundle (`builtin-dnd5e-default`). Users could never truly own or edit it, which was confusing, and keeping it in code forever was the wrong answer.

**What happens on upgrade:**

- **If you've used the built-in D&D 5e template** in a world, package, or character: on first launch of v5.0.0, it's copied to your local templates folder as a normal, fully-editable personal template. Nothing you own stops working, and the read-only/admin-only restrictions are gone.
- **If you've never touched it**: it doesn't appear anywhere. Your Templates tab stays clean.

The migration is one-shot, gated by a `seed_builtin_dnd5e_v1` flag in `SharedPreferences`, and only writes the file if your local database references the old ID. Safe to re-run.

Going forward, built-in status is purely a marketplace flag — there is no bundled template in the binary.

### "Publish as Built-in" for admins

Any admin opening a world/template/character/package settings now sees a second publish button alongside the usual **Share to Marketplace**:

- **Publish as Built-in** (gold, star icon) — publishes a snapshot and immediately marks it `is_builtin = true` in one flow. If the publish succeeds but the built-in flag step fails (rare — network blip between the two RPCs), a snackbar tells you to retry from **Admin → Content**; the publish itself is not lost.

Non-admin users see only the original share button; the admin button is fully gated by `isAdminProvider`.

### Data persistence across updates

Two problems were fixed at once:

**Android — APK overwrite install now preserves data.** Earlier builds were signed with a per-run debug key by GitHub Actions, so every release had a different signature and the installer refused to overwrite without uninstall (which wiped app data). v5.0.0 is signed with a persistent release keystore, and the manifest now opts into Android's auto-backup (`allowBackup=true`, `fullBackupContent`, `dataExtractionRules`). From this release forward, installing a new APK over the old one keeps everything — worlds, characters, packages, the SQLite DB, SharedPreferences.

> One-time cost: because pre-5.0 APKs were signed with a random debug key, v5.0.0 itself **cannot** overwrite-install on top of them. Uninstall the old version once, install v5.0.0, and you're done — every update after this works cleanly.

**Desktop — one unified data root.** Previously, your files lived under `~/Documents/DungeonMasterTool/` while the SQLite database lived under `~/.local/share/DungeonMasterTool/` (or the Windows/macOS equivalent). On first launch, v5.0.0 copies the database next to your files at `{Documents}/DungeonMasterTool/db/dmt.sqlite` (per-user: `…/users/{userId}/db/dmt.sqlite`). The legacy DB is **not deleted** — a `.moved_to_dataroot` marker is written next to it so you can manually roll back if needed.

A new **Data folder** row in Settings shows the full path with **Copy** and (on desktop) **Open folder** buttons, making backups and support diagnostics straightforward.

---

### Smaller improvements

- **Marketplace card layout** — language chip and tag chips are now pinned to the **bottom-right** of the card, in line with the `@user · date · 📥` row on the left.
- **Character editor header** — the RenderFlex overflow that appeared the first time you opened a character is gone. The header layout was switched from an `IntrinsicHeight + Row(stretch)` to a `Stack + Positioned` so the portrait stretches to match the text block height without off-by-eight rendering glitches.
- **Tag chips cap at 3** on marketplace cards to prevent wrap-around on narrow cards.
- **Silent-fail diagnostics** — the cover-image upload path now logs via `debugPrint` at every branch where it previously silently gave up (missing file, encoded blob too large, etc.), making it easier to diagnose "why is my banner blank" reports.
- **Legacy import cleanup** — `FeedScope.gameLists` was removed from the enum since it's no longer reachable from the UI.
- **l10n** — new key `socialTabGameListings` added for English, Turkish, German, and French. Five further keys added for the admin built-in publish flow: `publishAsBuiltinButton`, `publishAsBuiltinHeading`, `publishAsBuiltinNotice`, `publishAsBuiltinSuccess`, `publishAsBuiltinFlagFailed`.

---

### Deprecations & removals

- **Feed sub-scope "Game Lists"** — removed (moved to its own shell tab).
- **Top-level social tab "Discover"** — removed (moved into Feed scope).
- **Top-level social tab "Players"** — removed in an earlier iteration; the content lives inside profile lists.
- **"Quit to hub" button** in editor app bars — removed; use the top-left back arrow.
- **"Save changes?" confirmation dialog** on editor exit — removed; saves are automatic.
- **Hardcoded `builtin-dnd5e-default` template** — removed from the Dart bundle. Migrated to a local personal template for existing users; absent for new users (see above).
- **`BuiltinTemplateAdminRequiredException`** and the `bypassBuiltinGuard` parameter on `TemplateLocalDataSource.save()` — removed; all local templates are now edited the same way.
- **`BuiltinWarningDialog` + `template_clone_util.dart`** — removed (no remaining callers after built-in cleanup).

---

### Database migrations

Run these in order against your Supabase project:

| Migration | What it does |
|-----------|---------------|
| `020_marketplace_character_and_editable.sql` | Adds `character` to the allowed `item_type` values; temporarily loosens the immutability trigger. |
| `021_marketplace_immutable_restore.sql` | Re-tightens the immutability trigger — `title`, `description`, `language`, `tags` are locked again; only `download_count` and `changelog` mutate. |
| `022_marketplace_cover_image.sql` | Adds `cover_image_b64 TEXT` column and includes it in the immutability lock. |
| `023_admin_moderation_v2.sql` | Adds the `admin_audit_log` table, `online_restricted` user flag, `set_listing_builtin` RPC, and server-side cascade cleanup for banned users' published content. |

---

### Upgrade notes

- **App version bump:** `4.6.1` → `5.0.0`.
- **Two in-app migrations run silently on first launch:** the legacy built-in template seed (only if referenced by your local data) and the desktop DB relocation (only if the DB still lives at the old Application Support path). Both are one-shot and idempotent.
- **Android:** existing installs must be uninstalled once before installing v5.0.0 — see the signing note at the top of these release notes. Future updates install over the top.
- **Desktop:** your old SQLite file is **copied**, not moved. A `.moved_to_dataroot` marker is written next to the legacy file so you can roll back manually if you ever need to. Cleanup of the legacy copy is deferred to a later release.
- **Supabase required for social features** — the marketplace, feed, messages, game listings, and admin moderation all require Supabase to be configured, as before. Purely-local usage is unaffected.
- **Published listings pre-dating this release** have no cover image; they'll keep rendering the type icon fallback until you re-publish them with this build.

---

### Known issues

- **No cover re-publish shortcut** — if you want an existing listing to pick up the new cover-image support, you need to publish a fresh snapshot; there's no in-place "update cover" action (by design — snapshots are immutable).
- **Discover state is scope-local** — when you leave the Discover scope inside Feed, the search query is cleared the next time you return. This is intentional for v5.0 but may be persisted in a later release if feedback warrants it.
- **Legacy built-in cleanup is deferred** — `default_dnd5e_schema.dart` stays in the repo for one more release as the migration source. It has no remaining runtime references outside `seedLegacyBuiltinTemplateIfNeeded()` and will be removed in a later version.
- **Legacy desktop DB file is not auto-deleted** — v5.0.0 copies, marks, and leaves the old SQLite file in place. If you're tight on disk and confident in the migration, you can delete the legacy `Application Support/DungeonMasterTool/dmt.sqlite` manually after verifying the new one works.

---

*Thanks for playing. Roll well.*
