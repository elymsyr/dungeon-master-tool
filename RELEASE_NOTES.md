# Release Notes

## Dungeon Master Tool v6.1.0 — Onboarding, In-App Help, and Localization Polish (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v6.1.0) · [elymsyr.github.io](https://elymsyr.github.io/)

A focus release on first-run clarity and translation coverage. No data migration: v6.1 reads the v6.0 database as-is.

> **Heads-up — there is no auto-save and no auto-sync.** Local changes only persist when you tap **Save** in the relevant editor, and cloud sync (personal library, online worlds) only runs when you press the sync button. The welcome dialog now states this up front, but the rule applies app-wide: if you close the app mid-edit without saving, that edit is gone.

### Highlights

- **Welcome dialog rewritten** — First-run users now get a one-screen tour of the six hub tabs (Social, Settings, Worlds, Characters, Templates, Packages) and an explicit warning that saves and sync are manual.
- **Per-tab help refreshed** — The `?` button in every hub tab now opens a longer, plainer-language explanation of that section, mentions which actions live on which control, and points to Marketplace when it's the natural next step.
- **Localization sweep** — Tab labels, profile menu items, "Report a Bug" tooltips, and the most frequently-shown dialog buttons (Cancel / Save / Delete / Create / Copy / Marketplace / Refresh from cloud / Open / Sign in) are now translated into all four shipped languages (EN / TR / DE / FR) instead of falling back to English.
- **Version bump** — `6.0.1` → `6.1.0`.

### Upgrade notes
- **Schema:** no changes since v6.0. Existing local databases load unchanged.
- **Cloud:** Supabase migrations from v6.0 still apply; nothing new server-side.
- **Translations:** language strings are bundled in the app — no online fetch.

---

## Dungeon Master Tool v6.0.0 — Online Worlds, Full SRD Level-Up, and Personal Sync (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v6.0.0) · [elymsyr.github.io](https://elymsyr.github.io/)

This is the largest release since the Flutter rewrite. v6.0 turns the app from a single-DM toolkit into a shared, online table: worlds can be published with invite codes, members see character and entity changes in realtime, and your personal library (characters, worlds, templates, packages) now backs up to your account so you can move between devices without exporting files. The character system also caught up to SRD §1 — wizard, level-up, multiclass prerequisites, and weapon-mastery slot math all run end-to-end, with interactive decisions queued in a **Pending Choices** panel so you can finish a level-up later without losing context.

> **Heads-up for everyone upgrading from v5.x:** the local database auto-migrates to schema v8 on first launch. Back up your campaigns folder before launching v6 the first time if you want a hard restore point.

> **Heads-up for online features:** publishing worlds, invite codes, and personal cloud sync require Supabase to be configured. Purely-local usage (single-player, single-device) works exactly as before with no setup.

---

### Highlights

- **Online Worlds** — Publish a world, hand out an invite code, and see other players' characters, member rosters, and world entities update in realtime.
- **Character Creation Wizard** — Build a character end-to-end against SRD rules: species, class, background, ability scores (point-buy / standard array / roll / manual), skills, equipment, traits.
- **Level-Up Planner** — Non-interactive deltas apply automatically; interactive choices (ASI/feat, fighting style, subclass, weapon mastery, spells) queue as Pending Choices.
- **Multiclass Support** — SRD §1.10 ability prerequisites with AND/OR logic, multiclass caster slot calculation, and clear rejection reasons when you don't qualify.
- **Personal Cloud Sync** — Your own characters, worlds, templates, and packages back up to your account; pick up where you left off on another device.
- **Character Claim / Release / Delete** — Take ownership of an online-world character, release it back to the table, or (as DM) delete one that nobody owns.
- **Pending Choices Panel** — The character editor surfaces every owed SRD decision so old characters and mid-level-up characters can finish cleanly.
- **MembersStrip on Player Tab** — See who else is in the world and what character they're playing while you run combat.

---

