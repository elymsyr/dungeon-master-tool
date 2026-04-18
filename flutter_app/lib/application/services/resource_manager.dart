import '../../domain/entities/entity.dart';
import '../../domain/entities/resource_state.dart';
import '../../domain/entities/schema/event_kind.dart';

/// Resource pool yönetimi — spell slots, hit dice, rage uses,
/// bardic inspiration, channel divinity, charges, concentration, attunement.
///
/// Manager stateless — Entity al, mutated Entity döndür. Engine-only
/// mutation değil, direct UI action'lar (spend slot button, rest dialog)
/// bu API'yı kullanır. Engine-taraflı aynı logic RuleEventMutationApplier
/// içinde çalışır; iki yol da ResourceState'i aynı kurala göre günceller.
class ResourceManager {
  const ResourceManager();

  /// Tüket (current -= amount). Yetersizse [InsufficientResourceException].
  ///
  /// Resource mevcut değilse [ResourceNotInitializedException].
  Entity consume({
    required Entity entity,
    required String resourceKey,
    required int amount,
  }) {
    final state = entity.resources[resourceKey];
    if (state == null) {
      throw ResourceNotInitializedException(resourceKey);
    }
    if (state.current < amount) {
      throw InsufficientResourceException(
        resourceKey: resourceKey,
        available: state.current,
        requested: amount,
      );
    }
    return _update(
      entity,
      resourceKey,
      state.copyWith(current: state.current - amount),
    );
  }

  /// Güvenli consume — yetersizlikte [Entity] değiştirmeden null döner.
  Entity? tryConsume({
    required Entity entity,
    required String resourceKey,
    required int amount,
  }) {
    final state = entity.resources[resourceKey];
    if (state == null || state.current < amount) return null;
    return _update(
      entity,
      resourceKey,
      state.copyWith(current: state.current - amount),
    );
  }

  /// Yenile. [amount]=null & [fraction]=null → full refill.
  /// [fraction] = 0.5 → max*0.5 ceil() kadar ekle (hit dice on long rest).
  /// [amount] = X → X kadar ekle (Arcane Recovery gibi).
  Entity refresh({
    required Entity entity,
    required String resourceKey,
    int? amount,
    double? fraction,
  }) {
    final state = entity.resources[resourceKey];
    if (state == null) return entity;
    final int newCurrent;
    if (fraction != null) {
      final add = (state.max * fraction).ceil();
      newCurrent = (state.current + add).clamp(0, state.max);
    } else if (amount != null) {
      newCurrent = (state.current + amount).clamp(0, state.max);
    } else {
      newCurrent = state.max;
    }
    return _update(
      entity,
      resourceKey,
      state.copyWith(current: newCurrent),
    );
  }

  /// Tavanı ayarla + refresh kuralını set et. Current > newMax ise clamp.
  /// Resource henüz yoksa oluştur (current = newMax, yeni oluşturmada full).
  Entity setMax({
    required Entity entity,
    required String resourceKey,
    required int newMax,
    RefreshRule? refreshRule,
  }) {
    final existing = entity.resources[resourceKey];
    final state = existing ??
        ResourceState(
          resourceKey: resourceKey,
          current: newMax,
          max: newMax,
        );
    final clampedCurrent = existing == null
        ? newMax
        : state.current.clamp(0, newMax);
    return _update(
      entity,
      resourceKey,
      state.copyWith(
        max: newMax,
        current: clampedCurrent,
        refreshRule: refreshRule ?? state.refreshRule,
      ),
    );
  }

  /// [RefreshRule] eşleşen tüm resource'ları yenile. Short/long rest flow için.
  /// Hit dice special-case: long rest'te yarı (RAW), tam değil.
  Entity refreshAllByRule({
    required Entity entity,
    required RefreshRule rule,
  }) {
    var next = entity;
    for (final entry in entity.resources.entries) {
      if (entry.value.refreshRule != rule) continue;

      // Hit dice RAW: long rest'te yarı (min 1).
      final isHitDice = entry.key.startsWith('hit_dice_');
      if (isHitDice && rule == RefreshRule.longRest) {
        next = refresh(
          entity: next,
          resourceKey: entry.key,
          fraction: 0.5,
        );
      } else {
        next = refresh(entity: next, resourceKey: entry.key);
      }
    }
    return next;
  }

  // ── Concentration ────────────────────────────────────────────────────────

  /// Yeni concentration spell cast — mevcut concentration'ı kırıp temizler.
  /// Dönen entity'de `concentration` resource current=1, `concentratingOn`
  /// turn state'e set edilir (turn state yoksa dokunulmaz).
  Entity startConcentration({
    required Entity entity,
    required String effectId,
  }) {
    var next = _ensureResource(
      entity,
      'concentration',
      max: 1,
      current: 0,
    );
    // Mevcut concentration effect'leri entity'den düş.
    if (next.activeEffects.any((e) => e.requiresConcentration)) {
      next = next.copyWith(
        activeEffects: next.activeEffects
            .where((e) => !e.requiresConcentration)
            .toList(),
      );
    }
    // concentration.current = 1
    next = _update(
      next,
      'concentration',
      next.resources['concentration']!.copyWith(current: 1),
    );
    if (next.turnState != null) {
      next = next.copyWith(
        turnState: next.turnState!.copyWith(concentratingOn: effectId),
      );
    }
    return next;
  }

  /// Concentration'ı kır — requiresConcentration effect'leri düşür.
  Entity breakConcentration(Entity entity) {
    var next = entity.copyWith(
      activeEffects: entity.activeEffects
          .where((e) => !e.requiresConcentration)
          .toList(),
    );
    final concState = next.resources['concentration'];
    if (concState != null) {
      next = _update(
        next,
        'concentration',
        concState.copyWith(current: 0),
      );
    }
    if (next.turnState != null) {
      next = next.copyWith(
        turnState: next.turnState!.copyWith(concentratingOn: null),
      );
    }
    return next;
  }

  bool isConcentrating(Entity entity) {
    final state = entity.resources['concentration'];
    if (state != null && state.current > 0) return true;
    return entity.activeEffects.any((e) => e.requiresConcentration);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Entity _update(
    Entity entity,
    String resourceKey,
    ResourceState state,
  ) {
    return entity.copyWith(
      resources: {...entity.resources, resourceKey: state},
    );
  }

  Entity _ensureResource(
    Entity entity,
    String resourceKey, {
    required int max,
    required int current,
    RefreshRule refreshRule = RefreshRule.never,
  }) {
    if (entity.resources.containsKey(resourceKey)) return entity;
    return _update(
      entity,
      resourceKey,
      ResourceState(
        resourceKey: resourceKey,
        max: max,
        current: current,
        refreshRule: refreshRule,
      ),
    );
  }
}

class ResourceNotInitializedException implements Exception {
  const ResourceNotInitializedException(this.resourceKey);
  final String resourceKey;
  @override
  String toString() => 'Resource "$resourceKey" not initialized';
}

class InsufficientResourceException implements Exception {
  const InsufficientResourceException({
    required this.resourceKey,
    required this.available,
    required this.requested,
  });
  final String resourceKey;
  final int available;
  final int requested;
  @override
  String toString() =>
      'Insufficient "$resourceKey": available $available, requested $requested';
}
