import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/rule_catalog_provider.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/rules/rule_definition.dart';
import '../../../domain/entities/schema/rules/rule_validator.dart';
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

Widget _miniEnum({
  required String label,
  required String? value,
  required List<String> options,
  required bool readOnly,
  required ValueChanged<String?> onChanged,
  double width = 140,
  String Function(String)? display,
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
                child: Text(display?.call(o) ?? o,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: readOnly ? null : onChanged,
    ),
  );
}

Widget _miniBool({
  required String label,
  required bool value,
  required bool readOnly,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: readOnly ? null : (b) => onChanged(b ?? false),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
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

/// Curated kind set for the legacy `granted_modifiers` editor — only the
/// simple value/target grant kinds whose catalog entry is `resolverStatus:
/// applied` (i.e. the resolver actually applies them). Authoring a kind the
/// resolver ignores would silently do nothing, which is the bug this list
/// closes. Richer kinds (predicates/payload/scaling) live on the catalog-driven
/// `rule_effects` editor instead. Each entry is cross-checked against the live
/// catalog at build time (`catalog.contains`) before it is offered.
const _modifierCatalogKinds = [
  'ability_score_bonus',
  'ac_bonus',
  'speed_bonus',
  'hp_bonus_flat',
  'hp_bonus_per_level',
  'initiative_bonus',
  'passive_score_bonus',
  'proficiency_grant',
  'expertise_grant',
  'language_grant',
  'sense_grant',
  'spell_grant',
  'cantrip_grant',
  'damage_resistance',
  'damage_immunity',
  'damage_vulnerability',
  'condition_immunity_grant',
];

const _modifierTargetKinds = [
  '',
  'ability',
  'skill',
  'damage-type',
  'condition',
  'sense',
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

/// SRD common modifier presets. Each preset has a label and a list of one or
/// more pre-filled rows. Inserted at the end of the existing rows list.
const _modifierPresets = <String, List<Map<String, dynamic>>>{
  'Tough (feat)': [
    {
      'kind': 'hp_bonus_per_level',
      'target_kind': null,
      'target_ref': null,
      'value': 2,
      'scaling': 'per-level',
      'condition_ref': null,
      'notes': 'Tough: +2 HP per character level',
    },
  ],
  'Resilient: CON': [
    {
      'kind': 'proficiency_grant',
      'target_kind': 'save',
      'target_ref': 'ability-con',
      'value': null,
      'scaling': '',
      'condition_ref': null,
      'notes': 'Resilient (CON) saving throw proficiency',
    },
    {
      'kind': 'ability_score_bonus',
      'target_kind': 'ability',
      'target_ref': 'ability-con',
      'value': 1,
      'scaling': 'flat',
      'condition_ref': null,
      'notes': 'Resilient: +1 CON',
    },
  ],
  'Alert (feat)': [
    {
      'kind': 'initiative_bonus',
      'target_kind': null,
      'target_ref': null,
      'value': 5,
      'scaling': 'flat',
      'condition_ref': null,
      'notes': 'Alert: +5 initiative (2024 rules: PB, swap if needed)',
    },
  ],
  'Lucky (feat)': [
    {
      // Narrative only — luck points have no resolver-applied kind.
      'kind': null,
      'target_kind': null,
      'target_ref': null,
      'value': 3,
      'scaling': '',
      'condition_ref': null,
      'notes': 'Lucky: 3 luck points / long rest, reroll 1 d20 (track manually)',
    },
  ],
  'Magic Initiate: cantrip + 1st': [
    {
      'kind': 'cantrip_grant',
      'target_kind': 'spell',
      'target_ref': null,
      'value': null,
      'scaling': '',
      'condition_ref': null,
      'notes': 'Cantrip from chosen list',
    },
    {
      'kind': 'spell_grant',
      'target_kind': 'spell',
      'target_ref': null,
      'value': null,
      'scaling': '',
      'condition_ref': null,
      'notes': '1st-level spell from chosen list',
    },
    {
      'kind': 'spell_grant',
      'target_kind': 'spell',
      'target_ref': null,
      'value': 1,
      'scaling': '',
      'condition_ref': null,
      'notes': '1×/long rest cast of 1st-level without slot (track manually)',
    },
  ],
  'Darkvision 60 ft': [
    {
      'kind': 'sense_grant',
      'target_kind': 'sense',
      'target_ref': 'sense-darkvision',
      'value': 60,
      'scaling': '',
      'condition_ref': null,
      'notes': 'Darkvision 60 ft',
    },
  ],
  'Fire resistance': [
    {
      'kind': 'damage_resistance',
      'target_kind': 'damage-type',
      'target_ref': 'damage-type-fire',
      'value': null,
      'scaling': '',
      'condition_ref': null,
      'notes': 'Resistance to fire damage',
    },
  ],
  'Poison immunity + advantage': [
    {
      'kind': 'damage_immunity',
      'target_kind': 'damage-type',
      'target_ref': 'damage-type-poison',
      'value': null,
      'scaling': '',
      'condition_ref': null,
      'notes': 'Immunity to poison damage',
    },
    {
      // No resolver-applied kind for save-advantage-vs-condition yet — keep
      // as a narrative note (kind null = no mechanical effect; track manually).
      'kind': null,
      'target_kind': 'condition',
      'target_ref': 'condition-poisoned',
      'value': null,
      'scaling': '',
      'condition_ref': 'condition-poisoned',
      'notes': 'Advantage on saves vs being poisoned (track manually)',
    },
  ],
  'Heavy Armor Master': [
    {
      'kind': 'ability_score_bonus',
      'target_kind': 'ability',
      'target_ref': 'ability-str',
      'value': 1,
      'scaling': 'flat',
      'condition_ref': null,
      'notes': 'HAM: +1 STR',
    },
    {
      // No resolver-applied flat-damage-reduction kind yet — narrative note.
      'kind': null,
      'target_kind': 'damage-type',
      'target_ref': null,
      'value': -3,
      'scaling': 'flat',
      'condition_ref': null,
      'notes': 'While wearing heavy armor: reduce bludg/pierc/slash by 3 (track manually)',
    },
  ],
};

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
      headerActions: [
        PopupMenuButton<String>(
          tooltip: 'Add preset',
          icon: const Icon(Icons.bolt, size: 18),
          itemBuilder: (ctx) => _modifierPresets.keys
              .map((label) => PopupMenuItem<String>(value: label, child: Text(label, style: const TextStyle(fontSize: 13))))
              .toList(),
          onSelected: (label) {
            final preset = _modifierPresets[label];
            if (preset == null) return;
            onChanged([...rows, ...preset.map((r) => Map<String, dynamic>.from(r))]);
          },
        ),
      ],
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
        // Catalog is the single registry. Read (not watch): static for the
        // card's lifetime; falls back to the legacy const lists when no ref
        // (read-only projection views).
        final catalog = ref?.read(ruleCatalogProvider);
        final kind = row['kind'] as String?;
        // Offer only curated kinds the catalog actually knows; union the row's
        // stored kind so a legacy/dropped value is never silently hidden.
        final baseKinds = catalog == null
            ? _modifierKinds
            : _modifierCatalogKinds.where(catalog.contains).toList();
        final kindOptions =
            (kind != null && kind.isNotEmpty && !baseKinds.contains(kind))
                ? [...baseKinds, kind]
                : baseKinds;
        // Target-kind options from the selected rule's declared targets when
        // it names any, else the legacy union list (kinds that take no target
        // keep the historical picker for back-compat).
        final declaredTargets =
            (catalog != null && kind != null) ? (catalog[kind]?.allowedTargetKinds ?? const <String>[]) : const <String>[];
        final targetKindOptions = declaredTargets.isNotEmpty
            ? <String>{'', ...declaredTargets}.toList()
            : _modifierTargetKinds;
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _miniEnum(
              label: 'Kind',
              value: kind,
              options: kindOptions,
              readOnly: readOnly,
              display: (k) => catalog?.labelFor(k) ?? k,
              onChanged: (v) => onRowChanged({...row, 'kind': v}),
              width: 220,
            ),
            _miniEnum(
              label: 'Target Kind',
              value: targetKind,
              options: targetKindOptions,
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
// featEffectList — {kind, target_kind?, target_ref?, value?, payload?, predicates?, scales_with?, activation?}
//
// MVP editor: kind dropdown + value int + target relation. Predicates,
// scales_with, activation render as read-only badges (count). Authoring those
// nested structures from the UI is a follow-up; for now SRD content authors
// edit the data file directly when complex shapes are needed.
// ─────────────────────────────────────────────────────────────────────────

const _featEffectKinds = [
  // Existing
  'class_level_grant', 'proficiency_grant', 'language_grant', 'spell_grant',
  'cantrip_grant', 'ac_bonus', 'speed_bonus', 'hp_bonus_per_level',
  'hp_bonus_flat', 'initiative_bonus', 'attack_bonus', 'extra_attack_bump',
  'choice_group',
  // New (PR-7c+)
  'unarmored_ac_formula', 'damage_resistance', 'damage_immunity',
  'damage_vulnerability', 'condition_immunity_grant',
  'condition_advantage_on_save_grant', 'crit_range_extend',
  'extra_damage_on_attack', 'reroll_damage', 'reroll_d20',
  'attack_bonus_typed', 'damage_bonus_typed', 'ignore_cover',
  'ignore_long_range_disadvantage', 'damage_reduction_flat',
  'swim_speed_equals_speed', 'climb_speed_equals_speed', 'fly_speed',
  'sense_grant', 'truesight_grant', 'blindsight_grant', 'walk_on_liquid',
  'advantage_on', 'disadvantage_on', 'expertise_grant',
  'half_proficiency_to_unproficient_checks', 'passive_score_bonus',
  'reliable_talent', 'min_die_value', 'state_grant', 'resource_pool_grant',
  'recovery_grant', 'slot_recovery_short_rest', 'spell_always_prepared',
  'spell_cast_from_item', 'spellcasting_ability_to_damage',
  'cantrip_count_bonus', 'magical_unarmed_strikes', 'damage_type_override',
  'concentration_advantage', 'concentration_immune_to_damage_break',
  'reaction_attack_grant', 'reaction_damage_reduction',
  'reaction_negate_via_save',
  'opportunity_attack_immunity_when_disengage_redundant',
  'enemy_cant_disengage_oa', 'oa_stops_movement', 'weapon_mastery_grant',
  'weapon_mastery_count_bonus', 'expertise_count', 'extra_attack_count',
  'hp_max_bonus_total', 'temp_hp_grant',
];

const _featEffectTargetKinds = [
  '', 'ac', 'save', 'skill', 'speed', 'hp', 'sense', 'damage_type', 'condition',
  'class', 'spell', 'cantrip', 'language', 'feat', 'tool', 'weapon', 'ability',
];

class FeatEffectListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const FeatEffectListFieldWidget({
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
    // Catalog is the single source of truth for the kind / target-kind options.
    // Read (not watch): `ref` here is the host card's WidgetRef and the catalog
    // is static for the card's lifetime. Falls back to the historical const
    // lists when no ref is available (e.g. read-only projection views).
    final catalog = ref?.read(ruleCatalogProvider);
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
      },
      buildRow: (i, row, onRowChanged) => _FeatEffectRow(
        catalog: catalog,
        row: row,
        entities: entities,
        ref: ref,
        readOnly: readOnly,
        onChanged: onRowChanged,
      ),
    );
  }
}

/// One authorable feat-effect row: kind + target + per-rule params, plus the
/// full predicate / scales-with / activation sub-editors driven by the rule's
/// declared capability flags. Replaces the old MVP read-only badges.
class _FeatEffectRow extends StatelessWidget {
  final RuleCatalog? catalog;
  final Map<String, dynamic> row;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool readOnly;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _FeatEffectRow({
    required this.catalog,
    required this.row,
    required this.entities,
    required this.ref,
    required this.readOnly,
    required this.onChanged,
  });

  Map<String, dynamic> _without(String key) {
    final m = {...row}..remove(key);
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final kind = row['kind'] as String?;
    final rule = (catalog != null && kind != null) ? catalog![kind] : null;
    final targetKind = row['target_kind'] as String?;
    final allowed =
        _allowedTypesForTargetKind(targetKind == '' ? null : targetKind);

    // Kind options ← catalog, unioning any current value so a legacy /
    // not-yet-declared kind is never silently dropped from the row.
    final baseKinds = catalog?.kinds.toList() ?? _featEffectKinds;
    final kindOptions =
        (kind != null && kind.isNotEmpty && !baseKinds.contains(kind))
            ? [...baseKinds, kind]
            : baseKinds;

    // Target-kind dropdown is hidden for rules that take no target (e.g.
    // ac_bonus), unless the row already carries one (never hide data).
    final ruleTargets = rule?.allowedTargetKinds ?? const <String>[];
    final showTargetKind = catalog == null ||
        rule == null ||
        ruleTargets.isNotEmpty ||
        (targetKind != null && targetKind.isNotEmpty);
    final baseTargets = catalog?.targetKindsFor(kind) ?? _featEffectTargetKinds;
    final targetOptions = <String>{
      '',
      ...baseTargets,
      if (targetKind != null && targetKind.isNotEmpty) targetKind,
    }.toList();

    // Nested-shape gating: show a sub-editor when the rule supports it (edit
    // mode) or when the row already carries that data (any mode).
    final preds = _coerceRows(row['predicates']);
    final showPreds =
        (!readOnly && (rule?.supportsPredicates ?? false)) || preds.isNotEmpty;
    final scales =
        row['scales_with'] is Map ? Map<String, dynamic>.from(row['scales_with']) : null;
    final showScales =
        (!readOnly && (rule?.supportsScaling ?? false)) || scales != null;
    final activation =
        row['activation'] is Map ? Map<String, dynamic>.from(row['activation']) : null;
    final showActivation =
        (!readOnly && (rule?.supportsActivation ?? false)) || activation != null;

    // Undeclared payload keys (data we can't author yet) — surface as a badge
    // so the author knows the row carries extra structure that is preserved.
    final payload =
        row['payload'] is Map ? Map<String, dynamic>.from(row['payload']) : const {};
    final declaredPayloadKeys = <String>{
      for (final p in rule?.params ?? const <RuleParamSpec>[])
        if (p.location == RuleParamLocation.payload) p.key,
    };
    final extraPayloadKeys =
        payload.keys.where((k) => !declaredPayloadKeys.contains(k)).toList();

    // Non-blocking authoring warnings (bad target kind, unknown predicate,
    // missing required param). Only when a real kind is set, to avoid nagging
    // on a freshly-added empty row.
    final issues = (catalog != null && kind != null && kind.isNotEmpty)
        ? validateEffectRow(row, catalog!)
        : const <RuleIssue>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (issues.isNotEmpty)
              Tooltip(
                message: issues.map((e) => '• ${e.message}').join('\n'),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.orange),
              ),
            _miniEnum(
              label: 'Kind',
              value: kind,
              options: kindOptions,
              readOnly: readOnly,
              onChanged: (v) => onChanged({...row, 'kind': v}),
              width: 240,
              display: (k) => catalog?.labelFor(k) ?? k,
            ),
            if (showTargetKind)
              _miniEnum(
                label: 'Target Kind',
                value: targetKind,
                options: targetOptions,
                readOnly: readOnly,
                onChanged: (v) => onChanged({
                  ...row,
                  'target_kind': v == '' ? null : v,
                  'target_ref': null,
                }),
                width: 140,
              ),
            if (allowed.isNotEmpty)
              _MiniRelationField(
                label: 'Target',
                value: row['target_ref'] is String
                    ? row['target_ref'] as String
                    : null,
                allowedTypes: allowed,
                entities: entities,
                ref: ref,
                readOnly: readOnly,
                onChanged: (v) => onChanged({...row, 'target_ref': v}),
              ),
            ..._paramInputs(rule),
            if (extraPayloadKeys.isNotEmpty)
              _badge('payload: ${extraPayloadKeys.join(", ")}', Colors.brown),
          ],
        ),
        if (rule?.description.isNotEmpty == true && !readOnly)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2),
            child: Text(
              rule!.description,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic),
            ),
          ),
        if (showPreds)
          _PredicateEditor(
            predicateKinds: catalog?.predicateKinds ?? const [],
            preds: preds,
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (list) => onChanged(
                list.isEmpty ? _without('predicates') : {...row, 'predicates': list}),
          ),
        if (showScales)
          _ScalesWithEditor(
            scales: scales,
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (m) =>
                onChanged(m == null ? _without('scales_with') : {...row, 'scales_with': m}),
          ),
        if (showActivation)
          _ActivationEditor(
            activation: activation,
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (m) =>
                onChanged(m == null ? _without('activation') : {...row, 'activation': m}),
          ),
      ],
    );
  }

  /// Inline param inputs for the selected rule (top-level `value` + payload
  /// params). Legacy/unknown kinds keep the bare Value field; undeclared
  /// payload keys are preserved by always spreading the existing payload.
  List<Widget> _paramInputs(RuleDefinition? rule) {
    final out = <Widget>[];
    final payload =
        row['payload'] is Map ? Map<String, dynamic>.from(row['payload']) : <String, dynamic>{};

    void writePayload(String key, Object? v) {
      final p = {...payload};
      if (v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty)) {
        p.remove(key);
      } else {
        p[key] = v;
      }
      onChanged(p.isEmpty ? _without('payload') : {...row, 'payload': p});
    }

    RuleParamSpec? valueParam;
    for (final p in rule?.params ?? const <RuleParamSpec>[]) {
      if (p.location == RuleParamLocation.topLevel && p.key == 'value') {
        valueParam = p;
      }
    }

    if (valueParam != null) {
      out.add(_paramWidget(
          valueParam, row['value'], (v) => onChanged({...row, 'value': v})));
    } else if (rule == null || row['value'] != null) {
      // Preserve / allow editing of a bare value on legacy or unknown rows.
      out.add(_miniInt(
        label: 'Value',
        value: row['value'] is int ? row['value'] as int : null,
        readOnly: readOnly,
        onChanged: (v) => onChanged({...row, 'value': v}),
        width: 70,
      ));
    }

    for (final p in rule?.params ?? const <RuleParamSpec>[]) {
      if (p.location == RuleParamLocation.payload) {
        out.add(_paramWidget(p, payload[p.key], (v) => writePayload(p.key, v)));
      } else if (p.location == RuleParamLocation.topLevel && p.key != 'value') {
        out.add(_paramWidget(p, row[p.key], (v) {
          onChanged(v == null ? _without(p.key) : {...row, p.key: v});
        }));
      }
    }
    return out;
  }

  Widget _paramWidget(
      RuleParamSpec spec, Object? value, ValueChanged<Object?> write) {
    return switch (spec.type) {
      RuleParamType.int_ => _miniInt(
          label: spec.label,
          value: value is int ? value : null,
          readOnly: readOnly,
          onChanged: write,
          width: 80,
        ),
      RuleParamType.bool_ => _miniBool(
          label: spec.label,
          value: value == true,
          readOnly: readOnly,
          onChanged: write,
        ),
      RuleParamType.enumChoice => _miniEnum(
          label: spec.label,
          value: value?.toString(),
          options: ['', ...spec.enumOptions],
          readOnly: readOnly,
          onChanged: (v) => write(v == null || v.isEmpty ? null : v),
          width: 140,
        ),
      RuleParamType.relation => _MiniRelationField(
          label: spec.label,
          value: value is String ? value : null,
          allowedTypes: spec.relationAllowedTypes,
          entities: entities,
          ref: ref,
          readOnly: readOnly,
          onChanged: write,
        ),
      RuleParamType.abilityList => _miniText(
          label: spec.label,
          value: value is List ? value.join(',') : '',
          readOnly: readOnly,
          width: 150,
          onChanged: (s) {
            final list = s
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            write(list.isEmpty ? null : list);
          },
        ),
      RuleParamType.string_ || RuleParamType.dice => _miniText(
          label: spec.label,
          value: value?.toString() ?? '',
          readOnly: readOnly,
          width: 150,
          onChanged: (s) => write(s.isEmpty ? null : s),
        ),
    };
  }
}

