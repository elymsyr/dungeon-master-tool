import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/providers/template_editor_provider.dart';
import '../../../../../domain/entities/schema/field_schema.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'tc_shared.dart';

/// `skillTree` config form (the-template-system §2.3). Unifies saving throws
/// and skills: the bonus = `ability_mod + prof_bonus × tiers_checked + misc`.
/// Creator sets the ability source field, the proficiency-bonus aspect, the row
/// seed catalog, and which proficiency tiers exist.
class SkillTreeForm extends ConsumerStatefulWidget {
  final FieldSchema field;
  final DmToolColors palette;

  const SkillTreeForm({super.key, required this.field, required this.palette});

  @override
  ConsumerState<SkillTreeForm> createState() => _SkillTreeFormState();
}

class _SkillTreeFormState extends ConsumerState<SkillTreeForm> {
  late final TextEditingController _abilityFieldCtrl;
  late final TextEditingController _profAspectCtrl;
  late final TextEditingController _rowSeedCtrl;
  late Set<String> _tiers;

  @override
  void initState() {
    super.initState();
    final cfg = widget.field.typeConfig ?? const {};
    _abilityFieldCtrl =
        TextEditingController(text: (cfg['abilityFieldKey'] ?? '').toString());
    _profAspectCtrl = TextEditingController(
        text: (cfg['proficiencyBonusAspect'] ?? 'prof_bonus').toString());
    _rowSeedCtrl =
        TextEditingController(text: (cfg['rowSeed'] ?? '').toString());
    final tiers = cfg['tiers'];
    _tiers = {
      if (tiers is List)
        for (final t in tiers)
          if (skillTreeTiers.contains(t)) t.toString(),
    };
    if (_tiers.isEmpty) _tiers = {'proficient'};
  }

  @override
  void dispose() {
    _abilityFieldCtrl.dispose();
    _profAspectCtrl.dispose();
    _rowSeedCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final ordered = [
      for (final t in skillTreeTiers)
        if (_tiers.contains(t)) t,
    ];
    ref.read(templateEditorProvider.notifier).updateFieldTypeConfig(
      widget.field.categoryId,
      widget.field.fieldId,
      {
        'abilityFieldKey': _abilityFieldCtrl.text.trim(),
        'proficiencyBonusAspect': _profAspectCtrl.text.trim(),
        'rowSeed': _rowSeedCtrl.text.trim(),
        'tiers': ordered,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TcSection(
          title: 'Sources',
          palette: palette,
          children: [
            TcLabel(text: 'Ability field key', palette: palette),
            const SizedBox(height: 6),
            TcTextField(
              controller: _abilityFieldCtrl,
              hint: 'e.g. stat_block',
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 12),
            TcLabel(text: 'Proficiency bonus aspect', palette: palette),
            const SizedBox(height: 6),
            TcTextField(
              controller: _profAspectCtrl,
              hint: 'e.g. prof_bonus',
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 12),
            TcLabel(text: 'Row seed catalog', palette: palette),
            const SizedBox(height: 6),
            TcTextField(
              controller: _rowSeedCtrl,
              hint: 'e.g. skill or ability',
              onChanged: (_) => _emit(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TcSection(
          title: 'Proficiency tiers',
          subtitle: 'Each checked tier adds another × prof_bonus to the bonus.',
          palette: palette,
          children: [
            for (final t in skillTreeTiers)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  t[0].toUpperCase() + t.substring(1),
                  style: TextStyle(fontSize: 13, color: palette.tabActiveText),
                ),
                value: _tiers.contains(t),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _tiers.add(t);
                    } else if (_tiers.length > 1) {
                      _tiers.remove(t);
                    }
                  });
                  _emit();
                },
              ),
          ],
        ),
      ],
    );
  }
}
