import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/services/builtin_srd_entities.dart';
import '../../../../../domain/entities/entity.dart';
import '../../../../../domain/services/entity_ref.dart';
import '../../../../theme/dm_tool_colors.dart';
import '../../../../widgets/expandable_markdown.dart';
import '../../../../widgets/source_badge.dart';
import 'skill_mod_helper.dart';

/// Wizard step that surfaces per-feat sub-choices.
///
/// Reads the background's `origin_feat_ref` and any feats already in
/// `draft.featIds`. For each feat, walks `effects` filtering
/// `kind == 'choice_group'` and renders a picker per payload — enum, skill+
/// tool combo, tool-category, ability, or spell-from-list.
///
/// Picks are stored in `draft.originFeatChoices` keyed `<feat_id>:<group_id>`.
/// Single-pick values are plain option ids; multi-pick values are stored as a
/// comma-joined string the wizard parses on read.
class FeatsStep extends ConsumerWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const FeatsStep({
    super.key,
    required this.draft,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // Cheap early-out without watching the full entity provider — most
    // characters have no active feat choices and the wizard rebuilds this
    // step every Stepper tick.
    final backgroundId = draft.backgroundId;
    if (backgroundId == null && draft.featIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No feats with choices yet — background grants none, and you '
          'haven\'t taken a chooseable feat.',
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    }

    final entities = ref.watch(wizardEntitiesProvider);
    final feats = _activeFeats(draft, entities);
    if (feats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No feats with choices yet — background grants none, and you '
          'haven\'t taken a chooseable feat.',
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    }

    final featGroups = <Entity, List<Map<String, dynamic>>>{};
    for (final feat in feats) {
      final groups = _readChoiceGroups(feat);
      if (groups.isNotEmpty) featGroups[feat] = groups;
    }

    if (featGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No sub-choices needed for the active feats.',
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    }

    // Materialize entity buckets once per build instead of per group. The
    // skill / tool / spell base lists are pulled from the cached family
    // provider (sorted, identity-stable until the entity map changes), so
    // the factory below only has to bucket what each feat needs — no full
    // 7 K-entry scan per render (W5).
    final cache = _FeatsCache.from(
      entities,
      featGroups.values,
      skills: ref.watch(entitiesByCategoryProvider('skill')),
      tools: ref.watch(entitiesByCategoryProvider('tool')),
      spells: ref.watch(entitiesByCategoryProvider('spell')),
      classes: ref.watch(entitiesByCategoryProvider('class')),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in featGroups.entries)
          _FeatCard(
            feat: entry.key,
            groups: entry.value,
            draft: draft,
            notifier: notifier,
            entities: entities,
            cache: cache,
            palette: palette,
          ),
      ],
    );
  }

  /// All feats whose choice payloads the wizard should resolve: the
  /// background's origin feat + every entry in `featIds`. De-duped.
  static List<Entity> _activeFeats(
    CharacterDraft draft,
    Map<String, Entity> entities,
  ) {
    final ids = <String>[];
    final bg = draft.backgroundId == null ? null : entities[draft.backgroundId];
    // Built-in backgrounds store a resolved feat id; packaged ones store a
    // softRef `{slug, name}`. Resolve both so the origin feat is offered.
    final originId = resolveEntityRef(bg?.fields['origin_feat_ref'], entities);
    if (originId != null) ids.add(originId);
    for (final id in draft.featIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    final out = <Entity>[];
    for (final id in ids) {
      final e = entities[id];
      if (e != null) out.add(e);
    }
    return out;
  }

  static List<Map<String, dynamic>> _readChoiceGroups(Entity feat) {
    final effects = feat.fields['effects'];
    if (effects is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final row in effects) {
      if (row is! Map) continue;
      if (row['kind'] != 'choice_group') continue;
      final payload = row['payload'];
      if (payload is Map) out.add(Map<String, dynamic>.from(payload));
    }
    return out;
  }
}

