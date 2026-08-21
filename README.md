# Dungeon Master Tool

<p align="center">
  <b>A portable, offline-first DM tool.</b><br>
  <i>Build worlds, run sessions, play together — all in one app.</i>
</p>

<p align="center">
  <a href="https://elymsyr.github.io/"><b>Website</b></a> ·
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest"><b>Releases</b></a> ·
  <a href="https://github.com/elymsyr/dungeon-master-tool/issues"><b>Report a Bug</b></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-beta-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/version-v13.0.0--beta-blueviolet?style=flat-square" />
  <img src="https://img.shields.io/badge/license-CC%20BY--NC%204.0-lightgrey?style=flat-square" />
  <img src="https://img.shields.io/badge/Flutter-3.41-02569B?style=flat-square&logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.11-0175C2?style=flat-square&logo=dart" />
</p>

<p align="center">
  <b>Platforms:</b> Android · iOS · Windows · Linux · macOS &nbsp;|&nbsp;
  <b>Languages:</b> EN · TR · DE · FR
</p>

<h3 align="center">Download</h3>

<p align="center">
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest"><img src="https://img.shields.io/badge/Android-APK-34A853?style=for-the-badge&logo=android&logoColor=white" alt="Android" /></a>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest"><img src="https://img.shields.io/badge/Windows-x64-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows" /></a>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest"><img src="https://img.shields.io/badge/Linux-zip-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux" /></a>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest"><img src="https://img.shields.io/badge/macOS-app-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS" /></a>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest"><img src="https://img.shields.io/badge/iOS-ipa-999999?style=for-the-badge&logo=apple&logoColor=white" alt="iOS" /></a>
</p>

<p align="center">
  <sub>Support development:</sub><br><br>
  <a href="https://www.patreon.com/elymsyr"><img src="https://img.shields.io/badge/Patreon-F96854?style=flat-square&logo=patreon&logoColor=white" alt="Patreon" /></a>
  <a href="https://thanks.dev/u/gh/elymsyr"><img src="https://img.shields.io/badge/thanks.dev-2EBC4F?style=flat-square&logo=githubsponsors&logoColor=white" alt="thanks.dev" /></a>
  <p align="center">
    <a href="https://groupfinder.eu/library/dungeon-master-tool">
      <img src="media/gf-bar-rw.png" alt="Support us on GroupFinder Library" height="40" />
    </a>
  </p>
</p>

---

## What's New in v13 ✨

- **Local Sync (Wi-Fi)** — Move worlds, packages and characters straight between *your own* devices on the same network. Nothing goes online. Open it from the profile menu (or the save/sync panel), pair once with a QR code or an IP + PIN, then hit **Sync**.
- **Use it without an account** — Pick **Continue without an account** on the landing screen and everything local works. Sign in later and your offline workspace is carried into the account.
- **PDF Library per world** — PDFs you open are copied into the world, live under the **Library** tab of the PDF sidebar, and can be shared with your online players (they download on demand).
- **Package Links** — A package can borrow another package's content instead of copying it. Open a package → **Linked Packages** → pick one.
- **Every ref on a card is a link** — Spells, items, traits and relation chips inside cards are now tappable and open the card they point at.
- **Spell slots on the sheet** — Caster classes now land a real spell-slot grid on the character sheet at creation and level-up, and a template's own slot table wins over the built-in preset.
- **Content repair pass on the 19 official packs** — Thousands of corrected and newly filled values across spells, monsters, magic items, backgrounds, feats and subclasses. Re-install a pack to pick them up.
- **Images stay put** — Every image you pick is copied into the world folder, so it keeps working offline and travels with Local Sync; unreferenced files are swept on world open/exit.

---

## Roadmap

Planned for upcoming releases — order not final, scope may shift between patch and minor versions.

- **Better battle map system** — The VTT upgrade has landed: snap-to-grid tokens, creature-size auto-scaling, 5e diagonal measurement rules, AoE templates (cone/line/sphere/cube/sector), and vector shape annotations. Still planned: smoother large-grid performance, stat-block token previews, and line-of-sight + dynamic vision.
- **Built-in D&D 5e package visuals** — Cover art, monster/species/class portraits, equipment icons, and spell glyphs bundled with the SRD core pack so default content stops looking like raw text. The generation pipeline (`tool/art_gen`) is in place and scoped at ~5,500 art-worthy cards; the images themselves are not bundled yet.
- **More online storage for users** — Larger per-account quota for counted cloud media and selectable retention tiers; current beta cap is intentionally conservative (portraits, covers and live session media already sync free of quota).
- **Synced music from YouTube** — Paste a YouTube link and play it as a session track, kept in sync across every connected player's app so the whole table hears the same thing at the same time.
- **Local Sync, round two** — Deletions and renames do not propagate over Local Sync yet (it only adds and updates), and the transfer is authenticated but not encrypted. Both are on the list.

