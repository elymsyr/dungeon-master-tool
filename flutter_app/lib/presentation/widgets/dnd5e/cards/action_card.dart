import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/database/database_provider.dart';
import '../card_shell.dart';
import '../inline_field.dart';

/// Shared renderer for standalone action / reaction / trait / legendary-action
/// rows. SRD actions live embedded on their parent monster; standalone rows
/// are homebrew entries. Layout mirrors every other typed card: Identity
/// grid + Description, with inline editing on name + description + trigger.
class ActionCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;
  final String categorySlug;

  const ActionCard({
    required this.entityId,
    required this.categoryColor,
    required this.categorySlug,
    super.key,
  });

  @override
  ConsumerState<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends ConsumerState<ActionCard> {
  Future<void> _save({
    required String name,
    required Map<String, Object?> body,
  }) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    final db = ref.read(appDatabaseProvider);
    await db.dnd5eContentDao.upsertHomebrewEntry(
      HomebrewEntriesCompanion.insert(
        id: widget.entityId,
        categorySlug: widget.categorySlug,
        name: name,
        bodyJson: jsonEncode(body),
        campaignId: Value(campaignId),
      ),
    );
    if (!mounted) return;
    ref.invalidate(homebrewEntryRowProvider(widget.entityId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homebrewEntryRowProvider(widget.entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading entry…'),
      error: (e, _) => CardPlaceholder('Failed to load entry: $e'),
      data: (row) {
        final name = row?.name ?? widget.entityId;
        final body =
            row == null ? <String, Object?>{} : _decode(row.bodyJson);
        final trigger = (body['trigger'] as String?) ?? '';
        final cost = (body['cost'] as String?) ?? '';
        final description = (body['description'] as String?) ?? '';
        return CardShell(
          title: name,
          subtitle: _subtitle(widget.categorySlug),
          categoryColor: widget.categoryColor,
          tags: [CardTag(_subtitle(widget.categorySlug))],
          children: [
            CardFieldGroup(title: 'Identity', children: [
              CardFieldGrid(columns: 2, fields: [
                CardField(
                  label: 'Name',
                  child: InlineTextField(
                    value: name,
                    style: Theme.of(context).textTheme.titleMedium,
                    onCommit: (v) => _save(name: v, body: body),
                  ),
                ),
                CardField(
                  label: 'Kind',
                  child: Text(_subtitle(widget.categorySlug)),
                ),
                CardField(
                  label: 'Trigger',
                  child: InlineTextField(
                    value: trigger,
                    placeholder:
                        widget.categorySlug == 'reaction' ? 'Required' : '—',
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'trigger': v}),
                  ),
                ),
                CardField(
                  label: 'Cost',
                  child: InlineTextField(
                    value: cost,
                    placeholder: 'e.g. 1 action',
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'cost': v}),
                  ),
                ),
              ]),
            ]),
            CardFieldGroup(title: 'Description', children: [
              InlineTextField(
                value: description,
                maxLines: 12,
                placeholder: 'No description yet — tap to add…',
                onCommit: (v) =>
                    _save(name: name, body: {...body, 'description': v}),
              ),
            ]),
          ],
        );
      },
    );
  }
}

String _subtitle(String slug) => switch (slug) {
      'trait' => 'Trait',
      'action' => 'Action',
      'reaction' => 'Reaction',
      'legendary-action' => 'Legendary Action',
      _ => slug,
    };

Map<String, Object?> _decode(String raw) {
  try {
    final d = jsonDecode(raw);
    if (d is Map) return d.cast<String, Object?>();
  } catch (_) {}
  return <String, Object?>{};
}
