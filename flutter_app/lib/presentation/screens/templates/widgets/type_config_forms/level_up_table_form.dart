import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/providers/template_editor_provider.dart';
import '../../../../../domain/entities/schema/field_schema.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'tc_shared.dart';

/// `levelUpTable` config form (the-template-system §2.3). The per-level grants
/// and choices are *card data* the DM fills; the only template-level parameter
/// is the gate — which level drives the table (the owning class's level, or the
/// whole character's level).
class LevelUpTableForm extends ConsumerStatefulWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const LevelUpTableForm({
    super.key,
    required this.field,
    required this.palette,
  });

  @override
  ConsumerState<LevelUpTableForm> createState() => _LevelUpTableFormState();
}

class _LevelUpTableFormState extends ConsumerState<LevelUpTableForm> {
  late String _gate;

  static const Map<String, String> _labels = {
    'class': "Owning class's level",
    'character': 'Total character level',
  };

  @override
  void initState() {
    super.initState();
    final cfg = widget.field.typeConfig ?? const {};
    _gate = levelUpTableGates.contains(cfg['gate']) ? cfg['gate'] as String : 'class';
  }

  void _emit() {
    ref.read(templateEditorProvider.notifier).updateFieldTypeConfig(
      widget.field.categoryId,
      widget.field.fieldId,
      {'gate': _gate},
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return TcSection(
      title: 'Level gate',
      subtitle: 'Each row applies while the gated level ≥ the row level.',
      palette: palette,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _gate,
          isDense: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: [
            for (final g in levelUpTableGates)
              DropdownMenuItem(value: g, child: Text(_labels[g] ?? g)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _gate = v);
            _emit();
          },
        ),
      ],
    );
  }
}
