import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/services/builtin_srd_entities.dart';
import '../../../../../domain/entities/entity.dart';
import '../../../../../domain/services/entity_ref.dart';
import '../../../../widgets/class_level_up_table.dart';
import '../../../../widgets/expandable_markdown.dart';
import '../../../../widgets/expandable_section.dart';
import '../../../../widgets/source_badge.dart';

/// Subclass picker. Always shown when the chosen class has at least one
/// subclass entity referencing it via `parent_class_ref`. Selection is
/// stored on [CharacterDraft.subclassId]; the resolver gates feature
/// application by `granted_at_level`.
class SubclassStep extends ConsumerWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const SubclassStep({
    super.key,
    required this.draft,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (draft.classId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Pick a class first.'),
      );
    }
    final entities = ref.watch(wizardEntitiesProvider);
    // W4: filter the cached subclass list down to entries for this class.
    final allSubclasses = ref.watch(entitiesByCategoryProvider('subclass'));
    final subclasses = [
      for (final e in allSubclasses)
        if (_parentClassId(e, entities) == draft.classId) e,
    ];
    if (subclasses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No subclasses available for this class.'),
      );
    }
    // Re-sort by granted_at_level, then name (name is already alphabetical
    // from the family provider, so the stable sort preserves it).
    subclasses.sort((a, b) {
      final la = _grantedAtLevel(a);
      final lb = _grantedAtLevel(b);
      if (la != lb) return la.compareTo(lb);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Per SRD §1.5, a subclass cannot be picked before the class's
    // declared `granted_at_level`. If everything is gated, clear any
    // stale selection so the wizard's "complete" state matches.
    final minGranted = subclasses
        .map(_grantedAtLevel)
        .fold<int>(20, (acc, l) => l < acc ? l : acc);
    final allLocked = minGranted > draft.level;
    if (allLocked && draft.subclassId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.setSubclass(null);
      });
    }

    final classEntity = entities[draft.classId];
    final subclassEntity =
        draft.subclassId == null ? null : entities[draft.subclassId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allLocked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'This class chooses a subclass at level $minGranted. '
              'Bump the level on the Identity step to unlock subclass picks.',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        for (final s in subclasses)
          _SubclassRow(
            entity: s,
            grantedAtLevel: _grantedAtLevel(s),
            draftLevel: draft.level,
            selected: draft.subclassId == s.id,
            onTap: () => notifier.setSubclass(s.id),
          ),
        if (draft.subclassId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear selection'),
              onPressed: () => notifier.setSubclass(null),
            ),
          ),
        if (classEntity != null && subclassEntity != null) ...[
          const SizedBox(height: 12),
          // Collapsed by default — the 20-row table is reference detail, not a
          // decision the player makes here, so it shouldn't dominate the step.
          ExpandableSection(
            collapsedLabel: 'Show level-up table',
            expandedLabel: 'Hide level-up table',
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClassLevelUpTable(
                classEntity: classEntity,
                subclassEntity: subclassEntity,
                currentLevel: draft.level,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // `parent_class_ref` is a plain id for in-pack/built-in parents but a softRef
  // `{slug, name}` Map when the base class lives in another pack (toh/a5e
  // subclasses). Resolve both so packaged subclasses list under their class.
  static String? _parentClassId(Entity e, Map<String, Entity> entities) =>
      resolveEntityRef(e.fields['parent_class_ref'], entities);

  static int _grantedAtLevel(Entity e) {
    final v = e.fields['granted_at_level'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 1;
    return 1;
  }
}

class _SubclassRow extends StatelessWidget {
  final Entity entity;
  final int grantedAtLevel;
  final int draftLevel;
  final bool selected;
  final VoidCallback onTap;

  const _SubclassRow({
    required this.entity,
    required this.grantedAtLevel,
    required this.draftLevel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = grantedAtLevel > draftLevel;
    final lockedHint = 'Unlocks at level $grantedAtLevel';
    return RadioListTile<bool>(
      value: true,
      // ignore: deprecated_member_use
      groupValue: selected ? true : null,
      // ignore: deprecated_member_use
      onChanged: locked ? null : (_) => onTap(),
      dense: true,
      title: Row(
        children: [
          Flexible(
            child: Text(
              entity.name,
              style: locked
                  ? TextStyle(color: Theme.of(context).disabledColor)
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: SourceBadge(entity.source)),
          const Spacer(),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                lockedHint,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),
        ],
      ),
      subtitle: entity.description.isEmpty
          ? null
          : ExpandableMarkdown(
              data: entity.description,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: locked
                    ? TextStyle(color: Theme.of(context).disabledColor)
                    : null,
              ),
            ),
    );
  }
}
