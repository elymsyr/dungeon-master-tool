import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/services/free_field_styles.dart';
import '../../../domain/services/free_grants.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../dice/dice_fab.dart';
import '../dice/dice_log.dart';
import '../../theme/dm_tool_colors.dart';
import '../class_resources_card.dart' show UsePip;
import '../srd_text.dart';
import 'entity_link.dart';
import 'field_widget_factory.dart' show FieldWidgetFactory, ProficiencyDot;

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

// ------------------------------------------------------ resource, combat

/// A whole number: a box to type in (unless [readOnly]) and, with
/// [buttons], − / + beside it.
class _NumberBox extends StatefulWidget {
  const _NumberBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
    this.buttons = false,
    this.label,
    this.bold = false,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final bool readOnly;
  final bool buttons;
  final String? label;
  final bool bold;

  static const _width = 52.0;

  @override
  State<_NumberBox> createState() => _NumberBoxState();
}

class _NumberBoxState extends State<_NumberBox> {
  late final _text = TextEditingController(text: _show(widget.value));

  static String _show(int? v) => v?.toString() ?? '';

  @override
  void didUpdateWidget(covariant _NumberBox old) {
    super.didUpdateWidget(old);
    // Only a real change lands, so text being typed ("-", "") stays.
    if (int.tryParse(_text.text.trim()) != widget.value) {
      _text.text = _show(widget.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _button(IconData icon, int delta, String tip) => IconButton(
    tooltip: tip,
    icon: Icon(icon, size: 18),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    onPressed: () => widget.onChanged((widget.value ?? 0) + delta),
  );

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: widget.bold ? 16 : 14,
      fontWeight: widget.bold ? FontWeight.bold : FontWeight.w500,
    );
    final box = widget.readOnly
        ? SizedBox(
            width: _NumberBox._width,
            child: Text(
              widget.value?.toString() ?? '—',
              textAlign: TextAlign.center,
              style: style,
            ),
          )
        : SizedBox(
            width: _NumberBox._width,
            child: TextField(
              controller: _text,
              textAlign: TextAlign.center,
              style: style,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: widget.label,
                floatingLabelAlignment: FloatingLabelAlignment.center,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 4,
                ),
              ),
              onChanged: (t) => widget.onChanged(int.tryParse(t.trim())),
            ),
          );
    if (!widget.buttons || widget.readOnly) return box;
    final l10n = L10n.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(Icons.remove, -1, l10n.freeDecrease),
        box,
        _button(Icons.add, 1, l10n.freeIncrease),
      ],
    );
  }
}

