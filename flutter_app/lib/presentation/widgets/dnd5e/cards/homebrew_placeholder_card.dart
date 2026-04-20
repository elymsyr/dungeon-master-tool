import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../card_shell.dart';

/// Typed renderer for world-content categories stored in `homebrew_entries`
/// (Doc 50 Batch 7): quest / location / lore / plane / status-effect. Each
/// row ships `{ categorySlug, name, bodyJson }`; body shape is typed per
/// category by application-layer sealed models (follow-up). Until those
/// land, this card decodes the body as a `Map<String, Object?>` and renders
/// key-value pairs — a typed surface that preserves every field the user
/// authors.
class HomebrewPlaceholderCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homebrewEntryRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading entry…'),
      error: (e, _) => CardPlaceholder('Failed to load entry: $e'),
      data: (row) {
        if (row == null) {
          return CardShell(
            title: entityId,
            subtitle: _label(categorySlug),
            categoryColor: categoryColor,
            children: [
              CardSection(
                title: 'STATUS',
                child: Text(
                  'No typed "$categorySlug" row found. Create one via the '
                  'sidebar "Create" action (Batch 7 homebrew flow).',
                ),
              ),
            ],
          );
        }
        final body = _decodeBody(row.bodyJson);
        return CardShell(
          title: row.name,
          subtitle: _label(row.categorySlug),
          categoryColor: categoryColor,
          tags: [
            CardTag(_label(row.categorySlug)),
            if (row.sourcePackageId != 'homebrew')
              CardTag(row.sourcePackageId),
          ],
          children: [
            for (final entry in body.entries)
              CardKeyValue(entry.key, '${entry.value}'),
            if (body.isEmpty)
              const CardSection(
                title: 'BODY',
                child: Text('(empty)'),
              ),
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
