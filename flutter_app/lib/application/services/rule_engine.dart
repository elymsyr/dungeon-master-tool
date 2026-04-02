import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/category_rule.dart';
import '../../domain/entities/schema/entity_category_schema.dart';

/// Kural motoru — entity field değerlerini template kurallarına göre hesaplar.
class RuleEngine {
  /// Kuralları uygulayıp computed değerleri döndürür.
  /// Key: targetFieldKey, Value: hesaplanan değer
  static Map<String, dynamic> applyRules({
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
  }) {
    final computed = <String, dynamic>{};

    for (final rule in category.rules) {
      if (!rule.enabled) continue;

      switch (rule.ruleType) {
        case RuleType.pullField:
          final result = _pullField(entity, rule, allEntities);
          if (result != null) computed[rule.targetFieldKey] = result;

        case RuleType.mergeFields:
          computed[rule.targetFieldKey] = _mergeFields(entity, rule, allEntities);

        case RuleType.conditionalList:
          computed[rule.targetFieldKey] = _conditionalList(entity, rule, allEntities);
      }
    }

    return computed;
  }

  /// Tek kaynaktan tek değer çek.
  static dynamic _pullField(Entity entity, CategoryRule rule, Map<String, Entity> all) {
    if (rule.sources.isEmpty) return null;
    final source = rule.sources.first;
    final relatedEntity = _getRelatedEntity(entity, source.relationFieldKey, all);
    if (relatedEntity == null) return null;
    return relatedEntity.fields[source.sourceFieldKey];
  }

  /// Birden fazla kaynaktan birleştir.
  static dynamic _mergeFields(Entity entity, CategoryRule rule, Map<String, Entity> all) {
    switch (rule.operation) {
      case RuleOperation.add:
      case RuleOperation.subtract:
      case RuleOperation.multiply:
        // Sayısal birleştirme
        double result = 0;
        bool first = true;
        for (final source in rule.sources) {
          final related = _getRelatedEntity(entity, source.relationFieldKey, all);
          if (related == null) continue;
          final val = _toDouble(related.fields[source.sourceFieldKey]);
          if (first) {
            result = val;
            first = false;
          } else {
            switch (rule.operation) {
              case RuleOperation.add:
                result += val;
              case RuleOperation.subtract:
                result -= val;
              case RuleOperation.multiply:
                result *= val;
              default:
                break;
            }
          }
        }
        return result == result.roundToDouble() ? result.toInt() : result;

      case RuleOperation.appendList:
        // Liste birleştirme
        final merged = <dynamic>[];
        for (final source in rule.sources) {
          final related = _getRelatedEntity(entity, source.relationFieldKey, all);
          if (related == null) continue;
          final val = related.fields[source.sourceFieldKey];
          if (val is List) {
            merged.addAll(val);
          } else if (val != null) {
            merged.add(val);
          }
        }
        return merged;

      case RuleOperation.replace:
        // İlk kaynak değerini al
        if (rule.sources.isEmpty) return null;
        final source = rule.sources.first;
        final related = _getRelatedEntity(entity, source.relationFieldKey, all);
        return related?.fields[source.sourceFieldKey];
    }
  }

  /// Liste öğelerini topla, koşula göre active/inactive.
  /// conditionFieldKey varsa: relation list'teki her entity'nin bu field'ına bakılır.
  /// conditionFieldKey yoksa ama equip bilgisi varsa: [{id, equipped}] formatından equipped kontrol edilir.
  /// Döndürülen format: [{value: ..., active: bool, from: entityName}, ...]
  static List<Map<String, dynamic>> _conditionalList(
      Entity entity, CategoryRule rule, Map<String, Entity> all) {
    // Hedef field'daki mevcut değerleri oku — kullanıcı toggle'larını korumak için
    final existingItems = <String, bool>{};
    final targetValue = entity.fields[rule.targetFieldKey];
    if (targetValue is List) {
      for (final item in targetValue) {
        if (item is Map) {
          existingItems[item['id']?.toString() ?? ''] = item['equipped'] == true;
        }
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final source in rule.sources) {
      final relValue = entity.fields[source.relationFieldKey];

      final entries = <_ListEntry>[];
      if (relValue is List) {
        for (final item in relValue) {
          if (item is Map) {
            entries.add(_ListEntry(item['id']?.toString() ?? '', item['equipped'] == true));
          } else if (item is String) {
            entries.add(_ListEntry(item, true));
          }
        }
      }

      for (final entry in entries) {
        final related = all[entry.id];
        if (related == null) continue;

        // Kaynak equipped değilse → deactivate (override edemez)
        final sourceActive = rule.deactivateIfNotEquipped ? entry.equipped : true;

        final sourceValue = related.fields[source.sourceFieldKey];
        if (sourceValue is List) {
          for (final item in sourceValue) {
            final itemId = item is Map ? item['id']?.toString() : item?.toString();
            if (itemId != null && itemId.isNotEmpty) {
              // Kaynak active değilse → forced inactive
              // Kaynak active ise → kullanıcının mevcut toggle'ını koru, yoksa true
              final equipped = sourceActive ? (existingItems[itemId] ?? true) : false;
              result.add({'id': itemId, 'equipped': equipped, 'from': related.name, '_sourceActive': sourceActive});
            }
          }
        } else if (sourceValue is String && sourceValue.isNotEmpty) {
          final equipped = sourceActive ? (existingItems[sourceValue] ?? true) : false;
          result.add({'id': sourceValue, 'equipped': equipped, 'from': related.name, '_sourceActive': sourceActive});
        }
      }
    }

    return result;
  }

  /// Relation field'ından ilişkili entity'yi al.
  static Entity? _getRelatedEntity(Entity entity, String relationFieldKey, Map<String, Entity> all) {
    final relValue = entity.fields[relationFieldKey];
    if (relValue is String && relValue.isNotEmpty) {
      return all[relValue];
    }
    return null;
  }

  static double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0;
    return 0;
  }
}

class _ListEntry {
  final String id;
  final bool equipped;
  _ListEntry(this.id, this.equipped);
}
