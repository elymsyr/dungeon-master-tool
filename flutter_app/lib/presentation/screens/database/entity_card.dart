import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/media_provider.dart';
import '../../../application/providers/projection_provider.dart';
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

/// Module-level cache: sorted/filtered field schema lists per category.
/// Key: identity of EntityCategorySchema. Cleared automatically when category
/// instance is replaced (template reload, schema edit) since the new instance
/// never matches an old key. Avoids re-sorting N fields on every build.
class _SchemaFieldCache {
  final List<FieldSchema> visibleSorted;
  final List<FieldSchema> ungrouped;
  final Map<String, List<FieldSchema>> grouped;
  final List<FieldGroup> sortedGroups;
  _SchemaFieldCache({
    required this.visibleSorted,
    required this.ungrouped,
    required this.grouped,
    required this.sortedGroups,
  });
}

final Expando<_SchemaFieldCache> _schemaCache = Expando();

/// Module cache for the row-split layout of grouped multi-column fields.
/// Key: identity of the field-list (stable from _SchemaFieldCache).
final Expando<List<List<FieldSchema>>> _gridRowsCache = Expando();

List<List<FieldSchema>> _splitRows(List<FieldSchema> fields, int gridColumns,
    {bool useCache = true}) {
  if (useCache) {
    final cached = _gridRowsCache[fields];
    if (cached != null) return cached;
  }
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
  if (useCache) _gridRowsCache[fields] = rows;
  return rows;
}

/// Read-only visibility test — empty fields are skipped so cards render
/// only the data the entity actually has. Edit mode shows everything so
/// users can fill blanks in.
bool _isFieldVisibleInReadOnly(FieldSchema f, dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return true;
  if (v is String) return v.isNotEmpty;
  if (v is List) return v.isNotEmpty;
  if (v is Map) {
    if (v.isEmpty) return false;
    if (v.containsKey('count')) {
      final c = v['count'];
      return c is num && c > 0;
    }
    if (v.containsKey('rows')) {
      final r = v['rows'];
      return r is List && r.isNotEmpty;
    }
    return v.values.any((vv) {
      if (vv == null) return false;
      if (vv is String) return vv.isNotEmpty;
      if (vv is List) return vv.isNotEmpty;
      if (vv is Map) return vv.isNotEmpty;
      if (vv is bool) return vv;
      return true;
    });
  }
  return true;
}

_SchemaFieldCache _getSchemaCache(EntityCategorySchema cat) {
  final cached = _schemaCache[cat];
  if (cached != null) return cached;
  final visible = cat.fields
      .where((f) => f.visibility != FieldVisibility.private_)
      .toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  final ungrouped = visible.where((f) => f.groupId == null).toList();
  final grouped = <String, List<FieldSchema>>{};
  for (final f in visible) {
    if (f.groupId != null) {
      (grouped[f.groupId!] ??= []).add(f);
    }
  }
  final sortedGroups = cat.fieldGroups.toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  final result = _SchemaFieldCache(
    visibleSorted: visible,
    ungrouped: ungrouped,
    grouped: grouped,
    sortedGroups: sortedGroups,
  );
  _schemaCache[cat] = result;
  return result;
}

/// Schema-driven entity card — Python ui/widgets/npc_sheet.py karşılığı.
/// Sol kenarlık kategori renginde, tüm alanlar tema-uyumlu.
class EntityCard extends ConsumerStatefulWidget {
  final String entityId;
  final EntityCategorySchema? categorySchema;
  final bool readOnly;
  /// Hint passed down to relation widgets so a tap on a referenced entity
  /// opens it in the OPPOSITE panel rather than replacing the current
  /// card. Null = no hint, navigation goes to the default panel.
  final String? panelId;

