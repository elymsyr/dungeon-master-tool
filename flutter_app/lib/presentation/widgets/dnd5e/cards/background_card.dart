import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/character/background.dart';
import '../../../../domain/dnd5e/character/background_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../inline_field.dart';

/// Typed renderer for a Tier 2 `Background` row with inline name +
/// description editing. Edits fork SRD rows into the active campaign.
class BackgroundCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const BackgroundCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<BackgroundCard> createState() => _BackgroundCardState();
}

class _BackgroundCardState extends ConsumerState<BackgroundCard> {
  late String _effectiveId = widget.entityId;

  @override
  void didUpdateWidget(covariant BackgroundCard old) {
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
      categorySlug: 'background',
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
    final async = ref.watch(backgroundRowProvider(_effectiveId));
    return async.when(
      loading: () => const CardPlaceholder('Loading background…'),
      error: (e, _) => CardPlaceholder('Failed to load background: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Background "$_effectiveId" not found');
        }
        final Background bg;
        final Map<String, Object?> body;
        try {
          body = (jsonDecode(row.bodyJson) as Map).cast<String, Object?>();
          bg = backgroundFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid background body: $e');
        }
        return CardShell(
          title: row.name,
          subtitle: 'Background',
          categoryColor: widget.categoryColor,
          tags: [
            if (bg.effects.isNotEmpty)
              CardTag('${bg.effects.length} effects'),
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
                    label: 'Effects',
                    child: Text('${bg.effects.length}')),
              ]),
            ]),
            CardFieldGroup(title: 'Description', children: [
              InlineTextField(
                value: bg.description,
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