/// Compact bordered section used by the nested feat-effect sub-editors.
Widget _nestedBox({
  required BuildContext context,
  required String title,
  required bool readOnly,
  VoidCallback? onAdd,
  VoidCallback? onClear,
  required List<Widget> children,
}) {
  final outline = Theme.of(context).colorScheme.outline;
  return Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.fromLTRB(8, 2, 4, 6),
    decoration: BoxDecoration(
      border: Border.all(color: outline.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: outline)),
            const Spacer(),
            if (!readOnly && onClear != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                tooltip: 'Clear',
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
              ),
            if (!readOnly && onAdd != null)
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Add',
                visualDensity: VisualDensity.compact,
                onPressed: onAdd,
              ),
          ],
        ),
        ...children,
      ],
    ),
  );
}

/// Editor for an effect row's `predicates: [{kind, args}]` (AND-combined).
class _PredicateEditor extends StatelessWidget {
  final List<String> predicateKinds;
  final List<Map<String, dynamic>> preds;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool readOnly;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const _PredicateEditor({
    required this.predicateKinds,
    required this.preds,
    required this.entities,
    required this.ref,
    required this.readOnly,
    required this.onChanged,
  });

  static const _fallbackKinds = [
    'class_level_at_least', 'equipped_armor_kind', 'equipped_shield',
    'has_proficiency', 'has_state', 'has_condition', 'target_has_condition',
    'not_incapacitated',
  ];

