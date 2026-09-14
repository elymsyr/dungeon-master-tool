import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/services/entity_ref.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../expandable_markdown.dart';
import 'entity_link.dart';
import '../../l10n/app_localizations.dart';

/// Typed structured-list editors for the structured list FieldTypes:
///   - classFeatures
///   - spellEffectList
///   - rangedSenseList
///   - equipmentChoiceGroups
///   - resourcePoolGrants
///   - playerChoices
///   - subspeciesOptions
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

  void _reorder(int oldIndex, int newIndex) {
    final updated = [...rows];
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = updated.removeAt(oldIndex);
    updated.insert(adjusted, item);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (readOnly && rows.isEmpty) return const SizedBox.shrink();
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
                if (!readOnly)
                  Text(
                    schema.fieldType.name,
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                  ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: L10n.of(context)!.entryAdd,
                    onPressed: _addRow,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  L10n.of(context)!.entriesEmpty,
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
                        if (!readOnly) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${i + 1}.',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: buildRow(i, row, (r) => _updateRow(i, r)),
                        ),
                        if (!readOnly)
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            tooltip: L10n.of(context)!.btnRemove,
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

/// Read-only rendering of one row cell: `label value` as compact text, and
/// nothing at all when the value is empty. Read mode used to draw the same
/// grid of `TextFormField`s as the editor, blank boxes included.
Widget _roCell(String label, String? value,
    {double maxWidth = 520, bool markdown = false}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return const SizedBox.shrink();
  return Builder(builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    if (markdown) {
      // Prose cells hold markdown, so read mode renders it instead of leaking
      // literal `**`/`###`. Reuses the collapse/expand block used elsewhere.
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: scheme.outline)),
            ExpandableMarkdown(
              data: v,
              collapsedTextStyle:
                  TextStyle(fontSize: 12, color: scheme.onSurface),
            ),
          ],
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
          TextSpan(
            text: v,
            style: TextStyle(fontSize: 12, color: scheme.onSurface),
          ),
        ]),
      ),
    );
  });
}

Widget _miniText({
  required String label,
  required String value,
  required bool readOnly,
  required ValueChanged<String> onChanged,
  double width = 120,
  TextInputType? keyboardType,
  bool markdown = false,
}) {
  if (readOnly) return _roCell(label, value, markdown: markdown);
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
  if (readOnly) return _roCell(label, value?.toString());
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
  if (readOnly) {
    return _roCell(
        label, value == null ? null : (display?.call(value) ?? value));
  }
  return SizedBox(
    width: width,
    // Builder so the selected-value text inherits the theme's on-surface ink
    // instead of a hardcoded black that's unreadable on dark palettes.
    child: Builder(builder: (context) {
    return DropdownButtonFormField<String>(
      initialValue: (value != null && options.contains(value)) ? value : null,
      isDense: true,
      isExpanded: true,
      style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface),
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
    );
    }),
  );
}

/// Small tinted pill used to surface non-editable row facts (an unresolved
/// pack ref's name, a `choice_required` flag).
Widget _badge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color)),
  );
}

class _MiniRelationField extends StatelessWidget {
  final String label;

