import '../../domain/entities/applied_effect.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/event_kind.dart';
import '../../domain/entities/turn_state.dart';

/// Encounter turn state yönetimi — action economy reset, round advance,
/// exhaustion stacking (condition seviyeli).
class TurnManager {
  const TurnManager();

  /// Encounter başlat — entity'ye fresh TurnState ata.
  Entity startEncounter({
    required Entity entity,
    required int initiativeOrder,
  }) {
    return entity.copyWith(
      turnState: TurnState(
        entityId: entity.id,
        roundNumber: 1,
        initiativeOrder: initiativeOrder,
      ),
    );
  }

  /// Encounter bitir — turnState'i temizle.
  Entity endEncounter(Entity entity) {
    return entity.copyWith(turnState: null);
  }

  /// Round ilerlet — action economy reset, roundNumber +1.
  /// attack/movement counter'ları da sıfırla.
  Entity advanceRound(Entity entity) {
    final t = entity.turnState;
    if (t == null) return entity;
    return entity.copyWith(
      turnState: t.copyWith(
        roundNumber: t.roundNumber + 1,
        actionUsed: false,
        bonusActionUsed: false,
        reactionUsed: false,
        movementUsed: 0,
        attacksThisTurn: 0,
        firstAttackMade: false,
      ),
    );
  }

  /// Turn başlangıcında (bu entity sıraya geldiğinde) — action economy reset.
  /// Round numarası değişmez. Reaction RAW her turn değil, round sonunda
  /// reset olur — burada reset etmiyoruz.
  Entity startTurn(Entity entity) {
    final t = entity.turnState;
    if (t == null) return entity;
    return entity.copyWith(
      turnState: t.copyWith(
        actionUsed: false,
        bonusActionUsed: false,
        movementUsed: 0,
        attacksThisTurn: 0,
        firstAttackMade: false,
      ),
    );
  }

  /// Reaction turn değil round boyunca kullanılabilir; round başında reset.
  Entity resetReactionAtRoundStart(Entity entity) {
    final t = entity.turnState;
    if (t == null) return entity;
    return entity.copyWith(
      turnState: t.copyWith(reactionUsed: false),
    );
  }

  /// Belirtilen action tipini "kullanıldı" olarak işaretle.
  Entity markAction({
    required Entity entity,
    required ActionType type,
  }) {
    final t = entity.turnState;
    if (t == null) return entity;
    return switch (type) {
      ActionType.action => entity.copyWith(
          turnState: t.copyWith(actionUsed: true),
        ),
      ActionType.bonusAction => entity.copyWith(
          turnState: t.copyWith(bonusActionUsed: true),
        ),
      ActionType.reaction => entity.copyWith(
          turnState: t.copyWith(reactionUsed: true),
        ),
      ActionType.free || ActionType.legendary || ActionType.lair => entity,
    };
  }

  /// Attack sayacını artır + firstAttackMade bayrağını set et.
  Entity registerAttack(Entity entity) {
    final t = entity.turnState;
    if (t == null) return entity;
    return entity.copyWith(
      turnState: t.copyWith(
        attacksThisTurn: t.attacksThisTurn + 1,
        firstAttackMade: true,
      ),
    );
  }

  /// Movement tüket.
  Entity spendMovement({
    required Entity entity,
    required int feet,
  }) {
    final t = entity.turnState;
    if (t == null) return entity;
    return entity.copyWith(
      turnState: t.copyWith(movementUsed: t.movementUsed + feet),
    );
  }

  // ── Exhaustion (stackable condition) ─────────────────────────────────────

  static const String _exhaustionId = 'condition-exhaustion';

  /// Exhaustion seviyesini oku (0-6).
  int exhaustionLevel(Entity entity) {
    for (final e in entity.activeEffects) {
      if (e.conditionId == _exhaustionId) return e.level;
    }
    return 0;
  }

  /// Exhaustion seviyesini artır — mevcut effect güncellenir, yoksa eklenir.
  /// RAW: max 6; 6. seviyede karakter ölür (caller handle eder).
  Entity incrementExhaustion(Entity entity, {int amount = 1}) {
    final current = exhaustionLevel(entity);
    final newLevel = (current + amount).clamp(0, 6);
    return _setExhaustion(entity, newLevel);
  }

  /// Exhaustion seviyesini azalt (long rest → -1 RAW).
  Entity decrementExhaustion(Entity entity, {int amount = 1}) {
    final current = exhaustionLevel(entity);
    final newLevel = (current - amount).clamp(0, 6);
    return _setExhaustion(entity, newLevel);
  }

  Entity _setExhaustion(Entity entity, int level) {
    final others = entity.activeEffects
        .where((e) => e.conditionId != _exhaustionId)
        .toList();
    if (level <= 0) {
      return entity.copyWith(activeEffects: others);
    }
    return entity.copyWith(
      activeEffects: [
        ...others,
        AppliedEffect(
          effectId: 'auto_$_exhaustionId',
          conditionId: _exhaustionId,
          level: level,
        ),
      ],
    );
  }
}