/// Resource (DESIGN §8.3): current / max as numbers or boxes. The current
/// value stays within 0 … max; the max is the card's own.
class ResourceFieldWidget extends StatelessWidget {
  const ResourceFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.play = false,
  });

  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  /// With [readOnly], the current value still changes; the max does not.
  final bool play;

  /// More boxes than this read better as numbers.
  static const _maxBoxes = 30;

  @override
  Widget build(BuildContext context) {
    final spec = ResourceSpec.of(schema);
    final v = resourceValue(value);
    final max = v.max;
    final current = v.current;
    void put(int? cur, int? m) {
      final top = m ?? cur;
      onChanged(
        resourceJson((
          current: cur == null || top == null ? cur : cur.clamp(0, top),
          max: m,
        )),
      );
    }

    final boxes = spec.boxes && max != null && max > 0 && max <= _maxBoxes;
    final fixed = readOnly && !play;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (boxes)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < max; i++)
                        UsePip(
                          key: ValueKey('res_${schema.fieldKey}_$i'),
                          filled: i < (current ?? 0),
                          color: palette.featureCardAccent,
                          borderRadius: palette.br,
                          // A filled box spends it, an empty one takes it
                          // back (the class resource tracker's rule).
                          onTap: fixed
                              ? null
                              : () => put(i < (current ?? 0) ? i : i + 1, max),
                        ),
                    ],
                  )
                // Boxes wait for a max; no counter to type into meanwhile.
                else if (!spec.boxes)
                  _NumberBox(
                    key: ValueKey('res_${schema.fieldKey}_current'),
                    value: current,
                    readOnly: fixed,
                    buttons: true,
                    bold: true,
                    onChanged: (n) => put(n, max),
                  ),
                if (!spec.boxes) const Text('/'),
                // The box count is the max; its box shows only while editing.
                if (!boxes || !readOnly)
                  _NumberBox(
                    key: ValueKey('res_${schema.fieldKey}_max'),
                    value: max,
                    readOnly: readOnly,
                    label: L10n.of(context)!.freeMax,
                    onChanged: (n) => put(current, n),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Combat stats (DESIGN §8.6): HP / Max HP, then the template's values —
/// numbers, dice and one card list (conditions). [value] is the block as
/// `combatStatsValue` reads it, so an edit also stores what was read from
/// an SRD monster's flat fields.
class CombatBlockFieldWidget extends StatelessWidget {
  const CombatBlockFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
    this.play = false,
  });

  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  /// With [readOnly], HP and the editable numbers still change.
  final bool play;

  @override
  Widget build(BuildContext context) {
    final spec = CombatStatsSpec.of(schema);
    final fixed = readOnly && !play;
    final stats = value is Map
        ? Map<String, dynamic>.from(value as Map)
        : <String, dynamic>{};
    void put(String key, Object? v) => onChanged({...stats, key: v});
    final maxHp = combatNumber(stats[combatMaxHpKey]);
    String k(String key) => 'cb_${schema.fieldKey}_$key';

    Widget labelled(String label, Widget child) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );

    Widget valueTile(CombatValue cv) => switch (cv.type) {
      CombatValueType.number => labelled(
        cv.label,
        _NumberBox(
          key: ValueKey(k(cv.key)),
          value: combatNumber(stats[cv.key]),
          readOnly: fixed || !cv.editable,
          onChanged: (n) => put(cv.key, n),
        ),
      ),
      CombatValueType.dice => labelled(
        cv.label,
        SizedBox(
          width: 84,
          child: readOnly
              ? Text(
                  '${stats[cv.key] ?? '—'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                )
              : _TextCell(
                  key: ValueKey(k(cv.key)),
                  initial: '${stats[cv.key] ?? ''}',
                  onChanged: (t) => put(cv.key, t.trim()),
                ),
        ),
      ),
      CombatValueType.cards => const SizedBox.shrink(),
    };

    final cards = spec.values
        .where((v) => v.type == CombatValueType.cards)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                labelled(
                  spec.hpLabel,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NumberBox(
                        key: ValueKey(k(combatHpKey)),
                        value: combatNumber(stats[combatHpKey]),
                        readOnly: fixed,
                        bold: true,
                        onChanged: (n) => put(
                          combatHpKey,
                          n == null || maxHp == null ? n : n.clamp(0, maxHp),
                        ),
                      ),
                      const Text(' / '),
                      _NumberBox(
                        key: ValueKey(k(combatMaxHpKey)),
                        value: maxHp,
                        readOnly: readOnly,
                        label: L10n.of(context)!.freeMax,
                        onChanged: (n) => put(combatMaxHpKey, n),
                      ),
                    ],
                  ),
                ),
                for (final cv in spec.values)
                  if (cv.type != CombatValueType.cards) valueTile(cv),
              ],
            ),
            if (cards != null) ...[
              const SizedBox(height: 8),
              _CardList(
                label: cards.label,
                ids: [
                  for (final x in (stats[cards.key] as List?) ?? const [])
                    '$x',
                ],
                targets: cards.targets,
                readOnly: readOnly,
                entities: entities,
                widgetRef: ref,
                onChanged: (l) => put(cards.key, l),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The block's card list (conditions): chips, × to remove, + to pick more.
class _CardList extends StatelessWidget {
  const _CardList({
    required this.label,
    required this.ids,
    required this.targets,
    required this.readOnly,
    required this.entities,
    required this.widgetRef,
    required this.onChanged,
  });

  final String label;
  final List<String> ids;
  final List<String> targets;
  final bool readOnly;
  final Map<String, Entity>? entities;
  final WidgetRef? widgetRef;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final ref = widgetRef;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        for (final id in ids)
          InputChip(
            label: Text(
              switch (entityLinkTarget(id, entities)) {
                final t? => srdName(context, entities![t]!),
                null => id,
              },
              style: const TextStyle(fontSize: 12),
            ),
            visualDensity: VisualDensity.compact,
            onDeleted: readOnly
                ? null
                : () => onChanged([...ids.where((x) => x != id)]),
          ),
        if (!readOnly && ref != null)
          IconButton(
            tooltip: L10n.of(context)!.btnAdd,
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final picked = await showEntitySelectorDialog(
                context: context,
                ref: ref,
                allowedTypes: targets.isEmpty ? null : targets,
                multiSelect: true,
                excludeIds: ids,
                includeBuiltinSrd: true,
              );
              if (picked != null && picked.isNotEmpty) {
                onChanged([...ids, ...picked]);
              }
            },
          ),
      ],
    );
  }
}

