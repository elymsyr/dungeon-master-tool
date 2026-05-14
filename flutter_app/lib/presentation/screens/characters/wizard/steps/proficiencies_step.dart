import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/services/builtin_srd_entities.dart';
import '../../../../../domain/entities/entity.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'skill_mod_helper.dart';

/// Wizard step that asks the player to spend the proficiency / language
/// "choice slots" their class and background grant:
///
///   * Class skill picks   — `skill_proficiency_choice_count`/`_options`
///   * Class tool picks    — `tool_proficiency_count`/`_options`
///   * Background languages — `granted_language_count` (free pick from the
///                            active campaign's `language` lookups)
///
/// Each subsection is omitted when its cap is zero (or its source entity
/// isn't selected yet). The auto-granted proficiencies from background
/// (`granted_skill_refs`) and species are shown read-only at the top so the
/// player understands what is already covered before spending choices.
class ProficienciesStep extends ConsumerWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const ProficienciesStep({
    super.key,
    required this.draft,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final entities = ref.watch(wizardEntitiesProvider);

    final classEntity = _entity(entities, draft.classId);
    final background = _entity(entities, draft.backgroundId);
    final race = _entity(entities, draft.raceId);

    final skillCap = _int(classEntity?.fields['skill_proficiency_choice_count']);
    final toolCap = _int(classEntity?.fields['tool_proficiency_count']);
    final languageCap = _int(background?.fields['granted_language_count']);

    final skillOptionIds =
        _stringList(classEntity?.fields['skill_proficiency_options']);
    final toolOptionIds =
        _stringList(classEntity?.fields['tool_proficiency_options']);

    final grantedSkillIds = <String>{
      ..._stringList(background?.fields['granted_skill_refs']),
      ..._stringList(race?.fields['granted_skill_proficiencies']),
    };
    final grantedLanguageIds = {
      ..._stringList(race?.fields['granted_languages']),
    };

    // W4: shared cached family — sorted at provider level, no re-filter
    // per build.
    final languageEntities = ref.watch(entitiesByCategoryProvider('language'));

    if (skillCap == 0 &&
        toolCap == 0 &&
        languageCap == 0 &&
        grantedSkillIds.isEmpty &&
        grantedLanguageIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No proficiency or language choices for this class + background.',
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    }

    String? skillSuffix(String id) {
      final e = entities[id];
      if (e == null) return null;
      final mod = skillAbilityModFor(e, entities, draft);
      return mod == null ? null : formatModifier(mod);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (grantedSkillIds.isNotEmpty)
          _GrantedSection(
            title: 'Granted Skills (background / species)',
            ids: grantedSkillIds,
            entities: entities,
            palette: palette,
            suffixForId: skillSuffix,
          ),
        if (grantedLanguageIds.isNotEmpty)
          _GrantedSection(
            title: 'Granted Languages (species)',
            ids: grantedLanguageIds,
            entities: entities,
            palette: palette,
          ),
        if (skillCap > 0)
          _PickerSection(
            title: 'Class Skills',
            cap: skillCap,
            picked: draft.skillChoiceIds,
            optionIds: skillOptionIds,
            entities: entities,
            disabledIds: grantedSkillIds,
            disabledHint: 'already granted',
            onToggle: (id) =>
                notifier.toggleSkillChoice(id, cap: skillCap),
            palette: palette,
            suffixForId: skillSuffix,
          ),
        if (toolCap > 0)
          _PickerSection(
            title: 'Class Tools',
            cap: toolCap,
            picked: draft.toolChoiceIds,
            optionIds: toolOptionIds,
            entities: entities,
            disabledIds: const {},
            disabledHint: '',
            onToggle: (id) => notifier.toggleToolChoice(id, cap: toolCap),
            palette: palette,
          ),
        if (languageCap > 0)
          _PickerSection(
            title: 'Background Languages',
            cap: languageCap,
            picked: draft.languageChoiceIds,
            optionIds: languageEntities.map((e) => e.id).toList(),
            entities: entities,
            disabledIds: grantedLanguageIds,
            disabledHint: 'already known',
            onToggle: (id) =>
                notifier.toggleLanguageChoice(id, cap: languageCap),
            palette: palette,
          ),
      ],
    );
  }

  static Entity? _entity(Map<String, Entity> map, String? id) {
    if (id == null || id.isEmpty) return null;
    return map[id];
  }

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static List<String> _stringList(Object? v) {
    if (v is! List) return const [];
    return v.whereType<String>().toList();
  }
}

