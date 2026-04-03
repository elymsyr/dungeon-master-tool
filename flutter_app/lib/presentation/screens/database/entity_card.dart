import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../application/services/rule_engine.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_group.dart';
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
  late TextEditingController _sourceController;
  late TextEditingController _tagsController;
  late TextEditingController _dmNotesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _sourceController = TextEditingController();
    _tagsController = TextEditingController();
    _dmNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _sourceController.dispose();
    _tagsController.dispose();
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

    // Rule engine — computed değerleri hesapla
    Map<String, dynamic> computedValues = {};
    if (cat != null && cat.rules.isNotEmpty) {
      computedValues = RuleEngine.applyRules(
        entity: entity,
        category: cat,
        allEntities: entities,
      );
    }

    // Controller sync
    if (_nameController.text != entity.name) _nameController.text = entity.name;
    if (_descController.text != entity.description) _descController.text = entity.description;
    if (_dmNotesController.text != entity.dmNotes) _dmNotesController.text = entity.dmNotes;
    if (_sourceController.text != entity.source) _sourceController.text = entity.source;
    final tagsStr = entity.tags.join(', ');
    if (_tagsController.text != tagsStr) _tagsController.text = tagsStr;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === HEADER: Portre (sol) + İsim/Açıklama (sağ) ===
          _FeatureCard(
            palette: palette,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol: Portre resim galerisi
                _PortraitGallery(
                  images: [
                    if (entity.imagePath.isNotEmpty) entity.imagePath,
                    ...entity.images,
                  ],
                  readOnly: widget.readOnly,
                  palette: palette,
                  onImagesChanged: (newImages) {
                    ref.read(entityProvider.notifier).update(
                      entity.copyWith(imagePath: '', images: newImages),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Sağ: İsim, kategori, source, açıklama
                Expanded(
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
                      // İsim
                      TextFormField(
                        controller: _nameController,
                        readOnly: widget.readOnly,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.tabActiveText),
                        decoration: InputDecoration(
                          hintText: 'Entity Name',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (v) => ref.read(entityProvider.notifier).update(entity.copyWith(name: v)),
                      ),
                      const SizedBox(height: 10),
                      // Description (markdown)
                      Text('Description', style: TextStyle(fontSize: 11, color: palette.tabText)),
                      const SizedBox(height: 4),
                      if (widget.readOnly && entity.description.isNotEmpty)
                        MarkdownBody(
                          data: entity.description,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(fontSize: 13, color: palette.htmlText),
                            h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.htmlHeader),
                            h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.htmlHeader),
                            h3: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.htmlHeader),
                            code: TextStyle(fontSize: 12, backgroundColor: palette.htmlCodeBg),
                            a: TextStyle(color: palette.htmlLink),
                            listBullet: TextStyle(fontSize: 13, color: palette.htmlText),
                          ),
                        )
                      else
                        TextFormField(
                          controller: _descController,
                          readOnly: widget.readOnly,
                          maxLines: null,
                          minLines: 3,
                          style: TextStyle(fontSize: 13, color: palette.htmlText),
                          decoration: InputDecoration(
                            hintText: 'Markdown supported...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (v) => ref.read(entityProvider.notifier).update(entity.copyWith(description: v)),
                        ),
                      const SizedBox(height: 10),
                      // Source + Tags yan yana
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sourceController,
                              readOnly: widget.readOnly,
                              style: TextStyle(fontSize: 12, color: palette.htmlText),
                              decoration: InputDecoration(
                                labelText: 'Source',
                                hintText: widget.readOnly ? null : 'e.g. D&D 5e SRD',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              onChanged: (v) => ref.read(entityProvider.notifier).update(entity.copyWith(source: v)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _tagsController,
                              readOnly: widget.readOnly,
                              style: TextStyle(fontSize: 12, color: palette.htmlText),
                              decoration: InputDecoration(
                                labelText: 'Tags',
                                hintText: widget.readOnly ? null : 'comma separated',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              onChanged: (v) {
                                final tags = v.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                                ref.read(entityProvider.notifier).update(entity.copyWith(tags: tags));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // === SCHEMA-DRIVEN FIELDS ===
          if (cat != null) ..._buildSchemaFields(entity, cat, palette, computedValues),

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
                            style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldWidget(FieldSchema field, Entity entity, Map<String, dynamic> computed, DmToolColors palette) {
    final hasComputed = computed.containsKey(field.fieldKey);
    final fieldValue = hasComputed ? computed[field.fieldKey] : entity.fields[field.fieldKey];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldWidgetFactory.create(
          schema: field,
          value: fieldValue,
          readOnly: hasComputed && !(field.isList && field.fieldType == FieldType.relation) ? true : widget.readOnly,
          onChanged: (v) => _updateField(field.fieldKey, v),
          entities: ref.read(entityProvider),
          ref: ref,
          computedMode: hasComputed,
        ),
        if (hasComputed)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high, size: 12, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 4),
                Text('Auto-filled by rule', style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGroupGrid(List<FieldSchema> fields, int gridColumns, Entity entity, Map<String, dynamic> computed, DmToolColors palette) {
    if (gridColumns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.map((f) => _buildFieldWidget(f, entity, computed, palette)).toList(),
      );
    }

    // Satır satır böl — her satırdaki field'lar IntrinsicHeight ile eşit yükseklikte
    final rows = <List<FieldSchema>>[];
    var colsUsed = 0;
    var currentRow = <FieldSchema>[];
    for (final field in fields) {
      final span = field.gridColumnSpan.clamp(1, gridColumns);
      if (colsUsed + span > gridColumns && currentRow.isNotEmpty) {
        rows.add(currentRow);
        currentRow = [];
        colsUsed = 0;
      }
      currentRow.add(field);
      colsUsed += span;
    }
    if (currentRow.isNotEmpty) rows.add(currentRow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((rowFields) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowFields.map((field) {
            final span = field.gridColumnSpan.clamp(1, gridColumns);
            return Expanded(
              flex: span,
              child: _buildFieldWidget(field, entity, computed, palette),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  List<Widget> _buildSchemaFields(Entity entity, EntityCategorySchema cat, DmToolColors palette, Map<String, dynamic> computed) {
    final allFields = cat.fields.where((f) => f.visibility != FieldVisibility.private_).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    // Grupsuz field'lar
    final ungrouped = allFields.where((f) => f.groupId == null).toList();

    // Gruplu field'lar → Map<groupId, List<FieldSchema>>
    final grouped = <String, List<FieldSchema>>{};
    for (final f in allFields) {
      if (f.groupId != null) {
        (grouped[f.groupId!] ??= []).add(f);
      }
    }

    // Gruplar sıralı
    final sortedGroups = cat.fieldGroups.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final widgets = <Widget>[];

    // Grupsuz field'lar (geriye uyumluluk)
    if (ungrouped.isNotEmpty) {
      widgets.add(_FeatureCard(
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Properties', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText)),
            const SizedBox(height: 8),
            ...ungrouped.map((f) => _buildFieldWidget(f, entity, computed, palette)),
          ],
        ),
      ));
    }

    // Gruplar (collapsible)
    for (final group in sortedGroups) {
      final groupFields = grouped[group.groupId];
      if (groupFields == null || groupFields.isEmpty) continue;

      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));

      widgets.add(_CollapsibleGroupCard(
        group: group,
        palette: palette,
        child: _buildGroupGrid(groupFields, group.gridColumns, entity, computed, palette),
      ));
    }

    return widgets;
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

/// Portre resim galerisi — 200x260 sabit, hover'da sol/sağ nav, edit modda üstte ekle / altta sil.
class _PortraitGallery extends StatefulWidget {
  final List<String> images;
  final bool readOnly;
  final DmToolColors palette;
  final ValueChanged<List<String>> onImagesChanged;

  const _PortraitGallery({
    required this.images,
    required this.readOnly,
    required this.palette,
    required this.onImagesChanged,
  });

  @override
  State<_PortraitGallery> createState() => _PortraitGalleryState();
}

class _PortraitGalleryState extends State<_PortraitGallery> {
  int _currentIndex = 0;
  bool _hovered = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    final newPaths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();
    widget.onImagesChanged([...widget.images, ...newPaths]);
  }

  void _removeCurrentImage() {
    if (widget.images.isEmpty) return;
    final updated = List<String>.from(widget.images)..removeAt(_currentIndex);
    if (_currentIndex >= updated.length && updated.isNotEmpty) {
      _currentIndex = updated.length - 1;
    }
    widget.onImagesChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    // Index clamp
    if (_currentIndex >= widget.images.length) _currentIndex = widget.images.length - 1;
    if (_currentIndex < 0) _currentIndex = 0;

    final br = BorderRadius.circular(widget.palette.cardBorderRadius);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: 200,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border.all(color: widget.palette.featureCardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Resim veya placeholder
            widget.images.isNotEmpty
                ? _buildImage(widget.images[_currentIndex])
                : _buildPlaceholder(),

            // Hover: hafif overlay
            if (_hovered && widget.images.isNotEmpty)
              Container(color: Colors.black.withValues(alpha: 0.08)),

            // Nav: Sol ok
            if (_hovered && widget.images.length > 1 && _currentIndex > 0)
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex--),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),

            // Nav: Sağ ok
            if (_hovered && widget.images.length > 1 && _currentIndex < widget.images.length - 1)
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex++),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),

            // Sayaç
            if (widget.images.length > 1)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${_currentIndex + 1}/${widget.images.length}',
                      style: const TextStyle(fontSize: 9, color: Colors.white70),
                    ),
                  ),
                ),
              ),

            // Edit: üstte ekle
            if (!widget.readOnly && _hovered)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                    child: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 14),
                  ),
                ),
              ),

            // Edit: altta sil
            if (!widget.readOnly && _hovered && widget.images.isNotEmpty)
              Positioned(
                top: 4,
                left: 4,
                child: GestureDetector(
                  onTap: _removeCurrentImage,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                    child: Icon(Icons.close, color: widget.palette.dangerBtnBg, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    final file = File(path);
    if (!file.existsSync()) return _buildPlaceholder();
    return Image.file(
      file,
      width: 200,
      height: 260,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 200,
      height: 260,
      color: widget.palette.featureCardBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 48, color: widget.palette.sidebarLabelSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          Text('No Image', style: TextStyle(fontSize: 10, color: widget.palette.sidebarLabelSecondary)),
        ],
      ),
    );
  }
}

/// Basit section card — arka plan + padding, border yok.
/// Collapsible grup kartı — başlığa tıklayarak açılıp kapanır.
class _CollapsibleGroupCard extends StatefulWidget {
  final FieldGroup group;
  final DmToolColors palette;
  final Widget child;

  const _CollapsibleGroupCard({
    required this.group,
    required this.palette,
    required this.child,
  });

  @override
  State<_CollapsibleGroupCard> createState() => _CollapsibleGroupCardState();
}

class _CollapsibleGroupCardState extends State<_CollapsibleGroupCard> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.group.isCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık — tıklanabilir
          if (widget.group.name.isNotEmpty)
            InkWell(
              onTap: () => setState(() => _collapsed = !_collapsed),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _collapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 16,
                      color: widget.palette.tabText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.group.name,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.palette.tabText),
                    ),
                  ],
                ),
              ),
            ),
          // İçerik
          if (!_collapsed)
            Padding(
              padding: EdgeInsets.fromLTRB(12, widget.group.name.isEmpty ? 12 : 0, 12, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

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
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
