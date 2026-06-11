import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/providers/template_editor_provider.dart';
import '../../../../../domain/entities/schema/field_schema.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'tc_shared.dart';

/// Shared config form for the three pouch types (the-template-system §2.3):
/// `intPouch` (`maxSource`), `checkboxPouch` (`countSource` + pip/checkbox
/// style) and `pouchMatrix` (`rowKeys` + label prefix + `maxSource`). The
/// `maxSource`/`countSource` editor is the shared [TcSourceEditor].
class PouchConfigForm extends ConsumerStatefulWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const PouchConfigForm({super.key, required this.field, required this.palette});

  @override
  ConsumerState<PouchConfigForm> createState() => _PouchConfigFormState();
}

class _PouchConfigFormState extends ConsumerState<PouchConfigForm> {
  late Map<String, dynamic> _source;
  late String _style; // checkboxPouch only
  late List<TextEditingController> _rowKeys; // pouchMatrix only
  late final TextEditingController _prefixCtrl; // pouchMatrix only

  bool get _isCheckbox =>
      widget.field.fieldType == FieldType.checkboxPouch ||
      widget.field.fieldType == FieldType.slot;
  bool get _isMatrix =>
      widget.field.fieldType == FieldType.pouchMatrix ||
      widget.field.fieldType == FieldType.spellSlotGrid;

  String get _sourceKey => _isCheckbox ? 'countSource' : 'maxSource';

  @override
  void initState() {
    super.initState();
    final cfg = widget.field.typeConfig ?? const {};
    final src = cfg[_sourceKey];
    _source = src is Map
        ? Map<String, dynamic>.from(src)
        : {'kind': _isCheckbox ? 'fixed' : 'manual'};
    _style = (cfg['style'] == 'checkboxes') ? 'checkboxes' : 'pips';
    _rowKeys = [];
    final rows = cfg['rowKeys'];
    if (rows is List) {
      for (final r in rows) {
        _rowKeys.add(TextEditingController(text: '$r'));
      }
    }
    if (_rowKeys.isEmpty && _isMatrix) {
      _rowKeys.add(TextEditingController(text: '1'));
    }
    _prefixCtrl = TextEditingController(
      text: (cfg['rowLabelPrefix'] ?? 'Level ').toString(),
    );
  }

  @override
  void dispose() {
    for (final c in _rowKeys) {
      c.dispose();
    }
    _prefixCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final config = <String, dynamic>{_sourceKey: _source};
    if (_isCheckbox) {
      config['style'] = _style;
    }
    if (_isMatrix) {
      config['rowKeys'] = [
        for (final c in _rowKeys)
          if (c.text.trim().isNotEmpty) c.text.trim(),
      ];
      config['rowLabelPrefix'] = _prefixCtrl.text;
    }
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
        if (_isMatrix) ...[
          TcSection(
            title: 'Rows',
            subtitle: 'One row per resource tier (e.g. spell levels 1–9).',
            palette: palette,
            children: [
              TcLabel(text: 'Row label prefix', palette: palette),
              const SizedBox(height: 6),
              TcTextField(
                controller: _prefixCtrl,
                hint: 'e.g. "Level "',
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 12),
              TcLabel(text: 'Row keys', palette: palette),
              const SizedBox(height: 6),
              for (final ctrl in _rowKeys)
                TcListRow(
                  palette: palette,
                  onRemove: _rowKeys.length > 1
                      ? () {
                          setState(() {
                            ctrl.dispose();
                            _rowKeys.remove(ctrl);
                          });
                          _emit();
                        }
                      : null,
                  children: [
                    Expanded(
                      child: TcTextField(
                        controller: ctrl,
                        hint: 'Row key, e.g. 1',
                        onChanged: (_) => _emit(),
                      ),
                    ),
                  ],
                ),
              TcAddButton(
                label: 'Add row',
                palette: palette,
                onPressed: () {
                  setState(() =>
                      _rowKeys.add(TextEditingController(text: '${_rowKeys.length + 1}')));
                  _emit();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_isCheckbox) ...[
          TcSection(
            title: 'Display style',
            palette: palette,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _style,
                isDense: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'pips', child: Text('Pips')),
                  DropdownMenuItem(
                      value: 'checkboxes', child: Text('Checkboxes')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _style = v);
                  _emit();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TcSourceEditor(
          title: _isCheckbox ? 'Count source' : 'Maximum source',
          source: _source,
          palette: palette,
          onChanged: (s) {
            _source = s;
            _emit();
          },
        ),
      ],
    );
  }
}
