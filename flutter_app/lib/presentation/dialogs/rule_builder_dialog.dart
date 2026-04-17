import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/rule_v2.dart';
import '../theme/dm_tool_colors.dart';

const _uuid = Uuid();

/// Rule builder dialog — yeni veya mevcut kurali duzenler.
Future<RuleV2?> showRuleBuilderDialog({
  required BuildContext context,
  required EntityCategorySchema category,
  required List<EntityCategorySchema> allCategories,
  RuleV2? existing,
}) {
  return showDialog<RuleV2>(
    context: context,
    builder: (ctx) => _RuleBuilderDialog(
      category: category,
      allCategories: allCategories,
      existing: existing,
    ),
  );
}

// ─── Rule Effect Type ────────────────────────────────────────────────────────

enum _RuleEffectChoice { setValue, gateEquip, modifyWhileEquipped, styleItems }

// Pill tab data for rule types
const _ruleTypeTabs = <(_RuleEffectChoice, IconData, String, String)>[
  (_RuleEffectChoice.setValue, Icons.auto_fix_high, 'Set Value', 'Auto-fill a field from related entities'),
  (_RuleEffectChoice.gateEquip, Icons.shield_outlined, 'Gate Equip', 'Block equipping unless a condition is met'),
  (_RuleEffectChoice.modifyWhileEquipped, Icons.flash_on_outlined, 'While Equipped', 'Apply effects while an item is equipped'),
  (_RuleEffectChoice.styleItems, Icons.palette_outlined, 'Style Items', 'Visually style list items by condition'),
];

class _RuleBuilderDialog extends StatefulWidget {
  final EntityCategorySchema category;
  final List<EntityCategorySchema> allCategories;
  final RuleV2? existing;

  const _RuleBuilderDialog({
    required this.category,
    required this.allCategories,
    this.existing,
  });

  @override
  State<_RuleBuilderDialog> createState() => _RuleBuilderDialogState();
}

