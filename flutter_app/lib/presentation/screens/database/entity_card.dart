import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/media_provider.dart';
import '../../../application/providers/projection_provider.dart';
import '../../../application/providers/rule_provider.dart';
import '../../../application/services/rule_engine_v2.dart';
import '../../../domain/entities/schema/rule_v2.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_group.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../dialogs/media_gallery_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/asset_ref_image.dart';
import '../../widgets/field_widgets/field_widget_factory.dart';
import '../../widgets/markdown_text_area.dart';
import '../../widgets/projection/projectable.dart';

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

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();
  final FocusNode _sourceFocus = FocusNode();
  final FocusNode _tagsFocus = FocusNode();
  final FocusNode _dmNotesFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _sourceController = TextEditingController();
    _tagsController = TextEditingController();
    _dmNotesController = TextEditingController();
  }

  Timer? _updateTimer;

  /// Debounced provider update — avoids rebuilding the entire widget tree
  /// on every keystroke. The TextEditingController holds the current value
  /// so the UI stays responsive while the provider update is delayed.
  void _debouncedProviderUpdate(Entity Function() entityBuilder) {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(entityProvider.notifier).update(entityBuilder());
    });
  }

  /// Flush pending debounced update immediately (e.g. on dispose).
  void _flushPendingUpdate() {
    if (_updateTimer?.isActive ?? false) {
      _updateTimer!.cancel();
      // Re-read current entity and sync from controllers
      final entity = ref.read(entityProvider)[widget.entityId];
      if (entity == null) return;
      ref.read(entityProvider.notifier).update(entity.copyWith(
        name: _nameController.text,
        description: _descController.text,
        source: _sourceController.text,
        dmNotes: _dmNotesController.text,
        tags: _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      ));
    }
  }

  @override
  void dispose() {
    _flushPendingUpdate();
    _updateTimer?.cancel();
    _nameController.dispose();
    _descController.dispose();
    _sourceController.dispose();
    _tagsController.dispose();
    _dmNotesController.dispose();
    _nameFocus.dispose();
    _descFocus.dispose();
    _sourceFocus.dispose();
    _tagsFocus.dispose();
    _dmNotesFocus.dispose();
    super.dispose();
  }

  /// Sync controller text only when the field is not focused (to avoid
  /// overwriting user input mid-keystroke).
  void _syncIfNotFocused(TextEditingController ctrl, FocusNode focus, String newValue) {
    if (!focus.hasFocus && ctrl.text != newValue) {
      ctrl.text = newValue;
    }
  }

  void _updateField(String fieldKey, dynamic value) {
    _debouncedProviderUpdate(() {
      final entity = ref.read(entityProvider)[widget.entityId];
      if (entity == null) return entity!; // won't happen — guarded by caller
      final newFields = Map<String, dynamic>.from(entity.fields);
      newFields[fieldKey] = value;
      return entity.copyWith(fields: newFields);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch only this specific entity — not the entire map
    final entity = ref.watch(
      entityProvider.select((map) => map[widget.entityId]),
    );
    if (entity == null) {
      return const Center(child: Text('Entity not found'));
    }

    final palette = Theme.of(context).extension<DmToolColors>()!;
    final cat = widget.categorySchema;

    // Rule engine v2 — reaktif computed değerleri (ilişkili entity + schema değişikliklerini izler)
    final ruleResult = ref.watch(computedFieldsProvider(widget.entityId));
    final computedValues = ruleResult.computedValues;

    // Controller sync — only update when the field is not focused
    _syncIfNotFocused(_nameController, _nameFocus, entity.name);
    _syncIfNotFocused(_descController, _descFocus, entity.description);
    _syncIfNotFocused(_dmNotesController, _dmNotesFocus, entity.dmNotes);
    _syncIfNotFocused(_sourceController, _sourceFocus, entity.source);
    final tagsStr = entity.tags.join(', ');
    _syncIfNotFocused(_tagsController, _tagsFocus, tagsStr);

    final subtitle = cat != null ? _buildSubtitle(entity, cat) : '';
    final hasPortrait = entity.imagePath.isNotEmpty || entity.images.isNotEmpty;

    return Container(
      color: palette.srdParchment,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === TITLE ROW: name (serif red) + project button ===
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: widget.readOnly
                      ? Text(
                          entity.name.isEmpty ? '(Unnamed)' : entity.name,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: palette.srdHeadingRed,
                            height: 1.1,
                          ),
                        )
                      : TextFormField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: palette.srdHeadingRed,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Entity Name',
                            border: InputBorder.none,
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) => _debouncedProviderUpdate(
                            () => ref.read(entityProvider)[widget.entityId]!.copyWith(name: v),
                          ),
                        ),
                ),
                IconButton(
                  tooltip: 'Project entity card to player screen',
                  icon: Icon(Icons.cast, size: 18, color: palette.srdHeadingRed),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    ref
                        .read(projectionControllerProvider.notifier)
                        .addEntityCard(entityId: widget.entityId);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          duration: Duration(seconds: 2),
                          content: Text('Entity card projected to player screen'),
                        ),
                      );
                  },
                ),
              ],
            ),
            // Subtitle (italic muted) — e.g. "Level 2 Evocation (Wizard)"
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: palette.srdSubtitle,
                ),
              ),
            ],
            const SizedBox(height: 6),
            // Red rule under title
            Container(height: 1, color: palette.srdRule),
            const SizedBox(height: 12),

            // === BODY: portrait (right, small) + description (left, expanded) ===
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownTextArea(
                        controller: _descController,
                        focusNode: _descFocus,
                        readOnly: widget.readOnly,
                        minLines: widget.readOnly ? null : 3,
                        textStyle: TextStyle(fontSize: 14, color: palette.srdInk, height: 1.4),
                        decoration: InputDecoration(
                          hintText: 'Markdown supported... (@ to mention)',
                          border: InputBorder.none,
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: TextStyle(color: palette.sidebarLabelSecondary),
                        ),
                        onChanged: (v) => _debouncedProviderUpdate(
                          () => ref.read(entityProvider)[widget.entityId]!.copyWith(description: v),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Source + Tags (compact, italic, no bordered fields in read-only)
                      _SourceTagsRow(
                        sourceController: _sourceController,
                        sourceFocus: _sourceFocus,
                        tagsController: _tagsController,
                        tagsFocus: _tagsFocus,
                        readOnly: widget.readOnly,
                        palette: palette,
                        onSourceChanged: (v) => _debouncedProviderUpdate(
                          () => ref.read(entityProvider)[widget.entityId]!.copyWith(source: v),
                        ),
                        onTagsChanged: (v) {
                          final tags = v.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                          _debouncedProviderUpdate(
                            () => ref.read(entityProvider)[widget.entityId]!.copyWith(tags: tags),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (hasPortrait || !widget.readOnly) ...[
                  const SizedBox(width: 16),
                  _PortraitGallery(
                    images: [
                      if (entity.imagePath.isNotEmpty) entity.imagePath,
                      ...entity.images,
                    ],
                    entityName: entity.name,
                    readOnly: widget.readOnly,
                    palette: palette,
                    onImagesChanged: (newImages) {
                      ref.read(entityProvider.notifier).update(
                        entity.copyWith(imagePath: '', images: newImages),
                      );
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // === SCHEMA-DRIVEN FIELDS ===
            if (cat != null) ..._buildSchemaFields(entity, cat, palette, computedValues, ruleResult.itemStyles, ruleResult.equipGates),

            const SizedBox(height: 8),

            // === DM NOTES — heading + rule, no boxed border ===
            _SectionHeading(title: 'DM Notes', palette: palette, leadingIcon: Icons.lock),
            const SizedBox(height: 6),
            MarkdownTextArea(
              controller: _dmNotesController,
              focusNode: _dmNotesFocus,
              readOnly: widget.readOnly,
              maxLines: widget.readOnly ? null : 4,
              textStyle: TextStyle(fontSize: 13, color: palette.srdInk, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Private DM notes... (@ to mention)',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                hintStyle: TextStyle(color: palette.sidebarLabelSecondary),
              ),
              onChanged: (v) => _debouncedProviderUpdate(
                () => ref.read(entityProvider)[widget.entityId]!.copyWith(dmNotes: v),
              ),
            ),

            // === DELETE BUTTON ===
            if (!widget.readOnly) ...[
              const SizedBox(height: 24),
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
      ),
    );
  }

  /// Build the SRD-style italic subtitle line for known categories.
  /// e.g. spell → "Level 2 Evocation (Wizard)", monster → "Large Aberration, Lawful Evil",
  /// magic item → "Wondrous Item, Rare (Requires Attunement)".
  String _buildSubtitle(Entity entity, EntityCategorySchema cat) {
    final f = entity.fields;
    final slug = entity.categorySlug.toLowerCase();
    String relName(String key) {
      final id = f[key];
      if (id is! String || id.isEmpty) return '';
      final ent = ref.read(entityProvider)[id];
      return ent?.name ?? '';
    }
    List<String> relNames(String key) {
      final v = f[key];
      if (v is! List) return const [];
      final entities = ref.read(entityProvider);
      return v
          .whereType<String>()
          .map((id) => entities[id]?.name ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    if (slug == 'spells' || slug == 'spell') {
      final level = f['level'];
      final school = relName('school_ref');
      final classes = relNames('class_refs');
      final ritual = f['is_ritual'] == true;
      final lvlText = level == 0 ? 'Cantrip' : 'Level ${level ?? '?'}';
      final base = school.isEmpty ? lvlText : '$lvlText $school';
      final cls = classes.isEmpty ? '' : ' (${classes.join(', ')})';
      return '$base$cls${ritual ? ' (Ritual)' : ''}';
    }
    if (slug == 'monsters' || slug == 'monster' || slug == 'npcs' || slug == 'npc') {
      final size = relName('size_ref');
      final type = relName('creature_type_ref');
      final align = relName('alignment_ref');
      final parts = <String>[];
      if (size.isNotEmpty || type.isNotEmpty) {
        parts.add([size, type].where((s) => s.isNotEmpty).join(' '));
      }
      if (align.isNotEmpty) parts.add(align);
      return parts.join(', ');
    }
    if (slug == 'items' || slug == 'magic_items' || slug == 'magic_item' || slug == 'item') {
      final magicCat = relName('magic_category_ref');
      final rarity = relName('rarity_ref');
      final attune = f['requires_attunement'] == true;
      final parts = [magicCat, rarity].where((s) => s.isNotEmpty).join(', ');
      return '$parts${attune ? ' (Requires Attunement)' : ''}';
    }
    if (slug == 'feats' || slug == 'feat') {
      final fcat = relName('category_ref');
      final repeatable = f['repeatable'] == true;
      return repeatable ? '$fcat Feat (Repeatable)' : '$fcat Feat';
    }
    return cat.name;
  }

  Widget _buildFieldWidget(FieldSchema field, Entity entity, Map<String, dynamic> computed, DmToolColors palette, {Map<String, ItemStyle> itemStyles = const {}, Map<String, String> equipGates = const {}, bool compact = false}) {
    final hasComputed = computed.containsKey(field.fieldKey);
    final fieldValue = hasComputed ? computed[field.fieldKey] : entity.fields[field.fieldKey];
    final formula = hasComputed && !widget.readOnly ? _formulaFor(field.fieldKey) : null;

    // Inline relation lists in multi-column groups — keep equip-tracked lists
    // (inventory/spells/etc.) in their full Card form regardless of compact.
    final useCompact = compact && field.isList && field.fieldType == FieldType.relation && !field.hasEquip;

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
          itemStyles: itemStyles,
          equipGates: equipGates,
          entityFields: entity.fields,
          compact: useCompact,
        ),
        if (hasComputed)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high, size: 12, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    formula != null ? '= $formula' : 'Auto-filled by rule',
                    style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary, fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Bu entity'nin kategorisinde, [fieldKey] hedefli bir setValue kuralı
  /// varsa, ValueExpression'ı stringify ederek formül string'i döner.
  String? _formulaFor(String fieldKey) {
    final cat = widget.categorySchema;
    if (cat == null) return null;
    for (final rule in cat.rules) {
      if (!rule.enabled) continue;
      final match = rule.then_.maybeWhen(
        setValue: (target, value) => target == fieldKey ? value : null,
        orElse: () => null,
      );
      if (match != null) return RuleEngineV2.stringify(match);
    }
    return null;
  }

  Widget _buildGroupGrid(List<FieldSchema> fields, int gridColumns, Entity entity, Map<String, dynamic> computed, DmToolColors palette, {Map<String, ItemStyle> itemStyles = const {}, Map<String, String> equipGates = const {}}) {
    final compactRow = gridColumns > 1;

    if (gridColumns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.map((f) => _buildFieldWidget(f, entity, computed, palette, itemStyles: itemStyles, equipGates: equipGates)).toList(),
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
        final children = <Widget>[];
        for (var i = 0; i < rowFields.length; i++) {
          if (i > 0) children.add(const SizedBox(width: 8));
          final span = rowFields[i].gridColumnSpan.clamp(1, gridColumns);
          children.add(Expanded(
            flex: span,
            child: _buildFieldWidget(rowFields[i], entity, computed, palette, itemStyles: itemStyles, equipGates: equipGates, compact: compactRow),
          ));
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      }).toList(),
    );
  }

  List<Widget> _buildSchemaFields(Entity entity, EntityCategorySchema cat, DmToolColors palette, Map<String, dynamic> computed, Map<String, ItemStyle> itemStyles, Map<String, String> equipGates) {
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

    // Ungrouped fields — render under "Properties" heading, no boxed chrome.
    if (ungrouped.isNotEmpty) {
      widgets.add(_SectionHeading(title: 'Properties', palette: palette));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ungrouped
            .map((f) => _buildFieldWidget(f, entity, computed, palette, itemStyles: itemStyles, equipGates: equipGates))
            .toList(),
      ));
    }

    // Grouped fields — collapsible, no boxed chrome, optional centered.
    for (final group in sortedGroups) {
      final groupFields = grouped[group.groupId];
      if (groupFields == null || groupFields.isEmpty) continue;

      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));

      final centered = _shouldCenterGroup(group.name);

      widgets.add(_CollapsibleGroupCard(
        group: group,
        palette: palette,
        centered: centered,
        child: _buildGroupGrid(groupFields, group.gridColumns, entity, computed, palette, itemStyles: itemStyles, equipGates: equipGates),
      ));
    }

    return widgets;
  }

  /// Group-name match for SRD-style centered stat blocks.
  bool _shouldCenterGroup(String name) {
    final n = name.toLowerCase();
    return n == 'stats' ||
        n == 'ability scores' ||
        n == 'combat' ||
        n == 'combat stats' ||
        n == 'saves' ||
        n == 'saving throws';
  }
}

/// Section heading: serif red title + 1px red rule. SRD source-book pattern.
class _SectionHeading extends StatelessWidget {
  final String title;
  final DmToolColors palette;
  final IconData? leadingIcon;

  const _SectionHeading({
    required this.title,
    required this.palette,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 14, color: palette.srdHeadingRed),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.srdHeadingRed,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(height: 1, color: palette.srdRule),
      ],
    );
  }
}