  /// Hard ref (uuid `String`) **veya** soft ref (`{slug/_lookup, name}` Map).
  /// Built-in SRD kartları da paketler de soft ref yazıyor (`lookup('sense',
  /// 'Darkvision')`), bu yüzden `String?` cast'i gerçek veride patlıyordu.
  final Object? value;
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
    final v = value;
    final String? label0 = switch (v) {
      String s when s.isNotEmpty => entities?[s]?.name ?? s,
      Map m => (m['name'] ?? m['slug'] ?? m['_lookup'])?.toString(),
      _ => null,
    };
    final hasValue = label0 != null && label0.isNotEmpty;
    final displayName = hasValue ? label0 : '—';
    // Audit **U3** — the value is a link when a card for it exists. It stays
    // plain text otherwise (an uninstalled pack's ref), and the underline is
    // the affordance, so it only appears where the tap lands somewhere.
    // No `sourcePanel`: these rows sit inside a structured-list editor, which
    // is not panel-scoped, so the default routing applies.
    final linkId = entityLinkTarget(v, entities);
    if (readOnly) {
      if (!hasValue) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: TextStyle(
                  fontSize: 11, color: Theme.of(context).colorScheme.outline)),
          EntityLink(
            targetId: linkId,
            ref: ref,
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: 12,
                decoration: linkId != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      );
    }
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
              child: EntityLink(
                targetId: linkId,
                ref: ref,
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        hasValue ? null : Theme.of(context).colorScheme.outline,
                    decoration:
                        linkId != null ? TextDecoration.underline : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
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
    if (readOnly && values.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 220,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: readOnly ? label : '$label (${values.length})',
          isDense: true,
          labelStyle: const TextStyle(fontSize: 11),
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final id in values)
              // Audit **U3**: same rule as the single-value field — tappable
              // only when the id resolves to a card that is actually here.
              EntityLink(
                targetId: entityLinkTarget(id, entities),
                ref: ref,
                child: Chip(
                  label: Text(
                    entities?[id]?.name ?? id,
                    style: TextStyle(
                      fontSize: 11,
                      decoration: entities?[id] != null
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onDeleted: readOnly
                      ? null
                      : () => onChanged([...values]..remove(id)),
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
              label: L10n.of(context)!.slSense,
              value: row['sense_ref'],
              allowedTypes: const ['sense'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'sense_ref': v}),
            ),
            _miniInt(
              label: L10n.of(context)!.slRangeFt,
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

  /// A grant cell holds either a bare entity id or a `{_ref|slug|_lookup,
  /// name}` envelope — blueprint-authored content never has ids baked in.
  /// Reading only the String shape is how a packaged grant renders as an
  /// empty chip row (audit U1).
  List<String> _readStrList(Map row, String key) =>
      resolveEntityRefList(row[key], entities ?? const {});

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
        'name': '',
        'description': '',
        'granted_damage_resistances': <String>[],
        'granted_damage_immunities': <String>[],
        'granted_condition_immunities': <String>[],
        'granted_senses': <String>[],
        'granted_languages': <String>[],
        'always_prepared_spell_refs': <String>[],
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
                  label: L10n.of(context)!.lblLevel,
                  value: rowLvl,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'level': v}),
                  width: 60,
                ),
                // Every shipped row carries a `name`, but this editor never
                // drew it — the class card showed a bare summary line with no
                // feature title. It matters more now that the row is the
                // single place a level-gated grant is declared.
                _miniText(
                  label: L10n.of(context)!.slFeature,
                  value: (row['name'] ?? '').toString(),
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'name': v}),
                  width: 200,
                ),
                _miniText(
                  label: L10n.of(context)!.slSummary,
                  value: (row['description'] ?? '').toString(),
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'description': v}),
                  width: 380,
                  markdown: true,
                ),
                if (gateMiss)
                  Tooltip(
                    message:
                        L10n.of(context)!.slRowBelowGrant('$rowLvl', '$grantedAtLevel'),
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
                  label: L10n.of(context)!.slResistances,
                  values: _readStrList(row, 'granted_damage_resistances'),
                  allowedTypes: const ['damage-type'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged(
                      {...row, 'granted_damage_resistances': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.slImmunities,
                  values: _readStrList(row, 'granted_damage_immunities'),
                  allowedTypes: const ['damage-type'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged(
                      {...row, 'granted_damage_immunities': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.slConditionImm,
                  values: _readStrList(row, 'granted_condition_immunities'),
                  allowedTypes: const ['condition'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged(
                      {...row, 'granted_condition_immunities': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.slSenses,
                  values: _readStrList(row, 'granted_senses'),
                  allowedTypes: const ['sense'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_senses': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.slLanguages,
                  values: _readStrList(row, 'granted_languages'),
                  allowedTypes: const ['language'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_languages': v}),
                ),
                // R5 / F-pass0-08: a domain / circle spell list is level-gated
                // by the row it sits on, so it is authored here and not on a
                // separate feat card.
                _MiniRelationListField(
                  label: L10n.of(context)!.slAlwaysPrepared,
                  values: _readStrList(row, 'always_prepared_spell_refs'),
                  allowedTypes: const ['spell'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'always_prepared_spell_refs': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.wizardStepFeats,
                  values: _readStrList(row, 'granted_feat_refs'),
                  allowedTypes: const ['feat'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_feat_refs': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.slTraits,
                  values: _readStrList(row, 'granted_trait_refs'),
                  allowedTypes: const ['trait'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_trait_refs': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.slActions,
                  values: _readStrList(row, 'granted_action_refs'),
                  allowedTypes: const ['creature-action'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_action_refs': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.slBonusActions,
                  values: _readStrList(row, 'granted_bonus_action_refs'),
                  allowedTypes: const ['creature-action'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) =>
                      onRowChanged({...row, 'granted_bonus_action_refs': v}),
                ),
                _MiniRelationListField(
                  label: L10n.of(context)!.slReactions,
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
              label: L10n.of(context)!.slKind,
              value: row['kind'],
              options: _spellEffectKinds,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'kind': v}),
              width: 120,
            ),
            _miniText(
              label: L10n.of(context)!.slDice,
              value: (row['dice'] ?? '').toString(),
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'dice': v}),
              width: 90,
            ),
            _MiniRelationField(
              label: L10n.of(context)!.slDamageType,
              value: row['type_ref'],
              allowedTypes: const ['damage-type'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'type_ref': v}),
            ),
            _MiniRelationField(
              label: L10n.of(context)!.slSaveAbility,
              value: row['save_ability_ref'],
              allowedTypes: const ['ability'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'save_ability_ref': v}),
            ),
            _miniEnum(
              label: L10n.of(context)!.slSaveEffect,
              value: row['save_effect'],
              options: _spellSaveEffects,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'save_effect': v ?? ''}),
              width: 110,
            ),
            _MiniRelationListField(
              label: L10n.of(context)!.sessionConditions,
              values: condRefs,
              allowedTypes: const ['condition'],
              entities: entities,
              ref: ref,
              readOnly: readOnly,
              onChanged: (v) => onRowChanged({...row, 'condition_refs': v}),
            ),
            _miniText(
              label: L10n.of(context)!.slScalingDice,
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
                    label: Text(L10n.of(context)!.slAddGroup,
                        style: const TextStyle(fontSize: 11)),
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
                      : L10n.of(context)!.slNoGroups,
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
                  label: L10n.of(context)!.lblLabel,
                  value: (group['label'] ?? '').toString(),
                  readOnly: readOnly,
                  onChanged: (s) => writeGroup({...group, 'label': s}),
                  width: 180,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniText(
                    label: L10n.of(context)!.notifInputPrompt,
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
                    tooltip: L10n.of(context)!.chatMenuDeleteGroup,
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
                  label: Text(L10n.of(context)!.notifAddOption,
                      style: const TextStyle(fontSize: 11)),
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
                    label: L10n.of(context)!.lblLabel,
                    value: (option['label'] ?? '').toString(),
                    readOnly: readOnly,
                    onChanged: (s) => writeOption({...option, 'label': s}),
                    width: 280,
                  ),
                ),
                const SizedBox(width: 6),
                _miniInt(
                  label: L10n.of(context)!.slGoldGp,
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
                    tooltip: L10n.of(context)!.slDeleteOption,
                    onPressed: removeOption,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var ii = 0; ii < items.length; ii++)
              _buildItem(context, option, writeOption, items, ii),
            if (!readOnly)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 6),
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 12),
                  label: Text(L10n.of(context)!.slAddItem,
                      style: const TextStyle(fontSize: 10)),
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

  Widget _buildItem(BuildContext context,
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
            label: L10n.of(context)!.slItem,
            value: refId,
            allowedTypes: _kItemPickAllowedTypes,
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (v) => writeItem({...item, 'ref': v}),
          ),
          const SizedBox(width: 6),
          _miniInt(
            label: L10n.of(context)!.slQty,
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
              tooltip: L10n.of(context)!.slDeleteItem,
              onPressed: removeItem,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// resourcePoolGrants — {pool_ref, recharge, count?, count_formula?,
//   count_by_level?: {lvl: count}, class_ref?}
//
// One row per per-rest resource pool the card grants (Rage uses, Ki,
// Bardic Inspiration). Max precedence: count_by_level > count_formula >
// count — mirrors CharacterResolver / resolveResourcePoolsAt.
// ─────────────────────────────────────────────────────────────────────────

const _poolRecharges = ['', 'short_rest', 'long_rest'];

class ResourcePoolGrantsFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const ResourcePoolGrantsFieldWidget({
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
      makeEmptyRow: () => {'pool_ref': null, 'recharge': 'long_rest'},
      buildRow: (i, row, onRowChanged) {
        final table = row['count_by_level'] is Map
            ? Map<String, dynamic>.from(row['count_by_level'] as Map)
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MiniRelationField(
                  label: L10n.of(context)!.slPool,
                  value: row['pool_ref'],
                  allowedTypes: const ['resource-pool'],
                  entities: entities,
                  ref: ref,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'pool_ref': v}),
                ),
                if (row['pool_ref'] is Map)
                  _badge(
                    (row['pool_ref'] as Map)['name']?.toString() ?? 'pool',
                    Colors.teal,
                  ),
                _miniEnum(
                  label: L10n.of(context)!.slRecharge,
                  value: row['recharge']?.toString(),
                  options: _poolRecharges,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged(
                      {...row, 'recharge': (v == null || v.isEmpty) ? null : v}),
                  width: 120,
                ),
                _miniInt(
                  label: L10n.of(context)!.slUses,
                  value: row['count'] is int ? row['count'] as int : null,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'count': v}),
                  width: 70,
                ),
                _miniText(
                  label: L10n.of(context)!.slFormula,
                  value: row['count_formula']?.toString() ?? '',
                  readOnly: readOnly,
                  width: 190,
                  onChanged: (s) => onRowChanged(
                      {...row, 'count_formula': s.isEmpty ? null : s}),
                ),
              ],
            ),
            _LevelValueTableEditor(
              title: L10n.of(context)!.slUsesByLevel,
              table: table,
              classRefName: row['class_ref'] is Map
                  ? (row['class_ref'] as Map)['name']?.toString()
                  : null,
              readOnly: readOnly,
              onChanged: (m) {
                final next = {...row};
                if (m == null || m.isEmpty) {
                  next.remove('count_by_level');
                } else {
                  next['count_by_level'] = m;
                }
                onRowChanged(next);
              },
            ),
          ],
        );
      },
    );
  }
}

