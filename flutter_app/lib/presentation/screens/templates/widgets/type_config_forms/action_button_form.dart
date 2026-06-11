import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/providers/template_editor_provider.dart';
import '../../../../../domain/entities/schema/field_schema.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'tc_shared.dart';

/// `actionButton` config form (the-template-system §2.3). The button label is
/// the FieldSchema label (edited above in the core form); here the creator picks
/// the fixed process the button runs and where it renders on the sheet.
class ActionButtonForm extends ConsumerStatefulWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const ActionButtonForm({
    super.key,
    required this.field,
    required this.palette,
  });

  @override
  ConsumerState<ActionButtonForm> createState() => _ActionButtonFormState();
}

class _ActionButtonFormState extends ConsumerState<ActionButtonForm> {
  late String _action;
  late final TextEditingController _placementCtrl;

  static const Map<String, String> _labels = {
    'level_up': 'Level up',
    'short_rest': 'Short rest',
    'long_rest': 'Long rest',
  };

  @override
  void initState() {
    super.initState();
    final cfg = widget.field.typeConfig ?? const {};
    _action = actionButtonActions.contains(cfg['action'])
        ? cfg['action'] as String
        : 'level_up';
    _placementCtrl =
        TextEditingController(text: (cfg['placement'] ?? 'header').toString());
  }

  @override
  void dispose() {
    _placementCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final config = <String, dynamic>{'action': _action};
    final placement = _placementCtrl.text.trim();
    if (placement.isNotEmpty) config['placement'] = placement;
    ref.read(templateEditorProvider.notifier).updateFieldTypeConfig(
          widget.field.categoryId,
          widget.field.fieldId,
          config,
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return TcSection(
      title: 'Button action',
      subtitle: 'The label is set above; the process each action runs is fixed.',
      palette: palette,
      children: [
        TcLabel(text: 'Action', palette: palette),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _action,
          isDense: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: [
            for (final a in actionButtonActions)
              DropdownMenuItem(value: a, child: Text(_labels[a] ?? a)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _action = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        TcLabel(text: 'Placement', palette: palette),
        const SizedBox(height: 6),
        TcTextField(
          controller: _placementCtrl,
          hint: 'e.g. header',
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}
