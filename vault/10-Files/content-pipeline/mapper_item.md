---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/item.dart
layer: tool
language: dart
status: stable
updated: 2026-08-13
tags: [file]
---

# `mappers/item.dart`

> [!abstract] Primary Purpose
> Maps v2 Open5e `MagicItem.json` rows onto the app's `magic-item` package entity. Depth = stats + descriptive text: category, rarity, attunement, cost, weight plus the full effect markdown. Mundane SRD weapons/armor/gear are intentionally NOT imported (they duplicate built-in content 1:1); magic weapons/armor/shields ARE captured and mapped to the coarser app categories.

## Inputs / Outputs
**Inputs**
- `mapMagicItems(pack, norm, source, items, {knownBaseItems})` — magic-item fixtures from [[loaders]].
- `knownBaseItems`: `name → category slug` for every base item a `base_item_ref` may target, derived in [[build_packs]] from `builtinNameIndex()` ([[gate]]) over `weapon`/`armor`/`adventuring-gear`. Outside it, no ref.

**Outputs**
- Adds `magic-item` entities to the `PackBuilder` ([[refgraph]]), with `base_item_ref` on the 379 rows that have one.
- `baseItemName` is public so [[verify_packs]] can restate the `base_item_ref` contract without re-implementing the slug→name transform.

## Dependencies & Links
- Depends on: [[loaders]], [[normalize]] (`titleCase`), [[refgraph]], [[srd_helpers]] (`packEntity`), [[mapper_chargen]] (`softRef`).
- Used by: [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[SRD-5.2.1]]

## Key Logic / Variables
- `_categoryAlias`: Open5e categories are finer than the app's 9 — `weapon→Weapons`, `wondrous-item→Wondrous Items`, `armor→Armor`, `potion→Potions`, `ring→Rings`, `staff→Staffs`, `wand→Wands`, `rod→Rods`, `scroll→Scrolls`, and crucially `shield→Armor`, `ammunition→Weapons`.
- Attributes always set: `requires_attunement`, `is_cursed: false`, `activation: 'None'`, `effects: <desc markdown>`, `is_sentient: false`. Optional: `magic_category_ref`, `rarity_ref`, `attunement_prereq` (when attunement detail present), `cost_gp`, `weight_lb`.
- **`base_item_ref`** (audit **L3**, 2026-08-13): upstream keeps the base item in two structured columns, `MagicItem.weapon` and `MagicItem.armor` (`srd_longsword`, `srd_plate`); a row fills at most one. `baseItemName` strips the document prefix (up to the first `_`) and `titleCase`s the rest, then applies `_baseItemAlias` — 10 rows where the built-in card is filed under a different name (2024 renamed the armors, `plate` → `Plate Armor`; the crossbows are ordered the other way round, `crossbow-hand` → `Hand Crossbow`). The result is looked up in `knownBaseItems` and emitted as `softRef(slug, name)`; **the slug comes from the map, not from the source column**, because `srd_net` is a weapon upstream and an `adventuring-gear` card here. No built-in card → no ref: an unresolvable softRef is a `dangling-soft-ref` violation in [[gate]]. 379 of `open5e-vom`'s 1,063 items; the other 684 fill neither column.

## Notes
- Smallest mapper (~3KB). The cursed/sentient/activation fields are stubbed false/None — Open5e carries no structured data for them.
- The old note here said a `base_item_ref` "would dangle" — the same reversed premise as [[mapper_spell]]'s `class_refs`. A softRef into the built-in pack does not dangle, and the source was structured all along.
