import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/character_creation/caster_progression.dart';
import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/services/builtin_srd_entities.dart';
import '../../../../../domain/entities/entity.dart';
import '../../../../theme/dm_tool_colors.dart';

/// Wizard step that lets spellcasting classes pick their starting
/// cantrips and prepared/known spells. Hidden (renders an empty notice)
/// for non-casters.
///
/// Caps prefer entity-populated `cantrips_known_by_level` /
/// `prepared_spells_by_level` tables, falling back to caster_kind-keyed
/// SRD defaults via [caster_progression] when those tables aren't
/// authored yet. Spell list is filtered by `class_refs` (must contain the
/// chosen class) and by `level` (≤ max preparable level at this character
/// level).
class SpellsStep extends ConsumerWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const SpellsStep({super.key, required this.draft, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final entities = ref.watch(wizardEntitiesProvider);

    final classEntity =
        draft.classId == null ? null : entities[draft.classId];
    if (classEntity == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Pick a class first.'),
      );
    }

    final kind = parseCasterKind(classEntity.fields['caster_kind']);
    if (kind == CasterKind.none) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '${classEntity.name} is not a spellcasting class — skip to the next step.',
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    }

    final cantripCap = levelTableValue(
            classEntity.fields['cantrips_known_by_level'], draft.level) ??
        defaultCantripsKnown(kind, draft.level);
    final preparedCap = levelTableValue(
            classEntity.fields['prepared_spells_by_level'], draft.level) ??
        defaultPreparedSpells(kind, draft.level);
    final maxSpellLevel = maxPreparableSpellLevel(kind, draft.level);

    // W4: pull the slug-filtered + name-sorted list from the cached family
    // instead of re-running `entities.values.where(...)` per build.
    final allSpells = ref.watch(entitiesByCategoryProvider('spell'));
    final classSpells =
        allSpells.where((e) => _classRefs(e).contains(draft.classId));
    final cantrips = classSpells.where((e) => _level(e) == 0).toList();
    final leveled = classSpells
        .where((e) => _level(e) >= 1 && _level(e) <= maxSpellLevel)
        .toList()
      ..sort((a, b) {
        final lvlCmp = _level(a).compareTo(_level(b));
        if (lvlCmp != 0) return lvlCmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final fallbackInUse =
        classEntity.fields['cantrips_known_by_level'] is! Map ||
            classEntity.fields['prepared_spells_by_level'] is! Map;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Spellcasting: ${classEntity.name} (${_kindLabel(kind)}). '
          'Casting ability: ${_castingAbilityLabel(entities, classEntity)}.',
          style: TextStyle(
            fontSize: 12,
            color: palette.sidebarLabelSecondary,
          ),
        ),
        if (fallbackInUse)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Class entity has no cantrip/prepared tables — using SRD defaults. '
              'Populate the class data for exact caps.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (cantripCap > 0)
          _SpellSection(
            title: 'Cantrips',
            cap: cantripCap,
            picked: draft.cantripIds,
            spells: cantrips,
            onToggle: (id) =>
                notifier.toggleCantrip(id, cap: cantripCap),
            palette: palette,
          ),
        if (preparedCap > 0)
          _SpellSection(
            title:
                'Spells (level 1${maxSpellLevel > 1 ? '–$maxSpellLevel' : ''})',
            cap: preparedCap,
            picked: draft.preparedSpellIds,
            spells: leveled,
            showLevelChip: true,
            onToggle: (id) =>
                notifier.togglePreparedSpell(id, cap: preparedCap),
            palette: palette,
          ),
        if (cantripCap == 0 && preparedCap == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'This caster does not pick spells at level ${draft.level}.',
              style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
      ],
    );
  }

  static List<String> _classRefs(Entity e) {
    final v = e.fields['class_refs'];
    if (v is! List) return const [];
    return v.whereType<String>().toList();
  }

  static int _level(Entity e) {
    final v = e.fields['level'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String _kindLabel(CasterKind k) => switch (k) {
        CasterKind.full => 'Full caster',
        CasterKind.half => 'Half caster',
        CasterKind.third => 'Third caster',
        CasterKind.pact => 'Pact magic',
        CasterKind.none => 'Non-caster',
      };

  static String _castingAbilityLabel(
      Map<String, Entity> entities, Entity classEntity) {
    final ref = classEntity.fields['casting_ability_ref'];
    if (ref is String && entities.containsKey(ref)) {
      return entities[ref]!.name;
    }
    return '—';
  }
}

class _SpellSection extends StatelessWidget {
  final String title;
  final int cap;
  final List<String> picked;
  final List<Entity> spells;
  final bool showLevelChip;
  final ValueChanged<String> onToggle;
  final DmToolColors palette;

  const _SpellSection({
    required this.title,
    required this.cap,
    required this.picked,
    required this.spells,
    this.showLevelChip = false,
    required this.onToggle,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final pickedSet = picked.toSet();
    final pickedCount = pickedSet.length;
    final remaining = cap - pickedCount;
    final atCap = remaining <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
              Text(
                remaining > 0
                    ? '$pickedCount / $cap (pick $remaining more)'
                    : '$pickedCount / $cap',
                style: TextStyle(
                  fontSize: 11,
                  color: remaining > 0
                      ? palette.sidebarLabelSecondary
                      : palette.successBtnBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (spells.isEmpty)
            Text(
              'No matching spells in the active campaign.',
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in spells)
                  _SpellRow(
                    entity: s,
                    selected: pickedSet.contains(s.id),
                    disabled: atCap && !pickedSet.contains(s.id),
                    showLevelChip: showLevelChip,
                    palette: palette,
                    onTap: () => onToggle(s.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SpellRow extends StatelessWidget {
  final Entity entity;
  final bool selected;
  final bool disabled;
  final bool showLevelChip;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _SpellRow({
    required this.entity,
    required this.selected,
    required this.disabled,
    required this.showLevelChip,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final level = (entity.fields['level'] is int)
        ? entity.fields['level'] as int
        : int.tryParse(entity.fields['level']?.toString() ?? '') ?? 0;
    final description = entity.description.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: palette.cbr,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: palette.cbr,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? palette.featureCardAccent
                    : palette.featureCardBorder,
                width: selected ? 2 : 1,
              ),
              borderRadius: palette.cbr,
            ),
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                selected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: disabled
                    ? palette.sidebarLabelSecondary
                    : selected
                        ? palette.featureCardAccent
                        : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showLevelChip)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: palette.featureCardBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: palette.featureCardBorder),
                          ),
                          child: Text(
                            'L$level',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: palette.tabActiveText,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          entity.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: disabled
                                ? palette.sidebarLabelSecondary
                                : palette.tabActiveText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.sidebarLabelSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
