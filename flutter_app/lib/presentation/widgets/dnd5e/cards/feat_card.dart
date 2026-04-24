import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/character/feat.dart';
import '../../../../domain/dnd5e/character/feat_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../inline_field.dart';
import '../inline_field_extras.dart';

/// Typed renderer for a Tier 2 `Feat` row with inline name/prerequisite/
/// description editing. Edits fork SRD-owned rows into the active
/// campaign via [saveEditedEntity].
class FeatCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const FeatCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<FeatCard> createState() => _FeatCardState();
}

class _FeatCardState extends ConsumerState<FeatCard> {
  late String _effectiveId = widget.entityId;

  @override
  void didUpdateWidget(covariant FeatCard old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) {
      _effectiveId = widget.entityId;
    }
  }

  Future<void> _save({
    required String name,
    required Map<String, Object?> body,
  }) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    if (campaignId == null) return;
    final writtenId = await saveEditedEntity(
      db: ref.read(appDatabaseProvider),
      currentId: _effectiveId,
      categorySlug: 'feat',
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
    final async = ref.watch(featRowProvider(_effectiveId));
    return async.when(
      loading: () => const CardPlaceholder('Loading feat…'),
      error: (e, _) => CardPlaceholder('Failed to load feat: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Feat "$_effectiveId" not found');
        }
        final Feat feat;
        final Map<String, Object?> body;
        try {
          body = (jsonDecode(row.bodyJson) as Map).cast<String, Object?>();
          feat = featFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid feat body: $e');
        }
        return CardShell(
          title: row.name,
          subtitle: _categoryLabel(feat.category),
          categoryColor: widget.categoryColor,
          tags: [
            CardTag(_categoryLabel(feat.category)),
            if (feat.repeatable) const CardTag('Repeatable'),
            if (feat.prerequisite != null)
              CardTag('Prereq: ${feat.prerequisite}'),
          ],
          children: [
            CardFieldGroup(title: 'Identity', children: [
              CardFieldGrid(columns: 2, fields: [
                CardField(
                  label: 'Name',
                  child: InlineTextField(
                    value: row.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    onCommit: (v) => _save(name: v, body: body),
                  ),
                ),
                CardField(
                  label: 'Category',
                  child: InlineEnumField<FeatCategory>(
                    value: feat.category,
                    options: FeatCategory.values,
                    labelOf: _categoryLabel,
                    onCommit: (v) => _save(
                      name: row.name,
                      body: {...body, 'category': v.name},
                    ),
                  ),
                ),
                CardField(
                  label: 'Repeatable',
                  child: InlineBoolField(
                    value: feat.repeatable,
                    onCommit: (v) => _save(
                      name: row.name,
                      body: {
                        ...body,
                        if (v) 'repeatable': true,
                      }..removeWhere((k, _) => !v && k == 'repeatable'),
                    ),
                  ),
                ),
                CardField(
                  label: 'Prerequisite',
                  child: InlineTextField(
                    value: feat.prerequisite ?? '',
                    placeholder: 'None',
                    onCommit: (v) => _save(
                      name: row.name,
                      body: {
                        ...body,
                        'prerequisite': v.isEmpty ? null : v,
                      },
                    ),
                  ),
                ),
                CardField(
                    label: 'Effects',
                    child: Text('${feat.effects.length}')),
              ]),
            ]),
            CardFieldGroup(title: 'Description', children: [
              InlineTextField(
                value: feat.description,
                maxLines: 12,
                placeholder: 'No description yet — tap to add…',
                onCommit: (v) => _save(
                  name: row.name,
                  body: {...body, 'description': v},
                ),
              ),
            ]),
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
