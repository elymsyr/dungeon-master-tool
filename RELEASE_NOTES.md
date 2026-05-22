# Release Notes

## Dungeon Master Tool v8.3.1 — SRD Armor Mechanics, Derived Combat Stats, Per-World DB Filters (Beta)

**Release date:** May 2026
**Downloads & source:** [GitHub release](https://github.com/elymsyr/dungeon-master-tool/releases/tag/v8.3.1) · [elymsyr.github.io](https://elymsyr.github.io/)

A maintenance release on top of v8.3.0. The character editor now resolves armor consequences from the SRD 5.2.1 rules instead of leaving them to the DM, the combat-stats grid shows live derived values for level and AC, and the database sidebar remembers its filters per world. Several bugs around equipped armor, image decoding, and shared-entity sync are fixed. No database or cloud migrations.

### Highlights

- **SRD armor consequences** — The character resolver now derives the rule consequences of worn armor: an untrained-armor penalty (Disadvantage on STR/DEX D20 Tests + no spellcasting), a Speed −10 ft cut when STR is below the armor's requirement, and Stealth disadvantage. `EffectiveCharacter` carries a new `armorNotes` list and the combat-stats field renders them as an amber warning banner above the grid.
- **Derived combat stats** — The `combat_stats` grid's **Level** and **AC** cells are now read-only and track live derived values — root `level` (kept current by level-up) and resolver-computed armor class (equipped armor + Dex + shield) — instead of stale manually-stored entries. Monsters/NPCs with no root level or resolver AC keep the editable stored value.
- **One suit + one shield** — Equipping a piece of armor now auto-unequips any other equipped armor in the same slot (body / shield), enforcing the SRD "one suit of armor and one shield at a time" rule.
- **Equipped-armor detection fix** — `_equippedArmor` / `_hasEquippedShield` resolved the wrong field (`armor_category_ref`) and could pick up non-armor rows. They now read `category_ref` and require `categorySlug == 'armor'`, so AC, shield bonus, and armor-training checks resolve correctly.
- **Live AC on the stat-chip strip** — The character header's AC chip resolves off the live working copy, so equipping armor refreshes it immediately instead of lagging behind the persisted character.
- **Magic-item text corrections** — Weapon +1, Armor +1/+2/+3, and Shield +1 effect text rewritten to the SRD 5.2.1 wording. Armor +2 rarity corrected Rare → Very Rare and Armor +3 Very Rare → Legendary.
- **Version-aware SRD pack re-seed** — `SrdCorePackageBootstrap` now re-seeds the built-in pack whenever the code's `pack_version` differs from the stored copy, so content fixes land without a manual reinstall. SRD core pack bumped `1.0.0` → `1.0.1`.
- **Standard Array swap** — Picking an array value already held by another ability now swaps the two abilities instead of disabling the option, so the array always stays a valid permutation (no duplicate, none dropped). Every value stays selectable.
- **Manual ability-score focus fix** — The manual ability-score field uses a stable widget key so typing no longer rebuilds the field and drops keyboard focus.
- **Per-world database filters** — The database sidebar's category, source, share-mode, and sort selections are now persisted per world instead of in one global list, so filters no longer leak across worlds and survive exit/re-entry. (The legacy global filter resets once on upgrade.)
- **Sidebar filter jank fix** — The filter/sort cache key switched from an identity hash of the shared-entity set to a value-based hash, so a keyboard relayout no longer forces a full ~7 K-entity filter+sort re-run.
- **Single-axis image decode** — Character portraits and `AssetRefImage` now decode on one axis only. Passing both `cacheWidth` and `cacheHeight` made `ResizeImage` stretch the bitmap to those exact dimensions, distorting the image before `BoxFit` could crop it.
- **Shared-entity sync catch-up** — `applyInitialState` now invalidates the world entity-shares cache on reconnect / world re-entry. `entity_shares` CDC isn't replayed across a disconnect, so shares made while offline were filtered out by a stale list and the card never opened.
- **Minor UI fixes** — The "Character not found" screen gained a back button; the editor's Edit/View toggle icon was swapped to match its action; armor `base_ac` minimum lowered 10 → 0 so the Shield row (base_ac 2) is accepted in the content editor.

### Upgrade notes

- **App version bump:** `8.3.0` → `8.3.1`.
- **SRD core pack:** `1.0.0` → `1.0.1` — re-seeds automatically on first launch; no manual reinstall.
- **Local DB:** schema v12, unchanged. No migration.
- **Cloud migrations:** none.
- **No user action required.**

### Known issues

- **Custom content editors (full WYSIWYG)** — Still deferred; JSON editing remains the workaround for schemas and templates.
- **Row-level save+sync** — F0 (repo API) shipped in v8.0; F1–F6 (per-row outbox, change-bus apply, CDC row-merge) still pending.
- **Remaining SRD effect gaps** — Drow 120ft superior darkvision, Berserker condition immunities, Lore Bard L3 extra skills.
- **D7 test harness** — Drift v12 round-trip test harness for the auto-migration path is still pending.