/// Compact `{level: value}` table editor shared by the resource-pool rows.
/// Renders nothing in read-only mode when the table is empty.
class _LevelValueTableEditor extends StatelessWidget {
  final String title;
  final Map<String, dynamic>? table;
  final String? classRefName;
  final bool readOnly;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const _LevelValueTableEditor({
    required this.title,
    required this.table,
    required this.classRefName,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = table;
    if ((t == null || t.isEmpty) && readOnly) return const SizedBox.shrink();
    final entries = (t ?? const <String, dynamic>{}).entries.toList()
      ..sort((a, b) =>
          (int.tryParse(a.key) ?? 0).compareTo(int.tryParse(b.key) ?? 0));
    final suffix = classRefName == null ? '' : ' ($classRefName level)';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$title$suffix:',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline)),
          for (final e in entries)
            InputChip(
              label: Text('L${e.key} → ${e.value}',
                  style: const TextStyle(fontSize: 11)),
              onDeleted: readOnly
                  ? null
                  : () {
                      final next = {...?t}..remove(e.key);
                      onChanged(next);
                    },
              visualDensity: VisualDensity.compact,
            ),
          if (!readOnly)
            _AddLevelValueButton(
              onAdd: (lvl, v) => onChanged({...?t, '$lvl': v}),
            ),
        ],
      ),
    );
  }
}

