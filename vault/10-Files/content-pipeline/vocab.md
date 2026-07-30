---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/vocab.dart
layer: tool
language: dart
status: stable
updated: 2026-07-30
tags: [file]
---

# `vocab.dart`

> [!abstract] Primary Purpose
> The **second canon** behind [[normalize]]'s first one. Open5e's content fixtures reference Tier-0 rows by **fixture pk** (`thieves-cant`, `void-speech`, `titanic`), and the display names live in separate vocabulary fixtures — eleven files in the `open5e/core` document plus per-document extensions. [[normalize]] used to match those pks against the built-in canon by lowercasing / title-casing them, which misses any pk whose name is not a mechanical title-casing *and* every value the built-in Tier-0 simply lacks; both landed in `unmapped_report.json` with the field silently dropped. This file reads the vocabulary and turns a pk into a name, then either resolves it against the built-in canon or mints a Tier-0 row **inside the pack**. Added by audit phase **B9** (2026-07-30); took `unmapped_report.json` from 144 values to 70.

## Inputs / Outputs
**Inputs**
- `Vocabulary.load(dataRoot)` walks **every** `data/v2/<publisher>/<doc>/` and reads the files in `vocabFileSlugs`. Global, not per-document, on purpose: a Tome of Beasts **2** monster speaks `void-speech`, but the fixture defining it is in `kobold-press/tob/`.
- `seedTier0Row` additionally takes the live [[refgraph]] `PackBuilder` for the pack being built.

**Outputs**
- `Vocabulary.name(slug, raw)` → upstream display name, or null. Independent of what the built-in Tier-0 holds.
- `Vocabulary.row(slug, name)` → the fixture record, for its extra columns.
- `seedTier0Row(pack, vocab, slug:, name:, source:)` → adds a Tier-0 `packEntity` to `pack` (idempotent per `(slug, name)`) and returns a build-gated `ref(slug, name)`.
- `vocabFileSlugs` — the file → Tier-0 slug map (10 entries).

## Dependencies & Links
- Depends on: [[loaders]] (`loadFixtures`, `Fixture`), [[normalize]] (`titleCase`), [[refgraph]] (`PackBuilder`), [[srd_helpers]] (`packEntity`, `ref`).
- Used by: [[normalize]] (`Normalizer.vocab`, consulted inside `lookupRef`), [[build_packs]] (loads it once, rebinds `norm.tier0Seeder` per pack).
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]], [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[SRD-5.2.1]]
- Tests: `flutter_app/test/tool/vocab_test.dart` (10 cases, real snapshot fixture shapes).

## Key Logic / Variables
- **Alias index shape**: `slug → (lowercased alias → upstream display name)`. Each row is indexed under three aliases: the raw pk, the pk with its `<doc>_` prefix stripped (`a5e-ag_bloodied` → `bloodied`), and the display name itself.
- **`core` wins.** Document directories are sorted so `open5e/core` is read first and `putIfAbsent` keeps it; a third-party document can only ever *add* vocabulary, never redefine a core row.
- **The read never overrides a value that already mapped.** `Normalizer.lookupRef` consults `vocab` only after the built-in canon misses, so B9 cannot change existing output. See [[normalize]] for the three-outcome ladder.
- **Two outcomes, and the first one is the surprise.** `thieves-cant`'s upstream name is `Thieves' Cant`, which the *built-in* pack already ships — title-casing can never reach the apostrophe, so this was never third-party content and **nothing new ships** for it. Only genuinely-new vocabulary (`void-speech`, `titanic`) gets seeded.
- **Seeding is pack-local by policy** (audit §2): third-party vocabulary is minted in the package that needs it, never added to the built-in schema. The returned `{_ref}` is build-gated, so a seeding bug fails the build rather than shipping a dangling ref. Note the consequence: 6 Tome-of-Beasts-family packs each ship their own one-row `Void Speech`, which the audit files on its **L2** linking phase rather than hiding.
- **`_tier0Extras` fills only scalar columns upstream actually states** — `language`: `is_exotic`/`is_secret` → `tier: Rare|Standard`, `script_language` → `script`; `size`: `space_diameter` → `space_ft`, `suggested_hit_dice: d20` → `hit_die_size: 20`. Everything else ships with name + summary, which is enough for the relation to resolve and render.
- **One value is derived, and labelled**: `carrying_multiplier: 16.0` for a size above Gargantuan's 20 ft, extrapolated from the built-in ladder's doubling (L 2, H 4, G 8). Upstream has no such column.
- **`skill.ability` is deliberately not mapped.** The fixture has `ability: 'int'` and it looks like a free win, but the built-in field is `ability_ref`, a *relation* — guessing its shape would not be a fixture read. No `skill` value is currently unmapped anyway.

## Notes
- **`Environment.json` has no home.** 19 core rows + `tob_badlands`, and there is no `environment` slug in `tier0Slugs`, so it is absent from `vocabFileSlugs` by design (a test asserts it stays unread). `ItemCategory.json` stays out for the reason A1 recorded — it is an item taxonomy and nothing currently fails to map for `magic-item-category`.
- **`open5e/core` is still correctly not a package.** [[sources]] refuses to build a pack from it because it carries no content; this is a vocabulary read, **not** a new `_mappedFiles` entry. Do not "fix" the discovery skip.
- Only the `alignment` bucket survives in `unmapped_report.json` (70 values). That is **not** a vocabulary gap — `core/Alignment.json` holds exactly the 9 canonical values and upstream `Creature.alignment` is free text — so it is owned by the audit's **B10**, not by this file.
- `assets/open5e_packs/` predates B9; the shipped assets still show the old empty `size_ref`/`language_refs`. Promoting a rebuild is Stage D.
