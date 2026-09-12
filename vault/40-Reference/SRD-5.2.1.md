---
type: reference
domain: content-pipeline
updated: 2026-09-12
tags: [reference]
---

# SRD 5.2.1

> [!summary] What this is
> The System Reference Document the built-in content is authored against. Source PDF lives at `docs/SRD_CC_v5.2.1.pdf`. Deferred content in `docs/add_later/`.

## Coverage in code
Hand-authored built-in pack [[srd_core_pack]] (`lib/domain/entities/schema/builtin/srd_core/`, `pack_version` 1.0.8): **2,719 entities over 59 categories** — 2,350 Tier-1 + 369 Tier-0 seed rows. Re-counted 2026-08-17 with `audit_packs --builtin`; the older figures on this line (71 classes / 55 subclasses / 29 backgrounds / 236 feats / 364 spells) were stale.

Biggest categories: `creature-action` 528 · `spell` 341 · `feat` 305 · `magic-item` 286 · `monster` 248 · `trait` 238 · `adventuring-gear` 107 · `animal` 97 · `weapon`/`tool` 38 · `subspecies` 30 · `background` 16 · `class` 12 + `subclass` 12 (SRD ships exactly one subclass per class, all granted at level 3) · `species` 10 (9 from SRD 5.2.1 + **Half-Elf**, an SRD 5.1 legacy row — see below).

Field coverage: **306 of 725 declared (category, field) slots filled, 0 required-and-empty.** Of the 419 empty ones, 194 are the five shared Tier-0 lookup fields (`abbreviation`/`summary`/`effects`/`icon_name`/`color` — only `ability` and `skill` are written, so 345 vocabulary rows are name-only) and ~205 are grant-block fields that are empty by design. Two audited gaps are filed as findings in `flutter_app/docs/pack_conformance_findings.md`: no `save_bonuses`/`skill_bonuses` on any of the 345 statblocks (F-builtin-01) and no written cause-code table for the 419 empty slots (F-builtin-02).

## SRD 5.1 legacy content

5.2.1 dropped Half-Elf and Half-Orc. Where the 5.1 race survived as a *flavour* of a
2024 species it is modelled as a `subspecies` (Half-Orc → Orc, Lightfoot/Stout →
Halfling, Hill/Mountain → Dwarf, Standard Human → Human). **Half-Elf is the exception
and ships as its own `species` row**: subspecies grants are purely additive
(`CharacterResolver` never suppresses a parent's `trait_refs`), so hanging Half-Elf off
Elf would have handed it Trance, Keen Senses (Elf) and Elven Lineage — none of which
SRD 5.1 Half-Elf has. Fidelity beat filing consistency. Its SRD 5.1 ASI
(CHA +2 and two free +1s) is deliberately **not** carried: `background_asi` and a
grant-block `ability_bonuses` are applied by two independent resolver passes that
never see each other, so a species ASI stacks on top of the background's +2/+1 —
the 2024 rules moved the ASI off the species card precisely to avoid that.
(`Standard Human` still carries the old shape and still double-dips.) The ASI, the
two Skill Versatility skills and the bonus language are prose in `mechanical_notes`;
neither `species` nor `subspecies` declares `asi_distribution_options` (only
`background` does). Card art was generated with `tool/art_gen`
(subject written by hand in `subject_cache.json` — no Gemini key on this machine)
and bundled to `assets/art/srd/68f4cc2b-e065-5a13-a40b-71fcc8d9032a.webp`. Guarded by
the Half-Elf case in `test/domain/services/srd_grants_integration_test.dart`, which
asserts the bundled art file exists as well as the grants.

Wire format + ref placeholders via [[srd_helpers]]; card mechanics as named grant-block fields (see [[Grant-Resolution]]).

## Mechanics index
- Extra Attack, Weapon Mastery (§1.7), resource pools with `count_formula`, Drow Superior Darkvision (120 ft), etc. — resolved by [[character_resolver]] (see [[Grant-Resolution]]).

## Related
- MoCs: [[Content-Pipeline]] · [[Character-System]]
- Licensing: [[Content-Licenses]]