/// Source + Tags row — italic small text in read mode, plain text fields in edit mode.
class _SourceTagsRow extends StatelessWidget {
  final TextEditingController sourceController;
  final FocusNode sourceFocus;
  final TextEditingController tagsController;
  final FocusNode tagsFocus;
  final bool readOnly;
  final DmToolColors palette;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTagsChanged;

  const _SourceTagsRow({
    required this.sourceController,
    required this.sourceFocus,
    required this.tagsController,
    required this.tagsFocus,
    required this.readOnly,
    required this.palette,
    required this.onSourceChanged,
    required this.onTagsChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      final src = sourceController.text;
      final tags = tagsController.text;
      if (src.isEmpty && tags.isEmpty) return const SizedBox.shrink();
      final parts = <String>[
        if (src.isNotEmpty) 'Source: $src',
        if (tags.isNotEmpty) 'Tags: $tags',
      ];
      return Text(
        parts.join('   •   '),
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: palette.srdSubtitle,
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: sourceController,
            focusNode: sourceFocus,
            style: TextStyle(fontSize: 12, color: palette.srdInk),
            decoration: const InputDecoration(
              labelText: 'Source',
              hintText: 'e.g. D&D 5e SRD',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: onSourceChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: tagsController,
            focusNode: tagsFocus,
            style: TextStyle(fontSize: 12, color: palette.srdInk),
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'comma separated',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: onTagsChanged,
          ),
        ),
      ],
    );
  }
}