class _AddLevelValueButton extends StatefulWidget {
  final void Function(int level, int value) onAdd;
  const _AddLevelValueButton({required this.onAdd});

  @override
  State<_AddLevelValueButton> createState() => _AddLevelValueButtonState();
}

class _AddLevelValueButtonState extends State<_AddLevelValueButton> {
  final _lvl = TextEditingController();
  final _val = TextEditingController();

  @override
  void dispose() {
    _lvl.dispose();
    _val.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          child: TextField(
            controller: _lvl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
                labelText: L10n.of(context)!.lblLvl,
                isDense: true,
                labelStyle: const TextStyle(fontSize: 10)),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 44,
          child: TextField(
            controller: _val,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
                labelText: L10n.of(context)!.slValShort,
                isDense: true,
                labelStyle: const TextStyle(fontSize: 10)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 16),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final lvl = int.tryParse(_lvl.text.trim());
            final v = int.tryParse(_val.text.trim());
            if (lvl == null || v == null) return;
            widget.onAdd(lvl, v);
            _lvl.clear();
            _val.clear();
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// spellsAtLevel — {spell_ref, at_level, is_cantrip?, uses_per_long_rest?}
//
// The level-gated sibling of `granted_spell_refs`: one row per innate spell
// that unlocks as the character levels (Drow's Faerie Fire at 3, Darkness at
// 5). `CharacterResolver.applyGrantsFrom` skips rows above the character's
// level and turns `uses_per_long_rest` into a daily counter pool.
// ─────────────────────────────────────────────────────────────────────────

class SpellsAtLevelFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const SpellsAtLevelFieldWidget({
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
    return _StructuredListShell(
      schema: schema,
      rows: _coerceRows(value),
      readOnly: readOnly,
      onChanged: onChanged,
      makeEmptyRow: () => {'spell_ref': null, 'at_level': 1},
      buildRow: (i, row, onRowChanged) => Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _MiniRelationField(
            label: L10n.of(context)!.slSpell,
            value: row['spell_ref'],
            allowedTypes: const ['spell'],
            entities: entities,
            ref: ref,
            readOnly: readOnly,
            onChanged: (v) => onRowChanged({...row, 'spell_ref': v}),
          ),
          if (row['spell_ref'] is Map)
            _badge(
              (row['spell_ref'] as Map)['name']?.toString() ?? 'spell',
              Colors.indigo,
            ),
          _miniInt(
            label: L10n.of(context)!.slAtLevel,
            value: row['at_level'] is int ? row['at_level'] as int : null,
            readOnly: readOnly,
            onChanged: (v) => onRowChanged({...row, 'at_level': v ?? 1}),
            width: 90,
          ),
          _miniInt(
            label: L10n.of(context)!.slUsesPerLongRest,
            value: row['uses_per_long_rest'] is int
                ? row['uses_per_long_rest'] as int
                : null,
            readOnly: readOnly,
            onChanged: (v) {
              final next = {...row};
              if (v == null || v <= 0) {
                next.remove('uses_per_long_rest');
              } else {
                next['uses_per_long_rest'] = v;
              }
              onRowChanged(next);
            },
            width: 120,
          ),
          if (!readOnly || row['is_cantrip'] == true)
            FilterChip(
              label: Text(L10n.of(context)!.slCantrip, style: const TextStyle(fontSize: 11)),
              selected: row['is_cantrip'] == true,
              onSelected: readOnly
                  ? null
                  : (sel) {
                      final next = {...row};
                      if (sel) {
                        next['is_cantrip'] = true;
                      } else {
                        next.remove('is_cantrip');
                      }
                      onRowChanged(next);
                    },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// playerChoices — {group_id, label, prompt, pick_kind, pick, options?,
//   list_group_id?, spell_level?}
//
// One row per deferred "pick N of these" decision a card queues when taken
// (Magic Initiate's spell list + cantrips + level-1 spell, Skilled's three
// skills). `pending_choices.dart` reads these rows to queue prompts; the
// resolver dialog / wizard render the actual pickers.
// ─────────────────────────────────────────────────────────────────────────

const _playerChoicePickKinds = [
  'enum',
  'skill',
  'skill_or_tool',
  'tool_category',
  'spell_from_list',
];

class PlayerChoicesFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const PlayerChoicesFieldWidget({
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
        'group_id': '',
        'label': '',
        'pick_kind': 'enum',
        'pick': 1,
      },
      buildRow: (i, row, onRowChanged) {
        final options = row['options'] is List
            ? List<Map<String, dynamic>>.from(
                (row['options'] as List).whereType<Map>().map(
                    (m) => Map<String, dynamic>.from(m)))
            : const <Map<String, dynamic>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _miniText(
                  label: 'Id',
                  value: row['group_id']?.toString() ?? '',
                  readOnly: readOnly,
                  width: 90,
                  onChanged: (s) => onRowChanged({...row, 'group_id': s}),
                ),
                _miniText(
                  label: L10n.of(context)!.lblLabel,
                  value: row['label']?.toString() ?? '',
                  readOnly: readOnly,
                  width: 140,
                  onChanged: (s) => onRowChanged({...row, 'label': s}),
                ),
                _miniEnum(
                  label: L10n.of(context)!.slPickFrom,
                  value: row['pick_kind']?.toString(),
                  options: _playerChoicePickKinds,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'pick_kind': v}),
                  width: 140,
                ),
                _miniInt(
                  label: L10n.of(context)!.slPicks,
                  value: row['pick'] is int ? row['pick'] as int : null,
                  readOnly: readOnly,
                  onChanged: (v) => onRowChanged({...row, 'pick': v ?? 1}),
                  width: 60,
                ),
                if (row['pick_kind'] == 'spell_from_list') ...[
                  _miniInt(
                    label: L10n.of(context)!.slSpellLevel,
                    value: row['spell_level'] is int
                        ? row['spell_level'] as int
                        : null,
                    readOnly: readOnly,
                    onChanged: (v) =>
                        onRowChanged({...row, 'spell_level': v}),
                    width: 90,
                  ),
                  _miniText(
                    label: L10n.of(context)!.slListGroupId,
                    value: row['list_group_id']?.toString() ?? '',
                    readOnly: readOnly,
                    width: 110,
                    onChanged: (s) => onRowChanged(
                        {...row, 'list_group_id': s.isEmpty ? null : s}),
                  ),
                ],
              ],
            ),
            _miniText(
              label: L10n.of(context)!.slPromptToPlayer,
              value: row['prompt']?.toString() ?? '',
              readOnly: readOnly,
              width: 420,
              onChanged: (s) =>
                  onRowChanged({...row, 'prompt': s.isEmpty ? null : s}),
            ),
            if (row['pick_kind'] == 'enum')
              _ChoiceOptionsEditor(
                options: options,
                readOnly: readOnly,
                onChanged: (list) => onRowChanged(
                    list.isEmpty
                        ? ({...row}..remove('options'))
                        : {...row, 'options': list}),
              ),
          ],
        );
      },
    );
  }
}

