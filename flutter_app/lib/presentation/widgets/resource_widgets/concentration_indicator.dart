import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/rule_engine_v3_provider.dart';

/// Concentration indicator — concentration effect aktif mi, hangi spell,
/// X ile drop.
class ConcentrationIndicator extends ConsumerWidget {
  const ConcentrationIndicator({
    required this.entityId,
    super.key,
  });

  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = ref.watch(entityProvider.select((m) => m[entityId]));
    if (entity == null) return const SizedBox.shrink();

    final mgr = ref.read(resourceManagerProvider);
    final isConc = mgr.isConcentrating(entity);
    if (!isConc) return const SizedBox.shrink();

    final concEffect = entity.activeEffects.firstWhere(
      (e) => e.requiresConcentration,
      orElse: () => entity.activeEffects.first,
    );

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.blur_circular, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Concentrating: ${concEffect.sourceId.isNotEmpty ? concEffect.sourceId : concEffect.effectId}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Drop concentration',
              onPressed: () => _drop(ref),
            ),
          ],
        ),
      ),
    );
  }

  void _drop(WidgetRef ref) {
    final entity = ref.read(entityProvider)[entityId];
    if (entity == null) return;
    final mgr = ref.read(resourceManagerProvider);
    ref.read(entityProvider.notifier).update(mgr.breakConcentration(entity));
  }
}
