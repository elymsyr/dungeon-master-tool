import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../dialogs/entity_selector_dialog.dart';

/// Typed structured-list editors for the 4 list FieldTypes:
///   - classFeatures
///   - spellEffectList
///   - rangedSenseList
///   - grantedModifiers
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

  const _StructuredListShell({
    required this.schema,
    required this.rows,
    required this.readOnly,
    required this.onChanged,
    required this.makeEmptyRow,
    required this.buildRow,
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
            ...rows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            }),
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

Widget _miniEnum({
  required String label,
  required String? value,
  required List<String> options,
  required bool readOnly,
  required ValueChanged<String?> onChanged,
  double width = 140,
}) {
  return SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      initialValue: (value != null && options.contains(value)) ? value : null,
      isDense: true,
      isExpanded: true,
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        labelStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      items: options
          .map((o) => DropdownMenuItem(
                value: o,
                child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: readOnly ? null : onChanged,
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
// 2. classFeatures — {level, name, kind, dice, uses, recharge, description}
// ─────────────────────────────────────────────────────────────────────────

const _classFeatureKinds = [
  'passive',
  'resource',
  'extra-attack',
  'spellcasting-bump',
  'ability-improvement',
];

const _classFeatureRechargeKinds = [
  '',
  'short-rest',
  'long-rest',
  'day',
];

class ClassFeaturesFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const ClassFeaturesFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _coerceRows(value);
    return _StructuredListShell(
      schema: schema,
      rows: rows,
      readOnly: readOnly,
      onChanged: onChanged,
      makeEmptyRow: () => {
        'level': null,
        'name': '',
        'kind': null,
        'dice': '',
        'uses': null,
        'recharge': '',
        'description': '',
      },
      buildRow: (i, row, onRowChanged) {
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _miniInt(
              label: 'Level',
              value: row['level'] is int ? row['level'] as int : null,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'level': v}),
              width: 60,
            ),
            _miniText(
              label: 'Name',
              value: (row['name'] ?? '').toString(),
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'name': v}),
              width: 160,
            ),
            _miniEnum(
              label: 'Kind',
              value: row['kind'] as String?,
              options: _classFeatureKinds,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'kind': v}),
              width: 150,
            ),
            _miniText(
              label: 'Dice',
              value: (row['dice'] ?? '').toString(),
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'dice': v}),
              width: 80,
            ),
            _miniInt(
              label: 'Uses',
              value: row['uses'] is int ? row['uses'] as int : null,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'uses': v}),
              width: 60,
            ),
            _miniEnum(
              label: 'Recharge',
              value: row['recharge'] as String?,
              options: _classFeatureRechargeKinds,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'recharge': v ?? ''}),
              width: 120,
            ),
            _miniText(
              label: 'Description',
              value: (row['description'] ?? '').toString(),
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'description': v}),
              width: 300,
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 3. spellEffectList — {kind, dice, type_ref, save_ability_ref, save_effect, condition_refs[], scaling_dice}
// ─────────────────────────────────────────────────────────────────────────

const _spellEffectKinds = [
  'damage',
  'heal',
  'condition',
  'buff',
  'debuff',
];

const _spellSaveEffects = [
  '',
  'none',
  'half',
  'negate',
  'partial',
];

class SpellEffectListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const SpellEffectListFieldWidget({
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
      makeEmptyRow: () => {
        'kind': null,
        'dice': '',
        'type_ref': null,
        'save_ability_ref': null,
        'save_effect': '',
        'condition_refs': <String>[],
        'scaling_dice': '',
      },
      buildRow: (i, row, onRowChanged) {
        final condRefs = (row['condition_refs'] is List)
            ? List<String>.from((row['condition_refs'] as List).whereType<String>())
            : <String>[];
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _miniEnum(
              label: 'Kind',
              value: row['kind'] as String?,
              options: _spellEffectKinds,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'kind': v}),
              width: 120,
            ),
            _miniText(
              label: 'Dice',
              value: (row['dice'] ?? '').toString(),
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'dice': v}),
              width: 90,
            ),
            _MiniRelationField(
              label: 'Damage Type',
              value: row['type_ref'] as String?,
              allowedTypes: const ['damage-type'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'type_ref': v}),
            ),
            _MiniRelationField(
              label: 'Save Ability',
              value: row['save_ability_ref'] as String?,
              allowedTypes: const ['ability'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'save_ability_ref': v}),
            ),
            _miniEnum(
              label: 'Save Effect',
              value: row['save_effect'] as String?,
              options: _spellSaveEffects,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'save_effect': v ?? ''}),
              width: 110,
            ),
            _MiniRelationListField(
              label: 'Conditions',
              values: condRefs,
              allowedTypes: const ['condition'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'condition_refs': v}),
            ),
            _miniText(
              label: 'Scaling Dice',
              value: (row['scaling_dice'] ?? '').toString(),
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'scaling_dice': v}),
              width: 110,
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 4. grantedModifiers — {kind, target_kind, target_ref, value, scaling, condition_ref, notes}
// ─────────────────────────────────────────────────────────────────────────