### Roadmap

Planned for upcoming releases — order not final, scope may shift between patch and minor versions.

- **Better battle map system** — Smoother large-grid performance, snap-to-grid tokens with stat-block previews, line-of-sight + dynamic vision, measurement modes (cone/line/sphere), and animated AoE overlays.
- **Second screen for online play** — Dedicated player-screen view for online worlds: every member's client can act as the projected view, so remote players see the same battle map, entity cards, and reveals the in-person table sees.
- **Built-in D&D 5e package visuals** — Cover art, monster/species/class portraits, equipment icons, and spell glyphs bundled with the SRD core pack so default content stops looking like raw text.
- **More online storage for users** — Larger per-account quota for personal cloud sync (characters, worlds, templates, packages) and selectable retention tiers; current beta cap is intentionally conservative.
- **Deeper D&D 5e implementation** — Close remaining SRD gaps (Drow 120ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills, missing `auto_granted_by` metadata), automate more class/subclass effects, and finish bidirectional sync of mechanical resolutions across devices.
- **Full custom-content editors** — WYSIWYG editors for schemas, templates, and packages so creators stop hand-editing JSON.
- **Bidirectional personal sync** — Push edits from Device A back to Device B without a manual pull.

---

### Online Worlds & Multiplayer

#### Sharing a world
You can now publish any campaign online from the world panel. Publishing creates a server-side projection of the world and generates a fresh 8-character invite code. Other players paste that code into the "Join World" dialog and instantly see the world's entities, members, and any characters that aren't privately claimed.

#### Invites
Each world has **one active invite at a time**. From the world panel you can copy it, regenerate it (the old code stops working), or revoke it entirely. Invites carry a use-count and expiry so a code you handed out for a one-shot doesn't keep working forever.

#### Member roles
Two roles ship in v6: **DM** (the publisher; can manage members, publish, regenerate invites, and delete unowned characters) and **player** (can view the world, claim/release characters they own, and post to world-scoped surfaces). Row-level security is enforced server-side, so a player can't escalate by editing the local DB.

#### Realtime sync
Character, member, and world-entity changes stream over change-data-capture and apply to every connected client. If you go offline, your local edits keep working; on reconnect, your client publishes its diff and re-pulls authoritative state. Personal sync (your own private library) uses a separate one-way pull pipeline — see Known issues.

