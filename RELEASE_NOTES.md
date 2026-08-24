# Release Notes

## Dungeon Master Tool v14.0.1 — Cloud UI Cleanup

**Release date:** August 2026

Patch release. After v14.0.0 removed cloud sync, the storage usage bar (showing MB used / quota) was still visible in the save & sync dialog. That leftover UI is now gone — the dialog shows only local save info and LAN sync status, matching the reality that nothing lives in the cloud anymore.

> [!warning] Upgrading from v14.0.0
> v14.0.0 removed cloud sync entirely — cloud backups are gone, and anything that existed only in the cloud will be lost. LAN sync is now the only way to move content between devices. The beta program ended; all features are available without an account (except online play, publishing, and downloading others' content). Database migrations 076–079 were required by v14.0.0; v14.0.1 has no new migrations.

### Changes

- **Removed `StorageUsageBar`** from the save & sync dialog. The bar displayed cloud storage quota and remaining MB, which no longer applies after v14.0.0's cloud sync removal.
- **Tool content docs restructured** — character and world blueprint docs rewritten for clarity; `tool/content/README.md` simplified.

No database migrations. No breaking changes. Upgrade from v14.0.0 is seamless.

---

## Dungeon Master Tool v14.0.0 — No More Beta, No More Cloud Sync

**Release date:** August 2026

Three changes, one release, and they all point the same direction: **your content is yours, on your device, and you decide what leaves it.**

> [!warning] Breaking — read before upgrading
> Cloud backups are gone. Worlds, characters and packages are no longer copied to the cloud, and the copies that were there are deleted. **Anything that existed only in the cloud and not on a device will be lost.** If you were relying on cloud backup to move content between devices, open the app on the device that has the content first, then use LAN sync to bring it across.
>
> Requires database migrations 076–079.

### The beta program is over — everyone gets everything

The 90-slot, admin-approved beta is closed. There is no waiting list, no request form, no slot counter. Download the app and every feature is available, with or without an account.

An account is now required for exactly three things:
- **Playing online** with other people
- **Publishing** to the marketplace
- **Downloading other users' content**

Browsing the marketplace and installing official content need no account at all.

### Cloud sync removed — LAN sync is the way content moves

Your worlds, characters and packages live on your device. Moving them to another device is LAN sync: pair once over your local network (QR code or IP + PIN), then sync with one tap. Nothing passes through a server.

Removed with it: cloud backups, "Make Online" for packages, the sync queue and its status indicators, and the pull-to-refresh cloud fetch on the hub tabs.

### Online play now broadcasts what you share, not your whole world

Previously, a player who joined your world downloaded **the entire world** — every NPC, every map, every session note — and the app simply hid the parts they weren't supposed to see. The data was on their device the whole time.

Now nothing is sent until you share it. Players receive:
- **What you put on the shared screen** — battle maps, images, entity cards, PDFs — live as you place it
- **The cards you hand them** — a shared card now carries its own content, so it arrives complete
- **Their own character sheet**, synced with you both ways
- Packages you share into the world

Everything else — your prep, your notes, your unshared NPCs, your maps — stays on your machine. Joining a world now starts empty and fills in as you share.

### Marketplace is open to everyone

Browse listings and install official content without signing in. Sign in when you want to download something another user made, or publish something of your own.

---

## Dungeon Master Tool v13.1.0 — HP Dice Roller, Entity Deletion Fix, Linux Projection Fix (Beta)

**Release date:** August 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v13.1.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release, and the theme is **combat tracker polish and platform stability**. The encounter HP editor now has a dice button that rolls a creature's HP dice spec (e.g. 2d8+2) and fills both HP and Max HP in one tap. Deleting an entity from the database now closes its tab instead of leaving an empty "Entity not found" page. The mind map's invisible arrowheads are gone — edges now end as clean bezier curves. Stopping a Second Screen projection on Linux no longer crashes the app: the sub-window is hidden and re-shown on the next activate instead of being destroyed. No migrations needed.

---

### Highlights

- **HP dice roller in the encounter editor** — The HP cell now opens a two-field editor (HP + Max HP). A dice button next to Max HP rolls the creature's `hp_dice` spec and fills both fields, so saving sets max HP to the roll and equalizes HP with it (bar fills).
- **Entity deletion closes its tab** — Deleting an entity from the database screen now closes its open tab instead of leaving a blank "Entity not found" page.
- **Mind map arrowheads removed** — Invisible arrowheads drawn behind node fills are gone; edges now end as clean bezier curves at the target center.
- **Linux projection crash fixed** — Stopping a Second Screen projection no longer crashes the app on Linux. The sub-window is hidden on close and re-shown on the next activate.

---

### Combat tracker

#### HP dice roller

**Before (v13.0.1):** the HP cell in the encounter editor showed the current value; rolling a creature's HP dice required a separate manual step.

**After (v13.1.1):** tapping the HP cell opens a two-field editor (HP + Max HP). A dice button next to Max HP rolls the creature's `hp_dice` spec (resolves from the snapshot or the source entity) and fills both fields with the result. Saving sets max HP to the roll and equalizes HP with it.

---

### Bug fixes

- **Entity deletion left an empty tab** — Deleting an entity from the database screen left a blank "Entity not found" page; the tab is now closed automatically. Resolves #79.
- **Mind map edges had invisible arrowheads** — Arrows were drawn at target node centers, hidden behind the node fill; removed entirely so edges end as plain bezier curves. Fixes #81.
- **Linux projection crashed the app** — Stopping a Second Screen projection on Linux crashed because the desktop_multi_window plugin destroyed the sub-window through FlutterEngineRemoveView, which the embedder rejects and segfaults during GL teardown. The plugin is now vendored under `packages/desktop_multi_window` with a patch that hides the window on delete-event and disconnects the engine's own delete-event handler. Fixes #82.

---

### Smaller improvements

- **Theme cleanup** — Unused neon, scroll, goldenrod and vapor palettes removed.
- **Art generation** — New art jobs JSONL file for spell artwork; enhanced prompt generation with deterministic style variations and a grid comparison tool.

---

### Upgrade notes

- **App version bump:** `13.0.1` → `13.1.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **No cloud migrations.**

---

### Known issues

- Carry-over from v13.0.1: Local Sync does not propagate deletions or renames (tombstones are the planned fix); Local Sync is signed but not encrypted; soundpad content does not sync over LAN; raising a character's class level by hand skips the spell-slot grid; same-second edits do not transfer; first-party packs still ship duplicate content; package art is not bundled yet; feat effect parsing stays conservative; smoother large-grid performance, stat-block token previews, and line-of-sight / dynamic vision are still roadmap items.

---

*Thanks for playing. Roll well.*

---

## Dungeon Master Tool v13.0.1 — Combat Tracker Initiative Fixes, Mind Map Right-Click Fixes, Note Titles (Beta)

**Release date:** August 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v13.0.1) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release, and the theme is **the table running without fighting the tool**. Initiative in the combat tracker now behaves the way you expect: combatants join at their flat modifier, "Roll Initiative" rolls fresh every time, and a score you type in the encounter table sticks and re-sorts on the spot. The mind map lets you right-click a connection even inside a workspace, notes can be renamed while you edit them, and clearing a soundpad ambience slot no longer inherits the previous track's volume. Nothing to install by hand — no migrations.

---

### Highlights

- **Initiative joins at the modifier** — A new combatant starts at its flat initiative modifier instead of auto-rolling a d20, and a new **Reset Initiative** action restores the whole table to those modifiers in one tap.
- **Roll Initiative rolls fresh every time** — Re-rolling no longer leaves combatants frozen on a fixed score.
- **Editing initiative sticks** — A score typed in the encounter table now updates and re-sorts immediately, and the inline editor opens blank instead of prefilled with a dice spec.
- **Mind map right-click fixed** — Right-clicking a connection inside a workspace now opens its Delete Connection menu instead of being swallowed by the workspace menu, and connections are easier to grab.
- **Notes can be renamed while editing** — The note edit dialog gains a Title field.
- **Soundpad slots clear cleanly** — Clearing an ambience slot resets it to default instead of keeping the previous track's volume.

---

### Combat tracker

#### Initiative

**Before (v13.0.0):** adding a combatant rolled `1d20 + modifier` automatically; monsters with a flat `initiative_score` sat frozen on that one score no matter how often you re-rolled; typing a new initiative in the encounter table changed neither the value nor the sort order; the inline editor prefilled a dice spec like `+3`; and the mobile card showed that dice spec instead of the rolled value.

**After (v13.0.1):** a fresh combatant joins at its **flat initiative modifier** (no roll), so the DM decides how combat opens — roll with **Roll Initiative** (now re-rolls every combatant each time, no frozen scores) or type a score straight into the table and it updates and re-sorts on the spot. A new **Reset Initiative** menu item (desktop and mobile, under Roll Initiative) restores every combatant to its modifier, undoing a roll in one tap.

### Mind map

#### Right-clicking connections

**Before (v13.0.0):** right-clicking a connection that ran through a workspace's interior opened the workspace menu instead of the connection's menu, so Delete Connection was unreachable there.

**After (v13.0.1):** right-clicking over a connection always opens its menu, even inside a workspace, and the right-click hit radius is widened (24 px) so connections are easy to grab — the visible stroke is unchanged.

---

### Smaller improvements

- **Notes** — The mind map's note edit dialog gains a **Title** field, so you can rename a note while editing its content.
- **Soundpad** — Clearing an ambience slot now resets it to a clean default instead of inheriting the previous track's volume.
- **l10n** — New "Reset Initiative" key added in all four languages (EN · TR · DE · FR).

---

### Bug fixes

- **Editing initiative did nothing** — Typing a new initiative in the encounter table updated neither the value nor the sort order.
- **Monsters never re-rolled initiative** — Combatants with a flat `initiative_score` stayed frozen on one value no matter how often you hit Roll Initiative.
- **Right-clicking a connection inside a workspace did nothing** — The workspace menu swallowed the right-click; the connection's Delete Connection menu is reachable again.
- **Notes couldn't be renamed while editing** — The edit dialog only covered content; it now has a title field too.
- **Ambience slot kept the previous volume** — Clearing a slot inherited the last track's volume; it now resets to default.

---

### Upgrade notes

- **App version bump:** `13.0.0` → `13.0.1`.
- **Local DB:** schema v12, unchanged. No client migration.
- **No cloud migrations.**

---

### Known issues

- Carry-over from v13.0.0: Local Sync does not propagate deletions or renames (tombstones are the planned fix); Local Sync is signed but not encrypted; soundpad content does not sync over LAN; raising a character's class level by hand skips the spell-slot grid; same-second edits do not transfer; first-party packs still ship duplicate content; package art is not bundled yet; feat effect parsing stays conservative; smoother large-grid performance, stat-block token previews, and line-of-sight / dynamic vision are still roadmap items.

---

*Thanks for playing. Roll well.*

*Special thanks to [numerfolt](https://github.com/numerfolt) for the help that went into this release.*

---

## Dungeon Master Tool v13.0.0 — Local Sync, No-Account Mode, PDF Library, Package Links, Pack Content Repair (Beta)

**Release date:** August 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v13.0.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Major release, and the theme is **getting your content where you need it without going through the cloud**. Local Sync moves worlds, packages and characters straight between your own devices over Wi-Fi. The app now has a real no-account mode instead of a compile-time one. Each world gets its own PDF library that the DM can share with the table. Packages can link other packages instead of duplicating them, and the 19 official Open5e packs went through a full content repair pass — thousands of corrected values. Nothing to install by hand: the two in-app content migrations run transparently on first load.

> **Heads-up for self-hosted deployments:** redeploy the Cloudflare Worker before using the PDF library in an online world — sharing a PDF needs the `world_pdf` upload kind (50 MB) and the `application/pdf` MIME allowance. Without the redeploy, local PDF libraries still work; only sharing them with players fails on upload.

> **Heads-up for Local Sync users:** both devices must be signed into the **same account**, and both must have Local Sync open the first time they pair. Local Sync only adds and updates — deleting something on one device does not delete it on the other.

---

### Highlights

- **Local Sync** — Move worlds, packages and characters between your own devices over Wi-Fi, with nothing going online.
- **Continue without an account** — Offline use is now a mode you pick on the landing screen, not a side effect of how the binary was built.
- **PDF Library per world** — PDFs are copied into the world, listed in a Library tab, and shareable with online players on demand.
- **Package Links** — A package can borrow another package's cards instead of shipping a second copy of them.
- **Every ref on a card is a link** — Spells, items and traits inside cards open the card they point at.
- **Spell slot grid on the sheet** — Caster classes get real slots at creation and level-up, with template-authored tables beating the built-in preset.
- **Official pack content repair** — Thousands of corrected and newly filled values across spells, monsters, magic items, backgrounds, feats and subclasses.
- **Images stay put** — Every picked image is copied into the world, so it survives offline, travels with sync, and no longer depends on the cloud copy existing.

---

### Local Sync

#### Pair once, sync with one tap

Open **Local Sync** from the profile menu or the save/sync panel. The panel shows a QR code, a 6-digit PIN and this device's address. On the other device, tap **Add device** and either scan the code or type the address and PIN. Pairing is a one-time handshake that stores a shared secret on both sides; from then on the devices recognise each other and you never see the PIN again. Press **Sync** and every paired device is walked in turn — newer content is pulled, newer local content is pushed, and you get a "N items · M devices" summary at the end. A device that cannot be reached does not stop the run; it is listed when the sync finishes.

Desktop shows the QR code but cannot scan one (camera scanning is Android/iOS/macOS). The address + PIN path works everywhere.

#### What travels, and what deliberately doesn't

A synced world carries everything the cloud backup carries — entities, world schema, encounters, battle map, session notes, mind maps, map data and the PDF library — plus the world's package links and the view you had open (open cards, panel filters, PDF tabs, active sidebar). Window widths, theme, language and volume stay per-device. Media travels two ways: files under the world folder are copied outright, and for images that only exist as cloud references the actual bytes are taken out of the local content cache, so a synced image opens on the other device while offline and signed out.

- **Section-level merge.** If the same world exists on both devices, entities, sessions, map data and each settings block race on their own timestamps — editing combat notes on one device and the mind map on the other no longer means one of them loses everything. On a tie, local wins.
- **Deletions and renames do not propagate.** Only additions and updates cross. A card you deleted on one device comes back if the other device still has it; a locally renamed world keeps its local name and just receives content.
- **The transfer is authenticated, not encrypted.** Every request is signed with the 256-bit pairing secret, only private network addresses are accepted, and a failed pairing attempt is rate-limited without touching pairings that already exist. Body encryption is a later item.
- **Pairings are per account.** A device signed into a different account is refused with a clear message rather than a signature error.

---

### Playing without an account

#### Continue without an account

The landing screen has a second door. Everything that only touches the local database — hub, worlds, characters, packages, templates, bundled content — works with no sign-in at all, and the choice is remembered across launches. Previously the router asked one question ("is there a session?") and bounced every route but the landing screen, so offline use existed only in builds compiled without the backend.

#### Gated surfaces explain themselves

Screens that genuinely need a server no longer disappear or fail silently. The marketplace, cloud backup, online sync and world sharing each show what they are for and offer a **Sign In** button — for example, "Cloud backup copies this item to your account. Local saves keep working without it." Only `/profile` and `/admin` are still hard-redirected, because they render server rows.

#### Signing in brings your offline work with you

Signing in from guest mode promotes the whole offline workspace into the account: the local database (closed cleanly, WAL included), worlds, characters, packages and their media trees. Unowned characters created as a guest are claimed by the account. Once an account has claimed a guest workspace, entering guest mode again starts from an **empty** workspace — the old content lives in the account, not in a shared drawer both can see.

---

### Content & Packages

#### PDF library per world

Every PDF you open from inside a world is copied into that world's folder, so it stays with the world, rides along in cloud backups and moves over Local Sync. The PDF sidebar gains a **Library** tab listing what the world holds, with size and a remove action. Up to 10 PDFs can be open in tabs at the same time; the per-file limit is 50 MB. In an online world the DM shares the library in one action and each player's copy shows the file as "Shared by the DM" with a **Download** button — nothing is force-pushed, so joining a world does not pull 50 MB per book down your connection.

#### Package links

A package can now declare that it borrows another package's content. The two stores stay separate — nothing is copied — but the linked package's cards show up inside the linking package and follow it into every world it is imported into. Open a package, use the **Linked Packages** panel, and pick from what you have installed; cycles are refused with the reason. Deleting a package that others link warns you which ones will stop resolving, and installing a package installs its whole link closure.

- Installing a package into a world now goes through one code path that handles the link closure and remaps references pointing into a linked package.
- First-party packs do **not** use links yet. It was measured: across the whole bundled corpus exactly one card could be linked instead of copied, and declaring it would make five packs pull 2.9 MB of Tome of Beasts at install time. The mechanism ships; the packs stay as they are.

#### Packages tell you when they are out of date

An installed package that came from the official catalog now notices a newer catalog version and offers **Update to v…** on its card.

#### Official pack content repair

The 19 bundled Open5e packs were read end to end against a pinned source snapshot, and every defect found was fixed at the mapper that caused it. Highlights of what actually changed on the cards:

- **Spells** — 164 corrected values on 140 cards. "Permanent" durations stop becoming "Until Dispelled", ranges like "2–12 hours" stop being read as "12 Hours", "1 year" now carries 365 days, 58 fabricated `Material Cost: 0` lines are gone and 39 real component prices were recovered from the text, and self-area spells recover their radius.
- **Monsters** — Truncated stat-block text is recovered from the older source revision, mangled character escapes are cleaned, 114 legendary actions that were also published as at-will actions are de-duplicated, rows whose rule text had been stuffed into the name are recovered, and claims the source never made (`is_attack` on 681 rows) are no longer written. Resistance, immunity and language qualifier sentences now ship beside the lists they qualify.
- **Backgrounds & feats** — Over-granting stops: 30 backgrounds no longer hand out 62 skill proficiencies the source offered as a *choice*. "+1 to X and one other ability" now writes a fixed ability beside a free pick instead of offering all six. Backgrounds can grant languages, subclasses can declare their caster kind (third-casters finally get slots), and 24 subclass spell tables became real references instead of prose.
- **Magic items** — `base_item_ref` went from 0% to 36% (379 items) by reading the structured base-item columns nobody was reading.
- **Names & identity** — 19 cards whose names differed from a built-in card only by spacing or punctuation now resolve to the same card, and a 2024-rules subclass hiding inside a 2014-labelled pack is now distinguishable on its card.
- **Built-in SRD pack (v1.1.0)** — Saving-throw and skill rows for 252 of the 345 built-in creature cards, transcribed from the CC-BY SRD 5.2.1 PDF, plus the class spellcasting tables that feed the new slot grid.

---

### Characters & cards

#### Spell slots reach the sheet

All eight built-in caster classes (full, pact and half) now produce a spell-slot grid, written at character creation and at each level-up. The grid stays a stored, hand-editable field on the sheet, and a template that authors its own `spell_slots_by_level` table wins over the built-in preset — which matters immediately, since the authored half-caster table gives Paladin and Ranger a slot at level 1 where the preset gave them none.

#### Every reference on a card is a link

Relation chips, spell lists, structured list rows and markdown references all open the card they point at, from both the world screen and the package screen. A reference into a pack you do not have installed stays plain text on purpose — the underline appears only where the tap will land, so no link opens an empty dialog.

---

### Media

#### Images are always kept locally

Every image you pick — battle maps, world maps, mind map images, entity images, world/package/character covers, character portraits, entity file and PDF fields — is copied into your data folder, whether or not the cloud upload succeeds, and the upload is made from that copy. Raw picker paths (`.../Downloads/map.png`) are never stored. The practical effect: an image keeps rendering when you are offline, when the cloud object has been swept, and after it moves to another device over Local Sync. Old worlds are repaired once, on load.

The cost of keeping a local copy is duplicated bytes, so removal paths now clean up after themselves: an unused-media sweep runs when a world opens and closes, deleting files under the world's `media/` and `files/` folders that nothing references any more. Snapshots in the trash count as references, and files written in the last 10 minutes are left alone.

---

### Smaller improvements

- **Soundpad** — The sidebar, tab and toggles are consistently called "Soundpad" everywhere; some surfaces still said "Soundmap".
- **Profile menu** — Rebuilt around one authentication check, so the menu shows exactly the items that apply to your state (signed in, guest, or no backend at all) instead of dead entries.
- **PDF tabs** — Up to 10 PDFs open at once, with a message instead of a silent no-op when you hit the limit.
- **l10n** — 80 new keys for Local Sync, the PDF library, package links, account gating and the offline landing option, translated in all four languages (EN · TR · DE · FR).

---

### Bug fixes

- **Maps and sessions came back empty after a restore** — Restoring a world (from cloud backup or Local Sync) onto a device that already had that world silently dropped the incoming map data and session list, because the save path only wrote the settings blob while the load path preferred the dedicated rows. Both halves now agree. This affected every world whose map or sessions had ever been used.
- **Combat log entries disappeared** — Manually added combat log lines were kept in memory only and were lost on the next reload.
- **Species cards with senses crashed the renderer** — Opening a card carrying a granted sense (every Dragonborn / Elf / Dwarf, and any pack species with darkvision) threw while rendering. The same fix restores resource-pool and spell references that had been silently rendering as "—".
- **Packaged feats never applied their ability score increase** — 23 feats with an ASI raised nothing, because the resolver read only one of the three shapes an ability reference can take.
- **The wizard and the sheet disagreed about which card won** — When a package and the built-in pack shipped the same name, the character wizard resolved the built-in card while the sheet resolved the package card. All three code paths now follow one rule: the package you chose wins.
- **Links did nothing on the package screen** — Tapping a reference inside a package's cards was inert, and packaged spells with cross-pack references never appeared in spell lists at all.
- **Subclass grants were missing wholesale** — 101 subclasses granted nothing because a source file was never opened during the pack build.
- **Drow and Derro got no darkvision** — Superior Darkvision was matched by exact name, so species that spell it differently were skipped; ranges are now read from the trait's own text.
- **Startup crash on the built-in pack** — A pack whose level-keyed maps had integer keys crashed the SRD bootstrap at launch.
- **Character card chips showed "—"** — Characters built with a non-built-in package showed empty stat chips on four surfaces, because those surfaces built their own entity map and left the character's own packages out of it.
- **159 invented gear entries are gone** — The importer was fabricating empty `adventuring-gear` cards for every token in a background's equipment prose just so a reference would resolve.

---

### Deprecations & removals

- **The rule-effect DSLs (`rule_effects`, feat `effects`, `granted_modifiers`) are retired** — The engine no longer interprets them. Existing content is converted on load and on package install; anything with no mechanical home becomes a readable `mechanical_notes` line rather than being dropped.
- **`auto_granted_by` is retired** — The edge is inverted so the card that grants a feat or trait owns it, at the level it grants it. Converted automatically.
- **Standalone Open5e SRD packs** — Already dropped in v12; the built-in pack remains the owner of SRD content, and this release extends it rather than reintroducing them.

---

### Upgrade notes

- **App version bump:** `12.1.1` → `13.0.0`.
- **Local DB:** schema v12, unchanged. Local Sync's paired-device table is created on open without a schema bump, so there is no client migration.
- **In-app migrations (both idempotent, both automatic):** retired rule-effect DSLs are converted to named grant fields whenever a world entity is loaded or a package is installed; retired `auto_granted_by` edges are inverted onto their granting card at the same two points. Converted content persists on the next save.
- **Self-hosted deployments:** redeploy the Cloudflare Worker before sharing PDFs online — it needs the `world_pdf` kind (50 MB) and `application/pdf` in the allowed MIME list. Per-kind limits are now authoritative rather than capped by the global ceiling.
- **No cloud migrations** in this release.
- **Re-install a package to pick up the repaired content.** Existing installs keep working with the values they were installed with; nothing is rewritten under you.
- **Local Sync needs an account on both devices**, even though nothing leaves the local network — the account is used to prove the two devices are yours.
- **Existing characters are unaffected** until re-resolved. New spell-slot grids are written at creation and level-up, not retroactively.

---

### Known issues

- **Local Sync does not propagate deletions or renames** — Deliberate for now. A card deleted on one device returns if the other still has it, and a locally renamed world keeps its name. Tombstones are the fix and are not in this release.
- **Local Sync is not encrypted** — Requests are signed with the pairing secret and restricted to private addresses, but bodies are plaintext on the LAN. Encryption is a later item.
- **Soundpad content does not sync over LAN** — Sound libraries live outside the synced data root and can run to gigabytes; soundpacks are downloadable from the catalog on each device instead.
- **Raising a character's class level by hand skips the slot grid** — Slots are written by the wizard and the level-up dialog. Editing `class_levels` directly leaves the previous grid in place with no warning; this is the price of keeping the field hand-editable.
- **Same-second edits do not transfer** — Local Sync's world timestamps have one-second resolution, so two devices that edited the same world within the same second are treated as equal and nothing moves.
- **First-party packs still ship duplicate content** — Package links exist but the official packs do not use them; roughly 21% of bundled entities overlap by name. Deduplicating them is separate work.
- **Package art is not bundled yet** — The generation pipeline exists and the scope is measured (~5,500 art-worthy cards), but default content still renders as text.
- Carry-over from v12.1.1: feat effect parsing stays conservative; subspecies reclassification on legacy packs is heuristic; smoother large-grid performance, stat-block token previews, and line-of-sight / dynamic vision are still roadmap items; official catalog R2 publish awaits worker deploy + licensing sign-off; full WYSIWYG editors for schemas/templates/packages still in progress; Tier-4 combat-tracker-dependent effects pending.

---

*Thanks for playing. Roll well.*

---

## Dungeon Master Tool v12.1.1 — Soundmap Music Stops on Hub Exit (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v12.1.1) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release. Fixes a single bug: music and ambience playing through the Soundmap kept running after the DM or player returned to the Hub screen. No new features, no migrations.

---

### Bug fixes

- **Soundmap: music and ambience no longer continue after "Back to Hub"** — Selecting "Back to Hub" from inside a world now fully stops all Soundmap playback (music, ambience) before navigating to the Hub. Previously the audio engine kept running in the background, with no way to stop it from the Hub screen.

---

### Upgrade notes

- **App version bump:** `12.1.0` → `12.1.1`.
- **Local DB:** unchanged. No client migration.
- **No cloud migrations.**

---

### Known issues

- Carry-over from v12.1.0: feat effect parsing stays conservative; subspecies reclassification on legacy packs is heuristic; smoother large-grid performance, stat-block token previews, and line-of-sight / dynamic vision are still roadmap items; official catalog R2 publish awaits worker deploy + licensing sign-off; full WYSIWYG editors for schemas/templates/packages still in progress; feat-ASI honoring applies only to newly-recorded picks; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

*Thanks for playing. Roll well.*

---

## Dungeon Master Tool v12.1.0

**Release date:** June 2026

### Bug Fixes

- **Battlemap: HP bars now visible in player view** — Fixed an issue where HP bars were not displayed for players even when the DM had "Show HP" enabled. The `showAllHp` flag is now correctly propagated through all broadcast paths (`updateBattleMapSnapshot` and the online patch pipeline).
- **Battlemap: Token sizes now correct in player view** — Fixed an issue where all tokens appeared the same size in the player view regardless of creature size (Large, Huge, Gargantuan, etc.). Full creature-size multipliers are now computed from each combatant's entity and broadcast to players, instead of only sending manual resize overrides.

---

## Dungeon Master Tool v12.0.2 — Package Online Sync, Beta Backstop, Dark-Theme Readability (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v12.0.2) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release. One feature, one gating hardening, two readability fixes. Packages get their own **Online** section in the settings dialog — personal device-to-device cloud sync, the package-tab counterpart to the existing world "Make Online" flow. The beta gate on cloud actions is now also enforced at the provider level so UI paths that skip the pre-check (e.g. the phone overflow toggle) fail with a clear message instead of an opaque server error. Two dark-palette fixes restore unreadable text in structured editors and entity-card markdown.

### Highlights

#### Online sync for packages (`_PackageOnlineSection`)

- The package settings dialog now has an **Online** section mirroring `OnlineWorldSection`. Owners can **Make Online** to push the package to the cloud so it syncs across their own devices, or **Make Offline** to remove the cloud copy. Personal sync only — no invites or sharing.
- Pushes by name with the already-loaded package data, so it works even when the package isn't the active/open one.

#### Beta gate backstop on cloud sync

- `ActivePackageNotifier.makeOnline()` now throws a clear beta-only `StateError` at the provider level, covering UI paths that don't pre-check (the phone overflow toggle). Desktop buttons still pre-check for a nicer message.
- World **Publish** and package **Make Online** both surface the same "join the free beta" snackbar pointing to Settings → Subscriptions.

#### Dark-theme readability

- Mini dropdown fields in structured list editors now inherit the theme's `onSurface` color instead of a hardcoded black that was unreadable on dark palettes.
- Markdown headings and bullets in entity cards now derive their color from the caller's `textStyle` (e.g. `srdInk`) so subsections match the card palette instead of the global `html*` fallback.

---

## Dungeon Master Tool v12.0.1 — Beta Gating, SRD Reference Overlay, Equipment Pick Fix (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v12.0.1) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release. Three bug fixes and two internal improvements. "Make Online" and "Share to Marketplace" now correctly require beta membership (previously the client let any signed-in user trigger these actions and the request failed server-side with an opaque error). The package editor now overlays the full built-in SRD entity catalog as read-only reference rows, so conditions, damage types, spell lists, and other Tier-0 lookups render even when the package being edited carries none of that content. A scoped-key fix in the character resolver prevents class and background equipment picks from overwriting each other when both use the same group ID.

### Highlights

#### Beta gate on cloud actions

- **Make Online (packages)** and **Share to Marketplace** now show a clear snackbar directing non-beta users to Settings → Subscriptions instead of silently failing when the request reaches the server. World "Make Online" already had this gate; the two missing surfaces are now consistent with it.

#### SRD reference overlay in the package editor (`srdReferenceEntitiesProvider`)

- Every package's category lists (conditions, damage types, spells, monsters, …) now render the **built-in SRD entities as read-only reference rows** alongside the package's own content. The overlay is injected into `EntityNotifier` via a new `overlaySrdReference` flag; overlaid rows are tracked in `_referenceEntityIds` and are never written back to the package on save.
- Packages always load with the **live built-in D&D 5e v2 schema** instead of the stored `package_schemas` row, which could become stale or missing and surface a "No template found" error.

#### Bundled pack auto-installer (debug mode)

- A new `BundledPacksBootstrap` service mirrors the SRD bootstrap pattern for the bundled Open5e packs in `assets/open5e_packs/`. In debug builds it re-installs any pack whose on-disk SHA-1 hash differs from the stored `bundled_content_hash`, so freshly regenerated pack content (e.g. background equipment from the importer fix in v12.0.0) is visible immediately without flipping the admin toggle. **No-op in release** — the R2 catalog is the delivery channel there (BB-1: packs are excluded from release bundles). The admin "Install asset packs" toggle now correctly gates the installer; turning it OFF removes the packs and they stay gone.

#### Character resolver — scoped equipment choice key

- Equipment choices are now keyed as `$sourceId:$groupId` instead of `$groupId` alone. Class and background starting-equipment pick groups can share identical group IDs; the old flat key caused one source's selection to silently overwrite the other's, resulting in missing starting gear on new characters.

### Bug Fixes

- **Beta gate missing on package Make Online** — non-beta users saw no error and the server rejected the request silently.
- **Beta gate missing on Share to Marketplace** — same as above; client-side gate now shows a human-readable message.
- **Package editor empty category lists** — Tier-0 lookups (conditions, damage types, etc.) showed empty when a custom package carried none of its own; fixed by the SRD reference overlay.
- **"No template found" on package open** — packages with a missing or stale `package_schemas` row errored on load; now always resolved to the live built-in schema.
- **Equipment picks collision** — class and background starting-equipment picks with the same `group_id` overwrote each other in the character resolver.

### Internal / Developer

- `BundledPacksBootstrap` service + `bundledPacksBootstrapProvider` — content-hash gated debug installer for the Open5e asset packs; warm-start cost is ~22 cheap DB reads.
- `srdReferenceEntitiesProvider` — cached Riverpod provider that parses the installed SRD pack into typed `Entity` objects (all categories, marked `linked: true`).
- `EntityNotifier` gains `overlaySrdReference` constructor flag and `_applyReferenceOverlay()` — overlay ids tracked in `_referenceEntityIds` to prevent accidental persistence.
- `packageEntitiesProvider` calls `bundledPacksBootstrapProvider` before reading so the wizard/editor always sees current bundled pack content.

---

## Dungeon Master Tool v12.0.0 — SRD Content Consolidation, Unified Banner Art, Open5e Import Quality, Final Anon Lockdown (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v12.0.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Major release. The bundled D&D 5e content gets a **consolidation pass**: the redundant standalone SRD 5.1 / 5.2 Open5e packs are dropped (the built-in `srd_core` already covers ~99% of them via the 2024 renames + generic base items), the two Open5e "Originals" packs merge into one, and the 14 magic items + 7 spells that were only available in those packs are **ported into the built-in `srd_core` pack** (now **v1.0.3**) so nothing is lost. Card banner art is rebuilt around a **single shared 5:2 geometry** so worlds, packages, templates, marketplace, and game-listing cards all render banners identically on mobile and desktop, with re-cropped/optimized source art and per-banner attribution. The Open5e importer gets two quality fixes — **monster entity-name sanitization** and **chargen rule-mechanic wiring** that was silently dropping feat/background effects — and migration **074** closes the last anonymous attack surface flagged by the Supabase linter. No local DB migrations.

### Highlights

#### SRD content consolidation (`srd_core` v1.0.3)

- **Redundant SRD packs dropped** — The standalone Open5e SRD 5.1 and SRD 5.2 packs are removed; the built-in `srd_core` pack already reproduces ~99% of their content through the 2024 entity renames and generic base items, so shipping them as separate installable packs was duplication. The two Open5e "Originals" packs are merged into a single pack.
- **14 magic items + 7 spells ported into the built-in pack** — Gaps that previously lived only in the now-dropped packs are folded into `srd_core` (bumped to **v1.0.3**): Amulet of Proof against Detection and Location, Arrow-Catching Shield, Candle of Invocation, Cloak of Arachnida, Cloak of the Manta Ray, Dagger of Venom, Elemental Gem, Eversmoking Bottle, Horseshoes of a Zephyr, Javelin of Lightning, Ring of Jumping, Ring of X-ray Vision, Staff of Thunder and Lightning, and Wand of Secrets, plus seven missing spells. 2014-only content is intentionally not carried over.

#### Unified banner art

- **One shared banner geometry (`banner_metrics`)** — World / package / template / marketplace / game-listing cards previously each computed their own banner box (some fixed-height, some cover-cropped), so the same art rendered differently per surface. A new shared `kBannerCoverAspect` (5:2), `kBannerCoverCacheWidth`, and `kCardMaxWidth` make every top-banner surface use one fixed `AspectRatio` box with `cacheWidth`-bounded decode, so source banners (cropped to 5:2) display in full with no edge-crop, identical on mobile and desktop.
- **Re-cropped & optimized source art** — The first-party banner set is re-cropped to 5:2 and recompressed (`optimize_banners.py`, `crop_banners_gui.py`), the official 2024 banner is added, and the dropped SRD 5.1/5.2 banners are removed. A `banner-credits.yaml` records per-banner attribution.

#### Open5e import quality

- **Monster entity-name sanitization** — Upstream Open5e v2 splits some stat blocks (numbered option lists, roll tables, tiered effects, flavor paragraphs) into phantom action/trait rows whose `name` is junk, which shipped as nonsensical card titles ("1", "1-4: Arm", "Npc: Warlock Of The Genie Lord", "An acolyte is a priest in training…"). New `_cleanChildName` / `_cleanMonsterName` strip the `Npc:` prefix and lowercase title small-words, recover a bold label from the description for purely-numeric names, strip leading list-counts and leaked attack clauses, reduce "Label: effect sentence" to the label, and drop truly-spurious fragments (the parent skips the ref so no orphan ships). Re-scan of residual-bad names = 0; no monster loses all its actions; 0 dangling refs. Packs `a5e-mm`, `ccdx`, `tob`, `tob3` regenerated.
- **Chargen rule-mechanics wiring** — The importer left several build mechanics in prose the runtime already consumes, so feats/backgrounds silently dropped their effects:
  - **Background floating ASI** — A5E "+1 to X and one other ability score" emitted only `[X]`; the resolver gates `background_asi` by that list and dropped the floating pick. Widened to all six abilities for the "one other" phrasing (27 backgrounds, e.g. Acolyte).
  - **Feat ASI of-your-choice** — `_parseFeatAsi` now also matches "An ability score of your choice increases by N" / "Choose one ability score … increases by N" (Destiny's Call, Tenacious) → `asi_amount` + all-six options.
  - **Feat skill/tool choices** — new `_parseFeatChoiceGroups` emits a `skill_or_tool` `choice_group` for "choose N skills/tools" (Skillful, Crafting Expert), which `seedFeatChoicePendings` turns into a pick prompt; a negative lookahead keeps A5E subsystems and per-use combat "choose" out.
  - **Skill-proficiency prerequisites** — parsed into a `skill_proficiency` prereq clause (Floriographer, Part of the Pack); junk `*N/A*` prerequisites stripped. The resolver dialog gets a matching `skill_proficiency` case in `_passesPrereqClauses` (OR semantics, reuses `existingSkillNames`).
  - Packs `a5e-ag`, `a5e-ddg`, `a5e-gpg`, `tdcs`, `toh` regenerated. `monster_mapper_check` green; build 0 unresolved refs; analyze clean.

#### Security — final anon lockdown (migration 074)

- **Internal helper locked to definer-internal calls** — `_assert_admin_rate_limit()` is only ever called from inside other `SECURITY DEFINER` RPCs (where the EXECUTE check is against the function *owner*), so all client-role EXECUTE is revoked. Drops it from linter rule 0029.
- **Anon beta oracles closed** — 073 left `is_beta_active(uuid)` and `get_beta_status()` on `anon` as "pre-login required", but the code disproves that — both are only called after sign-in, and no anon RLS path reaches them. `is_beta_active(uuid)` was a per-uuid "is this user a beta member?" oracle (ids leak from community posts/listings) and `get_beta_status()` leaked the free-slot count to everyone. Anon EXECUTE revoked; `authenticated` / `service_role` preserved, so real users are unaffected. Linter rule 0028 (anon) → 0. Bodies unchanged, grants-only, idempotent.

### Upgrade notes

- **App version bump:** `11.2.0` → `12.0.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **Cloud migration:** `074_lock_internal_helper.sql` — permission-only (REVOKE), no function bodies change, idempotent. Apply via Supabase Dashboard → SQL Editor. Apply after `072` / `073` if those have not been run yet.
- **Bundled packs rebuilt** — `srd_core` is now v1.0.3 (the ported magic items/spells); the redundant SRD 5.1/5.2 Open5e packs and one duplicate Originals pack are gone, and the regenerated Open5e packs carry the sanitized monster names + wired feat/background mechanics. Re-install a pack to pick up the richer data; existing installs keep working.
- **Existing characters/worlds are unaffected** until re-resolved. Ported magic items/spells are immediately available in pickers; wired feat/background mechanics apply on the next wizard or level-up pass.

### Known issues

- **2014-only SRD content dropped intentionally** — Content unique to the 5.1 (2014) packs that has no 2024 analogue is not carried into `srd_core`.
- **Monster-name recovery is heuristic** — Sanitization keys on description bold labels / list markers; an upstream row with no recoverable label is dropped rather than renamed.
- Carry-over from v11.2.0: feat effect parsing stays conservative (unconditional armor/shield/speed/Tough-HP grants only); subspecies reclassification on legacy packs is heuristic; shape color picker is per-layer; smoother large-grid performance, stat-block token previews, and line-of-sight / dynamic vision are still roadmap items; official catalog R2 publish awaits worker deploy + licensing sign-off; full WYSIWYG editors for schemas/templates/packages still in progress; feat-ASI honoring applies only to newly-recorded picks; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v11.2.0 — Official-Pack Characters Resolve Everywhere, Typed Feat Prerequisites, Email Confirmation Fix, RPC Security Hardening (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v11.2.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v11.1.0. Closes the loop opened in v11.1.0: a character built from an **official / imported package** now resolves its packaged refs on **every card surface**, not just inside the wizard — the editor, header stat chips, and resolver all layer the character's `source_packages` on top of the bundled SRD through one shared helper, so worldless official-content characters stop rendering empty header chips and count-but-empty granted fields. Feat prerequisites graduate to **typed `prereq_clauses`** (ability-OR, spellcasting, armor/weapon proficiency) honored in both the wizard and the level-up resolver, and the Open5e importer now emits those clauses plus feat ASI bumps, conservative feat effect grants, and structured background equipment choices. Two infrastructure fixes ride along: **email confirmation** moves to a hosted `token_hash` page (the old PKCE `?code=` link never confirmed), and migrations **072/073** pin function `search_path` and strip anon `EXECUTE` from every `SECURITY DEFINER` RPC. No local DB migrations; the Open5e packs are rebuilt with subspecies reclassification reflected in the manifest counts.

### Highlights

#### Official-pack characters resolve on every surface

- **One shared package-layering helper (`layerCharacterPackages` / `sourcePackagesOf`)** — A worldless character built from an official package stamps its `source_packages` on the PC entity, but only the editor's private helper re-layered them — the resolver, header chips, and stat strip still resolved against bundled SRD alone, so packaged species/class/subclass/feat refs dereferenced to nothing. Lifted into `package_source_entities.dart` and wired through `effectiveCharacterProvider`, `readCharacterEntities` (header chips), and the editor's `_readEntitiesFor`, so all card surfaces layer the character's packages on top of the campaign/SRD base identically. Packages still loading contribute nothing yet; each `watch` re-runs when its future settles.
- **No raw UUIDs leak onto the sheet** — `ResolvedGrantsCard._nameOf` now maps an unresolved entity id that *looks like a UUID* to "Unknown" instead of printing the raw `xxxxxxxx-…` string (official content that hasn't loaded). Synthetic ids (`pool:rage_uses`, …) aren't UUIDs, so they still pass through for prettifying.
- **Entity pickers surface package + SRD options with their source** — Char-sheet relation fields pass the character's package entities to `showEntitySelectorDialog` as `extraEntities`, merged on top of campaign + bundled SRD and **deduped by `(slug, name)`** so an option picked from an official pack at creation stays addable afterward. Each row's subtitle now shows the source (`spell · System Reference Document 5.2`) so duplicate-named rows are distinguishable.

#### Typed feat prerequisites (`prereq_clauses`)

- **Resolver gates on the full clause set** — The pending-choice feat picker (wizard *and* level-up) now prefers a feat's typed `prereq_clauses` over the flat single-ability fields: `ability_min` with an **OR** option list ("Strength **or** Dexterity 13"), `character_level`, `spellcasting`, `armor_proficiency`, and `weapon_proficiency` (simple/martial/any). Unknown / `other` clauses never block (display-only). The editor resolves the live working copy first, so eligibility reflects current proficiencies and spellcasting, not just ability scores. Built-in feats without clauses fall back to the legacy ability + level fields unchanged.
- **Importer emits the clauses** — `_parseFeatPrereq` now captures an OR/AND/comma ability group sharing one minimum ("Strength or Dexterity 13+") and keeps **every** option, plus character-level, spellcasting, and armor/weapon proficiency gates, alongside the back-compat flat fields.

#### Open5e importer — feat ASI, effects, background equipment

- **Feat ASI bumps parsed (`asi_amount` / `asi_max_score` / `asi_ability_options`)** — Both SRD-2024 ("Increase your X or Y score by N, to a maximum of M") and A5e ("Your X or Y score increases by N…") phrasings, plus "increase one ability score of your choice" (all six), so half-feats actually offer their ability bump.
- **Conservative feat effect grants** — `_parseFeatEffects` emits only high-confidence unconditional grants the resolver knows: armor/shield `proficiency_grant`, flat `speed_bonus`, and Tough-style `hp_bonus_per_level`. Grant parsers read the benefit text **without** the prerequisite line, so "proficiency with Light armor" as a *prereq* is never misread as a *granted* proficiency.
- **Background equipment A/B prose → structured choice** — SRD-2024 backgrounds ship starting gear as `"*Choose A or B:* (A) <items>, N GP; or (B) 50 GP"` prose; `_parseEquipmentChoiceProse` turns it into pickable `equipment_choice_groups` (gold always captured; items become a hard `ref` only when they resolve in-pack, so the build stays safe) instead of losing it to a note.

#### Wizard & editor polish

- **Choice-less granted feats shown read-only** — Origin feats with no sub-choice (Alert, Tough, …) used to leave the feats step blank ("No sub-choices needed"). They now render a read-only `_GrantedFeatCard` with name, source badge, and collapsible description, so the player sees what they received. The expensive ~7 K-entry bucket cache is only built when an interactive picker actually needs it.
- **Level-up table collapsed by default** — The 20-row class level-up table in the editor and the wizard's subclass step is now wrapped in a new `ExpandableSection` ("Show level-up table"), so reference detail no longer dominates the step.

#### Email confirmation & RPC hardening

- **Email confirmation via hosted page** — Email sign-up confirmation used the default PKCE `?code=` link, whose `code_verifier` lives only in the app instance that called `signUp` — so the emailed link (landing on a browser / `localhost:3000`) could never complete confirmation. Confirmation now goes through a hosted static page using `token_hash` + `verifyOtp` (server-verifiable, no `code_verifier`), which works on every platform with no deep-link / URL-scheme registration. The OAuth/auth redirect scheme is also lifted into one `_authRedirect` constant. Setup steps in `docs/email_confirmation_setup.md`.
- **Migration 072 — pin `search_path`** — Ten functions flagged by the Supabase security linter (`function_search_path_mutable`) get `SET search_path = public, pg_temp`. Bodies and `SECURITY` attributes unchanged; idempotent.
- **Migration 073 — revoke anon `EXECUTE`** — Strips anonymous `EXECUTE` from every `public` `SECURITY DEFINER` RPC. 072's `REVOKE … FROM anon` was a no-op (anon inherits the default `PUBLIC` grant), so 073 revokes from `PUBLIC` after explicitly re-granting the captured `authenticated` / `service_role` access — anon closes, everything else keeps today's access. Deliberate pre-login RPCs (`is_beta_active`, `get_beta_status`, `whoami`) are allowlisted. Defense-in-depth: admin RPCs already self-guard with `is_admin()`.

### Upgrade notes

- **App version bump:** `11.1.0` → `11.2.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **Cloud migrations:** `072_security_hardening.sql` then `073_revoke_anon_execute.sql` — apply in order via Supabase Dashboard → SQL Editor. Permission-only; no function bodies change, no data change, both idempotent.
- **Email confirmation requires the hosted confirm page** — Deploy `confirm/index.html` to the user-pages site and point the Supabase email template at `token_hash` per `docs/email_confirmation_setup.md`. Until then, email sign-up confirmation stays broken (OAuth sign-in is unaffected).
- **Open5e packs rebuilt** — Bundled `assets/open5e_packs/*.pkg.json` regenerated with feat ASI/effects/prereq clauses, background equipment groups, and subspecies reclassification (manifest counts now split `species` / `subspecies`). Re-install a pack to pick up the richer feat/background data; existing installs keep working.
- **Existing characters are unaffected** until re-resolved. Worldless official-content characters render their packaged refs immediately on reopen (no migration); packaged feat prerequisites/ASI apply on the next wizard or level-up pass.

### Known issues

- **Feat effect parsing is conservative** — Only unconditional armor/shield/speed/Tough-HP grants are emitted; conditional, PB-scaling, or "of your choice" benefits stay in the folded narrative.
- Carry-over from v11.1.0: subspecies reclassification on legacy packs is heuristic (keys on the `*Subspecies of X.*` prefix); shape color picker is per-layer; smoother large-grid performance, stat-block token previews, and line-of-sight / dynamic vision are still roadmap items; official catalog R2 publish awaits worker deploy + licensing sign-off; full WYSIWYG editors for schemas/templates/packages still in progress; feat-ASI honoring applies only to newly-recorded picks; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v11.1.0 — Imported-Pack Chargen, First-Class Subspecies, Hub Filters (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v11.1.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v11.0.0. Closes the gap between the **Open5e import pipeline** (shipped in v10.1.0) and the **character creation wizard**: packaged content — subclasses, origin feats, spell lists, weapon masteries, feat prerequisites — now resolves into chargen instead of being silently dropped. The cause was a single shape mismatch: built-in SRD content stores resolved entity-id strings, while imported packs store cross-pack `softRef` envelopes (`{slug, name}`) the wizard's `is String` reads ignored. One shared resolver (`entity_ref.dart`) now reads both everywhere. **Subspecies** become a first-class category (subclass-parity), the hub gains **list filters**, and the Open5e build tool recovers spell→class linkage missing from the v2 dataset. No DB migrations; the local schema self-heals the new category at load.

### Highlights

#### Imported-pack chargen now resolves packaged content

- **One ref resolver across the wizard (`entity_ref.dart`)** — Lifted `CharacterResolver`'s three-envelope resolution (plain id string · `{_ref, name}` · `softRef {slug, name}`) into a shared `resolveEntityRef` / `findEntityIdByName`. Every wizard + level-up site that read only `is String` (subclass `parent_class_ref`, background `origin_feat_ref`, `mastery_ref`, feat `category_ref`/`variant_of_ref`) now resolves softRefs too, so packaged content stops vanishing. Name matching is qualifier-tolerant (`"Magic Initiate (Cleric)"` → `"Magic Initiate"`) and O(1) via an Expando-cached `(slug,name)→id` index keyed on the entity map.
- **Spells match by class tag, not just UUID** — SRD spells link to a class by `class_refs` UUID; imported packs instead carry the bare class name in `tags` (`["Wizard"]`). The spells step, the creation-time feat spell-list picker, and the level-up `_featChoiceOptions` (Magic Initiate, etc.) now accept **either** (`byRef || byTag`), so packaged spell lists populate.
- **Feat ability prerequisites enforced** — Pending-choice feat options now honor `prereq_min_score` + `prereq_ability_ref`, mapping the ability entity back to its STR…CHA key and hiding feats the character doesn't qualify for.
- **Source labels + expandable descriptions** — New `SourceBadge` shows where each chargen option came from (e.g. "System Reference Document 5.2", "Adventurer's Guide") next to feats, spells, and subclasses. New `ExpandableMarkdown` collapses long packaged descriptions to a 2-line plain-text preview (markdown stripped, no leaking `###`) and expands into a fixed-height scroll box at the same font size. Relation-list fields skip the inline description dump for class/subclass/species/background/feat chips.
- **Unstructured background equipment surfaced** — Imported backgrounds carry no `equipment_choice_groups` — their starting gear lives only as prose. The equipment step now extracts the description's `### …Equipment…` section into an info card so the player adds it by hand instead of losing it silently.
- **Int-faced hit dice normalized (`canonicalHitDie`)** — Built-in classes store `"d8"`; imported packs store the int `8`. Both now canonicalize to `"dN"` before the HP-table lookup so packaged classes compute HP correctly.

#### First-class subspecies

- **`subspecies` category (subclass-parity)** — Subspecies/lineage becomes its own entity category with a `parent_species_ref` (the analogue of `subclass.parent_class_ref`), wired through the resolver, wizard picker, and editor. The character entity carries a matching `subspecies_id`.
- **Legacy reclassification on import** — Older packs emitted subraces as `species` entities marked only by a `*Subspecies of X.*` description prefix. The package installer now promotes those to `subspecies` and synthesizes the parent softRef; new packs already ship slug `subspecies` + `parent_species_ref`, so it's a no-op for them.
- **World schema self-heal** — A built-in world whose stored schema snapshot predates the `subspecies` category now overlays any missing built-in category at load (custom/Tier-2 categories preserved, snapshot untouched on disk), so existing worlds surface it without a per-world migration.

#### Hub list filters

- **Filter worlds / packages / characters** — A header filter button opens a multi-section dialog: worlds filter by template + attached package, packages by template, characters by template + world. Within a dimension selections OR; across dimensions they AND. A badge shows the active count; selection is in-memory (resets on restart). Backed by a new `worldPackageNamesProvider` (world→package-name set from the `world_packages` junction) and an `installedWorldPackageIdsProvider` stream.

#### Species innate movement speeds

- **Fly / swim / climb / burrow** — The resolver now reads absolute `speed_fly_ft` / `speed_swim_ft` / `speed_climb_ft` / `speed_burrow_ft` carried on a species (packaged Open5e species + homebrew), keeping the larger value per mode against any effect-granted speed.

#### Open5e build tool — spell class linkage recovered

- **v1 `dnd_class` fallback index** — The Open5e v2 fixtures leave `Spell.classes` empty for most 3rd-party docs (KP / ToH / Warlock / A5E), so those spells shipped with no class link. `build_packs.dart` now indexes each `v1/<doc>/Spell.json`'s comma-string `dnd_class` by spell name, with a doc-scoped overlay (verified by spell-count parity) over a canonical-SRD-first global fallback, and `mapSpells` recovers the class tags when v2 has none (alias-fixed: `Sorceror` → `Sorcerer`). All 8 Open5e packs rebuilt with populated spell class tags.

### Upgrade notes

- **App version bump:** `11.0.0` → `11.1.0`.
- **Local DB:** schema v12, unchanged. No client migration. The `subspecies` built-in category self-heals onto existing built-in worlds at load.
- **No new cloud (Supabase) migrations.** Pure client + build-tool work.
- **Open5e packs rebuilt** — The bundled `assets/open5e_packs/*.pkg.json` are regenerated with spell class tags (and subspecies reclassification on install). Re-install a pack to pick up the new spell links; existing installs keep working.
- **Existing characters are unaffected** until re-resolved. Packaged subclasses / origin feats / spell picks become selectable on the next pass through the wizard or level-up.

### Known issues

- **Subspecies reclassification is heuristic on legacy packs** — Promotion keys on the `*Subspecies of X.*` description prefix; a legacy subrace lacking that marker stays a plain `species` until the pack is rebuilt.
- Carry-over from v11.0.0: shape color picker is per-layer (no per-shape picker); smoother large-grid performance, stat-block token previews, and line-of-sight / dynamic vision are still roadmap items; official catalog R2 publish awaits worker deploy + licensing sign-off; full WYSIWYG editors for schemas/templates/packages still in progress; feat-ASI honoring applies only to newly-recorded picks; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v11.0.0 — Battle Map Becomes a VTT: AoE Templates, 5e Diagonals, Creature-Size Tokens, Vector Annotations (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v11.0.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Major release. The battle map graduates into a proper **VTT**. Five feature areas land together: area-of-effect templates (cone / line / sphere / cube / sector), 5e diagonal measurement rules, creature-size token auto-scaling, vector shape annotations on layered surfaces, and a set of per-player projection controls (Show All HP, Hide Token HUD, hidden DM-only tokens, DM-driven viewport sync). Everything renders identically on the DM canvas and the projected player view through a shared geometry core, and the projection snapshot schema bumps to v4 (additive, backward-compatible). No DB migrations — new encounter state rides the existing `combat_state` JSON.

### Highlights

#### AoE templates (new)

- **Five 5e template shapes** — Cone, line, sphere (circle), cube (square), and sector (pie wedge), driven by pure geometry functions (`aoeConePath`, `aoeLinePath`, `aoeSectorPath`, `aoeSquareRect`) in the new `grid_distance.dart` so the DM painter and the player painter build identical vertices. Sectors place in two stages: drag radius, then drag the sweep angle (defaults to a 90° wedge).
- **Persistent, colored, projected** — Templates carry a fill color (`MeasurementMark.colorHex` / `sweepDeg`), persist across reload, and stream to every connected player. Origins snap to the grid intersection when grid-snap is on.

#### 5e diagonal measurement (new)

- **Three diagonal rules (`DiagonalRule`)** — `euclidean` (default, `√(dx²+dy²)`), `fiveTenFive` (DMG alternating 5/10 ft, `max + floor(min/2)`), and `fiveFiveFive` (PHB Chebyshev, all squares 5 ft). DM picks from a toolbar dropdown (Euclid / 5-10-5 / 5-5-5).
- **Labels match on the player view** — `gridDistanceFeet()` is the single distance calculator for ruler, circle, and AoE labels on both the DM canvas and the projection; the chosen rule rides the snapshot (`diagonalRule`) so player distance labels agree with the DM's.

#### Creature-size token auto-scaling (new)

- **Tokens size to their D&D footprint** — New `CreatureSize` value object (tiny → gargantuan) and `tokenCellSpan()` resolve a token's grid span (Tiny 0.5, Medium 1, Large 2, Huge 3, Gargantuan 4). `BattleMapSnapshotBuilder` computes per-token `tokenSizeMultipliers` so a Huge creature renders 3×3 with no manual resize — a DM-set manual multiplier still wins when present.
- **Three storage forms resolved** — `creatureSizeName()` reads a plain enum string, a UUID `size_ref` relation, or an unresolved `{_lookup:'size', name:…}` seed placeholder, falling back to Medium.

#### Vector shape annotations (new)

- **Rectangles, lines, text labels (`MapShape` / `ShapeKind`)** — Drawn on three layers (`ShapeLayer`: background under fog/tokens, object over tokens, **gm** DM-only). GM-layer shapes are filtered out **on the send side** and never reach players. Each shape carries its own color, stroke width, fill flag; text labels carry font size and are drag-to-move with the navigate tool.
- **Individually deletable, individually persisted** — Shapes serialize to a versioned scene blob (`{"v":1,"shapes":[…]}`, `sceneVectorJson`) and pen strokes now persist as their own `strokesData` vector JSON instead of being baked into the annotation bitmap, so every stroke and shape stays separately erasable across reload. The drag-eraser (`eraseMarksAt`) removes any stroke, shape, or measurement the pointer crosses.
- **Merged draw-tools picker (`DrawToolsButton`)** — A single toolbar button opens a grid popup of all 10 draw/measure/AoE/shape tools; the button icon tracks the last-used tool.

#### Per-player projection controls (new)

- **Show All HP** — DM toggle reveals monster/NPC HP (bar on the map + numeric in the initiative sidebar) to players; off by default.
- **Hide Token HUD** — Suppresses the HP bar and condition badge under tokens on the player projection for a cleaner board when the sidebar already carries the info.
- **Hidden DM-only tokens** — `hiddenTokenIds` ghosts a token on the DM map and omits it entirely from the player view (not merely dimmed).
- **Viewport sync** — The DM's zoom/pan streams to players as a `NormalizedRect` (0..1 coords) at ~30 Hz; players mirror the DM's framing with no letterbox padding. Drawings/fog/grid stream on a separate ~80 Hz throttle, with fog re-encoded only when dirty.

### Upgrade notes

- **App version bump:** `10.2.0` → `11.0.0`.
- **Local DB:** schema v12, unchanged. No client migration. New encounter fields (`diagonalRule`, `sceneVectorJson`, `showAllHp`, `hideTokenHud`, `hiddenTokenIds`, `strokesData`) ride the existing `combat_state` JSON — no Drift columns.
- **No new cloud (Supabase) migrations.** Pure client-side VTT work.
- **Projection snapshot v4** — The `shapes` field is additive and tolerant; older clients/rows omit it and default to `[]`. Mixed-version tables (DM on v11, player on an older build) degrade gracefully.
- **Existing encounters are unaffected** — Diagonal rule defaults to Euclidean (the previous behavior); no shapes/AoE until the DM draws them.

### Known issues

- **Shape color picker** — Shapes use a per-layer default color in v1; a per-shape color picker is not wired yet.
- Carry-over from v10.2.0: smoother large-grid performance, stat-block token previews, and line-of-sight / dynamic vision are still roadmap items; official catalog R2 publish awaits worker deploy + licensing sign-off; full WYSIWYG editors for schemas/templates/packages still in progress; feat-ASI honoring applies only to newly-recorded picks; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v10.2.0 — Marketplace Contents Preview, Official Package Details & Banner Art (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v10.2.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v10.1.0. Makes the Marketplace tell you what an item *contains* before you download it: publishing now captures a compact content summary (template name + per-category entity counts and names) stored on the listing, which drives a richer card and a new preview dialog — no full-payload fetch required. The Official Content channel gains a parallel details dialog and ships banner art that downloads from the CDN and becomes the installed package's local cover. One bug fix: publishing no longer silently no-ops when the client-side beta flag is stale.

### Highlights

#### Marketplace contents preview (new)

- **Publish-time content summary (`buildListingContentSummary`)** — On publish, a single builder walks the world/package payload (`entities` grouped by `world_schema` category) into a compact `{template, categories:[{slug, name, count, names, overflow}]}` summary. Name lists are capped (500/category) with the surplus reported as `overflow`; characters and schema-less payloads summarise to `null`. Stored alongside a `template_name` column so the card subtitle and preview don't pull the gzip payload.
- **Marketplace preview dialog + richer cards** — A new preview dialog renders the captured summary as collapsed per-category sections (counts + names), and the listing tile (`MarketplaceListingTile`) surfaces template name and totals on the card. Both degrade gracefully on pre-existing listings that have `NULL` summary columns.
- **Migration 071 — two read-only listing columns** — `marketplace_listings.template_name` (TEXT) and `content_summary` (JSONB), captured at publish time. `publish_listing_snapshot` recreated with two appended optional params (`p_template_name`, `p_content_summary`); still beta-gated server-side. Old listings keep `NULL` and backfill on re-publish; the immutability trigger needs no change.

#### Official Content channel

- **Official package details dialog (`OfficialPackageDialog`)** — A first-party-catalog parallel to the marketplace preview: opened from an official card's Get button (or tap), it shows pills (template / license / version), per-category entity counts from `CatalogEntry.counts`, and installs through the `firstPartyInstallProvider` state machine.
- **Banner art → local cover** — Official banners now ship as JPEG (`{worker}/catalog/banners/<slug>.jpg`); the bundled built-in template + SRD-package banners switch PNG → JPG (~20× smaller). At install, `FirstPartyCatalogService.fetchBanner` downloads the banner and `CoverImageBundler.restore` materialises it as the local package cover, so the Packages tab shows the same art. Missing/offline banners degrade silently.
- **Upload helper (`cloudflare/upload_banners.sh`)** — Script to push the banner set to the R2 worker under `catalog/banners/`.

#### Fixes

- **Publish no longer silently no-ops on stale beta flag** — The publish path used a client-side `isBetaActiveProvider` pre-check that could be stale-false (async / offline refresh), swallowing the publish with no error. Removed: the `publish_listing_snapshot` RPC is the authoritative beta gate (migration 057), and any `42501 beta membership required` now surfaces through the dialog's catch instead of a silent return.

### Upgrade notes

- **App version bump:** `10.1.0` → `10.2.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **Cloud migration:** `071_marketplace_listing_summary.sql` — adds the two read-only listing columns and recreates `publish_listing_snapshot` with the two new optional params. Apply via Supabase Dashboard → SQL Editor. Pure additive; existing listings keep `NULL` and backfill on re-publish.
- **Banner upload (optional):** run `cloudflare/upload_banners.sh` to publish official banner art to the R2 worker. Without it, official packs still install (banner just absent).

### Known issues

- **Content summary backfills on re-publish only** — Listings published before migration 071 show no contents breakdown until re-published.
- Carry-over from v10.1.0: official catalog R2 publish awaits worker deploy + licensing sign-off; full WYSIWYG editors for schemas/templates/packages still in progress; feat-ASI honoring applies only to newly-recorded picks; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v10.1.0 — Official Content Channel, Open5e Import Pipeline (Beta)

**Release date:** June 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v10.1.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v10.0.0. Adds an app-owned **Official Content** channel: a curated catalog of first-party packages served from a public Cloudflare R2 endpoint and surfaced inside the Marketplace, with a bundled offline fallback so the packs install without a network. Behind it sits a new offline **Open5e import pipeline** that maps the Open5e API into shareable, chargen-wired packages — 22 packs (≈31 MB) covering 3,540 monsters, 1,955 spells, 2,319 magic items, and full character-creation data (26 classes, 125 subclasses, 63 species, 58 backgrounds, 91 feats). No DB changes; the catalog is read-only on the client and admin-gated on write.

### Highlights

#### Official Content channel (new)

- **First-party catalog served from R2** — New Cloudflare Worker `catalog/*` routes: public `GET` (per-IP hourly rate limit, `manifest.json` short-cached, versioned payloads cached hard/immutable) and `Bearer ADMIN_TOKEN`-gated `PUT`/`DELETE` for publishing and retiring versions. Objects live under the `catalog/` R2 prefix as `catalog/{type}/{slug}@{ver}.json.gz`.
- **Read path with offline fallback (`FirstPartyCatalogService`)** — Resolves the catalog online (R2 manifest → gzipped payload) and degrades to the bundled `assets/first_party/manifest.json` when the worker URL is unset, offline, or a fetch fails. Unlike the soundpack service it never surfaces an offline error — official packs stay installable without a network.
- **Marketplace surface (`OfficialPackagesCatalogView`)** — The Marketplace **All** and **Packages** tabs render the official catalog below the Supabase listings, each entry with an Install / Installing… / Installed action. Pull-to-refresh invalidates the catalog; an empty Supabase feed yields to the catalog instead of an empty state.
- **Publish CLI (`tool/catalog_publish`)** — `build_catalog.dart` assembles `assets/first_party/manifest.json` from the bundled packs; `publish_catalog.dart` uploads manifest + payloads to the worker behind the admin token.
- **Admin asset-pack installer** — A dashboard toggle installs/removes the shipped `assets/open5e_packs/` content locally (stamped `metadata.installed_from = 'assets'`, tagged "(assets)" in the package list) so a maintainer can inspect the bundled content and diff it against a published version.

#### Open5e import pipeline (new)

- **Offline import tool (`tool/open5e_import`)** — Maps the Open5e dataset into the app's package/entity schema: dedicated mappers for monsters, spells, magic items, and chargen (classes/subclasses/species/backgrounds/feats), plus normalization, a cross-pack reference graph (`softRef`), and a monster-mapper sanity-check harness.
- **22 shareable packages (≈31 MB)** — Bundled under `assets/open5e_packs/` with a manifest: 1,955 spells, 3,540 monsters, 2,319 magic items, 26 classes, 125 subclasses, 63 species, 58 backgrounds, 91 feats across SRD 2014/2024, A5E, Kobold Press, Tome of Beasts, and more. Chargen content is wired to typed mechanics (subclass→parent, caster kind, species resistances/skills/spells, feat prereqs, background origin feats); an `unmapped_report.json` records source fields with no mechanical target.

#### Performance & build (new)

- **Editor & sync hot paths** — The character editor resolves a sheet once per frame instead of twice per keystroke, and the effective-character recompute no longer re-runs on every unrelated world-entity edit. Warm cold-starts skip the full SRD pack rebuild via a version-gated bootstrap; the package list and per-row saves use indexed lookups + count queries instead of full-table scans, and the sync layer skips redundant asset-ref diffs.
- **Leaner builds** — The ≈31 MB Open5e packs are now excluded from release builds (loaded from a debug build for the admin installer). Mobile image-cache cap lowered for lower-RAM devices.
- **Perf probe** — In-memory frame + save-latency histograms in debug/profile builds (no-op in release).

### Upgrade notes

- **App version bump:** `10.0.0` → `10.1.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **No new cloud (Supabase) migrations.**
- **Worker deploy required for online catalog:** `wrangler deploy` to publish the `catalog/*` routes; set `CATALOG_GET_LIMIT_PER_HOUR` (optional, default 600). Without the deploy, official packs still install from the bundled fallback.
- **Catalog publish is admin-only** — `tool/catalog_publish/bin/publish_catalog.dart` requires the worker `ADMIN_TOKEN`.
- **Bundle size** — The Open5e packs (≈31 MB) are excluded from release builds; the admin asset-pack installer reads them from a `flutter run` (debug) build instead, so production ships leaner.

### Known issues

- **Official catalog publish pending** — Bundled packs ship and install locally; the R2-published catalog awaits worker deploy and licensing sign-off for full Open5e content distribution.
- Carry-over from v10.0.0: full WYSIWYG editors for schemas/templates/packages still in progress; feat-ASI honoring applies only to newly-recorded picks; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v10.0.0 — Rule & Effect Authoring Engine, Feat Effects That Actually Apply, Editable Core Rules (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v10.0.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Major release. Custom content gets its first real authoring surface: a catalog-driven **Rule & Effect editor** replaces hand-editing the `effects` JSON, and the numeric rules that were hardcoded in the resolver (ASI levels, HP-per-hit-die, AC constants, proficiency-bonus progression) become a **per-template, DM-editable config**. On the consumption side, feats now actually *apply their effect* whether granted at level-up or added by hand — the long-standing "I took the feat but nothing changed" class of bug is closed for ability-score, proficiency, and choice-bearing feats. Plus the Marketplace "All" tab finally shows soundpacks, and admin-broadcast notifications stop overwriting earlier answers when a notification has multiple poll/input blocks.

### Highlights

#### Rule & effect authoring (new)

- **Catalog-driven Rule Catalog (`RuleDefinition` / `RuleCatalog`)** — Every effect `kind` the resolver understands is now declared as a named, introspectable `RuleDefinition` (label, description, category, authorable params, accepted target kinds, capability flags, `applied` vs `deferred` status). A debug-only drift guard cross-checks `CharacterResolver.knownEffectKinds` against the catalog at startup, so the declared and executable surfaces can never silently diverge. The catalog is pure code-declared data — never persisted into the schema, never hashed by `computeWorldSchemaContentHash`.
- **Guided feat-effect editor (`_FeatEffectRow`)** — The feat/feature effect list field is now a structured editor instead of raw JSON: an effect-kind dropdown, a target-kind dropdown filtered to what the rule accepts, per-rule param inputs (int / string / bool / enum / relation / ability-list / dice), and full predicate / scales-with / activation sub-editors that surface only for rules that support them. Legacy/unknown kinds degrade gracefully to a bare Value field so existing content never becomes uneditable.
- **Non-blocking authoring validation (`validateEffectRow`)** — High-confidence warnings (no/unknown rule, a target kind the rule doesn't accept, an unknown predicate, a missing required param) render inline as the author edits. Warnings never block save or mutate data — conservative capability flags don't nag on valid SRD content.
- **Editable core rules (`RuleConfig`)** — The proficiency-bonus progression, the hit-die→HP table, the ASI/feat levels, and the AC base/shield constants move out of hardcode into a template-scoped `RuleConfig`, threaded as a value param through `CharacterResolver` and `planLevelUp`. `RuleConfig.dnd5eDefaults` reproduces the old hardcoded values byte-for-byte, so a world with no override resolves identically; a world only diverges when a DM writes `metadata['rule_config']`, which is also the correct moment for the template content-hash to change. Value-equal, so an override that round-trips to the same numbers doesn't churn provider rebuilds.

#### Characters & SRD — feats now apply their effect

- **Manually-added feats reach the resolver** — The resolver enumerates feats from `feat_ids`, but a manual edit of the Feats relation field only wrote `feats`, so a hand-added feat was mechanically invisible (no ASI, no proficiency, no picks). Manual edits now mirror `feats` → `feat_ids`, seed the same follow-on Pending Choices a level-up pick would (skill / expertise / feat-ASI / `choice_group`), and prune recorded picks + pendings for any removed feat so no ghost bonuses linger.
- **Feat ASI honors your chosen ability** — Ability-bump feats (Moderately Armored, Lightly Armored, the Ability Score Improvement feat, Resilient, …) were applied by a resolver heuristic that always bumped the *first* eligible ability, ignoring the pick. The exact pick is now recorded (`feat_asi_choices`, keyed by feat id) and applied verbatim by the resolver; the heuristic remains only as the fallback for old/unresolved characters, so there is no double-count and no regression.
- **Plain ASI no longer masked on modern characters** — A plain Ability Score Improvement wrote to `stat_block`/per-ability keys, but a character with a populated `base_abilities` displays via the resolver, which seeds only from `base_abilities` — so the bump was invisible. Plain ASI now also folds into `base_abilities` (guarded to non-empty maps only, so legacy characters keep their raw-write fallback intact).
- **Armor / weapon proficiency grants surfaced** — Feats like Moderately Armored (Medium Armor + Shields) now show their granted armor/weapon proficiencies read-only in the Resolved Grants card, alongside the existing skill/tool-proficiency, HP, and initiative rows.
- **Shared follow-on seeding (`seedFeatFollowOns`)** — Level-up and manual-add now route through one helper, so the two paths can't drift on what a taken feat prompts for.

#### Marketplace & notifications

- **"All" tab shows soundpacks** — The Marketplace "All" view now merges the Supabase listing feed with the soundpack catalog, so curated soundpacks are no longer hidden behind their dedicated tab. Pull-to-refresh invalidates both sources; an empty listing feed yields to the catalog instead of an empty state.
- **Notification multi-block answers preserved** — In a broadcast notification with several poll/input blocks, the detail dialog captured `myAnswers` once at construction, so submitting one block overwrote answers from the others. The dialog now watches the live notification provider and merges against the freshest answer map, so each block's submission accumulates correctly.

### Upgrade notes

- **App version bump:** `9.5.0` → `10.0.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **No new cloud migrations.** Pure client-side work (rules engine + resolver/editor changes + UI fixes).
- **No new runtime dependencies.** `flutter pub get` not required for new packages.
- **Existing characters/worlds are unaffected** until re-resolved. The default `RuleConfig` matches the previously-hardcoded values exactly, so nothing changes for a world that never edits its rule config. Feats resolved *before* this release keep their old heuristic ability until re-resolved (no migration) — only new picks are honored.

### Known issues

- Feat-ASI honoring applies to newly-recorded picks; characters who resolved an ability-bump feat under an older build keep the first-eligible-ability heuristic until the feat is re-resolved.
- The rule/effect editor covers feat/feature effect rows; full WYSIWYG editors for schemas, templates, and packages are still in progress.
- Carry-over from v9.5.0: no publishing/sharing of user soundpacks (curated catalog only); Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v9.5.0 — Soundpack Marketplace, Admin Broadcast Notifications, Involuntary Beta-Loss Data Guard, 14-Day Inactivity Window (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.5.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v9.4.0. Adds a curated soundpack catalog so the Soundpad ships with downloadable audio instead of empty folders, an admin-to-everyone broadcast notification system with interactive content, hardens the beta program against silent data loss when access is lost involuntarily, and doubles the beta inactivity grace period from 7 to 14 days.

### Highlights

#### Soundpacks

- **Soundpacks marketplace item** — A new **Soundpacks** filter in the Marketplace tab and a "Download soundpacks" section in Settings → Soundpad both render a curated catalog. Each pack shows name, description, size, and a **Get → Downloading… → Installed** action. No user sharing yet — the catalog is read-only, fetched from a manifest hosted in the GitHub repo, so new packs can be added without an app release.
- **Two pack kinds** — `theme` packs install as a self-contained theme folder (`theme.yaml` + audio) under the soundpad root and are auto-discovered by `loadAllThemes`; `library` packs download ambience/SFX audio and merge their entries into `soundpad_library.yaml`. Downloaded music themes, ambience, and SFX appear in the Soundpad sidebar immediately (theme/library providers are invalidated on install).
- **Catalog source** — Manifest at `soundpacks/manifest.json` in the repo lists each pack (`id`, `kind`, `name`, `baseUrl`, `files`, optional `entries`). The launch catalog ships three music themes (Samurai, Medieval Meditation, Salute), four ambience packs (Rain, Crowd, Fireplace, Dungeon), and three SFX packs (Sword Slice, Arrow Swish, Door Creak).
- **Resilient fetch** — Downloads use the native `HttpClient` with a path-traversal guard and atomic `.tmp`→rename writes; a failed download rolls back its files. A missing manifest (404) shows an empty catalog rather than a false "you're offline" state, which is reserved for genuine network failures.

#### Notifications

- **Admin broadcast notifications** — Admins compose a notification (title + ordered content blocks) from a new "Notifications" admin tab and publish it to every user. Three block types: `markdown` (rendered rich text), `poll` (single- or multi-select question), and `input` (free-text prompt, multiline by default). Backed by new `notifications`, `notification_responses`, and `notification_reads` tables (migration 069). Writes go only through `SECURITY DEFINER` RPCs; RLS lets every user read published notifications while clients cannot write directly.
- **Inbox + unread badge** — A notification icon button with an unread-count badge sits in the hub. Users open an inbox dialog to read notifications and answer polls / inputs inline; one response row per user per notification, upsert-on-edit. Read tracking drives the badge.
- **Admin response viewer** — Admins open a per-notification responses dialog to see aggregated poll tallies and individual free-text answers. `notifications` + `notification_responses` are added to the realtime publication so the inbox and the response viewer update live.

#### Beta program

- **Involuntary beta-loss data guard (`BetaLossGate`)** — When a user loses beta access *involuntarily* (server-side inactivity sweep or admin revoke) rather than via the voluntary exit flow, the server-side cascade DELETE events arriving over realtime (or replayed on cold start) would previously wipe the owner's offline Drift copy of their own worlds. A per-user sentinel now marks the involuntary-loss state and makes CDC DELETE appliers skip purge/trash for rows the user *owns* (`owner_id == uid`). Worlds the user merely plays in (non-owner) are still purged normally on membership removal. Set the instant a `wasActive && !nowActive` transition is detected; cleared on successful beta re-enter.
- **Inactivity window 7 → 14 days** — `beta_inactivity_days()` now returns 14 (migration 070). The single `CREATE OR REPLACE` flows through both the daily `sweep_inactive_beta()` purge cutoff and the client-facing `get_beta_status().inactivity_days`; sweep scope, cron, and RPCs are otherwise unchanged.

### Upgrade notes

- **App version bump:** `9.4.0` → `9.5.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **New cloud migrations:** `069_notifications.sql` (notification tables + RLS + RPCs + realtime publication) and `070_beta_inactivity_14d.sql` (inactivity threshold). Apply via Supabase Dashboard → SQL Editor before / alongside the client rollout.
- **Pure additive schema.** Existing tables and data are unaffected.
- **Soundpacks:** no migration or new dependency. Requires `soundpacks/manifest.json` on the repo's default branch; the referenced audio already lives under `assets/soundpad/`.

### Known issues

- Soundpacks: no publishing/sharing of user packs (curated catalog only); no in-catalog uninstall — remove installed themes from the Soundpad sidebar as before.
- Carry-over from v9.4.0: full WYSIWYG custom-content editors still deferred; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v9.4.0 — Thirteen New Themes, Google Fonts Per-Theme, Dynamic App Version, Heartbeat Service Refactor (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.4.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v9.3.0. Theme catalog nearly doubles: 13 new palettes ship alongside `google_fonts` integration so themes can pin their own typeface. `appVersion` is now resolved at runtime from the bundled pubspec via `package_info_plus`, so the admin heartbeat always reflects the real installed build instead of a hand-edited constant. Heartbeat itself moves out of `main.dart` into a dedicated service that pings on boot, on every `signedIn` / `tokenRefreshed` / `userUpdated` auth event, and on a 15-minute foreground timer (paused while backgrounded).

### Highlights

#### Theming

- **13 new theme palettes** — `obsidian` (volcanic glass, near-black slate + crimson edge), `sunset` (coral + amber on smoky plum), `nord` (arctic polar night + frost cyan), `rose` (cream pink + magenta pill chips, light theme), `neon` (cyberpunk hot magenta + cyan on near-black), `terminal` (green-on-black CRT), `scroll` (warm parchment + ink, light theme), `terra` (earthy clay), `goldenrod` (heraldic gold + ivory), `jade` (deep jade + bone), `vapor` (synthwave purple/pink), `mono` (pure greyscale), `carmine` (oxblood + cream). Brings the in-app palette picker count from 11 to 24.
- **Google Fonts per theme (`fontFamily`)** — `DmToolColors` gains an optional `fontFamily` field. When set, the theme builder resolves the family via `google_fonts` instead of falling back to the binary `useSerif` toggle, so palettes can ship distinct typefaces (e.g. monospace for `terminal` / `mono`, condensed serif for `scroll`).

#### Admin telemetry

- **Dynamic `appVersion` via `package_info_plus`** — `appVersion` was a hand-edited `const String` in `constants.dart`; every release required a code edit just to keep the admin panel honest. New `initAppVersion()` resolves the bundled pubspec version (Android/iOS/desktop) or the web build's `info.json` and overwrites the fallback before Supabase init, so `user_heartbeat` RPC carries the real installed build on the first ping.
- **`HeartbeatService` refactor** — Old inline `user_heartbeat` RPC in `_initSupabase()` only fired once at boot, missed late sign-ins, and would have paged the radio on backgrounded mobile sessions. New singleton `HeartbeatService` (instance API: `start()` / `stop()` / `send()`) subscribes to the Supabase auth stream and re-pings on `signedIn` / `tokenRefreshed` / `userUpdated`, runs a 15-min foreground timer via `WidgetsBinding` lifecycle observer, and cancels the timer when the app is paused/inactive so it doesn't wake the network for an idle heartbeat. `profiles.last_active_at` / `app_version` / `platform` stay populated across long sessions, late auth, and token refresh boundaries.

### Upgrade notes

- **App version bump:** `9.3.0` → `9.4.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **No new cloud migrations.** Pure client-side theme + telemetry work.
- **New runtime deps:** `google_fonts: ^6.2.1`, `package_info_plus: ^8.0.2`. `flutter pub get` required after upgrade.
- **`appVersion` is no longer `const`** — Code that imported it expecting a compile-time constant must treat it as a mutable `String` populated by `initAppVersion()` during bootstrap.

### Known issues

- Carry-over from v9.3.0: full WYSIWYG custom-content editors still deferred; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.
- Google Fonts at runtime fetch on first use when a system copy is not bundled; first launch on a fresh install may briefly render the fallback family before the network resolve completes.

---

## Dungeon Master Tool v9.3.0 — Class Tool Proficiencies, Weapon Mastery Picker Fix, Silent Auto-Grant Resolver Bugs, Drow 120 ft Darkvision, Formula-Driven Resource Pools (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.3.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v9.2.0. SRD 5.2.1 class tool proficiencies are finally wired through (Bard / Druid / Monk / Rogue), and three character-creation resolvers — Weapon Mastery, Extra Attack, resource pool grants (Rage, Bardic Inspiration, Ki, …) — get a silent-failure fix that had been hiding **all** auto-granted class effects on built-in SRD content. The two remaining SRD effect gaps close in this release as well: Drow Superior Darkvision now actually overrides the base 60 ft to 120 ft, and `count_formula` resource pool grants (Paladin Lay on Hands, Monk Ki, Cleric Channel Divinity, …) are evaluated end-to-end. Net effect: Barbarian / Fighter / Paladin / Ranger / Rogue L1 now show the Weapon Mastery picker, Fighter L5 shows the correct extra-attack count, Rage / Bardic Inspiration / Ki / Lay on Hands / Channel Divinity uses populate on the PC card with the right per-level max, and Drow PCs render with 120 ft darkvision.

### Highlights

#### Characters & SRD

- **Class tool proficiencies (SRD §1.5)** — Four classes finally pick up the tool proficiencies the SRD grants them. Bard L1 picker offers all musical instruments (cap 3), Monk L1 picker offers artisan's tools + musical instruments (cap 1), Druid L1 auto-grants Herbalism Kit, Rogue L1 auto-grants Thieves' Tools. Wizard step already had the picker UI; the data side was empty on every class until now. Resolver `Pass 8` extended to walk class-side `granted_tool_refs` (previously background-only). Wizard `buildSeedFields()` extended to seed class granted tools so the PC entity's `tool_proficiencies` list opens populated.
- **Weapon Mastery picker now appears for Barbarian / Fighter / Paladin / Ranger / Rogue at L1** — Two layered bugs were hiding the picker. (1) `_passesMasteryFilter` in [proficiencies_step.dart](flutter_app/lib/presentation/screens/characters/wizard/steps/proficiencies_step.dart) only handled Map-shape `category_ref`; the SRD pack-build's `_resolveRefs` rewrites `{_ref, name}` placeholders to String UUIDs before the resolver ever sees them, so every weapon failed the filter → `masteryWeaponIds` was empty → picker hidden. Filter now accepts either shape. (2) Even with the filter fixed, `masteryCap` was still 0 because the resolver's `_isAutoGranted` check matched only Map-shape `source_ref` — same shape mismatch, same silent failure.
- **Silent auto-grant resolver bug fixed across 3 resolvers** — `weapon_mastery_resolver`, `extra_attack_resolver`, and `resource_pool_resolver` all carried the same Map-only `source_ref` check, so every class auto-grant on built-in SRD content was invisible. The pack-build's two-pass `_resolveRefs` pipeline turns `{_ref, name}` placeholders into String UUIDs; resolvers now look up entities by UUID in addition to the legacy Map form. Side-effect fixes: Fighter L5 / L11 / L20 Extra Attack count now resolves to 2 / 3 / 4 as it should, and resource pools (Rage uses, Bardic Inspiration, Channel Divinity, Ki / Focus Points, Wild Shape, Lay on Hands, …) populate on the PC card at the right levels instead of staying blank until manual edit.
- **Drow Superior Darkvision (120 ft) now applies** — `_modifierAsEffect()` in [character_resolver.dart](flutter_app/lib/domain/services/character_resolver.dart) only forwarded a small whitelist of `granted_modifiers` kinds to `applyEffect`; `sense_grant` (plus `truesight_grant`, `blindsight_grant`, `condition_immunity_grant`, and the three `damage_*_grant` kinds) fell through to default and were silently dropped. Drow's subspecies modifier (`sense_grant` with `range_ft: 120`) now reaches the resolver's existing max-wins range logic, so Drow PCs render with 120 ft darkvision instead of the base 60 ft.
- **`count_formula` resource pool grants are now evaluated** — Paladin Lay on Hands (`paladin_level_x5`), Monk Ki / Focus Points (`monk_level`), Cleric Channel Divinity (`cha_mod_min_1`), and any other pool with a formula instead of a literal `count` / scaling table now resolve to the correct max in the level-up plan and on the PC card. The token evaluator (`paladin_level_x5`, `cha_mod_min_1`, `pb`, …) was already complete in `CharacterResolver` for full character resolution but the planner-side `resource_pool_resolver` intentionally skipped it for lack of context. Extracted the evaluator to a shared `count_formula.dart`, threaded `abilities` + `classLevels` through `planLevelUp` from the character editor and wizard, and per-side `classLevels` snapshots so prev/new deltas are correct (e.g. Paladin 4 → 5 shows Lay on Hands 20 → 25).

### Upgrade notes

- **App version bump:** `9.2.0` → `9.3.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **No new cloud migrations.** Pure client-side data + resolver fixes.
- **Existing characters are unaffected** until they are re-resolved (level-up, edit, re-open). The tool proficiency picker only fires on character creation; existing PCs without the granted tools can add them manually via the editor.

### Known issues

- Carry-over from v9.2.0: full WYSIWYG custom-content editors still deferred; Tier-4 combat-tracker-dependent effects pending; D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v9.2.0 — Era Timeline Overhaul, Per-Location Maps, Beta Merge Hardening (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.2.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release on top of v9.1.0. World map era timeline becomes a full drill-in system: each location can carry its own nested pin/timeline data per era, with a fresh background image per era resolved straight off the location entity. Beta-enter no longer overwrites offline-only work with stale cloud rows — a dedicated merge service pushes local content cloud-first on first enter, gated by a per-user sentinel. Level-up dialog stops auto-committing on dismiss. Entity card stops crushing the name field next to the portrait on phones. Battle map background can be reused from a location's already-uploaded `battlemaps` field without re-uploading to R2.

### Highlights

#### World map & timeline

- **Epoch → Era rename, drill-in nested maps** — `MapEpoch` / `EpochWaypoint` renamed to `MapEra` / `EraWaypoint`. New `LocationMapData` holds per-location nested pin + timeline collections inside each era, so a location entity can have its own zoomed-in map with its own pins per era. Background image for the nested view comes from the location entity's `map_per_era[eraId]` (falls back to `map`), keeping image storage on the entity instead of duplicated in map state.
- **New `imagePerEra` field type** — Schema-driven image-per-era widget on location entities. DM uploads a different map image for each era and the world map picks the right one automatically when entering the era. New `_FB.image` / `_FB.imagePerEra` schema helpers with `mediaKindWire` plumbed through, so per-era map images count under the correct media quota kind.
- **Per-scope merge strategy on waypoint delete** — `DeleteWaypointDialog` now lists every scope that holds pin data (root world map + each location whose drilled map has pins in either era) so the DM picks merge / keep-left / keep-right independently per scope instead of forcing one strategy across the whole world.
- **Map breadcrumb + location pin preview** — New `map_breadcrumb_bar` and `location_pin_preview_card` widgets surface the current era + drill path and give pins a hover/tap preview before entering. `era_scroll_bar` replaces the old `epoch_scroll_bar`.
- **Battle map "From location" picker** — New `battlemap_picker_flow` lets the DM pick a battle map background from either a fresh device file *or* a location entity's `battlemaps` field. Location refs skip re-upload because they are already `dmt-asset://` refs counted under `MediaKind.battleMap`; `applyMapImage` is shared between the two sources so reused refs flow through the same decode/state pipeline.

#### Characters

- **Level-up dialog stops auto-committing on dismiss** — Previously any exit path (barrier tap, system back, X icon) committed the level up via `PopScope.onPopInvokedWithResult`. Now only the **Apply** button commits; barrier tap / back gesture / new **Cancel** button discard the staged choices and leave the character untouched.
- **Entity selector picks up bundled SRD rows** — Char-sheet relation fields (inventory, equipment) couldn't pick from the bundled SRD 5.2.1 Core rows (longsword, leather armor, …) because those rows live in the in-memory `builtinSrdEntitiesProvider`, not `entityProvider`. New `includeBuiltinSrd: true` flag merges them in for char-sheet pickers (map/session/mindmap pickers default to false to keep the ~7K SRD rows out of those lists). `EntityNameText` also falls back to the SRD map, so previously-picked SRD rows render with their real name instead of a raw UUID.
- **Entity card mobile layout** — On phones, the portrait gallery now stacks above the name/subtitle/description column instead of sitting beside it. The 200 px portrait was crushing the name field on narrow screens; tablet+ layouts are unchanged. The same vertical-stack pattern lands in the projection view.

#### Sync, beta & storage

- **Beta-enter merge service (PR-B1..B6)** — First-time beta-enter on a device used to race the cloud appliers: a stale cloud row from a prior beta session could land before local writes and silently wipe offline work (the "Aleseus" content-loss case). New `BetaEnterMergeService` pushes every piece of owned local content (worlds + their granular tables, orphan characters, personal packages) to the cloud *before* any cloud→local applier runs, with **local-wins** conflict policy on first enter. Gated by a per-user `BetaEnterGate` sentinel; `leaveBeta` clears the sentinel so a re-enter re-runs the merge.
- **Wipe guards in cloud appliers** — `CloudCatchupService`, `PersonalMirrorApplier`, `WorldReconciler` and the world / package repositories now consult the gate and skip applying empty/stale cloud snapshots while a merge is pending, so a partial sync race can no longer publish empty defaults that fan out to other devices.
- **`_saveToDb` merge-mode** — Repository save paths honour the gate too, shallow-merging cloud-derived rows onto local state during the merge window instead of overwriting.
- **`StartupSyncGate` reconciles before splash closes** — Already shipped in v9.1.0 for the worlds tab; v9.2.0 extends it to invalidate hub list providers after merge so a fresh sign-in lands on a populated hub without a manual refresh.
- **Migration 068 — beta quota actually at 100 MB** — `062_double_media_limits.sql` updated the wrong function (`get_beta_quota_bytes`) while every real caller reads `beta_user_quota_bytes()`, so the admin panel and storage checks were stuck at 50 MB. Migration 068 fixes `beta_user_quota_bytes()` to return 100 MB and drops the orphan function.

### Upgrade notes

- **App version bump:** `9.1.0` → `9.2.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **Cloud migration:** `068_fix_beta_quota_100mb.sql` — required to surface the correct 100 MB quota in the admin panel and storage checks. No data change beyond the function body.
- **No new Edge Function or Worker deploys** required for this release; v9.1.0's `beta_purge_with_cleanup` deploy is still the gate for full R2 + Supabase Storage cleanup on beta exit / admin revoke.
- **Stored map data** is forward-compatible: the JSON keys for `MapEra` / `EraWaypoint` / `LocationMapData` are new; old `MapEpoch` / `EpochWaypoint` worlds still load via the rename.

### Known issues

- Carry-over from v9.1.0: full WYSIWYG custom-content editors still deferred; remaining SRD effect gaps (Drow 120 ft superior darkvision, Tier-4 combat-tracker-dependent effects); D7 Drift v12 round-trip test harness pending.
- `imagePerEra` field type is only wired into the location entity schema; custom packages cannot yet declare their own per-era image fields through the JSON editor.

---

## Dungeon Master Tool v9.1.0 — Cross-Device Sync Hardening, Storage Cleanup, Map Persistence (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.1.0) · [elymsyr.github.io](https://elymsyr.github.io/)

Patch release focused on cross-device reliability and storage hygiene on top of v9.0.0. Online worlds opened from a second device now populate Session, Mind Map and World Map tabs correctly; empty-state clobbers during the initial sync race no longer wipe cloud state; world map data persists across reopens via granular Drift mirrors; beta exit and admin revoke now fully purge Cloudflare R2 and all Supabase Storage buckets, not just DB rows.

### Highlights

#### Cross-device sync

- **Tabs no longer empty on second-device open** — Cloud settings blob was being stuffed under `data['settings']` while screens read top-level keys (`combat_state`, `mind_maps`, `map_view`, …). `_applySettingsRow` / `_applyWorldsEvent` now spread cloud subkeys to top-level with a blocklist for granular-table owners (entities/sessions/map_data) and identity fields. Pending-write merges are preserved subkey-by-subkey.
- **Screens re-initialise after cloud arrives** — `MindMapScreen` gained a `_consumedRealData` flag and `WorldMapNotifier` exposes `hasContent`. If first init happened against an empty Drift snapshot and the user has not edited yet, a revision bump now triggers re-init; user edits or real data still block clobber. `applyInitialState` early-return widened to also continue when only `mapData`/`sessions`/`settings` are populated.
- **Empty-state clobber guard** — A cross-device open used to surface empty defaults before cloud sync, and the first auto-save would write that empty state back to the cloud and fan it out. Three gates added: (1) `combatProvider._loaded` now requires either real `combat_state` or a `worldInitialSyncSettledProvider` signal so `session_screen`'s auto-create-encounter cannot publish a phantom "Encounter 1"; (2) `WorldMapNotifier.syncToCampaignData` only writes when init had real data or the user added content; (3) `MindMapScreen.deactivate` skips save when init was empty and the notifier is still empty.
- **Worlds tab populates on startup** — `StartupSyncGate` now runs `worldReconciler.reconcile()` after beta/auth ready and invalidates the three hub list providers (worlds, packages, characters) before the splash closes, so sign-in / cache-wipe / new-device opens no longer require a manual hub refresh. Stays inside the 8 s startup ceiling.

#### Storage & persistence

- **World map + sessions persist locally** — `world_map_data` and `world_sessions` have had Drift tables for a while but the campaign load path was only reading the `settings_json` dual-write, so a force-close or partial sync could lose the battle map image. `CampaignRepository` now exposes `saveMapData`, `saveSessions`, `saveSession`, `deleteSession` against the typed DAOs; `_loadFromDb` overlays the typed rows on top of `settings_json` (granular = source of truth); cloud appliers (`_applyMapDataRow`, `_applySessionEvent`, `_applySessionsList`) write through to disk too.
- **Full R2 + Supabase Storage cleanup on beta exit & admin revoke** — Previously the admin "Revoke" button only called `admin_revoke_beta`, leaving Supabase Storage (`campaign-backups`, `free-media`, `shared-payloads`) and Cloudflare R2 (`{userId}/`, `transient/{userId}/`) orphaned. Self-exit cleaned Supabase Storage but couldn't touch R2 from the client. Three-tier fix: (1) new Cloudflare Worker endpoint `POST /admin/purge-user` does cursor-paginated list + batch delete of both prefixes behind `ADMIN_TOKEN`; (2) new Supabase Edge Function `beta_purge_with_cleanup` orchestrates everything — verifies caller JWT, picks self-exit vs. admin-gate path, runs the corresponding RPC, sweeps the three Storage buckets with the service role, then calls the Worker; (3) Flutter `admin_beta_requests_remote_ds.revoke` and `beta_provider.leaveBeta` route through the Edge Function, with a legacy fallback on self-exit when the function is not deployed.

### Upgrade notes

- **App version bump:** `9.0.0` → `9.1.0`.
- **Local DB:** schema v12, unchanged.
- **No new SQL migrations.**
- **Deploy required for full beta-exit cleanup:** `wrangler deploy` (Worker) + `supabase functions deploy beta_purge_with_cleanup`. Edge Function secrets `R2_WORKER_URL` and `R2_ADMIN_TOKEN` must match the Worker's `ADMIN_TOKEN`. Without the deploy, self-exit still works via the legacy fallback but leaves R2 objects behind.

### Known issues

- Carry-over from v9.0.0: full WYSIWYG custom-content editors still deferred; remaining SRD effect gaps (Drow 120 ft superior darkvision, Tier-4 combat-tracker-dependent effects); D7 Drift v12 round-trip test harness pending.

---

## Dungeon Master Tool v9.0.0 — Online Play, Second Screen, Free Session Media, Admin-Gated Beta (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v9.0.0) · [elymsyr.github.io](https://elymsyr.github.io/)

The biggest release since v8.0. The closed beta now powers full online play: every character of a beta member becomes online, worlds and packages can be published, and **only the DM needs a beta slot** for the whole table to play together. The DM second screen is live for all connected players (entity cards, world map, battle map, images) and players can now mark up the projected battle map. Cloud media is split into free vs. counted kinds and a shared transient pool means images and battle maps shared in a live session no longer count against your save quota. Beta enrolment moved to admin-reviewed requests with a slot cap of 90.

### Highlights

#### Online play (experimental)

- **All-characters-online on beta join** — Joining the beta auto-mirrors every character you own to your cloud account and unlocks "Publish online" on worlds and packages. Leaving the beta hydrates the rows back into local-only storage instead of dropping them, so a beta exit no longer destroys work (migration 057 + 064).
- **DM-only beta requirement** — Only the DM has to be a beta member. Players connect, claim characters, see live updates, and use the projected second screen without their own beta slot.
- **DM-driven second screen for every player** — The DM's projection output (entity cards, images, world map, battle map) replicates to every connected player's client. A per-world manifest stores the active view so a late-joining or reconnecting player catches up instantly. Player tab gained a "second screen" view that mirrors what the DM is projecting (migrations 059, 061, 062).
- **Player marks on battle map** — Players can now place rulers, circles and free strokes on the DM-projected battle map (battlemap_marks_protocol). Marks stream through CDC with optimistic ghost + 50 ms debounce.
- **Row-level online sync, F1–F12** — Outbox + change-bus + per-row CDC apply replaces the legacy blob mirror for worlds, characters, packages and projection state. Schema versioning, reference graph, LRU sweeper, prefetch/prewarm, fog externalisation, raw-path migrator and telemetry shipped together.
- **Shared real-time visibility** — World members see each other's character changes live; member CDC + character CDC use granular notifiers; MembersStrip surfaces who's online on the player tab.

#### Media & storage

- **Free vs. counted media** — Character portraits and world/package cover art now sync free of your beta quota. Entity images and battle map media count against it, with per-kind size limits and a separate counted-asset bucket (migrations 053, 058, 060).
- **Free session-media pool** — Images and battle maps shared during a live online session use a shared transient pool (100 MB/user, 10 GB global LRU). Sharing live content with players no longer eats into your personal cloud save (migration 065 + worker evict-sweep + admin-purge).
- **Doubled cloud media limits** for paid kinds (migration 062).
- **Marketplace cover updates** — Cover images on marketplace listings are now mutable and re-encoded with a dedicated cover-sync service (migration 056).
- **Cloud media cleanup on delete** — Deleting a character, world or package now sweeps the associated cloud images server-side (`EntityMediaCleanupService`); local cache is preserved.

#### Beta program

- **Admin-reviewed beta requests** — Beta enrolment is now a request → admin review → approve/reject flow with a "Beta Requests" admin tab. Slot cap raised to 90 (migrations 063, 066, 067).
- **Hard reset path** — Mass beta wipe is available to admins for emergency resets (migration 064).
- **Beta exit preserves your data** — `BetaExitPreserveService` hydrates owned worlds, orphan characters and personal packages into offline-only storage on leave, with CDC purge guards and a summary dialog of what stayed local vs. what was uploaded.

#### Characters & SRD

- **"~3 HP at level 1" bug fix** — Wizard wrote HP to `combat_stats` while editor/rest/level-up paths read top-level fields, so newly-created characters showed 0/0 and the first level-up landed them in the 3–6 band. HP now uses `combat_stats.{hp,max_hp}` as the single source of truth via `_readHp`/`_writeHp` helpers; level-up, short rest, long rest and damage flows are all aligned.
- **Locked HP, new Extra HP field** — `combat_stats.hp` / `combat_stats.max_hp` are now read-only in the character editor (mid-session damage/heal still goes through the combat tracker and rest buttons). A new top-level **Extra HP** field above Death Save Successes accepts a signed value (`+5`, `-3`, `0`) and propagates the delta to `max_hp` + current HP atomically.
- **Subclass skill picks** — `bonus_skill_pick_count` / `bonus_expertise_pick_count` on subclasses now seed the wizard's pending-choice pipeline (e.g. College of Lore L3 → 3 skill picks at higher-level start). Subclass auto-grants are gated by parent class level, so a level-3 subclass selection no longer fires its L6 features.
- **Berserker Mindless Rage as a mechanical grant** — L6 Mindless Rage now grants both the narrative trait and the `Mindless Rage` feat so the resolver actually walks its effects; condition-immunity-while-raging surfaces in ResolvedGrantsCard instead of staying narrative-only.
- **Higher-level start gold (SRD §1 "Starting at Higher Levels")** — Wizard now auto-adds the SRD higher-level GP bundle when starting above L1 (L5–10 +500, L11–16 +5 000, L17+ +20 000, plus 1d10×25/L5+ avg-fixed) instead of leaving it as advisory-only text.
- **Template re-apply preserves combat_stats subfields** — `applyTemplateUpdate` now shallow-merges Map fields so re-running a template against an existing character doesn't wipe HP/AC sub-values back to defaults.

#### App-wide

- **Unified debounce + tier-1 perf wins** — 5-tier SyncTier classifier, batched package_sync upsert+delete, combat event log capped at 500, startup AppIconImage swap, CDC race guard.
- **Offline guard** — Network-backed screens (feed, marketplace, messages, profiles, game listings) render a single "You're offline" placeholder via the new `OfflineGuard` widget + `guardedNetwork` helper instead of infinite spinners. Auto-recovers on reconnect; outbox writes hold and flush.
- **Mobile responsiveness** — Keyboard relayout fixes (K1/K3/K4), mention input fix (M1/M2), single-axis image decode for portraits and `AssetRefImage`.
- **Workspace + map fixes** — Battle-map snapshot + snapshot builder reworked; mind-map node rebuilds reduced; world-map notifier streamlined.
- **Soundpad sidebar rebuilt** — Layout and theming overhaul (≈670 LoC churn).

### Upgrade notes

- **App version bump:** `8.4.0` → `9.0.0`.
- **Local DB:** schema v12, unchanged. No client migration.
- **Cloud migrations 053 → 067** — All required, in order. Run via `supabase/migrations/`.
- **Beta members re-enrolled via request flow** — Existing beta slots are preserved; new members go through the admin-reviewed request.
- **No user action required for offline players** — Players connecting to a DM's world don't need a beta slot.

### Known issues

- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision still needs resolver `sense_grant range_ft` wiring; Tier-4 combat-tracker-dependent effects (aura predicates, advantage/disadvantage grants, on-hit extra damage, condition writers, pool spending automation) remain unimplemented.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.
- **Online play is experimental** — Expect occasional desync; report cases via Settings → Report a bug.