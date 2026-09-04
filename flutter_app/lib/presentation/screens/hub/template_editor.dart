import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../dialogs/field_schema_dialog.dart';
import '../../theme/dm_tool_colors.dart';

const _uuid = Uuid();

/// Template gezgini/editörü. Bir [WorldSchema]'nın kategorilerini, alanlarını
/// ve gruplarını gösterir.
///
/// [onChanged] verildiğinde düzenleme modundadır: kategori ve alan ekle /
/// düzenle / sil. Built-in template için `null` geçilir — read-only kalır.
/// Düzenleme her değişiklikte [onChanged] ile yukarı bildirilir; kaydetme
/// sorumluluğu çağırana aittir.
class TemplateEditor extends StatefulWidget {
  final WorldSchema initial;
  final ValueChanged<WorldSchema>? onChanged;

  const TemplateEditor({super.key, required this.initial, this.onChanged});

  @override
  State<TemplateEditor> createState() => TemplateEditorState();
}

class TemplateEditorState extends State<TemplateEditor> {
  int _selectedIndex = 0;
  late WorldSchema _schema = widget.initial;

  bool get _editable => widget.onChanged != null;

  void _apply(WorldSchema next) {
    setState(() => _schema = next);
    widget.onChanged?.call(next);
  }

  void _replaceCategory(int index, EntityCategorySchema cat) {
    final cats = [..._schema.categories];
    cats[index] = cat;
    _apply(_schema.copyWith(categories: cats));
  }

  Future<void> _addCategory() async {
    final name = await _promptText(context, 'New category', '');
    if (name == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final slug = fieldKeyFromLabel(name).replaceAll('_', '-');
    if (_schema.categories.any((c) => c.slug == slug)) {
      _snack('A category with slug "$slug" already exists.');
      return;
    }
    final cats = [
      ..._schema.categories,
      EntityCategorySchema(
        categoryId: _uuid.v4(),
        schemaId: _schema.schemaId,
        name: name,
        slug: slug,
        orderIndex: _schema.categories.length,
        allowedInSections: const ['mindmap', 'worldmap'],
        createdAt: now,
        updatedAt: now,
      ),
    ];
    _apply(_schema.copyWith(categories: cats));
    setState(() => _selectedIndex = cats.length - 1);
  }

  Future<void> _renameCategory(int index) async {
    final cat = _schema.categories[index];
    final name = await _promptText(context, 'Rename category', cat.name);
    if (name == null) return;
    _replaceCategory(index, cat.copyWith(name: name));
  }

  Future<void> _deleteCategory(int index) async {
    final cat = _schema.categories[index];
    final ok = await _confirm(
      context,
      'Delete category "${cat.name}"?',
      'Cards already created in this category are not deleted, but they stop '
          'rendering until the category comes back.',
    );
    if (!ok) return;
    final cats = [..._schema.categories]..removeAt(index);
    _apply(_schema.copyWith(categories: cats));
  }

  Future<void> _addField(int categoryIndex) async {
    final cat = _schema.categories[categoryIndex];
    final field = await showFieldSchemaDialog(
      context: context,
      categoryId: cat.categoryId,
      existingKeys: cat.fields.map((f) => f.fieldKey).toSet(),
      title: 'New field',
    );
    if (field == null) return;
    _replaceCategory(
      categoryIndex,
      cat.copyWith(fields: [
        ...cat.fields,
        field.copyWith(orderIndex: cat.fields.length),
      ]),
    );
  }

  Future<void> _editField(int categoryIndex, FieldSchema field) async {
    final cat = _schema.categories[categoryIndex];
    final edited = await showFieldSchemaDialog(
      context: context,
      categoryId: cat.categoryId,
      initial: field,
      existingKeys: cat.fields
          .where((f) => f.fieldId != field.fieldId)
          .map((f) => f.fieldKey)
          .toSet(),
      title: 'Edit field',
    );
    if (edited == null) return;
    _replaceCategory(
      categoryIndex,
      cat.copyWith(fields: [
        for (final f in cat.fields) f.fieldId == field.fieldId ? edited : f,
      ]),
    );
  }

  Future<void> _deleteField(int categoryIndex, FieldSchema field) async {
    final ok = await _confirm(
      context,
      'Delete field "${field.label}"?',
      'Values already stored under "${field.fieldKey}" stay on the cards but '
          'stop rendering.',
    );
    if (!ok) return;
    final cat = _schema.categories[categoryIndex];
    _replaceCategory(
      categoryIndex,
      cat.copyWith(
        fields: cat.fields.where((f) => f.fieldId != field.fieldId).toList(),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final categories = _schema.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This template has no categories.',
              style: TextStyle(color: palette.sidebarLabelSecondary),
            ),
            if (_editable) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add category'),
              ),
            ],
          ],
        ),
      );
    }

    final selectedIndex = _selectedIndex.clamp(0, categories.length - 1);
    final selected = categories[selectedIndex];

    return Row(
      children: [
        SizedBox(
          width: 240,
          child: Container(
            color: palette.sidebarFilterBg,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: categories.length,
                    itemBuilder: (ctx, i) {
                      final cat = categories[i];
                      final isSelected = i == selectedIndex;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor:
                            palette.featureCardAccent.withValues(alpha: 0.15),
                        title: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: palette.tabActiveText,
                          ),
                        ),
                        subtitle: Text(
                          '${cat.fields.length} fields',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.sidebarLabelSecondary,
                          ),
                        ),
                        trailing: _editable
                            ? PopupMenuButton<String>(
                                onSelected: (v) {
                                  switch (v) {
                                    case 'rename':
                                      _renameCategory(i);
                                    case 'delete':
                                      _deleteCategory(i);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'rename', child: Text('Rename')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Delete')),
                                ],
                              )
                            : null,
                        onTap: () => setState(() => _selectedIndex = i),
                      );
                    },
                  ),
                ),
                if (_editable)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add category'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _CategoryInspector(
            category: selected,
            palette: palette,
            onAddField: _editable ? () => _addField(selectedIndex) : null,
            onEditField:
                _editable ? (f) => _editField(selectedIndex, f) : null,
            onDeleteField:
                _editable ? (f) => _deleteField(selectedIndex, f) : null,
          ),
        ),
      ],
    );
  }
}