---

## For Worldbuilders 🗺️

Build a setting, then bring it to the table — fully offline.

- **Mind Map** — Infinite canvas with Bezier links, multiple workspaces and undo/redo, for plotting factions, characters and plot threads.
- **World Map** — Drop an image and pin it: every pin carries a label, colour, style, a note and an optional link to an entity card, so a city pin opens the city. Grid overlay with snapping and a feet-per-cell scale, freehand drawings, and fog of war you reveal as the party explores.
- **Nested location maps** — A pin can be walked into. Open a city and you get *its own* map — a district plan, a dungeon level, a tavern floor — with its own pins and timeline, as deep as you care to nest.
- **Era Timeline** — The world map is time-aware. Define eras and waypoints on a scroll bar, and each era keeps its own pins, timeline pins and background image (including for nested location maps) — slide back and the map shows the same place centuries earlier. Timeline pins mark dated events, link to the entities involved, to the session they happened in, and to the events that caused them.
- **Entity System** — Schema-driven cards with 16 field widget types (text, markdown, image, stat block, dice roller…). Every reference on a card — spells, items, traits, relation chips — is tappable and opens what it points at.
- **Templates & Packages** — Built-in D&D 5e schema, your own templates, full import/export. **Package Links** let one package borrow another's content instead of copying it, and installed packages tell you when a newer version exists.

Sign in to sync worlds across devices and share them with collaborators.

---

## For Dungeon Masters ⚔️

Run a session without breaking flow.

- **Combat Tracker** — Initiative, HP, conditions, turn management, automatic event log.
- **Battle Map (VTT)** — 6-layer canvas (grid, token, annotation, fog, terrain, decal) with draw tool, persistent rulers and fog of war. Tokens auto-scale to creature size, distances follow your chosen 5e diagonal rule, and AoE templates (cone, line, sphere, cube, sector) plus vector annotations persist across reloads. Reuse location battlemaps without re-uploading.
- **Session & Campaign Management** — Rich notes, timeline tracking, encounter setup, state saved between sessions.
- **Soundpad** — Layered audio with gapless loops, fades and custom themes; download ready-made soundpacks (music, ambience, SFX) from Marketplace → Soundpacks.
- **PDF Library** — PDFs are copied into the world, so they travel with backups and Local Sync. Up to 10 open in tabs (50 MB each); in an online world one action shares the library and players download on demand.
- **Dice Roller** — d4 through d100.

**Second screen, three ways:** pop out a window on the same device for a TV or projector, cast to a tablet or laptop nearby, or project into every connected player's app — with per-player controls (show/hide HP, hidden tokens, DM viewport sync) and a manifest that catches late joiners up instantly.

---

## For Players 🎲

Roll up a character, then take it anywhere.

- **Character Creation Wizard** — SRD-driven: species, class, subclass, background, ability scores (point-buy, array, roll, manual), skills, equipment, traits. Imported Open5e packs feed straight into the wizard, and every option shows its source.
- **Level-Up Planner** — Auto-applies HP, proficiency bonus and hit dice; ASI/feat, fighting style, subclass and spell picks queue up as **Pending Choices** you resolve inline.
- **Multiclass & Spell Slots** — Full SRD prereq checks with readable rejection reasons and multiclass slot math. Caster classes get a real, hand-editable slot grid; a template's own slot table wins over the preset.
- **Weapon Mastery** — Mastery slots granted per class/subclass, taking the max across overlapping feats.
- **Online Play** — Join any world the DM publishes, claim a character, see live updates from every device, and drop your own marks on the projected map.

---

## Online & Offline

Everything core works fully offline. Online features (sync, sharing, marketplace, social) require a free account.

