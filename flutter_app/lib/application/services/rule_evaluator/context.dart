import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/rule_triggers.dart';
import '../../../domain/entities/turn_state.dart';
import '../dice_roller.dart';

/// Rule evaluation context — predicate/expression/effect evaluation'ın
/// ihtiyacı olan state'i taşır.
///
/// Immutable; recursive çağrılar için `withDepth()` derinlik sayacı artırır
/// (infinite-loop guard). Event-driven rules için `eventPayload` ve
/// reactive için payload boş map.
class RuleContext {
  RuleContext({
    required this.entity,
    required this.category,
    required this.allEntities,
    required this.trigger,
    this.eventPayload = const <String, dynamic>{},
    this.turnState,
    this.relatedEntity,
    this.listItemId,
    this.depth = 0,
    DiceRoller? diceRoller,
  }) : diceRoller = diceRoller ?? DefaultDiceRoller();

  /// Değerlendirilen ana entity.
  final Entity entity;

  /// Entity'nin kategori şeması — field tanımları, rule'lar, grup'lar.
  final EntityCategorySchema category;

  /// Sahnedeki tüm entity'ler — relation çözümleme için (id → Entity).
  final Map<String, Entity> allEntities;

  /// Bu evaluation'ı tetikleyen trigger (always / event / d20 / damage / turn).
  final RuleTrigger trigger;

  /// Event trigger için payload (damage_amount, spell_id, slot_level, vb.).
  final Map<String, dynamic> eventPayload;

  /// Encounter içi turn state (yoksa null — out-of-combat).
  final TurnState? turnState;

  /// "While equipped" veya per-item style değerlendirmesinde ilişkili entity.
  final Entity? relatedEntity;

  /// List-item scoped değerlendirmede öğe id'si (equipGates kullanır).
  final String? listItemId;

  /// Recursion derinliği — engine depth cap'ine tabi.
  final int depth;

  /// Dice roll abstraksiyonu — test'te deterministik.
  final DiceRoller diceRoller;

  RuleContext withDepth() => RuleContext(
        entity: entity,
        category: category,
        allEntities: allEntities,
        trigger: trigger,
        eventPayload: eventPayload,
        turnState: turnState,
        relatedEntity: relatedEntity,
        listItemId: listItemId,
        depth: depth + 1,
        diceRoller: diceRoller,
      );

  RuleContext withRelated(Entity? related, {String? itemId}) => RuleContext(
        entity: entity,
        category: category,
        allEntities: allEntities,
        trigger: trigger,
        eventPayload: eventPayload,
        turnState: turnState,
        relatedEntity: related,
        listItemId: itemId,
        depth: depth,
        diceRoller: diceRoller,
      );

  /// Nokta notasyonu ile context key'den değer çek.
  /// Desteklenen ön-ekler: `trigger.*`, `turn.*`.
  dynamic contextValue(String key) {
    final dot = key.indexOf('.');
    if (dot <= 0) return eventPayload[key];
    final scope = key.substring(0, dot);
    final rest = key.substring(dot + 1);
    switch (scope) {
      case 'trigger':
        return eventPayload[rest];
      case 'turn':
        return _turnField(rest);
      default:
        return null;
    }
  }

  dynamic _turnField(String field) {
    final t = turnState;
    if (t == null) return null;
    switch (field) {
      case 'round_number':
      case 'roundNumber':
        return t.roundNumber;
      case 'initiative_order':
      case 'initiativeOrder':
        return t.initiativeOrder;
      case 'action_used':
      case 'actionUsed':
        return t.actionUsed;
      case 'bonus_action_used':
      case 'bonusActionUsed':
        return t.bonusActionUsed;
      case 'reaction_used':
      case 'reactionUsed':
        return t.reactionUsed;
      case 'movement_used':
      case 'movementUsed':
        return t.movementUsed;
      case 'attacks_this_turn':
      case 'attacksThisTurn':
        return t.attacksThisTurn;
      case 'first_attack_made':
      case 'firstAttackMade':
        return t.firstAttackMade;
      case 'critical_range_min':
      case 'criticalRangeMin':
        return t.criticalRangeMin;
      case 'concentrating_on':
      case 'concentratingOn':
        return t.concentratingOn;
      default:
        return null;
    }
  }
}
