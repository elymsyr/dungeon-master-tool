import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/character_creation/origin_constants.dart';
import '../../../../../application/character_creation/weapon_mastery_resolver.dart';
import '../../../../../application/services/builtin_srd_entities.dart';
import '../../../../../domain/entities/entity.dart';
import '../../../../theme/dm_tool_colors.dart';
import 'skill_mod_helper.dart';

/// Wizard step that asks the player to spend the proficiency / language
/// "choice slots" their class and background grant, and to lock in the L1
/// class-feature choices that mutate proficiencies (Cleric Divine Order,
/// Druid Primal Order). Sub-sections appear in this order:
///
///   1. **L1 Order Choice** — Cleric Divine Order / Druid Primal Order pick.
///   2. **Weapon Proficiencies** — read-only badges (class + order pick).
///   3. **Armor Training** — read-only badges (class + order pick).
///   4. **Granted Skills / Languages** — auto-granted refs (read-only).
///   5. **Class Skills / Tools / Background Tool Variant** — interactive.
///   6. **Origin Languages** — SRD 2024 puts the +2 standard languages on
///      origin, not background; cap from [OriginConstants].
///   7. **Bonus Language** — Rogue Thieves' Cant feature grants +1 of any.
///   8. **Weapon Mastery** — Barb/Fighter/Paladin/Ranger/Rogue starting picks.
///
/// Each subsection is omitted when its cap is zero or its source entity
/// isn't selected yet.
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
    final subclassEntity = _entity(entities, draft.subclassId);

    final skillCap = _int(classEntity?.fields['skill_proficiency_choice_count']);
    final toolCap = _int(classEntity?.fields['tool_proficiency_count']);
    const languageCap = OriginConstants.standardLanguageChoiceCount;

    final skillOptionIds =
        _stringList(classEntity?.fields['skill_proficiency_options']);
    final toolOptionIds =
        _stringList(classEntity?.fields['tool_proficiency_options']);

    final grantedSkillIds = <String>{
      ..._stringList(background?.fields['granted_skill_refs']),
      ..._stringList(race?.fields['granted_skill_proficiencies']),
    };

    // Class-level granted_languages (e.g. Druid's Druidic, Rogue's Thieves'
    // Cant) — auto-applied at commit by absorbGrants but shown here so the
    // player understands what's already known before picking origin languages.
    final grantedLanguageIds = <String>{
      ..._stringList(race?.fields['granted_languages']),
      ..._stringList(classEntity?.fields['granted_languages']),
    };

    // W4: shared cached family — sorted at provider level, no re-filter
    // per build.
    final languageEntities = ref.watch(entitiesByCategoryProvider('language'));
    final standardLanguageIds = [
      for (final e in languageEntities)
        if (e.fields['tier']?.toString() == 'Standard') e.id,
    ];
    final allLanguageIds = languageEntities.map((e) => e.id).toList();

    // L1 Order choice (Cleric Divine Order / Druid Primal Order). Feats live
    // under a category name declared on the class entity; we render them as
    // a mutex picker. Selecting one writes its id to `draft.l1OrderChoiceId`.
    final orderCategoryName =
        classEntity?.fields['l1_order_feat_category']?.toString() ?? '';
    final orderFeats = orderCategoryName.isEmpty
        ? const <Entity>[]
        : _featsByCategory(entities, orderCategoryName);

    // Read-only weapon/armor badges. The class entity declares base
    // categories; the picked Order feat layers `+Martial` / `+Heavy/Medium`
    // on top via its proficiency_grant effects, which we mirror here so the
    // chips reflect the live pick.
    final orderFeatEntity = draft.l1OrderChoiceId == null
        ? null
        : entities[draft.l1OrderChoiceId];
    final weaponCategoryIds = mergeProficiencyRefs(
      base: _stringList(classEntity?.fields['weapon_proficiency_categories']),
      featEffects: orderFeatEntity?.fields['effects'],
      targetKind: 'weapon_category',
    );
    final armorCategoryIds = mergeProficiencyRefs(
      base: _stringList(classEntity?.fields['armor_training_refs']),
      featEffects: orderFeatEntity?.fields['effects'],
      targetKind: 'armor_category',
    );

    // Weapon Mastery picker — count derived from class feats with
    // `weapon_mastery_count_bonus` (Fighter L1 = 3, others = 2). Filter via
    // class's `weapon_mastery_filter` enum.
    final masteryCap = classEntity == null
        ? 0
        : resolveWeaponMasteryCountAt(
            classEntity: classEntity,
            subclassEntity: subclassEntity,
            level: draft.level,
            entities: entities,
          );
    final masteryFilter =
        classEntity?.fields['weapon_mastery_filter']?.toString() ?? '';
    final masteryWeaponIds = masteryCap > 0
        ? _weaponMasteryOptionIds(entities, masteryFilter)
        : const <String>[];

    // Soldier-style background tool variant. Active when the bg entity
    // declares `granted_tool_variant_group`; values map to tool subcategory
    // lookups (e.g. 'gaming_set' → tool category 'Gaming Set').
    final bgToolVariantGroup =
        background?.fields['granted_tool_variant_group']?.toString() ?? '';
    final bgToolVariantOptions = bgToolVariantGroup.isEmpty
        ? const <Entity>[]
        : _toolVariantsByGroup(entities, bgToolVariantGroup);

    final bonusLanguageCap = classEntity == null
        ? 0
        : _classBonusLanguageCap(classEntity);

    if (skillCap == 0 &&
        toolCap == 0 &&
        languageCap == 0 &&
        masteryCap == 0 &&
        orderFeats.isEmpty &&
        bgToolVariantOptions.isEmpty &&
        bonusLanguageCap == 0 &&
        weaponCategoryIds.isEmpty &&
        armorCategoryIds.isEmpty &&
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
        if (orderFeats.isNotEmpty)
          _OrderChoiceSection(
            categoryName: orderCategoryName,
            feats: orderFeats,
            pickedId: draft.l1OrderChoiceId,
            onPick: notifier.setL1OrderChoice,
            palette: palette,
          ),
        if (weaponCategoryIds.isNotEmpty)
          _GrantedSection(
            title: 'Weapon Proficiencies (class)',
            ids: weaponCategoryIds,
            entities: entities,
            palette: palette,
          ),
        if (armorCategoryIds.isNotEmpty)
          _GrantedSection(
            title: 'Armor Training (class)',
            ids: armorCategoryIds,
            entities: entities,
            palette: palette,
          ),
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
            title: 'Granted Languages (class / species)',
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
        if (bgToolVariantOptions.isNotEmpty)
          _SingleChoiceSection(
            title: 'Background Tool Variant',
            options: bgToolVariantOptions,
            pickedId: draft.backgroundToolVariantId,
            onPick: notifier.setBackgroundToolVariant,
            palette: palette,
          ),
        if (standardLanguageIds.isNotEmpty)
          _PickerSection(
            title: 'Origin Languages (Standard)',
            cap: languageCap,
            picked: draft.languageChoiceIds,
            optionIds: standardLanguageIds,
            entities: entities,
            disabledIds: grantedLanguageIds,
            disabledHint: 'already known',
            onToggle: (id) =>
                notifier.toggleLanguageChoice(id, cap: languageCap),
            palette: palette,
          ),
        if (bonusLanguageCap > 0)
          _PickerSection(
            title: classEntity!.name == 'Rogue'
                ? "Bonus Language (Thieves' Cant feature)"
                : 'Bonus Language',
            cap: bonusLanguageCap,
            picked: draft.bonusLanguageChoiceIds,
            optionIds: allLanguageIds,
            entities: entities,
            disabledIds: {
              ...grantedLanguageIds,
              ...draft.languageChoiceIds,
            },
            disabledHint: 'already picked',
            onToggle: (id) => notifier.toggleBonusLanguageChoice(
                id,
                cap: bonusLanguageCap),
            palette: palette,
          ),
        if (masteryCap > 0 && masteryWeaponIds.isNotEmpty)
          _PickerSection(
            title: 'Weapon Mastery',
            cap: masteryCap,
            picked: draft.weaponMasteryChoiceIds,
            optionIds: masteryWeaponIds,
            entities: entities,
            disabledIds: const {},
            disabledHint: '',
            onToggle: (id) => notifier.toggleWeaponMasteryChoice(
                id,
                cap: masteryCap),
            palette: palette,
            suffixForId: (id) {
              final ref = entities[id]?.fields['mastery_ref'];
              final masteryId = ref is Map ? ref['id']?.toString() : null;
              if (masteryId == null) return null;
              return entities[masteryId]?.name;
            },
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

  /// Merge base proficiency refs (from the class entity) with any
  /// `proficiency_grant` effects on the picked L1 Order feat. The feat
  /// effect schema is `{kind: 'proficiency_grant', target_kind: '...',
  /// target_ref: {id: 'category-id'}}` — pull `target_ref.id` when
  /// `target_kind` matches the requested category type.
  static List<String> mergeProficiencyRefs({
    required List<String> base,
    required Object? featEffects,
    required String targetKind,
  }) {
    final out = <String>[...base];
    if (featEffects is List) {
      for (final eff in featEffects) {
        if (eff is! Map) continue;
        if (eff['kind'] != 'proficiency_grant') continue;
        if (eff['target_kind'] != targetKind) continue;
        final ref = eff['target_ref'];
        final id = ref is Map ? ref['id']?.toString() : ref?.toString();
        if (id == null || id.isEmpty) continue;
        if (!out.contains(id)) out.add(id);
      }
    }
    return out;
  }

  /// Sorted feats whose `category_ref` resolves to a category entity with
  /// the given [categoryName] (e.g. 'Divine Order', 'Primal Order').
  static List<Entity> _featsByCategory(
    Map<String, Entity> entities,
    String categoryName,
  ) {
    final out = <Entity>[];
    for (final e in entities.values) {
      if (e.categorySlug != 'feat') continue;
      final ref = e.fields['category_ref'];
      final catId = ref is Map ? ref['id']?.toString() : null;
      if (catId == null) continue;
      if (entities[catId]?.name != categoryName) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// Sorted variant tools belonging to a category group (e.g. 'gaming_set'
  /// → tool category 'Gaming Set'). Excludes the base umbrella tool whose
  /// name matches the category name.
  static List<Entity> _toolVariantsByGroup(
    Map<String, Entity> entities,
    String group,
  ) {
    final categoryName = _toolCategoryNameForGroup(group);
    if (categoryName.isEmpty) return const [];
    final out = <Entity>[];
    for (final e in entities.values) {
      if (e.categorySlug != 'tool') continue;
      // Variant tools point at the base via `variant_of_ref`. The base itself
      // (e.g. 'Gaming Set') doesn't — exclude it.
      final variantRef = e.fields['variant_of_ref'];
      if (variantRef == null) continue;
      final catRef = e.fields['category_ref'];
      final catId = catRef is Map ? catRef['id']?.toString() : null;
      if (catId == null) continue;
      if (entities[catId]?.name != categoryName) continue;
      out.add(e);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  static String _toolCategoryNameForGroup(String group) {
    switch (group) {
      case 'gaming_set':
        return 'Gaming Set';
      case 'musical_instrument':
        return 'Musical Instrument';
      case 'artisans_tools':
        return "Artisan's Tools";
      default:
        return '';
    }
  }

  /// Class-granted bonus language pick count at L1. Mirrors the buildSeed
  /// helper of the same name in [character_creation_wizard_screen.dart].
  static int _classBonusLanguageCap(Entity classEntity) {
    if (classEntity.name == 'Rogue') return 1;
    return 0;
  }

  /// Sorted weapon IDs eligible for mastery picks given a class's filter.
  /// Filters supported:
  ///   - `simple_or_martial`: every Simple/Martial weapon (Fighter).
  ///   - `melee_simple_or_martial`: Simple/Martial **melee** only (Barbarian).
  ///   - `proficient_any`: same as `simple_or_martial` (Paladin/Ranger — they
  ///     have proficiency with all Simple+Martial).
  ///   - `proficient_finesse_or_light`: Simple + Martial with Finesse OR
  ///     Light property (Rogue).
  /// Unknown filter → all weapons (defensive fallback so unknown content
  /// doesn't produce an empty picker).
  static List<String> _weaponMasteryOptionIds(
    Map<String, Entity> entities,
    String filter,
  ) {
    final out = <String>[];
    for (final e in entities.values) {
      if (e.categorySlug != 'weapon') continue;
      // Mastery picks only apply to weapons that *have* a mastery property.
      if (e.fields['mastery_ref'] == null) continue;
      if (!_passesMasteryFilter(e, entities, filter)) continue;
      out.add(e.id);
    }
    out.sort((a, b) => (entities[a]?.name ?? a)
        .toLowerCase()
        .compareTo((entities[b]?.name ?? b).toLowerCase()));
    return out;
  }

  static bool _passesMasteryFilter(
    Entity weapon,
    Map<String, Entity> entities,
    String filter,
  ) {
    final isMelee = weapon.fields['is_melee'] == true;
    final categoryRef = weapon.fields['category_ref'];
    final catId = categoryRef is Map ? categoryRef['id']?.toString() : null;
    final catName = catId == null ? '' : (entities[catId]?.name ?? '');
    final isSimple = catName.startsWith('Simple');
    final isMartial = catName.startsWith('Martial');
    if (!isSimple && !isMartial) return false;

    switch (filter) {
      case 'simple_or_martial':
      case 'proficient_any':
        return true;
      case 'melee_simple_or_martial':
        return isMelee;
      case 'proficient_finesse_or_light':
        if (isSimple) return true;
        // Martial: require Finesse OR Light property.
        final props = weapon.fields['property_refs'];
        if (props is! List) return false;
        for (final p in props) {
          String? name;
          if (p is Map) {
            final pid = p['id']?.toString();
            name = pid == null ? null : entities[pid]?.name;
          } else if (p is String) {
            name = entities[p]?.name;
          }
          if (name == 'Finesse' || name == 'Light') return true;
        }
        return false;
      default:
        return true;
    }
  }
}

/// Mutex L1 order picker (Cleric Divine Order / Druid Primal Order).
class _OrderChoiceSection extends StatelessWidget {
  final String categoryName;
  final List<Entity> feats;
  final String? pickedId;
  final ValueChanged<String?> onPick;
  final DmToolColors palette;

  const _OrderChoiceSection({
    required this.categoryName,
    required this.feats,
    required this.pickedId,
    required this.onPick,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 4),
          for (final f in feats)
            RadioListTile<String?>(
              value: f.id,
              // ignore: deprecated_member_use
              groupValue: pickedId,
              // ignore: deprecated_member_use
              onChanged: onPick,
              dense: true,
              title: Text(f.name),
              subtitle: f.description.isEmpty
                  ? null
                  : Text(
                      f.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
        ],
      ),
    );
  }
}

/// Mutex single-choice picker for variant grants (e.g. background tool
/// variant). Stores `null` when unselected.
class _SingleChoiceSection extends StatelessWidget {
  final String title;
  final List<Entity> options;
  final String? pickedId;
  final ValueChanged<String?> onPick;
  final DmToolColors palette;

  const _SingleChoiceSection({
    required this.title,
    required this.options,
    required this.pickedId,
    required this.onPick,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in options)
            RadioListTile<String?>(
              value: e.id,
              // ignore: deprecated_member_use
              groupValue: pickedId,
              // ignore: deprecated_member_use
              onChanged: onPick,
              dense: true,
              title: Text(e.name),
            ),
        ],
      ),
    );
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
