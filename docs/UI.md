# Entity Card & Field Specification

> Self-contained design specification for the **Entity Card** — the unified read/edit widget used for every entity (NPC, Monster, Spell, Equipment, …) — and the schema-driven field catalog it consumes. The document describes the design as a contract: shapes, sizes, typography, colors, layout rules, and per-category content. It does not depend on, and does not cite, any specific source file or line number.

---

## Table of Contents

1. [Purpose & Scope](#1-purpose--scope)
2. [Top-Level Card Anatomy](#2-top-level-card-anatomy)
3. [Building Blocks](#3-building-blocks)
4. [Schema-Driven Field Pipeline](#4-schema-driven-field-pipeline)
5. [Field Type → Widget Reference](#5-field-type--widget-reference)
6. [Field Schema Metadata Reference](#6-field-schema-metadata-reference)
7. [Per-Category Card Designs](#7-per-category-card-designs)
8. [Spacing, Typography & Color Tokens](#8-spacing-typography--color-tokens)
9. [Lifecycle & State Management](#9-lifecycle--state-management)
10. [Code Sample Appendix](#10-code-sample-appendix)

---

## 1. Purpose & Scope

The Entity Card is the canonical detail view for any entity in the database. It is a single Flutter widget that supports both read-only display and inline editing, and renders identically for every category — the body of the card is derived dynamically from the active world schema (`EntityCategorySchema` → `FieldGroup` → `FieldSchema`).

The card is per-entity reactive: it rebuilds only when its target entity changes. User input is routed through a 300 ms debounced provider update so typing stays smooth, and a focus-aware sync ensures external updates never overwrite a typing user.

The same card houses 19 built-in categories. Each category contributes a different field set; the card chrome (header, DM notes, delete button) stays identical. Per-category visual mockups appear in [§7 Per-Category Card Designs](#7-per-category-card-designs).

---

## 2. Top-Level Card Anatomy

The card is a vertically scrolling stack with `EdgeInsets.all(16)` outer padding. Inside, six logical regions stack in this order:

```
SingleChildScrollView (padding: 16)
└── Column
    ├── _FeatureCard ── HEADER ───────────────────────────────────────┐
    │   Row(crossAxis: start)                                          │
    │     • _PortraitGallery (200×260, fixed)                          │
    │     • SizedBox(width: 12)                                        │
    │     • Expanded(Column)                                           │
    │         · Row( CategoryBadge  +  Spacer  +  CastIconButton )     │
    │         · SizedBox(height: 8)                                    │
    │         · TextFormField   "Entity Name" (18 / bold)              │
    │         · SizedBox(height: 10)                                   │
    │         · "Description" label (11)                               │
    │         · SizedBox(height: 4)                                    │
    │         · MarkdownTextArea (markdown + @mention)                 │
    │         · SizedBox(height: 10)                                   │
    │         · Row( Source TextField | gap 8 | Tags TextField )       │
    └──────────────────────────────────────────────────────────────────┘
    │   SizedBox(height: 8)
    ├── SCHEMA-DRIVEN FIELDS  (one ungrouped "Properties" card +
    │     N _CollapsibleGroupCard, separated by 8 px)
    │   SizedBox(height: 8)
    ├── DM NOTES  (red dmNoteBorder, lock icon, MarkdownTextArea)
    │   SizedBox(height: 16)   ← edit mode only
    └── Row(MainAxis.end, [ Delete FilledButton.icon ])  ← edit mode only
```

The visual rhythm is uniform: every block is a flat, low-elevation card-like container with `featureCardBg`, 4 px corner radius, 12 px internal padding. The DM Notes block is the only block with a visible border (`dmNoteBorder`).

The portrait gallery is the only element on the card that participates in the theme's radius scale (`cardBorderRadius`); every other surface uses a hardcoded 4 px corner regardless of theme.

---

## 3. Building Blocks

### 3.1 `_FeatureCard`

Plain section container used by the header and by the ungrouped "Properties" group.

```dart
class _FeatureCard extends StatelessWidget {
  final DmToolColors palette;
  final Widget child;

  const _FeatureCard({required this.palette, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
```

- 4 px corner radius (hardcoded; deliberately does **not** read `cardBorderRadius`).
- No border, no shadow. Surface separation comes from the contrast between `featureCardBg` and the page background.
- `width: double.infinity` ensures the card fills the column.

### 3.2 `_CollapsibleGroupCard`

Wraps every `FieldGroup` defined on the active category. Tapping the header toggles `_collapsed`, suppressing the body but keeping the header visible.

| Property | Value |
|---|---|
| Background | `featureCardBg` |
| Radius | 4 px |
| Header padding | `EdgeInsets.symmetric(horizontal: 12, vertical: 10)` |
| Header chevron | `Icons.chevron_right` collapsed / `Icons.expand_more` open, 16 px, `tabText` |
| Header gap chevron→title | `SizedBox(width: 4)` |
| Header title style | 12 px / `FontWeight.w600` / `tabText` |
| Body padding | `EdgeInsets.fromLTRB(12, name.isEmpty ? 12 : 0, 12, 12)` |
| Initial collapsed state | from `FieldGroup.isCollapsed` |
| Header `InkWell` ripple radius | top corners only, 4 px |

### 3.3 `_PortraitGallery`

Fixed-size 200×260 image carousel that lives in the header row.

| Element | Constants |
|---|---|
| Container | `width: 200`, `height: 260`, border `featureCardBorder`, radius `cardBorderRadius`, `clipBehavior: Clip.antiAlias` |
| Image renderer | `BoxFit.cover`, `cacheWidth: 400` |
| Placeholder | `Icons.person_outline` 48 px @ 40 % alpha + "No Image" caption (10 px / `sidebarLabelSecondary`) on `featureCardBg` |
| Hover overlay (desktop only) | `Colors.black.withValues(alpha: 0.08)` |
| Nav arrows | 26×26 circle, `Colors.black26`, `Icons.chevron_left/right` (18 px white), shown only when `images.length > 1` and not at bounds |
| Counter pill | bottom-center, 6×2 padding, radius 10, `Colors.black38`, label `'${i+1}/${n}'` 9 px `Colors.white70` |
| Edit-mode add button | top-right corner, 26×26 circle (`Colors.black26`), `Icons.add_photo_alternate` 14 px white |
| Edit-mode remove button | top-left corner, 26×26 circle (`Colors.black26`), `Icons.close` 14 px in `dangerBtnBg` |

Visibility rules:

- `_showControls = _hovered || Platform.isAndroid || Platform.isIOS` — desktop hides controls until hover; mobile always shows them.
- Right-click and long-press open a projection menu (cast image to player screen).
- Multi-image picking goes through a media gallery dialog when a media directory is configured, otherwise falls back to a system file picker (`type: image`, `allowMultiple: true`).

The gallery merges the legacy single-image path with the multi-image list for display, and writes everything back to the multi-image list (clearing the legacy path).

### 3.4 Header right column

The right side of the header lays out, top to bottom: category badge + cast button, name, description, source/tags row.

#### Category badge

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: catColor.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    cat?.name ?? entity.categorySlug,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor),
  ),
)
```

`catColor` parsed from `EntityCategorySchema.color` (a hex string like `#ff9800`); when missing, falls back to `tabIndicator`. The badge uses the same hue for both fill (15 % alpha) and label (full opacity).

#### Cast-to-projection button

`IconButton` with `Icons.cast` (16 px), `VisualDensity.compact`, `BoxConstraints(minWidth: 28, minHeight: 28)`, zero padding. Single tap projects the card to the player screen and shows a 2-second SnackBar confirmation.

#### Entity name

```dart
TextFormField(
  controller: _nameController,
  focusNode: _nameFocus,
  readOnly: widget.readOnly,
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.tabActiveText),
  decoration: InputDecoration(
    hintText: 'Entity Name',
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  ),
)
```

#### Description

11 px label "Description" in `tabText`, 4 px gap, then a `MarkdownTextArea` body 13 px in `htmlText`. Hint: `Markdown supported... (@ to mention)`. `minLines: 3` in edit mode, unbounded in read-only mode. Renders markdown in preview mode and resolves `@entityName` mentions to clickable links.

#### Source + Tags row

Two `Expanded` `TextFormField`s separated by `SizedBox(width: 8)`:

| Field | Label | Hint (edit) | Style |
|---|---|---|---|
| Source | `Source` | `e.g. D&D 5e SRD` | 12 px / `htmlText` |
| Tags | `Tags` | `comma separated` | 12 px / `htmlText` |

The tags input splits on commas and trims whitespace before storing.

### 3.5 DM Notes block

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: palette.featureCardBg,
      border: Border.all(color: palette.dmNoteBorder),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.lock, size: 14, color: palette.dmNoteTitle),
          const SizedBox(width: 4),
          Text('DM Notes',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.dmNoteTitle)),
        ]),
        const SizedBox(height: 6),
        MarkdownTextArea(
          controller: _dmNotesController,
          focusNode: _dmNotesFocus,
          readOnly: widget.readOnly,
          maxLines: widget.readOnly ? null : 4,
          textStyle: TextStyle(fontSize: 13, color: palette.htmlText),
          decoration: InputDecoration(
            hintText: 'Private DM notes... (@ to mention)',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            filled: false,
            hintStyle: TextStyle(color: palette.sidebarLabelSecondary),
          ),
        ),
      ],
    ),
  ),
)
```

The only block on the card with a visible border — uses `dmNoteBorder` (typically a muted red) to signal "private to DM". The text area itself is unbordered and undecorated, blending into the container.

### 3.6 Delete button

Right-aligned `FilledButton.icon` ("Delete" + `Icons.delete_outline` 16 px), edit-mode only, tinted with `dangerBtnBg` / `dangerBtnText`. Wraps the delete operation in a confirmation dialog (`Cancel` / `Delete` actions; the second uses the danger styling).

---

## 4. Schema-Driven Field Pipeline

The schema-driven body of the card runs through three private methods:

```
_buildSchemaFields(entity, cat, palette, computed, itemStyles, equipGates)
   ↓
_buildGroupGrid(fields, gridColumns, …)
   ↓
_buildFieldWidget(field, …)
   ↓