#### Character ownership
A world character can be **unowned** (visible to everyone, nobody's responsibility), **owned by you** (lives in your character tab, you can edit it), or **owned by someone else** (visible in the world, not editable here). Claim a character to take it, release it to return it to the table, and — only as DM, and only if nobody owns it — delete it.

### Characters & SRD

#### Character creation wizard
The wizard walks species → class → background → ability scores → skills → equipment → traits in one flow. Ability scores support four input methods (point-buy, standard array, 4d6-drop-lowest roll, manual) with live validation against SRD constraints. Equipment options come from the class equipment lists and respect proficiency selections.

#### Level-up planner with pending choices
Level-up now runs in two passes:

- **Auto-apply** — HP increase, proficiency bonus, hit dice, and any feature that has no decision attached.
- **Defer** — Anything that requires you to pick (ASI vs. feat, fighting style, subclass at the SRD-defined level, divine order, weapon mastery slot, spell selection, expertise targets) becomes a `PendingChoice` on the character.

The character editor exposes a **Pending Choices** panel showing every owed decision. You can resolve them in any order and at any time — characters mid-level-up no longer block on a modal.

#### Multiclass
Multiclassing into a second class now checks SRD §1.10 ability prerequisites with full AND/OR logic (e.g. Paladin needs Strength **and** Charisma 13; some classes accept either of two stats). When a class is rejected, the wizard tells you exactly which ability gate failed and what the threshold is. Caster spell slots use the multiclass caster table.

#### Weapon mastery
Weapon Mastery slot counts now resolve automatically from class and subclass features. When two features grant mastery slots, the resolver takes the **maximum** (matching the Fighter pattern in the SRD), not the sum.

### Marketplace

The marketplace is now a first-class destination: worlds, templates, packages, **and characters** can be published as immutable snapshots. Each publish creates a new version; lineage tracking links every version of the same item so subscribers can see history. Listings carry title, description, tags, changelog, and a cover image. Atomic download counters keep the leaderboards honest. Built-in items are kept in their own section from community uploads.

### Smaller improvements

- **Hub** — Cross-world character list with claim/release/delete controls inline; personal sync indicator per character.
- **Battle Map** — 6-layer canvas (grid/token/annotation/fog/terrain/decal) keeps state across player-screen projection.
- **Soundpad** — Layered audio engine with gapless loops, fades, and YAML-based custom themes.
- **Themes** — 11 themes (dark and light variants): dark, light, parchment, ocean, emerald, midnight, discord, baldur, grim, frost, amethyst.
- **l10n** — Four supported languages (English, Turkish, German, French). New strings for online-world and pending-choice flows are translated across all four.
- **Admin** — Bug-report screen surfaces submitter app version and platform on each report card.

---

### Bug fixes

- **Character tab visibility** — Characters with no owner and no world correctly surface in your tab again; previously, some imported online-world characters got hidden when their owner left.
- **World import** — DM dropping ownership during world import no longer leaves orphan-but-owned characters; the import flow now consistently switches the button to "Release" when ownership lingers.
- **Realtime member list** — Member additions and removals propagate to every connected client without requiring a manual refresh.
- **SRD subclass + weapon mastery choices** — Subclass and weapon mastery picks now show up as pending choices instead of being silently skipped.

---

### Deprecations & removals

- **PyQT-era gallery images** — Removed from the README; they no longer matched the Flutter UI.
- **Legacy admin builtin migration** — The `025_drop_admin_builtins.sql` cleanup retires the old admin-managed built-in package surface in favor of the new bundled SRD core pack.

---

### Upgrade notes

- **App version bump:** `5.1.0` → `6.0.0`.
- **In-app migrations:** Local DB auto-migrates to schema v8 on first launch (adds `entities.packageId/packageEntityId/linked` columns + `installed_packages` table, and heals dev DBs whose initial createAll predated either). Idempotent.
- **Legacy DB path:** A one-shot copy from `{ApplicationSupportDirectory}/DungeonMasterTool/.../dmt.sqlite` to `AppPaths.dataRoot/.../db/dmt.sqlite` runs once on first launch. The legacy file is **not** deleted; a `.moved_to_dataroot` marker is written next to it.
- **Online features:** Supabase must be configured (URL + anon key) for online worlds, invites, personal sync, marketplace, social, and LFG. Local-only usage is unaffected.
- **Marketplace listings:** Listings published before v6 won't have cover images, lineage links, or the character item type until re-published.
- **Android:** No special action — APK installs over previous versions.
- **iOS:** Still unsigned; sideload via Xcode or AltStore as before.

---

### Known issues

- **Personal sync is one-way pull only** — You can back up to and pull from your account, but a change made on Device A doesn't push back to Device B without a manual pull. Bidirectional sync is tracked for a later release.
- **Custom content editors (full WYSIWYG)** — Entity editor scaffolding exists, but the full schema/template/package editor suite is deferred post-v6.
- **SRD `auto_granted_by` data audit** — A handful of class feats still lack `auto_granted_by` metadata, so a few subclass-tied features don't yet appear in Pending Choices. The resolver is correct; the missing data lands in a 6.0.x patch.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision, Berserker condition immunities, and Lore Bard L3 extra skill proficiencies are tracked but not yet wired into the mechanic resolver.
- **Window glitch on personal sync (desktop)** — A repaint glitch can briefly flash the personal-sync indicator during the first sync after launch. Cosmetic; data is unaffected.

---

*Thanks for playing. Roll well.*
