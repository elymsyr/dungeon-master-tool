import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../../../../domain/dnd5e/character/species.dart';
import '../../../../domain/dnd5e/character/species_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../editors/entity_editor_dialog.dart';

/// Typed renderer for a Tier 2 `Species` (race) row.
class RaceCard extends ConsumerWidget {
  final String entityId;
  final Color categoryColor;

  const RaceCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(speciesRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading species…'),
      error: (e, _) => CardPlaceholder('Failed to load species: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Species "$entityId" not found');
        }
        final Species sp;
        try {
          sp = speciesFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid species body: $e');
        }
        return CardShell(
          title: sp.name,
          subtitle: 'Species',
          categoryColor: categoryColor,
          onEdit: () => showEntityEditor(
            context: context,
            entityId: entityId,
            categorySlug: 'race',
          ),
          tags: [
            CardTag(_localSlug(sp.sizeId)),
            CardTag('Speed ${sp.baseSpeedFt} ft.'),
            if (sp.effects.isNotEmpty)
              CardTag('${sp.effects.length} trait(s)'),
          ],
          children: [
            CardKeyValue('Size', _localSlug(sp.sizeId)),
            CardKeyValue('Base Speed', '${sp.baseSpeedFt} ft.'),
            if (sp.description.isNotEmpty)
              CardSection(title: 'DESCRIPTION', child: Text(sp.description)),
          ],
        );
      },
    );
  }
}

String _localSlug(String id) {
  final idx = id.indexOf(':');
  return idx < 0 ? id : id.substring(idx + 1);
}