FieldWidgetFactory.create(...)  → concrete widget
```

### 4.1 `_buildSchemaFields`

```dart
List<Widget> _buildSchemaFields(Entity entity, EntityCategorySchema cat, DmToolColors palette,
    Map<String, dynamic> computed, Map<String, ItemStyle> itemStyles,
    Map<String, String> equipGates) {
  final allFields = cat.fields
      .where((f) => f.visibility != FieldVisibility.private_)
      .toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  final ungrouped = allFields.where((f) => f.groupId == null).toList();

  final grouped = <String, List<FieldSchema>>{};
  for (final f in allFields) {
    if (f.groupId != null) (grouped[f.groupId!] ??= []).add(f);
  }

  final sortedGroups = cat.fieldGroups.toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  final widgets = <Widget>[];

  if (ungrouped.isNotEmpty) {
    widgets.add(_FeatureCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: palette.tabText)),
          const SizedBox(height: 8),
          ...ungrouped.map((f) => _buildFieldWidget(f, entity, computed, palette,
              itemStyles: itemStyles, equipGates: equipGates)),
        ],
      ),
    ));
  }

  for (final group in sortedGroups) {
    final groupFields = grouped[group.groupId];
    if (groupFields == null || groupFields.isEmpty) continue;
    if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
    widgets.add(_CollapsibleGroupCard(
      group: group, palette: palette,
      child: _buildGroupGrid(groupFields, group.gridColumns, entity, computed, palette,
          itemStyles: itemStyles, equipGates: equipGates),
    ));
  }

  return widgets;
}
```

Behavior:

- **Visibility filter.** Fields with `FieldVisibility.private_` are dropped before render. `shared` and `dmOnly` both render here; differentiating DM-only display is the responsibility of the online sync layer, not the card.
- **Order.** Fields are sorted by `orderIndex` before bucketing, so order *inside* each group is also stable.
- **Ungrouped fields.** Any field with `groupId == null` is rendered first inside a single `_FeatureCard` whose header is the literal text "Properties".
- **Groups.** Iterated in `FieldGroup.orderIndex` order. Empty groups are skipped. Each non-empty group is wrapped in a `_CollapsibleGroupCard`.
- **Inter-group spacing.** `SizedBox(height: 8)` between any two rendered widgets in the result list.

### 4.2 `_buildGroupGrid`

Responsive grid algorithm. For `gridColumns == 1`, fields stack in a `Column`. For `gridColumns >= 2`, fields are packed into rows respecting each field's `gridColumnSpan` (clamped to `[1, gridColumns]`):

```dart
Widget _buildGroupGrid(List<FieldSchema> fields, int gridColumns, Entity entity,
    Map<String, dynamic> computed, DmToolColors palette,
    {Map<String, ItemStyle> itemStyles = const {},
     Map<String, String> equipGates = const {}}) {
  if (gridColumns <= 1) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.map((f) => _buildFieldWidget(
        f, entity, computed, palette,
        itemStyles: itemStyles, equipGates: equipGates,
      )).toList(),
    );
  }

  final rows = <List<FieldSchema>>[];
  var colsUsed = 0;
  var currentRow = <FieldSchema>[];
  for (final field in fields) {
    final span = field.gridColumnSpan.clamp(1, gridColumns);
    if (colsUsed + span > gridColumns && currentRow.isNotEmpty) {
      rows.add(currentRow);
      currentRow = [];
      colsUsed = 0;
    }
    currentRow.add(field);
    colsUsed += span;
  }
  if (currentRow.isNotEmpty) rows.add(currentRow);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: rows.map((rowFields) {
      final children = <Widget>[];
      for (var i = 0; i < rowFields.length; i++) {
        if (i > 0) children.add(const SizedBox(width: 8));
        final span = rowFields[i].gridColumnSpan.clamp(1, gridColumns);
        children.add(Expanded(
          flex: span,
          child: _buildFieldWidget(rowFields[i], entity, computed, palette,
              itemStyles: itemStyles, equipGates: equipGates),
        ));
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }).toList(),
  );
}
```

Worked example (`gridColumns = 2`):

| Fields (in order) | `gridColumnSpan` | Result |
|---|---|---|
| `race` | 1 | Row 1: race + class (1 + 1 = 2) |
| `class_` | 1 | |
| `level` | 1 | Row 2: level + attitude |
| `attitude` | 1 | |
| `combat_stats` | 2 | Row 3: combat_stats alone (full row) |
| `saving_throws` | 2 | Row 4: saving_throws alone |

Inter-field gutter inside a row is always `SizedBox(width: 8)`. There is no inter-row gutter at this level — vertical spacing comes from each field widget's own `Padding(symmetric vertical: 4)`.

### 4.3 `_buildFieldWidget`

```dart
Widget _buildFieldWidget(FieldSchema field, Entity entity, Map<String, dynamic> computed,
    DmToolColors palette,
    {Map<String, ItemStyle> itemStyles = const {},
     Map<String, String> equipGates = const {}}) {
  final hasComputed = computed.containsKey(field.fieldKey);
  final fieldValue = hasComputed ? computed[field.fieldKey] : entity.fields[field.fieldKey];
  final formula = hasComputed && !widget.readOnly ? _formulaFor(field.fieldKey) : null;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldWidgetFactory.create(
        schema: field,
        value: fieldValue,
        readOnly: hasComputed && !(field.isList && field.fieldType == FieldType.relation)
            ? true : widget.readOnly,
        onChanged: (v) => _updateField(field.fieldKey, v),
        entities: ref.read(entityProvider),
        ref: ref,
        computedMode: hasComputed,
        itemStyles: itemStyles,
        equipGates: equipGates,
        entityFields: entity.fields,
      ),
      if (hasComputed)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: Row(children: [
            Icon(Icons.auto_fix_high, size: 12, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 4),
            Expanded(child: Text(
              formula != null ? '= $formula' : 'Auto-filled by rule',
              style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary,
                  fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        ),
    ],
  );
}
```

Computed-field badge: when the `computed` map contains the field key, a 12 px `Icons.auto_fix_high` + 10 px italic line is rendered below the field widget, displaying the formula or the literal `Auto-filled by rule`. The field becomes read-only unless it is a relation list (which still allows manual edits even when partially computed).

---

## 5. Field Type → Widget Reference

`FieldType` is the discriminator that drives widget selection. The router has a special-cased preamble for `isList` fields: `relation` lists go to `_ReferenceListFieldWidget`, `image` lists go to the same `_ImageFieldWidget` as singles (it handles both cases internally), and any other list-typed field falls through to a generic `_GenericListFieldWidget`.

### 5.1 At-a-glance table

| `FieldType` | JSON | Widget | Default value | Validation knobs that apply |
|---|---|---|---|---|
| `text` | `text` | `_TextFieldWidget` | `''` | `minLength`, `maxLength`, `pattern` |
| `textarea` | `textarea` | `_TextAreaFieldWidget` | `''` | `minLength`, `maxLength` |
| `markdown` | `markdown` | `_MarkdownFieldWidget` | `''` | `minLength`, `maxLength` |
| `integer` | `integer` | `_IntegerFieldWidget` | `0` | `minValue`, `maxValue` |
| `float_` | `float` | (text fallback) | `0.0` | `minValue`, `maxValue` |
| `boolean_` | `boolean` | `_BooleanFieldWidget` | `false` | — |
| `enum_` | `enum` | `_EnumFieldWidget` | `''` | `allowedValues` |
| `date` | `date` | `_DateFieldWidget` | system default | — |
| `image` | `image` | `_ImageFieldWidget` (single + list) | `''` | `allowedExtensions` |
| `file` | `file` | `_FileFieldWidget` | `''` | `allowedExtensions` |
| `pdf` | `pdf` | `_PdfFieldWidget` | `''` | `allowedExtensions` |
| `relation` | `relation` | `_RelationFieldWidget` (single) / `_ReferenceListFieldWidget` (list) | `''` (single) / `[]` (list) | `allowedTypes` |
| `tagList` | `tagList` | `_TagListFieldWidget` | `<String>[]` | — |
| `statBlock` | `statBlock` | `_StatBlockFieldWidget` | `{STR:10, DEX:10, CON:10, INT:10, WIS:10, CHA:10}` | — |
| `combatStats` | `combatStats` | `_CombatStatsFieldWidget` | `{hp:'', max_hp:'', ac:'', speed:'', cr:'', xp:'', initiative:'', level:''}` | uses `subFields` |
| `conditionStats` | `conditionStats` | `_CombatStatsFieldWidget` (shared) | `{default_duration:'', effect:''}` | uses `subFields` |
| `dice` | `dice` | `_DiceFieldWidget` | `''` | — |
| `slot` | `slot` | `_SlotFieldWidget` | `null` | — |
| `proficiencyTable` | `proficiencyTable` | `_ProficiencyTableFieldWidget` | preset rows | — |
| `levelTable` | `levelTable` | `_LevelTableFieldWidget` | `{}` | — |
| any with `isList: true` (other) | n/a | `_GenericListFieldWidget` | `[]` | per inner type |

`allowedExtensions` is enforced by the file picker; the other validation properties are wired up to the form controller per type.

### 5.2 Per-type rendering notes

#### `text` — single-line input

Plain `TextFormField` with `isDense: true` and `Padding(symmetric vertical: 4)`. Renders inside the card grid as one row's worth of column span.

```dart
Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: TextFormField(
    key: ValueKey('${schema.fieldKey}_text'),
    controller: _controller,
    readOnly: readOnly,
    decoration: InputDecoration(
      labelText: schema.label,
      hintText: schema.placeholder.isNotEmpty ? schema.placeholder : null,
      isDense: true,
    ),
    onChanged: (v) => onChanged(v),
  ),
)
```

#### `textarea` — multi-line plain text

Same shell as `text`, `maxLines: null` / `minLines: 3` on the shared rich editor but no markdown rendering. Used for long prose where `@mention` linking would be confusing.

#### `markdown` — full rich text

Rich editor with edit/preview toggle. In edit mode it shows the raw markdown source; in preview mode it renders the markdown through the in-app renderer that resolves `@entityName` mentions to clickable links. Container border + 100 px min height.

#### `integer` — number input

`TextFormField` with `keyboardType: TextInputType.number`. `onChanged` parses with `int.tryParse(v) ?? 0`.

```dart
TextFormField(
  key: ValueKey('${schema.fieldKey}_int'),
  controller: _controller,
  readOnly: readOnly,
  keyboardType: TextInputType.number,
  decoration: InputDecoration(labelText: schema.label, isDense: true),
  onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
)
```

#### `float_` — floating point

Routes through the `_TextFieldWidget` fallback — there is no dedicated float widget. Numeric coercion happens at write time.

#### `boolean_` — switch

Dense `SwitchListTile` with `dense: true`, label = `schema.label`.

#### `enum_` — dropdown

`DropdownButtonFormField<String>` populated from `validation.allowedValues`. Disabled when `readOnly: true` (sets `onChanged: null`).

```dart
DropdownButtonFormField<String>(
  initialValue: options.contains(currentVal) ? currentVal : null,
  decoration: InputDecoration(labelText: schema.label, isDense: true),
  items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
  onChanged: readOnly ? null : (v) => onChanged(v),
)
```

#### `date` — date picker

Read-only `TextFormField` showing the formatted date, with `Icons.calendar_today` suffix that opens `showDatePicker`.

#### `image` — single or list

Carousel-style preview at fixed height 180 px, `cacheWidth: 600`. Add via media gallery dialog (preferred) or system file picker. When `isList: true`, the same widget is reused — internally it stores a `List<String>` and exposes left/right nav, "Remove" and "Add Image" buttons.

#### `file` / `pdf`

`InputDecorator`-wrapped column listing the chosen file paths plus an "Add file" button using a system file picker. PDF additionally exposes a "View" affordance that hands off to a PDF viewer.

#### `relation` — single

`InputDecorator` with `Icons.link` prefix. Tapping opens an entity selector dialog filtered by `validation.allowedTypes`. The current value is displayed by resolving the linked entity's name through the provided entities map.

#### `relation` (list, a.k.a. `isList: true`)

`_ReferenceListFieldWidget` — a Card with one row per linked entity. Supports:

- **Equip toggles** (`hasEquip: true`): `Icons.shield` icon; tap to mark equipped, drives downstream rules.
- **Source filter** (`showSourceFilter: true`): when on, items sourced by rules (e.g. class traits) appear with a source badge instead of being filtered out.
- **Item styles** (`itemStyles` parameter): per-item visual style — fade, strikethrough, color, tooltip, icon — produced by the rule engine.
- **Equip gates** (`equipGates` parameter): tooltip strings explaining why an item cannot be equipped.

#### `tagList`

`Wrap` with `spacing: 4`, `runSpacing: 4`, one `Chip` per tag plus a trailing `ActionChip(label: '+')` to add new tags via a small dialog.

#### `statBlock`

`Card` with a six-column `Row` showing one ability per column (STR / DEX / CON / INT / WIS / CHA). Each column is `[label, score input, modifier]`:

```dart
Expanded(
  child: Column(
    children: [
      Text(key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      SizedBox(
        width: 44,
        child: TextFormField(
          key: ValueKey('sb_$key'),
          controller: _controllers[key],
          readOnly: readOnly,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: (v) {
            final updated = Map<String, dynamic>.from(stats);
            updated[key] = int.tryParse(v) ?? 10;
            widget.onChanged(updated);
          },
        ),
      ),
      const SizedBox(height: 2),
      Text(modStr, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
    ],
  ),
)
```

The modifier is computed inline as `((val - 10) ~/ 2)` and rendered in `colorScheme.outline` at 11 px.

ASCII layout:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Ability Scores                                                      │
│  STR    DEX    CON    INT    WIS    CHA                             │
│ [ 10 ] [ 14 ] [ 12 ] [ 10 ] [ 13 ] [ 8 ]                             │
│  +0     +2     +1     +0     +1    -1                               │
└─────────────────────────────────────────────────────────────────────┘
```

#### `combatStats` / `conditionStats`

Shared `_CombatStatsFieldWidget`. Sub-fields are read from `schema.subFields` (each `{key, label, type}`). Non-textarea sub-fields render in a responsive grid with `~88 px per column` (the available width is divided by 88 and clamped to `[1, fields.length]`):

```dart
LayoutBuilder(builder: (context, constraints) {
  final cols = (constraints.maxWidth / 88).floor().clamp(1, gridFields.length);
  // pack gridFields into rows of `cols`
})
```

`textarea`-typed sub-fields render full-width below the grid through a `MarkdownTextArea` (markdown + `@mention`). This is how the Condition category's `effect` sub-field gets its rich behavior.

Default schema layouts:

- `combatStats` sub-fields (NPC / Monster / Player Combat group): `hp`, `max_hp`, `ac`, `speed`, `level`, `initiative` (dice), `cr`, `xp`. `gridColumnSpan: 2`.
- `conditionStats` sub-fields (Condition category): `default_duration` (integer), `effect` (textarea). `gridColumnSpan: 2`.

#### `dice`

`TextFormField` with `Icons.casino` prefix and `hintText: 'e.g. 2d6+3'`. Parses standard dice notation (`NdM[+|-K]`).

#### `slot`

A row of small "pip" checkboxes representing slot/charge/hit-die counts. Includes increment / decrement / refill buttons; max 99. The widget reads adjacent fields from `entityFields` to derive how many slots exist (e.g. spell slots from `levelTable`).

```
[●] [●] [●] [○] [○]   −  +  ↻
```

#### `proficiencyTable`

Table per row: `{name, ability, proficient, expertise, misc}`. Each row computes its total at render time as `proficiency_bonus + ability_modifier (+ expertise) + misc`, where `ability_modifier` and `proficiency_bonus` come from sibling fields (`stat_block`, `proficiency_bonus`) — that is the reason `entityFields` is threaded through the factory.

ASCII layout:

```
┌──────────────────────────────────────────────────────────┐
│ Skills                                                   │
│ ☐  Acrobatics      DEX   +2                              │
│ ☑  Athletics       STR   +5   ★ expertise                │
│ ☐  Insight         WIS   +1                              │
│ ☐  Perception      WIS   +1                              │
│ ...                                                      │
└──────────────────────────────────────────────────────────┘
```

Default presets:

- Saving throws — 6 rows (one per ability).
- Skills — 18 rows.

#### `levelTable`

Editable table mapping `int → int` (level → value). Used for class progression like spell-slot counts and hit-dice totals.

#### `_GenericListFieldWidget` (fallback for `isList: true`)

Card with numbered `TextFormField` rows and `+` / `−` buttons. Fires `onChanged` with a fresh `List<String>` every edit.

---

## 6. Field Schema Metadata Reference

### 6.1 `FieldType`

```dart
enum FieldType {
  text,
  textarea,
  markdown,
  integer,
  @JsonValue('float')   float_,
  @JsonValue('boolean') boolean_,
  @JsonValue('enum')    enum_,
  date,
  image,
  file,
  pdf,
  relation,
  tagList,
  statBlock,
  combatStats,
  conditionStats,
  dice,
  slot,
  proficiencyTable,
  levelTable,
}
```

### 6.2 `FieldVisibility`

| Value | JSON | Card behavior |
|---|---|---|
| `shared` | `shared` | Visible to all viewers (default). |
| `dmOnly` | `dmOnly` | Visible to all locally; differentiation lives in the online sync layer, not in the card. |
| `private_` | `private` | **Filtered out of the schema-driven body** before rendering. |

### 6.3 `FieldValidation`

```dart
@freezed
abstract class FieldValidation with _$FieldValidation {
  const factory FieldValidation({
    double? minValue,
    double? maxValue,
    int? minLength,
    int? maxLength,
    String? pattern,
    List<String>? allowedValues,
    List<String>? allowedTypes,
    List<String>? allowedExtensions,
    String? customMessage,
  }) = _FieldValidation;
}
```

| Property | Type | Applies to | Notes |
|---|---|---|---|
| `minValue` | `double?` | `integer`, `float_` | Clamp at write time. |
| `maxValue` | `double?` | `integer`, `float_` | Clamp at write time. |
| `minLength` | `int?` | `text`, `textarea`, `markdown` | Validation only, not enforced by widget. |
| `maxLength` | `int?` | `text`, `textarea`, `markdown` | Validation only. |
| `pattern` | `String?` | `text` | Regex. |
| `allowedValues` | `List<String>?` | `enum_` | Drives dropdown options. |
| `allowedTypes` | `List<String>?` | `relation`, `relation` (list) | Filters the entity selector to these category slugs. |
| `allowedExtensions` | `List<String>?` | `image`, `file`, `pdf` | Passed to the file picker. |
| `customMessage` | `String?` | all | Replaces the default validation error message. |

### 6.4 `FieldSchema`

```dart
@freezed
abstract class FieldSchema with _$FieldSchema {
  const factory FieldSchema({
    required String fieldId,
    required String categoryId,
    required String fieldKey,
    required String label,
    required FieldType fieldType,
    @Default(false) bool isRequired,
    @Default(null) dynamic defaultValue,
    @Default('') String placeholder,
    @Default('') String helpText,
    @Default(FieldValidation()) FieldValidation validation,
    @Default(FieldVisibility.shared) FieldVisibility visibility,
    @Default(0) int orderIndex,
    @Default(false) bool isBuiltin,
    @Default(false) bool isList,
    @Default(false) bool hasEquip,
    @Default(false) bool showSourceFilter,
    @Default([]) List<String> allowedInSections,
    @Default([]) List<Map<String, String>> subFields,
    @Default(null) String? groupId,
    @Default(1) int gridColumnSpan,
    required String createdAt,
    required String updatedAt,
  }) = _FieldSchema;
}
```

| Property | Type | Default | Card-side meaning |
|---|---|---|---|
| `fieldId` | `String` | — | UUID; identity in the schema. |
| `categoryId` | `String` | — | Which category owns this field. |
| `fieldKey` | `String` | — | Key into `entity.fields` map; used by rules and lookups. |
| `label` | `String` | — | Header text shown by every widget. |
| `fieldType` | `FieldType` | — | Selects the widget class. |
| `isRequired` | `bool` | `false` | Validation hint; widget does not block input. |
| `defaultValue` | `dynamic` | `null` | Seed value when creating a new entity. |
| `placeholder` | `String` | `''` | Used as `hintText` on text-style widgets. |
| `helpText` | `String` | `''` | Reserved for tooltip/help affordance. |
| `validation` | `FieldValidation` | empty | See §6.3. |
| `visibility` | `FieldVisibility` | `shared` | Card filters out `private_`. |
| `orderIndex` | `int` | `0` | Sort key inside its group (and globally for ungrouped). |
| `isBuiltin` | `bool` | `false` | Read-only in the schema editor; the card itself ignores this. |
| `isList` | `bool` | `false` | Triggers list variants of `relation` / `image`, otherwise `_GenericListFieldWidget`. |
| `hasEquip` | `bool` | `false` | For relation lists — exposes the equip toggle column. |
| `showSourceFilter` | `bool` | `false` | For relation lists — show rule-sourced items with a badge. |
| `allowedInSections` | `List<String>` | `[]` | Reserved for non-card surfaces (encounter, mindmap, worldmap, projection). |
| `subFields` | `List<Map<String, String>>` | `[]` | Used by `combatStats` / `conditionStats` to define `{key, label, type}` columns. |
| `groupId` | `String?` | `null` | Group bucket; `null` ⇒ rendered in the "Properties" card. |
| `gridColumnSpan` | `int` | `1` | Flex weight inside the group grid (clamped to `[1, group.gridColumns]`). |
| `createdAt` / `updatedAt` | `String` | — | ISO 8601 timestamps. |

### 6.5 `FieldGroup`

```dart
@freezed
abstract class FieldGroup with _$FieldGroup {
  const factory FieldGroup({
    required String groupId,
    @Default('') String name,
    @Default(1) int gridColumns,
    @Default(0) int orderIndex,
    @Default(false) bool isCollapsed,
  }) = _FieldGroup;
}
```

| Property | Type | Default | Card-side meaning |
|---|---|---|---|
| `groupId` | `String` | — | Bucket key referenced by `FieldSchema.groupId`. |
| `name` | `String` | `''` | Header label inside the `_CollapsibleGroupCard`; if empty, the header is omitted and the body padding is bumped. |
| `gridColumns` | `int` | `1` | Number of columns in the responsive grid (1–4 in practice). |
| `orderIndex` | `int` | `0` | Order in which groups stack vertically. |
| `isCollapsed` | `bool` | `false` | Initial collapsed state. |

The seven built-in group IDs:

| `groupId` | Display name | `gridColumns` |
|---|---|---|
| `grp-attributes` | Attributes | 2 |
| `grp-abilities` | Ability Scores | 1 |
| `grp-combat` | Combat | 2 |
| `grp-resistances` | Resistances | 2 |
| `grp-actions` | Actions | 1 |
| `grp-spells` | Spells | 1 |
| `grp-condition-stats` | Condition Stats | 2 |

---

## 7. Per-Category Card Designs

This section is a self-contained reproduction guide. A reader who has never seen the project should be able to recreate every entity card pixel-for-pixel using only the content below. Each subsection gives the exact arrangement, dimensions, fonts, colors, hint text, and sample-rendered mockups for one category. The card chrome (header, DM notes block, delete button) is identical for every category and is documented once in §7.2 — the per-category subsections only describe the body that fills the slot between header and DM notes.

### 7.1 Mockup conventions

Every ASCII mockup in this section uses a fixed symbol set:

| Symbol | Meaning |
|---|---|
| `┌─┐ │ └─┘` (light) | `_FeatureCard` / `_CollapsibleGroupCard` outer border (purely visual; the real implementation has no border, only a `featureCardBg` fill — the box drawing is just to delimit the region in the mockup). |
| `╔═╗ ║ ╚═╝` (heavy) | The outlined `TextFormField` for the entity name (Material outlined input border in the active theme). |
| `[ … ]` | Outlined `TextFormField` (single-line). The text inside is what the user sees: either the live value (filled state), or the placeholder/hint text in italics (empty state). |
| `[ … ▼]` | `DropdownButtonFormField`. The arrow is the trailing affordance; tapping opens a menu. |
| `[ … ▶]` | Single relation field. The chevron is the trailing affordance; tapping opens an entity selector dialog filtered by `allowedTypes`. |
| `[+]` | "Add" affordance on a list field — opens an entity selector (relation list) or appends a blank row (generic list). |
| `[×]` / `[🗑]` | "Remove" affordance per row. |
| `▾` / `▸` | Collapsible group chevron (open / collapsed). |
| `🛡` | Equip toggle on a relation list row (only visible when the field has `hasEquip: true`). |
| `🎲` | Dice icon prefix on a `dice` field (`Icons.casino`). |
| `📺` | Cast-to-projection icon button (`Icons.cast`). |
| `🔒` | DM Notes lock icon (`Icons.lock`). |
| `🗑` | Delete button leading icon (`Icons.delete_outline`). |
| `☐` / `☑` | `proficiencyTable` proficient checkbox (off / on). |
| `★` | `proficiencyTable` expertise marker (when `expertise: true`). |
| `●` / `○` | `slot` field pips (filled / empty). |
| `(empty)` | Field has no value and is rendered with hint text only. |

Dimensional defaults used everywhere:

| Element | Value |
|---|---|
| Outer scroll padding | 16 px on all sides |
| Inter-block gap | 8 px (between header card / body groups / DM notes) |
| Section card radius | 4 px (hardcoded, not theme-driven) |
| Section card padding | 12 px (all sides) |
| Section card fill | `featureCardBg` |
| Inter-field gap inside a row | 8 px (`SizedBox(width: 8)`) |
| Per-leaf-field vertical padding | 4 px top + 4 px bottom (every leaf widget wraps itself in `Padding(symmetric vertical: 4)`) |
| Group header padding | 12 px horizontal × 10 px vertical |
| Group title style | 12 px / `FontWeight.w600` / `tabText` |
| Group chevron | `Icons.chevron_right` (▸) collapsed / `Icons.expand_more` (▾) open, 16 px, `tabText` |
| Group chevron→title gap | 4 px |
| Default text input style (`isDense: true`) | label 13 px / `tabText`, hint 13 px / `sidebarLabelSecondary` |
| Default text input fill | `canvasBg @ 0.5` (dark themes) / `nodeBgNote @ 0.5` (light themes) |
| Default text input border radius | `borderRadius` from active theme (commonly 4 px, 2 px in serif themes) |
| Default text input content padding | `EdgeInsets.symmetric(horizontal: 12, vertical: 10)` |

Color tokens referenced below are read from `Theme.of(context).extension<DmToolColors>()!`. The card never names a hex literal directly except for the four hardcoded portrait-overlay colors (`Colors.black26`, `Colors.black38`, `Colors.white`, `Colors.white70`) and the per-category badge color which is parsed from `EntityCategorySchema.color` (a hex string like `#ff9800`).

### 7.2 Universal card skeleton (the chrome)

Every category card stamps out the same five-region skeleton. Only the body region varies; everything below is identical for all 19 categories.

#### 7.2.1 Annotated full-card mockup (filled state)

```
─────────────────────────────────────── 16 px outer padding ─────────────────────────────────────────

┌─ Header _FeatureCard ─ featureCardBg ─ radius 4 ─ padding 12 ─────────────────────────────────────┐
│                                                                                                  │
│  ┌──────────────┐  ┌── Right column (Expanded) ──────────────────────────────────────────────┐   │
│  │              │  │  ┌─ Badge ─┐                                                  ┌─ Cast ─┐│   │
│  │              │  │  │  NPC    │ ← 11 px w600 catColor on catColor@0.15             │  📺   ││   │
│  │              │  │  └─────────┘                                                    └────────┘│   │
│  │              │  │  ↕ 8 px                                                                  │   │
│  │  Portrait    │  │  ╔══════════════════════════════════════════════════════════════════════╗│   │
│  │  200×260 px  │  │  ║  Captain Aldric                                                     ║│ ← │ 18 px bold tabActiveText
│  │              │  │  ╚══════════════════════════════════════════════════════════════════════╝│   │
│  │   ◀ 1/3 ▶    │  │  ↕ 10 px                                                                 │   │
│  │              │  │  Description                          ← 11 px tabText                     │   │
│  │              │  │  ↕ 4 px                                                                  │   │
│  │              │  │  ┌──────────────────────────────────────────────────────────────────────┐│   │
│  │              │  │  │ A grizzled half-elf veteran of the city watch. Carries a longsword,  ││ ← │ 13 px htmlText
│  │              │  │  │ and a tankard. @LordRavencroft trusts him implicitly.                ││   │  (markdown + @mention)
│  │              │  │  └──────────────────────────────────────────────────────────────────────┘│   │
│  │              │  │  ↕ 10 px                                                                 │   │
│  │              │  │  ┌──── Source (Expanded) ────┐  ↔ 8 px  ┌──── Tags (Expanded) ─────────┐ │   │
│  │              │  │  │ [ PHB                  ] │           │ [ city, guard, friendly    ] │ │ ← │ 12 px htmlText
│  │              │  │  └───────────────────────────┘           └────────────────────────────┘ │   │
│  └──────────────┘  └──────────────────────────────────────────────────────────────────────────┘   │
│         ↔ 12 px (between portrait and right column)                                              │
│                                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
                                          ↕ 8 px
─────────────────────────────────────────── BODY SLOT ───────────────────────────────────────────────
                       (per-category content — see the subsection for that category)
─────────────────────────────────────────────────────────────────────────────────────────────────────
                                          ↕ 8 px
┌─ DM Notes ─ featureCardBg ─ radius 4 ─ Border.all(dmNoteBorder, 1 px) ─ padding 12 ───────────────┐
│  🔒 DM Notes        ← lock 14 px @ dmNoteTitle, label 12 px w600 dmNoteTitle                     │
│  ↕ 6 px                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │ Owed money to the cooper Mathilde — leverage if Captain misbehaves. (@to mention)         │ ← │ 13 px htmlText
│  └──────────────────────────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
                                          ↕ 16 px (edit mode only — read-only mode ends at DM Notes)
                                                                                  ┌──────────────┐
                                                                                  │ 🗑  Delete   │ ← FilledButton.icon
                                                                                  └──────────────┘   13 px w600
                                                                                  dangerBtnBg / dangerBtnText
```

#### 7.2.2 Empty-state mockup (new, blank entity)

```
┌─ Header ──────────────────────────────────────────────────────────────────────────────────────────┐
│  ┌──────────────┐  ┌─ NPC ─┐                                                          ┌─ 📺 ─┐    │
│  │   👤         │  └───────┘                                                          └──────┘    │
│  │              │  ↕ 8 px                                                                         │
│  │  No Image    │  ╔══════════════════════════════════════════════════════════════════════╗      │
│  │              │  ║  Entity Name                                                        ║ ← hint │
│  │              │  ╚══════════════════════════════════════════════════════════════════════╝      │
│  │              │  Description                                                                   │
│  │              │  ┌──────────────────────────────────────────────────────────────────────┐       │
│  │              │  │ Markdown supported... (@ to mention)                                 │ ← hint│
│  │              │  │                                                                      │       │
│  │              │  │                                                                      │       │
│  │              │  └──────────────────────────────────────────────────────────────────────┘       │
│  │              │  ┌──── Source ────────────────┐    ┌──── Tags ────────────────────────┐         │
│  │              │  │ e.g. D&D 5e SRD            │ ← hint │ comma separated              │ ← hint  │
│  │              │  └────────────────────────────┘    └──────────────────────────────────┘         │
│  └──────────────┘                                                                                 │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─ Body — depends on category ──────────────────────────────────────────────────────────────────────┐
│   ...                                                                                             │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─ DM Notes ─ dmNoteBorder ─────────────────────────────────────────────────────────────────────────┐
│  🔒 DM Notes                                                                                       │
│  Private DM notes... (@ to mention)        ← hint, sidebarLabelSecondary                          │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘

                                                                                  ┌──────────────┐
                                                                                  │ 🗑  Delete   │
                                                                                  └──────────────┘
```

The portrait placeholder (when `images.length == 0`) shows `Icons.person_outline` 48 px @ 40 % alpha of `sidebarLabelSecondary` and the caption "No Image" 10 px / `sidebarLabelSecondary`, both vertically centered.

#### 7.2.3 Element-by-element measurement table

| # | Element | Position | Dimensions | Fill / Border | Typography | Hint / Placeholder |
|---|---|---|---|---|---|---|
| 1 | Outer scroll | full width | `EdgeInsets.all(16)` | none | — | — |
| 2 | Header `_FeatureCard` | full width | radius 4, padding 12 | `featureCardBg`, no border | — | — |
| 3 | Portrait container | header left | 200 × 260 px | radius `cardBorderRadius`, `Border.all(featureCardBorder)`, `clipBehavior: Clip.antiAlias` | — | — |
| 4 | Portrait image | inside #3 | full | `BoxFit.cover`, `cacheWidth: 400` | — | — |
| 5 | Portrait placeholder | inside #3 | full | `featureCardBg` | "No Image" 10 px / `sidebarLabelSecondary` | — |
| 6 | Portrait nav arrow (left/right) | absolute, 4 px from edge, vertically centered | 26 × 26 px circle | `Colors.black26` | `Icons.chevron_left/right` 18 px white | — |
| 7 | Portrait counter pill | absolute, 6 px from bottom, horizontally centered | wraps content | `Colors.black38`, radius 10, padding 6 × 2 | `'${i+1}/${n}'` 9 px `Colors.white70` | — |
| 8 | Portrait add button | absolute, top 4 right 4 (edit mode) | 26 × 26 px circle | `Colors.black26` | `Icons.add_photo_alternate` 14 px white | — |
| 9 | Portrait remove button | absolute, top 4 left 4 (edit mode) | 26 × 26 px circle | `Colors.black26` | `Icons.close` 14 px `dangerBtnBg` | — |
| 10 | Portrait→right gap | between #3 and #11 | 12 px | — | — | — |
| 11 | Header right column | header right (Expanded) | flex 1 | — | — | — |
| 12 | Category badge | top-left of #11 | wraps content, radius 4, padding 8 × 3 | `catColor.withValues(alpha: 0.15)` | category name 11 px / w600 / `catColor` | — |
| 13 | Spacer | between #12 and #14 | flex 1 | — | — | — |
| 14 | Cast button | top-right of #11 | 28 × 28 min hit target, 0 padding | transparent | `Icons.cast` 16 px | tooltip: "Project entity card to player screen" |
| 15 | Gap below #12 row | — | 8 px | — | — | — |
| 16 | Name input | full width of #11 | `TextFormField` `isDense: false`, contentPadding 10 × 10 | theme input fill, theme input border | input text 18 px / bold / `tabActiveText` | "Entity Name" |
| 17 | Gap below #16 | — | 10 px | — | — | — |
| 18 | "Description" label | full width of #11 | bare `Text` | none | 11 px regular / `tabText` | — |
| 19 | Gap below #18 | — | 4 px | — | — | — |
| 20 | Description editor | full width of #11 | `MarkdownTextArea`, contentPadding 10 × 10, `minLines: 3` (edit) / `null` (read-only) | theme input fill, theme input border | 13 px / `htmlText` | "Markdown supported... (@ to mention)" |
| 21 | Gap below #20 | — | 10 px | — | — | — |
| 22 | Source/Tags `Row` | full width of #11 | `Row` of two `Expanded` children with `SizedBox(width: 8)` between | — | — | — |
| 22a | Source input | left half of #22 | `TextFormField`, contentPadding 10 × 10 | theme input fill, theme input border | label "Source" 13 px / `tabText`, value 12 px / `htmlText` | "e.g. D&D 5e SRD" |
| 22b | Tags input | right half of #22 | `TextFormField`, contentPadding 10 × 10 | theme input fill, theme input border | label "Tags" 13 px / `tabText`, value 12 px / `htmlText` | "comma separated" |
| 23 | Gap below header | — | 8 px | — | — | — |
| 24 | Body slot | full width | one `_FeatureCard` ("Properties") plus N `_CollapsibleGroupCard`, separated by 8 px gaps; per-category | — | — | — |
| 25 | Gap below body | — | 8 px | — | — | — |
| 26 | DM Notes container | full width | `ClipRRect(radius: 4)` + `Container` with `Border.all(dmNoteBorder, 1 px)`, padding 12 | `featureCardBg`, border `dmNoteBorder` | — | — |
| 27 | DM Notes header row | top of #26 | `Row` | — | lock icon 14 px / `dmNoteTitle` + 4 px gap + "DM Notes" 12 px / w600 / `dmNoteTitle` | — |
| 28 | Gap inside DM Notes | between #27 and #29 | 6 px | — | — | — |
| 29 | DM Notes editor | bottom of #26 | `MarkdownTextArea`, `border: InputBorder.none`, `isDense: true`, `contentPadding: EdgeInsets.zero`, `filled: false`, `maxLines: 4` (edit) / `null` (read-only) | none | 13 px / `htmlText`, hint `sidebarLabelSecondary` | "Private DM notes... (@ to mention)" |
| 30 | Gap below DM Notes | edit mode only | 16 px | — | — | — |
| 31 | Delete row | edit mode only | `Row(MainAxisAlignment.end, [...])` | — | — | — |
| 31a | Delete button | right edge of #31 | `FilledButton.icon` | `dangerBtnBg` background | "Delete" 13 px / w600 / `dangerBtnText` + leading `Icons.delete_outline` 16 px | — |

#### 7.2.4 Behavioral details that affect rendering

- The portrait gallery's nav arrows, counter pill, add/remove buttons all conditionally render: arrows only when `images.length > 1` and the index is not at the corresponding bound; counter pill only when `images.length > 1`; add/remove only when `!readOnly` and `_showControls` is true. `_showControls = _hovered || Platform.isAndroid || Platform.isIOS` — desktop hides them until the cursor enters the gallery; mobile always shows them.
- Right-click (desktop) and long-press (mobile) on the portrait open a "Project to player screen" context menu.
- Tapping the cast button (#14) projects the whole entity card to the player screen and shows a 2-second SnackBar `"Entity card projected to player screen"`.
- Confirming delete shows a centered AlertDialog with title `"Delete Entity"`, content `"Are you sure you want to delete \"${entity.name}\"?"`, two actions: a `TextButton` "Cancel" and a `FilledButton` "Delete" styled with `dangerBtnBg` / `dangerBtnText`.
- Read-only mode hides the delete row entirely and disables every input (the input still shows the value, just non-editable). Dropdowns become inert (`onChanged: null`).

### 7.3 Capability matrix

| Category | Slug | Color | Stat block | Actions | Spells | Cond. stats | Sections | Filters |
|---|---|---|:-:|:-:|:-:|:-:|---|---|
| NPC | `npc` | `#ff9800` orange | ✓ | ✓ | ✓ | — | encounter, mindmap, worldmap, projection | attitude, level, source |
| Monster | `monster` | `#d32f2f` red | ✓ | ✓ | ✓ | — | encounter, mindmap, worldmap, projection | cr, attack_type, source |
| Player | `player` | `#4caf50` green | ✓ | ✓ | ✓ | — | encounter, mindmap, worldmap, projection | level |
| Spell | `spell` | `#7b1fa2` purple | — | — | — | — | mindmap | level, school, source |
| Equipment | `equipment` | `#795548` brown | — | — | — | — | mindmap | category, rarity, source |
| Class | `class` | `#1976d2` blue | — | — | — | — | mindmap | — |
| Race | `race` | `#00897b` teal | — | — | — | — | mindmap | — |
| Location | `location` | `#2e7d32` dark green | — | — | — | — | worldmap, mindmap | danger_level |
| Quest | `quest` | `#f57c00` amber | — | — | — | — | mindmap | status |
| Lore | `lore` | `#5c6bc0` indigo | — | — | — | — | mindmap | category |
| Status Effect | `status-effect` | `#e91e63` pink | — | — | — | — | encounter | effect_type |
| Feat | `feat` | `#ff7043` light red | — | — | — | — | mindmap | — |
| Background | `background` | `#8d6e63` warm gray | — | — | — | — | mindmap | — |
| Plane | `plane` | `#26c6da` cyan | — | — | — | — | mindmap, worldmap | — |
| Condition | `condition` | `#ab47bc` violet | — | — | — | ✓ | encounter | — |
| Trait | `trait` | `#78909c` gray | — | — | — | — | mindmap | — |
| Action | `action` | `#ef6c00` deep orange | — | — | — | — | mindmap | — |
| Reaction | `reaction` | `#5e35b1` deep purple | — | — | — | — | mindmap | — |
| Legendary Action | `legendary-action` | `#ffd600` yellow | — | — | — | — | mindmap | — |

The capability flags drive which built-in groups the category gets:

- `hasStatBlock` ⇒ `Attributes`, `Ability Scores`, `Combat`, `Resistances` groups, plus the stat-block field set documented in §7.4.
- `hasActions` ⇒ `Actions` group with `traits`, `actions`, `reactions`, `legendary_actions` (relation lists into Trait / Action / Reaction / Legendary Action categories).
- `hasSpells` ⇒ `Spells` group with `spells` relation list (target = Spell category).
- `hasConditionStats` ⇒ `Condition Stats` group with `condition_stats` (`{default_duration, effect}`).

### 7.4 Stat-block body skeleton (shared by NPC, Monster, Player)

Every category that has `hasStatBlock: true` (NPC, Monster, Player) renders the **same** body skeleton. Only the *Attributes* group's fields differ — everything below Attributes is identical for all three categories. This subsection documents the shared part once; §7.5 / §7.6 / §7.7 only describe each category's Attributes group plus a sample-filled mockup of the whole card.

The shared body is six collapsible groups in this order: **Attributes** (per-category fields), **Ability Scores**, **Combat**, **Resistances**, **Actions** (when `hasActions: true`), **Spells** (when `hasSpells: true`). Group `gridColumns` values: Attributes 2, Ability Scores 1, Combat 2, Resistances 2, Actions 1, Spells 1. Each group is a `_CollapsibleGroupCard`. Inter-group gap is 8 px.

#### 7.4.1 Attributes group (per-category — see §7.5/7.6/7.7)

The Attributes group always contains the `source` field plus the category-specific attribute fields. With `gridColumns: 2`, fields with `gridColumnSpan: 1` pair up two-per-row. Visual structure:

```
┌─ ▾ Attributes ────────────────────────────────────────────── featureCardBg ──┐
│  ┌─ field 1 ───────────────────┐  ↔ 8 px  ┌─ field 2 ───────────────────┐    │
│  │ [ Source                  ] │           │ [ Race                  ▶ ] │    │
│  └─────────────────────────────┘           └─────────────────────────────┘    │
│  ┌─ field 3 ───────────────────┐           ┌─ field 4 ───────────────────┐    │
│  │ [ Class                 ▶ ] │           │ [ Level                   ] │    │
│  └─────────────────────────────┘           └─────────────────────────────┘    │
│  ┌─ field 5 ───────────────────┐           ┌─ field 6 ───────────────────┐    │
│  │ [ Attitude              ▼ ] │           │ [ Location              ▶ ] │    │
│  └─────────────────────────────┘           └─────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

Each cell is a leaf field widget wrapped in `Padding(symmetric vertical: 4)`. Text inputs (`text`), enum dropdowns (`enum_`), and single relation fields (`relation`) all share the same outlined `TextFormField`-style chrome supplied by `InputDecorationTheme`: theme input fill, theme input border radius, label above, value inside. Relation fields additionally show a leading `Icons.link` (size 18) prefix.

#### 7.4.2 Ability Scores group

Single field `stat_block` of type `statBlock`. Group `gridColumns: 1`. The field widget itself is a `Card` (Material default elevation, theme card shape, `margin: EdgeInsets.symmetric(vertical: 4)`, padding 12 inside) holding a `Column`:

```
┌─ ▾ Ability Scores ──────────────────────────── featureCardBg ───────────────┐
│  ┌─ Card (Material) ─────────────────────────────────────────────────────┐  │
│  │ Ability Scores       ← 14 px / theme.titleSmall                       │  │
│  │ ↕ 8 px                                                                │  │
│  │ ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐                        │  │
│  │ │STR │  │DEX │  │CON │  │INT │  │WIS │  │CHA │  ← 11 px bold          │  │
│  │ │ ↕4 │  │ ↕4 │  │ ↕4 │  │ ↕4 │  │ ↕4 │  │ ↕4 │                        │  │
│  │ │[10]│  │[14]│  │[12]│  │[10]│  │[13]│  │[ 8]│  ← 44 px wide, 16 bold │  │
│  │ │ ↕2 │  │ ↕2 │  │ ↕2 │  │ ↕2 │  │ ↕2 │  │ ↕2 │                        │  │
│  │ │ +0 │  │ +2 │  │ +1 │  │ +0 │  │ +1 │  │ -1 │  ← 11 px outline       │  │
│  │ └────┘  └────┘  └────┘  └────┘  └────┘  └────┘                        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

- Six columns laid out in a `Row`, each child wrapped in `Expanded`. Equal flex.
- Per column: `Column` with three children — ability key label (11 px / bold / inherited color), 4 px gap, score input (`SizedBox(width: 44)` containing a `TextFormField` with `keyboardType: TextInputType.number`, `textAlign: TextAlign.center`, value style 16 px bold, `contentPadding: EdgeInsets.symmetric(vertical: 8)`, `isDense: true`), 2 px gap, modifier text (11 px regular / `colorScheme.outline`).
- Modifier displayed as `+N` (sign always shown) computed inline as `((score - 10) ~/ 2)`. Modifiers re-render whenever the value changes.
- Default values when the entity has no `stat_block` map: every score 10, every modifier `+0`.

#### 7.4.3 Combat group (`gridColumns: 2`)

Five fields in this exact order: `combat_stats` (span 2), `saving_throws` (span 2), `skills` (span 2), `proficiency_bonus` (span 1), `passive_perception` (span 1). Span-2 fields each occupy a full row; the last two fields share a row.

```
┌─ ▾ Combat ─────────────────────────────────── featureCardBg ────────────────┐
│  ┌─ Card (combat_stats) ─────────────────────────────────────────────────┐  │
│  │ Combat Stats                                                          │  │
│  │ ↕ 8 px                                                                │  │
│  │ ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐              │  │
│  │ │ HP   │MaxHP │ AC   │Speed │ Lvl  │ Init │ CR   │ XP   │              │  │
│  │ │[27 ] │[30 ] │[16 ] │[30ft]│[ 3 ] │[+2 ] │[1/2] │[100] │              │  │
│  │ └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│  ┌─ Card (saving_throws) ────────────────────────────────────────────────┐  │
│  │ Saving Throws                                                         │  │
│  │ ☐ Strength      STR  +0       ☐ Intelligence  INT  +0                 │  │
│  │ ☑ Dexterity     DEX  +4       ☐ Wisdom        WIS  +1                 │  │
│  │ ☐ Constitution  CON  +1       ☐ Charisma      CHA  -1                 │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│  ┌─ Card (skills) ───────────────────────────────────────────────────────┐  │
│  │ Skills                                                                │  │
│  │ ☐ Acrobatics       DEX  +2     ☐ Investigation     INT  +0            │  │
│  │ ☐ Animal Handling  WIS  +1     ☑ Medicine          WIS  +3            │  │
│  │ ☐ Arcana           INT  +0     ☐ Nature            INT  +0            │  │
│  │ ☑ Athletics        STR  +5★    ☑ Perception        WIS  +3            │  │
│  │ ☐ Deception        CHA -1      ☐ Performance       CHA -1             │  │
│  │ ☐ History          INT  +0     ☐ Persuasion        CHA -1             │  │
│  │ ☐ Insight          WIS  +1     ☐ Religion          INT  +0            │  │
│  │ ☐ Intimidation     CHA -1      ☐ Sleight of Hand   DEX  +2            │  │
│  │                                ☐ Stealth           DEX  +2            │  │
│  │                                ☐ Survival          WIS  +1            │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│  ┌─ proficiency_bonus ─────────┐  ┌─ passive_perception ────────────────┐   │
│  │ [ Proficiency Bonus  : 2  ] │  │ [ Passive Perception : 11         ] │   │
│  └─────────────────────────────┘  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

- Combat Stats and Saving Throws and Skills are each their own Material `Card` (the field widget chooses Card chrome internally; the surrounding `_CollapsibleGroupCard` adds another visual layer).
- `combat_stats` lays its eight sub-fields (`hp / max_hp / ac / speed / level / initiative / cr / xp`) into a responsive grid where the column count is `(maxWidth / 88).floor().clamp(1, 8)`. With a typical 720 px-wide card body the formula resolves to 8 columns, so all sub-fields share one row. On narrower viewports the row wraps. Inter-cell horizontal gap inside this grid is 8 px (`Padding(EdgeInsets.only(right: 8))` on every cell except the last in each row); inter-row gap is 8 px.
- Each `combat_stats` cell is a `TextFormField` with `textAlign: TextAlign.center`, `isDense: true`, `contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4)`, and `labelText` set to the sub-field label (`HP`, `Max HP`, …).
- The `initiative` sub-field is the only `dice`-typed cell in the default schema; it accepts standard dice notation (`+2`, `-1d4`, `+2+1d4`) which the encounter screen later evaluates against a chosen die.
- `saving_throws` and `skills` are `proficiencyTable` widgets. Each row shows: a checkbox (`Icons.check_box_outline_blank` / `Icons.check_box`) for proficient, the row name (12 px regular), the ability key (11 px bold uppercase), the computed total in monospaced format `±N`. When `expertise: true` the row shows a star marker (`★` or filled badge) and the total adds proficiency bonus twice.
- The total per row is computed at render time: `ability_modifier(stat_block[ability]) + (proficient ? proficiency_bonus * (expertise ? 2 : 1) : 0) + misc`.

#### 7.4.4 Resistances group (`gridColumns: 2`)

Four `text` fields, one per row pair:

```
┌─ ▾ Resistances ────────────────────────────── featureCardBg ───────────────┐
│  ┌─ damage_vulnerabilities ────┐  ┌─ damage_resistances ────────────────┐   │
│  │ [ Damage Vulnerabilities  ] │  │ [ Damage Resistances              ] │   │
│  └─────────────────────────────┘  └─────────────────────────────────────┘   │
│  ┌─ damage_immunities ─────────┐  ┌─ condition_immunities ──────────────┐   │
│  │ [ Damage Immunities       ] │  │ [ Condition Immunities            ] │   │
│  └─────────────────────────────┘  └─────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
```

Plain text inputs. The card does **not** auto-parse comma-separated values into chips — the field stores the literal string the user typed.

#### 7.4.5 Actions group (when `hasActions: true`, `gridColumns: 1`)

Four `relation` list fields, one per row:

```
┌─ ▾ Actions ────────────────────────────────── featureCardBg ───────────────┐
│  ┌─ traits (relation list, allowedTypes: ['trait']) ───────────────────┐   │
│  │ Trait List                                                    [+]   │   │
│  │ ──────────────────────────────────────────────────────────────────  │   │
│  │  • Pack Tactics                                            🛡  [×]   │   │
│  │  • Brave                                                       [×]   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  ┌─ actions (relation list, allowedTypes: ['action']) ─────────────────┐   │
│  │ Action List                                                   [+]   │   │
│  │ ──────────────────────────────────────────────────────────────────  │   │
│  │  • Longsword Strike     +5 to hit, 1d8+2 slashing          🛡  [×]   │   │
│  │  • Shield Bash          +4 to hit, 1d4+2 bludgeoning           [×]   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  ┌─ reactions (relation list, allowedTypes: ['reaction']) ─────────────┐   │
│  │ Reaction List                                                 [+]   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  ┌─ legendary_actions (relation list) ─────────────────────────────────┐   │
│  │ Legendary Action List                                         [+]   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
```

Each row is `_ReferenceListFieldWidget` (a `Card`):
- Header row: label 12 px / w600 / `tabText` on the left, `[+]` (`Icons.add_circle_outline` 18 px) on the right. `[+]` opens an entity selector dialog filtered by `allowedTypes`.
- Body: zero or more linked-entity rows. Each row shows `•` bullet + entity name (13 px / `htmlText`) + a peek of its summary (12 px / `sidebarLabelSecondary`) + an equip toggle (`Icons.shield` filled when equipped, outlined when unequipped) when `hasEquip: true` + `[×]` (`Icons.close` 16 px) remove button.
- Empty state: header row only, no separator, no body content.
- The `Trait List` / `Action List` fields are NOT marked `hasEquip` by default in the built-in schema, so the shield icon does not appear unless a custom schema enables it.

#### 7.4.6 Spells group (when `hasSpells: true`, `gridColumns: 1`)

Single `relation` list field `spells` (`allowedTypes: ['spell']`):

```
┌─ ▾ Spells ─────────────────────────────────── featureCardBg ───────────────┐
│  ┌─ spells (relation list) ────────────────────────────────────────────┐   │
│  │ Spell List                                                    [+]   │   │
│  │ ──────────────────────────────────────────────────────────────────  │   │
│  │  • Bless                  Lvl 1 · Enchantment              [×]      │   │
│  │  • Cure Wounds            Lvl 1 · Evocation                [×]      │   │
│  │  • Sacred Flame           Cantrip · Evocation              [×]      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
```

The peek line shows `Lvl ${spell.level} · ${spell.school}` pulled from the linked Spell entity's fields.

### 7.5 NPC

| Property | Value |
|---|---|
| Slug | `npc` |
| Badge color | `#ff9800` (orange). Badge fill `#ff9800 @ 15 %`. Badge label `#ff9800 @ 100 %`. |
| Capabilities | `hasStatBlock`, `hasActions`, `hasSpells` |
| Built-in groups | Attributes, Ability Scores, Combat, Resistances, Actions, Spells |
| Sections | encounter, mindmap, worldmap, projection |
| Filter keys | attitude, level, source |

**Attributes group fields** (in order):

| Field key | Label | Type | Span | Validation / Notes |
|---|---|---|---|---|
| `source` | Source | `text` | 1 | placeholder `e.g. PHB, MM, Custom` |
| `race` | Race | `relation` | 1 | `allowedTypes: ['race']` |
| `class_` | Class | `relation` | 1 | `allowedTypes: ['class']` |
| `level` | Level | `text` | 1 | — |
| `attitude` | Attitude | `enum_` | 1 | `allowedValues: ['Friendly', 'Neutral', 'Hostile']` |
| `location` | Location | `relation` | 1 | `allowedTypes: ['location']` |

NPC's Attributes group renders six fields paired into three rows of two (because `gridColumns: 2` and every field has `gridColumnSpan: 1`).

#### 7.5.1 Sample-filled mockup ("Captain Aldric")

```
┌─ Header ─────────────────────────────────────────────────────────── featureCardBg ──┐
│  ┌──────────────┐  ┌─ NPC ─┐                                              ┌──────┐  │
│  │ portrait of  │  │ NPC   │ ← orange badge                               │  📺  │  │
│  │ Captain      │  └───────┘                                              └──────┘  │
│  │ Aldric       │  ╔══════════════════════════════════════════════════════════╗     │
│  │              │  ║ Captain Aldric                                          ║     │
│  │              │  ╚══════════════════════════════════════════════════════════╝     │
│  │  ◀  1/3  ▶   │  Description                                                     │
│  │              │  ┌──────────────────────────────────────────────────────────┐    │
│  └──────────────┘  │ A grizzled half-elf veteran of the Waterdeep watch.      │    │
│                    │ Loyal to @LordRavencroft. Carries a +1 longsword.        │    │
│                    └──────────────────────────────────────────────────────────┘    │
│                    [ Source: PHB                ]   [ Tags: city, guard, ally ]    │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Attributes ──────────────────────────────────────────────────────────────────────┐
│  [ Source: PHB                  ]    [ Race: Half-Elf                          ▶ ]  │
│  [ Class: Fighter            ▶  ]    [ Level: 5                                  ]  │
│  [ Attitude: Friendly        ▼  ]    [ Location: Waterdeep — The Yawning Portal ▶ ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Ability Scores ──────────────────────────────────────────────────────────────────┐
│   STR    DEX    CON    INT    WIS    CHA                                            │
│  [ 16 ] [ 14 ] [ 14 ] [ 11 ] [ 13 ] [ 10 ]                                           │
│   +3     +2     +2     +0     +1     +0                                              │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Combat ──────────────────────────────────────────────────────────────────────────┐
│  ┌ Combat Stats ────────────────────────────────────────────────────────────────┐   │
│  │  HP    MaxHP  AC    Speed  Lvl  Init  CR    XP                               │   │
│  │ [44] [44 ]  [18 ] [30ft] [5 ] [+2] [3  ] [700]                              │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│  ┌ Saving Throws ───────────────────────────────────────────────────────────────┐   │
│  │ ☑ Strength      STR  +6    ☐ Intelligence  INT  +0                           │   │
│  │ ☐ Dexterity     DEX  +2    ☐ Wisdom        WIS  +1                           │   │
│  │ ☑ Constitution  CON  +5    ☐ Charisma      CHA  +0                           │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│  ┌ Skills ──────────────────────────────────────────────────────────────────────┐   │
│  │ ☐ Acrobatics       DEX +2     ☐ Investigation    INT +0                      │   │
│  │ ☐ Animal Handling  WIS +1     ☐ Medicine         WIS +1                      │   │
│  │ ☐ Arcana           INT +0     ☐ Nature           INT +0                      │   │
│  │ ☑ Athletics        STR +6     ☑ Perception       WIS +4                      │   │
│  │ ☐ Deception        CHA +0     ☐ Performance      CHA +0                      │   │
│  │ ☐ History          INT +0     ☑ Persuasion       CHA +3                      │   │
│  │ ☑ Insight          WIS +4     ☐ Religion         INT +0                      │   │
│  │ ☑ Intimidation     CHA +3     ☐ Sleight of Hand  DEX +2                      │   │
│  │ ☐                              ☐ Stealth          DEX +2                      │   │
│  │ ☐                              ☐ Survival         WIS +1                      │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│  [ Proficiency Bonus: 3 ]      [ Passive Perception: 14 ]                           │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Resistances ─────────────────────────────────────────────────────────────────────┐
│  [ Damage Vulnerabilities:        ]   [ Damage Resistances:                       ] │
│  [ Damage Immunities:             ]   [ Condition Immunities: charmed, frightened ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Actions ─────────────────────────────────────────────────────────────────────────┐
│  ┌ Trait List                                                              [+] ─┐   │
│  │  • Brave                       Adv. on saves vs. frightened          [×]    │   │
│  │  • Second Wind                 1/short rest, regain 1d10+5 HP        [×]    │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│  ┌ Action List                                                             [+] ─┐   │
│  │  • Longsword Strike            +6 to hit, 1d8+3 slashing             [×]    │   │
│  │  • Heavy Crossbow              +5 to hit, 1d10+2 piercing            [×]    │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│  ┌ Reaction List                                                           [+] ─┐   │
│  │  • Parry                       +3 to AC vs. one melee attack         [×]    │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│  ┌ Legendary Action List                                                   [+] ─┐   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Spells ──────────────────────────────────────────────────────────────────────────┐
│  ┌ Spell List                                                              [+] ─┐   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ DM Notes ──────────────────────────── dmNoteBorder ──────── featureCardBg ─────────┐
│  🔒 DM Notes                                                                         │
│  Owes the cooper Mathilde 80 gp; can be bribed for tavern intel.                    │
└─────────────────────────────────────────────────────────────────────────────────────┘

                                                                          ┌──────────┐
                                                                          │🗑 Delete │
                                                                          └──────────┘
```

#### 7.5.2 Empty-state mockup (new NPC)

```
Header — chrome identical to §7.2.2 with the orange [ NPC ] badge.

┌─ ▾ Attributes ──────────────────────────────────────────────────────────────────────┐
│  [ Source: e.g. PHB, MM, Custom ]   [ Race                                       ▶ ] │
│  [ Class                      ▶ ]   [ Level                                        ] │
│  [ Attitude                   ▼ ]   [ Location                                   ▶ ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Ability Scores ──────────────────────────────────────────────────────────────────┐
│   STR    DEX    CON    INT    WIS    CHA                                            │
│  [ 10 ] [ 10 ] [ 10 ] [ 10 ] [ 10 ] [ 10 ]                                           │
│   +0     +0     +0     +0     +0     +0                                              │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Combat ──────────────────────────────────────────────────────────────────────────┐
│  Combat Stats — every cell empty                                                    │
│  Saving Throws — 6 unchecked rows, all totals +0                                    │
│  Skills — 18 unchecked rows, all totals based on score 10 (+0 unless modified)      │
│  [ Proficiency Bonus: 2 ]   [ Passive Perception: ]                                 │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Resistances ─────────────────────────────────────────────────────────────────────┐
│  [ Damage Vulnerabilities ]   [ Damage Resistances ]                                │
│  [ Damage Immunities       ]   [ Condition Immunities ]                              │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Actions ─────────────────────────────────────────────────────────────────────────┐
│  Trait List              [+]                                                         │
│  Action List             [+]                                                         │
│  Reaction List           [+]                                                         │
│  Legendary Action List   [+]                                                         │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Spells ──────────────────────────────────────────────────────────────────────────┐
│  Spell List              [+]                                                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.6 Monster

| Property | Value |
|---|---|
| Slug | `monster` |
| Badge color | `#d32f2f` (red). Badge fill `#d32f2f @ 15 %`. Badge label `#d32f2f @ 100 %`. |
| Capabilities | `hasStatBlock`, `hasActions`, `hasSpells` |
| Built-in groups | Attributes, Ability Scores, Combat, Resistances, Actions, Spells |
| Sections | encounter, mindmap, worldmap, projection |
| Filter keys | cr, attack_type, source |

**Attributes group fields:**

| Field key | Label | Type | Span | Validation / Notes |
|---|---|---|---|---|
| `source` | Source | `text` | 1 | placeholder `e.g. PHB, MM, Custom` |
| `cr` | Challenge Rating | `text` | 1 | — |
| `attack_type` | Attack Type | `text` | 1 | — |

Three fields with `gridColumns: 2` ⇒ first row pairs `source` + `cr`; second row holds `attack_type` alone in the left slot, right slot stays empty.

Everything below Attributes is identical to §7.4 (shared stat-block body skeleton).

#### 7.6.1 Sample-filled mockup ("Goblin Scout")

```
┌─ Header ────────────────────────────────────────────────────────────────────────────┐
│  ┌──────────────┐  ┌─ Monster ─┐                                          ┌──────┐  │
│  │ goblin       │  │ Monster   │ ← red badge                              │  📺  │  │
│  │ portrait     │  └───────────┘                                          └──────┘  │
│  │              │  ╔══════════════════════════════════════════════════════════╗     │
│  │              │  ║ Goblin Scout                                            ║     │
│  │              │  ╚══════════════════════════════════════════════════════════╝     │
│  │   1/1        │  Description                                                     │
│  │              │  ┌──────────────────────────────────────────────────────────┐    │
│  │              │  │ Wiry green-skinned skirmisher. Sneaks ahead of the warband│   │
│  └──────────────┘  │ to scout. Flees when reduced below 1/3 HP.               │    │
│                    └──────────────────────────────────────────────────────────┘    │
│                    [ Source: MM                 ]   [ Tags: humanoid, goblin     ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Attributes ──────────────────────────────────────────────────────────────────────┐
│  [ Source: MM                   ]   [ Challenge Rating: 1/4                       ] │
│  [ Attack Type: Ranged          ]                                                    │
└─────────────────────────────────────────────────────────────────────────────────────┘

(rest of body — Ability Scores / Combat / Resistances / Actions / Spells —
 follows the §7.4 skeleton with goblin-appropriate values.)
```

#### 7.6.2 Empty-state mockup

Identical to NPC empty-state with the Attributes group instead showing:

```
┌─ ▾ Attributes ──────────────────────────────────────────────────────────────────────┐
│  [ Source: e.g. PHB, MM, Custom ]   [ Challenge Rating ]                            │
│  [ Attack Type ]                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.7 Player

| Property | Value |
|---|---|
| Slug | `player` |
| Badge color | `#4caf50` (green). Badge fill `#4caf50 @ 15 %`. Badge label `#4caf50 @ 100 %`. |
| Capabilities | `hasStatBlock`, `hasActions`, `hasSpells` |
| Built-in groups | Attributes, Ability Scores, Combat, Resistances, Actions, Spells |
| Sections | encounter, mindmap, worldmap, projection |
| Filter keys | level |

**Attributes group fields:**

| Field key | Label | Type | Span | Validation / Notes |
|---|---|---|---|---|
| `source` | Source | `text` | 1 | placeholder `e.g. PHB, MM, Custom` |
| `class_` | Class | `relation` | 1 | `allowedTypes: ['class']` |
| `race` | Race | `relation` | 1 | `allowedTypes: ['race']` |
| `level` | Level | `text` | 1 | — |

Four fields paired into two rows.

Everything below Attributes is identical to §7.4.

#### 7.7.1 Sample-filled mockup ("Lyra Sunbloom")

```
┌─ Header ────────────────────────────────────────────────────────────────────────────┐
│  ┌──────────────┐  ┌─ Player ─┐                                           ┌──────┐  │
│  │ Lyra         │  │ Player   │ ← green badge                             │  📺  │  │
│  │ portrait     │  └──────────┘                                           └──────┘  │
│  │              │  ╔══════════════════════════════════════════════════════════╗     │
│  │              │  ║ Lyra Sunbloom                                           ║     │
│  │              │  ╚══════════════════════════════════════════════════════════╝     │
│  │   1/2        │  Description                                                     │
│  │              │  ┌──────────────────────────────────────────────────────────┐    │
│  │              │  │ Wood Elf druid raised by the rangers of @TheGreyOaks.    │    │
│  │              │  │ Wields a quarterstaff carved from her grandmother's tree.│    │
│  └──────────────┘  └──────────────────────────────────────────────────────────┘    │
│                    [ Source: Custom              ]   [ Tags: party, druid          ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Attributes ──────────────────────────────────────────────────────────────────────┐
│  [ Source: Custom                ]   [ Class: Druid (Circle of the Land)        ▶ ] │
│  [ Race: Wood Elf              ▶ ]   [ Level: 3                                   ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

(rest of body follows §7.4.)
```

#### 7.7.2 Empty-state mockup

```
┌─ ▾ Attributes ──────────────────────────────────────────────────────────────────────┐
│  [ Source: e.g. PHB, MM, Custom ]   [ Class                                      ▶ ] │
│  [ Race                       ▶ ]   [ Level                                        ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.8 Spell

| Property | Value |
|---|---|
| Slug | `spell` |
| Badge color | `#7b1fa2` (purple). Badge fill `#7b1fa2 @ 15 %`. Badge label `#7b1fa2 @ 100 %`. |
| Capabilities | none — fields all ungrouped |
| Built-in groups | none (single "Properties" card) |
| Sections | mindmap |
| Filter keys | level, school, source |

All fields render in one ungrouped `_FeatureCard` whose header is the literal text `Properties` (12 px / w600 / `tabText`). Vertical stacking, one field per row.

| Field key | Label | Type | Validation / Notes |
|---|---|---|---|
| `source` | Source | `text` | placeholder `e.g. PHB, MM, Custom` |
| `level` | Level | `enum_` | `allowedValues: ['Cantrip', '1', '2', '3', '4', '5', '6', '7', '8', '9']` |
| `school` | School | `text` | typical values: Abjuration, Conjuration, Divination, Enchantment, Evocation, Illusion, Necromancy, Transmutation |
| `casting_time` | Casting Time | `text` | typical: "1 action", "1 bonus action", "1 reaction" |
| `range` | Range | `text` | typical: "60 ft", "Self", "Touch", "120 ft" |
| `duration` | Duration | `text` | typical: "Instantaneous", "1 minute", "Concentration, up to 10 minutes" |
| `components` | Components | `text` | typical: "V, S", "V, S, M (a pinch of salt)" |

#### 7.8.1 Sample-filled mockup ("Magic Missile")

```
┌─ Header ────────────────────────────────────────────────────────────────────────────┐
│  ┌──────────────┐  ┌─ Spell ─┐                                            ┌──────┐  │
│  │ glowing      │  │ Spell   │ ← purple badge                             │  📺  │  │
│  │ projectiles  │  └─────────┘                                            └──────┘  │
│  │ portrait     │  ╔══════════════════════════════════════════════════════════╗     │
│  │              │  ║ Magic Missile                                           ║     │
│  │              │  ╚══════════════════════════════════════════════════════════╝     │
│  │   1/1        │  Description                                                     │
│  │              │  ┌──────────────────────────────────────────────────────────┐    │
│  │              │  │ You create three glowing darts of magical force. Each    │    │
│  │              │  │ dart hits a creature of your choice for 1d4+1 force.     │    │
│  └──────────────┘  └──────────────────────────────────────────────────────────┘    │
│                    [ Source: PHB                 ]   [ Tags: arcane, force         ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties        ← 12 px w600 tabText                                             │
│  ↕ 8 px                                                                              │
│  [ Source: PHB                                                                    ] │
│  [ Level: 1                                                                       ▼ ] │
│  [ School: Evocation                                                              ] │
│  [ Casting Time: 1 action                                                         ] │
│  [ Range: 120 ft                                                                  ] │
│  [ Duration: Instantaneous                                                        ] │
│  [ Components: V, S                                                               ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

#### 7.8.2 Empty-state mockup

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: e.g. PHB, MM, Custom                                                   ] │
│  [ Level                                                                          ▼ ] │
│  [ School                                                                         ] │
│  [ Casting Time                                                                   ] │
│  [ Range                                                                          ] │
│  [ Duration                                                                       ] │
│  [ Components                                                                     ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

The Level dropdown shows the 10 options on tap: `Cantrip / 1 / 2 / 3 / 4 / 5 / 6 / 7 / 8 / 9`.

### 7.9 Equipment

| Property | Value |
|---|---|
| Slug | `equipment` |
| Badge color | `#795548` (brown) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |
| Filter keys | category, rarity, source |

| Field key | Label | Type | Validation / Notes |
|---|---|---|---|
| `source` | Source | `text` | placeholder `e.g. PHB, MM, Custom` |
| `category` | Category | `text` | typical: "Weapon", "Armor", "Tool", "Wondrous Item", "Potion" |
| `rarity` | Rarity | `text` | typical: "Common", "Uncommon", "Rare", "Very Rare", "Legendary", "Artifact" |
| `attunement` | Attunement | `text` | typical: "yes", "no", "by a wizard" |
| `cost` | Cost | `text` | typical: "15 gp", "1,500 gp" |
| `weight` | Weight | `text` | typical: "3 lb", "0.5 lb" |
| `damage_dice` | Damage Dice | `text` | typical: "1d8", "2d6+3" — note: stored as plain text in this category, *not* as a `dice` field |
| `damage_type` | Damage Type | `text` | typical: "slashing", "piercing", "fire" |
| `range` | Range | `text` | typical: "5 ft", "30/120" |
| `ac` | AC | `text` | typical: "16", "14 + Dex (max 2)" |
| `requirements` | Requirements | `text` | typical: "Str 13", "Proficiency with martial weapons" |
| `properties` | Properties | `text` | typical: "Versatile (1d10), Heavy" |

#### 7.9.1 Sample-filled mockup ("Longsword +1")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: DMG                                                                    ] │
│  [ Category: Weapon                                                               ] │
│  [ Rarity: Uncommon                                                               ] │
│  [ Attunement: no                                                                 ] │
│  [ Cost: 1,500 gp                                                                 ] │
│  [ Weight: 3 lb                                                                   ] │
│  [ Damage Dice: 1d8+1                                                             ] │
│  [ Damage Type: slashing                                                          ] │
│  [ Range: 5 ft                                                                    ] │
│  [ AC:                                                                            ] │
│  [ Requirements: Proficiency with martial weapons                                 ] │
│  [ Properties: Versatile (1d10+1)                                                 ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

#### 7.9.2 Empty-state mockup

Same shape; every field shows its label only with no value.

### 7.10 Class

| Property | Value |
|---|---|
| Slug | `class` |
| Badge color | `#1976d2` (blue) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |

| Field key | Label | Type | Validation / Notes |
|---|---|---|---|
| `source` | Source | `text` | — |
| `hit_die` | Hit Die | `text` | typical: "d6", "d8", "d10", "d12" |
| `main_stats` | Main Stats | `text` | typical: "Strength, Constitution" |
| `proficiencies` | Proficiencies | `text` | typical: "Light armor, simple weapons, martial weapons" |

#### 7.10.1 Sample-filled mockup ("Fighter")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: PHB                                                                    ] │
│  [ Hit Die: d10                                                                   ] │
│  [ Main Stats: Strength or Dexterity, Constitution                                ] │
│  [ Proficiencies: All armor, shields, simple weapons, martial weapons             ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.11 Race

| Property | Value |
|---|---|
| Slug | `race` |
| Badge color | `#00897b` (teal) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |

| Field key | Label | Type | Validation |
|---|---|---|---|
| `source` | Source | `text` | — |
| `speed` | Speed | `text` | typical: "30 ft" |
| `size` | Size | `enum_` | `allowedValues: ['Small', 'Medium', 'Large']` |
| `alignment` | Alignment | `text` | typical: "Chaotic Good", "Lawful Neutral" |
| `language` | Language | `text` | typical: "Common, Elvish" |

#### 7.11.1 Sample-filled mockup ("Half-Elf")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: PHB                                                                    ] │
│  [ Speed: 30 ft                                                                   ] │
│  [ Size: Medium                                                                   ▼ ] │
│  [ Alignment: usually Chaotic                                                     ] │
│  [ Language: Common, Elvish, plus one of your choice                              ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

The Size dropdown opens to show three options: `Small / Medium / Large`.

### 7.12 Location

| Property | Value |
|---|---|
| Slug | `location` |
| Badge color | `#2e7d32` (dark green) |
| Capabilities | none |
| Built-in groups | none |
| Sections | worldmap, mindmap |
| Filter keys | danger_level |

| Field key | Label | Type | Validation |
|---|---|---|---|
| `source` | Source | `text` | — |
| `danger_level` | Danger Level | `enum_` | `allowedValues: ['Safe', 'Low', 'Medium', 'High']` |
| `environment` | Environment | `text` | typical: "Urban", "Forest", "Dungeon", "Coastal" |

#### 7.12.1 Sample-filled mockup ("The Yawning Portal")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: SCAG                                                                   ] │
│  [ Danger Level: Low                                                              ▼ ] │
│  [ Environment: Urban tavern                                                      ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.13 Quest

| Property | Value |
|---|---|
| Slug | `quest` |
| Badge color | `#f57c00` (amber) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |
| Filter keys | status |

| Field key | Label | Type | Validation |
|---|---|---|---|
| `source` | Source | `text` | — |
| `status` | Status | `enum_` | `allowedValues: ['Not Started', 'Active', 'Completed']` |
| `giver` | Quest Giver | `text` | — |
| `reward` | Reward | `text` | typical: "500 gp + magic ring" |

#### 7.13.1 Sample-filled mockup ("The Lost Heirloom")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: Custom                                                                 ] │
│  [ Status: Active                                                                 ▼ ] │
│  [ Quest Giver: Mathilde the Cooper                                               ] │
│  [ Reward: 200 gp and a silver pendant                                            ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.14 Lore

| Property | Value |
|---|---|
| Slug | `lore` |
| Badge color | `#5c6bc0` (indigo) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |
| Filter keys | category |

| Field key | Label | Type | Validation |
|---|---|---|---|
| `source` | Source | `text` | — |
| `category` | Category | `enum_` | `allowedValues: ['History', 'Geography', 'Religion', 'Culture', 'Other']` |
| `secret_info` | Secret Info | `text` | DM-private content typically goes here, but the field itself uses `FieldVisibility.shared` by default — visibility can be tightened in the schema editor. |

#### 7.14.1 Sample-filled mockup ("The Founding of Neverwinter")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: SCAG                                                                   ] │
│  [ Category: History                                                              ▼ ] │
│  [ Secret Info: The Crown Prince's bloodline traces to the dragons of Mount Hotenow ]│
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.15 Status Effect

| Property | Value |
|---|---|
| Slug | `status-effect` |
| Badge color | `#e91e63` (pink) |
| Capabilities | none |
| Built-in groups | none |
| Sections | encounter |
| Filter keys | effect_type |

| Field key | Label | Type | Validation |
|---|---|---|---|
| `source` | Source | `text` | — |
| `duration_turns` | Duration (Turns) | `text` | typical: "10", "until end of next turn" |
| `effect_type` | Effect Type | `enum_` | `allowedValues: ['Buff', 'Debuff', 'Condition']` |
| `linked_condition` | Linked Condition | `relation` | `allowedTypes: ['condition']` — picks an entity from the Condition category |

#### 7.15.1 Sample-filled mockup ("Bless")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: PHB                                                                    ] │
│  [ Duration (Turns): 10                                                           ] │
│  [ Effect Type: Buff                                                              ▼ ] │
│  [ Linked Condition: (none)                                                       ▶ ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

The Linked Condition row opens an entity selector dialog (filtered to the Condition category) when tapped.

### 7.16 Feat

| Property | Value |
|---|---|
| Slug | `feat` |
| Badge color | `#ff7043` (light red) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |

| Field key | Label | Type |
|---|---|---|
| `source` | Source | `text` |
| `prerequisite` | Prerequisite | `text` |

#### 7.16.1 Sample-filled mockup ("Sentinel")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: PHB                                                                    ] │
│  [ Prerequisite: —                                                                ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.17 Background

| Property | Value |
|---|---|
| Slug | `background` |
| Badge color | `#8d6e63` (warm gray) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |

| Field key | Label | Type |
|---|---|---|
| `source` | Source | `text` |
| `skill_proficiencies` | Skill Proficiencies | `text` |
| `tool_proficiencies` | Tool Proficiencies | `text` |
| `languages` | Languages | `text` |
| `equipment` | Equipment | `text` |

#### 7.17.1 Sample-filled mockup ("Acolyte")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: PHB                                                                    ] │
│  [ Skill Proficiencies: Insight, Religion                                         ] │
│  [ Tool Proficiencies:                                                            ] │
│  [ Languages: two of your choice                                                  ] │
│  [ Equipment: holy symbol, prayer book, 5 sticks of incense, vestments, common    ] │
│              clothes, pouch with 15 gp                                              │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.18 Plane

| Property | Value |
|---|---|
| Slug | `plane` |
| Badge color | `#26c6da` (cyan) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap, worldmap |

| Field key | Label | Type |
|---|---|---|
| `source` | Source | `text` |
| `type` | Type | `text` |

#### 7.18.1 Sample-filled mockup ("The Feywild")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: DMG                                                                    ] │
│  [ Type: Inner Plane (Mirror Plane)                                               ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.19 Condition

| Property | Value |
|---|---|
| Slug | `condition` |
| Badge color | `#ab47bc` (violet) |
| Capabilities | `hasConditionStats` |
| Built-in groups | Condition Stats |
| Sections | encounter |

This is the only category with `hasConditionStats: true`. The body has two regions: the ungrouped "Properties" `_FeatureCard` (for `source` and `effects`), then the `Condition Stats` `_CollapsibleGroupCard` containing the `condition_stats` `conditionStats` field.

| Field key | Label | Type | Group | Span | Notes |
|---|---|---|---|---|---|
| `source` | Source | `text` | — (Properties) | 1 | placeholder `e.g. PHB, MM, Custom` |
| `effects` | Effects | `text` | — (Properties) | 1 | a one-line summary; the longer narrative goes in `condition_stats.effect` |
| `condition_stats` | Condition Stats | `conditionStats` | Condition Stats | 2 | sub-fields `default_duration` (integer), `effect` (textarea, markdown + @mention) |

The `conditionStats` field uses the same `_CombatStatsFieldWidget` shell as `combatStats`, but with two sub-fields. The `default_duration` sub-field renders as a numeric input in the responsive grid; the `effect` sub-field is `textarea`-typed, so it renders full-width below the grid as a `MarkdownTextArea` with hint `@ to mention entities`, body 13 px / `htmlText`, label 12 px / w600 / `tabText` shown above the editor.

#### 7.19.1 Sample-filled mockup ("Poisoned")

```
┌─ Header ────────────────────────────────────────────────────────────────────────────┐
│  ┌──────────────┐  ┌─ Condition ─┐                                        ┌──────┐  │
│  │ skull        │  │ Condition   │ ← violet badge                         │  📺  │  │
│  │ portrait     │  └─────────────┘                                        └──────┘  │
│  │              │  ╔══════════════════════════════════════════════════════════╗     │
│  │              │  ║ Poisoned                                                ║     │
│  │              │  ╚══════════════════════════════════════════════════════════╝     │
│  │   1/1        │  Description                                                     │
│  │              │  ┌──────────────────────────────────────────────────────────┐    │
│  │              │  │ The creature is sickened. Negative effects on attacks    │    │
│  └──────────────┘  │ and ability checks while the condition lasts.            │    │
│                    └──────────────────────────────────────────────────────────┘    │
│                    [ Source: PHB                 ]   [ Tags: condition, debuff   ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: PHB                                                                    ] │
│  [ Effects: Disadvantage on attack rolls and ability checks                       ] │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Condition Stats ─────────────────────────────────────────────────────────────────┐
│  ┌─ Card (condition_stats) ──────────────────────────────────────────────────────┐  │
│  │ Condition Stats                                                                │  │
│  │ ↕ 8 px                                                                         │  │
│  │ ┌───────────────────────────────┐                                              │  │
│  │ │ Default Duration (turns)      │   ← only one grid sub-field (the integer    │  │
│  │ │ [ 10                       ]  │     one); textarea sub-field renders below  │  │
│  │ └───────────────────────────────┘                                              │  │
│  │                                                                                │  │
│  │ Effect       ← 12 px w600 tabText                                              │  │
│  │ ↕ 4 px                                                                         │  │
│  │ ┌──────────────────────────────────────────────────────────────────────────┐    │  │
│  │ │ The creature has disadvantage on attack rolls and ability checks. A      │    │  │
│  │ │ poisoned creature can repeat the saving throw at the end of each of its  │    │  │
│  │ │ turns, ending the condition on itself on success.                        │    │  │
│  │ └──────────────────────────────────────────────────────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

#### 7.19.2 Empty-state mockup

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: e.g. PHB, MM, Custom ]                                                    │
│  [ Effects                       ]                                                    │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ ▾ Condition Stats ─────────────────────────────────────────────────────────────────┐
│  ┌ Condition Stats ──────────────────────────────────────────────────────────────┐   │
│  │ [ Default Duration (turns): 0 ]                                               │   │
│  │ Effect                                                                         │   │
│  │ [ @ to mention entities                                                     ] │   │
│  └───────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.20 Trait

| Property | Value |
|---|---|
| Slug | `trait` |
| Badge color | `#78909c` (gray) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |

| Field key | Label | Type |
|---|---|---|
| `source` | Source | `text` |
| `usage` | Usage | `text` — typical: "Passive", "1/short rest", "1/long rest", "1/day" |

#### 7.20.1 Sample-filled mockup ("Pack Tactics")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: MM                                                                     ] │
│  [ Usage: Passive                                                                 ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.21 Action

| Property | Value |
|---|---|
| Slug | `action` |
| Badge color | `#ef6c00` (deep orange) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |

| Field key | Label | Type | Validation / Notes |
|---|---|---|---|
| `source` | Source | `text` | — |
| `attack_bonus` | Attack Bonus | `dice` | parses standard dice notation; widget shows `Icons.casino` 🎲 prefix and hint `e.g. 2d6+3` |
| `damage_dice` | Damage Dice | `dice` | same chrome as `attack_bonus` |
| `damage_type` | Damage Type | `text` | typical: "slashing", "piercing", "bludgeoning", "fire", "force" |

The `dice` field renders identically to a `text` field, except for the `Icons.casino` prefix glyph (16 px, neutral color) inside the `InputDecoration.prefixIcon` slot. The hint text is always `e.g. 2d6+3` — the schema's `placeholder` is overridden by the dice widget.

#### 7.21.1 Sample-filled mockup ("Greatsword Strike")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: MM                                                                     ] │
│  [ 🎲 Attack Bonus: +5                                                            ] │
│  [ 🎲 Damage Dice:  2d6+3                                                         ] │
│  [ Damage Type: slashing                                                          ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

#### 7.21.2 Empty-state mockup

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: e.g. PHB, MM, Custom ]                                                    │
│  [ 🎲 Attack Bonus: e.g. 2d6+3 ]                                                     │
│  [ 🎲 Damage Dice:  e.g. 2d6+3 ]                                                     │
│  [ Damage Type:                  ]                                                    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.22 Reaction

| Property | Value |
|---|---|
| Slug | `reaction` |
| Badge color | `#5e35b1` (deep purple) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |

| Field key | Label | Type |
|---|---|---|
| `source` | Source | `text` |
| `trigger` | Trigger | `text` — typical: "When a creature you can see attacks a target other than you within 5 feet of you" |

#### 7.22.1 Sample-filled mockup ("Opportunity Attack")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: PHB                                                                    ] │
│  [ Trigger: When a creature within reach moves out of your reach                  ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.23 Legendary Action

| Property | Value |
|---|---|
| Slug | `legendary-action` |
| Badge color | `#ffd600` (yellow) |
| Capabilities | none |
| Built-in groups | none |
| Sections | mindmap |

| Field key | Label | Type | Validation |
|---|---|---|---|
| `source` | Source | `text` | — |
| `cost` | Cost | `enum_` | `allowedValues: ['1', '2', '3']` |

#### 7.23.1 Sample-filled mockup ("Tail Sweep")

```
┌─ Properties ────────────────────────────────────────────────────────────────────────┐
│  Properties                                                                          │
│  [ Source: MM                                                                     ] │
│  [ Cost: 2                                                                        ▼ ] │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

The Cost dropdown shows three options: `1 / 2 / 3`.

### 7.24 D&D 5e constants used by the card

These constants are referenced by the Ability Scores, Combat Stats, Saving Throws, and Skills field widgets. They are part of the universal card design — every category that has `hasStatBlock: true` shares the same numeric tables and modifier formulas.

```dart
const kDnd5eAbilities = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

int proficiencyBonusForLevel(int level) {
  if (level <= 0) return 2;
  if (level >= 17) return 6;
  if (level >= 13) return 5;
  if (level >= 9)  return 4;
  if (level >= 5)  return 3;
  return 2;
}

int abilityModifier(int score) {
  final diff = score - 10;
  return (diff < 0 && diff.isOdd) ? (diff ~/ 2) - 1 : diff ~/ 2;
}
```

| Level range | Proficiency bonus |
|---|---|
| 1–4 | +2 |
| 5–8 | +3 |
| 9–12 | +4 |
| 13–16 | +5 |
| 17–20 | +6 |

The 18 standard skills and their ability mappings:

| Skill | Ability | | Skill | Ability |
|---|---|---|---|---|
| Acrobatics | DEX | | Medicine | WIS |
| Animal Handling | WIS | | Nature | INT |
| Arcana | INT | | Perception | WIS |
| Athletics | STR | | Performance | CHA |
| Deception | CHA | | Persuasion | CHA |
| History | INT | | Religion | INT |
| Insight | WIS | | Sleight of Hand | DEX |
| Intimidation | CHA | | Stealth | DEX |
| Investigation | INT | | Survival | WIS |

The 6 saving throws: Strength (STR), Dexterity (DEX), Constitution (CON), Intelligence (INT), Wisdom (WIS), Charisma (CHA).

`proficiencyTableDefault` builds the default value map used by every saving-throw and skill field:

```dart
Map<String, dynamic> proficiencyTableDefault(List<ProficiencyRowPreset> preset) {
  return {
    'rows': preset.map((p) => {
      'name': p.name,
      'ability': p.ability,
      'proficient': false,
      'expertise': false,
      'misc': 0,
    }).toList(),
  };
}
```

---

## 8. Spacing, Typography & Color Tokens

This section lists only what the entity card itself uses.

### 8.1 Spacing constants

| Value | Where it appears |
|---|---|
| 16 | Outer scroll padding; `SizedBox` above the delete button (edit mode). |
| 12 | Internal padding of every `_FeatureCard` and `_CollapsibleGroupCard` body; collapsible group header horizontal padding; portrait-row `SizedBox(width: 12)` between gallery and right column. |
| 10 | Header-card vertical gaps (between badge row and name, between name and description label, between description and source/tags row); collapsible group header vertical padding; counter pill border radius. |
| 8 | Inter-block spacing (between header / schema body / DM notes); inter-group spacing inside the schema body; gutter between the source and tags fields; gutter between fields in the responsive grid; gap between section title and its first child in `Properties` and `combatStats`. |
| 6 | Gap inside DM Notes between header row and editor; counter-pill horizontal padding. |
| 4 | Vertical padding of every leaf field widget; category badge radius; DM notes radius; `_FeatureCard` radius; collapsible group radius; counter-pill vertical padding; gap between description label and editor; gap between chevron and group title. |
| 3 | Category badge vertical padding. |
| 2 | Counter-pill vertical padding (within container); minor `SizedBox`es in `statBlock` between score input and modifier label. |

### 8.2 Border radii used on the card

| Value | Where |
|---|---|
| `cardBorderRadius` (theme-driven; commonly 8 px, 2 px in serif themes) | `_PortraitGallery` container only. |
| 4 px (hardcoded) | `_FeatureCard`, `_CollapsibleGroupCard`, DM Notes block, category badge, header `InkWell` (top corners only). |
| 10 px (hardcoded) | Image counter pill. |

The portrait gallery is the **only** part of the card that participates in the theme's radius scale. Every other surface uses a tight 4 px corner regardless of theme.

### 8.3 Typography used on the card

The card sets text styles inline — no `TextTheme` overrides. Sizes used:

| Size | Weight | Color | Used for |
|---|---|---|---|
| 18 | bold | `tabActiveText` | Entity name. |
| 16 | bold | inherited | `statBlock` ability score input. |
| 13 | regular | `htmlText` | Description body, DM notes body, markdown body in `combatStats` textareas. |
| 12 | w600 | `tabText` | "Properties" header; group title in `_CollapsibleGroupCard`; section title in `combatStats` / `conditionStats`; sub-field label above textarea sub-fields. |
| 12 | w600 | `dmNoteTitle` | "DM Notes" header. |
| 12 | regular | `htmlText` | Source / Tags input text. |
| 11 | w600 | `catColor` | Category badge label. |
| 11 | regular | `tabText` | "Description" label above the body. |
| 11 | bold | inherited | `statBlock` ability key (STR/DEX/…). |
| 11 | regular | `colorScheme.outline` | `statBlock` ability modifier. |
| 10 | regular | `sidebarLabelSecondary` | "No Image" caption inside the placeholder. |
| 10 | italic | `sidebarLabelSecondary` | Computed-field formula badge (`Auto-filled by rule`). |
| 9 | regular | `Colors.white70` | Image counter pill. |

No custom font is loaded; the card inherits whatever `ThemeData.fontFamily` the active theme sets (system default sans-serif, or `Georgia` for serif themes). The card never names a `fontFamily` directly.

### 8.4 `DmToolColors` tokens consumed by the card

Every token below is read from `Theme.of(context).extension<DmToolColors>()!`.

| Token | Used for |
|---|---|
| `featureCardBg` | Background of header card, ungrouped "Properties" card, collapsible group body, DM notes container, portrait placeholder. |
| `featureCardBorder` | Portrait gallery border. |
| `tabActiveText` | Entity name color. |
| `tabText` | Description label, source/tags labels, "Properties" header, group title, chevron color, `combatStats` textarea sub-field label. |
| `htmlText` | Description body, DM notes body, source/tags field body, `combatStats` textarea body. |
| `sidebarLabelSecondary` | Placeholder icon (40 % alpha), "No Image" caption, computed-formula text, DM notes hint color. |
| `dmNoteBorder` | DM Notes container border. |
| `dmNoteTitle` | Lock icon and "DM Notes" header text. |
| `dangerBtnBg` | Delete button background; portrait remove icon color. |
| `dangerBtnText` | Delete button label. |
| `cardBorderRadius` | Portrait gallery radius (only). |
| `tabIndicator` | Fallback when `EntityCategorySchema.color` is missing. |

Plus `catColor` — derived per-entity from `EntityCategorySchema.color` (a hex string parsed to `Color`). Used for both the badge fill (15 % alpha) and the badge label.

---

## 9. Lifecycle & State Management

### 9.1 Per-entity Riverpod selector

The card watches **only** its target entity, not the whole entity map, so unrelated edits do not rebuild it:

```dart
final entity = ref.watch(
  entityProvider.select((map) => map[widget.entityId]),
);
if (entity == null) {
  return const Center(child: Text('Entity not found'));
}
```

### 9.2 Debounced provider updates

Every text input on the card (name, description, source, tags, DM notes, schema-driven text fields) writes through `_debouncedProviderUpdate`, which collapses bursts of edits into a single `entityProvider.notifier.update(...)` call after 300 ms of inactivity:

```dart
Timer? _updateTimer;

void _debouncedProviderUpdate(Entity Function() entityBuilder) {
  _updateTimer?.cancel();
  _updateTimer = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    ref.read(entityProvider.notifier).update(entityBuilder());
  });
}
```

### 9.3 Dispose-time flush

If the user navigates away mid-typing, the pending debounce timer is cancelled and the in-flight controller values are flushed synchronously to the provider so nothing is lost:

```dart
void _flushPendingUpdate() {
  if (_updateTimer?.isActive ?? false) {
    _updateTimer!.cancel();
    final entity = ref.read(entityProvider)[widget.entityId];
    if (entity == null) return;
    ref.read(entityProvider.notifier).update(entity.copyWith(
      name: _nameController.text,
      description: _descController.text,
      source: _sourceController.text,
      dmNotes: _dmNotesController.text,
      tags: _tagsController.text.split(',').map((t) => t.trim())
          .where((t) => t.isNotEmpty).toList(),
    ));
  }
}
```

### 9.4 Focus-aware controller sync

When the provider changes externally (e.g. another client edited the same entity online), controllers must be re-synced — but only when the field is *not* focused, otherwise an external update would overwrite the current keystroke position:

```dart
void _syncIfNotFocused(TextEditingController ctrl, FocusNode focus, String newValue) {
  if (!focus.hasFocus && ctrl.text != newValue) {
    ctrl.text = newValue;
  }
}
```

### 9.5 Schema-driven field updates

`_updateField` is the path used by every `FieldWidgetFactory.create(...)` `onChanged` callback. It is also debounced:

```dart
void _updateField(String fieldKey, dynamic value) {
  _debouncedProviderUpdate(() {
    final entity = ref.read(entityProvider)[widget.entityId];
    if (entity == null) return entity!; // guarded by the build-time entity check
    final newFields = Map<String, dynamic>.from(entity.fields);
    newFields[fieldKey] = value;
    return entity.copyWith(fields: newFields);
  });
}
```

---

## 10. Code Sample Appendix

Five copy-paste blocks. Use these as the starting point when building a parallel surface that needs to look identical to the entity card.

### 10.1 Outer scaffold + header card

```dart
return SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // === HEADER: portrait (left) + name/description (right) ===
      _FeatureCard(
        palette: palette,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PortraitGallery(
              images: [
                if (entity.imagePath.isNotEmpty) entity.imagePath,
                ...entity.images,
              ],
              entityName: entity.name,
              readOnly: widget.readOnly,
              palette: palette,
              onImagesChanged: (newImages) {
                ref.read(entityProvider.notifier).update(
                  entity.copyWith(imagePath: '', images: newImages),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cat?.name ?? entity.categorySlug,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Project entity card to player screen',
                      icon: const Icon(Icons.cast, size: 16),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      onPressed: () { /* projectionControllerProvider.addEntityCard(...) */ },
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    readOnly: widget.readOnly,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: palette.tabActiveText),
                    decoration: InputDecoration(
                      hintText: 'Entity Name',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => _debouncedProviderUpdate(
                      () => ref.read(entityProvider)[widget.entityId]!.copyWith(name: v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Description', style: TextStyle(fontSize: 11, color: palette.tabText)),
                  const SizedBox(height: 4),
                  MarkdownTextArea(
                    controller: _descController,
                    focusNode: _descFocus,
                    readOnly: widget.readOnly,
                    minLines: widget.readOnly ? null : 3,
                    textStyle: TextStyle(fontSize: 13, color: palette.htmlText),
                    decoration: InputDecoration(
                      hintText: 'Markdown supported... (@ to mention)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => _debouncedProviderUpdate(
                      () => ref.read(entityProvider)[widget.entityId]!.copyWith(description: v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextFormField( /* Source */ )),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField( /* Tags */ )),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (cat != null) ..._buildSchemaFields(entity, cat, palette, computedValues, const {}, const {}),
      const SizedBox(height: 8),
      // DM Notes block …
      // Delete button (edit mode) …
    ],
  ),
);
```

### 10.2 Schema-driven group rendering

```dart
List<Widget> _buildSchemaFields(Entity entity, EntityCategorySchema cat, DmToolColors palette,
    Map<String, dynamic> computed, Map<String, ItemStyle> itemStyles,
    Map<String, String> equipGates) {
  final allFields = cat.fields
      .where((f) => f.visibility != FieldVisibility.private_)
      .toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  final ungrouped = allFields.where((f) => f.groupId == null).toList();

  final grouped = <String, List<FieldSchema>>{};
  for (final f in allFields) {
    if (f.groupId != null) (grouped[f.groupId!] ??= []).add(f);
  }

  final sortedGroups = cat.fieldGroups.toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  final widgets = <Widget>[];

  if (ungrouped.isNotEmpty) {
    widgets.add(_FeatureCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: palette.tabText)),
          const SizedBox(height: 8),
          ...ungrouped.map((f) => _buildFieldWidget(f, entity, computed, palette,
              itemStyles: itemStyles, equipGates: equipGates)),
        ],
      ),
    ));
  }

  for (final group in sortedGroups) {
    final groupFields = grouped[group.groupId];
    if (groupFields == null || groupFields.isEmpty) continue;
    if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
    widgets.add(_CollapsibleGroupCard(
      group: group,
      palette: palette,
      child: _buildGroupGrid(groupFields, group.gridColumns, entity, computed, palette,
          itemStyles: itemStyles, equipGates: equipGates),
    ));
  }

  return widgets;
}
```

### 10.3 Responsive grid algorithm

```dart
Widget _buildGroupGrid(List<FieldSchema> fields, int gridColumns, Entity entity,
    Map<String, dynamic> computed, DmToolColors palette,
    {Map<String, ItemStyle> itemStyles = const {},
     Map<String, String> equipGates = const {}}) {
  if (gridColumns <= 1) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.map((f) => _buildFieldWidget(
        f, entity, computed, palette,
        itemStyles: itemStyles, equipGates: equipGates,
      )).toList(),
    );
  }

  // Pack fields into rows, respecting each field's gridColumnSpan.
  final rows = <List<FieldSchema>>[];
  var colsUsed = 0;
  var currentRow = <FieldSchema>[];
  for (final field in fields) {
    final span = field.gridColumnSpan.clamp(1, gridColumns);
    if (colsUsed + span > gridColumns && currentRow.isNotEmpty) {
      rows.add(currentRow);
      currentRow = [];
      colsUsed = 0;
    }
    currentRow.add(field);
    colsUsed += span;
  }
  if (currentRow.isNotEmpty) rows.add(currentRow);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: rows.map((rowFields) {
      final children = <Widget>[];
      for (var i = 0; i < rowFields.length; i++) {
        if (i > 0) children.add(const SizedBox(width: 8));
        final span = rowFields[i].gridColumnSpan.clamp(1, gridColumns);
        children.add(Expanded(
          flex: span,
          child: _buildFieldWidget(rowFields[i], entity, computed, palette,
              itemStyles: itemStyles, equipGates: equipGates),
        ));
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }).toList(),
  );
}
```

### 10.4 Computed-field badge wrapper

```dart
Widget _buildFieldWidget(FieldSchema field, Entity entity, Map<String, dynamic> computed,
    DmToolColors palette,
    {Map<String, ItemStyle> itemStyles = const {},
     Map<String, String> equipGates = const {}}) {
  final hasComputed = computed.containsKey(field.fieldKey);
  final fieldValue = hasComputed ? computed[field.fieldKey] : entity.fields[field.fieldKey];
  final formula = hasComputed && !widget.readOnly ? _formulaFor(field.fieldKey) : null;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldWidgetFactory.create(
        schema: field,
        value: fieldValue,
        readOnly: hasComputed && !(field.isList && field.fieldType == FieldType.relation)
            ? true : widget.readOnly,
        onChanged: (v) => _updateField(field.fieldKey, v),
        entities: ref.read(entityProvider),
        ref: ref,
        computedMode: hasComputed,
        itemStyles: itemStyles,
        equipGates: equipGates,
        entityFields: entity.fields,
      ),
      if (hasComputed)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: Row(children: [
            Icon(Icons.auto_fix_high, size: 12, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 4),
            Expanded(child: Text(
              formula != null ? '= $formula' : 'Auto-filled by rule',
              style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary,
                  fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        ),
    ],
  );
}
```

### 10.5 Portrait gallery container + nav controls

```dart
Container(
  width: 200,
  height: 260,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(widget.palette.cardBorderRadius),
    border: Border.all(color: widget.palette.featureCardBorder),
  ),
  clipBehavior: Clip.antiAlias,
  child: Stack(
    fit: StackFit.expand,
    children: [
      widget.images.isNotEmpty
          ? _buildImage(widget.images[_currentIndex])
          : _buildPlaceholder(),

      if (_hovered && !(Platform.isAndroid || Platform.isIOS) && widget.images.isNotEmpty)
        Container(color: Colors.black.withValues(alpha: 0.08)),

      // Left nav arrow
      if (_showControls && widget.images.length > 1 && _currentIndex > 0)
        Positioned(
          left: 4, top: 0, bottom: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex--),
              child: Container(
                width: 26, height: 26,
                decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),

      // Right nav arrow
      if (_showControls && widget.images.length > 1 && _currentIndex < widget.images.length - 1)
        Positioned(
          right: 4, top: 0, bottom: 0,
          child: Center( /* mirrored Icons.chevron_right */ ),
        ),

      // Counter pill
      if (widget.images.length > 1)
        Positioned(
          bottom: 6, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.images.length}',
                style: const TextStyle(fontSize: 9, color: Colors.white70),
              ),
            ),
          ),
        ),

      // Add button (edit mode) — top-right
      if (!widget.readOnly && _showControls)
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 26, height: 26,
              decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
              child: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 14),
            ),
          ),
        ),

      // Remove button (edit mode) — top-left
      if (!widget.readOnly && _showControls && widget.images.isNotEmpty)
        Positioned(
          top: 4, left: 4,
          child: GestureDetector(
            onTap: _removeCurrentImage,
            child: Container(
              width: 26, height: 26,
              decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
              child: Icon(Icons.close, color: widget.palette.dangerBtnBg, size: 14),
            ),
          ),
        ),
    ],
  ),
)
```
