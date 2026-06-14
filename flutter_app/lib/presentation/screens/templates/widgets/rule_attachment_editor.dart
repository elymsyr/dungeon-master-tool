import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../../../../core/utils/screen_type.dart';
import '../../../../domain/entities/schema/entity_category_schema.dart';
import '../../../../domain/entities/schema/field_schema.dart';
import '../../../../domain/services/template_rules/template_rule_resolver.dart'
    show RuleKinds, RuleTriggers;
import '../../../theme/dm_tool_colors.dart';
import 'type_config_forms/tc_shared.dart';

/// PR-3.5a — the responsive rule-attachment editor mounted in the Template
/// Editor inspector (master-roadmap §1.5 / Phase 3.5a).
///
/// On an editable copy it replaces the read-only rules JSON dump for
/// rule-capable fields: the creator adds / edits / deletes / reorders the
/// field's `rules[]` through friendly per-kind forms (the closed [RuleKinds] ×
/// [RuleTriggers] vocabulary is enforced by dropdowns), with an advanced raw
/// parameters escape hatch for kind-specific payloads (choose `perPick`,
/// check_clauses `clauses`, pouch `source`, …). Each change writes the full
/// list through [TemplateEditorNotifier.updateFieldRules]; the editor's explicit
/// Save persists it. Works on phone (the field-edit page), tablet and desktop
/// (the inspector pane) — the add/edit form is a bottom sheet on touch and a
/// dialog on desktop, matching the category/type-picker convention.

/// Human labels for the closed rule-kind set, in [RuleKinds.all] order.
const Map<String, String> ruleKindLabels = {
  RuleKinds.modifyStat: 'Modify stat',
  RuleKinds.grantRefs: 'Grant references',
  RuleKinds.grantProficiency: 'Grant proficiency',
  RuleKinds.choose: 'Choose (pick N)',
  RuleKinds.setPouchMax: 'Set pouch max',
  RuleKinds.grantPouch: 'Grant pouch',
  RuleKinds.refillPouch: 'Refill pouch',
  RuleKinds.emptyPouch: 'Empty pouch',
  RuleKinds.checkClauses: 'Check prerequisites',
  RuleKinds.note: 'Note (rule text)',
};

/// Human labels for the closed trigger set.
const Map<String, String> ruleTriggerLabels = {
  RuleTriggers.whenGranted: 'When granted (always on)',
  RuleTriggers.levelUp: 'On level up',
  RuleTriggers.prereqToGrant: 'Prerequisite to grant',
  RuleTriggers.whenEquipped: 'When equipped',
  RuleTriggers.prereqToEquip: 'Prerequisite to equip',
  RuleTriggers.onButton: 'On button press',
};

/// Pouch button choices for refill/empty rules (= the actionButton actions).
const List<String> _pouchButtons = ['long_rest', 'short_rest', 'level_up'];

String _kindLabel(String kind) => ruleKindLabels[kind] ?? kind;

String _triggerLabel(String? trigger) =>
    trigger == null ? 'Default (when granted)' : (ruleTriggerLabels[trigger] ?? trigger);

/// The structured (form-backed) param keys for a given kind — everything else a
/// rule carries is surfaced in the advanced JSON box so no payload is lost.
List<String> _structuredKeysFor(String kind) {
  switch (kind) {
    case RuleKinds.note:
      return const ['text', 'note'];
    case RuleKinds.modifyStat:
      return const ['target', 'value'];
    case RuleKinds.grantRefs:
      return const ['target'];
    case RuleKinds.grantProficiency:
      return const ['target', 'tier'];
    case RuleKinds.choose:
      return const ['prompt', 'pick', 'target'];
    case RuleKinds.setPouchMax:
    case RuleKinds.grantPouch:
      return const ['target'];
    case RuleKinds.refillPouch:
    case RuleKinds.emptyPouch:
      return const ['button', 'amount'];
    case RuleKinds.checkClauses:
      return const ['policy'];
    default:
      return const [];
  }
}

