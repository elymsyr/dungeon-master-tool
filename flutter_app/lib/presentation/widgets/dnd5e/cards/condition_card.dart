import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../../../../domain/dnd5e/catalog/catalog_json_codecs.dart' as codecs;
import '../../../../domain/dnd5e/catalog/condition.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';

/// Typed renderer for a Tier 1 `Condition` catalog row.
class ConditionCard extends ConsumerWidget {
  final String entityId;
  final Color categoryColor;

  const ConditionCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conditionRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading condition…'),
      error: (e, _) => CardPlaceholder('Failed to load condition: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Condition "$entityId" not found');
        }
        final Condition c;
        try {
          c = codecs.conditionFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid condition body: $e');
        }
        return CardShell(
          title: c.name,
          subtitle: 'Condition',
          categoryColor: categoryColor,
          tags: [
            if (c.effects.isNotEmpty) CardTag('${c.effects.length} effects'),
          ],
          children: [
            if (c.description.isNotEmpty)
              CardSection(title: 'DESCRIPTION', child: Text(c.description)),
          ],
        );
      },
    );
  }
}
