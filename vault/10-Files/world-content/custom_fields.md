---
type: file-note
domain: world-content
path: flutter_app/lib/domain/entities/custom_fields.dart
layer: domain
language: dart
status: stable
updated: 2026-09-04
tags: [file]
---

# `custom_fields.dart`

> [!abstract] Primary Purpose
> Free fields — a field added to **one card**, not to its category and never to the template. Defines the reserved `_custom_fields` key inside an entity's untyped `fields` map plus the read/encode helpers.

## Inputs / Outputs
**Inputs**
- `customFieldsOf(Map<String, dynamic> entityFields)` — the entity's `fields` map.

**Outputs**
- `List<FieldSchema>` (bad rows skipped), and `encodeCustomFields` back to plain JSON.
- `kCustomFieldsKey` = `'_custom_fields'`.

## Dependencies & Links
- Depends on: [[field_schema]], `dart:convert`
- Used by: `entity_card` (`_buildCustomFields`, `_addCustomField`, `_editCustomField`, `_deleteCustomField`), `field_schema_dialog` (shared with the template editor)
- Domain map: [[World-and-Content]]
- System flow: [[Template-System]]

## Key Logic / Variables
- **Why it lives in the entity's own `fields` map:** attributes are already untyped and written verbatim to `fields_json`. Putting the *definition* there too means save, LAN sync and the share broadcast (`payload_json`) carry it with zero changes — the field travels with the card whether the card lives in a world or in a package.
- **The template is never touched.** Built-in or custom, the source schema is untouched; the field renders on this card only. Values are stored under the field's own key, beside schema values.
- **Always pure data.** `CharacterResolver.grantFieldKeys` is a closed set, so a key invented here can never fire a mechanic — including inside a built-in world.
- `encodeCustomFields` round-trips through `jsonEncode`/`jsonDecode`: `FieldSchema.toJson()` leaves nested freezed objects (`validation`) as objects, and the card map is read back **before** it ever hits disk, so without normalising, a freshly added field would be invisible until reload.
- Renaming a field's key moves the stored value with it (`entity_card._editCustomField`); deleting the field deletes its value.

## Notes
- Guard: `test/domain/template_authoring_test.dart` (`free fields` group).
