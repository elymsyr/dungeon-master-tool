---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/free_grants.dart
layer: domain
language: dart
status: active
updated: 2026-10-12
tags: [file]
---

# `free_grants.dart`

> [!abstract] Primary Purpose
> The free template's level system (`docs/free-template/DESIGN.md` §8.4, §8.5, §8.7, §11): **Grants** (`FieldType.grantHolder`), the **Level table** (`FieldType.progressionTable`) and the **Pool** (`FieldType.autoResources`), and the engine that reads them. A card passes what it grants to the **carrier** — a character, or another card — that takes it into a list. Pure and stateless; deliberately **not** [[character_resolver]] (ROADMAP K4). Nothing is computed: cards go into lists, resources and the rest into the Pool (D2).

## Inputs / Outputs
**Inputs**
- The carrier's stored values (`Map<String, dynamic>`) and a `GrantContext`: the carrier's category, every category, the world's cards by id.

**Outputs**
- Items: `GrantItem` (`kind: card | resource | style`; card `{card: ref, targets?: {carrier category slug: list key}}` — D41, a feat may give a monster's and a player's lists different homes, resource `{name, max?, short, long}` — D39, style `{style, label, config?, value?}`), `grantItemsOf`, `nextGrantItemId`, `grantItemStyles` (V31: never Grants, Level table, Pool, Combat stats or Level), `GrantItem.asField()` (a style item drawn by the ordinary field widgets).
- Rows: `LevelRow {level, text, items}`, `levelRowsOf` (by level, stable).
- Category helpers: `LevelMode {separate, together}` / `levelModeOf` (category `levelMode`, null = together), `levelTableOf`, `poolFieldOf`, `levelFieldOf`, `carrierListsOf` (card link lists), `listTakes`, `listTargets`.
- Carrier data (DESIGN §10.3): `cardLevelsKey` (`_card_levels: {card id: level}`), `grantedKey` (`_granted: {card id: {from, level?}}`), `cardLevelsOf`, `grantLabelsOf`, `mainLevelOf` (null without a Level field: card carrier V30, or D34), `listedIds`.
- `computeGrants(fields, ctx)` → `GrantResult {reached, cards, resources, entries, reads, homeless}`.
- `settleGrants(before, after, ctx)` → `GrantChange {fields, before, after, added, stale}`; `summarize(change)` → `GrantSummary` (added cards, into the Pool, rows to read, resources `from → to`, cards with nowhere to go).
- Level up: `levelUpGroups(fields, ctx)` (separate categories with own cards), `levelUp(fields, ctx, picked:, added:)`.
- List edits: `withGrantedCards`, `withoutCards`.
- Pool values: `poolResourceValue(resource, stored)`, `poolStoredWith`, `poolAfterRest`.

## Dependencies & Links
- Depends on: [[entity]], [[entity_category_schema]], [[field_schema]], [[entity_ref]] (`resolveEntityRef`), [[free_field_styles]] (`RestEffect`, `RestKind`, `afterRest`)
- Used by: [[free_character_sheet]] (level up, grants on a list change, captions, Pool, rests), `entity_card.dart` (card carrier: a list change in a free world settles its cards' Grants, its Pool, reached rows), `free_grant_widgets.dart` (Grants and Level table card widgets, item dialog), `free_style_field_widgets.dart` (`PoolFieldWidget`), `free_level_dialogs.dart` (level up, summary, levels, take-back), [[template_edit]] (once per category, dependency warnings)
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/DESIGN.md` §8.4–§8.7, §10.3, §11, §12; `docs/free-template/ROADMAP.md` Faz 7a

## Key Logic / Variables
- **Roots** are the cards in the carrier's lists. A card the carrier took itself in a **separate** category reads its rows to its own level (`_card_levels`, default 1); every other card — together categories, and every **granted** card even in a separate category (V11) — reads to the main level. No Level field → no rows read (V30, D34); Grants still apply.
- **One card, one read:** a visited set guards chains and loops (A ↔ B, §11.6); a card granted twice is one `CardGrant`.
- **Where a granted card goes (V10, D41):** the list the item names for the carrier's category if the carrier has it and it takes the card's category; else the first list **naming** that category (an "any" list never swallows grants); else the Pool (under its giver), or `homeless` without a Pool. A card bound for a list is read as a root only once it is listed — the player may have removed it. A Pool card's own grants apply at once (chain).
- **Resources (D39):** per giver, a later one with the same name replaces an earlier one — the card's own Grants first, then rows by level; across givers the larger max wins, a set max over one left to the player. The winner's rest settings apply.
- **Settling a change:** grants not wanted before the change and not yet listed are added, labelled `{from, level}`, round after round until nothing new (chains). A card wanted before is never added again (§11.6: the player manages them). `stale` = labelled cards still listed that were wanted before and are not now (V12) — offered, never removed unasked. Labels and card levels of cards gone from the lists are pruned (raw stored ids count, so an unloaded world keeps them).
- **Pool values (V29, V32):** only `{name: {current?, max?}}` is stored (max only when the item leaves it open, D30). A new resource reads full; a lower max lowers the current value on read; a resource that leaves keeps its stored value for when it comes back.

## Notes
- Tests: `test/domain/services/free_grants_test.dart` (DESIGN §11.9's Aria example step by step, Barbarian Rage 8 → 4, Wizard slots follow the card's level, Second Wind follows the main level, together card added later, V10's four cases, V31, A ↔ B, removed grant not re-added, Pool merge / V29 / V32 / rests, take-back by removal and by a lowered level, card carrier, dependency warnings, shapes); `test/presentation/free_grants_widget_test.dart`, `test/presentation/free_character_sheet_test.dart` (level up from the sheet).
- The SRD copy's converter v4 (class features → Level table rows, resource pools → resource items, slots) is Faz 7b.
