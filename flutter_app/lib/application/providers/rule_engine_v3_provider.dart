import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/choice_manager.dart';
import '../services/dice_roller.dart';
import '../services/resource_manager.dart';
import '../services/rule_engine_v3.dart';
import '../services/rule_event_bus.dart';
import '../services/rule_event_mutation_applier.dart';
import '../services/rule_v2_to_v3_adapter.dart';
import '../services/turn_manager.dart';
import '../services/rule_evaluator/rule_evaluation_result_v3.dart';
import '../../domain/entities/schema/rule_v3.dart';
import 'entity_provider.dart';

/// Global DiceRoller — DefaultDiceRoller. Test tarafında override.
final diceRollerProvider = Provider<DiceRoller>((ref) => DefaultDiceRoller());

/// Global RuleEngineV3 singleton.
final ruleEngineV3Provider = Provider<RuleEngineV3>((ref) {
  return RuleEngineV3(diceRoller: ref.watch(diceRollerProvider));
});

/// Tek bir entity için V3 reactive evaluation. V2 rule'ları adapter üstünden
/// V3 rule'lara upgrade eder — transition sürecinde paralel çalışır.
final entityEvaluationV3Provider =
    Provider.family<RuleEvaluationResultV3, String>(
  dependencies: [entityProvider, worldSchemaProvider],
  (ref, entityId) {
    final entity = ref.watch(entityProvider.select((m) => m[entityId]));
    if (entity == null) return RuleEvaluationResultV3();

    final schema = ref.watch(worldSchemaProvider);
    final cat = schema.categories
        .where((c) => c.slug == entity.categorySlug)
        .firstOrNull;
    if (cat == null) return RuleEvaluationResultV3();

    // V2 rules → V3 rules (adapter) — Faz 6 geçiş. Native V3 rule seti
    // category.rules yanına `rulesV3` alanı geldiğinde buradan değişir.
    final v3Rules = <RuleV3>[
      ...RuleV2ToV3Adapter.upgradeAll(cat.rules),
    ];

    final engine = ref.watch(ruleEngineV3Provider);
    return engine.evaluateReactive(
      entity: entity,
      category: cat,
      allEntities: ref.read(entityProvider),
      rules: v3Rules,
      turnState: entity.turnState,
    );
  },
);

/// RuleEventBus — engine + campaign entity state ile bağlı.
///
/// `entityResolver` / `entitySink` entity_provider ile entegre. Emit edilen
/// event'in mutation'ı provider state'ine yazar; Riverpod diğer tüketicileri
/// otomatik rebuild eder.
final ruleEventBusProvider = Provider<RuleEventBus>((ref) {
  final engine = ref.watch(ruleEngineV3Provider);
  return RuleEventBus(
    engine: engine,
    entityResolver: (id) => ref.read(entityProvider)[id],
    categoryResolver: (slug) {
      final schema = ref.read(worldSchemaProvider);
      for (final c in schema.categories) {
        if (c.slug == slug) return c;
      }
      return null;
    },
    rulesResolver: (cat) => RuleV2ToV3Adapter.upgradeAll(cat.rules),
    entitySink: (updated) {
      ref.read(entityProvider.notifier).update(updated);
    },
    mutationApplier: RuleEventMutationApplier(),
  );
});

// ── Managers ─────────────────────────────────────────────────────────────

final resourceManagerProvider =
    Provider<ResourceManager>((ref) => const ResourceManager());

final choiceManagerProvider =
    Provider<ChoiceManager>((ref) => const ChoiceManager());

final turnManagerProvider =
    Provider<TurnManager>((ref) => const TurnManager());