  void _write(int i, Map<String, dynamic> next) {
    final l = [...preds];
    l[i] = next;
    onChanged(l);
  }

  @override
  Widget build(BuildContext context) {
    final kinds = predicateKinds.isEmpty ? _fallbackKinds : predicateKinds;
    return _nestedBox(
      context: context,
      title: 'Predicates — all must pass',
      readOnly: readOnly,
      onAdd: () =>
          onChanged([...preds, {'kind': null, 'args': <String, dynamic>{}}]),
      children: [
        if (preds.isEmpty)
          Text('No predicates',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline)),
        for (var i = 0; i < preds.length; i++) _row(context, kinds, i),
      ],
    );
  }

  Widget _row(BuildContext context, List<String> kinds, int i) {
    final p = preds[i];
    final kind = p['kind'] as String?;
    final args = p['args'] is Map
        ? Map<String, dynamic>.from(p['args'])
        : <String, dynamic>{};
    final kindOptions =
        (kind != null && kind.isNotEmpty && !kinds.contains(kind))
            ? [...kinds, kind]
            : kinds;
    void writeArgs(Map<String, dynamic> a) => _write(i, {...p, 'args': a});
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _miniEnum(
            label: 'Predicate',
            value: kind,
            options: kindOptions,
            readOnly: readOnly,
            onChanged: (v) =>
                _write(i, {...p, 'kind': v, 'args': <String, dynamic>{}}),
            width: 210,
          ),
          ..._argInputs(kind, args, writeArgs),
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged([...preds]..removeAt(i)),
            ),
        ],
      ),
    );
  }

  List<Widget> _argInputs(
      String? kind, Map<String, dynamic> args, ValueChanged<Map<String, dynamic>> writeArgs) {
    String? refArg() {
      final v = args['ref'] ?? args['state_ref'] ?? args['condition_ref'];
      return v is String ? v : null;
    }

    switch (kind) {
      case 'class_level_at_least':
        return [
          _MiniRelationField(
            label: 'Class',
            value: args['class_ref'] is String ? args['class_ref'] as String : null,
            allowedTypes: const ['class'],
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (v) => writeArgs({...args, 'class_ref': v}),
          ),
          _miniInt(
            label: 'Level',
            value: args['level'] is int ? args['level'] as int : null,
            readOnly: readOnly,
            onChanged: (v) => writeArgs({...args, 'level': v}),
            width: 70,
          ),
        ];
      case 'equipped_armor_kind':
        return [
          _miniEnum(
            label: 'Value',
            value: args['value']?.toString(),
            options: const ['none', 'light', 'medium', 'heavy', 'not_heavy', 'not_none'],
            readOnly: readOnly,
            onChanged: (v) => writeArgs({...args, 'value': v}),
            width: 130,
          ),
        ];
      case 'equipped_shield':
        return [
          _miniEnum(
            label: 'Value',
            value: args['value']?.toString(),
            options: const ['any', 'true', 'false'],
            readOnly: readOnly,
            onChanged: (v) => writeArgs({...args, 'value': v}),
            width: 100,
          ),
        ];
      case 'has_state':
        return [
          _MiniRelationField(
            label: 'State',
            value: refArg(),
            allowedTypes: const ['character-state'],
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (v) => writeArgs(v == null ? <String, dynamic>{} : {'ref': v}),
          ),
        ];
      case 'has_condition':
      case 'target_has_condition':
        return [
          _MiniRelationField(
            label: 'Condition',
            value: refArg(),
            allowedTypes: const ['condition'],
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (v) => writeArgs(v == null ? <String, dynamic>{} : {'ref': v}),
          ),
        ];
      case 'not_incapacitated':
      case null:
        return const [];
      default:
        return [
          _miniText(
            label: 'Value',
            value: args['value']?.toString() ?? '',
            readOnly: readOnly,
            width: 130,
            onChanged: (s) =>
                writeArgs(s.isEmpty ? <String, dynamic>{} : {...args, 'value': s}),
          ),
        ];
    }
  }
}

