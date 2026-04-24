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
import '../inline_field_extras.dart';

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
        return _BackgroundBody(
          bg: bg,
          name: row.name,
          body: body,
          categoryColor: widget.categoryColor,
          onSave: _save,
        );
      },
    );
  }
}

class _BackgroundBody extends ConsumerWidget {
  final Background bg;
  final String name;
  final Map<String, Object?> body;
  final Color categoryColor;
  final Future<void> Function(String, Map<String, Object?>) onSave;

  const _BackgroundBody({
    required this.bg,
    required this.name,
    required this.body,
    required this.categoryColor,
    required this.onSave,
  });

  /// Rewrites `effects[]` in-place so that entries of kind [kind] are
  /// exactly [newIds] (as `GrantProficiency` maps), while preserving every
  /// other effect.
  Map<String, Object?> _withProficiencies(
      String kind, List<String> newIds) {
    final rawEffects = body['effects'];
    final kept = <Map<String, Object?>>[];
    if (rawEffects is List) {
      for (final e in rawEffects) {
        if (e is Map) {
          final m = e.cast<String, Object?>();
          if (m['t'] == 'grantProficiency' && m['kind'] == kind) continue;
          kept.add(m);
        }
      }
    }
    for (final id in newIds) {
      kept.add({
        't': 'grantProficiency',
        'kind': kind,
        'targetId': id,
      });
    }
    final out = <String, Object?>{...body};
    if (kept.isEmpty) {
      out.remove('effects');
    } else {
      out['effects'] = kept;
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<CatalogOption> optionsFrom<T>(AsyncValue<List<T>> async) =>
        async.maybeWhen(
          data: (list) => [
            for (final e in list)
              CatalogOption(
                id: (e as dynamic).id as String,
                name: (e as dynamic).name as String,
              )
          ],
          orElse: () => const <CatalogOption>[],
        );

    final skillOptions = optionsFrom(ref.watch(allSkillsProvider));
    final languageOptions = optionsFrom(ref.watch(allLanguagesProvider));
    final featOptions = optionsFrom(ref.watch(allFeatsProvider));
    final itemOptions = optionsFrom(ref.watch(allItemsProvider));

    return CardShell(
      title: name,
      subtitle: 'Background',
      categoryColor: categoryColor,
      tags: [
        if (bg.effects.isNotEmpty) CardTag('${bg.effects.length} effects'),
      ],
      children: [
        CardFieldGroup(title: 'Identity', children: [
          CardFieldGrid(columns: 2, fields: [
            CardField(
              label: 'Name',
              child: InlineTextField(
                value: name,
                style: Theme.of(context).textTheme.titleMedium,
                onCommit: (v) => onSave(v, body),
              ),
            ),
            CardField(
              label: 'Starting Feat',
              child: InlineCatalogRelationField(
                value: (body['grantedFeatId'] as String?) ?? '',
                options: featOptions,
                placeholder: 'None',
                onClear: () => onSave(name, {
                  ...body,
                }..remove('grantedFeatId')),
                onCommit: (v) =>
                    onSave(name, {...body, 'grantedFeatId': v}),
              ),
            ),
          ]),
        ]),
        CardFieldGroup(title: 'Proficiencies', children: [
          _labeled(
            'Skills',
            InlineCatalogChipListField(
              ids: bg.skillProficiencyIds,
              options: skillOptions,
              onCommit: (ids) =>
                  onSave(name, _withProficiencies('skill', ids)),
            ),
          ),
          _labeled(
            'Languages',
            InlineCatalogChipListField(
              ids: bg.languageIds,
              options: languageOptions,
              onCommit: (ids) =>
                  onSave(name, _withProficiencies('language', ids)),
            ),
          ),
          _labeled(
            'Tools',
            InlineCatalogChipListField(
              ids: bg.toolProficiencyIds,
              options: const <CatalogOption>[],
              onCommit: (ids) =>
                  onSave(name, _withProficiencies('tool', ids)),
            ),
          ),
        ]),
        CardFieldGroup(title: 'Starting Equipment', children: [
          InlineCatalogChipListField(
            ids: bg.startingEquipmentIds,
            options: itemOptions,
            onCommit: (ids) {
              final out = <String, Object?>{...body};
              if (ids.isEmpty) {
                out.remove('startingEquipmentIds');
              } else {
                out['startingEquipmentIds'] = ids;
              }
              onSave(name, out);
            },
          ),
        ]),
        CardFieldGroup(title: 'Description', children: [
          InlineTextField(
            value: bg.description,
            maxLines: 12,
            placeholder: 'No description yet — tap to add…',
            onCommit: (v) => onSave(name, {...body, 'description': v}),
          ),
        ]),
      ],
    );
  }

  static Widget _labeled(String label, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text('$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: child),
          ],
        ),
      );
}
