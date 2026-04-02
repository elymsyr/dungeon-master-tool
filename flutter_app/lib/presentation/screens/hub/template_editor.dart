import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/schema/category_rule.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';

const _uuid = Uuid();
const _allSections = ['encounter', 'mindmap', 'worldmap', 'projection'];
const _sectionLabels = {
  'encounter': 'Encounter',
  'mindmap': 'Mind Map',
  'worldmap': 'World Map',
  'projection': 'Projection',
};

/// Full template editor — kategori + alan + encounter kolon yönetimi.
class TemplateEditor extends StatefulWidget {
  final WorldSchema? initial; // null = yeni template
  final bool readOnly;
  final ValueChanged<WorldSchema>? onSave;
  final VoidCallback onBack;

  const TemplateEditor({
    this.initial,
    this.readOnly = false,
    this.onSave,
    required this.onBack,
    super.key,
  });

  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  late WorldSchema _schema;
  int _selectedCatIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _schema = widget.initial!;
    } else {
      final now = DateTime.now().toUtc().toIso8601String();
      _schema = WorldSchema(
        schemaId: _uuid.v4(),
        name: 'New Template',
        version: '1.0.0',
        description: '',
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final cats = _schema.categories;
    final selectedCat = cats.isNotEmpty && _selectedCatIndex < cats.length
        ? cats[_selectedCatIndex]
        : null;

    return Column(
      children: [
        // Üst bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            border: Border(bottom: BorderSide(color: palette.featureCardBorder)),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: widget.onBack, visualDensity: VisualDensity.compact),
              const SizedBox(width: 8),
              // Template adı
              Expanded(
                child: widget.readOnly
                    ? Text(_schema.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText))
                    : TextFormField(
                        initialValue: _schema.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Template name', isDense: true, filled: false),
                        onChanged: (v) => _schema = _schema.copyWith(name: v),
                      ),
              ),
              if (widget.readOnly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: palette.sidebarFilterBg, borderRadius: BorderRadius.circular(4)),
                  child: Text('Read Only', style: TextStyle(fontSize: 10, color: palette.tabText)),
                ),
              if (!widget.readOnly) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => widget.onSave?.call(_schema),
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                ),
              ],
            ],
          ),
        ),

        // İçerik: sol kategori listesi + sağ detay
        Expanded(
          child: Row(
            children: [
              // Sol: Kategori listesi
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: cats.length,
                        itemBuilder: (context, i) {
                          final cat = cats[i];
                          final isSelected = i == _selectedCatIndex;
                          final color = _parseColor(cat.color);

                          return InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => setState(() => _selectedCatIndex = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.1) : null,
                                borderRadius: BorderRadius.circular(4),
                                border: isSelected ? Border.all(color: color.withValues(alpha: 0.4)) : null,
                              ),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(cat.name, style: TextStyle(fontSize: 13, color: palette.tabActiveText, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                                  ),
                                  Text('${cat.fields.length}', style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      Divider(height: 1, color: palette.sidebarDivider),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _addCategory,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add'),
                                style: FilledButton.styleFrom(backgroundColor: palette.successBtnBg, minimumSize: const Size(0, 32)),
                              ),
                            ),
                            if (selectedCat != null && !selectedCat.isBuiltin) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.delete, size: 18, color: palette.dangerBtnBg),
                                onPressed: () => _deleteCategory(_selectedCatIndex),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              VerticalDivider(width: 1, color: palette.sidebarDivider),

              // Sağ: Kategori detayı
              Expanded(
                child: selectedCat == null
                    ? Center(child: Text('Select or add a category', style: TextStyle(color: palette.sidebarLabelSecondary)))
                    : _CategoryEditor(
                        category: selectedCat,
                        allCategories: cats,
                        readOnly: widget.readOnly,
                        palette: palette,
                        onChanged: (updated) => setState(() {
                          final list = List<EntityCategorySchema>.from(_schema.categories);
                          list[_selectedCatIndex] = updated;
                          _schema = _schema.copyWith(categories: list);
                        }),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addCategory() {
    final now = DateTime.now().toUtc().toIso8601String();
    final newCat = EntityCategorySchema(
      categoryId: _uuid.v4(),
      schemaId: _schema.schemaId,
      name: 'New Category',
      slug: 'new-category-${_schema.categories.length}',
      color: '#808080',
      orderIndex: _schema.categories.length,
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _schema = _schema.copyWith(categories: [..._schema.categories, newCat]);
      _selectedCatIndex = _schema.categories.length - 1;
    });
  }

  void _deleteCategory(int index) {
    setState(() {
      final list = List<EntityCategorySchema>.from(_schema.categories)..removeAt(index);
      _schema = _schema.copyWith(categories: list);
      if (_selectedCatIndex >= list.length) _selectedCatIndex = list.length - 1;
    });
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return Colors.grey; }
  }
}

/// Sağ panel: tek bir kategorinin detayları.
class _CategoryEditor extends StatelessWidget {
  final EntityCategorySchema category;
  final List<EntityCategorySchema> allCategories;
  final bool readOnly;
  final DmToolColors palette;
  final ValueChanged<EntityCategorySchema> onChanged;

  const _CategoryEditor({
    required this.category,
    required this.allCategories,
    required this.readOnly,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === HEADER: Name + Color + Field count ===
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.featureCardBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.featureCardBorder),
            ),
            child: Row(
              children: [
                _ColorDot(
                  color: _parseColor(category.color),
                  readOnly: readOnly,
                  onColorChanged: (hex) => onChanged(category.copyWith(color: hex)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: readOnly
                      ? Text(category.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.tabActiveText))
                      : TextFormField(
                          initialValue: category.name,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.tabActiveText),
                          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Category name', isDense: true, filled: false),
                          onChanged: (v) => onChanged(category.copyWith(name: v)),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: palette.sidebarFilterBg, borderRadius: BorderRadius.circular(4)),
                  child: Text('${category.fields.length} fields', style: TextStyle(fontSize: 10, color: palette.tabText)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // === AVAILABLE IN (kategori seviyesi) ===
          Text('Available In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _allSections.map((section) {
              final isChecked = category.allowedInSections.contains(section);
              return FilterChip(
                label: Text(_sectionLabels[section] ?? section, style: const TextStyle(fontSize: 10)),
                selected: isChecked,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: readOnly ? null : (v) {
                  final updated = v
                      ? [...category.allowedInSections, section]
                      : category.allowedInSections.where((s) => s != section).toList();
                  onChanged(category.copyWith(allowedInSections: updated));
                },
              );
            }).toList(),
          ),

          // === ENCOUNTER SETTINGS (encounter seçili ise) ===
          if (category.allowedInSections.contains('encounter')) ...[
            const SizedBox(height: 12),
            Text('Encounter Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
            const SizedBox(height: 6),
            // Sort + Initiative satırı
            Row(
              children: [
                // Sort field
                Expanded(
                  child: _fieldDropdown(
                    label: 'Sort By',
                    value: category.encounterSortField,
                    onChanged: readOnly ? null : (v) => onChanged(category.copyWith(encounterSortField: v ?? '')),
                  ),
                ),
                const SizedBox(width: 8),
                // Sort direction
                SizedBox(
                  width: 90,
                  child: DropdownButtonFormField<String>(
                    initialValue: category.encounterSortDirection,
                    isDense: true,
                    decoration: InputDecoration(labelText: 'Dir', labelStyle: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                    items: const [
                      DropdownMenuItem(value: 'desc', child: Text('Desc', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 'asc', child: Text('Asc', style: TextStyle(fontSize: 11))),
                    ],
                    onChanged: readOnly ? null : (v) => onChanged(category.copyWith(encounterSortDirection: v ?? 'desc')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Initiative field
                Expanded(
                  child: _fieldDropdown(
                    label: 'Initiative Field',
                    value: category.encounterInitiativeField,
                    onChanged: readOnly ? null : (v) => onChanged(category.copyWith(encounterInitiativeField: v ?? '')),
                  ),
                ),
                const SizedBox(width: 8),
                // Initiative bonus field
                Expanded(
                  child: _fieldDropdown(
                    label: 'Initiative Bonus',
                    value: category.encounterInitBonusField,
                    onChanged: readOnly ? null : (v) => onChanged(category.copyWith(encounterInitBonusField: v ?? '')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Display columns
            Text('Table Columns', style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: category.fields.where((f) => !f.isList).map((f) {
                final isCol = category.encounterColumnKeys.contains(f.fieldKey);
                return FilterChip(
                  label: Text(f.label, style: const TextStyle(fontSize: 10)),
                  selected: isCol,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: readOnly ? null : (v) {
                    final updated = v
                        ? [...category.encounterColumnKeys, f.fieldKey]
                        : category.encounterColumnKeys.where((k) => k != f.fieldKey).toList();
                    onChanged(category.copyWith(encounterColumnKeys: updated));
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // === ADD BUTTONS ===
          if (!readOnly)
            Row(
              children: [
                _addButton(Icons.add, 'Field', palette.tabText, () => _addField(context)),
                const SizedBox(width: 6),
                _addPopup(
                  icon: Icons.list,
                  label: 'List',
                  color: palette.tabText,
                  items: [FieldType.text, FieldType.integer, FieldType.float_, FieldType.image, FieldType.file, FieldType.enum_]
                      .map((t) => PopupMenuItem(value: t, child: Text('${_fieldTypeName(t)} List', style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onSelected: (t) => _addListField(t),
                ),
                const SizedBox(width: 6),
                _relationPopup(palette),
              ],
            ),

          if (!readOnly) const SizedBox(height: 12),

          // === FIELD CARDS ===
          ...category.fields.asMap().entries.map((entry) {
            final i = entry.key;
            final field = entry.value;
            final isFilter = category.filterFieldKeys.contains(field.fieldKey);
            return _buildFieldRow(
              context: context,
              key: ValueKey(field.fieldId),
              index: i,
              field: field,
              isFilter: isFilter,
            );
          }),

          // Relation alanları için allowedTypes gösterimi (_inline_action hariç)
          ...category.fields.where((f) =>
              f.fieldType == FieldType.relation &&
              f.validation.allowedTypes?.contains('_inline_action') != true
          ).map((field) {
            return Padding(
              padding: const EdgeInsets.only(left: 36, top: 4, bottom: 4),
              child: Row(
                children: [
                  Text('${field.label} → ', style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                  if (!readOnly)
                    DropdownButtonHideUnderline(
                      child: Builder(builder: (context) {
                        final otherSlugs = allCategories.where((c) => c.slug != category.slug).map((c) => c.slug).toSet();
                        final currentTarget = field.validation.allowedTypes?.isNotEmpty == true ? field.validation.allowedTypes!.first : null;
                        final validValue = currentTarget != null && otherSlugs.contains(currentTarget) ? currentTarget : null;
                        return DropdownButton<String>(
                        value: validValue,
                        hint: Text('Select target category', style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                        isDense: true,
                        style: TextStyle(fontSize: 10, color: palette.featureCardAccent),
                        dropdownColor: palette.uiPopupBg,
                        items: allCategories
                            .where((c) => c.slug != category.slug)
                            .map((c) => DropdownMenuItem(value: c.slug, child: Text(c.name, style: const TextStyle(fontSize: 10))))
                            .toList(),
                        onChanged: (slug) {
                          if (slug == null) return;
                          final idx = category.fields.indexOf(field);
                          _updateField(idx, field.copyWith(
                            validation: field.validation.copyWith(allowedTypes: [slug]),
                          ));
                        },
                      );
                      }),
                    )
                  else
                    Text(
                      field.validation.allowedTypes?.join(', ') ?? 'any',
                      style: TextStyle(fontSize: 10, color: palette.featureCardAccent),
                    ),
                ],
              ),
            );
          }),

          // === RULES ===
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Rules', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText))),
              if (!readOnly)
                TextButton.icon(
                  onPressed: () => _addRule(context),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Rule', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (category.rules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No rules defined', style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
            ),
          ...category.rules.asMap().entries.map((entry) {
            final i = entry.key;
            final rule = entry.value;
            final typeLabel = switch (rule.ruleType) {
              RuleType.pullField => 'Pull',
              RuleType.mergeFields => 'Merge',
              RuleType.conditionalList => 'Conditional',
            };
            final opLabel = switch (rule.operation) {
              RuleOperation.replace => '=',
              RuleOperation.add => '+',
              RuleOperation.subtract => '−',
              RuleOperation.multiply => '×',
              RuleOperation.appendList => '⊕',
            };
            final sourcesText = rule.sources.map((s) => '${s.relationFieldKey}.${s.sourceFieldKey}').join(' $opLabel ');

            return InkWell(
              onTap: readOnly ? null : () => _editRule(context, i, rule),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.featureCardBorder.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Checkbox(
                        value: rule.enabled,
                        onChanged: readOnly ? null : (v) {
                          final updated = List<CategoryRule>.from(category.rules);
                          updated[i] = rule.copyWith(enabled: v ?? true);
                          onChanged(category.copyWith(rules: updated));
                        },
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: palette.sidebarFilterBg, borderRadius: BorderRadius.circular(3)),
                      child: Text(typeLabel, style: TextStyle(fontSize: 9, color: palette.tabText)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rule.name, style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
                          Text(
                            '$sourcesText → ${rule.targetFieldKey}'
                            '${rule.matchOnly ? ' [match]' : ' [add]'}'
                            '${rule.deactivateIfNotEquipped ? ' [equip]' : ''}',
                            style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!readOnly) ...[
                      InkWell(
                        onTap: () => _editRule(context, i, rule),
                        child: Icon(Icons.edit, size: 14, color: palette.sidebarLabelSecondary),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          final updated = List<CategoryRule>.from(category.rules)..removeAt(i);
                          onChanged(category.copyWith(rules: updated));
                        },
                        child: Icon(Icons.close, size: 14, color: palette.sidebarLabelSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
    });
  }

  void _editRule(BuildContext context, int index, CategoryRule existing) {
    _showRuleDialog(context, existing: existing, onSave: (rule) {
      final updated = List<CategoryRule>.from(category.rules);
      updated[index] = rule;
      onChanged(category.copyWith(rules: updated));
    });
  }

  void _addRule(BuildContext context) {
    _showRuleDialog(context, onSave: (rule) {
      onChanged(category.copyWith(rules: [...category.rules, rule]));
    });
  }

  void _showRuleDialog(BuildContext context, {CategoryRule? existing, required ValueChanged<CategoryRule> onSave}) {
    var ruleType = existing?.ruleType ?? RuleType.pullField;
    var operation = existing?.operation ?? RuleOperation.replace;
    var matchOnly = existing?.matchOnly ?? false;
    var deactivateIfNotEquipped = existing?.deactivateIfNotEquipped ?? false;
    final nameController = TextEditingController(text: existing?.name ?? '');
    String? sourceRelation = existing?.sources.isNotEmpty == true ? existing!.sources.first.relationFieldKey : null;
    String? sourceField = existing?.sources.isNotEmpty == true ? existing!.sources.first.sourceFieldKey : null;
    String? targetField = existing?.targetFieldKey;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Relation field'ları (tek referans)
          final relationFields = category.fields.where((f) => f.fieldType == FieldType.relation && !f.isList).toList();
          // Liste relation field'ları
          final listRelationFields = category.fields.where((f) => f.fieldType == FieldType.relation && f.isList).toList();
          // Tüm relation field'lar
          final allRelFields = [...relationFields, ...listRelationFields];
          // Hedef field'lar
          final targetFields = category.fields.toList();

          // Source relation'ın hedef kategorisindeki field'lar
          List<FieldSchema> getSourceFields() {
            if (sourceRelation == null) return [];
            final rel = category.fields.where((f) => f.fieldKey == sourceRelation);
            if (rel.isEmpty) return [];
            final types = rel.first.validation.allowedTypes;
            if (types == null || types.isEmpty) return [];
            final targetCat = allCategories.where((c) => c.slug == types.first);
            if (targetCat.isEmpty) return [];
            return targetCat.first.fields;
          }

          return AlertDialog(
            title: const Text('Add Rule', style: TextStyle(fontSize: 16)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Rule Name', hintText: 'e.g. Pull speed from Race'),
                  ),
                  const SizedBox(height: 12),
                  // Type
                  DropdownButtonFormField<RuleType>(
                    initialValue: ruleType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: RuleType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(switch (t) {
                        RuleType.pullField => 'Pull Field (single source → target)',
                        RuleType.mergeFields => 'Merge Fields (multiple sources → target)',
                        RuleType.conditionalList => 'Conditional List (list items with active/inactive)',
                      }, style: const TextStyle(fontSize: 12)),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => ruleType = v ?? RuleType.pullField),
                  ),
                  const SizedBox(height: 12),
                  // Source relation
                  Builder(builder: (_) {
                    final srcItems = (ruleType == RuleType.conditionalList ? listRelationFields : allRelFields);
                    final validSrcRel = srcItems.any((f) => f.fieldKey == sourceRelation) ? sourceRelation : null;
                    if (validSrcRel != sourceRelation) {
                      // Geçersiz — sıfırla (post-frame)
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (sourceRelation != validSrcRel) setDialogState(() { sourceRelation = validSrcRel; sourceField = null; });
                      });
                    }
                    return DropdownButtonFormField<String>(
                      key: ValueKey('src_rel_${ruleType}_${srcItems.length}'),
                      initialValue: validSrcRel,
                      decoration: const InputDecoration(labelText: 'Source Relation'),
                      items: srcItems
                          .map((f) => DropdownMenuItem(value: f.fieldKey, child: Text(f.label, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setDialogState(() { sourceRelation = v; sourceField = null; }),
                    );
                  }),
                  const SizedBox(height: 8),
                  // Source field (with type info)
                  Builder(builder: (_) {
                    final srcFields = getSourceFields();
                    return DropdownButtonFormField<String>(
                      key: ValueKey('src_field_$sourceRelation'),
                      initialValue: srcFields.any((f) => f.fieldKey == sourceField) ? sourceField : null,
                      decoration: const InputDecoration(labelText: 'Source Field'),
                      items: srcFields.map((f) {
                        final typeName = _fieldTypeName(f.fieldType) + (f.isList ? ' []' : '');
                        return DropdownMenuItem(value: f.fieldKey, child: Text(
                          '${f.label}  ($typeName)',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ));
                      }).toList(),
                      onChanged: (v) => setDialogState(() { sourceField = v; targetField = null; }),
                    );
                  }),
                  const SizedBox(height: 8),
                  // Target field — type uyumlu olanlar
                  Builder(builder: (_) {
                    final srcFields = getSourceFields();
                    final selectedSrc = srcFields.where((f) => f.fieldKey == sourceField);
                    // Uyumlu hedefler: aynı fieldType veya aynı relation allowedTypes
                    final compatibleTargets = selectedSrc.isEmpty
                        ? targetFields
                        : targetFields.where((t) {
                            final s = selectedSrc.first;
                            // relation → relation (aynı allowedTypes)
                            if (s.fieldType == FieldType.relation && t.fieldType == FieldType.relation) {
                              final sTypes = s.validation.allowedTypes ?? [];
                              final tTypes = t.validation.allowedTypes ?? [];
                              return sTypes.any((st) => tTypes.contains(st));
                            }
                            // Aynı tip
                            if (s.fieldType == t.fieldType) return true;
                            // Liste → liste (tek → listeye de atanabilir)
                            if (!s.isList && t.isList && s.fieldType == t.fieldType) return true;
                            return false;
                          }).toList();

                    return DropdownButtonFormField<String>(
                      key: ValueKey('target_$sourceField'),
                      initialValue: compatibleTargets.any((f) => f.fieldKey == targetField) ? targetField : null,
                      decoration: const InputDecoration(labelText: 'Target Field (type-compatible)'),
                      items: compatibleTargets.map((f) {
                        final typeName = _fieldTypeName(f.fieldType) + (f.isList ? ' []' : '');
                        return DropdownMenuItem(value: f.fieldKey, child: Text(
                          '${f.label}  ($typeName)',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ));
                      }).toList(),
                      onChanged: (v) => setDialogState(() => targetField = v),
                    );
                  }),
                  if (ruleType == RuleType.mergeFields) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RuleOperation>(
                      initialValue: operation,
                      decoration: const InputDecoration(labelText: 'Operation'),
                      items: RuleOperation.values.map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(switch (o) {
                          RuleOperation.replace => 'Replace (=)',
                          RuleOperation.add => 'Add (+)',
                          RuleOperation.subtract => 'Subtract (−)',
                          RuleOperation.multiply => 'Multiply (×)',
                          RuleOperation.appendList => 'Append List (⊕)',
                        }, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (v) => setDialogState(() => operation = v ?? RuleOperation.replace),
                    ),
                  ],
                  // Match or Add
                  const SizedBox(height: 8),
                  _dialogCheckbox('Match only (skip if already exists)', matchOnly,
                    (v) => setDialogState(() => matchOnly = v)),
                  // Deactivate if not equipped — sadece equip destekli source varsa
                  if (sourceRelation != null) Builder(builder: (_) {
                    final srcField = category.fields.where((f) => f.fieldKey == sourceRelation);
                    final hasEquip = srcField.isNotEmpty && srcField.first.hasEquip;
                    if (!hasEquip) return const SizedBox.shrink();
                    return _dialogCheckbox('Deactivate if source not equipped', deactivateIfNotEquipped,
                      (v) => setDialogState(() => deactivateIfNotEquipped = v));
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: sourceRelation != null && sourceField != null && targetField != null
                    ? () {
                        final rule = CategoryRule(
                          ruleId: existing?.ruleId ?? _uuid.v4(),
                          name: nameController.text.isEmpty ? 'Rule ${category.rules.length + 1}' : nameController.text,
                          ruleType: ruleType,
                          sources: [RuleSource(relationFieldKey: sourceRelation!, sourceFieldKey: sourceField!)],
                          targetFieldKey: targetField!,
                          operation: ruleType == RuleType.mergeFields ? operation : RuleOperation.replace,
                          matchOnly: matchOnly,
                          deactivateIfNotEquipped: deactivateIfNotEquipped,
                        );
                        onSave(rule);
                        Navigator.pop(ctx);
                      }
                    : null,
                child: Text(existing != null ? 'Save' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Normal tip liste alanı ekle (text list, integer list, image list...).
  void _addListField(FieldType type) {
    final now = DateTime.now().toUtc().toIso8601String();
    final label = '${_fieldTypeName(type)} List';
    final newField = FieldSchema(
      fieldId: _uuid.v4(),
      categoryId: category.categoryId,
      fieldKey: '${type.name}_list_${category.fields.length}',
      label: label,
      fieldType: type,
      isList: true,
      orderIndex: category.fields.length,
      createdAt: now,
      updatedAt: now,
    );
    onChanged(category.copyWith(fields: [...category.fields, newField]));
  }

  /// Relation alanı ekle — single veya list.
  void _addRelationField(String targetSlug, bool isList) {
    final targetCat = allCategories.where((c) => c.slug == targetSlug);
    final targetName = targetCat.isNotEmpty ? targetCat.first.name : targetSlug;
    final now = DateTime.now().toUtc().toIso8601String();
    final label = isList ? '$targetName List' : targetName;
    final key = isList ? '${targetSlug}_list' : targetSlug;

    final newField = FieldSchema(
      fieldId: _uuid.v4(),
      categoryId: category.categoryId,
      fieldKey: '${key}_${category.fields.length}',
      label: label,
      fieldType: FieldType.relation,
      isList: isList,
      validation: FieldValidation(allowedTypes: [targetSlug]),
      orderIndex: category.fields.length,
      createdAt: now,
      updatedAt: now,
    );
    onChanged(category.copyWith(fields: [...category.fields, newField]));
  }

  void _addField(BuildContext context) {
    final now = DateTime.now().toUtc().toIso8601String();
    final newField = FieldSchema(
      fieldId: _uuid.v4(),
      categoryId: category.categoryId,
      fieldKey: 'field_${category.fields.length}',
      label: 'New Field',
      fieldType: FieldType.text,
      orderIndex: category.fields.length,
      createdAt: now,
      updatedAt: now,
    );
    onChanged(category.copyWith(fields: [...category.fields, newField]));
  }

  void _updateField(int index, FieldSchema updated) {
    final list = List<FieldSchema>.from(category.fields);
    list[index] = updated;
    onChanged(category.copyWith(fields: list));
  }

  Widget _buildFieldRow({
    required BuildContext context,
    required Key key,
    required int index,
    required FieldSchema field,
    required bool isFilter,
  }) {
    final canFilter = !field.isList && const {
      FieldType.text, FieldType.integer, FieldType.float_,
      FieldType.enum_, FieldType.boolean_, FieldType.tagList, FieldType.relation,
    }.contains(field.fieldType);

    final isFirst = index == 0;
    final isLast = index == category.fields.length - 1;

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.featureCardBorder.withValues(alpha: 0.5))),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          dense: true,
          visualDensity: VisualDensity.compact,
          // Sol: oklar + ikon
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!readOnly) ...[
                InkWell(
                  onTap: isFirst ? null : () => _moveField(index, index - 1),
                  child: Icon(Icons.keyboard_arrow_up, size: 16, color: isFirst ? palette.featureCardBorder : palette.tabText),
                ),
                InkWell(
                  onTap: isLast ? null : () => _moveField(index, index + 1),
                  child: Icon(Icons.keyboard_arrow_down, size: 16, color: isLast ? palette.featureCardBorder : palette.tabText),
                ),
                const SizedBox(width: 2),
              ],
              Icon(_fieldTypeIcon(field.fieldType), size: 14, color: palette.tabText),
            ],
          ),
          // Başlık
          title: Row(
            children: [
              // Label — sabit genişlik
              SizedBox(
                width: 140,
                child: readOnly
                    ? Text(field.label, style: TextStyle(fontSize: 13, color: palette.tabActiveText), overflow: TextOverflow.ellipsis)
                    : TextFormField(
                        initialValue: field.label,
                        style: TextStyle(fontSize: 13, color: palette.tabActiveText),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, filled: false, contentPadding: EdgeInsets.zero),
                        onChanged: (v) => _updateField(index, field.copyWith(label: v)),
                      ),
              ),
              const SizedBox(width: 8),
              // Type text
              Expanded(
                child: Text(
                  _fieldTypeName(field.fieldType) + (field.isList ? ' [ ]' : ''),
                  style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                ),
              ),
              if (isFilter)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.filter_alt, size: 11, color: palette.sidebarLabelSecondary),
                ),
              // Delete
              if (!readOnly && !field.isBuiltin)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => _removeField(index),
                    child: Icon(Icons.close, size: 14, color: palette.sidebarLabelSecondary),
                  ),
                ),
            ],
          ),
          // Detay
          children: [
            if (!readOnly) ...[
              // Type dropdown
              DropdownButtonFormField<FieldType>(
                initialValue: field.fieldType,
                isDense: true,
                isExpanded: true,
                style: TextStyle(fontSize: 11, color: palette.tabActiveText),
                dropdownColor: palette.uiPopupBg,
                decoration: InputDecoration(labelText: 'Type', labelStyle: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                items: FieldType.values.map((t) => DropdownMenuItem(value: t, child: Text(_fieldTypeName(t), style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (t) { if (t != null) _updateField(index, field.copyWith(fieldType: t)); },
              ),
              const SizedBox(height: 8),
              // Checkboxes — List + Filter + Equip
              Row(
                children: [
                  _checkboxRow('List', field.isList, (v) => _updateField(index, field.copyWith(isList: v))),
                  const SizedBox(width: 16),
                  _checkboxRow('Filter', isFilter, canFilter ? (v) => _toggleFilter(field.fieldKey, v) : null),
                  // Equip — sadece isList + relation field'larda
                  if (field.isList && field.fieldType == FieldType.relation) ...[
                    const SizedBox(width: 16),
                    _checkboxRow('Equip', field.hasEquip, (v) => _updateField(index, field.copyWith(hasEquip: v))),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _checkboxRow(String label, bool value, ValueChanged<bool>? onChanged) {
    return InkWell(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18, height: 18,
              child: Checkbox(
                value: value,
                onChanged: onChanged != null ? (v) => onChanged(v ?? false) : null,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: onChanged != null ? palette.tabActiveText : palette.sidebarLabelSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _addButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color), const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ]),
      ),
    );
  }

  Widget _addPopup<T>({required IconData icon, required String label, required Color color, required List<PopupMenuEntry<T>> items, required void Function(T) onSelected}) {
    return PopupMenuButton<T>(onSelected: onSelected, offset: const Offset(0, 32), itemBuilder: (_) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color), const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ]),
      ),
    );
  }

  Widget _relationPopup(DmToolColors p) {
    return PopupMenuButton<String>(
      onSelected: (v) { final parts = v.split(':'); _addRelationField(parts[0], parts[1] == 'list'); },
      offset: const Offset(0, 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: p.featureCardAccent.withValues(alpha: 0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.link, size: 14, color: p.featureCardAccent), const SizedBox(width: 4),
          Text('Relation', style: TextStyle(fontSize: 11, color: p.featureCardAccent)),
        ]),
      ),
      itemBuilder: (_) {
        final otherCats = allCategories.where((c) => c.slug != category.slug).toList();
        if (otherCats.isEmpty) return [const PopupMenuItem(enabled: false, child: Text('No other categories'))];
        return otherCats.expand((c) {
          final cl = _parseColor(c.color);
          return [
            PopupMenuItem(value: '${c.slug}:single', child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: cl, shape: BoxShape.circle)), const SizedBox(width: 8), Text(c.name, style: const TextStyle(fontSize: 12)), Text('  single', style: TextStyle(fontSize: 9, color: p.sidebarLabelSecondary))])),
            PopupMenuItem(value: '${c.slug}:list', child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: cl, shape: BoxShape.circle)), const SizedBox(width: 8), Text('${c.name} List', style: const TextStyle(fontSize: 12)), Text('  list', style: TextStyle(fontSize: 9, color: p.sidebarLabelSecondary))])),
          ];
        }).toList();
      },
    );
  }

  Widget _dialogCheckbox(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            SizedBox(width: 20, height: 20, child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 11))),
          ],
        ),
      ),
    );
  }

  Widget _fieldDropdown({required String label, required String value, required ValueChanged<String?>? onChanged}) {
    final items = category.fields.where((f) => !f.isList).map((f) =>
      DropdownMenuItem(value: f.fieldKey, child: Text(f.label, style: const TextStyle(fontSize: 11)))
    ).toList();
    final validValue = items.any((i) => i.value == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: validValue,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
      style: TextStyle(fontSize: 11, color: palette.tabActiveText),
      dropdownColor: palette.uiPopupBg,
      items: [
        const DropdownMenuItem(value: '', child: Text('None', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic))),
        ...items,
      ],
      onChanged: onChanged,
    );
  }

  void _moveField(int from, int to) {
    final list = List<FieldSchema>.from(category.fields);
    final item = list.removeAt(from);
    list.insert(to, item);
    final reindexed = list.asMap().entries.map((e) => e.value.copyWith(orderIndex: e.key)).toList();
    onChanged(category.copyWith(fields: reindexed));
  }

  void _removeField(int index) {
    final list = List<FieldSchema>.from(category.fields)..removeAt(index);
    onChanged(category.copyWith(fields: list));
  }

  void _toggleFilter(String fieldKey, bool enabled) {
    final list = List<String>.from(category.filterFieldKeys);
    if (enabled) {
      if (!list.contains(fieldKey)) list.add(fieldKey);
    } else {
      list.remove(fieldKey);
    }
    onChanged(category.copyWith(filterFieldKeys: list));
  }

  String _fieldTypeName(FieldType t) => switch (t) {
    FieldType.text => 'Text',
    FieldType.textarea => 'Text Area',
    FieldType.markdown => 'Markdown',
    FieldType.integer => 'Integer',
    FieldType.float_ => 'Float',
    FieldType.boolean_ => 'Boolean',
    FieldType.enum_ => 'Enum',
    FieldType.date => 'Date',
    FieldType.image => 'Image',
    FieldType.file => 'File',
    FieldType.relation => 'Relation',
    FieldType.tagList => 'Tags',
    FieldType.statBlock => 'Stat Block',
    FieldType.combatStats => 'Combat Stats',
    FieldType.dice => 'Dice',
  };

  IconData _fieldTypeIcon(FieldType t) => switch (t) {
    FieldType.text || FieldType.textarea || FieldType.markdown => Icons.text_fields,
    FieldType.integer || FieldType.float_ => Icons.tag,
    FieldType.boolean_ => Icons.check_box_outlined,
    FieldType.enum_ => Icons.list,
    FieldType.date => Icons.calendar_today,
    FieldType.image => Icons.image,
    FieldType.file => Icons.attach_file,
    FieldType.relation => Icons.link,
    FieldType.tagList => Icons.label,
    FieldType.statBlock => Icons.casino,
    FieldType.combatStats => Icons.shield,
    FieldType.dice => Icons.casino,
  };

  Color _parseColor(String hex) {
    try { return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return Colors.grey; }
  }
}

/// Renk seçici nokta.
class _ColorDot extends StatelessWidget {
  final Color color;
  final bool readOnly;
  final ValueChanged<String> onColorChanged;

  const _ColorDot({required this.color, required this.readOnly, required this.onColorChanged});

  static const _presetColors = [
    '#ff9800', '#d32f2f', '#4caf50', '#7b1fa2', '#795548',
    '#1976d2', '#00897b', '#2e7d32', '#f57c00', '#5c6bc0',
    '#e91e63', '#ff7043', '#8d6e63', '#26c6da', '#ab47bc',
    '#808080', '#ffffff', '#000000',
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !readOnly,
      onSelected: onColorChanged,
      offset: const Offset(0, 30),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _presetColors.map((hex) {
              final c = Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
              return InkWell(
                onTap: () { onColorChanged(hex); Navigator.pop(context); },
                child: Container(width: 24, height: 24, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