/// Editor for an enum choice row's `options: [{id, label}]`.
class _ChoiceOptionsEditor extends StatelessWidget {
  final List<Map<String, dynamic>> options;
  final bool readOnly;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const _ChoiceOptionsEditor({
    required this.options,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty && readOnly) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(L10n.of(context)!.slOptionsColon,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline)),
          for (var i = 0; i < options.length; i++)
            InputChip(
              label: Text(
                options[i]['label']?.toString() ??
                    options[i]['id']?.toString() ??
                    '',
                style: const TextStyle(fontSize: 11),
              ),
              onDeleted: readOnly
                  ? null
                  : () {
                      final next = [...options]..removeAt(i);
                      onChanged(next);
                    },
              visualDensity: VisualDensity.compact,
            ),
          if (!readOnly)
            _AddChoiceOptionButton(
              onAdd: (id) => onChanged(
                  [...options, {'id': id, 'label': id}]),
            ),
        ],
      ),
    );
  }
}

class _AddChoiceOptionButton extends StatefulWidget {
  final ValueChanged<String> onAdd;
  const _AddChoiceOptionButton({required this.onAdd});

  @override
  State<_AddChoiceOptionButton> createState() =>
      _AddChoiceOptionButtonState();
}

class _AddChoiceOptionButtonState extends State<_AddChoiceOptionButton> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 110,
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
                labelText: L10n.of(context)!.slNewOption,
                isDense: true,
                labelStyle: const TextStyle(fontSize: 10)),
            onSubmitted: (s) {
              if (s.trim().isEmpty) return;
              widget.onAdd(s.trim());
              _ctrl.clear();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 16),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final s = _ctrl.text.trim();
            if (s.isEmpty) return;
            widget.onAdd(s);
            _ctrl.clear();
          },
        ),
      ],
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
// grants through the same `applyGrantsFrom` reader every other card uses.
// Keys beyond the ones listed above (numeric bonuses, resource pools,
// mechanical notes) belong on a first-class `subspecies` entity rather than
// a nested option row; authors needing them should promote the row.
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
                    label: Text(L10n.of(context)!.slAddLineage,
                        style: const TextStyle(fontSize: 11)),
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
                  readOnly ? '—' : L10n.of(context)!.slNoLineages,
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
        // Lazy viewport: the row unmounts when scrolled off. A PageStorageKey
        // makes ExpansionTile restore its expanded state instead of collapsing.
        key: PageStorageKey('lineage_$ri'),
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
                tooltip: L10n.of(context)!.slDeleteLineage,
                onPressed: removeRow,
              ),
        children: [
          Row(
            children: [
              _miniText(
                label: L10n.of(context)!.sessionName,
                value: name,
                readOnly: readOnly,
                onChanged: (s) => writeRow({...row, 'name': s}),
                width: 200,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniText(
                  label: L10n.of(context)!.listingDescriptionLabel,
                  value: description,
                  readOnly: readOnly,
                  onChanged: (s) =>
                      writeRow({...row, 'description': s}),
                  width: 400,
                  markdown: true,
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
                  EntityLink(
                    targetId: entityLinkTarget(values[i], entities),
                    ref: ref,
                    child: Chip(
                      label: Text(
                        entities?[values[i]]?.name ?? values[i],
                        style: TextStyle(
                          fontSize: 11,
                          decoration: entityLinkTarget(values[i], entities) !=
                                  null
                              ? TextDecoration.underline
                              : null,
                        ),
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
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            L10n.of(context)!.btnAdd,
                            style: const TextStyle(fontSize: 11),
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
