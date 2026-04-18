import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/event_kind.dart';
import '../../domain/entities/schema/rule_v3.dart';
import '../../domain/entities/turn_state.dart';
import 'damage_apply_result.dart';
import 'rule_engine_v3.dart';
import 'rule_event_bus.dart';

/// D&D 5e damage uygulama pipeline'ı.
///
/// Sıra (SRD): crit → damage roll rules → vulnerability × → resistance ÷ →
/// immunity = 0 → temp HP absorb → HP reduce → onDamageTaken / onHpZero.
///
/// Immunity/resistance/vulnerability kaynakları:
/// 1. Rule engine `evaluateDamage` result'ı (grant*Effect rule'ları ekler — şu
///    an domain'de bu effect tipi yok; genişletme hook'u burada).
/// 2. Entity.fields['damage_immunities'] / ['damage_resistances'] /
///    ['damage_vulnerabilities'] list field'ları (SRD stat-block default).
class DamagePipeline {
  DamagePipeline({
    required RuleEngineV3 engine,
    RuleEventBus? eventBus,
  })  : _engine = engine,
        _bus = eventBus;

  final RuleEngineV3 _engine;
  final RuleEventBus? _bus;

  DamageApplyResult apply({
    required Entity target,
    required EntityCategorySchema category,
    required List<RuleV3> rules,
    required Map<String, Entity> allEntities,
    required int amount,
    required String damageType,
    String? attackerId,
    bool isCritical = false,
    TurnState? turnState,
  }) {
    // 1. Engine damage rules eval (grant adv/disadv saves, modify amount vb.)
    _engine.evaluateDamage(
      entity: target,
      category: category,
      allEntities: allEntities,
      rules: rules,
      direction: DamageDirection.taken,
      damageType: damageType,
      amount: amount,
      turnState: turnState,
    );

    final rawAmount = amount;

    // 2. Crit double (damage dice doubled — caller assumed to roll base once;
    //    pipeline doubles the *rolled* amount per SRD shortcut).
    int working = isCritical ? rawAmount * 2 : rawAmount;

    // 3. Resistance/immunity/vulnerability lookup (entity.fields).
    final immunities = _asStringList(target.fields['damage_immunities']);
    final resistances = _asStringList(target.fields['damage_resistances']);
    final vulnerabilities =
        _asStringList(target.fields['damage_vulnerabilities']);

    final isImmune = immunities.contains(damageType);
    final isResistant = resistances.contains(damageType);
    final isVulnerable = vulnerabilities.contains(damageType);

    // 4. Apply in SRD order: vulnerability ×2 → resistance ÷2 (floor) →
    //    immunity 0.
    if (isVulnerable) working *= 2;
    if (isResistant) working = working ~/ 2;
    final multiplied = working;
    int applied = isImmune ? 0 : working;

    // 5. Temp HP absorb.
    final combat = _safeMap(target.fields['combat_stats']);
    final tempHp = _asInt(combat['temp_hp']);
    final absorbed = applied > 0 ? (tempHp < applied ? tempHp : applied) : 0;
    applied -= absorbed;
    final newTempHp = tempHp - absorbed;

    // 6. HP reduce.
    final hp = _asInt(combat['hp']);
    final newHp = (hp - applied).clamp(0, 1 << 30);
    final hpZero = newHp == 0 && hp > 0;

    // 7. Concentration save DC (SRD: max(10, damage/2)).
    int? concSaveDc;
    if (applied > 0 && target.activeEffects.any((e) => e.requiresConcentration)) {
      concSaveDc = applied ~/ 2;
      if (concSaveDc < 10) concSaveDc = 10;
    }

    // 8. Emit events.
    if (_bus != null && applied > 0) {
      _bus.fire(
        EventKind.onDamageTaken,
        target.id,
        payload: {
          'damage_type': damageType,
          'damage_amount': applied,
          'was_critical': isCritical,
          'attacker_id': ?attackerId,
        },
      );
      if (hpZero) {
        _bus.fire(
          EventKind.onHpZero,
          target.id,
          payload: {'attacker_id': ?attackerId},
        );
      }
      if (attackerId != null) {
        _bus.fire(
          EventKind.onDamageDealt,
          attackerId,
          targetEntityId: target.id,
          payload: {
            'damage_type': damageType,
            'damage_amount': applied,
          },
        );
      }
    }

    return DamageApplyResult(
      rawAmount: rawAmount,
      multipliedAmount: multiplied,
      appliedAmount: applied,
      absorbedByTempHp: absorbed,
      newHp: newHp,
      newTempHp: newTempHp,
      hpZero: hpZero,
      damageType: damageType,
      wasImmune: isImmune,
      wasResistant: isResistant,
      wasVulnerable: isVulnerable,
      wasCritical: isCritical,
      concentrationSaveDc: concSaveDc,
    );
  }

  /// [DamageApplyResult] → Entity mutation. combat_stats.hp + .temp_hp güncelle.
  Entity applyMutation({
    required Entity target,
    required DamageApplyResult result,
  }) {
    if (result.appliedAmount == 0 && result.absorbedByTempHp == 0) return target;
    final combat = Map<String, dynamic>.from(_safeMap(target.fields['combat_stats']));
    combat['hp'] = result.newHp;
    combat['temp_hp'] = result.newTempHp;
    final fields = Map<String, dynamic>.from(target.fields);
    fields['combat_stats'] = combat;
    return target.copyWith(fields: fields);
  }

  Map<String, dynamic> _safeMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
}