class _RuleBuilderDialogState extends State<_RuleBuilderDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _blockReasonController;
  late final TextEditingController _literalController;
  late final TextEditingController _styleTooltipController;

  // Rule effect type
  _RuleEffectChoice _effectChoice = _RuleEffectChoice.setValue;

  // Predicate (condition)
  bool _alwaysActive = true;
  RefScope _predLeftScope = RefScope.self;
  String? _predLeftRelation;
  String? _predLeftField;
  String? _predLeftNested;
  CompareOp _predOp = CompareOp.gte;
  bool _predUseLiteral = true;
  RefScope _predRightScope = RefScope.self;
  String? _predRightRelation;
  String? _predRightField;
  String? _predRightNested;

  // Effect: setValue
  String? _targetField;
  _ValueExprChoice _valueChoice = _ValueExprChoice.fieldValue;
  RefScope _valueFieldScope = RefScope.related;
  String? _valueFieldRelation;
  String? _valueFieldKey;
  String? _valueFieldNested;
  // Effect: aggregate
  String? _aggRelation;
  String? _aggSourceField;
  AggregateOp _aggOp = AggregateOp.sum;
  bool _aggOnlyEquipped = false;
  // Effect: styleItems
  String? _styleListField;
  bool _styleFaded = true;
  bool _styleStrikethrough = false;
  // Effect: modifyWhileEquipped
  String? _modTargetField;
  // General
  int _priority = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _blockReasonController = TextEditingController();
    _literalController = TextEditingController();
    _styleTooltipController = TextEditingController();

    if (e != null) {
      _priority = e.priority;
      _initFromExisting(e);
    }
  }

  void _initFromExisting(RuleV2 rule) {
    rule.then_.when(
      setValue: (targetFieldKey, value) {
        _effectChoice = _RuleEffectChoice.setValue;
        _targetField = targetFieldKey;
        _initValueExpr(value);
      },
      gateEquip: (blockReason) {
        _effectChoice = _RuleEffectChoice.gateEquip;
        _blockReasonController.text = blockReason;
      },
      modifyWhileEquipped: (targetFieldKey, value) {
        _effectChoice = _RuleEffectChoice.modifyWhileEquipped;
        _modTargetField = targetFieldKey;
        _initValueExpr(value);
      },
      styleItems: (listFieldKey, style) {
        _effectChoice = _RuleEffectChoice.styleItems;
        _styleListField = listFieldKey;
        _styleFaded = style.faded;
        _styleStrikethrough = style.strikethrough;
        _styleTooltipController.text = style.tooltip ?? '';
      },
    );

    rule.when_.when(
      always: () => _alwaysActive = true,
      compare: (left, op, right, literalValue) {
        _alwaysActive = false;
        _predLeftScope = left.scope;
        _predLeftRelation = left.relationFieldKey;
        _predLeftField = left.fieldKey;
        _predLeftNested = left.nestedFieldKey;
        _predOp = op;
        if (right != null) {
          _predUseLiteral = false;
          _predRightScope = right.scope;
          _predRightRelation = right.relationFieldKey;
          _predRightField = right.fieldKey;
          _predRightNested = right.nestedFieldKey;
        } else {
          _predUseLiteral = true;
          _literalController.text = literalValue?.toString() ?? '';
        }
      },
      and: (_) => _alwaysActive = false,
      or: (_) => _alwaysActive = false,
      not: (_) => _alwaysActive = false,
    );
  }

  void _initValueExpr(ValueExpression value) {
    value.when(
      fieldValue: (source) {
        _valueChoice = _ValueExprChoice.fieldValue;
        _valueFieldScope = source.scope;
        _valueFieldRelation = source.relationFieldKey;
        _valueFieldKey = source.fieldKey;
        _valueFieldNested = source.nestedFieldKey;
      },
      aggregate: (relationFieldKey, sourceFieldKey, op, onlyEquipped) {
        _valueChoice = _ValueExprChoice.aggregate;
        _aggRelation = relationFieldKey;
        _aggSourceField = sourceFieldKey;
        _aggOp = op;
        _aggOnlyEquipped = onlyEquipped;
      },
      literal: (v) {
        _valueChoice = _ValueExprChoice.literal;
        _literalController.text = v?.toString() ?? '';
      },
      arithmetic: (_, _, _) {
        _valueChoice = _ValueExprChoice.fieldValue;
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _blockReasonController.dispose();
    _literalController.dispose();
    _styleTooltipController.dispose();
    super.dispose();
  }

  // ─── Field Helpers ─────────────────────────────────────────────────────────

  List<FieldSchema> get _ownFields => widget.category.fields;
  List<FieldSchema> get _relationFields => _ownFields.where((f) => f.fieldType == FieldType.relation && !f.isList).toList();
  List<FieldSchema> get _listRelationFields => _ownFields.where((f) => f.fieldType == FieldType.relation && f.isList).toList();
  List<FieldSchema> get _allRelationFields => [..._relationFields, ..._listRelationFields];

  List<FieldSchema> _fieldsOfRelation(String? key) {
    if (key == null) return [];
    final rel = _ownFields.where((f) => f.fieldKey == key).firstOrNull;
    if (rel == null) return [];
    final types = rel.validation.allowedTypes;
    if (types == null || types.isEmpty) return [];
    final targetCat = widget.allCategories.where((c) => c.slug == types.first).firstOrNull;
    return targetCat?.fields ?? [];
  }

  // ─── Main Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.rule_outlined, size: 20, color: palette.tabIndicator),
          const SizedBox(width: 8),
          Text(widget.existing != null ? 'Edit Rule' : 'New Rule', style: const TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name + Description (always visible at top) ──
              _buildNameSection(palette),
              const SizedBox(height: 16),

              // ── Rule Type Tabs (pill bar style) ──
              _buildSectionLabel('Rule Type', Icons.category_outlined, palette),
              const SizedBox(height: 8),
              _buildRuleTypeTabs(palette),
              const SizedBox(height: 4),
              _buildEffectDescription(palette),
              const SizedBox(height: 16),

              // ── Effect Configuration ──
              _buildSectionLabel('Configuration', Icons.tune_outlined, palette),
              const SizedBox(height: 8),
              _buildEffectConfig(palette),
              const SizedBox(height: 16),

              // ── Condition ──
              _buildSectionLabel('Condition', Icons.filter_alt_outlined, palette),
              const SizedBox(height: 8),
              _buildConditionSection(palette),

              // ── Priority ──
              const SizedBox(height: 16),
              _buildPrioritySection(palette),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(widget.existing != null ? 'Save' : 'Add Rule'),
        ),
      ],
    );
  }

  // ─── Section Label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text, IconData icon, DmToolColors palette) {
    return Row(
      children: [
        Icon(icon, size: 14, color: palette.tabIndicator),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: palette.featureCardBorder, height: 1)),
      ],
    );
  }

  // ─── Name Section ──────────────────────────────────────────────────────────

  Widget _buildNameSection(DmToolColors palette) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Rule name',
              hintText: 'e.g. Pull speed from Race',
              isDense: true,
              prefixIcon: Icon(Icons.label_outline, size: 16, color: palette.sidebarLabelSecondary),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Note (optional)', isDense: true),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ─── Rule Type Tabs (pill bar pattern) ─────────────────────────────────────

  Widget _buildRuleTypeTabs(DmToolColors palette) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.cbr,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: _ruleTypeTabs.map((tab) {
          final (choice, icon, label, _) = tab;
          final isActive = choice == _effectChoice;
          return Expanded(
            child: InkWell(
              borderRadius: palette.br,
              onTap: () => setState(() => _effectChoice = choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? palette.featureCardAccent : Colors.transparent,
                  borderRadius: palette.br,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: isActive ? Colors.white : palette.sidebarLabelSecondary),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? Colors.white : palette.tabText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Effect Description Card ───────────────────────────────────────────────

  Widget _buildEffectDescription(DmToolColors palette) {
    final (_, icon, title, desc) = _ruleTypeTabs.firstWhere((t) => t.$1 == _effectChoice);
    final examples = _effectExamples(_effectChoice);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: palette.tabIndicator),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...examples.map((ex) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('  ', style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                  Icon(Icons.arrow_right, size: 12, color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 2),
                  Expanded(child: Text(ex, style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary, fontStyle: FontStyle.italic))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  static List<String> _effectExamples(_RuleEffectChoice c) {
    return switch (c) {
      _RuleEffectChoice.setValue => [
        'Pull an NPC\'s speed from their Race',
        'Sum equipment bonuses into a total modifier',
        'Collect spells from all equipped items',
      ],
      _RuleEffectChoice.gateEquip => [
        'Sword requires STR >= 13 to wield',
        'Spell requires Intelligence >= spell level',
        'Heavy armor needs proficiency',
      ],
      _RuleEffectChoice.modifyWhileEquipped => [
        'Cursed ring applies -2 to AC while worn',
        'Cloak of Elvenkind grants advantage on Stealth',
        'Amulet adds +1 to all saving throws',
      ],
      _RuleEffectChoice.styleItems => [
        'Fade spells that require missing components',
        'Strikethrough abilities that are on cooldown',
        'Grey out items the character can\'t use',
      ],
    };
  }

  // ─── Effect Configuration ──────────────────────────────────────────────────

  Widget _buildEffectConfig(DmToolColors palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: switch (_effectChoice) {
        _RuleEffectChoice.setValue => _buildSetValueConfig(palette),
        _RuleEffectChoice.gateEquip => _buildGateEquipConfig(palette),
        _RuleEffectChoice.modifyWhileEquipped => _buildModifyWhileEquippedConfig(palette),
        _RuleEffectChoice.styleItems => _buildStyleItemsConfig(palette),
      },
    );
  }

  Widget _buildSetValueConfig(DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target field
        DropdownButtonFormField<String>(
          initialValue: _ownFields.any((f) => f.fieldKey == _targetField) ? _targetField : null,
          decoration: const InputDecoration(labelText: 'Write result to field', isDense: true, helperText: 'The field that will be auto-filled'),
          items: _ownFields.map((f) => DropdownMenuItem(value: f.fieldKey, child: Text('${f.label} (${_fieldTypeName(f.fieldType)}${f.isList ? ' []' : ''})', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _targetField = v),
        ),
        const SizedBox(height: 12),
        // Value source tabs
        Text('Value source', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
        const SizedBox(height: 6),
        _buildValueSourceTabs(palette),
        const SizedBox(height: 8),
        _buildValueSourceConfig(palette),
      ],
    );
  }

  Widget _buildValueSourceTabs(DmToolColors palette) {
    const tabs = <(_ValueExprChoice, IconData, String)>[
      (_ValueExprChoice.fieldValue, Icons.link, 'From Field'),
      (_ValueExprChoice.aggregate, Icons.functions, 'Aggregate'),
      (_ValueExprChoice.literal, Icons.edit_note, 'Constant'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: tabs.map((t) {
          final (choice, icon, label) = t;
          final isActive = choice == _valueChoice;
          return Expanded(
            child: InkWell(
              borderRadius: palette.br,
              onTap: () => setState(() => _valueChoice = choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? palette.featureCardAccent : Colors.transparent,
                  borderRadius: palette.br,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: isActive ? Colors.white : palette.sidebarLabelSecondary),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? Colors.white : palette.tabText)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildValueSourceConfig(DmToolColors palette) {
    switch (_valueChoice) {
      case _ValueExprChoice.fieldValue:
        return _buildFieldRefPicker(
          label: 'Source', scope: _valueFieldScope, relationKey: _valueFieldRelation, fieldKey: _valueFieldKey, nestedKey: _valueFieldNested,
          onScopeChanged: (v) => setState(() { _valueFieldScope = v; _valueFieldRelation = null; _valueFieldKey = null; _valueFieldNested = null; }),
          onRelationChanged: (v) => setState(() { _valueFieldRelation = v; _valueFieldKey = null; _valueFieldNested = null; }),
          onFieldChanged: (v) => setState(() { _valueFieldKey = v; _valueFieldNested = null; }),
          onNestedChanged: (v) => setState(() => _valueFieldNested = v),
          palette: palette,
        );
      case _ValueExprChoice.aggregate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _listRelationFields.any((f) => f.fieldKey == _aggRelation) ? _aggRelation : null,
              decoration: const InputDecoration(labelText: 'From relation list', isDense: true, helperText: 'Iterate over items in this list'),
              items: _listRelationFields.map((f) => DropdownMenuItem(value: f.fieldKey, child: Text(f.label, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() { _aggRelation = v; _aggSourceField = null; }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('agg_src_$_aggRelation'),
              initialValue: _fieldsOfRelation(_aggRelation).any((f) => f.fieldKey == _aggSourceField) ? _aggSourceField : null,
              decoration: const InputDecoration(labelText: 'Read field from each item', isDense: true),
              items: _fieldsOfRelation(_aggRelation).map((f) => DropdownMenuItem(value: f.fieldKey, child: Text(f.label, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _aggSourceField = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AggregateOp>(
              initialValue: _aggOp,
              decoration: const InputDecoration(labelText: 'Combine with', isDense: true),
              items: AggregateOp.values.map((op) => DropdownMenuItem(value: op, child: Text(_aggOpLabel(op), style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _aggOp = v ?? AggregateOp.sum),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _aggOnlyEquipped,
              title: const Text('Only from equipped sources', style: TextStyle(fontSize: 12)),
              subtitle: const Text('Skip items that are not equipped', style: TextStyle(fontSize: 10)),
              dense: true, contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _aggOnlyEquipped = v ?? false),
            ),
          ],
        );
      case _ValueExprChoice.literal:
        return TextField(
          controller: _literalController,
          decoration: const InputDecoration(labelText: 'Constant value', isDense: true, helperText: 'Number, text, true/false'),
        );
    }
  }

  Widget _buildGateEquipConfig(DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When the condition below is NOT met, equipping will be blocked and this message is shown to the user:',
          style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _blockReasonController,
          decoration: InputDecoration(
            labelText: 'Block reason',
            hintText: 'e.g. Intelligence too low',
            isDense: true,
            prefixIcon: Icon(Icons.block, size: 16, color: palette.sidebarLabelSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildModifyWhileEquippedConfig(DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _ownFields.any((f) => f.fieldKey == _modTargetField) ? _modTargetField : null,
          decoration: const InputDecoration(labelText: 'Modify this field on the owner', isDense: true, helperText: 'Effect applies only while the item is equipped'),
          items: _ownFields.map((f) => DropdownMenuItem(value: f.fieldKey, child: Text('${f.label} (${_fieldTypeName(f.fieldType)})', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _modTargetField = v),
        ),
        const SizedBox(height: 12),
        Text('Value source', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
        const SizedBox(height: 6),
        _buildValueSourceTabs(palette),
        const SizedBox(height: 8),
        _buildValueSourceConfig(palette),
      ],
    );
  }

  Widget _buildStyleItemsConfig(DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _listRelationFields.any((f) => f.fieldKey == _styleListField) ? _styleListField : null,
          decoration: const InputDecoration(labelText: 'Apply style to items in', isDense: true, helperText: 'Items where the condition is NOT met will be styled'),
          items: _listRelationFields.map((f) => DropdownMenuItem(value: f.fieldKey, child: Text(f.label, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _styleListField = v),
        ),
        const SizedBox(height: 12),
        Text('Visual effects', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _styleChip(palette, 'Faded', Icons.opacity, _styleFaded, (v) => setState(() => _styleFaded = v)),
            _styleChip(palette, 'Strikethrough', Icons.strikethrough_s, _styleStrikethrough, (v) => setState(() => _styleStrikethrough = v)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _styleTooltipController,
          decoration: InputDecoration(
            labelText: 'Tooltip message',
            hintText: 'e.g. Missing required items',
            isDense: true,
            prefixIcon: Icon(Icons.info_outline, size: 16, color: palette.sidebarLabelSecondary),
          ),
        ),
      ],
    );
  }

  Widget _styleChip(DmToolColors palette, String label, IconData icon, bool active, ValueChanged<bool> onChanged) {
    return InkWell(
      borderRadius: palette.br,
      onTap: () => onChanged(!active),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? palette.featureCardAccent : Colors.transparent,
          borderRadius: palette.br,
          border: Border.all(color: active ? palette.featureCardAccent : palette.featureCardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : palette.sidebarLabelSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : palette.tabText)),
          ],
        ),
      ),
    );
  }

  // ─── Condition Section ─────────────────────────────────────────────────────

  Widget _buildConditionSection(DmToolColors palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always active toggle
          InkWell(
            borderRadius: palette.br,
            onTap: () => setState(() => _alwaysActive = !_alwaysActive),
            child: Row(
              children: [
                SizedBox(
                  width: 20, height: 20,
                  child: Checkbox(
                    value: _alwaysActive,
                    onChanged: (v) => setState(() => _alwaysActive = v ?? true),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Always active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text('Rule fires unconditionally for every entity in this category', style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_alwaysActive) ...[
            const Divider(height: 16),
            Text('Fire only when...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
            const SizedBox(height: 8),
            // Left field ref
            _buildFieldRefPicker(
              label: 'Left', scope: _predLeftScope, relationKey: _predLeftRelation, fieldKey: _predLeftField, nestedKey: _predLeftNested,
              onScopeChanged: (v) => setState(() { _predLeftScope = v; _predLeftRelation = null; _predLeftField = null; _predLeftNested = null; }),
              onRelationChanged: (v) => setState(() { _predLeftRelation = v; _predLeftField = null; _predLeftNested = null; }),
              onFieldChanged: (v) => setState(() { _predLeftField = v; _predLeftNested = null; }),
              onNestedChanged: (v) => setState(() => _predLeftNested = v),
              palette: palette,
            ),
            const SizedBox(height: 8),
            // Operator
            DropdownButtonFormField<CompareOp>(
              initialValue: _predOp,
              decoration: const InputDecoration(labelText: 'Comparison', isDense: true),
              items: CompareOp.values.map((op) => DropdownMenuItem(value: op, child: Text(_compareOpLabel(op), style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _predOp = v ?? CompareOp.gte),
            ),
            // Right side
            if (_predOp != CompareOp.isEmpty && _predOp != CompareOp.isNotEmpty) ...[
              const SizedBox(height: 8),
              // Toggle: value vs field
              Row(
                children: [
                  Text('Compare against:', style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                  const SizedBox(width: 8),
                  _buildMiniTab(palette, 'Value', _predUseLiteral, () => setState(() => _predUseLiteral = true)),
                  const SizedBox(width: 4),
                  _buildMiniTab(palette, 'Field', !_predUseLiteral, () => setState(() => _predUseLiteral = false)),
                ],
              ),
              const SizedBox(height: 8),
              if (_predUseLiteral)
                TextField(
                  controller: _literalController,
                  decoration: const InputDecoration(labelText: 'Value', isDense: true, helperText: 'Number, text, true/false'),
                )
              else
                _buildFieldRefPicker(
                  label: 'Right', scope: _predRightScope, relationKey: _predRightRelation, fieldKey: _predRightField, nestedKey: _predRightNested,
                  onScopeChanged: (v) => setState(() { _predRightScope = v; _predRightRelation = null; _predRightField = null; _predRightNested = null; }),
                  onRelationChanged: (v) => setState(() { _predRightRelation = v; _predRightField = null; _predRightNested = null; }),
                  onFieldChanged: (v) => setState(() { _predRightField = v; _predRightNested = null; }),
                  onNestedChanged: (v) => setState(() => _predRightNested = v),
                  palette: palette,
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMiniTab(DmToolColors palette, String label, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: palette.br,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? palette.featureCardAccent : Colors.transparent,
          borderRadius: palette.br,
          border: Border.all(color: active ? palette.featureCardAccent : palette.featureCardBorder),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: active ? Colors.white : palette.tabText)),
      ),
    );
  }

  // ─── Priority ──────────────────────────────────────────────────────────────

  Widget _buildPrioritySection(DmToolColors palette) {
    return Row(
      children: [
        Icon(Icons.low_priority, size: 14, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 6),
        Text('Priority', style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: DropdownButtonFormField<int>(
            initialValue: _priority,
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            items: List.generate(10, (i) => DropdownMenuItem(value: i, child: Text('$i', style: const TextStyle(fontSize: 12)))),
            onChanged: (v) => setState(() => _priority = v ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        Text('(lower runs first)', style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
      ],
    );
  }

  // ─── Field Ref Picker ──────────────────────────────────────────────────────

  Widget _buildFieldRefPicker({
    required String label,
    required RefScope scope,
    required String? relationKey,
    required String? fieldKey,
    required String? nestedKey,
    required ValueChanged<RefScope> onScopeChanged,
    required ValueChanged<String?> onRelationChanged,
    required ValueChanged<String?> onFieldChanged,
    required ValueChanged<String?> onNestedChanged,
    required DmToolColors palette,
  }) {
    final List<FieldSchema> availableFields;
    switch (scope) {
      case RefScope.self:
        availableFields = _ownFields;
      case RefScope.related:
      case RefScope.relatedItems:
        availableFields = relationKey != null ? _fieldsOfRelation(relationKey) : [];
    }

    final selectedField = availableFields.where((f) => f.fieldKey == fieldKey).firstOrNull;
    final hasNested = selectedField != null &&
        (selectedField.fieldType == FieldType.statBlock || selectedField.fieldType == FieldType.combatStats) &&
        selectedField.subFields.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scope tabs (pill style)
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            borderRadius: palette.br,
            border: Border.all(color: palette.featureCardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _scopeTab(palette, 'This entity', RefScope.self, scope, onScopeChanged),
              _scopeTab(palette, 'Related entity', RefScope.related, scope, onScopeChanged),
              _scopeTab(palette, 'List items', RefScope.relatedItems, scope, onScopeChanged),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Relation picker
        if (scope != RefScope.self) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('${label}_rel_$scope'),
            initialValue: (scope == RefScope.relatedItems ? _listRelationFields : _allRelationFields).any((f) => f.fieldKey == relationKey) ? relationKey : null,
            decoration: InputDecoration(labelText: 'Via relation', isDense: true, helperText: scope == RefScope.relatedItems ? 'Traverse this list relation' : 'Follow this single relation'),
            items: (scope == RefScope.relatedItems ? _listRelationFields : _allRelationFields).map((f) => DropdownMenuItem(value: f.fieldKey, child: Text(f.label, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: onRelationChanged,
          ),
          const SizedBox(height: 6),
        ],
        // Field picker
        DropdownButtonFormField<String>(
          key: ValueKey('${label}_field_${scope}_$relationKey'),
          initialValue: availableFields.any((f) => f.fieldKey == fieldKey) ? fieldKey : null,
          decoration: const InputDecoration(labelText: 'Field', isDense: true),
          items: availableFields.map((f) => DropdownMenuItem(value: f.fieldKey, child: Text('${f.label} (${_fieldTypeName(f.fieldType)})', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: onFieldChanged,
        ),
        // Nested key
        if (hasNested) ...[
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('${label}_nested_$fieldKey'),
            initialValue: selectedField.subFields.any((sf) => sf['key'] == nestedKey) ? nestedKey : null,
            decoration: const InputDecoration(labelText: 'Sub-field', isDense: true),
            items: selectedField.subFields.map((sf) => DropdownMenuItem(value: sf['key'], child: Text(sf['label'] ?? sf['key'] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: onNestedChanged,
          ),
        ],
      ],
    );
  }

  Widget _scopeTab(DmToolColors palette, String label, RefScope value, RefScope current, ValueChanged<RefScope> onChanged) {
    final isActive = value == current;
    return InkWell(
      borderRadius: palette.br,
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? palette.featureCardAccent : Colors.transparent,
          borderRadius: palette.br,
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? Colors.white : palette.tabText)),
      ),
    );
  }

  // ─── Build Model ───────────────────────────────────────────────────────────

  bool get _canSave {
    switch (_effectChoice) {
      case _RuleEffectChoice.setValue:
        return _targetField != null;
      case _RuleEffectChoice.gateEquip:
        return !_alwaysActive;
      case _RuleEffectChoice.modifyWhileEquipped:
        return _modTargetField != null;
      case _RuleEffectChoice.styleItems:
        return _styleListField != null;
    }
  }

  Predicate _buildPredicate() {
    if (_alwaysActive) return const Predicate.always();
    return Predicate.compare(
      left: FieldRef(scope: _predLeftScope, fieldKey: _predLeftField ?? '', relationFieldKey: _predLeftScope != RefScope.self ? _predLeftRelation : null, nestedFieldKey: _predLeftNested),
      op: _predOp,
      right: !_predUseLiteral && _predOp != CompareOp.isEmpty && _predOp != CompareOp.isNotEmpty
          ? FieldRef(scope: _predRightScope, fieldKey: _predRightField ?? '', relationFieldKey: _predRightScope != RefScope.self ? _predRightRelation : null, nestedFieldKey: _predRightNested)
          : null,
      literalValue: _predUseLiteral ? _parseLiteral(_literalController.text) : null,
    );
  }

  ValueExpression _buildValueExpression() {
    switch (_valueChoice) {
      case _ValueExprChoice.fieldValue:
        return ValueExpression.fieldValue(FieldRef(scope: _valueFieldScope, fieldKey: _valueFieldKey ?? '', relationFieldKey: _valueFieldScope != RefScope.self ? _valueFieldRelation : null, nestedFieldKey: _valueFieldNested));
      case _ValueExprChoice.aggregate:
        return ValueExpression.aggregate(relationFieldKey: _aggRelation ?? '', sourceFieldKey: _aggSourceField ?? '', op: _aggOp, onlyEquipped: _aggOnlyEquipped);
      case _ValueExprChoice.literal:
        return ValueExpression.literal(_parseLiteral(_literalController.text));
    }
  }

  RuleEffect _buildEffect() {
    switch (_effectChoice) {
      case _RuleEffectChoice.setValue:
        return RuleEffect.setValue(targetFieldKey: _targetField!, value: _buildValueExpression());
      case _RuleEffectChoice.gateEquip:
        return RuleEffect.gateEquip(blockReason: _blockReasonController.text);
      case _RuleEffectChoice.modifyWhileEquipped:
        return RuleEffect.modifyWhileEquipped(targetFieldKey: _modTargetField!, value: _buildValueExpression());
      case _RuleEffectChoice.styleItems:
        return RuleEffect.styleItems(listFieldKey: _styleListField!, style: ItemStyle(faded: _styleFaded, strikethrough: _styleStrikethrough, tooltip: _styleTooltipController.text.isNotEmpty ? _styleTooltipController.text : null));
    }
  }

  void _save() {
    final rule = RuleV2(
      ruleId: widget.existing?.ruleId ?? _uuid.v4(),
      name: _nameController.text.isEmpty ? 'Rule' : _nameController.text,
      enabled: widget.existing?.enabled ?? true,
      when_: _buildPredicate(),
      then_: _buildEffect(),
      priority: _priority,
      description: _descriptionController.text,
    );
    Navigator.pop(context, rule);
  }

  // ─── Label Helpers ─────────────────────────────────────────────────────────

  static dynamic _parseLiteral(String text) {
    if (text.isEmpty) return null;
    final asInt = int.tryParse(text);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(text);
    if (asDouble != null) return asDouble;
    if (text.toLowerCase() == 'true') return true;
    if (text.toLowerCase() == 'false') return false;
    return text;
  }

  static String _compareOpLabel(CompareOp op) => switch (op) {
    CompareOp.eq => '= equals',
    CompareOp.neq => '!= not equals',
    CompareOp.gt => '> greater than',
    CompareOp.gte => '>= greater or equal',
    CompareOp.lt => '< less than',
    CompareOp.lte => '<= less or equal',
    CompareOp.contains => 'contains',
    CompareOp.notContains => 'not contains',
    CompareOp.isSubsetOf => 'is subset of',
    CompareOp.isSupersetOf => 'is superset of',
    CompareOp.isDisjointFrom => 'has no overlap with',
    CompareOp.isEmpty => 'is empty / null',
    CompareOp.isNotEmpty => 'is not empty',
  };

  static String _aggOpLabel(AggregateOp op) => switch (op) {
    AggregateOp.sum => 'Sum (+)',
    AggregateOp.product => 'Product (x)',
    AggregateOp.min => 'Minimum',
    AggregateOp.max => 'Maximum',
    AggregateOp.concat => 'Concatenate text',
    AggregateOp.append => 'Append to list',
    AggregateOp.replace => 'Replace (first value)',
  };

  static String _fieldTypeName(FieldType t) => switch (t) {
    FieldType.text => 'text',
    FieldType.textarea => 'textarea',
    FieldType.markdown => 'markdown',
    FieldType.integer => 'int',
    FieldType.float_ => 'float',
    FieldType.boolean_ => 'bool',
    FieldType.enum_ => 'enum',
    FieldType.date => 'date',
    FieldType.image => 'image',
    FieldType.file => 'file',
    FieldType.pdf => 'pdf',
    FieldType.relation => 'relation',
    FieldType.tagList => 'tags',
    FieldType.statBlock => 'stat block',
    FieldType.combatStats => 'combat stats',
    FieldType.conditionStats => 'conditions',
    FieldType.dice => 'dice',
    FieldType.slot => 'slot',
    FieldType.proficiencyTable => 'proficiency',
  };
}

enum _ValueExprChoice { fieldValue, aggregate, literal }