const _modifierKinds = [
  'ability_score_bonus',
  'ability_score_max_increase',
  'ac_bonus',
  'save_bonus',
  'skill_bonus',
  'attack_bonus',
  'damage_bonus',
  'speed_bonus',
  'hp_bonus_flat',
  'hp_bonus_per_level',
  'initiative_bonus',
  'passive_score_bonus',
  'resistance_grant',
  'immunity_grant',
  'vulnerability_grant',
  'condition_save_advantage',
  'condition_save_immunity',
  'attack_advantage_vs',
  'proficiency_grant',
  'expertise_grant',
  'language_grant',
  'sense_grant',
  'spell_known_grant',
  'spell_at_will_grant',
  'feat_grant',
  'feature_text',
];

const _modifierTargetKinds = [
  '',
  'ability',
  'skill',
  'damage-type',
  'condition',
  'sense',
  'speed-type',
  'weapon-category',
  'armor-category',
  'class',
  'spell',
  'feat',
  'tool',
  'language',
  'save',
];

const _modifierScalings = [
  '',
  'flat',
  'per-level',
  'per-proficiency-bonus',
];

/// Maps a `target_kind` string to the entity slug(s) accepted by
/// [showEntitySelectorDialog]. Lookup categories share their slug with the
/// target_kind value (e.g. 'ability' → 'ability'), but a few aliases exist
/// for content categories.
List<String> _allowedTypesForTargetKind(String? targetKind) {
  switch (targetKind) {
    case 'ability':
    case 'skill':
    case 'damage-type':
    case 'condition':
    case 'sense':
    case 'speed-type':
    case 'weapon-category':
    case 'armor-category':
    case 'language':
      return [targetKind!];
    case 'class':
      return const ['class'];
    case 'spell':
      return const ['spell'];
    case 'feat':
      return const ['feat'];
    case 'tool':
      return const ['tool'];
    case 'save':
      return const ['ability']; // saves resolve via ability lookup
    default:
      return const <String>[];
  }
}

class GrantedModifiersFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const GrantedModifiersFieldWidget({
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
      makeEmptyRow: () => {
        'kind': null,
        'target_kind': null,
        'target_ref': null,
        'value': null,
        'scaling': '',
        'condition_ref': null,
        'notes': '',
      },
      buildRow: (i, row, onRowChanged) {
        final targetKind = row['target_kind'] as String?;
        final allowed = _allowedTypesForTargetKind(targetKind);
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _miniEnum(
              label: 'Kind',
              value: row['kind'] as String?,
              options: _modifierKinds,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'kind': v}),
              width: 220,
            ),
            _miniEnum(
              label: 'Target Kind',
              value: targetKind,
              options: _modifierTargetKinds,
              readOnly: readOnly,
              onChanged: (v) {
                // Reset target_ref when target_kind changes since allowed types differ.
                onRowChanged({...row, 'target_kind': v == '' ? null : v, 'target_ref': null});
              },
              width: 160,
            ),
            if (allowed.isNotEmpty)
              _MiniRelationField(
                label: 'Target',
                value: row['target_ref'] as String?,
                allowedTypes: allowed,
                entities: entities,
                ref: ref,
                readOnly: readOnly,
                onChanged: (v) => onRowChanged({...row, 'target_ref': v}),
              ),
            _miniInt(
              label: 'Value',
              value: row['value'] is int ? row['value'] as int : null,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'value': v}),
              width: 70,
            ),
            _miniEnum(
              label: 'Scaling',
              value: row['scaling'] as String?,
              options: _modifierScalings,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'scaling': v ?? ''}),
              width: 150,
            ),
            _MiniRelationField(
              label: 'Condition',
              value: row['condition_ref'] as String?,
              allowedTypes: const ['condition'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'condition_ref': v}),
            ),
            _miniText(
              label: 'Notes',
              value: (row['notes'] ?? '').toString(),
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'notes': v}),
              width: 240,
            ),
          ],
        );
      },
    );
  }
}
