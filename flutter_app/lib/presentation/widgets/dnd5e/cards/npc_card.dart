import 'package:flutter/material.dart';

import 'monster_card.dart';

/// NPC entity card. NPCs in 5e share the `Monster` stat block shape — the DM
/// just categorizes them as NPC for narrative intent. Typed storage for
/// bespoke per-campaign NPCs lands in Batch 7 (`homebrew_entries` +
/// `hb:<campaignId>:<uuid>` ids); until then this widget delegates to
/// [MonsterCard] so SRD creatures reused as NPCs render correctly.
class NpcCard extends StatelessWidget {
  final String entityId;
  final Color categoryColor;

  const NpcCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MonsterCard(entityId: entityId, categoryColor: categoryColor);
  }
}