/// Splits the comma-joined storage value back into individual option ids.
/// Empty string → empty list (avoids `['']`).
List<String> _splitChoiceValue(String? v) {
  if (v == null || v.isEmpty) return const [];
  return v.split(',').where((s) => s.isNotEmpty).toList();
}

String _joinChoiceValue(List<String> ids) => ids.join(',');

/// Per-build entity lookup tables built from the active feats' choice
/// groups. Avoids walking `entities.values` once per chip-picker — instead
/// we scan once and bucket into the slices the renderer needs.
class _FeatsCache {
  final List<Entity> skills;
  final List<Entity> tools;
  final Map<String, List<Entity>> toolsByCategoryName;
  final Map<String, List<Entity>> spellsByClassAndLevel;

  _FeatsCache._({
    required this.skills,
    required this.tools,
    required this.toolsByCategoryName,
    required this.spellsByClassAndLevel,
  });

  factory _FeatsCache.from(
    Map<String, Entity> entities,
    Iterable<List<Map<String, dynamic>>> allGroups, {
    required List<Entity> skills,
    required List<Entity> tools,
    required List<Entity> spells,
    required List<Entity> classes,
  }) {
    // Collect requested filter axes so we only bucket what the renderer
    // actually needs — keeps the scan O(N) instead of O(N × groups).
    final toolCategoryNames = <String>{};
    final spellListNames = <String>{};
    final spellLevels = <int>{};
    var needSkillsOrTools = false;
    for (final groups in allGroups) {
      for (final g in groups) {
        switch (g['pick_kind']) {
          case 'tool_category':
            final n = g['tool_category_name']?.toString();
            if (n != null && n.isNotEmpty) toolCategoryNames.add(n);
          case 'skill_or_tool':
            needSkillsOrTools = true;
          case 'spell_from_list':
            final l = g['spell_level'];
            if (l is int) spellLevels.add(l);
        }
      }
    }
    // Resolve every enum-options spell-list pick into the corresponding
    // class name so we know which class refs to bucket. The list group
    // sits *before* its dependent spell groups in the same feat.
    for (final groups in allGroups) {
      for (final g in groups) {
        if (g['pick_kind'] != 'enum') continue;
        final options = g['options'];
        if (options is! List) continue;
        for (final o in options) {
          if (o is Map && o['id'] is String) {
            spellListNames.add(o['id'] as String);
          }
        }
      }
    }

    // Skills / tools / spells / classes already arrive sorted by name from
    // the family providers — no full entity-map scan needed.
    final scopedSkills = needSkillsOrTools ? skills : const <Entity>[];
    final scopedTools = needSkillsOrTools ? tools : const <Entity>[];

    final toolsByCat = <String, List<Entity>>{
      for (final n in toolCategoryNames) n: <Entity>[],
    };
    if (toolCategoryNames.isNotEmpty) {
      for (final e in tools) {
        final catRef = e.fields['category_ref'];
        final cat = catRef is String ? entities[catRef] : null;
        final name = cat?.name;
        if (name != null && toolsByCat.containsKey(name)) {
          toolsByCat[name]!.add(e);
        }
      }
    }

    final classIdsByName = <String, String>{};
    if (spellListNames.isNotEmpty) {
      for (final e in classes) {
        if (spellListNames.contains(e.name)) classIdsByName[e.name] = e.id;
      }
    }

    final spellsByKey = <String, List<Entity>>{};
    if (classIdsByName.isNotEmpty && spellLevels.isNotEmpty) {
      for (final e in spells) {
        final lvl = e.fields['level'];
        if (lvl is! int || !spellLevels.contains(lvl)) continue;
        // SRD spells link to classes by UUID (`class_refs`); imported packs
        // carry the bare class name in `tags` instead. Accept either so
        // packaged spells show in creation-time feat spell-list picks (Magic
        // Initiate, etc.) — mirrors the level-up path
        // (pending_choice_resolver_dialog `_featChoiceOptions`, `byRef||byTag`).
        final refs = e.fields['class_refs'];
        final refList = refs is List ? refs : const [];
        for (final entry in classIdsByName.entries) {
          final byRef = refList.contains(entry.value);
          final byTag =
              e.tags.any((t) => t.toLowerCase() == entry.key.toLowerCase());
          if (!byRef && !byTag) continue;
          spellsByKey
              .putIfAbsent('${entry.key}|$lvl', () => <Entity>[])
              .add(e);
        }
      }
    }

    return _FeatsCache._(
      skills: scopedSkills,
      tools: scopedTools,
      toolsByCategoryName: toolsByCat,
      spellsByClassAndLevel: spellsByKey,
    );
  }