/// One-line human summary of a rule for its tile (kind-aware).
String ruleSummary(Map<String, dynamic> rule) {
  final kind = (rule['kind'] ?? '').toString();
  String? part(String key) {
    final v = rule[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  switch (kind) {
    case RuleKinds.modifyStat:
      final t = part('target');
      final v = part('value');
      if (t != null && v != null) return '$t by $v';
      return t ?? v ?? 'modifies a stat';
    case RuleKinds.note:
      return part('text') ?? part('note') ?? 'rule text';
    case RuleKinds.grantRefs:
      return 'into ${part('target') ?? '(field)'}';
    case RuleKinds.grantProficiency:
      return '${part('tier') ?? 'proficient'} → ${part('target') ?? '(skills)'}';
    case RuleKinds.choose:
      return 'pick ${part('pick') ?? '1'}${part('prompt') != null ? ' — ${part('prompt')}' : ''}';
    case RuleKinds.setPouchMax:
    case RuleKinds.grantPouch:
      return part('target') ?? '(this field)';
    case RuleKinds.refillPouch:
    case RuleKinds.emptyPouch:
      return '${part('button') ?? 'long_rest'} · ${part('amount') ?? 'all'}';
    case RuleKinds.checkClauses:
      return 'policy: ${part('policy') ?? 'warn'}';
    default:
      return kind.isEmpty ? '(no kind)' : kind;
  }
}

class RuleAttachmentEditor extends ConsumerWidget {
  final FieldSchema field;
  final EntityCategorySchema category;
  final DmToolColors palette;

  const RuleAttachmentEditor({
    super.key,
    required this.field,
    required this.category,
    required this.palette,
  });

  TemplateEditorNotifier _notifier(WidgetRef ref) =>
      ref.read(templateEditorProvider.notifier);

  List<Map<String, dynamic>> get _rules => [
        for (final r in (field.rules ?? const <Map<String, dynamic>>[]))
          Map<String, dynamic>.from(r),
      ];

  void _commit(WidgetRef ref, List<Map<String, dynamic>> rules) {
    _notifier(ref).updateFieldRules(category.categoryId, field.fieldId, rules);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await showRuleEditSheet(context, existing: null);
    if (result == null) return;
    _commit(ref, [..._rules, result]);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, int index) async {
    final rules = _rules;
    if (index < 0 || index >= rules.length) return;
    final result = await showRuleEditSheet(context, existing: rules[index]);
    if (result == null) return;
    rules[index] = result;
    _commit(ref, rules);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?'),
        content: const Text(
            'This removes the rule from the field. You can re-add it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final rules = _rules;
    if (index < 0 || index >= rules.length) return;
    rules.removeAt(index);
    _commit(ref, rules);
  }

  void _reorder(WidgetRef ref, int oldIndex, int newIndex) {
    final rules = _rules;
    if (oldIndex < 0 || oldIndex >= rules.length) return;
    var insertAt = newIndex;
    if (insertAt > oldIndex) insertAt -= 1;
    if (insertAt < 0) insertAt = 0;
    if (insertAt >= rules.length) insertAt = rules.length - 1;
    if (insertAt == oldIndex) return;
    final moved = rules.removeAt(oldIndex);
    rules.insert(insertAt, moved);
    _commit(ref, rules);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = _rules;
    return TcSection(
      title: 'Rules (${rules.length})',
      palette: palette,
      subtitle:
          'Mechanics fire from this field. Pick a kind and trigger; advanced '
          'parameters cover kind-specific payloads.',
      children: [
        if (rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No rules attached yet.',
              style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: rules.length,
            onReorder: (o, n) => _reorder(ref, o, n),
            itemBuilder: (context, i) {
              final rule = rules[i];
              return _RuleTile(
                key: ValueKey('rule-$i-${rule['kind']}'),
                index: i,
                rule: rule,
                palette: palette,
                onEdit: () => _edit(context, ref, i),
                onDelete: () => _delete(context, ref, i),
              );
            },
          ),
        const SizedBox(height: 4),
        TcAddButton(
          label: 'Add rule',
          palette: palette,
          onPressed: () => _add(context, ref),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> rule;
  final DmToolColors palette;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleTile({
    super.key,
    required this.index,
    required this.rule,
    required this.palette,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final kind = (rule['kind'] ?? '').toString();
    final trigger = rule['trigger']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Icon(Icons.drag_indicator,
                  size: 18, color: palette.sidebarLabelSecondary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _kindLabel(kind),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.tabActiveText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TriggerChip(trigger: trigger, palette: palette),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ruleSummary(rule),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit rule',
            color: palette.featureCardAccent,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Delete rule',
            color: palette.dangerBtnBg,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _TriggerChip extends StatelessWidget {
  final String? trigger;
  final DmToolColors palette;

  const _TriggerChip({required this.trigger, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.htmlCodeBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _triggerLabel(trigger),
        style: TextStyle(
          fontSize: 10,
          color: palette.sidebarLabelSecondary,
        ),
      ),
    );
  }
}

/// Opens the responsive rule add/edit form (bottom sheet on touch, dialog on
/// desktop). [existing] non-null ⇒ edit mode. Returns the built rule map, or
/// `null` if cancelled.
Future<Map<String, dynamic>?> showRuleEditSheet(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) {
  final form = _RuleEditForm(existing: existing);
  if (isTouchPlatform) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: form,
      ),
    );
  }
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: form,
      ),
    ),
  );
}

class _RuleEditForm extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _RuleEditForm({required this.existing});

  @override
  State<_RuleEditForm> createState() => _RuleEditFormState();
}

class _RuleEditFormState extends State<_RuleEditForm> {
  late String _kind;
  String? _trigger;

  // Structured controls (only the ones relevant to the current kind render).
  late final TextEditingController _targetCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _textCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _pickCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _advancedCtrl;
  late String _tier;
  late String _policy;
  late String _button;

  String? _advancedError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? const <String, dynamic>{};
    final kind = (e['kind'] ?? '').toString();
    _kind = RuleKinds.all.contains(kind) ? kind : RuleKinds.all.first;
    final trig = e['trigger']?.toString();
    _trigger = (trig != null && RuleTriggers.all.contains(trig)) ? trig : null;

    String s(String key) => (e[key] ?? '').toString();
    _targetCtrl = TextEditingController(text: s('target'));
    _valueCtrl = TextEditingController(text: s('value'));
    _textCtrl =
        TextEditingController(text: e['text']?.toString() ?? e['note']?.toString() ?? '');
    _promptCtrl = TextEditingController(text: s('prompt'));
    _pickCtrl = TextEditingController(text: e['pick'] == null ? '' : '${e['pick']}');
    _amountCtrl = TextEditingController(text: s('amount'));

    final tier = s('tier');
    _tier = skillTreeTiers.contains(tier) ? tier : 'proficient';
    final policy = s('policy');
    _policy = (policy == 'block' || policy == 'warn') ? policy : 'warn';
    final button = s('button');
    _button = _pouchButtons.contains(button) ? button : 'long_rest';

    // Advanced box = every carried key that isn't `kind`/`trigger` and isn't a
    // structured key for the *current* kind, so nothing in the payload is lost.
    final structured = {..._structuredKeysFor(_kind), 'kind', 'trigger'};
    final extra = <String, dynamic>{
      for (final entry in e.entries)
        if (!structured.contains(entry.key)) entry.key: entry.value,
    };
    _advancedCtrl = TextEditingController(
      text: extra.isEmpty ? '' : const JsonEncoder.withIndent('  ').convert(extra),
    );
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _valueCtrl.dispose();
    _textCtrl.dispose();
    _promptCtrl.dispose();
    _pickCtrl.dispose();
    _amountCtrl.dispose();
    _advancedCtrl.dispose();
    super.dispose();
  }

  /// Parses the advanced JSON box into an extra-params map. Sets [_advancedError]
  /// and returns null when the text is present but not a JSON object.
  Map<String, dynamic>? _parseAdvanced() {
    final raw = _advancedCtrl.text.trim();
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  void _save() {
    final extra = _parseAdvanced();
    if (extra == null) {
      setState(() => _advancedError =
          'Advanced parameters must be a JSON object, e.g. {"perPick": []}.');
      return;
    }

    final map = <String, dynamic>{'kind': _kind};
    if (_trigger != null) map['trigger'] = _trigger;

    void putText(String key, String value) {
      final v = value.trim();
      if (v.isNotEmpty) map[key] = v;
    }

    switch (_kind) {
      case RuleKinds.note:
        putText('text', _textCtrl.text);
        break;
      case RuleKinds.modifyStat:
        putText('target', _targetCtrl.text);
        final raw = _valueCtrl.text.trim();
        if (raw.isNotEmpty) {
          final n = num.tryParse(raw);
          map['value'] = n ?? raw;
        }
        break;
      case RuleKinds.grantRefs:
        putText('target', _targetCtrl.text);
        break;
      case RuleKinds.grantProficiency:
        putText('target', _targetCtrl.text);
        map['tier'] = _tier;
        break;
      case RuleKinds.choose:
        putText('prompt', _promptCtrl.text);
        putText('target', _targetCtrl.text);
        final pick = int.tryParse(_pickCtrl.text.trim());
        if (pick != null && pick > 0) map['pick'] = pick;
        break;
      case RuleKinds.setPouchMax:
      case RuleKinds.grantPouch:
        putText('target', _targetCtrl.text);
        break;
      case RuleKinds.refillPouch:
      case RuleKinds.emptyPouch:
        map['button'] = _button;
        putText('amount', _amountCtrl.text);
        break;
      case RuleKinds.checkClauses:
        map['policy'] = _policy;
        break;
    }

    // Advanced keys fill in anything not set by the structured controls; a
    // structured value always wins so the friendly form is authoritative.
    extra.forEach((k, v) {
      if (k == 'kind' || k == 'trigger') return;
      map.putIfAbsent(k, () => v);
    });

    Navigator.of(context).pop(map);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit rule' : 'Add rule',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: palette.tabActiveText,
              ),
            ),
            const SizedBox(height: 16),

            TcLabel(text: 'Kind', palette: palette),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              isDense: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: [
                for (final k in RuleKinds.all)
                  DropdownMenuItem(value: k, child: Text(_kindLabel(k))),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _kind = v);
              },
            ),
            const SizedBox(height: 14),

            TcLabel(text: 'Trigger', palette: palette),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: _trigger,
              isDense: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Default (when granted)'),
                ),
                for (final t in RuleTriggers.all)
                  DropdownMenuItem<String?>(
                    value: t,
                    child: Text(ruleTriggerLabels[t] ?? t),
                  ),
              ],
              onChanged: (v) => setState(() => _trigger = v),
            ),
            const SizedBox(height: 14),

            ..._kindFields(palette),

            const SizedBox(height: 14),
            TcLabel(text: 'Advanced parameters (JSON)', palette: palette),
            const SizedBox(height: 4),
            Text(
              _advancedHint(_kind),
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: palette.sidebarLabelSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _advancedCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: '{ }',
                errorText: _advancedError,
              ),
              onChanged: (_) {
                if (_advancedError != null) {
                  setState(() => _advancedError = null);
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text(_isEdit ? 'Save rule' : 'Add rule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Per-kind structured controls.
  List<Widget> _kindFields(DmToolColors palette) {
    switch (_kind) {
      case RuleKinds.note:
        return [
          TcLabel(text: 'Rule text', palette: palette),
          const SizedBox(height: 6),
          TcTextField(
            controller: _textCtrl,
            maxLines: 3,
            hint: 'Player-facing text; {field_key} placeholders interpolate.',
            onChanged: (_) {},
          ),
        ];
      case RuleKinds.modifyStat:
        return [
          _targetField(palette, hint: 'e.g. ac, speed, max_hp'),
          const SizedBox(height: 12),
          TcLabel(text: 'Value', palette: palette),
          const SizedBox(height: 6),
          TcTextField(
            controller: _valueCtrl,
            hint: 'A number (2), aspect ({field}) or formula',
            onChanged: (_) {},
          ),
        ];
      case RuleKinds.grantRefs:
        return [_targetField(palette, hint: 'target list field, e.g. resistances')];
      case RuleKinds.grantProficiency:
        return [
          _targetField(palette, hint: 'skill tree field, e.g. skills'),
          const SizedBox(height: 12),
          TcLabel(text: 'Tier', palette: palette),
          const SizedBox(height: 6),
          _dropdown(
            value: _tier,
            items: skillTreeTiers,
            onChanged: (v) => setState(() => _tier = v),
          ),
        ];
      case RuleKinds.choose:
        return [
          TcLabel(text: 'Prompt', palette: palette),
          const SizedBox(height: 6),
          TcTextField(
            controller: _promptCtrl,
            hint: 'e.g. Choose an ability to increase',
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          TcLabel(text: 'Pick (how many)', palette: palette),
          const SizedBox(height: 6),
          TcTextField(
            controller: _pickCtrl,
            number: true,
            hint: '1',
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          _targetField(palette, hint: 'optional target field for the picks'),
        ];
      case RuleKinds.setPouchMax:
        return [_targetField(palette, hint: 'pouch field; blank = this field')];
      case RuleKinds.grantPouch:
        return [_targetField(palette, hint: 'optional; blank = this field')];
      case RuleKinds.refillPouch:
      case RuleKinds.emptyPouch:
        return [
          TcLabel(text: 'Button', palette: palette),
          const SizedBox(height: 6),
          _dropdown(
            value: _button,
            items: _pouchButtons,
            onChanged: (v) => setState(() => _button = v),
          ),
          const SizedBox(height: 12),
          TcLabel(text: 'Amount', palette: palette),
          const SizedBox(height: 6),
          TcTextField(
            controller: _amountCtrl,
            hint: 'all · half_max_round_up · a number · a formula',
            onChanged: (_) {},
          ),
        ];
      case RuleKinds.checkClauses:
        return [
          TcLabel(text: 'Policy', palette: palette),
          const SizedBox(height: 6),
          _dropdown(
            value: _policy,
            items: const ['warn', 'block'],
            onChanged: (v) => setState(() => _policy = v),
          ),
        ];
      default:
        return const [];
    }
  }

  Widget _targetField(DmToolColors palette, {required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TcLabel(text: 'Target', palette: palette),
        const SizedBox(height: 6),
        TcTextField(controller: _targetCtrl, hint: hint, onChanged: (_) {}),
      ],
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  /// Kind-specific hint listing the common advanced keys for the escape hatch.
  static String _advancedHint(String kind) {
    switch (kind) {
      case RuleKinds.modifyStat:
        return 'Optional: source ({"kind":"field"} / {"kind":"formula","expr":"…"}).';
      case RuleKinds.choose:
        return 'Optional: options (inline list), optionsFrom ("rows"/"refs"), '
            'perPick (nested effects applied per pick).';
      case RuleKinds.grantRefs:
        return 'Optional: refs (inline id list) — otherwise read from the field rows.';
      case RuleKinds.grantProficiency:
        return 'Optional: rows (inline list) — otherwise read from the field rows.';
      case RuleKinds.checkClauses:
        return 'Optional: clauses (inline list) — otherwise read from the field rows.';
      case RuleKinds.setPouchMax:
      case RuleKinds.grantPouch:
        return 'Optional: source / gate / column names — otherwise read from the field.';
      default:
        return 'Optional extra parameters as a JSON object.';
    }
  }
}
