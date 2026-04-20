import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../../../../domain/dnd5e/character/feat.dart';
import '../../../../domain/dnd5e/character/feat_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../editors/entity_editor_dialog.dart';

/// Typed renderer for a Tier 2 `Feat` row.
class FeatCard extends ConsumerWidget {
  final String entityId;
  final Color categoryColor;

  const FeatCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading feat…'),
      error: (e, _) => CardPlaceholder('Failed to load feat: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Feat "$entityId" not found');
        }
        final Feat feat;
        try {
          feat = featFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid feat body: $e');
        }
        return CardShell(
          title: feat.name,
          subtitle: _categoryLabel(feat.category),
          categoryColor: categoryColor,
          onEdit: () => showEntityEditor(
            context: context,
            entityId: entityId,
            categorySlug: 'feat',
          ),
          tags: [
            CardTag(_categoryLabel(feat.category)),
            if (feat.repeatable) const CardTag('Repeatable'),
          ],
          children: [
            if (feat.prerequisite != null && feat.prerequisite!.isNotEmpty)
              CardKeyValue('Prerequisite', feat.prerequisite!),
            if (feat.effects.isNotEmpty)
              CardKeyValue('Effects', '${feat.effects.length} effect(s)'),
            if (feat.description.isNotEmpty)
              CardSection(title: 'DESCRIPTION', child: Text(feat.description)),
          ],
        );
      },
    );
  }
}

String _categoryLabel(FeatCategory c) => switch (c) {
      FeatCategory.origin => 'Origin',
      FeatCategory.general => 'General',
      FeatCategory.fightingStyle => 'Fighting Style',
      FeatCategory.epicBoon => 'Epic Boon',
    };
