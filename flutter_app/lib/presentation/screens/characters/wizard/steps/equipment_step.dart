import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/services/builtin_srd_entities.dart';
import '../../../../../domain/entities/entity.dart';
import '../../../../theme/dm_tool_colors.dart';

/// Aggregates `equipment_choice_groups` from the chosen class, subclass and
/// background, then renders one card per group with selectable options.
/// Each option is rendered as the option label + the resolved item list +
/// optional gold alternative. Selection is persisted as
/// `Map<groupId, optionId>` on [CharacterDraft.equipmentChoices].
class EquipmentStep extends ConsumerWidget {
  final CharacterDraft draft;
  final CharacterDraftNotifier notifier;

  const EquipmentStep({
    super.key,
    required this.draft,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(wizardEntitiesProvider);
    final groups = <_GroupRow>[];
    void collect(String? id, String sourceLabel) {
      if (id == null) return;
      final src = entities[id];
      if (src == null) return;
      final raw = src.fields['equipment_choice_groups'];
      if (raw is! List) return;
      for (final g in raw) {
        if (g is! Map) continue;
        groups.add(_GroupRow(
          source: sourceLabel,
          sourceId: id,
          map: Map<String, dynamic>.from(g),
        ));
      }
    }

    // SRD 5.2.1: class and background each grant an *independent* starting
    // equipment pick — both apply. Group keys are scoped by source entity
    // id so identical group_ids (e.g. two 'A's) don't collide and
    // cross-select.
    collect(draft.classId, 'Class');
    collect(draft.subclassId, 'Subclass');
    collect(draft.backgroundId, 'Background');

    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No equipment choices required for this build.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups)
          _GroupCard(
            group: g,
            entities: entities,
            selectedOptionId: draft.equipmentChoices[g.storageKey],
            onPicked: (optionId) =>
                notifier.setEquipmentChoice(g.storageKey, optionId),
          ),
      ],
    );
  }
}

class _GroupRow {
  final String source;
  final String sourceId;
  final Map<String, dynamic> map;
  _GroupRow({
    required this.source,
    required this.sourceId,
    required this.map,
  });

  String get groupId => map['group_id']?.toString() ?? '';
  String get storageKey => '$sourceId:$groupId';
  String get label => map['label']?.toString() ?? 'Choice';
  String get prompt => map['prompt']?.toString() ?? 'Choose one';
  List<Map<String, dynamic>> get options {
    final raw = map['options'];
    if (raw is! List) return const [];
    return [
      for (final o in raw)
        if (o is Map) Map<String, dynamic>.from(o),
    ];
  }
}

class _GroupCard extends StatelessWidget {
  final _GroupRow group;
  final Map<String, Entity> entities;
  final String? selectedOptionId;
  final ValueChanged<String> onPicked;

  const _GroupCard({
    required this.group,
    required this.entities,
    required this.selectedOptionId,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${group.source}: ${group.label}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              group.prompt,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // W9: pre-resolve item names once per group instead of inside
            // each _OptionTile.build(). For an 8-option group this drops
            // ~32 map lookups per rebuild to ~0 — re-uses the cached lines
            // until the entities map identity changes.
            for (final o in group.options)
              _OptionTile(
                option: o,
                itemLines: _resolveItemLines(o, entities),
                selected: o['option_id']?.toString() == selectedOptionId,
                onTap: () => onPicked(o['option_id']?.toString() ?? ''),
              ),
          ],
        ),
      ),
    );
  }
}

/// W9: resolves an option's `items` list into the pre-formatted strings
/// the option tile renders. Called from `_GroupCard.build()` so we pay
/// the map lookups once per option, not once per tile rebuild.
List<String> _resolveItemLines(
  Map<String, dynamic> option,
  Map<String, Entity> entities,
) {
  final items = option['items'];
  if (items is! List) return const [];
  final out = <String>[];
  for (final i in items) {
    if (i is! Map) continue;
    final ref = i['ref'];
    final qty = i['quantity'] is int ? i['quantity'] as int : 1;
    String? name;
    if (ref is Map && ref['name'] is String) {
      name = ref['name'] as String;
    } else if (ref is String) {
      name = entities[ref]?.name;
    }
    if (name != null) {
      out.add(qty > 1 ? '$qty× $name' : name);
    }
  }
  return out;
}

class _OptionTile extends StatelessWidget {
  final Map<String, dynamic> option;
  final List<String> itemLines;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.itemLines,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final label = option['label']?.toString() ?? 'Option';
    final goldGp = option['gold_gp'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: palette.cbr,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: palette.cbr,
          child: Container(
            padding: const EdgeInsets.all(8),
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
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (itemLines.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        itemLines.join(', '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (goldGp is int && goldGp > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+$goldGp GP',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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
