import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../dialogs/entity_selector_dialog.dart';

/// Typed structured-list editors for the remaining (non-rule) list FieldTypes:
///   - classFeatures
///   - rangedSenseList
///   - equipmentChoiceGroups
///   - subspeciesOptions
///
/// The rule-authoring editors (spellEffectList, grantedModifiers,
/// featEffectList, autoGrantSources, prereqClauses) were removed in the
/// template-system migration (Phase 1.1): rules now live in the template,
/// not on entity cards.
///
/// All editors share the [_StructuredListShell] (Card + add button + per-row
/// removal) and operate on `List<Map<String, dynamic>>`. Each row is rendered
/// by a per-FieldType row builder.

// ─────────────────────────────────────────────────────────────────────────
// Shared shell
// ─────────────────────────────────────────────────────────────────────────

class _StructuredListShell extends StatelessWidget {
  final FieldSchema schema;
  final List<Map<String, dynamic>> rows;
  final bool readOnly;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final Map<String, dynamic> Function() makeEmptyRow;
  final Widget Function(int index, Map<String, dynamic> row, ValueChanged<Map<String, dynamic>> onRowChanged) buildRow;
  final List<Widget>? headerActions;

  const _StructuredListShell({
    required this.schema,
    required this.rows,
    required this.readOnly,
    required this.onChanged,
    required this.makeEmptyRow,
    required this.buildRow,
    this.headerActions,
  });

  void _addRow() {
    final updated = [...rows, makeEmptyRow()];
    onChanged(updated);
  }

  void _removeRow(int i) {
    final updated = [...rows]..removeAt(i);
    onChanged(updated);
  }

  void _updateRow(int i, Map<String, dynamic> row) {
    final updated = [...rows];
    updated[i] = row;
    onChanged(updated);
  }

  void _reorder(int oldIndex, int newIndex) {
    final updated = [...rows];
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = updated.removeAt(oldIndex);
    updated.insert(adjusted, item);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${schema.label} (${rows.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  schema.fieldType.name,
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                ),
                if (!readOnly && headerActions != null) ...headerActions!,
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: 'Add entry',
                    onPressed: _addRow,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No entries',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                ),
              ),
            if (rows.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: rows.length,
                onReorder: readOnly ? (a, b) {} : _reorder,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  return Padding(
                    key: ValueKey('${schema.fieldKey}_row_$i'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!readOnly)
                          ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.drag_handle,
                                size: 16,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${i + 1}.',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: buildRow(i, row, (r) => _updateRow(i, r)),
                        ),
                        if (!readOnly)
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            tooltip: 'Remove',
                            onPressed: () => _removeRow(i),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _coerceRows(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────
// Common micro-inputs
// ─────────────────────────────────────────────────────────────────────────

Widget _miniText({
  required String label,
  required String value,
  required bool readOnly,
  required ValueChanged<String> onChanged,
  double width = 120,
  TextInputType? keyboardType,
}) {
  return SizedBox(
    width: width,
    child: TextFormField(
      initialValue: value,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 12),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        labelStyle: const TextStyle(fontSize: 11),
      ),
      onChanged: onChanged,
    ),
  );
}

Widget _miniInt({
  required String label,
  required int? value,
  required bool readOnly,
  required ValueChanged<int?> onChanged,
  double width = 80,
}) {
  return SizedBox(
    width: width,
    child: TextFormField(
      initialValue: value?.toString() ?? '',
      readOnly: readOnly,
      style: const TextStyle(fontSize: 12),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        labelStyle: const TextStyle(fontSize: 11),
      ),
      onChanged: (s) => onChanged(int.tryParse(s.trim())),
    ),
  );
}

class _MiniRelationField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> allowedTypes;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool readOnly;
  final ValueChanged<String?> onChanged;