- **No account needed** — Pick **Continue without an account** on the landing screen: worlds, characters, packages and all bundled content work as-is. Screens that genuinely need a server (profile, marketplace, cloud backup, shared worlds) explain why and offer a sign-in instead of hiding. Sign in later and the offline workspace is carried into the account, database and media included.
- **Closed-Beta Online Play** — When a DM is in the beta, the whole table plays together online. Only the DM needs a beta slot; players just join.
- **Share a World** — Publish a world so players can join and see live updates. One active invite code per world; generate, copy, revoke at will.
- **Realtime Sync** — Character, member, and entity changes stream to every connected client via CDC. Offline edits reconcile on reconnect.
- **Roles** — Player and DM roles with row-level security.
- **Character Ownership** — Claim a world character, release it back, or delete it (DM only, if ownerless).
- **Personal Cloud Sync** — Back up characters, worlds, templates, and packages to your account; pick them up on another device.
- **Local Sync (LAN)** — Move worlds, packages and characters directly between your own devices over Wi-Fi, without touching the cloud. Open **Local Sync** from the profile menu or the save/sync panel, pair once (scan the QR code, or type the address + PIN), then press **Sync** — one tap syncs every paired device. Both devices must be signed into the same account; it only adds and updates, never deletes.
- **Cloud Media Tiers** — Portraits and covers sync free of quota. Entity images and battle maps count against your quota with per-kind size limits. **Live session media uses a shared transient pool** that does not bill your save space.
- **Local Media Safety** — Every image you pick is copied into the world folder, so it keeps rendering offline and travels with backups and Local Sync even if the cloud copy is gone. Files nothing references any more are swept when a world opens and closes.
- **Graceful Offline** — Network screens show a clean "You're offline" placeholder and auto-recover. Outbox writes flush on reconnect.

### Marketplace

**Marketplace needs a signed-in account** — browsing, downloading and publishing all run through the server, so *Continue without an account* mode offers a sign-in prompt instead.

- **Publish & Share** — Worlds, templates, packages, characters as immutable snapshots with title, description, tags, changelog, cover image.
- **Versioning** — Every publish is a new version. Lineage tracking links every release of the same item.
- **Browse & Download** — Filter by type, language, tags. Atomic download counters; built-in vs. community sections.
- **Contents Preview** — See what a world or package holds *before* downloading. A publish-time content summary (template name + per-category entity counts and names) drives a preview dialog and richer cards — no need to pull the full payload to know what's inside.
- **Integrity** — Database-enforced immutability on core metadata prevents silent edits post-publish.
- **Official Content** — A curated, app-owned catalog of first-party packages served from a public CDN. Surfaces under Marketplace → All / Packages with a details dialog and an Install action; works offline via a bundled fallback manifest. Banner art downloads from the CDN and is materialised as the local package cover on install. Includes Open5e-sourced content — 19 packages spanning thousands of monsters, spells, magic items, and full chargen data (classes, subclasses, species, backgrounds, feats). v13 puts the whole corpus through a repair pass: spell durations and component costs stop being rounded or invented, monster action blocks stop being truncated or duplicated, magic items link their base item, backgrounds and feats stop over-granting, and the built-in SRD creatures gain their saving-throw and skill rows. Re-install a package to pick up the corrected data.

**Ready-made packages in the Marketplace** (19, installable with one tap):

