import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/character/species.dart';
import '../../../../domain/dnd5e/character/species_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../entity_link_chip.dart';
import '../inline_field.dart';

/// Typed renderer for a Tier 2 `Species` (race) row.
class RaceCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const RaceCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<RaceCard> createState() => _RaceCardState();
}

class _RaceCardState extends ConsumerState<RaceCard> {
  late String _effectiveId = widget.entityId;

  @override
  void didUpdateWidget(covariant RaceCard old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) {
      _effectiveId = widget.entityId;
    }
  }

  Future<void> _save(String name, Map<String, Object?> body) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    if (campaignId == null) return;
    final writtenId = await saveEditedEntity(
      db: ref.read(appDatabaseProvider),
      currentId: _effectiveId,
      categorySlug: 'race',
      activeCampaignId: campaignId,
      name: name,
      bodyJson: body,
    );
    if (!mounted) return;
    if (writtenId != _effectiveId) {
      setState(() => _effectiveId = writtenId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(speciesRowProvider(_effectiveId));
    return async.when(
      loading: () => const CardPlaceholder('Loading species…'),
      error: (e, _) => CardPlaceholder('Failed to load species: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Species "$_effectiveId" not found');
        }
        final Species sp;
        final Map<String, Object?> body;
        try {
          body = (jsonDecode(row.bodyJson) as Map).cast<String, Object?>();
          sp = speciesFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid species body: $e');
        }
        return CardShell(
          title: row.name,
          subtitle: 'Species',
          categoryColor: widget.categoryColor,
          tags: [
            EntityLinkChip(entityId: sp.sizeId),
            CardTag('Speed ${sp.baseSpeedFt} ft.'),
            if (sp.effects.isNotEmpty)
              CardTag('${sp.effects.length} trait(s)'),
          ],
          children: [
            CardFieldGroup(title: 'Identity', children: [
              CardFieldGrid(columns: 2, fields: [
                CardField(
                  label: 'Name',
                  child: InlineTextField(
                    value: row.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    onCommit: (v) => _save(v, body),
                  ),
                ),
                CardField(
                    label: 'Size',
                    child: EntityLinkChip(entityId: sp.sizeId)),
                CardField(
                    label: 'Base Speed', child: Text('${sp.baseSpeedFt} ft.')),
                CardField(
                    label: 'Traits', child: Text('${sp.effects.length}')),
              ]),
            ]),
            CardFieldGroup(title: 'Description', children: [
              InlineTextField(
                value: sp.description,
                maxLines: 12,
                placeholder: 'No description yet — tap to add…',
                onCommit: (v) =>
                    _save(row.name, {...body, 'description': v}),
              ),
            ]),
          ],
        );
      },
    );
  }
}

