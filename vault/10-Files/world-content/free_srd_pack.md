---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/free_srd_pack.dart
layer: domain
language: dart
status: active
updated: 2026-11-03
tags: [file]
---

# `free_srd_pack.dart`

> [!abstract] Primary Purpose
> The free SRD package's converter (`docs/free-template/SRD-FREE-ALANLAR.md` §8, K11): the one place that turns the core SRD pack's cards into the shape the ready-made free template (`srdFreeTemplate`) reads. It runs when the package is seeded, so the free package needs no read-time conversion; the core pack itself never changes (ROADMAP K1). The work grows phase by phase (A1–A10, §11); A1 only writes into the data what [[free_field_styles]] and [[free_srd_levels]] read out of the SRD shapes.

## Inputs / Outputs
**Inputs**
- One pack card ([[entity]], `_lookup` placeholders unresolved, ids already the free package's) and every pack card by id.
- `srdFreeTemplate`'s categories ([[free_template]]).

**Outputs**
- `freeSrdFields(card, byId)` → the card's fields as the free template shows them.
- `freeSrdDescription(card)` → the card's description in the package: `''` for a closed category (S1), else unchanged.
- `inFreeSrd(slug)` — whether the free package carries the category's cards (the copy drops some, §5.14).
- `freeSrdClosed` — the categories finished so far (A2: `spell`; A3: `feat`, `trait`; A4: `species`, `subspecies`; A5: `class`, `subclass`, `background`; A6: `monster`, `animal`, `creature-action`; A7: `magic-item`, `weapon`, `armor`, `tool`, `adventuring-gear`, `pack`, `ammunition`, `mount`, `vehicle`); also read by [[extract]] (their free texts join the TR coverage) and the G7 guard.
- `freeSrdPackVersion` — bumped whenever the converter writes something new (7 since A7); the free package re-seeds on a change.

## Dependencies & Links
- Depends on: [[free_field_styles]] (`freeFieldValue`, `structuredListAsMarkdown`), [[free_srd_levels]] (through `freeFieldValue`), [[entity_ref]] (`entityRefName`), [[free_template]] (`srdFreeTemplate`), `free_srd_texts.dart` (SRD lines word for word from the PDF: species Size, lineage Level 1 cells)
- Used by: [[srd_core_package_bootstrap]] `_ensureFree` (writes the package), [[extract]] and [[suggest]] (the free texts for Turkish)
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/SRD-FREE-ALANLAR.md` §8, §11

## Key Logic / Variables
- **A1 (2026-10-28):** for every field of the card's category in the free template, the stored value becomes what `freeFieldValue` shows: `srd_read` Level tables and Grants (class / subclass features with slots and level-bound pools, spells at level, own pools) as free rows and items with `_id`; Monster / Animal flat AC / HP / Initiative as the Combat stats block; a markdown field's SRD list (starting equipment, player choices, subspecies options) as its markdown text. A value that reads as nothing but was not empty (a feat's level-bound pool, granted from the class rows) is stored empty, never left in its SRD shape.
- Refs and `_lookup` placeholders stay: the world resolves them when it synthesises the card ([[builtin_synth]]), the installer when it copies it.
- Categories the free template lacks pass through untouched; `_ensureFree` leaves their cards out (`inFreeSrd`).
- **Closed categories (A2+):** a card of a `freeSrdClosed` category keeps only the fields the copy declares (the dropped SRD fields leave the data) and loses its description (S1: it repeated the rules text field).
- **Grant block (A3, §4):** in a closed category the Grants field (`grantHolder`) gets, after the card's own pool items, one card item (`srdCardItem`, id `srd-g<n>`) per ref of the grant block's card lists, aimed at the player card list `_grantTargets` names (`srdFeatureTargets` + vulnerabilities, tools, weapon/armor, spells, cantrips, traits; a sense row gives its `sense_ref`, its range stays in the text). A card with `active_while_state_ref` (Rage) gets none (R6). Numbers, flags and skill grants stay only in the text (R3/R6, scanned in the test).
- **Species / Subspecies (A4, §5.4–5.5):** `_speciesLines` writes `size` (the SRD line from `free_srd_texts.dart`, else the size card's name) and `traits` (markdown: "As a Dwarf, you have these special traits." and one `**Name.** text` paragraph per sense — with its range — trait and action card, names without their "(Elf)" suffix, sorted; `mechanical_notes` last). `_lineageRow` puts a Level 1 row (`srd-lineage`) before a subspecies' spell rows: the SRD table cell, or for a lineage in no table its resistances / skill / HP / ability bonuses / cantrips in the SRD's sentences; its cantrips as card items. A subspecies' Grants skip its cantrips and sense (`_grantItems(skip:)`).
- **Class / Subclass / Background (A5, §5.2, §5.3, §5.6):** `_classLines` writes the Core Traits lines — `primary_ability` ("Strength and Constitution"), `skill_proficiencies` ("Choose 2: …, or Survival"), `weapon_proficiencies`, `tool_proficiencies` — from the data, with `srdClassLines` (`free_srd_texts.dart`) where the data cannot say it ("Strength or Dexterity", a kind of tool); `equipment_choice_groups` becomes the SRD line ("Choose A or B: (A) …, and 15 GP; or (B) 75 GP", `_equipment`); `becoming` is the "Becoming a …" box (the multiclass line from `srdClassMulticlass`, the rest the same in every class, the spell-slot sentence for casters). **S3** (`_featureRows`): a class / subclass row that grants a feat keeps only the feat item; `_featRowItems` adds the row's other cards to that feat's Grants (to the row's feat of the same name, else the first; a trait named as a feat is that feat again and goes; a card the feat's own block already gives is not repeated). A class's `granted_languages` (Druidic, Thieves' Cant) are card items in the row of their name. `_backgroundLines`: `tool_proficiency` (names, or `srdBackgroundTools` for a choice), `equipment_choice_groups` (no "and"), and the origin feat and tool as grant-block cards for the new Grants field. `freeSrdDescription` gives a subclass the SRD line under its name (`srdSubclassIntros`).
- **Monster / Animal / Action (A6, §5.10, §5.11):** `_statBlockLines` writes `speed` as the SRD line ("40 ft., Burrow 20 ft., Fly 80 ft. (hover)", from the five `speed_*_ft` and `can_hover`) and puts the flat `xp` into the Combat stats block, which `combatStatsValue` fills with AC / HP / Initiative from the flat fields; the flat fields then go. `_actionText` writes what the SRD puts in an action's heading at the start of its text — "(Recharge 5–6). ", "(3/Day). ", "(1/Day). " for a Long Rest, "(Recharge after a Short or Long Rest). " — unless the text already says it, and a save DC the text lacks ("*Dexterity Saving Throw:* DC 14, …" into the save line, or such a line first); Commanding Presence's DC is its Spellcasting's.
- **Magic item and equipment (A7, §5.9, §5.12):** `_armorClass` writes an armor's `armor_class` as the Armor table does ("14 + Dex modifier (max 2)", "16", a Shield's "+2") from `base_ac` / `adds_dex` / `dex_cap`; a tool's `craft` is its Craft line from `srdToolCrafts` (`free_srd_texts.dart`, PDF word for word; tools that craft nothing have none); an armor category's `effects` is its don / doff time (`srdArmorDonDoff`, the table's category headings). An open category's card (armor-category) keeps its own fields beside the new one. Magic items lose their description (S1: it was `effects` again); charges stay data (S4).
- **Spell (A2, §5.1):** `_spellLines` writes the SRD's header lines from the dropped fields: `casting_time` ("Action", "1 minute or Ritual", "Reaction, which you take when …" from `reaction_trigger`), `range` ("150 feet", "1,000 feet", Self / Touch / Sight / Unlimited; a bare Ranged is "Special"), `components` ("V, S, M (a diamond worth 500+ GP, which the spell consumes)": the material lower-cased, the consume clause only when the material text lacks it, a cost no text states appended — Find Familiar), `duration` ("Concentration, up to 1 minute", "Until dispelled", "1 round"). The pack's deviations stay (K13): its builder stored 23 Bonus Action spells as Action.

## Notes
- Tests: `test/domain/services/free_srd_pack_test.dart` — A2: sample spells' four lines (PDF lines where the pack agrees), every spell's lines and fields, S1, the three lookups gone; A1 equivalence (a closed category's new lines skipped) (every card and field shows the same as the SRD read did, placeholders resolved as a world resolves them), "stored data needs no read", and the G7 guard (filled fields declared in the copy except the known leftovers of later phases, no link to a missing category, every added field filled somewhere).
