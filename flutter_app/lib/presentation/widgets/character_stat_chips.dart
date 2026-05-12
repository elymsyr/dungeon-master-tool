import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/services/builtin_srd_entities.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/entity.dart';
import '../theme/dm_tool_colors.dart';

/// Six summary stats shown on character header / sidebar / tab cards in
/// place of the freeform tag list: HP / max HP, Species, Class, Level,
/// Armor Class, and User. User is a forward-looking slot for Sprint E
/// (multi-user campaigns) — for now it renders an em-dash.
///
/// Resolution prefers the character's bound campaign (when it matches the
/// active campaign) and falls back to the bundled SRD entity map so
/// builtin-only characters still surface species/class names.
class CharacterStatLine {
  final IconData icon;
  final String label;
  final String value;
  const CharacterStatLine({
    required this.icon,
    required this.label,
    required this.value,
  });
}

List<CharacterStatLine> characterStatLines(
  Character character,
  Map<String, Entity> entities,
) {
  final fields = character.entity.fields;

  int asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  String? firstId(Iterable<String> keys) {
    for (final k in keys) {
      final v = fields[k];
      if (v is String && v.isNotEmpty) return v;
      if (v is List) {
        final s = v.whereType<String>().firstWhere(
              (e) => e.isNotEmpty,
              orElse: () => '',
            );
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  // Most templates author hp / max_hp / ac / level inside the
  // `combat_stats` Map field rather than at the flat-field root. Read both
  // and prefer whichever produces a non-zero value.
  var hp = asInt(fields['hp']);
  var maxHp = asInt(fields['max_hp']);
  final combat = fields['combat_stats'];
  int? combatAc;
  int? combatLevel;
  if (combat is Map) {
    if (hp == 0) hp = asInt(combat['hp']);
    if (maxHp == 0) maxHp = asInt(combat['max_hp']);
    if (combat['ac'] != null) combatAc = asInt(combat['ac']);
    if (combat['level'] != null) combatLevel = asInt(combat['level']);
  }
  final ac = asInt(fields['ac']);
  final acDisplay = ac > 0
      ? '$ac'
      : (combatAc != null && combatAc > 0 ? '$combatAc' : '—');

  final raceId = firstId(const ['species_ref', 'race']);
  final classId = firstId(const ['class_refs', 'class_']);
  final raceName = raceId == null ? '—' : (entities[raceId]?.name ?? '—');
  final className = classId == null ? '—' : (entities[classId]?.name ?? '—');
  var level = asInt(fields['level']);
  if (level == 0 && combatLevel != null) level = combatLevel;

  return [
    CharacterStatLine(
      icon: Icons.favorite,
      label: 'HP',
      value: maxHp > 0 ? '$hp / $maxHp' : '$hp',
    ),
    CharacterStatLine(
      icon: Icons.pets,
      label: 'Species',
      value: raceName,
    ),
    CharacterStatLine(
      icon: Icons.shield_moon_outlined,
      label: 'Class',
      value: className,
    ),
    CharacterStatLine(
      icon: Icons.trending_up,
      label: 'Level',
      value: level > 0 ? '$level' : '—',
    ),
    CharacterStatLine(
      icon: Icons.security,
      label: 'AC',
      value: acDisplay,
    ),
    const CharacterStatLine(
      icon: Icons.person_outline,
      label: 'User',
      value: '—',
    ),
  ];
}

/// Reads the right entity map for [character]: campaign-bound entities
/// when the character's world is open, otherwise the bundled SRD pack.
Map<String, Entity> readCharacterEntities(WidgetRef ref, Character character) {
  final builtin = ref.watch(builtinSrdEntitiesProvider);
  if (character.worldName.isEmpty) return builtin;
  final active = ref.watch(activeCampaignProvider);
  if (active != character.worldName) return builtin;
  final campaign = ref.watch(entityProvider);
  return mergeWithBuiltinSrd(campaign, builtin, useCampaign: true);
}

/// Compact chip strip rendering [characterStatLines]. Used by the editor
/// header (full size) and the sidebar / characters tab tile (compact).
class CharacterStatChips extends StatelessWidget {
  final List<CharacterStatLine> lines;
  final DmToolColors palette;
  final bool compact;

  const CharacterStatChips({
    super.key,
    required this.lines,
    required this.palette,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Icon-only grid laid directly onto the card (no background, no border).
    // Hover/long-press surfaces the label via Tooltip so users can still
    // disambiguate the icons.
    final fontSize = compact ? 13.0 : 16.0;
    final iconSize = compact ? 14.0 : 18.0;
    final gap = compact ? 4.0 : 6.0;
    return Wrap(
      spacing: compact ? 12 : 18,
      runSpacing: compact ? 4 : 8,
      children: [
        for (final l in lines)
          Tooltip(
            message: l.label,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(l.icon,
                    size: iconSize, color: palette.sidebarLabelSecondary),
                SizedBox(width: gap),
                Text(
                  l.value,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
