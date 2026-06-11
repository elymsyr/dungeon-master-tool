import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/providers/template_editor_provider.dart';
import '../../../../../domain/entities/schema/field_schema.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'tc_shared.dart';

/// `abilityScoreTable` config form (the-template-system §2.3): editable score
/// columns plus the modifier formula `floor((score − base) / step)` and the
/// aspect-publish toggle. The built-in reproduces D&D's `(score − 10) / 2`.
class AbilityScoreTableForm extends ConsumerStatefulWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const AbilityScoreTableForm({
    super.key,
    required this.field,
    required this.palette,
  });

  @override
  ConsumerState<AbilityScoreTableForm> createState() =>
      _AbilityScoreTableFormState();
}

class _ColumnRow {
  final TextEditingController keyCtrl;
  final TextEditingController labelCtrl;
  _ColumnRow({String key = '', String label = ''})
      : keyCtrl = TextEditingController(text: key),
        labelCtrl = TextEditingController(text: label);
  void dispose() {
    keyCtrl.dispose();
    labelCtrl.dispose();
  }
}

class _AbilityScoreTableFormState extends ConsumerState<AbilityScoreTableForm> {
  late List<_ColumnRow> _columns;
  late final TextEditingController _baseCtrl;
  late final TextEditingController _stepCtrl;
  late bool _publishAspects;

  @override
  void initState() {
    super.initState();
    final cfg = widget.field.typeConfig ?? const {};
    _columns = [];
    final cols = cfg['columns'];
    if (cols is List) {
      for (final c in cols) {
        if (c is Map) {
          _columns.add(_ColumnRow(
            key: (c['key'] ?? '').toString(),
            label: (c['label'] ?? '').toString(),
          ));
        }
      }
    }
    if (_columns.isEmpty) _columns.add(_ColumnRow());
    _baseCtrl = TextEditingController(
      text: '${cfg['modifierBase'] is num ? cfg['modifierBase'] : 10}',
    );
    _stepCtrl = TextEditingController(
      text: '${cfg['modifierStep'] is num ? cfg['modifierStep'] : 2}',
    );
    _publishAspects = cfg['publishAspects'] != false;
  }

  @override
  void dispose() {
    for (final c in _columns) {
      c.dispose();
    }
    _baseCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final config = <String, dynamic>{
      'columns': [
        for (final c in _columns)
          {
            'key': fieldKeyNormalize(c.keyCtrl.text.trim()),
            'label': c.labelCtrl.text.trim(),
          },
      ],
      'modifierBase': int.tryParse(_baseCtrl.text.trim()) ?? 10,
      'modifierStep': int.tryParse(_stepCtrl.text.trim()) ?? 2,
      'publishAspects': _publishAspects,
    };
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
          title: 'Score columns',
          subtitle: 'Each column publishes <key> and <key>_mod as aspects when '
              'aspect-publish is on.',
          palette: palette,
          children: [
            for (final row in _columns)
              TcListRow(
                palette: palette,
                onRemove: _columns.length > 1
                    ? () {
                        setState(() {
                          row.dispose();
                          _columns.remove(row);
                        });
                        _emit();
                      }
                    : null,
                children: [
                  SizedBox(
                    width: 90,
                    child: TcTextField(
                      controller: row.keyCtrl,
                      hint: 'key',
                      onChanged: (v) {
                        final n = fieldKeyNormalize(v);
                        if (n != v) {
                          row.keyCtrl.value = TextEditingValue(
                            text: n,
                            selection: TextSelection.collapsed(offset: n.length),
                          );
                        }
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TcTextField(
                      controller: row.labelCtrl,
                      hint: 'Label',
                      onChanged: (_) => _emit(),
                    ),
                  ),
                ],
              ),
            TcAddButton(
              label: 'Add column',
              palette: palette,
              onPressed: () {
                setState(() => _columns.add(_ColumnRow()));
                _emit();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TcSection(
          title: 'Modifier formula',
          subtitle: 'modifier = floor((score − base) / step)',
          palette: palette,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TcLabel(text: 'Base', palette: palette),
                      const SizedBox(height: 6),
                      TcTextField(
                        controller: _baseCtrl,
                        number: true,
                        onChanged: (_) => _emit(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TcLabel(text: 'Step', palette: palette),
                      const SizedBox(height: 6),
                      TcTextField(
                        controller: _stepCtrl,
                        number: true,
                        onChanged: (_) => _emit(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Publish modifier aspects',
                style: TextStyle(fontSize: 13, color: palette.tabActiveText),
              ),
              value: _publishAspects,
              onChanged: (v) {
                setState(() => _publishAspects = v);
                _emit();
              },
            ),
          ],
        ),
      ],
    );
  }
}
