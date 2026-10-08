---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/entity_search.dart
layer: domain
language: dart
status: stable
updated: 2026-10-08
tags: [file]
---

# `entity_search.dart`

> [!abstract] Primary Purpose
> Search ranking + context suggestions for the `+` picker (`entity_selector_dialog.dart`). Giving a Wizard an item used to mean scrolling a name-sorted list of every item; now rows that fit the card's class / species / background sit under **Suggested** and are boosted in search, and a query matches tags, category and text, not only the name. Works for homebrew with no extra data: a ref to the class or the class name in the text/tags is enough.

## Inputs / Outputs
**Inputs**
- `rankEntities(pool, query, {suggested})` — the picker's name-sorted base list, the raw query, the suggested id set.
- `suggestedEntityIds(pool, fields, byId)` — the edited card's `fields` (`FieldWidgetFactory.create`'s `entityFields`), and a map holding every source (campaign + bundled SRD + `extraEntities`) to resolve refs.

**Outputs**
- Ranked `List<Entity>`; `Set<String>` of suggested ids. Pure Dart, no providers.

## Key Logic
- **`EntitySearchDoc`** — per entity, lowercased `name`, `meta` (tags + category with `-`→space) and `text` (description + every non-uuid string under `fields`, depth ≤ 4, so soft-ref names and `attunement_prereq` are in it; a field string identical to one already added is skipped — SRD spells repeat the description in `description`, magic items in `effects`, a third of all SRD text), plus `refIds` (uuid-shaped values = hard refs). Cached in an `Expando` keyed on the `Entity` instance: bundled SRD rows are built once per app session, an edited card is a new instance and rebuilds lazily.
- **Ranking.** Query split on spaces. A token hits the name anywhere (the old picker's rule — results only grow), or the **start of a word** in meta/text ("rmor" ≠ "armor"). Rows with any hit stay (OR, not AND: "wizard armor" keeps a Wizard-tagged robe). Sort key: matched-token count, then summed best tier per token (name word-start 4, name 3, meta 2, text 1) +2 if suggested, then name.
- **Context.** Only `class` / `subclass` / `species` / `subspecies` / `background` cards the fields point at (bare id, `{id, equipped}` row, or envelope via `resolveEntityRef`). Languages/skills/alignment are excluded on purpose — "Common" would make everything relevant. A row fits when a `refIds` value is one of those cards **or a same-slug-and-name twin from another source** (the card's Wizard is campaign, the spell's `class_refs` is SRD), or a context name appears as a **whole word** (plural `s` allowed) in name/meta/text — "Human" ≠ "Humanoid", "Elf" ≠ "itself".
- **`EntityRanking`** — the picker's per-dialog wrapper: a repeated query (rebuild after ticking a row) returns the cached hits; typing on inside the last word (`new.startsWith(old)`, no space added) ranks the previous hits, since every hit for "fire" was a hit for "fir". A space, backspace or edit ranks the whole pool. Test pins it to `rankEntities` keystroke by keystroke.
- **Cost** (AOT, Ryzen 5 3550H, 2026-10-05; SRD = 2352 rows, 0.65 M chars of doc text): docs 22 ms once per session (inventory pool ~500 rows ≈ 5 ms); suggestions 2 ms inventory / 9.5 ms whole SRD per open; a keystroke ≤ 3.4 ms inventory, 2–11 ms whole SRD (world-map pin picker has no type filter), and typing a word on is ~4× cheaper via `EntityRanking` ("fireball" 8 keystrokes: 31 → 7 ms total). Mobile: low-end Android ≈ 2.5×, oldest A53-class ≈ 6× slower → whole-SRD keystroke ≤ ~65 ms worst, under the dialog's 150 ms debounce; inventory ≤ ~20 ms. Before the dedupe: 35 ms docs, 17 ms worst keystroke. Bundled SRD tags cost 0.2 ms of `buildSrdCorePack` (~100 ms).
- **SRD içerik çevirisi (Faz 6, D6):** `rankEntities(..., shownNames)` / `EntityRanking(shownNames:)` — id → gösterilen ad (`searchFold`'lanmış, yalnızca İngilizceden farklı olanlar). Ad katmanı iki adla da eşleşir, eşitlikte gösterilen ada göre sıralar. `searchFold` = `'İ'`→`i` + `toLowerCase` (Dart `'İ'.toLowerCase()` = `i̇`). Kenar listesi araması da aynı katlamayı kullanır.
- One hop only: Wizard → its `armor_training_refs` → armor is deliberately not followed (saving throws would pull in every INT-save spell).

## Dependencies & Links
- Depends on: [[entity_ref]] (`resolveEntityRef`).
- Used by: `entity_selector_dialog.dart` (the `+` picker; preview map also used here, see [[entity_preview_dialog]]). Context reaches it from the three relation widgets in `field_widget_factory.dart` (single relation, reference list, inline list) via `contextFields`; the mini relation fields in `structured_list_field_widgets.dart` pass none.
- Data: [[srd_core_pack]] — SRD cards carry curated tags (`srd_tags.dart`: items, spells, monsters, origin/general feats) so the built-in pack gets suggestions and searchable school/type/habitat words.
- Domain map: [[World-and-Content]]
- Test: `test/domain/services/entity_search_test.dart`.
- Used by (ranking): `entity_selector_dialog.dart` holds one `EntityRanking` per open dialog.
