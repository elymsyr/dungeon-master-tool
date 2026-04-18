import 'dart:async';

import '../../domain/entities/entity.dart';
import '../../domain/entities/events/game_event.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/event_kind.dart';
import '../../domain/entities/schema/rule_v3.dart';
import 'rule_engine_v3.dart';
import 'rule_evaluator/rule_evaluation_result_v3.dart';
import 'rule_event_mutation_applier.dart';

/// Engine'in EventKind rule'larını tetikleyen event bus.
///
/// Generic [AppEventBus] farklı — oradaki [EventEnvelope] mind-map/encounter
/// notification içindir. Buradaki [GameEvent] RuleEngineV3 entegrasyonu.
///
/// Cascade (event içinde event emit edilir; örn. onHpZero → onDeath):
/// - [maxCascadeDepth] ile sınırlı
/// - Toplam emit edilen event sayısı [maxTotalEvents] ile sınırlı
///
/// Stream caller tarafından dinlenebilir (EventLog UI, debug tracer).
class RuleEventBus {
  RuleEventBus({
    required RuleEngineV3 engine,
    required this.entityResolver,
    required this.categoryResolver,
    required this.rulesResolver,
    required this.entitySink,
    RuleEventMutationApplier? mutationApplier,
    this.maxCascadeDepth = 16,
    this.maxTotalEvents = 50,
  })  : _engine = engine,
        _applier = mutationApplier ?? RuleEventMutationApplier();

  final RuleEngineV3 _engine;
  final RuleEventMutationApplier _applier;

  /// id → current Entity.
  final Entity? Function(String id) entityResolver;

  /// slug → category schema (rule seti).
  final EntityCategorySchema? Function(String slug) categoryResolver;

  /// category → rules V3 listesi.
  final List<RuleV3> Function(EntityCategorySchema category) rulesResolver;

  /// Mutated entity yazma hook'u (repo/state update).
  final void Function(Entity updated) entitySink;

  final int maxCascadeDepth;
  final int maxTotalEvents;

  final _stream = StreamController<GameEvent>.broadcast();

  /// Kimse emit edilen event'lerin akışı (UI EventLog, debug).
  Stream<GameEvent> get events => _stream.stream;

  /// Emit edilen event'lerin FIFO log'u — test/debug/EventLog UI için.
  /// `resetTrace()` ile temizlenir; otomatik clear yok (son N event burada).
  final List<GameEvent> _lastTrace = [];
  List<GameEvent> get lastTrace => List.unmodifiable(_lastTrace);

  /// Log'u manuel temizle.
  void resetTrace() => _lastTrace.clear();

  /// Event yayınla. Cascade edilen event'ler bu metoddan geri çağırır;
  /// cascadeDepth engine tarafından artırılır.
  ///
  /// Dönüş: kök event için üretilen [RuleEvaluationResultV3]. Cascade'de
  /// üretilen sub-result'lar caller'a ulaşmaz — entitySink hook üzerinden
  /// mutation zincirlenir.
  RuleEvaluationResultV3 emit(GameEvent event) {
    // Cascade guard tek session'a özgü — public emit'te reset.
    _cascadeTotalEmitted = 0;
    return _emit(event);
  }

  int _cascadeTotalEmitted = 0;

  RuleEvaluationResultV3 _emit(GameEvent event) {
    final empty = RuleEvaluationResultV3();
    if (event.cascadeDepth >= maxCascadeDepth) return empty;
    if (_cascadeTotalEmitted >= maxTotalEvents) return empty;
    _cascadeTotalEmitted++;
    _lastTrace.add(event);
    _stream.add(event);

    final entity = entityResolver(event.sourceEntityId);
    if (entity == null) return empty;
    final category = categoryResolver(entity.categorySlug);
    if (category == null) return empty;
    final rules = rulesResolver(category);
    if (rules.isEmpty) return empty;

    // Engine evaluate the event.
    final result = _engine.evaluateEvent(
      kind: event.kind,
      entity: entity,
      category: category,
      allEntities: _collectAllEntities(entity),
      rules: rules,
      payload: event.payload,
      turnState: entity.turnState,
    );

    // Apply mutations to source entity.
    final mutated = _applier.apply(entity: entity, result: result);
    if (mutated != entity) entitySink(mutated);

    // Cascade — result'taki cascadedEvents listesinden (engine'ce doldurulur).
    for (final kind in result.cascadedEvents) {
      _emit(GameEvent(
        kind: kind,
        sourceEntityId: event.sourceEntityId,
        targetEntityId: event.targetEntityId,
        payload: event.payload,
        cascadeDepth: event.cascadeDepth + 1,
      ));
    }

    return result;
  }

  Map<String, Entity> _collectAllEntities(Entity root) {
    // Resolver-only tek-entity context yetiyor çoğu event için; full map
    // caller'da lazım ise override etsin (şimdilik yalnız root).
    return <String, Entity>{root.id: root};
  }

  /// Kısa yol — yalnız kind + payload ile emit.
  RuleEvaluationResultV3 fire(
    EventKind kind,
    String sourceEntityId, {
    String? targetEntityId,
    Map<String, dynamic> payload = const {},
  }) {
    return emit(GameEvent(
      kind: kind,
      sourceEntityId: sourceEntityId,
      targetEntityId: targetEntityId,
      payload: payload,
    ));
  }

  Future<void> dispose() async {
    await _stream.close();
  }
}
