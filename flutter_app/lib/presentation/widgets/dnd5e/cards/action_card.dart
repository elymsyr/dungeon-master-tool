import 'package:flutter/material.dart';

import '../card_shell.dart';

/// Shared renderer for standalone action / reaction / trait / legendary-action
/// entries. In the typed D&D 5e model these live embedded on the parent
/// `Monster` or `CharacterClass`, so the sidebar only surfaces them when a
/// package explicitly ships them as first-class rows. Batch 7 (homebrew) wires
/// this surface to the `homebrew_entries.body_json` payload; Batch 2 ships the
/// shell so dispatch coverage is complete.
class ActionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CardShell(
      title: entityId,
      subtitle: _subtitle(categorySlug),
      categoryColor: categoryColor,
      children: [
        CardSection(
          title: 'STATUS',
          child: Text(
            'Standalone "$categorySlug" rows arrive with Batch 7 homebrew '
            'content. SRD actions live embedded on their parent monster.',
          ),
        ),
      ],
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
