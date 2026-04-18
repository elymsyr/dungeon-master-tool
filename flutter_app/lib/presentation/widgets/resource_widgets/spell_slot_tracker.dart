import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/rule_engine_v3_provider.dart';

/// Spell slot tracker — her level için dolu/boş slot checkbox'ları.
///
/// Slot tıklaması → ResourceManager.consume/tryConsume; long rest button
/// caller tarafından (`Rest` dialog) RuleEventBus.fire(onLongRest).
class SpellSlotTracker extends ConsumerWidget {
  const SpellSlotTracker({
    required this.entityId,
    super.key,
  });

  final String entityId;

  static const _slotLevels = [1, 2, 3, 4, 5, 6, 7, 8, 9];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = ref.watch(entityProvider.select((m) => m[entityId]));
    if (entity == null) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (final level in _slotLevels) {
      final key = 'spell_slot_$level';
      final state = entity.resources[key];
      if (state == null || state.max == 0) continue;

      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                'L$level',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...List.generate(state.max, (i) {
              final filled = i < state.current;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => _toggleSlot(ref, entityId, key, i),
                  child: Icon(
                    filled
                        ? Icons.circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: filled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            Text('${state.current}/${state.max}'),
          ],
        ),
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Spell Slots',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ...rows,
      ],
    );
  }

  /// Tıklanan slot index'ine göre consume/refresh karar ver.
  /// Index < current → filled → consume (current-1)
  /// Index >= current → empty → refill by 1 (manual adjust).
  void _toggleSlot(WidgetRef ref, String entityId, String key, int index) {
    final entity = ref.read(entityProvider)[entityId];
    if (entity == null) return;
    final state = entity.resources[key];
    if (state == null) return;

    final mgr = ref.read(resourceManagerProvider);
    final updated = index < state.current
        ? mgr.tryConsume(entity: entity, resourceKey: key, amount: 1) ?? entity
        : mgr.refresh(entity: entity, resourceKey: key, amount: 1);
    ref.read(entityProvider.notifier).update(updated);
  }
}