  const EntityCard({
    required this.entityId,
    this.categorySchema,
    this.readOnly = true,
    this.panelId,
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

  /// Cached scoped theme — invalidated only when palette flag flips.
  ThemeData? _cachedCardTheme;
  ThemeData? _cachedBaseTheme;
  bool? _cachedBorderlessFlag;

  /// Subtitle memo — invalidated when entity reference changes.
  /// Entity is immutable (Freezed) ⇒ identity check suffices for staleness.
  Entity? _subtitleEntity;
  EntityCategorySchema? _subtitleCat;
  String? _cachedSubtitle;

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
    // Re-resolve category from the live entity.categorySlug so a sync that
    // rewrites an entity's slug (e.g., package re-install with a renamed
    // category) doesn't strand the open card with a stale schema lookup
    // and render an empty body.
    final widgetCat = widget.categorySchema;
    final cat = widgetCat != null && widgetCat.slug == entity.categorySlug
        ? widgetCat
        : ref
            .read(worldSchemaProvider)
            .categories
            .where((c) => c.slug == entity.categorySlug)
            .firstOrNull;

    // Controller sync — only update when the field is not focused
    _syncIfNotFocused(_nameController, _nameFocus, entity.name);
    _syncIfNotFocused(_descController, _descFocus, entity.description);
    _syncIfNotFocused(_dmNotesController, _dmNotesFocus, entity.dmNotes);
    _syncIfNotFocused(_sourceController, _sourceFocus, entity.source);
    final tagsStr = entity.tags.join(', ');
    _syncIfNotFocused(_tagsController, _tagsFocus, tagsStr);

    final String subtitle;
    if (cat == null) {
      subtitle = '';
    } else if (identical(_subtitleEntity, entity) &&
        identical(_subtitleCat, cat) &&
        _cachedSubtitle != null) {
      subtitle = _cachedSubtitle!;
    } else {
      subtitle = _buildSubtitle(entity, cat);
      _subtitleEntity = entity;
      _subtitleCat = cat;
      _cachedSubtitle = subtitle;
    }
    final hasPortrait = entity.imagePath.isNotEmpty || entity.images.isNotEmpty;

    final baseTheme = Theme.of(context);
    if (!identical(_cachedBaseTheme, baseTheme) ||
        _cachedBorderlessFlag != palette.cardBorderlessInputs) {
      _cachedBaseTheme = baseTheme;
      _cachedBorderlessFlag = palette.cardBorderlessInputs;
      _cachedCardTheme = palette.cardBorderlessInputs
          ? baseTheme.copyWith(
              inputDecorationTheme:
                  baseTheme.inputDecorationTheme.copyWith(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 6),
              ),
            )
          : baseTheme;
    }
    final cardTheme = _cachedCardTheme!;

    final children = <Widget>[
      // === HEADER: portrait (top-left) | name + subtitle + desc + source/tags (right) ===
      Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPortrait || !widget.readOnly) ...[
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
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + project button row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: widget.readOnly
                                ? Text(
                                    entity.name.isEmpty ? '(Unnamed)' : entity.name,
                                    style: TextStyle(
                                      fontFamily: palette.useSerif ? 'Georgia' : null,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: palette.srdHeadingRed,
                                      height: 1.1,
                                      letterSpacing: palette.cardHeadingUppercase ? 1.2 : 0,
                                    ),
                                  )
                                : TextFormField(
                                    controller: _nameController,
                                    focusNode: _nameFocus,
                                    style: TextStyle(
                                      fontFamily: palette.useSerif ? 'Georgia' : null,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: palette.srdHeadingRed,
                                      letterSpacing: palette.cardHeadingUppercase ? 1.2 : 0,
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
                            fontFamily: palette.useSerif ? 'Georgia' : null,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: palette.srdSubtitle,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      if (palette.cardShowRule)
                        Container(height: 1, color: palette.srdRule),
                      const SizedBox(height: 10),
                      // Description (bigger ink)
                      MarkdownTextArea(
                        controller: _descController,
                        focusNode: _descFocus,
                        readOnly: widget.readOnly,
                        minLines: widget.readOnly ? null : 3,
                        textStyle: TextStyle(fontSize: 16, color: palette.srdInk, height: 1.45),
                        decoration: InputDecoration(
                          hintText: 'Markdown supported... (@ to mention)',
                          border: InputBorder.none,
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: TextStyle(color: palette.srdSubtitle, fontStyle: FontStyle.italic),
                        ),
                        onChanged: (v) => _debouncedProviderUpdate(
                          () => ref.read(entityProvider)[widget.entityId]!.copyWith(description: v),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Source + Tags (link icon prefix when entity is
                      // linked to a package)
                      _SourceTagsRow(
                        sourceController: _sourceController,
                        sourceFocus: _sourceFocus,
                        tagsController: _tagsController,
                        tagsFocus: _tagsFocus,
                        readOnly: widget.readOnly,
                        palette: palette,
                        linked: entity.linked,
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
              ],
            ),

            const SizedBox(height: 16),

            // === SCHEMA-DRIVEN FIELDS ===
            if (cat != null) ..._buildSchemaFields(entity, cat, palette),

            const SizedBox(height: 8),

            // === DM NOTES — heading + rule, no boxed border ===
            EntityCardSectionHeading(title: 'DM Notes', palette: palette, leadingIcon: Icons.lock),
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
    ];

    return Theme(
      data: cardTheme,
      child: Container(
        color: palette.srdParchment,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
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
      final align = (f['alignment_ref'] as String?) ?? '';
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
      final fcat = (f['category_ref'] as String?) ?? '';
      final repeatable = f['repeatable'] == true;
      return repeatable ? '$fcat Feat (Repeatable)' : '$fcat Feat';
    }
    return cat.name;
  }

  Widget _buildFieldWidget(FieldSchema field, Entity entity, DmToolColors palette, {bool compact = false}) {
    final fieldValue = entity.fields[field.fieldKey];

    // Inline relation lists in multi-column groups — keep equip-tracked lists
    // (inventory/spells/etc.) in their full Card form regardless of compact.
    final useCompact = compact && field.isList && field.fieldType == FieldType.relation && !field.hasEquip;

    return FieldWidgetFactory.create(
      schema: field,
      value: fieldValue,
      readOnly: widget.readOnly,
      onChanged: (v) => _updateField(field.fieldKey, v),
      entities: ref.read(entityProvider),
      ref: ref,
      entityFields: entity.fields,
      compact: useCompact,
      panelId: widget.panelId,
    );
  }

  Widget _buildGroupGrid(List<FieldSchema> fields, int gridColumns, Entity entity, DmToolColors palette, {bool cached = true}) {
    final compactRow = gridColumns > 1;

    if (gridColumns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.map((f) => _buildFieldWidget(f, entity, palette)).toList(),
      );
    }

    // Satır satır böl — her satırdaki field'lar IntrinsicHeight ile eşit yükseklikte.
    // Cached path uses the stable list identity from _SchemaFieldCache.
    // Filtered (read-only) path skips cache since the list is rebuilt per build.
    final rows = _splitRows(fields, gridColumns, useCache: cached);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((rowFields) {
        final children = <Widget>[];
        var totalSpan = 0;
        for (var i = 0; i < rowFields.length; i++) {
          if (i > 0) children.add(const SizedBox(width: 8));
          final span = rowFields[i].gridColumnSpan.clamp(1, gridColumns);
          totalSpan += span;
          children.add(Expanded(
            flex: span,
            child: _buildFieldWidget(rowFields[i], entity, palette, compact: compactRow),
          ));
        }
        // Pad short rows with a flex spacer so a partially-filled row keeps
        // each cell at the column width it would occupy if the row were full.
        // Without this, an Expanded(flex: 1) in a 2-col row stretches across
        // the whole width and breaks vertical alignment with neighbouring rows.
        if (totalSpan < gridColumns) {
          children.add(const SizedBox(width: 8));
          children.add(Expanded(
            flex: gridColumns - totalSpan,
            child: const SizedBox.shrink(),
          ));
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      }).toList(),
    );
  }

  List<Widget> _buildSchemaFields(Entity entity, EntityCategorySchema cat, DmToolColors palette) {
    final cache = _getSchemaCache(cat);
    final readOnly = widget.readOnly;
    final fullUngrouped = cache.ungrouped;
    final grouped = cache.grouped;
    final sortedGroups = cache.sortedGroups;

    List<FieldSchema> filterVisible(List<FieldSchema> fields) {
      if (!readOnly) return fields;
      return fields
          .where((f) => _isFieldVisibleInReadOnly(f, entity.fields[f.fieldKey]))
          .toList();
    }

    final ungrouped = filterVisible(fullUngrouped);
    final widgets = <Widget>[];

    // Ungrouped fields — render under "Properties" heading, no boxed chrome.
    if (ungrouped.isNotEmpty) {
      widgets.add(EntityCardSectionHeading(title: 'Properties', palette: palette));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ungrouped
            .map((f) => _buildFieldWidget(f, entity, palette))
            .toList(),
      ));
    }

    // Grouped fields — collapsible, no boxed chrome, optional centered.
    for (final group in sortedGroups) {
      final fullGroupFields = grouped[group.groupId];
      if (fullGroupFields == null || fullGroupFields.isEmpty) continue;
      final groupFields = filterVisible(fullGroupFields);
      if (groupFields.isEmpty) continue;

      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));

      final centered = _shouldCenterGroup(group.name);
      // Cache row-split only when rendering the unfiltered list (edit mode).
      final useCache = identical(groupFields, fullGroupFields);

      widgets.add(EntityCardCollapsibleGroupCard(
        group: group,
        palette: palette,
        centered: centered,
        child: _buildGroupGrid(groupFields, group.gridColumns, entity, palette, cached: useCache),
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

/// Section heading: theme-aware title + optional red rule. SRD source-book pattern
/// when palette.cardShowRule, modern flat when not. Uppercase per palette.cardHeadingUppercase.
class EntityCardSectionHeading extends StatelessWidget {
  final String title;
  final DmToolColors palette;
  final IconData? leadingIcon;

  const EntityCardSectionHeading({
    super.key,
    required this.title,
    required this.palette,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final upper = palette.cardHeadingUppercase;
    final display = upper ? title.toUpperCase() : title;
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
                display,
                style: TextStyle(
                  fontFamily: palette.useSerif ? 'Georgia' : null,
                  fontSize: upper ? 13 : 16,
                  fontWeight: FontWeight.w700,
                  color: palette.srdHeadingRed,
                  letterSpacing: upper ? 1.5 : 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (palette.cardShowRule)
          Container(height: 1, color: palette.srdRule)
        else
          const SizedBox(height: 4),
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
  final bool linked;
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
    this.linked = false,
  });

  @override
  Widget build(BuildContext context) {
    final linkBadge = linked
        ? Tooltip(
            message:
                'Linked to package — edits will detach this entity into a homebrew copy.',
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.link, size: 14, color: palette.tabActiveText),
            ),
          )
        : null;

    if (readOnly) {
      final src = sourceController.text;
      final tags = tagsController.text;
      if (src.isEmpty && tags.isEmpty && !linked) return const SizedBox.shrink();
      final parts = <String>[
        if (src.isNotEmpty) 'Source: $src',
        if (tags.isNotEmpty) 'Tags: $tags',
      ];
      final text = Text(
        parts.join('   •   '),
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: palette.srdSubtitle,
        ),
      );
      if (linkBadge == null) return text;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          linkBadge,
          Flexible(child: text),
        ],
      );
    }
    return Row(
      children: [
        ?linkBadge,
        Expanded(
          child: TextFormField(
            controller: sourceController,
            focusNode: sourceFocus,
            style: TextStyle(fontSize: 14, color: palette.srdInk),
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
            style: TextStyle(fontSize: 14, color: palette.srdInk),
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
          Icon(Icons.person_outline, size: 48, color: widget.palette.srdSubtitle.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          Text('No Image', style: TextStyle(fontSize: 10, color: widget.palette.srdSubtitle)),
        ],
      ),
    );
  }
}

/// Collapsible group — SRD heading + red rule, no boxed chrome. Optional centered content.
class EntityCardCollapsibleGroupCard extends StatefulWidget {
  final FieldGroup group;
  final DmToolColors palette;
  final Widget child;
  final bool centered;

  const EntityCardCollapsibleGroupCard({
    super.key,
    required this.group,
    required this.palette,
    required this.child,
    this.centered = false,
  });

  @override
  State<EntityCardCollapsibleGroupCard> createState() => EntityCardCollapsibleGroupCardState();
}

class EntityCardCollapsibleGroupCardState extends State<EntityCardCollapsibleGroupCard> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.group.isCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    final hasName = widget.group.name.isNotEmpty;
    final palette = widget.palette;
    final upper = palette.cardHeadingUppercase;
    final display = upper ? widget.group.name.toUpperCase() : widget.group.name;
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
                        color: palette.srdHeadingRed,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          display,
                          style: TextStyle(
                            fontFamily: palette.useSerif ? 'Georgia' : null,
                            fontSize: upper ? 13 : 16,
                            fontWeight: FontWeight.w700,
                            color: palette.srdHeadingRed,
                            letterSpacing: upper ? 1.5 : 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (palette.cardShowRule)
                    Container(height: 1, color: palette.srdRule)
                  else
                    const SizedBox(height: 4),
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
