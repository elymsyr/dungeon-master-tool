---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/free_srd_levels.dart
layer: domain
language: dart
status: active
updated: 2026-10-12
tags: [file]
---

# `free_srd_levels.dart`

> [!abstract] Primary Purpose
> The SRD copy's level system, read from the SRD shapes it replaced (`docs/free-template/DESIGN.md` §16.3, ROADMAP Faz 7b). The SRD pack never changes (K1); a free Level table / Grants field whose `styleConfig.srd_read` names one of three kinds shows what this file builds from the card's SRD data until the card is edited — then the card stores its own rows. Output is the free value shape of [[free_grants]]; nothing computes a sheet value (D2).

## Inputs / Outputs
**Inputs**
- The kind (`srd_read`), the field's stored value, the card's values, the world's cards by id (granted feats' pools, Resource Pool names, spell names).

**Outputs**
- `srdClassFeatures` (`class_features`), `srdSpellsAtLevel` (`spells_at_level`), `srdResourcePools` (`resource_pools`), `srdLevelReads`.
- `isSrdLevelShape(v)` — null, empty, or rows without `_id` (free rows and items always carry one).
- `srdLevelValue(kind, stored, card, byId)` — Level table rows or Grants items.
- `srdFeatureTargets` — SRD feature-row list → the copy's player-card list (§16.3 table: `granted_feat_refs` → `feats`, `granted_trait_refs` → `trait_refs`, actions / bonus actions / reactions, `always_prepared_spell_refs` → `spells_known`, senses, languages, resistances, immunities).

## Dependencies & Links
- Depends on: [[entity]], [[entity_ref]] (`resolveEntityRef`), [[caster_progression]] (`parseCasterKind`, `slotsByLevelOverride`, `defaultSpellSlotsByLevel` — read only, K4; an application-layer import like `character_ext.dart`'s), [[builtin_schema]] `lookups.dart` (`kResourcePoolLabels`, read only)
- Used by: [[free_field_styles]] (`freeFieldValue` dispatches on `srd_read`), so [[free_grants]] `computeGrants` and `entity_card.dart` read the same rows
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/DESIGN.md` §8.4, §8.5, §12.2, §16.2–§16.3; `docs/free-template/ROADMAP.md` Faz 7b

## Key Logic / Variables
- **Class / subclass `features` (`class_features`):** one row per SRD feature row — `level`, text `**Name.** description`, a card item per ref in its granted lists with `targets: {player-character: list}`. After them, one extra row per level (`srd-l<N>`) holding: the **caster kind's slots** (`spell_slots_by_level` override per level, else the `caster_kind` preset): `Level N Slots` wherever a count changes (short keep, long fill), a Warlock's single `Pact Slots` (short and long fill); and the **level-bound pools of the feats the row grants** (`count_by_level` with `class_ref`, or `monk_level` / `sorcerer_level` / `paladin_level_x5`), from the feature's level up, one item wherever the count changes. Same card, same name → the later row replaces (D39), so the class level drives the max (D26; a subclass follows the main level).
- **Own Grants (`resource_pools`):** a fixed `count` → resource item; a stat formula (`cha_mod_min_1`, `wis_mod_min_1`) → max left empty (D30) + a markdown item "Max = CHA modifier (min. 1)"; any other formula → empty max. Level-bound pools are skipped here (they live in the giver's rows or the card's own table).
- **Spells at level (`spells_at_level`, V24):** a row per spell at `at_level` — a card item into `spells_known`, plus `uses_per_long_rest` as a resource named after the spell. Then the card's own main-level pools: `pb` (or `count_by_level` without `class_ref`) — Lucky's Luck Points 2 → 6.
- `recharge: short_rest` → short and long fill; `long_rest` → short keep, long fill. A count ≥ 99 (SRD's "unlimited", Rage at 20) is not emitted: boxes can't show it, the last count stays.
- Pool names: the Resource Pool card's `display_name`, else `kResourcePoolLabels[name]`, else the key.

## Notes
- Tests: `test/domain/services/free_srd_levels_test.dart` — real SRD cards: copy v4 field types and Class = separate; a stored free value wins; Fighter 1 → 2 → Wizard 1 (slots, Arcane Recovery), Champion at 4; Barbarian 8 Rage 4 and 20 Rage 6; Monk 5 Focus 5; Paladin 3 Lay on Hands 15 and level 1 slots; Bard's Bardic Inspiration with an empty max; Warlock pact slots; Lucky at 5.
- Species / Subspecies reach the character through the player card's single links (roots since Faz 7b, [[free_grants]]); test: Drow gives Faerie Fire at 3, 1/day.
