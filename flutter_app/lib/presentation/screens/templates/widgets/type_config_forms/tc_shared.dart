import 'package:flutter/material.dart';

import '../../../../../application/providers/template_editor_provider.dart';
import '../../../../theme/dm_tool_colors.dart';

/// Shared building blocks for the per-type `typeConfig` sub-forms (PR-2.2b).
///
/// Each parametric field type (abilityScoreTable, recordList, the pouches,
/// skillTree, levelUpTable, actionButton, …) gets a small form that writes its
/// config wholesale through [TemplateEditorNotifier.updateFieldTypeConfig]; the
/// widgets below give those forms a consistent look on mobile and desktop.

/// A titled, bordered config section — the visual container every sub-form sits
/// inside, matching the inspector's `_Section` styling.
class TcSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final DmToolColors palette;
  final List<Widget> children;

  const TcSection({
    super.key,
    required this.title,
    required this.palette,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Small uppercase field caption used inside the sub-forms.
class TcLabel extends StatelessWidget {
  final String text;
  final DmToolColors palette;

  const TcLabel({super.key, required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: palette.sidebarLabelSecondary,
      ),
    );
  }
}

/// Dense outlined text field tuned for the compact config forms.
class TcTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final IconData? prefixIcon;
  final bool number;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const TcTextField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.prefixIcon,
    this.number = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onChanged: onChanged,
    );
  }
}

/// A row of the editable lists (columns, rows, table entries) — children laid
/// out horizontally with a trailing delete button. Reuses the structured-list
/// row visual from the entity editors.
class TcListRow extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback? onRemove;
  final DmToolColors palette;

  const TcListRow({
    super.key,
    required this.children,
    required this.palette,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...children,
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: palette.dangerBtnBg,
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Outlined "+ Add …" action used to append rows/columns to the list editors.
class TcAddButton extends StatelessWidget {
  final String label;
  final DmToolColors palette;
  final VoidCallback onPressed;

  const TcAddButton({
    super.key,
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: palette.featureCardAccent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

/// A single mutable level/value pair behind the level-table source editor.
class TcKvRow {
  final TextEditingController keyCtrl;
  final TextEditingController valCtrl;

  TcKvRow({String key = '', String value = ''})
      : keyCtrl = TextEditingController(text: key),
        valCtrl = TextEditingController(text: value);

  void dispose() {
    keyCtrl.dispose();
    valCtrl.dispose();
  }
}

/// The shared pouch `maxSource` / `countSource` editor (the-template-system
/// §2.3). One self-contained stateful widget reused by intPouch (`maxSource`),
/// checkboxPouch (`countSource`) and pouchMatrix (`maxSource`). It owns its own
/// controllers (seeded once from [source]) and emits a freshly-built source map
/// on every change. Key it by the field id so a selection change recreates it.
class TcSourceEditor extends StatefulWidget {
  final String title;
  final Map<String, dynamic> source;
  final DmToolColors palette;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const TcSourceEditor({
    super.key,
    required this.title,
    required this.source,
    required this.palette,
    required this.onChanged,
  });

  @override
  State<TcSourceEditor> createState() => _TcSourceEditorState();
}

class _TcSourceEditorState extends State<TcSourceEditor> {
  late String _kind;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _exprCtrl;
  late final TextEditingController _levelAspectCtrl;
  late List<TcKvRow> _table;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _kind = pouchSourceKinds.contains(s['kind']) ? s['kind'] as String : 'manual';
    _valueCtrl = TextEditingController(
      text: s['value'] is num ? '${s['value']}' : '',
    );
    _exprCtrl = TextEditingController(text: (s['expr'] ?? '').toString());
    _levelAspectCtrl = TextEditingController(
      text: (s['levelAspect'] ?? 'class_level').toString(),
    );
    _table = [];
    final table = s['table'];
    if (table is Map) {
      final entries = table.entries.toList()
        ..sort((a, b) =>
            (int.tryParse('${a.key}') ?? 0).compareTo(int.tryParse('${b.key}') ?? 0));
      for (final e in entries) {
        _table.add(TcKvRow(key: '${e.key}', value: '${e.value}'));
      }
    }
    if (_table.isEmpty) _table.add(TcKvRow());
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _exprCtrl.dispose();
    _levelAspectCtrl.dispose();
    for (final r in _table) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final map = <String, dynamic>{'kind': _kind};
    switch (_kind) {
      case 'fixed':
        final v = int.tryParse(_valueCtrl.text.trim());
        if (v != null) map['value'] = v;
        break;
      case 'formula':
        map['expr'] = _exprCtrl.text.trim();
        break;
      case 'levelTable':
        final t = <String, dynamic>{};
        for (final row in _table) {
          final lvl = row.keyCtrl.text.trim();
          final val = int.tryParse(row.valCtrl.text.trim());
          if (lvl.isNotEmpty && val != null) t[lvl] = val;
        }
        map['table'] = t;
        map['levelAspect'] = _levelAspectCtrl.text.trim().isEmpty
            ? 'class_level'
            : _levelAspectCtrl.text.trim();
        break;
      case 'manual':
        break;
    }
    widget.onChanged(map);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return TcSection(
      title: widget.title,
      palette: palette,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _kind,
          isDense: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: 'manual', child: Text('Manual (DM types it)')),
            DropdownMenuItem(value: 'fixed', child: Text('Fixed value')),
            DropdownMenuItem(value: 'levelTable', child: Text('By level table')),
            DropdownMenuItem(value: 'formula', child: Text('Formula')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _kind = v);
            _emit();
          },
        ),
        if (_kind == 'fixed') ...[
          const SizedBox(height: 10),
          TcLabel(text: 'Value', palette: palette),
          const SizedBox(height: 6),
          TcTextField(
            controller: _valueCtrl,
            number: true,
            hint: 'e.g. 3',
            onChanged: (_) => _emit(),
          ),
        ],
        if (_kind == 'formula') ...[
          const SizedBox(height: 10),
          TcLabel(text: 'Expression', palette: palette),
          const SizedBox(height: 6),
          TcTextField(
            controller: _exprCtrl,
            hint: 'e.g. prof_bonus + cha_mod',
            onChanged: (_) => _emit(),
          ),
        ],
        if (_kind == 'levelTable') ...[
          const SizedBox(height: 10),
          TcLabel(text: 'Level aspect', palette: palette),
          const SizedBox(height: 6),
          TcTextField(
            controller: _levelAspectCtrl,
            hint: 'e.g. class_level',
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          TcLabel(text: 'Level → value', palette: palette),
          const SizedBox(height: 6),
          for (final row in _table)
            TcListRow(
              palette: palette,
              onRemove: () {
                setState(() {
                  row.dispose();
                  _table.remove(row);
                  if (_table.isEmpty) _table.add(TcKvRow());
                });
                _emit();
              },
              children: [
                SizedBox(
                  width: 64,
                  child: TcTextField(
                    controller: row.keyCtrl,
                    number: true,
                    hint: 'Lvl',
                    onChanged: (_) => _emit(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→', style: TextStyle(fontSize: 14)),
                ),
                Expanded(
                  child: TcTextField(
                    controller: row.valCtrl,
                    number: true,
                    hint: 'Value',
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
          TcAddButton(
            label: 'Add level',
            palette: palette,
            onPressed: () {
              setState(() => _table.add(TcKvRow()));
              _emit();
            },
          ),
        ],
      ],
    );
  }
}
