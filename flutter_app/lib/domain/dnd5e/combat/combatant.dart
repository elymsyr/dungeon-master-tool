import '../catalog/content_reference.dart';
import '../character/character.dart';
import '../monster/monster.dart';
import 'concentration.dart';
import 'turn_state.dart';

/// Position on the battlemap in abstract feet from map origin (0,0 = top-left).
class TokenPosition {
  final double xFt;
  final double yFt;
  const TokenPosition(this.xFt, this.yFt);

  @override
  bool operator ==(Object other) =>
      other is TokenPosition && other.xFt == xFt && other.yFt == yFt;
  @override
  int get hashCode => Object.hash(xFt, yFt);
  @override
  String toString() => 'TokenPosition($xFt, $yFt)';
}

/// Sealed Combatant root — shared surface for initiative order, HP display,
/// condition tracking. Concrete cases wrap either a [Character] (PC) or a
/// [Monster] definition (NPC/monster).
sealed class Combatant {
  String get id;
  String get displayName;
  int get currentHp;
  int get maxHp;
  int get armorClass;
  int get initiativeRoll;
  Set<String> get conditionIds;
  Map<String, int> get conditionDurationsRounds;
  Concentration? get concentration;
  TurnState get turnState;
  TokenPosition? get mapPosition;
}

class PlayerCombatant implements Combatant {
  final Character character;
  @override
  final int initiativeRoll;
  @override
  final Set<String> conditionIds;
  @override
  final Map<String, int> conditionDurationsRounds;
  @override
  final Concentration? concentration;
  @override
  final TurnState turnState;
  @override
  final TokenPosition? mapPosition;

  PlayerCombatant._(
    this.character,
    this.initiativeRoll,
    this.conditionIds,
    this.conditionDurationsRounds,
    this.concentration,
    this.turnState,
    this.mapPosition,
  );

  factory PlayerCombatant({
    required Character character,
    required int initiativeRoll,
    Set<ContentReference> conditionIds = const {},
    Map<ContentReference, int> conditionDurationsRounds = const {},
    Concentration? concentration,
    required TurnState turnState,
    TokenPosition? mapPosition,
  }) {
    for (final id in conditionIds) {
      validateContentId(id);
    }
    for (final id in conditionDurationsRounds.keys) {
      validateContentId(id);
    }
    return PlayerCombatant._(
      character,
      initiativeRoll,
      Set.unmodifiable(conditionIds),
      Map.unmodifiable(conditionDurationsRounds),
      concentration,
      turnState,
      mapPosition,
    );
  }

  @override
  String get id => character.id;
  @override
  String get displayName => character.name;
  @override
  int get currentHp => character.hp.current;
  @override
  int get maxHp => character.hp.max;
  @override
  int get armorClass => character.armorClassBase();
}

class MonsterCombatant implements Combatant {
  final Monster definition;
  @override
  final String id; // per-instance — multiple goblins in an encounter
  final int instanceMaxHp;
  final int instanceCurrentHp;
  @override
  final int initiativeRoll;
  @override
  final Set<String> conditionIds;
  @override
  final Map<String, int> conditionDurationsRounds;
  @override
  final Concentration? concentration;
  @override
  final TurnState turnState;
  @override
  final TokenPosition? mapPosition;

  MonsterCombatant._(
    this.definition,
    this.id,
    this.instanceMaxHp,
    this.instanceCurrentHp,
    this.initiativeRoll,
    this.conditionIds,
    this.conditionDurationsRounds,
    this.concentration,
    this.turnState,
    this.mapPosition,
  );

  factory MonsterCombatant({
    required Monster definition,
    required String id,
    required int instanceMaxHp,
    int? instanceCurrentHp,
    required int initiativeRoll,
    Set<ContentReference> conditionIds = const {},
    Map<ContentReference, int> conditionDurationsRounds = const {},
    Concentration? concentration,
    required TurnState turnState,
    TokenPosition? mapPosition,
  }) {
    if (id.isEmpty) throw ArgumentError('MonsterCombatant.id must not be empty');
    if (instanceMaxHp < 1) {
      throw ArgumentError('MonsterCombatant.instanceMaxHp must be >= 1');
    }
    final current = instanceCurrentHp ?? instanceMaxHp;
    if (current < 0 || current > instanceMaxHp) {
      throw ArgumentError(
          'MonsterCombatant.instanceCurrentHp must be in [0, $instanceMaxHp]');
    }
    for (final cid in conditionIds) {
      validateContentId(cid);
    }
    for (final cid in conditionDurationsRounds.keys) {
      validateContentId(cid);
    }
    return MonsterCombatant._(
      definition,
      id,
      instanceMaxHp,
      current,
      initiativeRoll,
      Set.unmodifiable(conditionIds),
      Map.unmodifiable(conditionDurationsRounds),
      concentration,
      turnState,
      mapPosition,
    );
  }

  @override
  String get displayName => definition.name;
  @override
  int get currentHp => instanceCurrentHp;
  @override
  int get maxHp => instanceMaxHp;
  @override
  int get armorClass => definition.stats.armorClass;
}
