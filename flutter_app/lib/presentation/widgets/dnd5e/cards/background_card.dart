import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../../../../domain/dnd5e/character/background.dart';
import '../../../../domain/dnd5e/character/background_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';

/// Typed renderer for a Tier 2 `Background` row.
class BackgroundCard extends ConsumerWidget {
  final String entityId;
  final Color categoryColor;

  const BackgroundCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(backgroundRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading background…'),
      error: (e, _) => CardPlaceholder('Failed to load background: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Background "$entityId" not found');
        }
        final Background bg;
        try {
          bg = backgroundFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid background body: $e');
        }
        return CardShell(
          title: bg.name,
          subtitle: 'Background',
          categoryColor: categoryColor,
          tags: [
            if (bg.effects.isNotEmpty) CardTag('${bg.effects.length} effects'),
          ],
          children: [
            if (bg.description.isNotEmpty)
              CardSection(title: 'DESCRIPTION', child: Text(bg.description)),
          ],
        );
      },
    );
  }
}
