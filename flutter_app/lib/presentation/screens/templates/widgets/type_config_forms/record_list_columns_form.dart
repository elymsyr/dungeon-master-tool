import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/providers/template_editor_provider.dart';
import '../../../../../domain/entities/schema/field_schema.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'tc_shared.dart';

/// `recordList` config form (the-template-system §2.3): a generic typed table.
/// Each column has a key, label and kind (`text|int|float|dice|bool|enum|ref`);
/// `ref` columns carry allowed entity types, `enum` columns carry options. An
/// optional preset wires a bespoke renderer (spell-effects, equipment-choices…).
class RecordListColumnsForm extends ConsumerStatefulWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const RecordListColumnsForm({
    super.key,
    required this.field,
    required this.palette,
  });

  @override
  ConsumerState<RecordListColumnsForm> createState() =>
      _RecordListColumnsFormState();
}

class _RecordColumn {
  final TextEditingController keyCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController extraCtrl; // allowedTypes (ref) / options (enum)
  String kind;
  _RecordColumn({
    String key = '',
    String label = '',
    String extra = '',
    this.kind = 'text',
  })  : keyCtrl = TextEditingController(text: key),
        labelCtrl = TextEditingController(text: label),
        extraCtrl = TextEditingController(text: extra);
  void dispose() {
    keyCtrl.dispose();
    labelCtrl.dispose();
    extraCtrl.dispose();
  }
}

class _RecordListColumnsFormState extends ConsumerState<RecordListColumnsForm> {
  late List<_RecordColumn> _columns;
  late final TextEditingController _presetCtrl;

  @override
  void initState() {
    super.initState();
    final cfg = widget.field.typeConfig ?? const {};
    _columns = [];
    final cols = cfg['columns'];
    if (cols is List) {
      for (final c in cols) {
        if (c is! Map) continue;
        final kind = recordListColumnKinds.contains(c['kind'])
            ? c['kind'] as String
            : 'text';
        var extra = '';
        if (kind == 'ref' && c['allowedTypes'] is List) {
          extra = (c['allowedTypes'] as List).join(', ');
        } else if (kind == 'enum' && c['options'] is List) {
          extra = (c['options'] as List).join(', ');
        }
        _columns.add(_RecordColumn(
          key: (c['key'] ?? '').toString(),
          label: (c['label'] ?? '').toString(),
          extra: extra,
          kind: kind,
        ));
      }
    }
    if (_columns.isEmpty) {
      _columns.add(_RecordColumn(key: 'name', label: 'Name'));
    }
    _presetCtrl = TextEditingController(text: (cfg['preset'] ?? '').toString());
  }

  @override
  void dispose() {
    for (final c in _columns) {
      c.dispose();
    }
    _presetCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final columns = <Map<String, dynamic>>[];
    for (final c in _columns) {
      final col = <String, dynamic>{
        'key': fieldKeyNormalize(c.keyCtrl.text.trim()),
        'label': c.labelCtrl.text.trim(),
        'kind': c.kind,
      };
      final extras = c.extraCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (c.kind == 'ref' && extras.isNotEmpty) col['allowedTypes'] = extras;
      if (c.kind == 'enum' && extras.isNotEmpty) col['options'] = extras;
      columns.add(col);
    }
    final config = <String, dynamic>{'columns': columns};
    final preset = _presetCtrl.text.trim();
    if (preset.isNotEmpty) config['preset'] = preset;
    ref.read(templateEditorProvider.notifier).updateFieldTypeConfig(
          widget.field.categoryId,
          widget.field.fieldId,
          config,
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TcSection(
          title: 'Columns',
          subtitle: 'Typed columns the DM fills per row on each card.',
          palette: palette,
          children: [
            for (final col in _columns)
              _ColumnCard(
                column: col,
                palette: palette,
                onChanged: _emit,
                onKindChanged: (k) {
                  setState(() => col.kind = k);
                  _emit();
                },
                onRemove: _columns.length > 1
                    ? () {
                        setState(() {
                          col.dispose();
                          _columns.remove(col);
                        });
                        _emit();
                      }
                    : null,
              ),
            TcAddButton(
              label: 'Add column',
              palette: palette,
              onPressed: () {
                setState(() => _columns.add(_RecordColumn()));
                _emit();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TcSection(
          title: 'Renderer preset',
          subtitle: 'Optional — wires a bespoke renderer (e.g. equipment-choices).',
          palette: palette,
          children: [
            TcTextField(
              controller: _presetCtrl,
              hint: 'Leave blank for the generic table',
              onChanged: (_) => _emit(),
            ),
          ],
        ),
      ],
    );
  }
}

/// A single column card — responsive: the key/label/kind controls stack on
/// narrow phones and sit on one row when there's width.
class _ColumnCard extends StatelessWidget {
  final _RecordColumn column;
  final DmToolColors palette;
  final VoidCallback onChanged;
  final ValueChanged<String> onKindChanged;
  final VoidCallback? onRemove;

  const _ColumnCard({
    required this.column,
    required this.palette,
    required this.onChanged,
    required this.onKindChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final keyField = TcTextField(
      controller: column.keyCtrl,
      hint: 'key',
      onChanged: (v) {
        final n = fieldKeyNormalize(v);
        if (n != v) {
          column.keyCtrl.value = TextEditingValue(
            text: n,
            selection: TextSelection.collapsed(offset: n.length),
          );
        }
        onChanged();
      },
    );
    final labelField = TcTextField(
      controller: column.labelCtrl,
      hint: 'Label',
      onChanged: (_) => onChanged(),
    );
    final kindField = DropdownButtonFormField<String>(
      initialValue: column.kind,
      isDense: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: [
        for (final k in recordListColumnKinds)
          DropdownMenuItem(value: k, child: Text(k)),
      ],
      onChanged: (v) {
        if (v != null) onKindChanged(v);
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 96, child: keyField),
              const SizedBox(width: 8),
              Expanded(child: labelField),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: palette.dangerBtnBg,
                tooltip: 'Remove column',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 140, child: kindField),
              const SizedBox(width: 8),
              if (column.kind == 'ref' || column.kind == 'enum')
                Expanded(
                  child: TcTextField(
                    controller: column.extraCtrl,
                    hint: column.kind == 'ref'
                        ? 'Allowed types (comma-separated)'
                        : 'Options (comma-separated)',
                    onChanged: (_) => onChanged(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
