---
type: file-note
domain: world-content
path: flutter_app/lib/presentation/screens/templates/free_template_editor.dart
layer: presentation
language: dart
status: active
updated: 2026-10-11
tags: [file]
---

# `free_template_editor.dart` (+ `screens/templates/template_*.dart`)

> [!abstract] Primary Purpose
> The editor for the user's free templates (`docs/free-template/ROADMAP.md` Faz 2, DESIGN §7). Desktop: three panels (template · category layout · settings) over a palette strip. Narrow windows: template page → category page → settings bottom sheet. Edits save on their own. The built-in template never comes here: it keeps the read-only inspector (R8).

## Inputs / Outputs
**Inputs**
- The template from the `/template/edit` route; `TemplateEditorScreen` sends free templates here (`isFreeTemplate`), the built-in one to the inspector.
- `userTemplatesProvider` (latest copy at open; `save` for autosave).

**Outputs**
- Saved `WorldSchema` rows through `UserTemplatesNotifier.save` (V26).

## Files
| File | Role |
|---|---|
| `free_template_editor.dart` | Screen; width ≥ 1000 → three panels, else the phone flow. Nav list (details, player card, reorderable categories), category bar, save status, phone pages and sheets (`_Live` closes a page/sheet whose field, group or category was deleted). |
| `template_edit_controller.dart` | `ChangeNotifier`: working schema, selection (`TemplatePanel`), preview switch, debounced autosave (600 ms) and save-on-dispose. Thin wrappers over [[template_edit]]. |
| `template_layout_canvas.dart` | Centre panel: "Properties" box + group boxes in their columns (phone: one column, V22). Groups reorder from the header handle (long press on the header too); fields drag from their handle at once or by long press anywhere on the tile; palette styles drop in as new fields. |
| `template_settings_forms.dart` | Info / category / group / field forms, name and confirm dialogs, `addFieldWithLabel` (the label is asked first because the key comes from it). |
| `template_styles.dart` | Style names, hints, icons; desktop palette strip; phone style sheet; `TemplateDrag`; the shared app-style pieces `TemplatePills` (the `PillTabBar` look), `TemplateColorDot`, `TemplatePill`. |
| `template_card_preview.dart` | Preview (V27): an empty sample card drawn with the card's pieces (`EntityCardCollapsibleGroupCard`, `EntityCardSectionHeading`, `FieldWidgetFactory`, same column rule); nothing typed there is stored. No group is centred (free templates have no built-in layout rules). |

## Dependencies & Links
- Depends on: [[template_edit]], [[template_provider]], [[free_template]] (`builtinTier`), `entity_card.dart` (public group/heading widgets), `field_widget_factory.dart`, `pin_edit_dialog.dart` (`kPinIconChoices` / `kPinColorChoices`), `world_map_screen.dart` (`mapIconFromName`), `pen_color_picker.dart` (`showCustomColorDialog`), `database_screen.dart` (`parseHexColor`)
- Used by: `template_editor_screen.dart` (route `/template/edit`), Templates tab "Edit"
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/DESIGN.md` §6.6, §7, §8; `docs/free-template/ROADMAP.md` Faz 2

## Key Logic / Variables
- **Selection drives the right panel:** `info`, `category` (also the fallback), `group`, `field`. A palette click adds to the selected group or the selected field's group, else to "Properties".
- **Kept SRD types** (everything outside `simpleFieldTypes`) show an "SRD type" badge; only label, visibility, width, group and delete are offered (ROADMAP §6).
- **Style change** goes through `typeChangeOf`: lossy / incompatible changes ask first; an incompatible one swaps in a new field that stays selected.
- **Every drag has a no-drag twin:** Move up / Move down in the field, group and category forms (WCAG 2.2 dragging movements; keyboard works). The field handle and colour swatches have a 44 px hit area.
- **Deletes always confirm** (field, group, category). The player card has no delete; its form says so.
- Save status in the app bar: saved / saving / not saved (tap to retry).
- **Looks like the rest of the app (UI pass after user feedback):** boxes are `featureCardBg` + `featureCardBorder` with the theme radius (`palette.br` / `cbr`), small checkbox rows instead of switches, pills instead of `SegmentedButton`, nav rows like the codex sidebar (colour dot, name, count), palette buttons like the old editor's. Themes differ a lot (radius 0–14, `useBorders: false`), so nothing hard-codes a radius or a Material default colour.
- **Category settings:** name, colour (pin colours + custom colour through the HSV dialog), **Tier** (codex sidebar group; shows `builtinTier(slug)` until set), sections. The icon is only the world map pin's, so it is picked next to the "World map" checkbox while that is on.

## Notes
- Tests: `test/presentation/free_template_editor_test.dart` (phone / medium / desktop × en / tr, large text, add + rename + key, groups / columns / width / move, drag by handle, move up / down, incompatible change, player card, group delete, preview, every SRD copy category previews, phone sheet delete, style sheet, save on close).
- The map icon button draws `mapIconFromName(cat.icon)`, the same icon the world map draws; the list offers `kPinIconChoices`.
