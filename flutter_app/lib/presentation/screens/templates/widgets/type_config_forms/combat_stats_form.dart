import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/providers/template_editor_provider.dart';
import '../../../../../domain/entities/schema/field_schema.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'tc_shared.dart';

/// `combatStatsTable` config form (the-template-system §2.3). The key *set* is
/// fixed (canonical semantics live in the widget); only which keys are visible
/// is creator-editable, so this is a checklist over [combatStatsCanonicalKeys].
class CombatStatsForm extends ConsumerStatefulWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const CombatStatsForm({super.key, required this.field, required this.palette});

  @override
  ConsumerState<CombatStatsForm> createState() => _CombatStatsFormState();
}

class _CombatStatsFormState extends ConsumerState<CombatStatsForm> {
  late Set<String> _visible;

  static const Map<String, String> _labels = {
    'hp': 'Current HP',
    'max_hp': 'Max HP',
    'ac': 'Armor Class',
    'speed': 'Speed',
    'level': 'Level',
    'initiative': 'Initiative',
    'xp': 'XP',
  };

  @override
  void initState() {
    super.initState();
    final cfg = widget.field.typeConfig ?? const {};
    final keys = cfg['visibleKeys'];
    _visible = {
      if (keys is List)
        for (final k in keys)
          if (combatStatsCanonicalKeys.contains(k)) k.toString(),
    };
    if (_visible.isEmpty) {
      _visible = {'hp', 'max_hp', 'ac', 'initiative', 'level'};
    }
  }

  void _emit() {
    final ordered = [
      for (final k in combatStatsCanonicalKeys)
        if (_visible.contains(k)) k,
    ];
    ref.read(templateEditorProvider.notifier).updateFieldTypeConfig(
      widget.field.categoryId,
      widget.field.fieldId,
      {'visibleKeys': ordered},
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return TcSection(
      title: 'Visible stats',
      subtitle: 'Keys and behaviours are fixed; choose which appear on the card.',
      palette: palette,
      children: [
        for (final k in combatStatsCanonicalKeys)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              _labels[k] ?? k,
              style: TextStyle(fontSize: 13, color: palette.tabActiveText),
            ),
            subtitle: Text(
              k,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: palette.sidebarLabelSecondary,
              ),
            ),
            value: _visible.contains(k),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _visible.add(k);
                } else {
                  _visible.remove(k);
                }
              });
              _emit();
            },
          ),
      ],
    );
  }
}
