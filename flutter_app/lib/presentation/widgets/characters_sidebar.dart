import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/edit_mode_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/global_tags_provider.dart';
import '../../application/providers/template_provider.dart';
import '../../application/services/tag_moderation.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../screens/database/entity_card.dart';
import '../theme/dm_tool_colors.dart';
import 'field_widgets/field_widget_factory.dart';
import 'marketplace_panel.dart';
import 'markdown_text_area.dart';
import 'metadata_editor_section.dart';
import 'metadata_list_tile.dart';
import 'save_info_section.dart';

/// Right-sidebar character workspace. Two modes:
///   - List view (default): characters in active world, create/edit/delete.
///   - Detail view: opens when a list entry is clicked. Inline character
///     editor mirroring [CharacterEditorScreen]'s look but slimmer to fit
///     the sidebar width.
class CharactersSidebar extends ConsumerStatefulWidget {
  final DmToolColors palette;

  const CharactersSidebar({super.key, required this.palette});

  @override
  ConsumerState<CharactersSidebar> createState() => _CharactersSidebarState();
}

class _CharactersSidebarState extends ConsumerState<CharactersSidebar> {
  String? _selectedId;
  String? _openedId;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    if (_openedId != null) {
      return _SidebarCharacterEditor(
        key: ValueKey('sb_char_${_openedId!}'),
        characterId: _openedId!,
        palette: palette,
        onBack: () => setState(() => _openedId = null),
      );
    }
    return _buildList(palette);
  }

  Widget _buildList(DmToolColors palette) {
    final activeWorld = ref.watch(activeCampaignProvider);
    final charactersAsync = ref.watch(characterListProvider);

    return Column(
      children: [
        // Header
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.tabBg,
            border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
          ),
          child: Row(
            children: [
              Icon(Icons.people, size: 16, color: palette.tabActiveText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeWorld == null
                      ? 'Characters'
                      : 'Characters · $activeWorld',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedId != null) ...[
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 16),
                  tooltip: 'Open character',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _openedId = _selectedId),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: palette.dangerBtnBg),
                  tooltip: 'Remove from world',
                  visualDensity: VisualDensity.compact,
                  onPressed: _deleteSelected,
                ),
              ],
            ],
          ),
        ),

        // Body
        Expanded(
          child: charactersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: $e',
                  style: TextStyle(color: palette.dangerBtnBg),
                ),
              ),
            ),
            data: (all) {
              final scoped = activeWorld == null
                  ? const <Character>[]
                  : (all
                          .where((c) => c.worldName == activeWorld)
                          .toList()
                        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
              if (scoped.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      activeWorld == null
                          ? 'Open a world to see its characters.'
                          : 'No characters in this world yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.sidebarLabelSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: scoped.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final c = scoped[i];
                  final isSelected = c.id == _selectedId;
                  return InkWell(
                    borderRadius: palette.br,
                    onTap: () => setState(() {
                      _selectedId = isSelected ? null : c.id;
                    }),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? palette.featureCardAccent
                                .withValues(alpha: 0.1)
                            : palette.featureCardBg,
                        borderRadius: palette.br,
                        border: Border.all(
                          color: isSelected
                              ? palette.featureCardAccent
                              : palette.featureCardBorder,
                        ),
                      ),
                      child: MetadataListTile(
                        icon: Icons.person,
                        name: c.entity.name,
                        subtitle: c.templateName,
                        description: c.entity.description,
                        tags: c.entity.tags,
                        coverImagePath: c.entity.imagePath,
                        isSelected: isSelected,
                        palette: palette,
                        layout: MetadataTileLayout.leftAvatar,
                        onSettings: () => _showCharacterSettings(c.id, palette),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Footer actions
        Divider(height: 1, color: palette.sidebarDivider),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: activeWorld == null
                  ? null
                  : () => _createCharacter(),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Create Character'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.successBtnBg,
                foregroundColor: palette.successBtnText,
                minimumSize: const Size(0, 38),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _createCharacter() {
    // Wizard auto-prefills the active world; after creation it navigates
    // to the editor screen.
    context.push('/character/new');
  }

  Future<void> _deleteSelected() async {
    final id = _selectedId;
    if (id == null) return;
    final list = ref.read(characterListProvider).valueOrNull ?? const [];
    final c = list.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    final palette = widget.palette;
    final worldName = c.worldName;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from World'),
        content: Text(
            'Remove "${c.entity.name}" from "$worldName"? '
            'The character itself is kept and can be reattached to a world later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(characterListProvider.notifier)
                  .update(c.copyWith(worldName: ''));
              if (mounted) setState(() => _selectedId = null);
            },
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCharacterSettings(
      String characterId, DmToolColors palette) async {
    final list = ref.read(characterListProvider).valueOrNull ?? const [];
    final c = list.where((x) => x.id == characterId).firstOrNull;
    if (c == null) return;

    DateTime? updatedAt;
    try {
      updatedAt = DateTime.parse(c.updatedAt);
    } catch (_) {}

    var workingName = c.entity.name;
    var workingDescription = c.entity.description;
    var workingTags = [...c.entity.tags];
    var workingCover = c.entity.imagePath;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${c.entity.name} — Settings'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetadataEditorSection(
                    name: workingName,
                    description: workingDescription,
                    tags: workingTags,
                    coverImagePath: workingCover,
                    onNameChanged: (v) => workingName = v,
                    onDescriptionChanged: (v) => workingDescription = v,
                    onTagsChanged: (v) =>
                        setDialogState(() => workingTags = v),
                    onCoverChanged: (v) =>
                        setDialogState(() => workingCover = v),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: palette.featureCardBorder),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.description,
                          size: 16, color: palette.sidebarLabelSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Template: ${c.templateName}',
                            style: TextStyle(
                                fontSize: 13,
                                color: palette.tabActiveText)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.public,
                          size: 16, color: palette.sidebarLabelSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.worldName.isEmpty
                              ? L10n.of(context)!.charWorldOrphan
                              : 'World: ${c.worldName}',
                          style: TextStyle(
                              fontSize: 13,
                              color: palette.tabActiveText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (updatedAt != null)
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16,
                            color: palette.sidebarLabelSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Last edited: ${updatedAt.toLocal().toString().split('.').first}',
                          style: TextStyle(
                              fontSize: 12, color: palette.tabActiveText),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  SaveInfoSection(
                    itemName: c.entity.name,
                    itemId: c.id,
                    type: 'character',
                    localUpdatedAt: updatedAt,
                  ),
                  const SizedBox(height: 12),
                  MarketplacePanel(
                    itemType: 'character',
                    localId: c.id,
                    title: c.entity.name,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(characterListProvider.notifier).updateMetadata(
                      id: c.id,
                      name: workingName,
                      description: workingDescription,
                      tags: workingTags,
                      coverImagePath: workingCover,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Inline editor — slim variant of CharacterEditorScreen body. Renders
// inside the right-sidebar so users can edit characters without leaving
// the world view. Mirrors look (parchment, big serif red name, schema
// fields, DM Notes) and supports view/edit toggle.

class _SidebarCharacterEditor extends ConsumerStatefulWidget {
  final String characterId;
  final DmToolColors palette;
  final VoidCallback onBack;

  const _SidebarCharacterEditor({
    super.key,
    required this.characterId,
    required this.palette,
    required this.onBack,
  });

  @override
  ConsumerState<_SidebarCharacterEditor> createState() =>
      _SidebarCharacterEditorState();
}

class _SidebarCharacterEditorState
    extends ConsumerState<_SidebarCharacterEditor> {
  Character? _working;
  Timer? _autoSaveTimer;
  bool _saving = false;

  /// Read-only when global edit mode is off. Mirrors database/mind-map
  /// view/edit toggle. Read via getter so any rebuild picks up provider
  /// changes automatically.
  bool get _readOnly => !ref.watch(editModeProvider);

  final TextEditingController _descController = TextEditingController();
  final FocusNode _descFocus = FocusNode();
  final TextEditingController _dmNotesController = TextEditingController();
  final FocusNode _dmNotesFocus = FocusNode();
  bool _controllersPrimed = false;

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _descController.dispose();
    _descFocus.dispose();
    _dmNotesController.dispose();
    _dmNotesFocus.dispose();
    super.dispose();
  }

  void _primeControllers(Character c) {
    if (_controllersPrimed) return;
    _descController.text = c.entity.description;
    _dmNotesController.text = c.entity.dmNotes;
    _controllersPrimed = true;
  }

  void _syncIfNotFocused(
      TextEditingController ctrl, FocusNode focus, String value) {
    if (!focus.hasFocus && ctrl.text != value) ctrl.text = value;
  }

  void _mutate(Character next) {
    setState(() => _working = next);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _save();
    });
  }

  Future<void> _save() async {
    final w = _working;
    if (w == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(characterListProvider.notifier).update(w);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _flushAndBack() async {
    _autoSaveTimer?.cancel();
    await _save();
    if (mounted) widget.onBack();
  }

  Future<void> _pickPortrait() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null) return;
    final c = _working;
    if (c == null) return;
    _mutate(c.copyWith(entity: c.entity.copyWith(imagePath: path)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final character =
        _working ?? ref.watch(characterByIdProvider(widget.characterId));

    if (character == null) {
      return _shell(palette, 'Character',
          const Center(child: Text('Character not found.')));
    }
    _working ??= character;

    final templatesAsync = ref.watch(allTemplatesProvider);
    return templatesAsync.when(
      loading: () => _shell(palette, character.entity.name,
          const Center(child: CircularProgressIndicator())),
      error: (e, _) => _shell(
          palette, character.entity.name, Center(child: Text('Error: $e'))),
      data: (templates) {
        final template = templates
            .where((t) => t.schemaId == character.templateId)
            .firstOrNull;
        if (template == null) {
          return _shell(
            palette,
            character.entity.name,
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Template "${character.templateName}" missing.\n'
                  'Restore it in the Templates tab to edit this character.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.sidebarLabelSecondary),
                ),
              ),
            ),
          );
        }
        final playerCat = findPlayerCategory(template);
        if (playerCat == null) {
          return _shell(
            palette,
            character.entity.name,
            const Center(
              child: Text('Template has no Player category.'),
            ),
          );
        }
        return _shell(
          palette,
          character.entity.name,
          _body(palette, character, playerCat, template),
        );
      },
    );
  }

  Widget _shell(DmToolColors palette, String title, Widget body) {
    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: palette.tabBg,
            border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_saving)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Close character',
                visualDensity: VisualDensity.compact,
                onPressed: _flushAndBack,
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _body(DmToolColors palette, Character character,
      EntityCategorySchema playerCat, WorldSchema template) {
    _primeControllers(character);
    _syncIfNotFocused(
        _descController, _descFocus, character.entity.description);
    _syncIfNotFocused(
        _dmNotesController, _dmNotesFocus, character.entity.dmNotes);

    final baseTheme = Theme.of(context);
    final cardTheme = palette.cardBorderlessInputs
        ? baseTheme.copyWith(
            inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            ),
          )
        : baseTheme;

    return Theme(
      data: cardTheme,
      child: Container(
        color: palette.srdParchment,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _entityHeader(palette, character, template),
              const SizedBox(height: 16),
              ..._renderSchemaFields(palette, playerCat, character),
              const SizedBox(height: 8),
              EntityCardSectionHeading(
                title: 'DM Notes',
                palette: palette,
                leadingIcon: Icons.lock,
              ),
              const SizedBox(height: 6),
              MarkdownTextArea(
                controller: _dmNotesController,
                focusNode: _dmNotesFocus,
                readOnly: _readOnly,
                minLines: _readOnly ? null : 3,
                textStyle: TextStyle(
                    fontSize: 13, color: palette.srdInk, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Private DM notes...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  hintStyle: TextStyle(color: palette.sidebarLabelSecondary),
                ),
                onChanged: (v) {
                  final c = _working;
                  if (c == null) return;
                  _mutate(c.copyWith(entity: c.entity.copyWith(dmNotes: v)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entityHeader(
      DmToolColors palette, Character c, WorldSchema template) {
    final entity = c.entity;
    final hasImage =
        entity.imagePath.isNotEmpty && File(entity.imagePath).existsSync();
    final globalTags = ref.watch(globalTagsProvider);
    final l10n = L10n.of(context)!;
    final subtitle = c.worldName.isEmpty
        ? '${template.name} · ${l10n.charWorldOrphan}'
        : '${template.name} · ${c.worldName}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _readOnly ? null : _pickPortrait,
          child: Container(
            width: 110,
            height: 150,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.featureCardBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.featureCardBorder),
            ),
            child: hasImage
                ? Image.file(File(entity.imagePath), fit: BoxFit.cover)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person,
                          size: 40,
                          color: palette.sidebarLabelSecondary),
                      if (!_readOnly) ...[
                        const SizedBox(height: 4),
                        Text('Add photo',
                            style: TextStyle(
                                fontSize: 10,
                                color: palette.sidebarLabelSecondary)),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_readOnly)
                Text(
                  entity.name.isEmpty ? '(Unnamed)' : entity.name,
                  style: TextStyle(
                    fontFamily: palette.useSerif ? 'Georgia' : null,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: palette.srdHeadingRed,
                    letterSpacing:
                        palette.cardHeadingUppercase ? 1.0 : 0,
                    height: 1.1,
                  ),
                )
              else
                TextFormField(
                  key: ValueKey('sb_hdr_name_${c.id}'),
                  initialValue: entity.name,
                  style: TextStyle(
                    fontFamily: palette.useSerif ? 'Georgia' : null,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: palette.srdHeadingRed,
                    letterSpacing:
                        palette.cardHeadingUppercase ? 1.0 : 0,
                    height: 1.1,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Character Name',
                    border: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    _mutate(c.copyWith(entity: c.entity.copyWith(name: v)));
                  },
                ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: palette.useSerif ? 'Georgia' : null,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: palette.srdSubtitle,
                ),
              ),
              const SizedBox(height: 6),
              if (palette.cardShowRule)
                Container(height: 1, color: palette.srdRule),
              const SizedBox(height: 8),
              MarkdownTextArea(
                controller: _descController,
                focusNode: _descFocus,
                readOnly: _readOnly,
                minLines: _readOnly ? null : 3,
                textStyle: TextStyle(
                    fontSize: 13, color: palette.srdInk, height: 1.35),
                decoration: InputDecoration(
                  hintText: 'Short description...',
                  border: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                      color: palette.srdSubtitle,
                      fontStyle: FontStyle.italic),
                ),
                onChanged: (v) {
                  final cur = _working;
                  if (cur == null) return;
                  _mutate(cur.copyWith(
                      entity: cur.entity.copyWith(description: v)));
                },
              ),
              const SizedBox(height: 8),
              if (_readOnly)
                entity.tags.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        'Tags: ${entity.tags.join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: palette.srdSubtitle,
                        ),
                      )
              else
                _SidebarTagsField(
                  initial: entity.tags.join(', '),
                  globalTags: globalTags,
                  onCommit: (tags) {
                    _mutate(
                        c.copyWith(entity: c.entity.copyWith(tags: tags)));
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _renderSchemaFields(
      DmToolColors palette, EntityCategorySchema cat, Character character) {
    final fieldsByGroup = <String?, List<FieldSchema>>{};
    for (final f in cat.fields) {
      fieldsByGroup.putIfAbsent(f.groupId, () => []).add(f);
    }
    for (final list in fieldsByGroup.values) {
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }
    final groupsInOrder = [...cat.fieldGroups]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final widgets = <Widget>[];
    final ungrouped = fieldsByGroup[null] ?? const <FieldSchema>[];
    if (ungrouped.isNotEmpty) {
      widgets.add(EntityCardSectionHeading(
          title: 'Properties', palette: palette));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ungrouped.map((f) => _fieldTile(f, character)).toList(),
      ));
    }

    for (final g in groupsInOrder) {
      final list = fieldsByGroup[g.groupId] ?? const <FieldSchema>[];
      if (list.isEmpty) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(EntityCardCollapsibleGroupCard(
        group: g,
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: list.map((f) => _fieldTile(f, character)).toList(),
        ),
      ));
    }
    return widgets;
  }

  Widget _fieldTile(FieldSchema f, Character character) {
    final value = character.entity.fields[f.fieldKey];
    final activeCampaign = ref.watch(activeCampaignProvider);
    final entities = activeCampaign == character.worldName
        ? ref.watch(entityProvider)
        : null;
    return FieldWidgetFactory.create(
      schema: f,
      value: value,
      readOnly: _readOnly,
      onChanged: (v) {
        final updatedFields = {
          ...character.entity.fields,
          f.fieldKey: v,
        };
        _mutate(character.copyWith(
          entity: character.entity.copyWith(fields: updatedFields),
        ));
      },
      entities: entities,
      entityFields: character.entity.fields,
      ref: ref,
    );
  }
}

/// Compact tags field for the sidebar editor — comma-separated, with
/// global-tag autocomplete + light moderation.
class _SidebarTagsField extends StatefulWidget {
  final String initial;
  final Set<String> globalTags;
  final ValueChanged<List<String>> onCommit;

  const _SidebarTagsField({
    required this.initial,
    required this.globalTags,
    required this.onCommit,
  });

  @override
  State<_SidebarTagsField> createState() => _SidebarTagsFieldState();
}

class _SidebarTagsFieldState extends State<_SidebarTagsField> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parts = raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    String? err;
    final accepted = <String>[];
    for (final p in parts) {
      final reason = TagModeration.validate(p);
      if (reason != null) {
        err = '"$p": $reason';
        continue;
      }
      if (!accepted.contains(p)) accepted.add(p);
    }
    setState(() => _error = err);
    widget.onCommit(accepted);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        hintText: 'tags, comma, separated',
        errorText: _error,
        isDense: true,
        prefixIcon: const Icon(Icons.tag, size: 14),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 24, minHeight: 24),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      ),
      style: const TextStyle(fontSize: 11),
      onChanged: _commit,
    );
  }
}