/// The Pool (DESIGN §8.7, D38): what the carrier's cards grant that no
/// list takes. Resources first — name and boxes, a max the item leaves to
/// the player in a box of its own (D30) — then the rest under the giving
/// card's name, read-only. [grants] comes from the host (the character
/// sheet, a card carrying cards); [value] holds only the resources' current
/// values (V29).
class PoolFieldWidget extends StatelessWidget {
  const PoolFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.grants,
    this.entities,
    this.ref,
    this.play = false,
  });

  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  /// With [readOnly], a resource's current value still changes.
  final bool play;
  final GrantResult? grants;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  static const _maxBoxes = 30;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final g = grants;
    final muted = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.outline,
    );
    String nameOf(String id) {
      final e = entities?[id];
      return e == null ? id : srdName(context, e);
    }

    // Edit mode: take an item out of the Pool, put them all back.
    final removed = poolRemovedOf(value);
    Widget? remove(String key) => readOnly
        ? null
        : IconButton(
            key: ValueKey('pool_remove_$key'),
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.freePoolRemove,
            onPressed: () => onChanged(poolWithRemoved(value, key)),
          );

    Widget resource(PoolResource r) {
      final v = poolResourceValue(r, value);
      final max = v.max;
      final current = v.current;
      void put({int? current, int? max}) =>
          onChanged(poolStoredWith(value, r.name, current: current, max: max));
      final boxes = max != null && max > 0 && max <= _maxBoxes;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 96),
              child: Text(
                r.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (boxes)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < max; i++)
                    UsePip(
                      key: ValueKey('pool_${r.name}_$i'),
                      filled: i < (current ?? 0),
                      color: palette.featureCardAccent,
                      borderRadius: palette.br,
                      onTap: readOnly && !play
                          ? null
                          : () => put(
                              current: i < (current ?? 0) ? i : i + 1,
                            ),
                    ),
                ],
              )
            else if (max != null)
              _NumberBox(
                key: ValueKey('pool_${r.name}_current'),
                value: current,
                readOnly: readOnly && !play,
                bold: true,
                onChanged: (n) => put(current: n?.clamp(0, max)),
              ),
            // The item leaves the max to the player (D30).
            if (v.playerMax && !readOnly)
              _NumberBox(
                key: ValueKey('pool_${r.name}_max'),
                value: max,
                label: l10n.freeMax,
                onChanged: (n) => put(max: n),
              ),
            ?remove(r.name),
          ],
        ),
      );
    }

    Widget entryBody(PoolEntry e) {
      final card = e.cardId;
      if (card != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: EntityLink(
            targetId: entities?[card] == null ? null : card,
            ref: ref,
            entities: entities,
            child: Text(
              nameOf(card),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
          ),
        );
      }
      return FieldWidgetFactory.create(
        schema: e.item.asField(),
        value: e.item.value,
        readOnly: true,
        onChanged: (_) {},
        entities: entities,
        ref: ref,
      );
    }

    Widget entry(PoolEntry e) {
      final x = remove(poolEntryKey(e.fromId, e.item));
      if (x == null) return entryBody(e);
      return Row(children: [Expanded(child: entryBody(e)), x]);
    }

    final givers = <String, List<PoolEntry>>{};
    for (final e in g?.entries ?? const <PoolEntry>[]) {
      (givers[e.fromId] ??= []).add(e);
    }
    final empty = g == null || (g.resources.isEmpty && givers.isEmpty);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (empty)
              Text(l10n.freePoolEmpty, style: muted)
            else ...[
              for (final r in g.resources) resource(r),
              for (final MapEntry(key: from, value: list) in givers.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.freeGrantedFromCard(nameOf(from)),
                        style: muted.copyWith(fontWeight: FontWeight.w600),
                      ),
                      for (final e in list) entry(e),
                    ],
                  ),
                ),
            ],
            if (!readOnly && removed.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.undo, size: 16),
                label: Text(l10n.freePoolRestore(removed.length)),
                onPressed: () => onChanged(poolWithRemoved(value, null)),
              ),
          ],
        ),
      ),
    );
  }
}
