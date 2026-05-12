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

  final hp = asInt(fields['hp']);
  var maxHp = asInt(fields['max_hp']);
  // Some templates only store the HP pair inside `combat_stats`; fall back
  // to that when the flat keys are zero.
  final combat = fields['combat_stats'];
  int? combatAc;
  if (combat is Map) {
    if (maxHp == 0) maxHp = asInt(combat['max_hp']);
    if (combat['ac'] != null) combatAc = asInt(combat['ac']);
  }
  final ac = asInt(fields['ac']);
  final acDisplay = ac > 0
      ? '$ac'
      : (combatAc != null && combatAc > 0 ? '$combatAc' : '—');

  final raceId = firstId(const ['species_ref', 'race']);
  final classId = firstId(const ['class_refs', 'class_']);
  final raceName = raceId == null ? '—' : (entities[raceId]?.name ?? '—');
  final className = classId == null ? '—' : (entities[classId]?.name ?? '—');
  final level = asInt(fields['level']);

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
    final fontSize = compact ? 10.0 : 12.0;
    final iconSize = compact ? 10.0 : 12.0;
    final padH = compact ? 5.0 : 8.0;
    final padV = compact ? 1.0 : 3.0;
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: [
        for (final l in lines)
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
              color: palette.sidebarFilterBg,
              borderRadius: palette.chr,
              border: Border.all(color: palette.featureCardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(l.icon,
                    size: iconSize, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 4),
                Text(
                  '${l.label}: ${l.value}',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: palette.tabText,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
