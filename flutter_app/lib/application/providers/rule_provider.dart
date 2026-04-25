import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/rule_engine_v2.dart';
import 'entity_provider.dart';

/// Tek bir entity için reaktif kural değerlendirmesi.
///
/// Bu entity'nin kendisini, ilişkili entity'lerini ve worldSchema'yı izler.
/// Herhangi biri değiştiğinde otomatik yeniden hesaplar.
/// Statik cache yok — Riverpod'un kendi memoization'ı yeterli.
final computedFieldsProvider = Provider.family<RuleEvaluationResult, String>(
    dependencies: [entityProvider, worldSchemaProvider], (ref, entityId) {
  // 1. Entity'yi izle
  final entity = ref.watch(entityProvider.select((m) => m[entityId]));
  if (entity == null) return RuleEvaluationResult.empty;

  // 2. Schema'yı izle — template güncellemelerini yakalar
  final schema = ref.watch(worldSchemaProvider);
  final cat = schema.categories
      .where((c) => c.slug == entity.categorySlug)
      .firstOrNull;
  if (cat == null || cat.rules.isEmpty) return RuleEvaluationResult.empty;

  // 3. Bağımlı entity ID'lerini topla
  final depIds = RuleEngineV2.collectDependencyIds(entity, cat);

  // 4. Bağımlı entity'leri izle — sadece ilgili olanlar.
  //    Map yerine kombine hash int döndür: Map.== identity → her seferinde
  //    farklı eşit ⇒ gereksiz rebuild. int eşitliği O(1), unrelated entity
  //    update'lerinde rule re-eval'i iptal eder.
  if (depIds.isNotEmpty) {
    ref.watch(entityProvider.select((m) {
      var h = 0;
      for (final id in depIds) {
        h = Object.hash(h, m[id]?.hashCode);
      }
      return h;
    }));
  }

  // 5. Değerlendir
  return RuleEngineV2.evaluate(
    entity: entity,
    category: cat,
    allEntities: ref.read(entityProvider),
  );
});
