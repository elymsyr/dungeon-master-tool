---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/bin/dupe_census.dart
layer: tool
language: dart
status: stable
updated: 2026-08-13
tags: [file]
---

# `dupe_census.dart`

> [!abstract] Primary Purpose
> Duplication + cross-package-ref census over the bundled Open5e packs. Sibling of [[audit_packs]]: that tool asks *"are the fields filled?"*, this one asks *"should this entity exist at all?"*. Since [[Package-Links]] shipped (2026-07-29) a package can **link** another instead of copying it, and the built-in SRD pack is in scope everywhere implicitly — so a pack shipping its own "Acolyte" or "Amphibious" is shadowing content, not adding it. This measures how much of that there is. Backs `flutter_app/docs/open5e_content_audit.md` §3.2.

## Inputs / Outputs
**Inputs**
- `dart run tool/open5e_import/bin/dupe_census.dart [--packs <dir>] [--only <slugs>] [--markdown] [--list <slug>]`
- Reads the shipped assets plus the built-in pack (`generateBuiltinDnd5eV2Schema().seedRows` + `buildSrdCorePack()`, both pure Dart — no DB, no Flutter binding, **no source snapshot**).

**Outputs** — a headline, a fidelity block and three censuses:
- **headline** — the A ∪ B redundant total, the monster-owned share of it, and the **actionable redundancy** the audit's L1/L2 phases are graded on.
- **matcher fidelity** — how far the identity key and the resolver's matcher disagree, in both directions, for each section.
- **A** bundled entity ⟷ built-in pack (drop candidates: nothing to link, the built-in row is already in scope), split same-text / name-only / no-text.
- **B** bundled entity ⟷ another bundled pack (one owner + `metadata.links` candidates), same three-way text split per name.
- **C** cross-pack `softRef` targets, bucketed built-in / other pack / own pack / **nothing installed**, resolved the way [[entity_ref]] does.
- `--list <slug>` prints the colliding names in one category so drop-vs-keep can be decided row by row, marking each `=` / `≠` for text agreement and `[owned]` for a statblock's own child row.

## Dependencies & Links
- Depends on: [[builtin_schema]], [[srd_core_pack]] (the in-scope set), [[emit]] (the asset shape).
- Related: [[audit_packs]], [[Package-Links]], [[Ref-Resolution-Hard-vs-Soft]], [[build_catalog]] (`requires` comes from the `metadata.links` this census argues for).
- Domain map: [[Content-Pipeline]]

## Key Logic / Variables
- **Two keys, because identity and resolution are different questions** (phase L0, 2026-07-30). Sections **A/B key on identity**: `(category slug, lowercased name)`, exact — case folded because the importer title-cases, and a trailing parenthetical **never** stripped. Section **C keys on the resolver**: [[entity_ref]] `findEntityIdByName` exactly — case sensitive, one trailing-parenthetical retry. Both deltas are printed.
- ⚠️ **L0 was planned as "match like the runtime everywhere" and that would have been wrong.** The resolver's qualifier retry means `"Legendary Resistance (3/Day)"`, `"Wing Attack (Costs 2 Actions)"` and [[mapper_monster]]'s `_ensureChild`-disambiguated `"Scimitar (Firetamer)"` all strip onto a built-in card — **3,501 rows**, which took the headline from 20.9% to 34.9% while describing no duplication at all (the qualifier *is* the mechanic). Those 3,501 are instead a **latent resolution hazard**, filed on audit phase **T3**: nothing points at those names today, and a future softRef naming a qualified child would silently land on the generic built-in row.
- **Section C's "0 dangling" was false.** With the resolver's matcher, **1** ref dangles: `open5e-toh`'s `subspecies` "Favored" emits `spell "Spare The Dying"` while every pack in scope spells it `"Spare the Dying"`. Capital T, dropped silently at read, invisible to the build gate (soft refs never gate). Fix filed as the first box of audit phase **L3**; until then the gate's baseline is 1, not 0.
- **A name collision is not proof of identical content — the census now measures it per row.** Three buckets, not two: same text / **name only** / **no text on either side**. The third exists because `monster` ships an empty top-level `description` in every pack (the statblock lives in `attributes`) and the synthesised gear stubs have no prose at all — a two-bucket column would have reported 588 monster names and 15 gear names as "identical content". Result: **7 of 1,660** section-A collisions genuinely say the same thing; in section B, 188 of 2,540 names are identical, 1,749 only share a name, 603 have no prose to compare. Text is normalized by collapsing whitespace (so a reflow is not a divergence).
- **`creature-action` / `trait` rows are monster-owned children, not library entities.** `_collectOwnedIds` walks the five `monster` child-ref lists (`action_refs`, `bonus_action_refs`, `reaction_refs`, `legendary_action_refs`, `trait_refs`) and marks every id they reach; collapsing those by name reassigns another creature's text to this creature. **16,324 of 22,005 entities (74.2%) are owned rows, and 3,279 of the 4,462 redundant copies are** — which is why the census's headline is now **actionable redundancy 1,183 (5.4%)** and both categories report 0. `--list` marks them `[owned]`. See [[Package-Links]] and audit doc §2.5.
- **`--only <slug>` is the L1/L2 work list**: per category, actionable = `monster` 802, `spell` 318, `adventuring-gear` 43, `background` 13, `feat` 1, `magic-item` 1, `creature-action`/`trait` 0 — summing to exactly the 1,178 headline.
- Level Up: Advanced 5e (`game_system: a5e`) deliberately restats SRD material — 313 of *Adventurer's Guide*'s 371 spells collide by name and most should be **kept**. `game_system` is display-only metadata, so it cannot carry the decision automatically; the tool reports candidates, policy is per document.
- **`_redundantTotal`** is the A ∪ B union, not their sum (a trait can be in the built-in pack *and* in six packs): a name the built-in ships makes every bundled copy redundant, a name only packs ship makes all but one redundant.
- **`_walkSoftRefs`** recurses the whole `attributes` tree for the `{slug, name}` envelope and deliberately skips `{_ref, name}` (in-pack hard ref, build-gated) and `{_lookup, name}` (Tier-0, resolved at import).

## Notes
- **Run 2026-08-13 (post-promotion):** 19 packs / 22,005 entities vs 2,717 built-in rows → 4,462 redundant (20.3%) of which 3,279 monster-owned → **actionable 1,183 (5.4%)**. A = 1,666 (7 same text / 1,636 name-only / 23 no-text), B = 2,576 names / 3,524 copies. Section C = 158 softRefs (128 → built-in, 29 → own pack, **0 → another bundled pack**, **1 dangling**). (Pre-promotion, 2026-07-30: 20,712 entities, 4,331 redundant, actionable 1,178, C = 135.)
- The pre-L0 headline numbers are unchanged (4,331 / 20.9% / A 1,660 / B 3,393), so the identity key is backward-compatible with everything §3.2 quoted; only the *readings* are new.
- Section C doubles as the guard rail for the audit's fill phases: it must **grow** as `*_ref` fields get filled, and "nothing installed" must not rise above its baseline of 1 — and reach 0 once L3's casing fix lands. **Valid since L0: C now resolves the way the app does.**
- ⚠️ `--only <slug>` filters the *entities counted*, not `_collectOwnedIds`, which always scans every `monster` — ownership is a property of the owner, so `--only trait` must still see who refs each trait. The consequence: `--only creature-action,trait` correctly reports 0 actionable, while `--only monster` reports 802.
