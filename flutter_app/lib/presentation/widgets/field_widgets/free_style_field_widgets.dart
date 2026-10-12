import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/services/free_field_styles.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../dice/dice_fab.dart';
import '../dice/dice_log.dart';
import '../srd_text.dart';
import 'entity_link.dart';
import 'field_widget_factory.dart' show ProficiencyDot;

/// Card widgets of the free template's combined styles (docs/free-template/
/// DESIGN.md §8.1 Table and Skill table, §8.2 Stat table). Only free
/// templates declare these types; the shapes and readers are in
/// `free_field_styles.dart`.

String _signed(int n) => n >= 0 ? '+$n' : '−${-n}';

// ------------------------------------------------------------ stat table

class StatTableFieldWidget extends StatefulWidget {
  const StatTableFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  @override
  State<StatTableFieldWidget> createState() => _StatTableFieldWidgetState();
}

class _StatTableFieldWidgetState extends State<StatTableFieldWidget> {
  final _controllers = <String, TextEditingController>{};

  Map<String, dynamic> get _scores => widget.value is Map
      ? Map<String, dynamic>.from(widget.value as Map)
      : <String, dynamic>{};

  String _text(String key) => _scores[key]?.toString() ?? '';

  TextEditingController _controller(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: _text(key)),
  );

  @override
  void didUpdateWidget(covariant StatTableFieldWidget old) {
    super.didUpdateWidget(old);
    for (final e in _controllers.entries) {
      final t = _text(e.key);
      // Only a real change lands, so text being typed ("+3", "") stays.
      if (int.tryParse(e.value.text.trim()) != int.tryParse(t)) {
        e.value.text = t;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String key, String text) {
    final scores = _scores;
    final v = int.tryParse(text.trim());
    if (v == null) {
      scores.remove(key);
    } else {
      scores[key] = v;
    }
    widget.onChanged(scores);
  }

  @override
  Widget build(BuildContext context) {
    final spec = StatTableSpec.of(widget.schema);
    final outline = Theme.of(context).colorScheme.outline;
    final scores = _scores;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.schema.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (spec.stats.isEmpty)
              Text(
                L10n.of(context)!.rowsEmpty,
                style: TextStyle(color: outline, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in spec.stats)
                    SizedBox(
                      width: 56,
                      child: Column(
                        children: [
                          Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (widget.readOnly)
                            Text(
                              _text(s.key).isEmpty ? '—' : _text(s.key),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            TextField(
                              key: ValueKey(
                                'stat_${widget.schema.fieldKey}_${s.key}',
                              ),
                              controller: _controller(s.key),
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                  ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (v) => _set(s.key, v),
                            ),
                          if (spec.showModifier) ...[
                            const SizedBox(height: 2),
                            Text(switch (scores[s.key]) {
                              final num n => _signed(spec.modifier(n.toInt())),
                              _ => '—',
                            }, style: TextStyle(fontSize: 11, color: outline)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- table

class TableFieldWidget extends StatelessWidget {
  const TableFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
  });

  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  static double _width(TableColumnType t) => switch (t) {
    TableColumnType.text => 140,
    TableColumnType.relation => 170,
    TableColumnType.choice => 120,
    TableColumnType.dice => 80,
    TableColumnType.number => 64,
    TableColumnType.check => 44,
  };

  static bool _grows(TableColumnType t) =>
      t == TableColumnType.text || t == TableColumnType.relation;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final outline = Theme.of(context).colorScheme.outline;
    final spec = TableSpec.of(schema);
    final rows = tableRows(spec, value);
    final canAddRows = !spec.fixedRows && !readOnly;

    void write(List<Map<String, dynamic>> next) =>
        onChanged(tableValue(spec, next, previous: value));

    // Free rows get ids when rows come or go, so each row's inputs keep
    // their own text (SRD rows are stored without one).
    List<Map<String, dynamic>> withIds(List<Map<String, dynamic>> list) {
      final out = <Map<String, dynamic>>[];
      for (final r in list) {
        out.add(
          r[tableRowId] == null
              ? {
                  ...r,
                  tableRowId: nextTableRowId([...list, ...out]),
                }
              : r,
        );
      }
      return out;
    }

    Widget header() => Row(
      children: [
        for (final c in spec.columns)
          _Cell(
            width: _width(c.type),
            grows: _grows(c.type),
            child: Text(
              c.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign:
                  c.type == TableColumnType.text ||
                      c.type == TableColumnType.relation
                  ? TextAlign.start
                  : TextAlign.center,
              style: TextStyle(fontSize: 10, color: outline),
            ),
          ),
        if (canAddRows) const SizedBox(width: 36),
      ],
    );

    Widget row(int i) {
      final r = rows[i];
      final rowKey = r[tableRowId] ?? 'i$i';
      void setCell(String key, Object? v) {
        final next = [...rows];
        next[i] = {...r, key: v};
        write(next);
      }

      return Row(
        children: [
          for (final c in spec.columns)
            _Cell(
              width: _width(c.type),
              grows: _grows(c.type),
              child: _cell(
                context,
                c,
                r,
                key: '${schema.fieldKey}_${rowKey}_${c.key}',
                editable: !readOnly && !(spec.fixedRows && c.locked),
                onChanged: (v) => setCell(c.key, v),
              ),
            ),
          if (canAddRows)
            SizedBox(
              width: 36,
              child: IconButton(
                tooltip: l10n.btnDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => write(withIds([...rows]..removeAt(i))),
              ),
            ),
        ],
      );
    }

    final body = LayoutBuilder(
      builder: (context, box) {
        final needed =
            spec.columns.fold<double>(0, (s, c) => s + _width(c.type)) +
            (canAddRows ? 36 : 0);
        final fits = needed <= box.maxWidth;
        final table = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(),
            const Divider(height: 8),
            if (rows.isEmpty)
              Text(
                l10n.rowsEmpty,
                style: TextStyle(color: outline, fontSize: 12),
              )
            else
              for (var i = 0; i < rows.length; i++) row(i),
          ],
        );
        if (fits) return _Fit(fits: true, child: table);
        // Phone: the table keeps its column widths and scrolls sideways.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: needed,
            child: _Fit(fits: false, child: table),
          ),
        );
      },
    );

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
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (canAddRows)
                  IconButton(
                    tooltip: l10n.tplAddRow,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () =>
                        write(withIds([...rows, <String, dynamic>{}])),
                  ),
              ],
            ),
            if (spec.columns.isNotEmpty) body,
          ],
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    TableColumn c,
    Map<String, dynamic> r, {
    required String key,
    required bool editable,
    required ValueChanged<Object?> onChanged,
  }) {
    final v = r[c.key];
    const style = TextStyle(fontSize: 12);
    Widget plain(String text, {TextAlign align = TextAlign.center}) => Text(
      text,
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    switch (c.type) {
      case TableColumnType.check:
        return Checkbox(
          value: v == true,
          visualDensity: VisualDensity.compact,
          onChanged: editable ? (b) => onChanged(b == true) : null,
        );
      case TableColumnType.choice:
        if (!editable) return plain('${v ?? ''}');
        return _Dropdown(
          value: c.options.contains(v) ? v as String : null,
          items: {for (final o in c.options) o: o},
          onChanged: onChanged,
        );
      case TableColumnType.relation:
        return _RelationCell(
          value: v,
          targets: c.targets,
          editable: editable,
          entities: entities,
          widgetRef: ref,
          onChanged: onChanged,
        );
      case TableColumnType.number:
        if (!editable) return plain(v == null ? '' : '$v');
        return _TextCell(
          key: ValueKey(key),
          initial: v == null ? '' : '$v',
          number: true,
          onChanged: (s) {
            final t = s.trim().replaceAll(',', '.');
            onChanged(int.tryParse(t) ?? double.tryParse(t));
          },
        );
      case TableColumnType.text:
      case TableColumnType.dice:
        final align = c.type == TableColumnType.text
            ? TextAlign.start
            : TextAlign.center;
        if (!editable) return plain('${v ?? ''}', align: align);
        return _TextCell(
          key: ValueKey(key),
          initial: '${v ?? ''}',
          align: align,
          onChanged: (s) => onChanged(s.isEmpty ? null : s),
        );
    }
  }
}

// ----------------------------------------------------------- skill table

/// Skills / saving throws as the SRD's table shows them (D32): proficient
/// and expertise marks, the name, the row's stat (a card may pick another),
/// misc and the total; a tap on a row rolls d20 + total.
class SkillTableFieldWidget extends StatelessWidget {
  const SkillTableFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.ref,
    this.entityFields,
    this.entityName,
    this.categoryFields = const [],
  });

  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final WidgetRef? ref;

  /// The card's values: the stat scores and the bonus are read from them.
  final Map<String, dynamic>? entityFields;

  /// A roll goes to the session log under this name.
  final String? entityName;

  /// The category's fields: the stat table and the bonus field are here.
  final List<FieldSchema> categoryFields;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final spec = SkillTableSpec.of(schema);
    final table = spec.table;
    final rows = tableRows(table, value);
    final card = entityFields ?? const <String, dynamic>{};
    final stats = switch (skillStatField(spec, categoryFields)) {
      final st? => StatTableSpec.of(st).stats,
      null => const <StatEntry>[],
    };
    String statLabel(Object? k) =>
        stats.where((s) => s.key == k).firstOrNull?.label ?? '${k ?? ''}';
    final bonusField = categoryFields
        .where((f) => f.fieldKey == spec.bonus)
        .firstOrNull;
    final isSave = schema.fieldKey.startsWith('sav');

    void setCell(int i, String key, Object? v) {
      final next = [...rows];
      next[i] = {...rows[i], key: v};
      onChanged(tableValue(table, next, previous: value));
    }

    Widget head(String text, {double? width, TextAlign? align}) {
      final t = Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 10, color: outline),
      );
      return width == null
          ? Expanded(flex: 4, child: t)
          : SizedBox(width: width, child: t);
    }

    Widget statCell(int i, Object? ability) {
      final label = statLabel(ability);
      final text = Text(
        label.isEmpty ? '—' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, color: outline),
      );
      if (readOnly || !spec.statEditable || stats.isEmpty) return text;
      return PopupMenuButton<String>(
        tooltip: l10n.tplSkillRowStat,
        padding: EdgeInsets.zero,
        onSelected: (k) => setCell(i, 'ability', k),
        itemBuilder: (_) => [
          for (final s in stats)
            PopupMenuItem(value: s.key, height: 36, child: Text(s.label)),
        ],
        child: text,
      );
    }

    Widget row(int i) {
      final r = rows[i];
      // SRD names read in the app's language; a card may rename a row
      // when the template lets it.
      final name = spec.nameEditable && '${r['label'] ?? ''}'.isNotEmpty
          ? '${r['label']}'
          : srdText(context, isSave ? 'ability' : 'skill', '${r['name'] ?? ''}');
      final proficient = r['proficient'] == true;
      final expertise = r['expertise'] == true;
      final misc = switch (r['misc']) {
        final num n => n.toInt(),
        final String s => int.tryParse(s.trim()) ?? 0,
        _ => 0,
      };
      final total = skillTotal(spec, r, card: card, fields: categoryFields);
      final widgetRef = ref;
      // Tap a row: d20 + its total. The marks and the misc field sit
      // deeper, so they keep their own taps.
      return InkWell(
        hoverColor: Colors.transparent,
        onTap: widgetRef == null
            ? null
            : () => rollDice(
                context,
                widgetRef,
                const {'d20': 1},
                modifier: total,
                label: name,
                kind: isSave ? DiceRollKind.save : DiceRollKind.skill,
                character: entityName,
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              ProficiencyDot(
                active: proficient,
                tooltip: l10n.lblProficient,
                onTap: readOnly
                    ? null
                    : () => setCell(i, 'proficient', !proficient),
              ),
              ProficiencyDot(
                active: expertise,
                doubled: true,
                tooltip: l10n.lblExpertise,
                onTap: readOnly
                    ? null
                    : () => setCell(i, 'expertise', !expertise),
              ),
              Expanded(
                flex: 4,
                child: spec.nameEditable && !readOnly
                    ? TextFormField(
                        key: ValueKey(
                          'st_${schema.fieldKey}_${r[tableRowId]}_label',
                        ),
                        initialValue: name,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setCell(
                          i,
                          'label',
                          v.trim().isEmpty ? null : v.trim(),
                        ),
                      )
                    : Text(name, style: const TextStyle(fontSize: 12)),
              ),
              SizedBox(width: 44, child: statCell(i, r['ability'])),
              SizedBox(
                width: 44,
                child: TextFormField(
                  key: ValueKey('st_${schema.fieldKey}_${r[tableRowId]}_misc'),
                  initialValue: misc == 0 ? '' : '$misc',
                  readOnly: readOnly,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                  onChanged: (v) => setCell(i, 'misc', int.tryParse(v.trim())),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  _signed(total),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: proficient || expertise
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                  child: Text(schema.label, style: theme.textTheme.titleSmall),
                ),
                if (bonusField != null)
                  Text(
                    '${bonusField.label} ${_signed(skillBonus(spec, card))}',
                    style: TextStyle(fontSize: 11, color: outline),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 48),
                head(l10n.lblSkill),
                head(l10n.lblAbilShort, width: 44),
                head(l10n.lblMisc, width: 44, align: TextAlign.center),
                head(l10n.lblTotal, width: 40, align: TextAlign.right),
              ],
            ),
            const Divider(height: 8),
            if (rows.isEmpty)
              Text(
                l10n.rowsEmpty,
                style: TextStyle(color: outline, fontSize: 12),
              )
            else
              for (var i = 0; i < rows.length; i++) row(i),
          ],
        ),
      ),
    );
  }
}