| Package | Publisher | System | Contents |
|---|---|---|---|
| Adventurer's Guide | EN Publishing | Level Up A5e | 371 spells, 59 feats, 21 backgrounds, 3 subclasses |
| Dungeon Delver’s Guide | EN Publishing | Level Up A5e | 4 backgrounds |
| Gate Pass Gazette | EN Publishing | Level Up A5e | 2 backgrounds |
| Monstrous Menagerie | EN Publishing | Level Up A5e | 1745 creature actions, 829 traits, 586 monsters |
| Black Flag SRD | Kobold Press | 5e (2014) | 1363 creature actions, 776 traits, 360 monsters, 1 class |
| Creature Codex | Kobold Press | 5e (2014) | 1182 creature actions, 925 traits, 356 monsters |
| Deep Magic for 5th Edition | Kobold Press | 5e (2014) | 515 spells |
| Deep Magic Extended | Kobold Press | 5e (2014) | 64 spells |
| Kobold Press Compilation | Kobold Press | 5e (2014) | 31 spells |
| Open5e Originals | Open5e | 5e (2014) | 17 subclasses, 2 spells, 2 backgrounds, 1 subspecies |
| Spells That Don't Suck | SoMany Robots | 5e (2014) | 180 spells |
| Tal'dorei Campaign Setting | Green Ronin | 5e (2014) | 11 traits, 11 creature actions, 5 backgrounds, 4 monsters |
| Tome of Beasts | Kobold Press | 5e (2014) | 1330 creature actions, 1039 traits, 391 monsters |
| Tome of Beasts 1 (2023 Edition) | Kobold Press | 5e (2014) | 1755 creature actions, 1022 traits, 408 monsters |
| Tome of Beasts 2 | Kobold Press | 5e (2014) | 1235 creature actions, 1014 traits, 383 monsters |
| Tome of Beasts 3 | Kobold Press | 5e (2014) | 1608 creature actions, 818 traits, 397 monsters |
| Tome of Heroes | Kobold Press | 5e (2014) | 91 spells, 76 subclasses, 29 subspecies, 19 backgrounds |
| Vault of Magic | Kobold Press | 5e (2014) | 1063 magic items |
| Warlock Zine | Kobold Press | 5e (2014) | 43 spells |

---

## Social & Community

- **Public Profiles** — Username, display name, bio, avatar, follower counts. Discovery opt-out supported.
- **Follow System** — Optimistic follow/unfollow; browse followers and following per profile.
- **Activity Feed** — Text and image posts, likes, switch between *all* and *following only*. Server-side rate-limited.
- **Direct Messaging** — Realtime 1-to-1 and group chats. Unread counters, group rename, member leave, admin-managed deletion.
- **User Discovery** — Suggested profiles and username search with prefix matching.
- **Game Listings** — Post open games with system, seats, schedule, language, tags. Filter by language/system/tags.
- **Applications** — Players apply with a message; listing owners accept, reject, or applicants withdraw.

---

## Images

<p align="center">
  <table align="center">
    <tr>
      <td align="center"><img src="media/char.png" alt="Character" width="400"/></td>
      <td align="center"><img src="media/db.png" alt="Database" width="400"/></td>
    </tr>
    <tr>
      <td align="center"><img src="media/map.png" alt="Map" width="400"/></td>
      <td align="center"><img src="media/settings.png" alt="Pack" width="400"/></td>
    </tr>
    <tr>
      <td align="center"><img src="media/social.png" alt="Social" width="400"/></td>
      <td align="center"><img src="media/session.png" alt="Session" width="400"/></td>
    </tr>
    <tr>
      <td align="center"><img src="media/marketplace.png" alt="World" width="400"/></td>
      <td align="center"><img src="media/pack.png" alt="Settings" width="400"/></td>
    </tr>
  </table>
</p>

---

## Installation

### Android
1. Download `DungeonMasterTool-Android.apk` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Enable "Install from unknown sources" if prompted.
3. Open the APK to install.

### Windows
1. Download `DungeonMasterTool-Windows.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract and run `dungeon_master_tool.exe`.

### Linux
1. Download `DungeonMasterTool-Linux.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract and run:
   ```bash
   unzip DungeonMasterTool-Linux.zip
   cd bundle
   ./dungeon_master_tool
   ```

<div id="macos-installation"></div>

### macOS
1. Download `DungeonMasterTool-MacOS.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract and drag `dungeon_master_tool.app` into **Applications**.
3. Remove the quarantine flag:
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/dungeon_master_tool.app
   ```
4. Launch from Applications or Launchpad.

### iOS
> **Note:** iOS builds are currently unsigned. Sideload via Xcode or a signing service.

1. Download `DungeonMasterTool-iOS.ipa` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Sideload using Xcode, AltStore, or similar.

---

## Development

```bash
cd flutter_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

See [flutter_app/README.md](flutter_app/README.md) for full developer documentation and [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

## License

Licensed under [CC BY-NC 4.0](LICENSE). See the LICENSE file for details.

---

## Contact

| Platform | Link |
| :--- | :--- |
| **GitHub Issues** | [Report a Bug](https://github.com/elymsyr/dungeon-master-tool/issues) |
| **Instagram** | [@erenorhun](https://www.instagram.com/erenorhun) |
| **LinkedIn** | [Orhun Eren Yalcinkaya](https://www.linkedin.com/in/orhuneren) |
| **Email** | orhun868@gmail.com |