class _GrantedSection extends StatelessWidget {
  final String title;
  final Iterable<String> ids;
  final Map<String, Entity> entities;
  final DmToolColors palette;
  final String? Function(String id)? suffixForId;

  const _GrantedSection({
    required this.title,
    required this.ids,
    required this.entities,
    required this.palette,
    this.suffixForId,
  });

  @override
  Widget build(BuildContext context) {
    final rows = ids
        .map((id) => (id: id, name: entities[id]?.name ?? id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final r in rows)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.featureCardBg,
                    borderRadius: palette.chr,
                    border: Border.all(color: palette.featureCardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.tabActiveText,
                        ),
                      ),
                      if (suffixForId?.call(r.id) case final s?
                          when s.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: palette.sidebarLabelSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerSection extends StatelessWidget {
  final String title;
  final int cap;
  final List<String> picked;
  final List<String> optionIds;
  final Map<String, Entity> entities;
  final Set<String> disabledIds;
  final String disabledHint;
  final ValueChanged<String> onToggle;
  final DmToolColors palette;
  final String? Function(String id)? suffixForId;

  const _PickerSection({
    required this.title,
    required this.cap,
    required this.picked,
    required this.optionIds,
    required this.entities,
    required this.disabledIds,
    required this.disabledHint,
    required this.onToggle,
    required this.palette,
    this.suffixForId,
  });

  @override
  Widget build(BuildContext context) {
    final pickedSet = picked.toSet();
    final pickedCount = pickedSet.length;
    final atCap = pickedCount >= cap;
    final remaining = cap - pickedCount;

    final sortedOptions = [...optionIds]..sort((a, b) {
        final na = entities[a]?.name.toLowerCase() ?? a;
        final nb = entities[b]?.name.toLowerCase() ?? b;
        return na.compareTo(nb);
      });

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
          if (sortedOptions.isEmpty)
            Text(
              'No options defined for this entity in the active campaign.',
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final id in sortedOptions)
                  _OptionChip(
                    label: entities[id]?.name ?? id,
                    suffix: suffixForId?.call(id) ?? '',
                    selected: pickedSet.contains(id),
                    disabled: disabledIds.contains(id) ||
                        (atCap && !pickedSet.contains(id)),
                    disabledHint:
                        disabledIds.contains(id) ? disabledHint : '',
                    onTap: () => onToggle(id),
                    palette: palette,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final String suffix;
  final bool selected;
  final bool disabled;
  final String disabledHint;
  final VoidCallback onTap;
  final DmToolColors palette;

  const _OptionChip({
    required this.label,
    required this.suffix,
    required this.selected,
    required this.disabled,
    required this.disabledHint,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? palette.featureCardAccent
        : palette.featureCardBg;
    final fg = disabled
        ? palette.sidebarLabelSecondary
        : selected
            ? palette.canvasBg
            : palette.tabActiveText;
    final border = selected
        ? palette.featureCardAccent
        : palette.featureCardBorder;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: palette.chr,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.check, size: 12, color: fg),
            ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: fg),
          ),
          if (suffix.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                suffix,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          if (disabled && disabledHint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '($disabledHint)',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: fg,
                ),
              ),
            ),
        ],
      ),
    );

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: palette.chr,
      child: chip,
    );
  }
}
