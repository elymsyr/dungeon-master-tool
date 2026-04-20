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

/// World-content categories stored in `homebrew_entries`: quest / location /
/// lore / plane / status-effect. Each row ships `{ categorySlug, name,
/// bodyJson }`; body shape is an open map keyed by well-known fields the
/// card promotes to inline editors (`summary`, `description`) plus free-form
/// key-value pairs. Layout matches every other typed card: Identity group
/// + Description group.
class HomebrewPlaceholderCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;
  final String categorySlug;

  const HomebrewPlaceholderCard({
    required this.entityId,
    required this.categoryColor,
    required this.categorySlug,
    super.key,
  });

  @override
  ConsumerState<HomebrewPlaceholderCard> createState() =>
      _HomebrewPlaceholderCardState();
}

class _HomebrewPlaceholderCardState
    extends ConsumerState<HomebrewPlaceholderCard> {
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
            row == null ? <String, Object?>{} : _decodeBody(row.bodyJson);
        final summary = (body['summary'] as String?) ?? '';
        final description = (body['description'] as String?) ?? '';
        final promotedKeys = {'summary', 'description'};
        final extraEntries = body.entries
            .where((e) => !promotedKeys.contains(e.key))
            .toList();

        return CardShell(
          title: name,
          subtitle: _label(widget.categorySlug),
          categoryColor: widget.categoryColor,
          tags: [
            CardTag(_label(widget.categorySlug)),
            if (row != null && row.sourcePackageId != 'homebrew')
              CardTag(row.sourcePackageId),
          ],
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
                    label: 'Kind', child: Text(_label(widget.categorySlug))),
                CardField(
                  label: 'Summary',
                  child: InlineTextField(
                    value: summary,
                    placeholder: 'Short one-liner',
                    onCommit: (v) =>
                        _save(name: name, body: {...body, 'summary': v}),
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
            if (extraEntries.isNotEmpty)
              CardFieldGroup(title: 'Other Fields', children: [
                for (final e in extraEntries)
                  CardKeyValue(e.key, '${e.value}'),
              ]),
          ],
        );
      },
    );
  }
}

String _label(String slug) => switch (slug) {
      'location' => 'Location',
      'quest' => 'Quest',
      'lore' => 'Lore',
      'plane' => 'Plane',
      'status-effect' => 'Status Effect',
      _ => slug,
    };

Map<String, Object?> _decodeBody(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    return const {};
  } catch (_) {
    return const {};
  }
}
