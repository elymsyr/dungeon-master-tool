import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/rule_engine_v3_provider.dart';

/// Generic class resource tracker — rage_uses, channel_divinity, bardic,
/// ki points, sorcery points. Progress bar + +/- button'lar.
///
/// [resourceKey] tracker'ın hedef resource'u (entity.resources[key]).
/// [label] UI başlığı ("Rage", "Channel Divinity", "Ki Points").
class ClassResourceTracker extends ConsumerWidget {
  const ClassResourceTracker({
    required this.entityId,
    required this.resourceKey,
    required this.label,
    super.key,
  });

  final String entityId;
  final String resourceKey;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = ref.watch(entityProvider.select((m) => m[entityId]));
    if (entity == null) return const SizedBox.shrink();
    final state = entity.resources[resourceKey];
    if (state == null || state.max == 0) return const SizedBox.shrink();

    final ratio = state.max > 0 ? state.current / state.max : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            tooltip: 'Spend',
            onPressed: state.current > 0 ? () => _consume(ref) : null,
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${state.current}/${state.max}',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            tooltip: 'Restore',
            onPressed: state.current < state.max ? () => _refresh(ref) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
            ),
          ),
        ],
      ),
    );
  }

  void _consume(WidgetRef ref) {
    final entity = ref.read(entityProvider)[entityId];
    if (entity == null) return;
    final mgr = ref.read(resourceManagerProvider);
    final updated =
        mgr.tryConsume(entity: entity, resourceKey: resourceKey, amount: 1);
    if (updated != null) {
      ref.read(entityProvider.notifier).update(updated);
    }
  }

  void _refresh(WidgetRef ref) {
    final entity = ref.read(entityProvider)[entityId];
    if (entity == null) return;
    final mgr = ref.read(resourceManagerProvider);
    final updated = mgr.refresh(
      entity: entity,
      resourceKey: resourceKey,
      amount: 1,
    );
    ref.read(entityProvider.notifier).update(updated);
  }
}