Future<String?> _promptText(
    BuildContext context, String title, String initial) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return (value == null || value.isEmpty) ? null : value;
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _CategoryInspector extends StatelessWidget {
  final EntityCategorySchema category;
  final DmToolColors palette;
  final VoidCallback? onAddField;
  final ValueChanged<FieldSchema>? onEditField;
  final ValueChanged<FieldSchema>? onDeleteField;

  const _CategoryInspector({
    required this.category,
    required this.palette,
    this.onAddField,
    this.onEditField,
    this.onDeleteField,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'slug: ${category.slug}',
            style: TextStyle(
              fontSize: 12,
              color: palette.sidebarLabelSecondary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fields (${category.fields.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
              if (onAddField != null)
                OutlinedButton.icon(
                  onPressed: onAddField,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add field'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...category.fields.map(
            (f) => _FieldRow(
              field: f,
              palette: palette,
              onEdit: onEditField == null ? null : () => onEditField!(f),
              onDelete: onDeleteField == null ? null : () => onDeleteField!(f),
            ),
          ),
          if (category.fieldGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Groups (${category.fieldGroups.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
            const SizedBox(height: 8),
            ...category.fieldGroups.map(
              (g) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${g.name}  (${g.gridColumns} col)',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final FieldSchema field;
  final DmToolColors palette;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _FieldRow({
    required this.field,
    required this.palette,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              field.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.tabActiveText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              field.fieldKey,
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              field.fieldType.name + (field.isList ? ' (list)' : ''),
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          if (field.isRequired)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'required',
                style: TextStyle(
                  fontSize: 10,
                  color: palette.dangerBtnBg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
