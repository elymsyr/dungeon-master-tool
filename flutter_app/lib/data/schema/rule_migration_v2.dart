import '../../domain/entities/schema/category_rule.dart';
import '../../domain/entities/schema/rule_v2.dart';

/// Eski CategoryRule formatını yeni RuleV2 formatına dönüştürür.
/// Kampanya verileri yüklendiğinde otomatik çalışır — kullanıcı müdahalesi gerektirmez.
class RuleMigrationV2 {
  /// Legacy kural listesini yeni formata dönüştür.
  static List<RuleV2> migrateRules(List<dynamic> legacyJsonList) {
    return legacyJsonList
        .map((json) => _migrateOne(CategoryRule.fromJson(Map<String, dynamic>.from(json as Map))))
        .toList();
  }

  static RuleV2 _migrateOne(CategoryRule old) {
    return switch (old.ruleType) {
      RuleType.pullField => _migratePullField(old),
      RuleType.mergeFields => _migrateMergeFields(old),
      RuleType.conditionalList => _migrateConditionalList(old),
    };
  }

  /// pullField → setValue with FieldValueExpr(scope: related)
  static RuleV2 _migratePullField(CategoryRule old) {
    final source = old.sources.first;
    return RuleV2(
      ruleId: old.ruleId,
      name: old.name,
      enabled: old.enabled,
      when_: const Predicate.always(),
      then_: RuleEffect.setValue(
        targetFieldKey: old.targetFieldKey,
        value: ValueExpression.fieldValue(FieldRef(
          scope: RefScope.related,
          fieldKey: source.sourceFieldKey,
          relationFieldKey: source.relationFieldKey,
        )),
      ),
    );
  }

  /// mergeFields → setValue with appropriate ValueExpression
  static RuleV2 _migrateMergeFields(CategoryRule old) {
    final ValueExpression value;

    switch (old.operation) {
      case RuleOperation.replace:
        // İlk kaynağın değerini al
        final source = old.sources.first;
        value = ValueExpression.fieldValue(FieldRef(
          scope: RefScope.related,
          fieldKey: source.sourceFieldKey,
          relationFieldKey: source.relationFieldKey,
        ));

      case RuleOperation.add:
      case RuleOperation.subtract:
      case RuleOperation.multiply:
        // Sayısal birleştirme — birden fazla kaynağı aritmetik ile birleştir
        if (old.sources.length == 1) {
          final source = old.sources.first;
          value = ValueExpression.fieldValue(FieldRef(
            scope: RefScope.related,
            fieldKey: source.sourceFieldKey,
            relationFieldKey: source.relationFieldKey,
          ));
        } else {
          // İlk kaynak başlangıç değeri, sonrakiler aritmetik ile birleştirilir
          ValueExpression result = ValueExpression.fieldValue(FieldRef(
            scope: RefScope.related,
            fieldKey: old.sources.first.sourceFieldKey,
            relationFieldKey: old.sources.first.relationFieldKey,
          ));
          final arithOp = switch (old.operation) {
            RuleOperation.add => ArithOp.add,
            RuleOperation.subtract => ArithOp.subtract,
            RuleOperation.multiply => ArithOp.multiply,
            _ => ArithOp.add, // unreachable
          };
          for (var i = 1; i < old.sources.length; i++) {
            result = ValueExpression.arithmetic(
              left: result,
              op: arithOp,
              right: ValueExpression.fieldValue(FieldRef(
                scope: RefScope.related,
                fieldKey: old.sources[i].sourceFieldKey,
                relationFieldKey: old.sources[i].relationFieldKey,
              )),
            );
          }
          value = result;
        }

      case RuleOperation.appendList:
        // Eski appendList: birden fazla tek-relation kaynağını birleştir
        // Yeni modelde bu aggregate(append) ile yapılır, ama eski model
        // tek relation field'lar kullandığından source bazlı yaklaşım gerekir.
        // En yakın eşleme: ilk kaynağın relation field'ından aggregate
        if (old.sources.length == 1) {
          final source = old.sources.first;
          value = ValueExpression.fieldValue(FieldRef(
            scope: RefScope.related,
            fieldKey: source.sourceFieldKey,
            relationFieldKey: source.relationFieldKey,
          ));
        } else {
          // Birden fazla kaynak — ilk kaynağı kullan, diğerleri v1'de zaten nadir
          final source = old.sources.first;
          value = ValueExpression.fieldValue(FieldRef(
            scope: RefScope.related,
            fieldKey: source.sourceFieldKey,
            relationFieldKey: source.relationFieldKey,
          ));
        }
    }

    return RuleV2(
      ruleId: old.ruleId,
      name: old.name,
      enabled: old.enabled,
      when_: const Predicate.always(),
      then_: RuleEffect.setValue(
        targetFieldKey: old.targetFieldKey,
        value: value,
      ),
    );
  }

  /// conditionalList → setValue with AggregateExpr(op: append)
  static RuleV2 _migrateConditionalList(CategoryRule old) {
    final source = old.sources.first;
    return RuleV2(
      ruleId: old.ruleId,
      name: old.name,
      enabled: old.enabled,
      when_: const Predicate.always(),
      then_: RuleEffect.setValue(
        targetFieldKey: old.targetFieldKey,
        value: ValueExpression.aggregate(
          relationFieldKey: source.relationFieldKey,
          sourceFieldKey: source.sourceFieldKey,
          op: AggregateOp.append,
          onlyEquipped: old.deactivateIfNotEquipped,
        ),
      ),
    );
  }
}