  const _MiniRelationField({
    required this.label,
    required this.value,
    required this.allowedTypes,
    required this.entities,
    required this.ref,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    final displayName = hasValue ? (entities?[value!]?.name ?? value!) : '—';
    return SizedBox(
      width: 200,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: hasValue ? null : Theme.of(context).colorScheme.outline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!readOnly && hasValue)
              InkWell(
                onTap: () => onChanged(null),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 12),
                ),
              ),
            if (!readOnly)
              InkWell(
                onTap: () async {
                  if (ref == null) return;
                  final result = await showEntitySelectorDialog(
                    context: context,
                    ref: ref!,
                    allowedTypes: allowedTypes,
                    includeBuiltinSrd: true,
                  );
                  if (result != null && result.isNotEmpty) {
                    onChanged(result.first);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.search, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniRelationListField extends StatelessWidget {
  final String label;
  final List<String> values;
  final List<String> allowedTypes;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool readOnly;
  final ValueChanged<List<String>> onChanged;

  const _MiniRelationListField({
    required this.label,
    required this.values,
    required this.allowedTypes,
    required this.entities,
    required this.ref,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label (${values.length})',
          isDense: true,
          labelStyle: const TextStyle(fontSize: 11),
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final id in values)
              Chip(
                label: Text(
                  entities?[id]?.name ?? id,
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onDeleted: readOnly
                    ? null
                    : () => onChanged([...values]..remove(id)),
              ),
            if (!readOnly)
              InkWell(
                onTap: () async {
                  if (ref == null) return;
                  final result = await showEntitySelectorDialog(
                    context: context,
                    ref: ref!,
                    allowedTypes: allowedTypes,
                    multiSelect: true,
                    includeBuiltinSrd: true,
                  );
                  if (result != null && result.isNotEmpty) {
                    final merged = {...values, ...result}.toList();
                    onChanged(merged);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 1. rangedSenseList — {sense_ref, range_ft}
// ─────────────────────────────────────────────────────────────────────────

class RangedSenseListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const RangedSenseListFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _coerceRows(value);
    return _StructuredListShell(
      schema: schema,
      rows: rows,
      readOnly: readOnly,
      onChanged: onChanged,
      makeEmptyRow: () => {'sense_ref': null, 'range_ft': null},
      buildRow: (i, row, onRowChanged) {
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MiniRelationField(
              label: 'Sense',
              value: row['sense_ref'] as String?,
              allowedTypes: const ['sense'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'sense_ref': v}),
            ),
            _miniInt(
              label: 'Range (ft)',
              value: row['range_ft'] is int ? row['range_ft'] as int : null,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'range_ft': v}),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 2. classFeatures — {level, description}
// ─────────────────────────────────────────────────────────────────────────

class ClassFeaturesFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  /// Sibling fields of the entity hosting this widget — used to surface
  /// validation hints (e.g. subclass feature row level < `granted_at_level`).
  final Map<String, dynamic>? entityFields;

  const ClassFeaturesFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
    this.entityFields,
  });

  static List<String> _readStrList(Map row, String key) {
    final v = row[key];
    if (v is List) return v.whereType<String>().toList();
    return const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _coerceRows(value);
    // Subclass gating hint: `granted_at_level` is declared on subclass
    // entities only. Class entities don't carry it so the warning never
    // fires there. Pulls the value off the hosting entity's siblings.
    final grantedAtLevelRaw = entityFields?['granted_at_level'];
    final int? grantedAtLevel =
        grantedAtLevelRaw is int ? grantedAtLevelRaw : null;
    return _StructuredListShell(
      schema: schema,
      rows: rows,
      readOnly: readOnly,
      onChanged: onChanged,
      makeEmptyRow: () => {
        'level': null,
        'description': '',
        'granted_damage_resistances': <String>[],
        'granted_damage_immunities': <String>[],
        'granted_condition_immunities': <String>[],
        'granted_senses': <String>[],
        'granted_languages': <String>[],
        'granted_feat_refs': <String>[],
        'granted_trait_refs': <String>[],
        'granted_action_refs': <String>[],
        'granted_bonus_action_refs': <String>[],
        'granted_reaction_refs': <String>[],
      },
      buildRow: (i, row, onRowChanged) {
        final rowLvl = row['level'] is int ? row['level'] as int : null;
        final gateMiss = grantedAtLevel != null &&
            rowLvl != null &&
            rowLvl < grantedAtLevel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _miniInt(
                  label: 'Level',
                  value: rowLvl,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'level': v}),
                  width: 60,
                ),
                _miniText(
                  label: 'Summary',
                  value: (row['description'] ?? '').toString(),
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'description': v}),
                  width: 480,
                ),
                if (gateMiss)
                  Tooltip(
                    message:
                        'Row level $rowLvl is below subclass granted_at_level '
                        '$grantedAtLevel — resolver will skip this feature.',
                    child: const Icon(Icons.warning_amber,
                        size: 16, color: Colors.orange),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _MiniRelationListField(
                  label: 'Resistances',
                  values: _readStrList(row, 'granted_damage_resistances'),
                  allowedTypes: const ['damage-type'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged(
                      {...row, 'granted_damage_resistances': v}),
                ),
                _MiniRelationListField(
                  label: 'Immunities',
                  values: _readStrList(row, 'granted_damage_immunities'),
                  allowedTypes: const ['damage-type'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged(
                      {...row, 'granted_damage_immunities': v}),
                ),
                _MiniRelationListField(
                  label: 'Condition Imm.',
                  values: _readStrList(row, 'granted_condition_immunities'),
                  allowedTypes: const ['condition'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged(
                      {...row, 'granted_condition_immunities': v}),
                ),
                _MiniRelationListField(
                  label: 'Senses',
                  values: _readStrList(row, 'granted_senses'),
                  allowedTypes: const ['sense'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_senses': v}),
                ),
                _MiniRelationListField(
                  label: 'Languages',
                  values: _readStrList(row, 'granted_languages'),
                  allowedTypes: const ['language'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_languages': v}),
                ),
                _MiniRelationListField(
                  label: 'Feats',
                  values: _readStrList(row, 'granted_feat_refs'),
                  allowedTypes: const ['feat'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_feat_refs': v}),
                ),
                _MiniRelationListField(
                  label: 'Traits',
                  values: _readStrList(row, 'granted_trait_refs'),
                  allowedTypes: const ['trait'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_trait_refs': v}),
                ),
                _MiniRelationListField(
                  label: 'Actions',
                  values: _readStrList(row, 'granted_action_refs'),
                  allowedTypes: const ['creature-action'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_action_refs': v}),
                ),
                _MiniRelationListField(
                  label: 'Bonus Actions',
                  values: _readStrList(row, 'granted_bonus_action_refs'),
                  allowedTypes: const ['creature-action'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_bonus_action_refs': v}),
                ),
                _MiniRelationListField(
                  label: 'Reactions',
                  values: _readStrList(row, 'granted_reaction_refs'),
                  allowedTypes: const ['creature-action'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_reaction_refs': v}),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 5. equipmentChoiceGroups — editable structured display.
// Shape: List<{group_id, label, prompt, options:[{option_id, label,
//   items:[{ref, quantity}], gold_gp?}]}>
// Authoring + read-only share this widget; in read-only mode the add/remove
// affordances are hidden and inputs go disabled. The pickers reuse
// `_MiniRelationField` so item refs go through `showEntitySelectorDialog`
// just like every other relation field. Item-pickable categories match the
// `default_inventory_refs` schema declaration so the dialog presents the
// same item universe to authors and the runtime resolver.
// ─────────────────────────────────────────────────────────────────────────

const _kItemPickAllowedTypes = <String>[
  'adventuring-gear',
  'weapon',
  'armor',
  'tool',
  'pack',
  'ammunition',
];

class EquipmentChoiceGroupsFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const EquipmentChoiceGroupsFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
  });

  List<Map<String, dynamic>> _coerceGroups(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final g in raw)
        if (g is Map) Map<String, dynamic>.from(g),
    ];
  }

  /// `<prefix>-<unix-ms>` short ids — stable enough for round-trip and free
  /// of `package:uuid` (kept out of the structured-list file to avoid
  /// pulling another dep into a widget module).
  String _genId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  void _writeGroups(List<Map<String, dynamic>> groups) {
    onChanged(groups);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _coerceGroups(value);
    final palette = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schema.label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!readOnly)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Group',
                        style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      final next = [
                        ...groups,
                        {
                          'group_id': _genId('grp'),
                          'label': 'New Choice',
                          'prompt': 'Choose one',
                          'options': <Map<String, dynamic>>[],
                        },
                      ];
                      _writeGroups(next);
                    },
                  ),
              ],
            ),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  readOnly
                      ? '—'
                      : 'No groups — tap + Add Group to author a "Choose A or B" choice.',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.colorScheme.outline,
                  ),
                ),
              ),
            for (var gi = 0; gi < groups.length; gi++) ...[
              if (gi > 0) const Divider(height: 14),
              _buildGroup(context, groups, gi),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(
      BuildContext context, List<Map<String, dynamic>> groups, int gi) {
    final group = groups[gi];
    final rawOpts = group['options'];
    final options = rawOpts is List
        ? [for (final o in rawOpts) if (o is Map) Map<String, dynamic>.from(o)]
        : <Map<String, dynamic>>[];

    void writeGroup(Map<String, dynamic> next) {
      final list = [...groups];
      list[gi] = next;
      _writeGroups(list);
    }

    void removeGroup() {
      final list = [...groups]..removeAt(gi);
      _writeGroups(list);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _miniText(
                  label: 'Label',
                  value: (group['label'] ?? '').toString(),
                  readOnly: readOnly,
                  onChanged: (s) => writeGroup({...group, 'label': s}),
                  width: 180,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniText(
                    label: 'Prompt',
                    value: (group['prompt'] ?? '').toString(),
                    readOnly: readOnly,
                    onChanged: (s) => writeGroup({...group, 'prompt': s}),
                    width: 380,
                  ),
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete group',
                    onPressed: removeGroup,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var oi = 0; oi < options.length; oi++)
              _buildOption(context, group, writeGroup, options, oi),
            if (!readOnly)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 14),
                  label: const Text('Add Option',
                      style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final next = [
                      ...options,
                      {
                        'option_id': _genId('opt'),
                        'label': 'Option ${options.length + 1}',
                        'items': <Map<String, dynamic>>[],
                      },
                    ];
                    writeGroup({...group, 'options': next});
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    Map<String, dynamic> group,
    void Function(Map<String, dynamic>) writeGroup,
    List<Map<String, dynamic>> options,
    int oi,
  ) {
    final option = options[oi];
    final rawItems = option['items'];
    final items = rawItems is List
        ? [for (final i in rawItems) if (i is Map) Map<String, dynamic>.from(i)]
        : <Map<String, dynamic>>[];
    final goldGp = option['gold_gp'];

    void writeOption(Map<String, dynamic> next) {
      final list = [...options];
      list[oi] = next;
      writeGroup({...group, 'options': list});
    }

    void removeOption() {
      final list = [...options]..removeAt(oi);
      writeGroup({...group, 'options': list});
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _miniText(
                  label: 'ID',
                  value: (option['option_id'] ?? '').toString(),
                  readOnly: readOnly,
                  onChanged: (s) =>
                      writeOption({...option, 'option_id': s}),
                  width: 80,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _miniText(
                    label: 'Label',
                    value: (option['label'] ?? '').toString(),
                    readOnly: readOnly,
                    onChanged: (s) => writeOption({...option, 'label': s}),
                    width: 280,
                  ),
                ),
                const SizedBox(width: 6),
                _miniInt(
                  label: 'Gold gp',
                  value: goldGp is int
                      ? goldGp
                      : (goldGp is num ? goldGp.toInt() : null),
                  readOnly: readOnly,
                  onChanged: (n) {
                    final next = Map<String, dynamic>.from(option);
                    if (n == null || n <= 0) {
                      next.remove('gold_gp');
                    } else {
                      next['gold_gp'] = n;
                    }
                    writeOption(next);
                  },
                  width: 70,
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete option',
                    onPressed: removeOption,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var ii = 0; ii < items.length; ii++)
              _buildItem(option, writeOption, items, ii),
            if (!readOnly)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 6),
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 12),
                  label: const Text('Add Item',
                      style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    final next = [
                      ...items,
                      {'ref': null, 'quantity': 1},
                    ];
                    writeOption({...option, 'items': next});
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    Map<String, dynamic> option,
    void Function(Map<String, dynamic>) writeOption,
    List<Map<String, dynamic>> items,
    int ii,
  ) {
    final item = items[ii];
    final refId = item['ref'] is String ? item['ref'] as String : null;
    final qty = item['quantity'];

    void writeItem(Map<String, dynamic> next) {
      final list = [...items];
      list[ii] = next;
      writeOption({...option, 'items': list});
    }

    void removeItem() {
      final list = [...items]..removeAt(ii);
      writeOption({...option, 'items': list});
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
      child: Row(
        children: [
          _MiniRelationField(
            label: 'Item',
            value: refId,
            allowedTypes: _kItemPickAllowedTypes,
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (v) => writeItem({...item, 'ref': v}),
          ),
          const SizedBox(width: 6),
          _miniInt(
            label: 'Qty',
            value:
                qty is int ? qty : (qty is num ? qty.toInt() : null),
            readOnly: readOnly,
            onChanged: (n) => writeItem({...item, 'quantity': n ?? 1}),
            width: 60,
          ),
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.close, size: 12),
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete item',
              onPressed: removeItem,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// subspeciesOptions — species lineage rows
// Shape: List<{name, description, granted_senses, granted_damage_resistances,
//   granted_damage_immunities, granted_damage_vulnerabilities,
//   granted_condition_immunities, granted_languages,
//   granted_skill_proficiencies, granted_action_refs,
//   granted_bonus_action_refs, granted_reaction_refs, granted_trait_refs}>
//
// CharacterResolver matches rows by `name` (string) and folds the listed
// grants. `granted_modifiers` (typed DSL) is supported by the resolver but
// stays out of this MVP editor — authors needing the full DSL can drop to
// JSON view; the modifier editor at the species level already covers it.
// ─────────────────────────────────────────────────────────────────────────

const _kSubspeciesGrantKeys = <(
  String key,
  String label,
  List<String> allowedTypes,
)>[
  ('granted_senses', 'Senses', ['sense']),
  ('granted_damage_resistances', 'Resistances', ['damage-type']),
  ('granted_damage_immunities', 'Immunities', ['damage-type']),
  ('granted_damage_vulnerabilities', 'Vulnerabilities', ['damage-type']),
  ('granted_condition_immunities', 'Condition Imm.', ['condition']),
  ('granted_languages', 'Languages', ['language']),
  ('granted_skill_proficiencies', 'Skills', ['skill']),
  ('granted_action_refs', 'Actions', ['creature-action']),
  ('granted_bonus_action_refs', 'Bonus Actions', ['creature-action']),
  ('granted_reaction_refs', 'Reactions', ['creature-action']),
  ('granted_trait_refs', 'Traits', ['trait']),
];

class SubspeciesOptionsFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const SubspeciesOptionsFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
  });

  List<Map<String, dynamic>> _coerceRows(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map) Map<String, dynamic>.from(r),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _coerceRows(value);
    final palette = Theme.of(context);

    void writeRows(List<Map<String, dynamic>> next) => onChanged(next);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schema.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!readOnly)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Lineage',
                        style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      writeRows([
                        ...rows,
                        {
                          'name': 'New Lineage',
                          'description': '',
                        },
                      ]);
                    },
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  readOnly ? '—' : 'No lineages — tap + Add Lineage.',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.colorScheme.outline,
                  ),
                ),
              ),
            for (var ri = 0; ri < rows.length; ri++)
              _buildRow(context, rows, ri, writeRows),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    int ri,
    ValueChanged<List<Map<String, dynamic>>> writeRows,
  ) {
    final row = rows[ri];

    void writeRow(Map<String, dynamic> next) {
      final list = [...rows];
      list[ri] = next;
      writeRows(list);
    }

    void removeRow() {
      final list = [...rows]..removeAt(ri);
      writeRows(list);
    }

    final name = (row['name'] ?? '').toString();
    final description = (row['description'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          name.isEmpty ? '(unnamed lineage)' : name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        trailing: readOnly
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete lineage',
                onPressed: removeRow,
              ),
        children: [
          Row(
            children: [
              _miniText(
                label: 'Name',
                value: name,
                readOnly: readOnly,
                onChanged: (s) => writeRow({...row, 'name': s}),
                width: 200,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniText(
                  label: 'Description',
                  value: description,
                  readOnly: readOnly,
                  onChanged: (s) =>
                      writeRow({...row, 'description': s}),
                  width: 400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final spec in _kSubspeciesGrantKeys)
            _RelationListChips(
              key: ValueKey('lineage-$ri-${spec.$1}'),
              label: spec.$2,
              values: _readStringList(row[spec.$1]),
              allowedTypes: spec.$3,
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (next) {
                final updated = Map<String, dynamic>.from(row);
                if (next.isEmpty) {
                  updated.remove(spec.$1);
                } else {
                  updated[spec.$1] = next;
                }
                writeRow(updated);
              },
            ),
        ],
      ),
    );
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is! List) return const [];
    return [for (final v in raw) if (v is String) v];
  }
}

/// Reusable label + chip strip + "+ Add" button for relation-list cells.
/// Bridges single-value `_MiniRelationField` semantics into a multi-value
/// editor without forcing callers to construct a synthetic `FieldSchema`
/// for `_InlineRelationListFieldWidget`.
class _RelationListChips extends StatelessWidget {
  final String label;
  final List<String> values;
  final List<String> allowedTypes;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool readOnly;
  final ValueChanged<List<String>> onChanged;

  const _RelationListChips({
    super.key,
    required this.label,
    required this.values,
    required this.allowedTypes,
    required this.entities,
    required this.ref,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < values.length; i++)
                  Chip(
                    label: Text(
                      entities?[values[i]]?.name ?? values[i],
                      style: const TextStyle(fontSize: 11),
                    ),
                    onDeleted: readOnly
                        ? null
                        : () {
                            final next = [...values]..removeAt(i);
                            onChanged(next);
                          },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                if (!readOnly)
                  InkWell(
                    onTap: () async {
                      if (ref == null) return;
                      final result = await showEntitySelectorDialog(
                        context: context,
                        ref: ref!,
                        allowedTypes: allowedTypes,
                        excludeIds: values,
                        includeBuiltinSrd: true,
                      );
                      if (result != null && result.isNotEmpty) {
                        onChanged([...values, result.first]);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 12),
                          SizedBox(width: 2),
                          Text(
                            'Add',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