/// Whether the table fits its card (columns may grow) or scrolls sideways
/// (fixed widths).
class _Fit extends InheritedWidget {
  const _Fit({required this.fits, required super.child});

  final bool fits;

  @override
  bool updateShouldNotify(_Fit old) => fits != old.fits;
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.grows, required this.child});

  final double width;
  final bool grows;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fits =
        context.dependOnInheritedWidgetOfExactType<_Fit>()?.fits ?? true;
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: child,
    );
    if (fits && grows) {
      return Expanded(flex: width.round(), child: padded);
    }
    return SizedBox(width: width, child: padded);
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({
    super.key,
    required this.initial,
    required this.onChanged,
    this.number = false,
    this.align = TextAlign.center,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final bool number;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initial,
    textAlign: align,
    keyboardType: number
        ? const TextInputType.numberWithOptions(signed: true, decimal: true)
        : null,
    style: const TextStyle(fontSize: 12),
    decoration: const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    ),
    onChanged: onChanged,
  );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final Map<String, String> items;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: value,
      isExpanded: true,
      isDense: true,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}

/// A card link cell: the linked card's name (a link when the card is here)
/// and, while editing, a picker and a clear button.
class _RelationCell extends StatelessWidget {
  const _RelationCell({
    required this.value,
    required this.targets,
    required this.editable,
    required this.entities,
    required this.widgetRef,
    required this.onChanged,
  });

  final Object? value;
  final List<String> targets;
  final bool editable;
  final Map<String, Entity>? entities;
  final WidgetRef? widgetRef;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final id = entityLinkTarget(v, entities);
    final name = id != null
        ? srdName(context, entities![id]!)
        : switch (v) {
            final Map m => srdRefName(context, m) ?? '${m['name'] ?? ''}',
            final String s => s,
            _ => '',
          };
    final hasValue = name.isNotEmpty;
    final ref = widgetRef;
    return Row(
      children: [
        Expanded(
          child: EntityLink(
            targetId: id,
            ref: ref,
            entities: entities,
            child: Text(
              hasValue ? name : '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                decoration: id != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
        if (editable && hasValue)
          InkWell(
            onTap: () => onChanged(null),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14),
            ),
          ),
        if (editable && ref != null)
          InkWell(
            onTap: () async {
              final picked = await showEntitySelectorDialog(
                context: context,
                ref: ref,
                allowedTypes: targets.isEmpty ? null : targets,
                includeBuiltinSrd: true,
              );
              if (picked != null && picked.isNotEmpty) onChanged(picked.first);
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.search, size: 14),
            ),
          ),
      ],
    );
  }
}
