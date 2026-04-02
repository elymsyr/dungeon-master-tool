import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/field_widgets/field_widget_factory.dart';

/// Schema-driven entity card — Python ui/widgets/npc_sheet.py karşılığı.
/// Sol kenarlık kategori renginde, tüm alanlar tema-uyumlu.
class EntityCard extends ConsumerStatefulWidget {
  final String entityId;
  final EntityCategorySchema? categorySchema;
  final bool readOnly;

  const EntityCard({
    required this.entityId,
    this.categorySchema,
    this.readOnly = true,
    super.key,
  });

  @override
  ConsumerState<EntityCard> createState() => _EntityCardState();
}

class _EntityCardState extends ConsumerState<EntityCard> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _dmNotesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _dmNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dmNotesController.dispose();
    super.dispose();
  }

  void _updateField(String fieldKey, dynamic value) {
    final entities = ref.read(entityProvider);
    final entity = entities[widget.entityId];
    if (entity == null) return;

    final newFields = Map<String, dynamic>.from(entity.fields);
    newFields[fieldKey] = value;
    ref.read(entityProvider.notifier).update(entity.copyWith(fields: newFields));
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.watch(entityProvider);
    final entity = entities[widget.entityId];
    if (entity == null) {
      return const Center(child: Text('Entity not found'));
    }

    final palette = Theme.of(context).extension<DmToolColors>()!;
    final cat = widget.categorySchema;
    final catColor = cat != null ? _parseColor(cat.color) : palette.tabIndicator;

    // Controller sync
    if (_nameController.text != entity.name) _nameController.text = entity.name;
    if (_descController.text != entity.description) _descController.text = entity.description;
    if (_dmNotesController.text != entity.dmNotes) _dmNotesController.text = entity.dmNotes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === HEADER CARD: Kategori + İsim + Source ===
          _FeatureCard(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategori badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cat?.name ?? entity.categorySlug,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor),
                  ),
                ),
                const SizedBox(height: 8),
                // Entity adı
                TextFormField(
                  controller: _nameController,
                  readOnly: widget.readOnly,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: palette.tabActiveText,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Entity Name',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                  onChanged: (v) => ref.read(entityProvider.notifier).update(entity.copyWith(name: v)),
                ),
                const SizedBox(height: 4),
                // Source
                Text(
                  entity.source.isNotEmpty ? entity.source : 'Custom',
                  style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // === DESCRIPTION ===
          _FeatureCard(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  readOnly: widget.readOnly,
                  maxLines: 4,
                  style: TextStyle(fontSize: 13, color: palette.htmlText),
                  decoration: InputDecoration(
                    hintText: widget.readOnly ? null : 'Enter description...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    hintStyle: TextStyle(color: palette.sidebarLabelSecondary),
                  ),
                  onChanged: (v) => ref.read(entityProvider.notifier).update(entity.copyWith(description: v)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // === SCHEMA-DRIVEN FIELDS ===
          if (cat != null) ..._buildSchemaFields(entity, cat, palette),

          const SizedBox(height: 8),

          // === DM NOTES (kırmızı kenarlık — Python dm_note_border) ===
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.featureCardBg,
                border: Border.all(color: palette.dmNoteBorder),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock, size: 14, color: palette.dmNoteTitle),
                    const SizedBox(width: 4),
                    Text(
                      'DM Notes',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.dmNoteTitle),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dmNotesController,
                  readOnly: widget.readOnly,
                  maxLines: 4,
                  style: TextStyle(fontSize: 13, color: palette.htmlText),
                  decoration: InputDecoration(
                    hintText: 'Private DM notes...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    hintStyle: TextStyle(color: palette.sidebarLabelSecondary),
                  ),
                  onChanged: (v) => ref.read(entityProvider.notifier).update(entity.copyWith(dmNotes: v)),
                ),
              ],
            ),
          ), // Container
          ), // ClipRRect

          // === DELETE BUTTON ===
          if (!widget.readOnly) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Entity'),
                        content: Text('Are you sure you want to delete "${entity.name}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () {
                              ref.read(entityProvider.notifier).delete(entity.id);
                              Navigator.pop(ctx);
                            },
                            style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSchemaFields(Entity entity, EntityCategorySchema cat, DmToolColors palette) {
    final sortedFields = cat.fields.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    // Alanları gruplara ayır: basit (text/enum/relation) vs. complex (statBlock/combatStats/actionList/spellList)
    final simpleFields = <FieldSchema>[];
    final complexFields = <FieldSchema>[];

    for (final field in sortedFields) {
      if (field.visibility == FieldVisibility.private_) continue;
      switch (field.fieldType) {
        case FieldType.statBlock:
        case FieldType.combatStats:
        case FieldType.actionList:
        case FieldType.spellList:
          complexFields.add(field);
        default:
          simpleFields.add(field);
      }
    }

    return [
      // Basit alanlar bir FeatureCard içinde
      if (simpleFields.isNotEmpty)
        _FeatureCard(
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Properties', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
              const SizedBox(height: 8),
              ...simpleFields.map((field) => FieldWidgetFactory.create(
                    schema: field,
                    value: entity.fields[field.fieldKey],
                    readOnly: widget.readOnly,
                    onChanged: (v) => _updateField(field.fieldKey, v),
                  )),
            ],
          ),
        ),

      if (simpleFields.isNotEmpty && complexFields.isNotEmpty)
        const SizedBox(height: 8),

      // Complex alanlar her biri kendi card'ında
      ...complexFields.map((field) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FieldWidgetFactory.create(
              schema: field,
              value: entity.fields[field.fieldKey],
              readOnly: widget.readOnly,
              onChanged: (v) => _updateField(field.fieldKey, v),
            ),
          )),
    ];
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

/// Python QSS featureCard birebir karşılığı:
/// background + 1px border + 4px sol accent kenarlık + border-radius
class _FeatureCard extends StatelessWidget {
  final DmToolColors palette;
  final Widget child;

  const _FeatureCard({
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.featureCardBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
