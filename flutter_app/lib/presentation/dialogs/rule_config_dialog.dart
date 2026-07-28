import 'package:flutter/material.dart';

import '../../domain/entities/schema/rule_config.dart';
import '../../domain/entities/schema/world_schema.dart';

/// Minimal editor for the template's tunable [RuleConfig] values
/// (`metadata['rule_config']`): ASI levels, proficiency-bonus breakpoints,
/// the hit-die→HP table and the AC constants.
///
/// Persistence stays with the caller via [onSave] — the campaign screen saves
/// through `ActiveCampaignNotifier.applyTemplateUpdate`, the package screen
/// through `ActivePackageNotifier.applyTemplateUpdate`. When the edited values
/// equal [RuleConfig.dnd5eDefaults] the `rule_config` key is REMOVED instead
/// of written, so an untouched template keeps its content-hash.
class RuleConfigDialog extends StatefulWidget {
  final WorldSchema schema;
  final Future<void> Function(WorldSchema updated) onSave;

  const RuleConfigDialog({
    required this.schema,
    required this.onSave,
    super.key,
  });

  static Future<void> show(
    BuildContext context, {
    required WorldSchema schema,
    required Future<void> Function(WorldSchema updated) onSave,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => RuleConfigDialog(schema: schema, onSave: onSave),
    );
  }

  @override
  State<RuleConfigDialog> createState() => _RuleConfigDialogState();
}

/// The hit dice always offered as editable rows (SRD classes).
const _standardDice = ['d6', 'd8', 'd10', 'd12'];

class _RuleConfigDialogState extends State<RuleConfigDialog> {
  late final TextEditingController _asiLevels;
  late final TextEditingController _profBreakpoints;
  late final TextEditingController _acBase;
  late final TextEditingController _acShield;
  late final Map<String, TextEditingController> _hitDice;

  /// Non-standard hit-die entries carried by an existing override — preserved
  /// verbatim so editing AC doesn't drop a custom d20 row.
  late final Map<String, int> _extraDice;

  RuleConfig get _initial {
    final raw = widget.schema.metadata['rule_config'];
    if (raw is Map) {
      return RuleConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    return RuleConfig.dnd5eDefaults;
  }

  @override
  void initState() {
    super.initState();
    final c = _initial;
    _asiLevels = TextEditingController(text: c.asiLevels.join(', '));
    _profBreakpoints =
        TextEditingController(text: c.proficiencyBonusBreakpoints.join(', '));
    _acBase = TextEditingController(text: c.acUnarmoredBase.toString());
    _acShield = TextEditingController(text: c.acShieldBonus.toString());
    _hitDice = {
      for (final d in _standardDice)
        d: TextEditingController(
            text: (c.hitDieToHp[d] ??
                    RuleConfig.dnd5eDefaults.hitDieToHp[d] ??
                    0)
                .toString()),
    };
    _extraDice = {
      for (final e in c.hitDieToHp.entries)
        if (!_standardDice.contains(e.key)) e.key: e.value,
    };
  }

  @override
  void dispose() {
    _asiLevels.dispose();
    _profBreakpoints.dispose();
    _acBase.dispose();
    _acShield.dispose();
    for (final c in _hitDice.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetToDefaults() {
    const d = RuleConfig.dnd5eDefaults;
    setState(() {
      _asiLevels.text = d.asiLevels.join(', ');
      _profBreakpoints.text = d.proficiencyBonusBreakpoints.join(', ');
      _acBase.text = d.acUnarmoredBase.toString();
      _acShield.text = d.acShieldBonus.toString();
      for (final die in _standardDice) {
        _hitDice[die]!.text = (d.hitDieToHp[die] ?? 0).toString();
      }
      _extraDice.clear();
    });
  }

  List<int> _parseInts(String raw, List<int> fallback) {
    final parsed = raw
        .split(RegExp(r'[,\s]+'))
        .map((t) => int.tryParse(t.trim()))
        .whereType<int>()
        .toList();
    return raw.trim().isEmpty ? fallback : parsed;
  }

  RuleConfig _buildResult() {
    const d = RuleConfig.dnd5eDefaults;
    return RuleConfig(
      asiLevels: _parseInts(_asiLevels.text, d.asiLevels),
      proficiencyBonusBreakpoints:
          _parseInts(_profBreakpoints.text, d.proficiencyBonusBreakpoints),
      acUnarmoredBase: int.tryParse(_acBase.text.trim()) ?? d.acUnarmoredBase,
      acShieldBonus: int.tryParse(_acShield.text.trim()) ?? d.acShieldBonus,
      hitDieToHp: {
        for (final die in _standardDice)
          die: int.tryParse(_hitDice[die]!.text.trim()) ??
              d.hitDieToHp[die] ??
              0,
        ..._extraDice,
      },
    );
  }

  Future<void> _save() async {
    final result = _buildResult();
    final metadata = Map<String, dynamic>.from(widget.schema.metadata);
    if (result == RuleConfig.dnd5eDefaults) {
      metadata.remove('rule_config');
    } else {
      metadata['rule_config'] = result.toJson();
    }
    final navigator = Navigator.of(context);
    await widget.onSave(widget.schema.copyWith(metadata: metadata));
    if (mounted) navigator.pop();
  }

  Widget _intField(TextEditingController controller, String label,
      {String? helper, double width = 220}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
        ),
        style: const TextStyle(fontSize: 13),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rule Settings'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Numeric rules for this template. Character sheets, the '
                'level-up planner and AC recompute immediately after saving.',
                style: TextStyle(fontSize: 12),
              ),
              _sectionLabel('Progression'),
              _intField(_asiLevels, 'ASI / feat levels',
                  helper: 'Comma-separated, e.g. 4, 8, 12, 16, 19',
                  width: 440),
              const SizedBox(height: 10),
              _intField(_profBreakpoints, 'Proficiency bonus increases at',
                  helper: 'Levels where the +2 base grows by 1', width: 440),
              _sectionLabel('Hit points per level (after level 1)'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final die in _standardDice)
                    _intField(_hitDice[die]!, die, width: 100),
                ],
              ),
              _sectionLabel('Armor Class'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _intField(_acBase, 'Unarmored base', width: 160),
                  _intField(_acShield, 'Shield bonus', width: 160),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetToDefaults,
          child: const Text('Reset to D&D 5e defaults'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
