import 'package:flutter/material.dart';

import '../card_shell.dart';

/// Player-character card. Typed character rendering lands in Batch 6
/// (`Dnd5eCharacter` + character editor rewrite); Batch 2 ships the shell so
/// the dispatcher can route `player` slug to a typed surface today.
class PlayerCard extends StatelessWidget {
  final String entityId;
  final Color categoryColor;

  const PlayerCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CardShell(
      title: entityId,
      subtitle: 'Player Character',
      categoryColor: categoryColor,
      children: const [
        CardSection(
          title: 'STATUS',
          child: Text(
            'Typed player-character rendering lands in Batch 6 — see '
            'docs/engineering/50-typed-ui-migration.md.',
          ),
        ),
      ],
    );
  }
}