  List<Entity> spellsFor(String className, int level) =>
      spellsByClassAndLevel['$className|$level'] ?? const [];
}

class _FeatCard extends StatelessWidget {
  final Entity feat;
  final List<Map<String, dynamic>> groups;
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;
  final Map<String, Entity> entities;
  final _FeatsCache cache;
  final DmToolColors palette;

  const _FeatCard({
    required this.feat,
    required this.groups,
    required this.draft,
    required this.notifier,
    required this.entities,
    required this.cache,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  feat.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(child: SourceBadge(feat.source)),
              const Spacer(),
            ],
          ),
          if (feat.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            ExpandableMarkdown(
              data: feat.description,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final group in groups)
            _ChoiceGroupSection(
              feat: feat,
              group: group,
              groups: groups,
              draft: draft,
              notifier: notifier,
              entities: entities,
              cache: cache,
              palette: palette,
            ),
        ],
      ),
    );
  }
}

class _ChoiceGroupSection extends StatelessWidget {
  final Entity feat;
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> groups;
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;
  final Map<String, Entity> entities;
  final _FeatsCache cache;
  final DmToolColors palette;

  const _ChoiceGroupSection({
    required this.feat,
    required this.group,
    required this.groups,
    required this.draft,
    required this.notifier,
    required this.entities,
    required this.cache,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final groupId = group['group_id']?.toString() ?? '';
    final label = group['label']?.toString() ?? groupId;
    final prompt = group['prompt']?.toString() ?? '';
    final pickKind = group['pick_kind']?.toString() ?? 'enum';
    final pick = (group['pick'] is int) ? group['pick'] as int : 1;
    final storageKey = '${feat.id}:$groupId';
    final current = _splitChoiceValue(draft.originFeatChoices[storageKey]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
              Text(
                pick > 1
                    ? '${current.length} / $pick'
                    : (current.isEmpty ? 'pick 1' : 'picked'),
                style: TextStyle(
                  fontSize: 11,
                  color: current.length >= pick
                      ? palette.successBtnBg
                      : palette.sidebarLabelSecondary,
                ),
              ),
            ],
          ),
          if (prompt.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              prompt,
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          _renderPicker(pickKind, pick, current, storageKey),
        ],
      ),
    );
  }

  Widget _renderPicker(
    String kind,
    int pick,
    List<String> current,
    String storageKey,
  ) {
    switch (kind) {
      case 'enum':
        final options = _readEnumOptions(group['options']);
        return _RowPicker(
          options: options,
          picked: current,
          pick: pick,
          palette: palette,
          onToggle: (id) =>
              _toggle(storageKey, current, pick, id),
        );
      case 'ability':
        final abilities = _readAbilityOptions(group['ability_options']);
        return _RowPicker(
          options: [
            for (final a in abilities) _Option(id: a, label: _abilityLabel(a)),
          ],
          picked: current,
          pick: pick,
          palette: palette,
          onToggle: (id) =>
              _toggle(storageKey, current, pick, id),
        );
      case 'tool_category':
        final catName = group['tool_category_name']?.toString() ?? '';
        final tools = cache.toolsByCategoryName[catName] ?? const <Entity>[];
        return _RowPicker(
          options: [
            for (final t in tools)
              _Option(id: t.id, label: t.name, description: t.description),
          ],
          picked: current,
          pick: pick,
          palette: palette,
          onToggle: (id) =>
              _toggle(storageKey, current, pick, id),
          emptyHint: 'No "$catName" tools in the active campaign.',
        );
      case 'skill_or_tool':
        final skills = cache.skills;
        final tools = cache.tools;
        final grantedSkills = _grantedSkillIds();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (skills.isNotEmpty) ...[
              _GroupLabel(text: 'Skills', palette: palette),
              _ChipPicker(
                options: [
                  for (final s in skills)
                    _Option(
                      id: s.id,
                      label: s.name,
                      description: s.description,
                      suffix: () {
                        final m = skillAbilityModFor(s, entities, draft);
                        return m == null ? '' : formatModifier(m);
                      }(),
                    ),
                ],
                picked: current,
                pick: pick,
                palette: palette,
                disabledIds: grantedSkills,
                disabledHint: 'proficient',
                onToggle: (id) =>
                    _toggle(storageKey, current, pick, id),
              ),
              const SizedBox(height: 6),
            ],
            if (tools.isNotEmpty) ...[
              _GroupLabel(text: 'Tools', palette: palette),
              _RowPicker(
                options: [
                  for (final t in tools)
                    _Option(
                        id: t.id, label: t.name, description: t.description),
                ],
                picked: current,
                pick: pick,
                palette: palette,
                onToggle: (id) =>
                    _toggle(storageKey, current, pick, id),
              ),
            ],
          ],
        );
      case 'spell_from_list':
        final listGroupId = group['list_group_id']?.toString() ?? '';
        final listStorageKey = '${feat.id}:$listGroupId';
        final listValue =
            _splitChoiceValue(draft.originFeatChoices[listStorageKey])
                .firstOrNull;
        if (listValue == null || listValue.isEmpty) {
          return Text(
            'Pick the spell list first.',
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
              fontStyle: FontStyle.italic,
            ),
          );
        }
        final spellLevel =
            (group['spell_level'] is int) ? group['spell_level'] as int : 0;
        final spells = cache.spellsFor(listValue, spellLevel);
        return _RowPicker(
          options: [
            for (final s in spells)
              _Option(id: s.id, label: s.name, description: s.description),
          ],
          picked: current,
          pick: pick,
          palette: palette,
          onToggle: (id) =>
              _toggle(storageKey, current, pick, id),
          emptyHint: 'No matching $listValue spells in the active campaign.',
        );
      default:
        return Text(
          'Unsupported choice kind "$kind" — choose post-creation.',
          style: TextStyle(
            fontSize: 11,
            color: palette.sidebarLabelSecondary,
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }

  /// Union of skills the draft is already proficient in via background,
  /// race, or class skill picks — surfaced as an "(proficient)" hint on
  /// the feat skill chip and prevents double-picking.
  Set<String> _grantedSkillIds() {
    final out = <String>{};
    final bg = draft.backgroundId == null ? null : entities[draft.backgroundId];
    final race = draft.raceId == null ? null : entities[draft.raceId];
    final bgRefs = bg?.fields['granted_skill_refs'];
    if (bgRefs is List) out.addAll(bgRefs.whereType<String>());
    final raceRefs = race?.fields['granted_skill_proficiencies'];
    if (raceRefs is List) out.addAll(raceRefs.whereType<String>());
    out.addAll(draft.skillChoiceIds);
    return out;
  }

  void _toggle(String storageKey, List<String> current, int pick, String id) {
    final next = [...current];
    if (next.contains(id)) {
      next.remove(id);
    } else {
      if (pick == 1) {
        next
          ..clear()
          ..add(id);
      } else {
        if (next.length >= pick) return;
        next.add(id);
      }
    }
    notifier.setOriginFeatChoice(storageKey, _joinChoiceValue(next));
  }

  List<_Option> _readEnumOptions(Object? raw) {
    if (raw is! List) return const [];
    final out = <_Option>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final id = row['id']?.toString() ?? '';
      final label = row['label']?.toString() ?? id;
      if (id.isEmpty) continue;
      out.add(_Option(id: id, label: label));
    }
    return out;
  }

  List<String> _readAbilityOptions(Object? raw) {
    if (raw is! List) return const ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
    return raw.whereType<String>().toList();
  }

  static String _abilityLabel(String code) => switch (code) {
        'STR' => 'Strength',
        'DEX' => 'Dexterity',
        'CON' => 'Constitution',
        'INT' => 'Intelligence',
        'WIS' => 'Wisdom',
        'CHA' => 'Charisma',
        _ => code,
      };

}

