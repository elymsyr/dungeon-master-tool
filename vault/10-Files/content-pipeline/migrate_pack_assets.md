---
type: file-note
domain: content-pipeline
path: flutter_app/tool/migrate_pack_assets.dart
layer: tool
language: dart
status: stable
updated: 2026-07-29
tags: [file]
---

# `migrate_pack_assets.dart`

> [!abstract] Primary Purpose
> One-shot rewriter that brings bundled `.pkg.json` assets forward from the retired effect DSLs to the named grant-block fields. The Open5e packs under `assets/open5e_packs/` were emitted before the 2026-07-28 rule-system removal, so a handful of rows still carried `rule_effects` / `effects` / `granted_modifiers`. `PackagePayloadImporter.install` converts those on the way in, so the packs *worked* — which is exactly why the stale assets went unnoticed. This converts them on disk once.

## Inputs / Outputs
**Inputs**
- `dart run tool/migrate_pack_assets.dart [--dry-run] [<dir-or-file> ...]` — defaults to `assets/open5e_packs`.

**Outputs**
- Rewrites each changed `.pkg.json` in place. Format matches [[emit]]: compact `jsonEncode`, no trailing newline. A pack with nothing to convert is not touched at all, so unaffected assets stay byte-identical.
- Per-pack summary on stdout (`<pack>: <rows> rows {<key>: <count>}`).

## Dependencies & Links
- Depends on: [[rule_effects_migration]] — it calls the shipped `migrateRuleEffects` rather than reimplementing the kind→field table, so the asset rewrite and the install-time conversion can never disagree.
- Sibling of: [[emit]] (writes the assets in the first place), [[mapper_chargen]] (the producer, already emits the named fields).
- Guarded by: `test/domain/services/grant_contract_test.dart` → *"no bundled pack asset ships a retired DSL row"*, which fails with a pointer back to this command.
- Domain map: [[Content-Pipeline]]
- System flow: [[Grant-Resolution]]

## Key Logic / Variables
- **`_isLegacyEffects(slug, value)`** carries the whole subtlety. `effects` is *not* uniformly the retired DSL: on a `magic-item` it is the narrative blurb, on a `spell` / `creature-action` it is the still-live `spellEffectList`. Only a list of `{kind: …}` rows on some other card type is the feat DSL. Getting this wrong would have destroyed 1063 magic-item descriptions in `open5e-vom`.
- Keys the converter does not own are lifted out before the call and merged back after, so a card holding both a legacy row and a live `effects` field keeps the latter.
- Non-entity structure (`package_name`, `metadata`, every non-`attributes` row field) is passed through untouched — verified row-by-row after the run.

## Notes
- **Run 2026-07-29:** 45 rows in 3 packs — `open5e-a5e-ag` (9 feats: `proficiency_grant` → `granted_armor_proficiencies`, `choice_group` → `player_choices`), `open5e-open5e` (1 subspecies), `open5e-toh` (35 species/subspecies: `ability_score_bonus` → `ability_bonuses`). The other 18 packs were already clean.
- `manifest.json` carries only per-category counts and no hashes or sizes, and the rewrite changes no row count, so it needs no update.
- This is a **migration, not a step in the build**. The generator ([[mapper_chargen]]) already emits the named fields; re-running the Open5e import from scratch produces clean packs and never needs this.
