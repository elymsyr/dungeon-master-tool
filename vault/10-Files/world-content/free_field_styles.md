---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/free_field_styles.dart
layer: domain
language: dart
status: active
updated: 2026-10-12
tags: [file]
---

# `free_field_styles.dart`

> [!abstract] Primary Purpose
> Reading and writing the free template's combined styles — **Table** (`FieldType.table`, DESIGN §8.1), **Stat table** (`FieldType.statTable`, §8.2), **Skill table** (`FieldType.skillTable`, D32), **Resource** (`FieldType.resource`, §8.3) and **Combat stats** (free `combatStats`, §8.6, D36) — the Short / Long rest (§12.3), and the readers that show the SRD's stored shapes in them without changing the data (§16.3). Pure Dart; the card widgets in `free_style_field_widgets.dart` and the editor's settings forms only call into it.

## Inputs / Outputs
**Inputs**
- A `FieldSchema` whose `styleConfig` holds the style's settings; a card value in any of the shapes below; the card's other values and its category's fields (for skill totals).

**Outputs**
- `StatTableSpec.of(field)` — stats `[(key, label)]`, `base`, `step`, `showModifier`; `toConfig()`, `copyWith`, `modifier(v)`.
- `statModifier(value, base:, step:)` — ⌊(value − base) ÷ step⌋, rounded **down** (9 → −1 in D&D; the built-in stat block's truncation is not copied, Y7).
- `TableSpec.of(field)` / `TableColumn` — columns (`text | number | check | choice | dice | relation`, options, targets, `locked`), `fixedRows`, template `rows` (each with `_id`); `toConfig()`. The table computes nothing (D32).
- `storedTableRows(value)` — card rows in whatever shape: `List` rows, the SRD proficiency table's `{rows: [...]}`, a level table's `{level: value}` map (→ `{level, value}` rows, by level).
- `tableRows(spec, value)` — what a card shows; `tableValue(spec, rows, previous:)` — what it stores.
- `nextTableRowId(rows)`.
- `SkillTableSpec.of(field)` — template `rows` (`{_id, name, ability}`), `stat` (stat table key, null = the category's first), `bonus` (number field a mark adds), `nameEditable` (config `name_editable`, default off: a card may rename a row, stored as the row's `label`), `statEditable` (config `stat_editable`, default on: a card may pick another stat); `.table` is the fixed-row `TableSpec` its card rows are read / stored with (SRD proficiency row keys: `name` locked, `ability`, `proficient`, `expertise`, `misc`).
- `skillStatField(spec, fields)`, `skillBonus(spec, card)`, `skillTotal(spec, row, card:, fields:)`.
- `structuredListAsMarkdown(rows, nameOf)` — SRD starting equipment / player choices / subspecies options as markdown.
- `ResourceSpec.of(field)` — `boxes` (config `display: number|boxes`), `short` / `long` (`RestEffect.fill|empty|keep`; defaults keep / fill). `resourceValue(v)` reads `{current, max}` and the SRD slot's `{count, states|filled}`; `resourceJson`, `afterRest(effect, current, max)` (fill without a max changes nothing).
- `CombatStatsSpec.of(field)` — `hpLabel`, `short` / `long` for HP, `values: [CombatValue{key, label, type: number|dice|cards, encounter, width?, editable, targets}]` (no −/+ buttons anywhere in the block, user decision 2026-10-12); `keyFor(label)` never gives `hp` / `max_hp` or a taken key; `hasCards` (at most one card list); `applyTo(field)` writes `styleConfig` **and** `subFields` (the encounter reads those until Faz 9). `isCombatBlock(f)` = `combatStats` with settings (the built-in block has none).
- `combatStatsValue(stored, card)` — the block's values, filling what it lacks from an SRD monster's flat fields: `hp_average` → HP and Max HP, `ac` → AC, `initiative_modifier` → `1d20+N` / `1d20-N`. `combatNumber(v)` reads an int or the encounter's text.
- `freeFieldValue(field, card)` — what a field shows: stored value; a combat block through `combatStatsValue`; a Speed / CR field with `styleConfig.srd_read` (`srdReadKey`) reads the built-in `combat_stats` text through `srdNumber` ("30 ft." → 30, "1/2" → 0.5). Fields without settings read as stored, so the built-in path is unchanged.
- `restPatch(fields, card, kind)` — the changed values a rest writes: every Resource field and each combat block's HP take that rest's effect; nothing else.

## Dependencies & Links
- Depends on: [[field_schema]], [[template_edit]] (`keyFromLabel`)
- Used by: [[free_template]] (SRD copy v2 / v3 builds the specs), [[free_character_sheet]] (rests, values), `entity_card.dart` (`freeFieldValue`), `free_style_field_widgets.dart` (card widgets, through `field_widget_factory.dart`), [[free_template_editor]] (`template_settings_forms.dart`: stat / table / skill table settings), `field_widget_factory.dart` (markdown reader)
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/DESIGN.md` §8.1, §8.2, §16.3; `docs/free-template/ROADMAP.md` Faz 4a, Faz 6

## Key Logic / Variables
- **Fixed rows:** the template's rows, each overlaid with the card's values for it. A stored row matches by `_id`, or — SRD data has none — by equal **locked** cells (a skill's name), or by its locked cell being the template row's id (the SRD copy ids rows by their SRD name, so a renamed row keeps its SRD data). Locked cells always come from the template.
- **Storing a fixed row:** only the cells that differ from the template row (blank = null / false / ''), so a template default (a skill's stat) still reaches cards that never changed it. Stored rows of a template row that is gone stay in the card, hidden (D17), and come back with the row.
- **Free rows:** stored as they are; the card widget gives rows an `_id` when rows come or go so each row's inputs keep their own text.
- **Skill total** (D32, revised 2026-10-11 after the Faz 4a check): the row's stat modifier from the card's stat table (its own base / step) + the card's `bonus` field once per mark (proficient, expertise) + misc. A row with no stat, or a card with no score for it, adds 0 for the stat (2026-10-12, user decision after the Faz 4 check: the row still totals and rolls). The generic table has no stat / total columns any more.
- **Stat keys vs labels:** a stat's key is made once (V3); renaming a label keeps the card values. The SRD copy uses the SRD's own keys (`STR`…`CHA`), so SRD scores read directly.

## Notes
- Tests: `test/domain/services/free_sheet_test.dart` (Faz 6: rests × effects incl. HP, resource shapes, combat spec / subFields / SRD reads, converter v3), `test/domain/services/free_field_styles_test.dart` (DESIGN §8.2's two rows exactly; fixed / free rows; renamed SRD row; real SRD Goblin Warrior, Bard, Fireball, Fighter rows; skill totals), `test/presentation/free_field_styles_widget_test.dart` (card at phone / desktop, a mark and a stat change on a skill row, editor and preset flows).