/// Editor for an effect row's `scales_with: {kind, class_ref?, table:[{lvl,v}]}`.
class _ScalesWithEditor extends StatelessWidget {
  final Map<String, dynamic>? scales;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool readOnly;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const _ScalesWithEditor({
    required this.scales,
    required this.entities,
    required this.ref,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final base = scales ?? const {'kind': 'class_level'};
    final kind = base['kind']?.toString() ?? 'class_level';
    final table = _coerceRows(base['table']);
    void write(Map<String, dynamic> next) => onChanged(next);
    return _nestedBox(
      context: context,
      title: 'Scales with level (largest row ≤ level wins)',
      readOnly: readOnly,
      onClear: scales == null ? null : () => onChanged(null),
      onAdd: () => write({
        ...base,
        'kind': kind,
        'table': [...table, {'lvl': 1, 'v': 1}],
      }),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _miniEnum(
              label: 'By',
              value: kind,
              options: const ['class_level', 'character_level'],
              readOnly: readOnly,
              onChanged: (v) => write({...base, 'kind': v ?? 'class_level'}),
              width: 160,
            ),
            if (kind == 'class_level' || kind == 'class_level_table')
              _MiniRelationField(
                label: 'Class',
                value: base['class_ref'] is String ? base['class_ref'] as String : null,
                allowedTypes: const ['class'],
                entities: entities,
                ref: ref,
                readOnly: readOnly,
                onChanged: (v) => write({...base, 'class_ref': v}),
              ),
          ],
        ),
        if (table.isEmpty)
          Text('No table rows',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline)),
        for (var i = 0; i < table.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _miniInt(
                  label: 'Lvl',
                  value: table[i]['lvl'] is int ? table[i]['lvl'] as int : null,
                  readOnly: readOnly,
                  onChanged: (v) {
                    final t = [...table];
                    t[i] = {...t[i], 'lvl': v};
                    write({...base, 'table': t});
                  },
                  width: 70,
                ),
                _miniInt(
                  label: 'Value',
                  value: table[i]['v'] is int ? table[i]['v'] as int : null,
                  readOnly: readOnly,
                  onChanged: (v) {
                    final t = [...table];
                    t[i] = {...t[i], 'v': v};
                    write({...base, 'table': t});
                  },
                  width: 80,
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final t = [...table]..removeAt(i);
                      write({...base, 'table': t});
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Editor for an effect row's `activation: {action_type, uses{count,per},
/// triggers_state_ref}`. Combat-tracker metadata — no resolve-time effect.
/// Unknown keys (duration, end_conditions) are preserved by spreading.
class _ActivationEditor extends StatelessWidget {
  final Map<String, dynamic>? activation;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool readOnly;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const _ActivationEditor({
    required this.activation,
    required this.entities,
    required this.ref,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final base = activation ?? <String, dynamic>{};
    final uses = base['uses'] is Map
        ? Map<String, dynamic>.from(base['uses'])
        : <String, dynamic>{};
    void write(Map<String, dynamic> next) => onChanged(next);
    void writeUses(Map<String, dynamic> u) {
      final next = {...base};
      if (u.isEmpty) {
        next.remove('uses');
      } else {
        next['uses'] = u;
      }
      write(next);
    }

    return _nestedBox(
      context: context,
      title: 'Activation (action economy)',
      readOnly: readOnly,
      onClear: activation == null ? null : () => onChanged(null),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _miniEnum(
              label: 'Action',
              value: base['action_type']?.toString(),
              options: const [
                'action', 'bonus_action', 'reaction', 'free', 'no_action', 'passive'
              ],
              readOnly: readOnly,
              onChanged: (v) => write({...base, 'action_type': v}),
              width: 150,
            ),
            _miniInt(
              label: 'Uses',
              value: uses['count'] is int ? uses['count'] as int : null,
              readOnly: readOnly,
              onChanged: (v) {
                final u = {...uses};
                if (v == null) {
                  u.remove('count');
                } else {
                  u['count'] = v;
                }
                writeUses(u);
              },
              width: 70,
            ),
            _miniEnum(
              label: 'Per',
              value: uses['per']?.toString(),
              options: const ['', 'short_rest', 'long_rest'],
              readOnly: readOnly,
              onChanged: (v) {
                final u = {...uses};
                if (v == null || v.isEmpty) {
                  u.remove('per');
                } else {
                  u['per'] = v;
                }
                writeUses(u);
              },
              width: 130,
            ),
            _MiniRelationField(
              label: 'Triggers State',
              value: base['triggers_state_ref'] is String
                  ? base['triggers_state_ref'] as String
                  : null,
              allowedTypes: const ['character-state'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) {
                final next = {...base};
                if (v == null) {
                  next.remove('triggers_state_ref');
                } else {
                  next['triggers_state_ref'] = v;
                }
                write(next);
              },
            ),
          ],
        ),
      ],
    );
  }
}

Widget _badge(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );

// ─────────────────────────────────────────────────────────────────────────
// autoGrantSources — {source: 'class'|'subclass'|'species'|'background',
//                     source_ref, at_level?, choice_required?}
// ─────────────────────────────────────────────────────────────────────────

const _autoGrantSources = ['class', 'subclass', 'species', 'background'];

class AutoGrantSourcesFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const AutoGrantSourcesFieldWidget({
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
        'source': null,
        'source_ref': null,
        'at_level': null,
      },
      buildRow: (i, row, onRowChanged) {
        final source = row['source'] as String?;
        final allowed = (source == null || source.isEmpty)
            ? const <String>[]
            : <String>[source];
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _miniEnum(
              label: 'Source',
              value: source,
              options: _autoGrantSources,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({
                ...row,
                'source': v,
                'source_ref': null,
              }),
              width: 130,
            ),
            if (allowed.isNotEmpty)
              _MiniRelationField(
                label: 'Source Ref',
                value: row['source_ref'] is String
                    ? row['source_ref'] as String
                    : null,
                allowedTypes: allowed,
                entities: entities,
                ref: ref,
                readOnly: readOnly,
                onChanged: (v) => onRowChanged({...row, 'source_ref': v}),
              ),
            _miniInt(
              label: 'At Level',
              value: row['at_level'] is int ? row['at_level'] as int : null,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'at_level': v}),
              width: 80,
            ),
            if (row['choice_required'] == true)
              _badge('choice_required', Colors.orange),
          ],
        );
      },
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
