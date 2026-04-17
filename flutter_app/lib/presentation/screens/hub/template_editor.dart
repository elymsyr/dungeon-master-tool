import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/schema/encounter_config.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_group.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/rule_v2.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../core/utils/screen_type.dart';
import '../../dialogs/rule_builder_dialog.dart';
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
  bool _showEncounterConfig = false;
  /// Mobile: true = show detail, false = show category list
  bool _mobileShowingDetail = false;

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

  Widget _buildDetailContent(DmToolColors palette, EntityCategorySchema? selectedCat) {
    if (_showEncounterConfig) {
      return _EncounterConfigEditor(
        schema: _schema,
        readOnly: widget.readOnly,
        palette: palette,
        onSchemaChanged: (updated) => setState(() { _schema = updated; }),
      );
    }
    if (selectedCat == null) {
      return Center(child: Text('Select or add a category', style: TextStyle(color: palette.sidebarLabelSecondary)));
    }
    return _CategoryEditor(
      key: ValueKey(selectedCat.categoryId),
      category: selectedCat,
      allCategories: _schema.categories,
      readOnly: widget.readOnly,
      palette: palette,
      onChanged: (updated) => setState(() {
        final list = List<EntityCategorySchema>.from(_schema.categories);
        list[_selectedCatIndex] = updated;
        _schema = _schema.copyWith(categories: list);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final phone = isPhone(context);
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
              // Mobile detail: back to category list. Otherwise: back to templates list.
              if (phone && _mobileShowingDetail)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => setState(() => _mobileShowingDetail = false),
                  visualDensity: VisualDensity.compact,
                )
              else
                IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: widget.onBack, visualDensity: VisualDensity.compact),
              const SizedBox(width: 8),
              // Template adı
              Expanded(
                child: widget.readOnly
                    ? Text(_schema.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText), overflow: TextOverflow.ellipsis)
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
                  decoration: BoxDecoration(color: palette.sidebarFilterBg, borderRadius: palette.br),
                  child: Text('Read Only', style: TextStyle(fontSize: 10, color: palette.tabText)),
                ),
              if (!widget.readOnly) ...[
                const SizedBox(width: 8),
                phone
                    ? IconButton(
                        onPressed: () => widget.onSave?.call(_schema),
                        icon: const Icon(Icons.save, size: 20),
                        tooltip: 'Save',
                        visualDensity: VisualDensity.compact,
                      )
                    : FilledButton.icon(
                        onPressed: () => widget.onSave?.call(_schema),
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save'),
                      ),
              ],
            ],
          ),
        ),

        // İçerik
        Expanded(
          child: phone
              ? _buildMobileContent(palette, cats, selectedCat)
              : _buildDesktopContent(palette, cats, selectedCat),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop/Tablet: side-by-side
  // ---------------------------------------------------------------------------
  Widget _buildDesktopContent(DmToolColors palette, List<EntityCategorySchema> cats, EntityCategorySchema? selectedCat) {
    return Row(
      children: [
        // Sol: Encounter Settings + Kategori listesi
        SizedBox(
          width: 200,
          child: _buildCategorySidebar(palette, cats, selectedCat),
        ),
        VerticalDivider(width: 1, color: palette.sidebarDivider),
        // Sağ: detay
        Expanded(child: _buildDetailContent(palette, selectedCat)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile: single column — list OR detail
  // ---------------------------------------------------------------------------
  Widget _buildMobileContent(DmToolColors palette, List<EntityCategorySchema> cats, EntityCategorySchema? selectedCat) {
    if (_mobileShowingDetail) {
      return _buildDetailContent(palette, selectedCat);
    }
    return _buildCategorySidebar(palette, cats, selectedCat);
  }

  // ---------------------------------------------------------------------------
  // Shared category sidebar (used by both layouts)
  // ---------------------------------------------------------------------------
  Widget _buildCategorySidebar(DmToolColors palette, List<EntityCategorySchema> cats, EntityCategorySchema? selectedCat) {
    return Column(
      children: [
        // Encounter Settings butonu
        InkWell(
          onTap: () => setState(() {
            _showEncounterConfig = true;
            _mobileShowingDetail = true;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            decoration: BoxDecoration(
              color: _showEncounterConfig ? palette.tabIndicator.withValues(alpha: 0.1) : null,
              borderRadius: palette.br,
              border: _showEncounterConfig ? Border.all(color: palette.tabIndicator.withValues(alpha: 0.4)) : null,
            ),
            child: Row(
              children: [
                Icon(Icons.shield, size: 16, color: _showEncounterConfig ? palette.tabIndicator : palette.tabText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Encounter', style: TextStyle(fontSize: 13, color: palette.tabActiveText, fontWeight: _showEncounterConfig ? FontWeight.w600 : FontWeight.normal)),
                ),
                Icon(Icons.chevron_right, size: 16, color: palette.sidebarLabelSecondary),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: palette.sidebarDivider, indent: 8, endIndent: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: cats.length,
            itemBuilder: (context, i) {
              final cat = cats[i];
              final isSelected = i == _selectedCatIndex;
              final color = _parseColor(cat.color);

              return InkWell(
                key: ValueKey(cat.slug),
                borderRadius: palette.br,
                onTap: () => setState(() {
                  _selectedCatIndex = i;
                  _showEncounterConfig = false;
                  _mobileShowingDetail = true;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.1) : null,
                    borderRadius: palette.br,
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
                    style: FilledButton.styleFrom(backgroundColor: palette.successBtnBg, foregroundColor: palette.successBtnText, minimumSize: const Size(0, 32)),
                  ),
                ),
                if (selectedCat != null) ...[
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
    super.key,
    required this.category,
    required this.allCategories,
    required this.readOnly,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
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
              borderRadius: palette.br,
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
                  decoration: BoxDecoration(color: palette.sidebarFilterBg, borderRadius: palette.br),
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

          const SizedBox(height: 12),

          // === FIELD GROUPS ===
          Row(
            children: [
              Text('Field Groups', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
              const Spacer(),
              if (!readOnly)
                TextButton.icon(
                  onPressed: () {
                    final newGroup = FieldGroup(
                      groupId: _uuid.v4(),
                      name: 'New Group',
                      orderIndex: category.fieldGroups.length,
                    );
                    onChanged(category.copyWith(fieldGroups: [...category.fieldGroups, newGroup]));
                  },
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Group', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Group header
          if (category.fieldGroups.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: palette.tabBg,
              child: Row(
                children: [
                  if (!readOnly) const SizedBox(width: 40),
                  Expanded(flex: 3, child: Text('Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
                  SizedBox(width: 50, child: Text('Cols', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText), textAlign: TextAlign.center)),
                  SizedBox(width: 50, child: Text('Fields', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText), textAlign: TextAlign.center)),
                  if (!readOnly) const SizedBox(width: 28),
                ],
              ),
            ),
          // Sorted group rows
          ...(category.fieldGroups.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex))).asMap().entries.map((entry) {
            final gi = entry.key;
            final group = entry.value;
            final fieldCount = category.fields.where((f) => f.groupId == group.groupId).length;
            final sortedGroups = category.fieldGroups.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.featureCardBorder.withValues(alpha: 0.3)))),
              child: Row(
                children: [
                  if (!readOnly)
                    SizedBox(
                      width: 40,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: gi > 0 ? () {
                              final list = List.of(sortedGroups);
                              final item = list.removeAt(gi);
                              list.insert(gi - 1, item);
                              // Re-index orderIndex
                              final reindexed = list.asMap().entries.map((e) => e.value.copyWith(orderIndex: e.key)).toList();
                              onChanged(category.copyWith(fieldGroups: reindexed));
                            } : null,
                            child: Icon(Icons.keyboard_arrow_up, size: 16, color: gi > 0 ? palette.tabText : palette.featureCardBorder),
                          ),
                          InkWell(
                            onTap: gi < sortedGroups.length - 1 ? () {
                              final list = List.of(sortedGroups);
                              final item = list.removeAt(gi);
                              list.insert(gi + 1, item);
                              final reindexed = list.asMap().entries.map((e) => e.value.copyWith(orderIndex: e.key)).toList();
                              onChanged(category.copyWith(fieldGroups: reindexed));
                            } : null,
                            child: Icon(Icons.keyboard_arrow_down, size: 16, color: gi < sortedGroups.length - 1 ? palette.tabText : palette.featureCardBorder),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: readOnly ? null : () => _editGroup(context, group, (updated) {
                        final list = category.fieldGroups.map((g) => g.groupId == group.groupId ? updated : g).toList();
                        onChanged(category.copyWith(fieldGroups: list));
                      }),
                      child: Text(group.name.isEmpty ? 'Unnamed' : group.name, style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
                    ),
                  ),
                  SizedBox(width: 50, child: Text('${group.gridColumns}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 50, child: Text('$fieldCount', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  if (!readOnly)
                    SizedBox(
                      width: 28,
                      child: IconButton(
                        icon: Icon(Icons.close, size: 14, color: palette.dangerBtnBg),
                        onPressed: () {
                          final updatedFields = category.fields.map((f) =>
                            f.groupId == group.groupId ? f.copyWith(groupId: null) : f
                          ).toList();
                          final updatedGroups = category.fieldGroups.where((g) => g.groupId != group.groupId).toList();
                          onChanged(category.copyWith(fields: updatedFields, fieldGroups: updatedGroups));
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // === ADD BUTTONS ===
          if (!readOnly)
            Row(
              children: [
                _addButton(context, Icons.add, 'Field', palette.tabText, () => _addField(context)),
                const SizedBox(width: 6),
                _addPopup(
                  context: context,
                  icon: Icons.list,
                  label: 'List',
                  color: palette.tabText,
                  items: [FieldType.text, FieldType.integer, FieldType.float_, FieldType.image, FieldType.file, FieldType.pdf, FieldType.enum_]
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
            final typeLabel = rule.then_.when(
              setValue: (_, _) => 'Set',
              gateEquip: (_) => 'Gate',
              modifyWhileEquipped: (_, _) => 'Equip',
              styleItems: (_, _) => 'Style',
            );
            final subtitleText = rule.then_.when(
              setValue: (targetFieldKey, _) => '→ $targetFieldKey',
              gateEquip: (reason) => reason.isNotEmpty ? reason : 'Gate equipping',
              modifyWhileEquipped: (targetFieldKey, _) => '→ $targetFieldKey (while equipped)',
              styleItems: (listFieldKey, style) => '→ $listFieldKey${style.faded ? ' [faded]' : ''}${style.strikethrough ? ' [strike]' : ''}',
            );

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
                          final updated = List<RuleV2>.from(category.rules);
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
                      decoration: BoxDecoration(color: palette.sidebarFilterBg, borderRadius: palette.br),
                      child: Text(typeLabel, style: TextStyle(fontSize: 9, color: palette.tabText)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rule.name, style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
                          Text(
                            subtitleText,
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
                          final updated = List<RuleV2>.from(category.rules)..removeAt(i);
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

  void _editRule(BuildContext context, int index, RuleV2 existing) async {
    final result = await showRuleBuilderDialog(
      context: context,
      category: category,
      allCategories: allCategories,
      existing: existing,
    );
    if (result != null) {
      final updated = List<RuleV2>.from(category.rules);
      updated[index] = result;
      onChanged(category.copyWith(rules: updated));
    }
  }

  void _addRule(BuildContext context) async {
    final result = await showRuleBuilderDialog(
      context: context,
      category: category,
      allCategories: allCategories,
    );
    if (result != null) {
      onChanged(category.copyWith(rules: [...category.rules, result]));
    }
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
              // Label
              Expanded(
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
              Text(
                _fieldTypeName(field.fieldType) + (field.isList ? ' [ ]' : ''),
                style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
              ),
              if (isFilter)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.filter_alt, size: 11, color: palette.sidebarLabelSecondary),
                ),
              // Delete
              if (!readOnly)
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
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _checkboxRow('List', field.isList, (v) => _updateField(index, field.copyWith(isList: v))),
                  _checkboxRow('Filter', isFilter, canFilter ? (v) => _toggleFilter(field.fieldKey, v) : null),
                  // Equip — sadece isList + relation field'larda
                  if (field.isList && field.fieldType == FieldType.relation)
                    _checkboxRow('Equip', field.hasEquip, (v) => _updateField(index, field.copyWith(hasEquip: v))),
                ],
              ),
              const SizedBox(height: 8),
              // Group + Column Span
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: field.groupId,
                      isDense: true,
                      isExpanded: true,
                      style: TextStyle(fontSize: 11, color: palette.tabActiveText),
                      dropdownColor: palette.uiPopupBg,
                      decoration: InputDecoration(labelText: 'Group', labelStyle: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Ungrouped', style: TextStyle(fontSize: 11))),
                        ...category.fieldGroups.map((g) => DropdownMenuItem(
                          value: g.groupId,
                          child: Text(g.name.isEmpty ? 'Unnamed' : g.name, style: const TextStyle(fontSize: 11)),
                        )),
                      ],
                      onChanged: (v) => _updateField(index, field.copyWith(groupId: v)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<int>(
                      initialValue: field.gridColumnSpan,
                      isDense: true,
                      style: TextStyle(fontSize: 11, color: palette.tabActiveText),
                      dropdownColor: palette.uiPopupBg,
                      decoration: InputDecoration(labelText: 'Span', labelStyle: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
                      items: [1, 2, 3, 4].map((c) => DropdownMenuItem(value: c, child: Text('$c', style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (v) { if (v != null) _updateField(index, field.copyWith(gridColumnSpan: v)); },
                    ),
                  ),
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

  Widget _addButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return InkWell(
      onTap: onTap, borderRadius: palette.br,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(borderRadius: palette.br, border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color), const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ]),
      ),
    );
  }

  Widget _addPopup<T>({required BuildContext context, required IconData icon, required String label, required Color color, required List<PopupMenuEntry<T>> items, required void Function(T) onSelected}) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return PopupMenuButton<T>(onSelected: onSelected, offset: const Offset(0, 32), itemBuilder: (_) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(borderRadius: palette.br, border: Border.all(color: color.withValues(alpha: 0.4))),
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
        decoration: BoxDecoration(borderRadius: p.br, border: Border.all(color: p.featureCardAccent.withValues(alpha: 0.4))),
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
    FieldType.pdf => 'PDF',
    FieldType.relation => 'Relation',
    FieldType.tagList => 'Tags',
    FieldType.statBlock => 'Stat Block',
    FieldType.combatStats => 'Combat Stats',
    FieldType.conditionStats => 'Condition Stats',
    FieldType.dice => 'Dice',
    FieldType.slot => 'Slots',
    FieldType.proficiencyTable => 'Proficiency Table',
  };

  IconData _fieldTypeIcon(FieldType t) => switch (t) {
    FieldType.text || FieldType.textarea || FieldType.markdown => Icons.text_fields,
    FieldType.integer || FieldType.float_ => Icons.tag,
    FieldType.boolean_ => Icons.check_box_outlined,
    FieldType.enum_ => Icons.list,
    FieldType.date => Icons.calendar_today,
    FieldType.image => Icons.image,
    FieldType.file => Icons.attach_file,
    FieldType.pdf => Icons.picture_as_pdf,
    FieldType.relation => Icons.link,
    FieldType.tagList => Icons.label,
    FieldType.statBlock => Icons.casino,
    FieldType.combatStats => Icons.shield,
    FieldType.conditionStats => Icons.flash_on,
    FieldType.dice => Icons.casino,
    FieldType.slot => Icons.check_box_outlined,
    FieldType.proficiencyTable => Icons.fact_check,
  };

  void _editGroup(BuildContext context, FieldGroup group, ValueChanged<FieldGroup> onUpdate) {
    final nameCtrl = TextEditingController(text: group.name);
    int cols = group.gridColumns;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Group', style: TextStyle(fontSize: 14)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: cols,
                  decoration: const InputDecoration(labelText: 'Grid Columns'),
                  items: [1, 2, 3, 4].map((c) => DropdownMenuItem(value: c, child: Text('$c column${c > 1 ? 's' : ''}'))).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => cols = v); },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              Navigator.pop(ctx);
              onUpdate(group.copyWith(name: nameCtrl.text, gridColumns: cols));
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return Colors.grey; }
  }
}

/// Encounter ayarları editörü — combat stats alanları, kolon yapısı, conditions.
///
/// Stateful so we can keep parallel **stable row IDs** for the table-columns
/// and sub-field lists. Without these, `TextFormField` rows with only
/// `initialValue` (no key) reuse their `_FormFieldState` and
/// `TextEditingController` based on position; deleting a middle row leaves
/// the surviving rows showing stale text from neighbours, which made the UI
/// look like delete always nuked the LAST row. The IDs feed `ValueKey` so
/// Flutter's element reconciliation properly identifies which logical row
/// disappeared.
class _EncounterConfigEditor extends StatefulWidget {
  final WorldSchema schema;
  final bool readOnly;
  final DmToolColors palette;
  final ValueChanged<WorldSchema> onSchemaChanged;

  const _EncounterConfigEditor({
    required this.schema,
    required this.readOnly,
    required this.palette,
    required this.onSchemaChanged,
  });

  @override
  State<_EncounterConfigEditor> createState() => _EncounterConfigEditorState();
}

class _EncounterConfigEditorState extends State<_EncounterConfigEditor> {
  // Parallel row-id lists for the three editable lists in this editor.
  // Mutated in lockstep with the underlying data on every add / remove /
  // reorder so widget keys stay stable per logical row.
  late List<String> _columnIds;
  late List<String> _combatStatsRowIds;
  late List<String> _conditionStatsRowIds;
  // Track which parent field the sub-field row IDs were generated for so
  // we can detect when the user picks a different combat-stats /
  // condition-stats source field via the dropdown and regenerate.
  String? _lastCombatStatsFieldKey;
  String? _lastConditionStatsFieldKey;

  EncounterConfig get _config => widget.schema.encounterConfig;

  @override
  void initState() {
    super.initState();
    _columnIds = List.generate(_config.columns.length, (_) => _uuid.v4());
    _combatStatsRowIds = List.generate(
      _getSubFields(_config.combatStatsFieldKey, FieldType.combatStats).length,
      (_) => _uuid.v4(),
    );
    _conditionStatsRowIds = List.generate(
      _getSubFields(_config.conditionStatsFieldKey, FieldType.conditionStats).length,
      (_) => _uuid.v4(),
    );
    _lastCombatStatsFieldKey = _config.combatStatsFieldKey;
    _lastConditionStatsFieldKey = _config.conditionStatsFieldKey;
  }

  @override
  void didUpdateWidget(_EncounterConfigEditor old) {
    super.didUpdateWidget(old);
    final newConfig = widget.schema.encounterConfig;
    // Columns: regen IDs only when an outside-driven length change happens
    // (e.g., schema reloaded). Local mutations update _columnIds first via
    // setState, so the lengths already match by the time we get here.
    if (_columnIds.length != newConfig.columns.length) {
      _columnIds = List.generate(newConfig.columns.length, (_) => _uuid.v4());
    }
    // Combat stats sub-fields: regen if the source parent field changed
    // (different combatStats field selected) OR length differs.
    final csSubs = _getSubFields(newConfig.combatStatsFieldKey, FieldType.combatStats);
    if (_lastCombatStatsFieldKey != newConfig.combatStatsFieldKey ||
        _combatStatsRowIds.length != csSubs.length) {
      _combatStatsRowIds = List.generate(csSubs.length, (_) => _uuid.v4());
      _lastCombatStatsFieldKey = newConfig.combatStatsFieldKey;
    }
    // Condition stats sub-fields: same.
    final condSubs = _getSubFields(newConfig.conditionStatsFieldKey, FieldType.conditionStats);
    if (_lastConditionStatsFieldKey != newConfig.conditionStatsFieldKey ||
        _conditionStatsRowIds.length != condSubs.length) {
      _conditionStatsRowIds = List.generate(condSubs.length, (_) => _uuid.v4());
      _lastConditionStatsFieldKey = newConfig.conditionStatsFieldKey;
    }
  }

  void _onConfigChanged(EncounterConfig updated) {
    widget.onSchemaChanged(widget.schema.copyWith(encounterConfig: updated));
  }

  /// Find the canonical sub-fields for a given field key and type.
  List<Map<String, String>> _getSubFields(String fieldKey, FieldType fieldType) {
    if (fieldKey.isEmpty) return const [];
    for (final cat in widget.schema.categories) {
      for (final f in cat.fields) {
        if (f.fieldKey == fieldKey && f.fieldType == fieldType) {
          return f.subFields;
        }
      }
    }
    return const [];
  }

  /// All distinct field keys in the schema with the given type, formatted
  /// for the dropdowns (`<categoryName> · <label> (<key>)`). Used to power
  /// the Combat Stats / Stat Block / Condition Stats field-key pickers so
  /// the user no longer has to type the key by hand.
  List<({String key, String label})> _findFieldsOfType(FieldType type) {
    final result = <({String key, String label})>[];
    final seen = <String>{};
    for (final cat in widget.schema.categories) {
      for (final f in cat.fields) {
        if (f.fieldType == type && !seen.contains(f.fieldKey)) {
          seen.add(f.fieldKey);
          result.add((key: f.fieldKey, label: '${cat.name} · ${f.label} (${f.fieldKey})'));
        }
      }
    }
    return result;
  }

  /// Update sub-fields across ALL categories that have the matching field.
  WorldSchema _updateSubFieldsAcrossCategories(
    String fieldKey,
    FieldType fieldType,
    List<Map<String, String>> newSubFields,
  ) {
    // Build new defaultValue from sub-fields
    final newDefault = <String, dynamic>{};
    for (final sf in newSubFields) {
      newDefault[sf['key'] ?? ''] = '';
    }

    final updatedCategories = widget.schema.categories.map((cat) {
      final updatedFields = cat.fields.map((f) {
        if (f.fieldKey == fieldKey && f.fieldType == fieldType) {
          return f.copyWith(subFields: newSubFields, defaultValue: newDefault);
        }
        return f;
      }).toList();
      return cat.copyWith(fields: updatedFields);
    }).toList();
    return widget.schema.copyWith(categories: updatedCategories);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final config = _config;
    final combatStatsFields = _findFieldsOfType(FieldType.combatStats);
    final statBlockFields = _findFieldsOfType(FieldType.statBlock);
    final conditionStatsFields = _findFieldsOfType(FieldType.conditionStats);
    final combatStatsSubs = _getSubFields(config.combatStatsFieldKey, FieldType.combatStats);
    final conditionStatsSubs = _getSubFields(config.conditionStatsFieldKey, FieldType.conditionStats);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.shield, size: 20, color: palette.tabIndicator),
              const SizedBox(width: 8),
              Text('Encounter Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
            ],
          ),
          const SizedBox(height: 16),

          // Combat Stats Field + Stat Block Field — dropdowns of fields with
          // the matching FieldType across the schema (no more typing keys).
          Row(
            children: [
              Expanded(
                child: _buildFieldKeyDropdown(
                  label: 'Combat Stats Field',
                  currentKey: config.combatStatsFieldKey,
                  fields: combatStatsFields,
                  onChanged: (v) => _onConfigChanged(config.copyWith(combatStatsFieldKey: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFieldKeyDropdown(
                  label: 'Stat Block Field',
                  currentKey: config.statBlockFieldKey,
                  fields: statBlockFields,
                  onChanged: (v) => _onConfigChanged(config.copyWith(statBlockFieldKey: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Initiative + Sort By — dropdowns of sub-fields of the SELECTED
          // combat-stats parent field. The user defines sub-fields below;
          // here they just pick which one drives initiative / sort.
          Row(
            children: [
              Expanded(
                child: _buildSubFieldKeyDropdown(
                  label: 'Initiative Sub-Field',
                  currentKey: config.initiativeSubField,
                  subFields: combatStatsSubs,
                  onChanged: (v) => _onConfigChanged(config.copyWith(initiativeSubField: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSubFieldKeyDropdown(
                  label: 'Sort By',
                  currentKey: config.sortBySubField,
                  subFields: combatStatsSubs,
                  onChanged: (v) => _onConfigChanged(config.copyWith(sortBySubField: v)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  initialValue: config.sortDirection,
                  decoration: const InputDecoration(labelText: 'Dir'),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'desc', child: Text('Desc', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'asc', child: Text('Asc', style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: widget.readOnly ? null : (v) => _onConfigChanged(config.copyWith(sortDirection: v ?? 'desc')),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // === COLUMNS ===
          ..._buildColumnsSection(combatStatsSubs),

          const SizedBox(height: 20),

          // === COMBAT STATS SUB-FIELDS ===
          _buildSubFieldEditor(
            title: 'Combat Stats Sub-Fields',
            fieldKey: config.combatStatsFieldKey,
            fieldType: FieldType.combatStats,
            subFields: combatStatsSubs,
            rowIds: _combatStatsRowIds,
            mutateRowIds: (mut) => setState(() => mut(_combatStatsRowIds)),
          ),

          const SizedBox(height: 20),

          // Condition Stats Field — dropdown of conditionStats fields.
          Text('Condition Stats', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
          const SizedBox(height: 8),
          SizedBox(
            width: 300,
            child: _buildFieldKeyDropdown(
              label: 'Condition Stats Field',
              currentKey: config.conditionStatsFieldKey,
              fields: conditionStatsFields,
              onChanged: (v) => _onConfigChanged(config.copyWith(conditionStatsFieldKey: v)),
            ),
          ),
          const SizedBox(height: 12),

          // === CONDITION STATS SUB-FIELDS ===
          _buildSubFieldEditor(
            title: 'Condition Stats Sub-Fields',
            fieldKey: config.conditionStatsFieldKey,
            fieldType: FieldType.conditionStats,
            subFields: conditionStatsSubs,
            rowIds: _conditionStatsRowIds,
            mutateRowIds: (mut) => setState(() => mut(_conditionStatsRowIds)),
          ),
        ],
      ),
    );
  }

  /// Dropdown that lets the user pick which schema field of [type] backs
  /// this encounter setting (combat stats, stat block, condition stats).
  /// Falls back to a `(missing: ...)` entry when the saved key no longer
  /// matches any field — so the user can see what's broken and pick a
  /// replacement.
  Widget _buildFieldKeyDropdown({
    required String label,
    required String currentKey,
    required List<({String key, String label})> fields,
    required ValueChanged<String> onChanged,
  }) {
    final palette = widget.palette;
    final keys = fields.map((f) => f.key).toSet();
    final items = <DropdownMenuItem<String>>[
      ...fields.map((f) => DropdownMenuItem(
            value: f.key,
            child: Text(f.label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
          )),
      if (currentKey.isNotEmpty && !keys.contains(currentKey))
        DropdownMenuItem(
          value: currentKey,
          child: Text('(missing: $currentKey)', style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
        ),
    ];
    return DropdownButtonFormField<String>(
      initialValue: currentKey.isEmpty ? null : currentKey,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: items,
      onChanged: widget.readOnly
          ? null
          : (v) {
              if (v != null) onChanged(v);
            },
    );
  }

  /// Sentinel sub-field key matching `_SessionScreenState.conditionsColumnKey`
  /// — when this appears in `EncounterConfig.columns`, the encounter table
  /// renders the condition badges at that position instead of the legacy
  /// "always at the end" slot. Kept in sync with the renderer manually
  /// because the editor doesn't depend on session_screen.dart.
  static const String _conditionsColumnSentinel = '__conditions__';

  /// Dropdown for picking a sub-field key from the currently-selected
  /// combat-stats parent field. Used by Initiative / Sort By and by the
  /// table-column "sub-field" picker. Same orphan handling as the parent
  /// field-key dropdown.
  ///
  /// When [includeConditionsOption] is true, an extra "Conditions" entry
  /// is appended (sentinel value [_conditionsColumnSentinel]) so the
  /// table-columns editor can place the conditions block anywhere in the
  /// row. Initiative / Sort By leave it false — conditions can't drive
  /// numeric sorting.
  Widget _buildSubFieldKeyDropdown({
    required String label,
    required String currentKey,
    required List<Map<String, String>> subFields,
    required ValueChanged<String> onChanged,
    InputDecoration? decoration,
    bool includeConditionsOption = false,
  }) {
    final palette = widget.palette;
    final keys = subFields.map((s) => s['key'] ?? '').toSet();
    final items = <DropdownMenuItem<String>>[
      ...subFields.map((s) {
        final key = s['key'] ?? '';
        final lbl = s['label'] ?? key;
        return DropdownMenuItem(
          value: key,
          child: Text(
            key.isEmpty ? lbl : '$lbl ($key)',
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
      if (includeConditionsOption)
        DropdownMenuItem(
          value: _conditionsColumnSentinel,
          child: Text(
            'Conditions',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: palette.tabIndicator),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (currentKey.isNotEmpty &&
          !keys.contains(currentKey) &&
          !(includeConditionsOption && currentKey == _conditionsColumnSentinel))
        DropdownMenuItem(
          value: currentKey,
          child: Text('(missing: $currentKey)', style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
        ),
    ];
    return DropdownButtonFormField<String>(
      initialValue: currentKey.isEmpty ? null : currentKey,
      decoration: decoration ?? InputDecoration(labelText: label),
      isExpanded: true,
      items: items,
      onChanged: widget.readOnly
          ? null
          : (v) {
              if (v != null) onChanged(v);
            },
    );
  }

  /// The "Table Columns" block. Each row carries a stable [ValueKey] from
  /// `_columnIds[i]` so deleting / reordering doesn't leave stray
  /// `TextEditingController` state attached to the wrong row.
  List<Widget> _buildColumnsSection(List<Map<String, String>> combatStatsSubs) {
    final config = _config;
    final palette = widget.palette;
    return [
      Row(
        children: [
          Text('Table Columns', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
          const Spacer(),
          if (!widget.readOnly)
            TextButton.icon(
              onPressed: () {
                final cols = [...config.columns, const EncounterColumnConfig(subFieldKey: '', label: 'New')];
                setState(() => _columnIds.add(_uuid.v4()));
                _onConfigChanged(config.copyWith(columns: cols));
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Column', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
      const SizedBox(height: 4),
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: palette.tabBg,
        child: Row(
          children: [
            if (!widget.readOnly) const SizedBox(width: 40),
            Expanded(flex: 2, child: Text('Sub-Field', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
            Expanded(flex: 2, child: Text('Label', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
            SizedBox(width: 50, child: Text('Width', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText), textAlign: TextAlign.center)),
            SizedBox(width: 40, child: Text('Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText), textAlign: TextAlign.center)),
            SizedBox(width: 40, child: Text('+/-', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText), textAlign: TextAlign.center)),
            if (!widget.readOnly) const SizedBox(width: 28),
          ],
        ),
      ),
      // Rows — keyed by `_columnIds[i]`.
      ...config.columns.asMap().entries.map((entry) {
        final i = entry.key;
        final col = entry.value;
        final rowId = i < _columnIds.length ? _columnIds[i] : _uuid.v4();
        return Container(
          key: ValueKey('col-$rowId'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.featureCardBorder.withValues(alpha: 0.3)))),
          child: Row(
            children: [
              if (!widget.readOnly)
                SizedBox(
                  width: 40,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: i > 0
                            ? () {
                                final l = List<EncounterColumnConfig>.from(config.columns);
                                final item = l.removeAt(i);
                                l.insert(i - 1, item);
                                setState(() {
                                  final id = _columnIds.removeAt(i);
                                  _columnIds.insert(i - 1, id);
                                });
                                _onConfigChanged(config.copyWith(columns: l));
                              }
                            : null,
                        child: Icon(Icons.keyboard_arrow_up, size: 16, color: i > 0 ? palette.tabText : palette.featureCardBorder),
                      ),
                      InkWell(
                        onTap: i < config.columns.length - 1
                            ? () {
                                final l = List<EncounterColumnConfig>.from(config.columns);
                                final item = l.removeAt(i);
                                l.insert(i + 1, item);
                                setState(() {
                                  final id = _columnIds.removeAt(i);
                                  _columnIds.insert(i + 1, id);
                                });
                                _onConfigChanged(config.copyWith(columns: l));
                              }
                            : null,
                        child: Icon(Icons.keyboard_arrow_down, size: 16, color: i < config.columns.length - 1 ? palette.tabText : palette.featureCardBorder),
                      ),
                    ],
                  ),
                ),
              // Sub-field key — dropdown of the current combat-stats
              // sub-fields PLUS the special "Conditions" entry that lets
              // the user place the condition badges anywhere in the row.
              Expanded(
                flex: 2,
                child: widget.readOnly
                    ? Text(
                        col.subFieldKey == _conditionsColumnSentinel
                            ? 'Conditions'
                            : col.subFieldKey,
                        style: const TextStyle(fontSize: 12),
                      )
                    : _buildSubFieldKeyDropdown(
                        label: '',
                        currentKey: col.subFieldKey,
                        subFields: combatStatsSubs,
                        includeConditionsOption: true,
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, filled: false, contentPadding: EdgeInsets.zero),
                        onChanged: (v) {
                          final l = List<EncounterColumnConfig>.from(config.columns);
                          // When the user flips a column to conditions and
                          // hadn't customized the label, auto-fill it so
                          // the header reads "Conditions" instead of "New".
                          final autoLabel = (v == _conditionsColumnSentinel &&
                                  (col.label.isEmpty || col.label == 'New'))
                              ? 'Conditions'
                              : col.label;
                          l[i] = col.copyWith(subFieldKey: v, label: autoLabel);
                          _onConfigChanged(config.copyWith(columns: l));
                        },
                      ),
              ),
              Expanded(
                flex: 2,
                child: widget.readOnly
                    ? Text(col.label, style: const TextStyle(fontSize: 12))
                    : TextFormField(
                        initialValue: col.label,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, filled: false),
                        onChanged: (v) {
                          final l = List<EncounterColumnConfig>.from(config.columns);
                          l[i] = col.copyWith(label: v);
                          _onConfigChanged(config.copyWith(columns: l));
                        },
                      ),
              ),
              SizedBox(
                width: 50,
                child: widget.readOnly
                    ? Text('${col.width}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)
                    : TextFormField(
                        initialValue: '${col.width}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, filled: false),
                        onChanged: (v) {
                          final l = List<EncounterColumnConfig>.from(config.columns);
                          l[i] = col.copyWith(width: int.tryParse(v) ?? 0);
                          _onConfigChanged(config.copyWith(columns: l));
                        },
                      ),
              ),
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: col.editable,
                  onChanged: widget.readOnly
                      ? null
                      : (v) {
                          final l = List<EncounterColumnConfig>.from(config.columns);
                          l[i] = col.copyWith(editable: v ?? false);
                          _onConfigChanged(config.copyWith(columns: l));
                        },
                  visualDensity: VisualDensity.compact,
                ),
              ),
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: col.showButtons,
                  onChanged: widget.readOnly
                      ? null
                      : (v) {
                          final l = List<EncounterColumnConfig>.from(config.columns);
                          l[i] = col.copyWith(showButtons: v ?? false);
                          _onConfigChanged(config.copyWith(columns: l));
                        },
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (!widget.readOnly)
                SizedBox(
                  width: 28,
                  child: IconButton(
                    icon: Icon(Icons.close, size: 14, color: palette.dangerBtnBg),
                    onPressed: () {
                      final l = List<EncounterColumnConfig>.from(config.columns)..removeAt(i);
                      setState(() => _columnIds.removeAt(i));
                      _onConfigChanged(config.copyWith(columns: l));
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        );
      }),
    ];
  }

  /// Renders one sub-field list (Combat Stats or Condition Stats). Each row
  /// is keyed by `rowIds[i]` so deletes/reorders don't leak controller
  /// state across positions. Now also includes up/down reorder buttons,
  /// previously only the table-columns section had them.
  Widget _buildSubFieldEditor({
    required String title,
    required String fieldKey,
    required FieldType fieldType,
    required List<Map<String, String>> subFields,
    required List<String> rowIds,
    required void Function(void Function(List<String>)) mutateRowIds,
  }) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
            const Spacer(),
            if (!widget.readOnly)
              TextButton.icon(
                onPressed: fieldKey.isEmpty
                    ? null
                    : () {
                        final updated = [...subFields, const {'key': '', 'label': 'New Field', 'type': 'text'}];
                        mutateRowIds((ids) => ids.add(_uuid.v4()));
                        widget.onSchemaChanged(_updateSubFieldsAcrossCategories(fieldKey, fieldType, updated));
                      },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Sub-Field', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: palette.tabBg,
          child: Row(
            children: [
              if (!widget.readOnly) const SizedBox(width: 40),
              Expanded(flex: 2, child: Text('Key', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
              Expanded(flex: 2, child: Text('Label', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText))),
              SizedBox(width: 100, child: Text('Type', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.tabText), textAlign: TextAlign.center)),
              if (!widget.readOnly) const SizedBox(width: 28),
            ],
          ),
        ),
        // Rows
        ...subFields.asMap().entries.map((entry) {
          final i = entry.key;
          final sf = entry.value;
          final rowId = i < rowIds.length ? rowIds[i] : _uuid.v4();
          return Container(
            key: ValueKey('sf-$fieldKey-$rowId'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.featureCardBorder.withValues(alpha: 0.3)))),
            child: Row(
              children: [
                if (!widget.readOnly)
                  SizedBox(
                    width: 40,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: i > 0
                              ? () {
                                  final updated = subFields.map((s) => Map<String, String>.from(s)).toList();
                                  final item = updated.removeAt(i);
                                  updated.insert(i - 1, item);
                                  mutateRowIds((ids) {
                                    final id = ids.removeAt(i);
                                    ids.insert(i - 1, id);
                                  });
                                  widget.onSchemaChanged(_updateSubFieldsAcrossCategories(fieldKey, fieldType, updated));
                                }
                              : null,
                          child: Icon(Icons.keyboard_arrow_up, size: 16, color: i > 0 ? palette.tabText : palette.featureCardBorder),
                        ),
                        InkWell(
                          onTap: i < subFields.length - 1
                              ? () {
                                  final updated = subFields.map((s) => Map<String, String>.from(s)).toList();
                                  final item = updated.removeAt(i);
                                  updated.insert(i + 1, item);
                                  mutateRowIds((ids) {
                                    final id = ids.removeAt(i);
                                    ids.insert(i + 1, id);
                                  });
                                  widget.onSchemaChanged(_updateSubFieldsAcrossCategories(fieldKey, fieldType, updated));
                                }
                              : null,
                          child: Icon(Icons.keyboard_arrow_down, size: 16, color: i < subFields.length - 1 ? palette.tabText : palette.featureCardBorder),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: widget.readOnly
                      ? Text(sf['key'] ?? '', style: const TextStyle(fontSize: 12))
                      : TextFormField(
                          initialValue: sf['key'] ?? '',
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, filled: false),
                          onChanged: (v) {
                            final updated = subFields.map((s) => Map<String, String>.from(s)).toList();
                            updated[i] = {...updated[i], 'key': v};
                            widget.onSchemaChanged(_updateSubFieldsAcrossCategories(fieldKey, fieldType, updated));
                          },
                        ),
                ),
                Expanded(
                  flex: 2,
                  child: widget.readOnly
                      ? Text(sf['label'] ?? '', style: const TextStyle(fontSize: 12))
                      : TextFormField(
                          initialValue: sf['label'] ?? '',
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, filled: false),
                          onChanged: (v) {
                            final updated = subFields.map((s) => Map<String, String>.from(s)).toList();
                            updated[i] = {...updated[i], 'label': v};
                            widget.onSchemaChanged(_updateSubFieldsAcrossCategories(fieldKey, fieldType, updated));
                          },
                        ),
                ),
                SizedBox(
                  width: 100,
                  child: widget.readOnly
                      ? Text(sf['type'] ?? 'text', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)
                      : DropdownButtonFormField<String>(
                          initialValue: sf['type'] ?? 'text',
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, filled: false, contentPadding: EdgeInsets.zero),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'text', child: Text('Text', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'integer', child: Text('Integer', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'textarea', child: Text('Textarea', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'dice', child: Text('Dice', style: TextStyle(fontSize: 11))),
                          ],
                          onChanged: (v) {
                            final updated = subFields.map((s) => Map<String, String>.from(s)).toList();
                            updated[i] = {...updated[i], 'type': v ?? 'text'};
                            widget.onSchemaChanged(_updateSubFieldsAcrossCategories(fieldKey, fieldType, updated));
                          },
                        ),
                ),
                if (!widget.readOnly)
                  SizedBox(
                    width: 28,
                    child: IconButton(
                      icon: Icon(Icons.close, size: 14, color: palette.dangerBtnBg),
                      onPressed: () {
                        final updated = subFields.map((s) => Map<String, String>.from(s)).toList()..removeAt(i);
                        mutateRowIds((ids) => ids.removeAt(i));
                        widget.onSchemaChanged(_updateSubFieldsAcrossCategories(fieldKey, fieldType, updated));
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          );
        }),
        if (subFields.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              fieldKey.isEmpty
                  ? 'Select a parent field above first.'
                  : 'No sub-fields defined',
              style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

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