/// Portre resim galerisi — 200x260 sabit, hover'da sol/sağ nav, edit modda üstte ekle / altta sil.
class _PortraitGallery extends ConsumerStatefulWidget {
  final List<String> images;
  final String entityName;
  final bool readOnly;
  final DmToolColors palette;
  final ValueChanged<List<String>> onImagesChanged;

  const _PortraitGallery({
    required this.images,
    required this.entityName,
    required this.readOnly,
    required this.palette,
    required this.onImagesChanged,
  });

  @override
  ConsumerState<_PortraitGallery> createState() => _PortraitGalleryState();
}

class _PortraitGalleryState extends ConsumerState<_PortraitGallery> {
  int _currentIndex = 0;
  bool _hovered = false;

  bool get _showControls => _hovered || Platform.isAndroid || Platform.isIOS;

  Future<void> _pickImage() async {
    final mediaDir = ref.read(mediaDirectoryProvider);
    final campaignId = ref.read(mediaCampaignIdProvider);
    if (mediaDir.isNotEmpty) {
      final selected = await MediaGalleryDialog.show(
        context,
        mediaDir: mediaDir,
        campaignId: campaignId,
        allowMultiple: true,
      );
      if (selected == null || selected.isEmpty) return;
      widget.onImagesChanged([...widget.images, ...selected]);
      return;
    }
    // Fallback: doğrudan dosya seçici
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Sağ tık → player screen'e project menüsü.
        // GestureDetector dış Container'da çünkü iç Stack'teki overlay'ler
        // pointer event'leri tutuyor.
        onSecondaryTapDown: widget.images.isEmpty
            ? null
            : (details) {
                context.showProjectionMenu(
                  ref: ref,
                  globalPosition: details.globalPosition,
                  itemBuilder: () => ProjectionItemBuilders.image(
                    label: widget.entityName.isEmpty
                        ? 'Image'
                        : widget.entityName,
                    filePaths: [widget.images[_currentIndex]],
                  ),
                );
              },
        // Long-press → projection menüsü (mobile, sağ tık yerine)
        onLongPressStart: widget.images.isEmpty
            ? null
            : (details) {
                context.showProjectionMenu(
                  ref: ref,
                  globalPosition: details.globalPosition,
                  itemBuilder: () => ProjectionItemBuilders.image(
                    label: widget.entityName.isEmpty
                        ? 'Image'
                        : widget.entityName,
                    filePaths: [widget.images[_currentIndex]],
                  ),
                );
              },
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

            // Hover: hafif overlay (desktop only)
            if (_hovered && !(Platform.isAndroid || Platform.isIOS) && widget.images.isNotEmpty)
              Container(color: Colors.black.withValues(alpha: 0.08)),

            // Nav: Sol ok
            if (_showControls && widget.images.length > 1 && _currentIndex > 0)
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
            if (_showControls && widget.images.length > 1 && _currentIndex < widget.images.length - 1)
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
            if (!widget.readOnly && _showControls)
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
            if (!widget.readOnly && _showControls && widget.images.isNotEmpty)
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
      ),
    );
  }

  Widget _buildImage(String path) {
    // Entity.images[] may hold either a legacy absolute path or a
    // `dmt-asset://` cloud URI — both flow through AssetRefImage.
    return AssetRefImage(
      ref: AssetRef(path),
      width: 200,
      height: 260,
      fit: BoxFit.cover,
      cacheWidth: 400,
      placeholder: _buildPlaceholder(),
      errorWidget: _buildPlaceholder(),
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

/// Collapsible group — SRD heading + red rule, no boxed chrome. Optional centered content.
class _CollapsibleGroupCard extends StatefulWidget {
  final FieldGroup group;
  final DmToolColors palette;
  final Widget child;
  final bool centered;

  const _CollapsibleGroupCard({
    required this.group,
    required this.palette,
    required this.child,
    this.centered = false,
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
    final hasName = widget.group.name.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasName)
          InkWell(
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _collapsed ? Icons.chevron_right : Icons.expand_more,
                        size: 16,
                        color: widget.palette.srdHeadingRed,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.group.name,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.palette.srdHeadingRed,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(height: 1, color: widget.palette.srdRule),
                ],
              ),
            ),
          ),
        if (!_collapsed)
          Padding(
            padding: EdgeInsets.symmetric(vertical: hasName ? 8 : 0),
            child: widget.centered ? Center(child: widget.child) : widget.child,
          ),
      ],
    );
  }
}
