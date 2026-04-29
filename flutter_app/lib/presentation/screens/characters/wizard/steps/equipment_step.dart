import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../application/character_creation/character_draft_notifier.dart';
import '../../../../../application/providers/entity_provider.dart';
import '../../../../../domain/entities/entity.dart';

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
    final entities = ref.watch(entityProvider);
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
          map: Map<String, dynamic>.from(g),
        ));
      }
    }

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
            selectedOptionId: draft.equipmentChoices[g.groupId],
            onPicked: (optionId) =>
                notifier.setEquipmentChoice(g.groupId, optionId),
          ),
      ],
    );
  }
}

class _GroupRow {
  final String source;
  final Map<String, dynamic> map;
  _GroupRow({required this.source, required this.map});

  String get groupId => map['group_id']?.toString() ?? '';
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
            for (final o in group.options)
              _OptionTile(
                option: o,
                entities: entities,
                selected: o['option_id']?.toString() == selectedOptionId,
                onTap: () => onPicked(o['option_id']?.toString() ?? ''),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final Map<String, dynamic> option;
  final Map<String, Entity> entities;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.entities,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = option['label']?.toString() ?? 'Option';
    final goldGp = option['gold_gp'];
    final items = option['items'];
    final itemLines = <String>[];
    if (items is List) {
      for (final i in items) {
        if (i is! Map) continue;
        final ref = i['ref'];
        final qty = i['quantity'] is int ? i['quantity'] as int : 1;
        final name = _refName(ref);
        if (name != null) {
          itemLines.add(qty > 1 ? '$qty× $name' : name);
        }
      }
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
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
    );
  }

  String? _refName(Object? ref) {
    if (ref is Map && ref['name'] is String) return ref['name'] as String;
    if (ref is String) {
      final e = entities[ref];
      if (e != null) return e.name;
    }
    return null;
  }
}
