---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/item.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `mappers/item.dart`

> [!abstract] Primary Purpose
> Maps v2 Open5e `MagicItem.json` rows onto the app's `magic-item` package entity. Depth = stats + descriptive text: category, rarity, attunement, cost, weight plus the full effect markdown. Mundane SRD weapons/armor/gear are intentionally NOT imported (they duplicate built-in content 1:1); magic weapons/armor/shields ARE captured and mapped to the coarser app categories.

## Inputs / Outputs
**Inputs**
- `mapMagicItems(pack, norm, source, items)` — magic-item fixtures from [[loaders]].

**Outputs**
- Adds `magic-item` entities to the `PackBuilder` ([[refgraph]]).

## Dependencies & Links
- Depends on: [[loaders]], [[normalize]], [[refgraph]], [[srd_helpers]] (`packEntity`).
- Used by: [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[SRD-5.2.1]]

## Key Logic / Variables
- `_categoryAlias`: Open5e categories are finer than the app's 9 — `weapon→Weapons`, `wondrous-item→Wondrous Items`, `armor→Armor`, `potion→Potions`, `ring→Rings`, `staff→Staffs`, `wand→Wands`, `rod→Rods`, `scroll→Scrolls`, and crucially `shield→Armor`, `ammunition→Weapons`.
- Attributes always set: `requires_attunement`, `is_cursed: false`, `activation: 'None'`, `effects: <desc markdown>`, `is_sentient: false`. Optional: `magic_category_ref`, `rarity_ref`, `attunement_prereq` (when attunement detail present), `cost_gp`, `weight_lb`.
- **No `base_item_ref` emitted** — magic-item packages ship no base weapon/armor entities to point at, so the link would dangle.

## Notes
- Smallest mapper (~3KB). The cursed/sentient/activation fields are stubbed false/None — Open5e carries no structured data for them.
