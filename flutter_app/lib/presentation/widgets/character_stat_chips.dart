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

/// Extracts the canonical race and class entity ids the stat-chip strip
/// needs to resolve names. Pulled out so callers that prefer scoped
/// `.select()` watches can resolve the two names without forcing a full
/// entity-map watch (see E5 in performance_hotspots_wizard_editor_hub.md).
class CharacterRaceClassIds {
  final String? raceId;
  final String? classId;
  const CharacterRaceClassIds({this.raceId, this.classId});
}

CharacterRaceClassIds characterRaceClassIds(Character character) {
  final fields = character.entity.fields;
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

  return CharacterRaceClassIds(
    raceId: firstId(const ['species_ref', 'race']),
    classId: firstId(const ['class_refs', 'class_']),
  );
}

List<CharacterStatLine> characterStatLines(
  Character character,
  Map<String, Entity> entities, {
  int? effectiveAc,
}) {
  final ids = characterRaceClassIds(character);
  final raceName =
      ids.raceId == null ? '—' : (entities[ids.raceId]?.name ?? '—');
  final className =
      ids.classId == null ? '—' : (entities[ids.classId]?.name ?? '—');
  return characterStatLinesWithNames(
    character,
    raceName: raceName,
    className: className,
    effectiveAc: effectiveAc,
  );
}

/// E5: alternate entry point used by surfaces that have already resolved
/// the race/class names via `.select()`. Skips the full entity-map watch
/// (which is the expensive part for character headers / list tiles that
/// only need two strings).
List<CharacterStatLine> characterStatLinesWithNames(
  Character character, {
  required String raceName,
  required String className,
  int? effectiveAc,
}) {
  final fields = character.entity.fields;

  int asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
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
  // Prefer the resolver-computed AC (armor + Dex + shield + acBonus +
  // unarmored formulas) so equipping armor/shield refreshes the chip
  // without manual edits to combat_stats. Fall back to the manually
  // authored field when no resolver value is supplied (sidebar/list tiles
  // that don't invoke the effective provider).
  final ac = asInt(fields['ac']);
  final String acDisplay;
  if (effectiveAc != null && effectiveAc > 0) {
    acDisplay = '$effectiveAc';
  } else if (ac > 0) {
    acDisplay = '$ac';
  } else if (combatAc != null && combatAc > 0) {
    acDisplay = '$combatAc';
  } else {
    acDisplay = '—';
  }

  var level = asInt(fields['level']);
  if (level == 0 && combatLevel != null) level = combatLevel;

  final subspeciesRaw = fields['subspecies_id'];
  final subspeciesName =
      subspeciesRaw is String && subspeciesRaw.isNotEmpty ? subspeciesRaw : '';

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
    if (subspeciesName.isNotEmpty)
      CharacterStatLine(
        icon: Icons.diversity_3,
        label: 'Ancestry',
        value: subspeciesName,
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
///
/// `scrollHorizontally` swaps the default [Wrap] for a single-line
/// horizontally-scrollable [Row]. Used by the editor header on phones where
/// a long species/class name would otherwise force a chip wider than the
/// portrait column and trigger a RenderFlex overflow.
class CharacterStatChips extends StatelessWidget {
  final List<CharacterStatLine> lines;
  final DmToolColors palette;
  final bool compact;
  final bool scrollHorizontally;

  const CharacterStatChips({
    super.key,
    required this.lines,
    required this.palette,
    this.compact = false,
    this.scrollHorizontally = false,
  });

  @override
  Widget build(BuildContext context) {
    // Icon-only grid laid directly onto the card (no background, no border).
    // Hover/long-press surfaces the label via Tooltip so users can still
    // disambiguate the icons.
    final fontSize = compact ? 12.0 : 16.0;
    final iconSize = compact ? 13.0 : 18.0;
    final gap = compact ? 3.0 : 6.0;
    final spacing = compact ? 10.0 : 18.0;
    final chips = [
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
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
            ],
          ),
        ),
    ];
    if (scrollHorizontally) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              chips[i],
            ],
          ],
        ),
      );
    }
    return Wrap(
      spacing: spacing,
      runSpacing: compact ? 4 : 8,
      children: chips,
    );
  }
}
