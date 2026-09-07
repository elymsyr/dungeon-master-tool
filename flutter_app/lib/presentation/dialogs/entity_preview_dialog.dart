import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/asset_ref_image.dart';
import '../widgets/expandable_markdown.dart';
import '../widgets/field_widgets/field_widget_factory.dart';

/// Read-only "quick look" at an entity, shown from a long-press on any ref
/// link (see `entity_link.dart`). Lets the character sheet and the creation
/// wizard show a card's full content without navigating away from the step.
///
/// Deliberately **not** [EntityCard]: that widget reads and writes
/// `entityProvider` on every field, and the wizard's entities are the bundled
/// SRD / installed-package rows, which never live in that map. This renders
/// off a plain [Entity] plus whatever entity map the host already threads into
/// its field widgets, so both contexts work through one path.
Future<void> showEntityPreview(
  BuildContext context,
  Entity entity, {
  Map<String, Entity>? entities,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Consumer(
          builder: (ctx, ref, _) => _PreviewBody(
            entity: entity,
            entities: entities ?? ref.read(entityProvider),
            category: ref
                .read(worldSchemaProvider)
                .categories
                .where((c) => c.slug == entity.categorySlug)
                .firstOrNull,
            ref: ref,
          ),
        ),
      ),
    ),
  );
}

class _PreviewBody extends StatelessWidget {
  final Entity entity;
  final Map<String, Entity> entities;
  final EntityCategorySchema? category;
  final WidgetRef ref;

  const _PreviewBody({
    required this.entity,
    required this.entities,
    required this.category,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // imagePath is the legacy single-portrait slot and still holds the art for
    // most cards; entity_card renders both, so must this.
    final images = [
      if (entity.imagePath.isNotEmpty) entity.imagePath,
      ...entity.images,
    ];
    final fields = [
      for (final f in category?.fields ?? const [])
        if (!_isEmpty(entity.fields[f.fieldKey])) f,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: palette.chr,
                  child: SizedBox(
                    width: 200,
                    // contain, not cover: a quick look should show the whole
                    // art (maps and landscape pieces included), not a crop.
                    child: AssetRefImage(
                      ref: AssetRef(images[i]),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            entity.name.isEmpty ? '(Unnamed)' : entity.name,
            style: TextStyle(
              fontFamily: palette.useSerif ? 'Georgia' : null,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: palette.srdHeadingRed,
              height: 1.1,
            ),
          ),
          if (category != null)
            Text(
              category!.name,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: palette.srdSubtitle,
              ),
            ),
          const SizedBox(height: 8),
          if (entity.description.trim().isNotEmpty) ...[
            ExpandableMarkdown(
              data: entity.description,
              collapsedMaxLines: 6,
              collapsedTextStyle: TextStyle(fontSize: 15, color: palette.srdInk),
            ),
            const SizedBox(height: 8),
          ],
          for (final f in fields)
            FieldWidgetFactory.create(
              schema: f,
              value: entity.fields[f.fieldKey],
              readOnly: true,
              onChanged: (_) {},
              entities: entities,
              ref: ref,
              entityFields: entity.fields,
            ),
        ],
      ),
    );
  }
}

/// Nothing worth a row: unset, blank string, or an empty list/map.
bool _isEmpty(Object? v) =>
    v == null ||
    (v is String && v.trim().isEmpty) ||
    (v is Iterable && v.isEmpty) ||
    (v is Map && v.isEmpty);

/// Wraps [child] so a long-press opens [entity] in [showEntityPreview].
///
/// The creation wizard's pickers are `RadioListTile`s and `InkWell` rows —
/// neither exposes a long-press hook — so the gesture is added from outside.
/// A tap-only descendant loses the arena to this recognizer once the
/// long-press timer fires, so selection still works normally.
class EntityPreviewLongPress extends StatelessWidget {
  const EntityPreviewLongPress({
    super.key,
    required this.entity,
    required this.entities,
    required this.child,
  });

  final Entity entity;
  final Map<String, Entity> entities;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onLongPress: () =>
            showEntityPreview(context, entity, entities: entities),
        child: child,
      );
}
