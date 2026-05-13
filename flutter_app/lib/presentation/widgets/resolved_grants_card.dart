import 'package:flutter/material.dart';

import '../../domain/entities/character/effective_character.dart';
import '../../domain/entities/entity.dart';
import '../theme/dm_tool_colors.dart';
import '../screens/database/entity_card.dart';

/// Read-only summary of grants computed by [CharacterResolver] but not always
/// mirrored on the PC entity's raw ref fields — senses, damage resistances /
/// immunities / vulnerabilities, and condition immunities. Renders as a
/// collapsible card so it doesn't push the editable schema fields down on
/// every sheet load.
class ResolvedGrantsCard extends StatelessWidget {
  final EffectiveCharacter effective;
  final Map<String, Entity> entities;
  final DmToolColors palette;

  const ResolvedGrantsCard({
    super.key,
    required this.effective,
    required this.entities,
    required this.palette,
  });

  String _nameOf(String id) => entities[id]?.name ?? id;

  String _chipLabel(String id) {
    final name = _nameOf(id);
    final sources = effective.grantSources[id];
    if (sources == null || sources.isEmpty) return name;
    return '$name — ${sources.join(', ')}';
  }

  Widget _chipRow(
    String label,
    List<String> ids,
    Color chipColor,
  ) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          for (final id in ids)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: chipColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                _chipLabel(id),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.srdInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final senses = effective.senseEntityIds;
    final res = effective.damageResistanceIds;
    final imm = effective.damageImmunityIds;
    final vuln = effective.damageVulnerabilityIds;
    final cimm = effective.conditionImmunityIds;
    if (senses.isEmpty &&
        res.isEmpty &&
        imm.isEmpty &&
        vuln.isEmpty &&
        cimm.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: BorderRadius.circular(palette.cardBorderRadius),
          border: Border.all(color: palette.featureCardBorder, width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntityCardSectionHeading(
              title: 'Resolved Grants',
              palette: palette,
              leadingIcon: Icons.shield_outlined,
            ),
            const SizedBox(height: 8),
            _chipRow('Senses', senses, Colors.indigo),
            _chipRow('Resistances', res, Colors.green),
            _chipRow('Immunities', imm, Colors.blue),
            _chipRow('Vulnerabilities', vuln, Colors.deepOrange),
            _chipRow('Condition Imm.', cimm, Colors.purple),
          ],
        ),
      ),
    );
  }
}