class _Option {
  final String id;
  final String label;
  final String description;
  final String suffix;
  const _Option({
    required this.id,
    required this.label,
    this.description = '',
    this.suffix = '',
  });
}

class _GroupLabel extends StatelessWidget {
  final String text;
  final DmToolColors palette;
  const _GroupLabel({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.sidebarLabelSecondary,
        ),
      ),
    );
  }
}

class _ChipPicker extends StatelessWidget {
  final List<_Option> options;
  final List<String> picked;
  final int pick;
  final ValueChanged<String> onToggle;
  final DmToolColors palette;
  final Set<String> disabledIds;
  final String disabledHint;

  const _ChipPicker({
    required this.options,
    required this.picked,
    required this.pick,
    required this.onToggle,
    required this.palette,
    this.disabledIds = const {},
    this.disabledHint = '',
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        'No options available.',
        style: TextStyle(
          fontSize: 11,
          color: palette.sidebarLabelSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    // W8: skip `toSet()` — `picked` is the user's selection list (cap
    // ~4). Linear `contains` on a tiny list is cheaper than allocating
    // a Set + hashing per row.
    final atCap = picked.length >= pick;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final o in options)
          _OptionChip(
            label: o.label,
            suffix: o.suffix,
            description: o.description,
            selected: picked.contains(o.id),
            disabled: disabledIds.contains(o.id) ||
                (atCap && !picked.contains(o.id)),
            disabledHint:
                disabledIds.contains(o.id) ? disabledHint : '',
            onTap: () => onToggle(o.id),
            palette: palette,
          ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final String suffix;
  final String description;
  final bool selected;
  final bool disabled;
  final String disabledHint;
  final VoidCallback onTap;
  final DmToolColors palette;

  const _OptionChip({
    required this.label,
    required this.suffix,
    required this.description,
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

    final tappable = InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: palette.chr,
      child: chip,
    );

    if (description.isEmpty) return tappable;
    return Tooltip(message: description, child: tappable);
  }
}

class _RowPicker extends StatelessWidget {
  final List<_Option> options;
  final List<String> picked;
  final int pick;
  final ValueChanged<String> onToggle;
  final DmToolColors palette;
  final String? emptyHint;

  const _RowPicker({
    required this.options,
    required this.picked,
    required this.pick,
    required this.onToggle,
    required this.palette,
    this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        emptyHint ?? 'No options available.',
        style: TextStyle(
          fontSize: 11,
          color: palette.sidebarLabelSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final atCap = picked.length >= pick;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in options)
          _OptionRow(
            label: o.label,
            description: o.description,
            selected: picked.contains(o.id),
            disabled: atCap && !picked.contains(o.id),
            onTap: () => onToggle(o.id),
            palette: palette,
          ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  final DmToolColors palette;

  const _OptionRow({
    required this.label,
    required this.description,
    required this.selected,
    required this.disabled,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: disabled
                              ? palette.sidebarLabelSecondary
                              : palette.tabActiveText,
                        ),
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

/// Pure validator the wizard calls from `_validateStep`. Returns null when
/// every active feat's choice groups are filled; otherwise a short error
/// message naming the first under-picked group.
String? validateFeatsStep(CharacterDraft draft, Map<String, Entity> entities) {
  for (final feat in FeatsStep._activeFeats(draft, entities)) {
    final groups = FeatsStep._readChoiceGroups(feat);
    for (final group in groups) {
      final groupId = group['group_id']?.toString() ?? '';
      final pick = (group['pick'] is int) ? group['pick'] as int : 1;
      final pickKind = group['pick_kind']?.toString() ?? 'enum';
      final key = '${feat.id}:$groupId';
      final current = _splitChoiceValue(draft.originFeatChoices[key]);

      // For spell-from-list groups we can't validate until the upstream
      // list pick is made — let the upstream group's error surface first.
      if (pickKind == 'spell_from_list') {
        final listGroupId = group['list_group_id']?.toString() ?? '';
        final listKey = '${feat.id}:$listGroupId';
        final listValue =
            _splitChoiceValue(draft.originFeatChoices[listKey]).firstOrNull;
        if (listValue == null || listValue.isEmpty) continue;
      }

      // Picks are upper bounds — players may leave choice groups empty and
      // come back later. Fail only when more than [pick] options are
      // selected (UI should prevent this, but defensive check stays).
      if (current.length > pick) {
        final label = group['label']?.toString() ?? groupId;
        return '${feat.name}: pick at most $pick "$label" choice(s).';
      }
    }
  }
  return null;
}

/// Aggregated deltas the wizard folds into the player entity at commit time:
/// ability bumps from origin-feat ASI picks, plus skill / tool / cantrip /
/// prepared-spell ids picked through feat choice groups.
class FeatChoiceContributions {
  final Map<String, int> abilityBumps;
  final List<String> skillIds;
  final List<String> toolIds;
  final List<String> cantripIds;
  final List<String> preparedSpellIds;

  const FeatChoiceContributions({
    required this.abilityBumps,
    required this.skillIds,
    required this.toolIds,
    required this.cantripIds,
    required this.preparedSpellIds,
  });

  bool get isEmpty =>
      abilityBumps.values.every((v) => v == 0) &&
      skillIds.isEmpty &&
      toolIds.isEmpty &&
      cantripIds.isEmpty &&
      preparedSpellIds.isEmpty;
}

/// Walk each active feat's `choice_group` effects and bucket the picks by
/// type so the wizard can apply them to the seed map at commit. Skill/tool
/// folding uses entity category to route a `skill_or_tool` pick to the
/// right bucket.
FeatChoiceContributions deriveFeatChoiceContributions(
  CharacterDraft draft,
  Map<String, Entity> entities,
) {
  final abilityBumps = <String, int>{
    'STR': 0,
    'DEX': 0,
    'CON': 0,
    'INT': 0,
    'WIS': 0,
    'CHA': 0,
  };
  final skillIds = <String>[];
  final toolIds = <String>[];
  final cantripIds = <String>[];
  final preparedSpellIds = <String>[];

  for (final feat in FeatsStep._activeFeats(draft, entities)) {
    final groups = FeatsStep._readChoiceGroups(feat);
    for (final group in groups) {
      final groupId = group['group_id']?.toString() ?? '';
      final pickKind = group['pick_kind']?.toString() ?? 'enum';
      final key = '${feat.id}:$groupId';
      final ids = _splitChoiceValue(draft.originFeatChoices[key]);
      if (ids.isEmpty) continue;

      switch (pickKind) {
        case 'ability':
          final code = ids.first;
          if (abilityBumps.containsKey(code)) {
            abilityBumps[code] = (abilityBumps[code] ?? 0) + 1;
          }
        case 'tool_category':
          for (final id in ids) {
            if (entities[id]?.categorySlug == 'tool' &&
                !toolIds.contains(id)) {
              toolIds.add(id);
            }
          }
        case 'skill_or_tool':
          for (final id in ids) {
            final slug = entities[id]?.categorySlug;
            if (slug == 'skill' && !skillIds.contains(id)) {
              skillIds.add(id);
            } else if (slug == 'tool' && !toolIds.contains(id)) {
              toolIds.add(id);
            }
          }
        case 'spell_from_list':
          final lvl = group['spell_level'];
          for (final id in ids) {
            if (entities[id]?.categorySlug != 'spell') continue;
            if (lvl == 0) {
              if (!cantripIds.contains(id)) cantripIds.add(id);
            } else {
              if (!preparedSpellIds.contains(id)) preparedSpellIds.add(id);
            }
          }
      }
    }
  }

  return FeatChoiceContributions(
    abilityBumps: abilityBumps,
    skillIds: skillIds,
    toolIds: toolIds,
    cantripIds: cantripIds,
    preparedSpellIds: preparedSpellIds,
  );
}
