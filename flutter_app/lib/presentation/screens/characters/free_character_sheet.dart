import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/services/free_field_styles.dart';
import '../../../domain/services/free_template.dart';
import '../../../domain/services/template_edit.dart'
    show fieldsIn, sortedGroups;
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/field_widgets/field_widget_factory.dart';
import '../database/entity_card.dart'
    show EntityCardCollapsibleGroupCard, splitFieldRows;

/// A free template character's sheet (docs/free-template/DESIGN.md §10.2):
/// the player card's layout, the main level, Short / Long rest. None of
/// the built-in sheet's parts (resolved grants, class resource tracker,
/// derived values) — the built-in editor only routes here (ROADMAP K3).
class FreeCharacterSheet extends ConsumerStatefulWidget {
  const FreeCharacterSheet({
    super.key,
    required this.characterId,
    required this.schema,
    this.onClose,
  });

  final String characterId;

  /// The world's own copy, or the template of a worldless character.
  final WorldSchema schema;

  /// Embedded (sidebar / player tab): back closes through this.
  final VoidCallback? onClose;

  @override
  ConsumerState<FreeCharacterSheet> createState() => _FreeCharacterSheetState();
}

class _FreeCharacterSheetState extends ConsumerState<FreeCharacterSheet> {
  Character? _working;

  /// Local edits not stored yet: an outside change (the encounter writing
  /// HP back) is taken only when there are none.
  bool _pending = false;

  String get _saveKey => 'character:${widget.characterId}';

  void _edit(Character Function(Character) change) {
    final c = _working;
    if (c == null) return;
    setState(() {
      _working = change(c);
      _pending = true;
    });
    final notifier = ref.read(characterListProvider.notifier);
    ref
        .read(pendingWriteBufferProvider)
        .schedule(
          key: _saveKey,
          kind: WriteKind.shortText,
          action: () async {
            final cur = _working;
            if (cur == null) return;
            await notifier.update(cur);
            if (identical(_working, cur)) _pending = false;
          },
        );
  }

  void _setFields(Map<String, dynamic> patch) => _edit(
    (c) => c.copyWith(
      entity: c.entity.copyWith(fields: {...c.entity.fields, ...patch}),
    ),
  );

  void _rest(EntityCategorySchema card, RestKind kind) {
    final patch = restPatch(card.fields, _working!.entity.fields, kind);
    if (patch.isNotEmpty) _setFields(patch);
    final l10n = L10n.of(context)!;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          kind == RestKind.short
              ? l10n.freeShortRestDone
              : l10n.freeLongRestDone,
        ),
      ),
    );
  }

  Future<void> _close() async {
    await ref.read(pendingWriteBufferProvider).flushPrefix(_saveKey);
    if (!mounted) return;
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    ref.listen<Character?>(characterByIdProvider(widget.characterId), (
      _,
      next,
    ) {
      if (next != null && !_pending && mounted) {
        setState(() => _working = next);
      }
    });
    _working ??= ref.read(characterByIdProvider(widget.characterId));
    final character = _working;
    final card = freePlayerCard(widget.schema);
    if (character == null || card == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            character == null ? l10n.charNotFound : l10n.charTemplateNoPlayer,
          ),
        ),
      );
    }
    final level = characterLevelOf(card, character.entity);
    // Card links resolve against the open world's cards.
    final Map<String, Entity> entities =
        character.worldId != null &&
            ref.watch(activeCampaignProvider) == character.worldId
        ? ref.watch(entityProvider)
        : const {};
    final phone = isPhone(context);

    Widget restButton(RestKind kind) {
      final label = kind == RestKind.short
          ? l10n.freeShortRest
          : l10n.freeLongRest;
      final icon = kind == RestKind.short
          ? Icons.local_cafe_outlined
          : Icons.bedtime_outlined;
      void onTap() => _rest(card, kind);
      return phone
          ? IconButton(tooltip: label, icon: Icon(icon), onPressed: onTap)
          : TextButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
            );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 8,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: l10n.btnBack,
                onPressed: _close,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  character.entity.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (level != null) ...[
                const SizedBox(width: 8),
                Text(
                  l10n.freeSheetLevel(level),
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            restButton(RestKind.short),
            restButton(RestKind.long),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            TextFormField(
              key: const ValueKey('free_sheet_name'),
              initialValue: character.entity.name,
              decoration: InputDecoration(labelText: l10n.tplName),
              onChanged: (v) =>
                  _edit((c) => c.copyWith(entity: c.entity.copyWith(name: v))),
            ),
            const SizedBox(height: 12),
            ..._fields(fieldsIn(card, null), 1, card, character, entities),
            for (final g in sortedGroups(card))
              if (fieldsIn(card, g.groupId).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: EntityCardCollapsibleGroupCard(
                    group: g,
                    palette: palette,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _fields(
                        fieldsIn(card, g.groupId),
                        phone ? 1 : g.gridColumns,
                        card,
                        character,
                        entities,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// [fields] in rows of [cols] columns, each field as wide as its span.
  List<Widget> _fields(
    List<FieldSchema> fields,
    int cols,
    EntityCategorySchema card,
    Character character,
    Map<String, Entity> entities,
  ) {
    Widget tile(FieldSchema f, {bool compact = false}) =>
        FieldWidgetFactory.create(
          schema: f,
          value: freeFieldValue(f, character.entity.fields),
          readOnly: false,
          onChanged: (v) => _setFields({f.fieldKey: v}),
          entities: entities,
          ref: ref,
          entityFields: character.entity.fields,
          entityName: character.entity.name,
          compact:
              compact &&
              f.isList &&
              f.fieldType == FieldType.relation &&
              !f.hasEquip,
          categoryFields: card.fields,
        );
    if (cols <= 1) return [for (final f in fields) tile(f)];
    return [
      for (final row in splitFieldRows(fields, cols, useCache: false))
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, f) in row.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                flex: f.gridColumnSpan.clamp(1, cols),
                child: tile(f, compact: true),
              ),
            ],
            // A short row keeps its cells at full-row widths.
            if (row.fold(0, (n, f) => n + f.gridColumnSpan.clamp(1, cols)) <
                cols)
              Expanded(
                flex:
                    cols -
                    row.fold(0, (n, f) => n + f.gridColumnSpan.clamp(1, cols)),
                child: const SizedBox.shrink(),
              ),
          ],
        ),
    ];
  }
}
