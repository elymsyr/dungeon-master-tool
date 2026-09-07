---
type: file-note
domain: world-content
path: flutter_app/lib/presentation/dialogs/entity_preview_dialog.dart
layer: presentation
language: dart
status: stable
updated: 2026-09-07
tags: [file]
---

# `entity_preview_dialog.dart`

> [!abstract] Primary Purpose
> Read-only "quick look" at an entity, opened by **long-pressing** any ref link. Lets the character sheet and the creation wizard show a referenced card's full content — a background's granted skill, an item in the inventory, a starting-equipment weapon — without navigating away from the step the user is on.

## Inputs / Outputs
**Inputs**
- `Entity entity` — a plain entity, *not* an id. The caller already holds it.
- `Map<String, Entity>? entities` — the map the host threads into its field widgets. Falls back to `entityProvider` when null.

**Outputs**
- `Future<void> showEntityPreview(BuildContext, Entity, {Map<String, Entity>? entities})` — a `Dialog` (max 560×640) with `entity.images`, name, category name, description, and every non-empty schema field rendered read-only through [[field_widget_factory|FieldWidgetFactory.create]].
- `EntityPreviewLongPress` — a `GestureDetector` wrapper that opens the preview for a given entity. Used by the creation-wizard pickers, whose rows are `RadioListTile`s with no long-press hook of their own.

## Key Logic

**Why not `EntityCard`.** The obvious reuse does not work: `entity_card.dart` reads *and writes* `entityProvider` on essentially every field (`ref.read(entityProvider)[widget.entityId]!` appears ~15 times, and its `build` starts by watching that map). The creation wizard's entities are the bundled SRD rows plus installed-package rows served by [[package_source_entities|wizardEntitiesProvider]] — **none of which are in `entityProvider`** — so an `EntityCard` opened from a wizard step renders "Entity not found". Taking an `Entity` plus an entity map instead makes one widget serve both contexts.

**Art is shown.** `entity.images` renders as a 260-high horizontal strip of 200-wide [[asset_ref_image|AssetRefImage]]s above the title — the same `AssetRef` path the card uses, so bundled `dmt-art://`, local paths and `dmt-asset://` all resolve. `BoxFit.contain`, not `cover`: a quick look should show the whole piece rather than a portrait crop.

**Empty fields are skipped.** `_isEmpty` drops null / blank-string / empty-list / empty-map values, so a preview is the card's actual content rather than a wall of empty inputs — the read-only card in the Database panel can afford placeholders, a transient dialog cannot.

## Dependencies & Links
- Depends on: [[field_widget_factory]], `entity_provider` (`entityProvider`, `worldSchemaProvider`), `expandable_markdown.dart`, `dm_tool_colors.dart`.
- Opened from: [[entity_link|entityPreviewHandler]] — the long-press entry point for ref links, wired into `EntityLink` and the three direct `_navigateToEntity` `InkWell`s in [[field_widget_factory]] (relation field, reference list row, inline relation chip). The editable `InputChip` list is deliberately not wired: `InputChip` has no `onLongPress`. Also opened from the character-creation wizard's pickers (class / background / species in `_EntityPickStep`, entity-backed lineage rows in `_RaceStep`, `subclass_step.dart`, `spells_step.dart`) via `EntityPreviewLongPress` / a direct `InkWell.onLongPress`, with [[package_source_entities|wizardEntitiesProvider]] as the entity map. Ve `entity_selector_dialog.dart`'ın `+` seçici listesinden (`ListTile.onLongPress`) — orada entity haritası kampanya + (istenmişse) bundled SRD + `extraEntities` birleşimi, ilk uzun basmada tembel kurulur.
- Domain map: [[World-and-Content]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
