import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/apply_damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/attack_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/attack_roll.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_instance.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_repository.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_service.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/target_defenses.dart';
import 'package:dungeon_master_tool/application/dnd5e/effect/combatant_effect_source.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/concentration_check_resolver.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/encounter.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/initiative.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
// EffectDescriptor type used via _noEffects return.
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/stat_block.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueRng implements math.Random {
  final List<int> q;
  int i = 0;
  _QueueRng(this.q);
  @override
  int nextInt(int max) => q[i++];
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

AbilityScores _abs() => AbilityScores(
      str: AbilityScore(10),
      dex: AbilityScore(10),
      con: AbilityScore(10),
      int_: AbilityScore(10),
      wis: AbilityScore(10),
      cha: AbilityScore(10),
    );

MonsterCombatant _mc(String id, {int hp = 10}) => MonsterCombatant(
      definition: Monster(
        id: 'srd:goblin',
        name: 'Goblin',
        stats: StatBlock(
          sizeId: 'srd:small',
          typeId: 'srd:humanoid',
          armorClass: 13,
          hitPoints: 10,
          abilities: _abs(),
          cr: ChallengeRating.parse('1/4'),
        ),
      ),
      id: id,
      instanceMaxHp: 10,
      instanceCurrentHp: hp,
      initiativeRoll: 10,
      turnState: TurnState(speedFt: 30),
    );

Encounter _enc(List<MonsterCombatant> cs) => Encounter(
      id: 'e1',
      name: 'Test',
      combatants: cs,
      order: InitiativeOrder(combatantIds: [for (final c in cs) c.id]),
    );

EncounterService _service({
  required EncounterRepository repo,
  ConditionEffectsLookup lookup = _noEffects,
  List<int> attackRolls = const [],
  List<int> saveRolls = const [],
}) {
  final source = CombatantEffectSource(conditionEffects: lookup);
  return EncounterService(
    repository: repo,
    attackPipeline: AttackPipeline(
      effectSource: source,
      resolver: AttackResolver(D20Roller(_QueueRng(attackRolls))),
    ),
    damagePipeline: DamagePipeline(
      effectSource: source,
      applyPipeline: ApplyDamagePipeline(
        damageResolver: const DamageResolver(),
        concentrationResolver:
            ConcentrationCheckResolver(SaveResolver(D20Roller())),
      ),
    ),
    savePipeline: SavePipeline(
      effectSource: source,
      resolver: SaveResolver(D20Roller(_QueueRng(saveRolls))),
    ),
    defensesFor: (c) => TargetDefenses(
      currentHp: c.currentHp,
      maxHp: c.maxHp,
    ),
  );
}

List<EffectDescriptor> _noEffects(String _) => const [];

void main() {
  group('EncounterService', () {
    test('runAttack: resolves and does not mutate encounter', () async {
      final repo = InMemoryEncounterRepository();
      final e = _enc([_mc('a'), _mc('b')]);
      await repo.save(e);
      final svc = _service(repo: repo, attackRolls: const [9]);
      final out = await svc.runAttack(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: (atk, tgt) => AttackPipelineInput(
          attacker: atk,
          target: tgt,
          abilityMod: 3,
          proficiencyBonus: 2,
          targetArmorClass: 13,
        ),
      );
      expect(out.result.roll.totalRoll, 10 + 3 + 2);
      // No write — encounter still has original HP.
      final after = await repo.findById('e1');
      expect(after!.byId('b')!.currentHp, 10);
    });

    test('applyDamage: writes new HP back through copyWith and persists',
        () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b')]));
      final svc = _service(repo: repo);
      final out = await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: (atk, tgt, def) => DamagePipelineInput(
          attacker: atk,
          target: tgt,
          defenses: def,
          baseDamage:
              DamageInstance(amount: 4, typeId: 'srd:slashing'),
        ),
      );
      expect(out.result.outcome.damage.newCurrentHp, 6);
      final after = await repo.findById('e1');
      expect(after!.byId('b')!.currentHp, 6);
    });

    test('requestSave: resolves without mutating encounter', () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('s')]));
      final svc = _service(repo: repo, saveRolls: const [9]); // d20 = 10
      final out = await svc.requestSave(
        encounterId: 'e1',
        saverId: 's',
        buildInput: (s) => SavePipelineInput(
          saver: s,
          ability: Ability.dexterity,
          abilityMod: 2,
          dc: 11,
        ),
      );
      expect(out.result.save.succeeded, isTrue);
      expect(out.result.save.totalRoll, 12);
    });

    test('advanceTurn: rotates and persists', () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a'), _mc('b')]));
      final svc = _service(repo: repo);
      final next = await svc.advanceTurn('e1');
      expect(next.order.currentId, 'b');
      final after = await repo.findById('e1');
      expect(after!.order.currentId, 'b');
    });

    test('tickConditions: decrements all combatants and surfaces expirations',
        () async {
      final repo = InMemoryEncounterRepository();
      final a = MonsterCombatant(
        definition: Monster(
          id: 'srd:goblin',
          name: 'Goblin',
          stats: StatBlock(
            sizeId: 'srd:small',
            typeId: 'srd:humanoid',
            armorClass: 13,
            hitPoints: 10,
            abilities: _abs(),
            cr: ChallengeRating.parse('1/4'),
          ),
        ),
        id: 'a',
        instanceMaxHp: 10,
        initiativeRoll: 10,
        conditionIds: const {'srd:bless'},
        conditionDurationsRounds: const {'srd:bless': 1},
        turnState: TurnState(speedFt: 30),
      );
      await repo.save(Encounter(
        id: 'e1',
        name: 'Test',
        combatants: [a, _mc('b')],
        order: InitiativeOrder(combatantIds: const ['a', 'b']),
      ));
      final svc = _service(repo: repo);
      final out = await svc.tickConditions('e1');
      expect(out.expiredByCombatant, {
        'a': {'srd:bless'},
      });
      final after = await repo.findById('e1');
      expect(after!.byId('a')!.conditionIds, isEmpty);
    });

    test('runAttack: missing encounter throws StateError', () async {
      final repo = InMemoryEncounterRepository();
      final svc = _service(repo: repo);
      expect(
        () => svc.runAttack(
          encounterId: 'nope',
          attackerId: 'a',
          targetId: 'b',
          buildInput: (atk, tgt) => AttackPipelineInput(
            attacker: atk,
            target: tgt,
            abilityMod: 0,
            proficiencyBonus: 0,
            targetArmorClass: 10,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('applyDamage: missing target throws StateError', () async {
      final repo = InMemoryEncounterRepository();
      await repo.save(_enc([_mc('a')]));
      final svc = _service(repo: repo);
      expect(
        () => svc.applyDamage(
          encounterId: 'e1',
          attackerId: 'a',
          targetId: 'zzz',
          buildInput: (atk, tgt, def) => DamagePipelineInput(
            attacker: atk,
            target: tgt,
            defenses: def,
            baseDamage:
                DamageInstance(amount: 1, typeId: 'srd:slashing'),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('attacker effects flow through pipeline call sites', () async {
      final repo = InMemoryEncounterRepository();
      final a = MonsterCombatant(
        definition: Monster(
          id: 'srd:goblin',
          name: 'Goblin',
          stats: StatBlock(
            sizeId: 'srd:small',
            typeId: 'srd:humanoid',
            armorClass: 13,
            hitPoints: 10,
            abilities: _abs(),
            cr: ChallengeRating.parse('1/4'),
          ),
        ),
        id: 'a',
        instanceMaxHp: 10,
        initiativeRoll: 10,
        conditionIds: const {'srd:rage'},
        turnState: TurnState(speedFt: 30),
      );
      await repo.save(Encounter(
        id: 'e1',
        name: 'Test',
        combatants: [a, _mc('b')],
        order: InitiativeOrder(combatantIds: const ['a', 'b']),
      ));
      final svc = _service(
        repo: repo,
        lookup: (id) => id == 'srd:rage'
            ? [ModifyDamageRoll(flatBonus: 3)]
            : const [],
      );
      final out = await svc.applyDamage(
        encounterId: 'e1',
        attackerId: 'a',
        targetId: 'b',
        buildInput: (atk, tgt, def) => DamagePipelineInput(
          attacker: atk,
          target: tgt,
          defenses: def,
          baseDamage: DamageInstance(amount: 2, typeId: 'srd:slashing'),
        ),
      );
      expect(out.result.contribution.flatBonus, 3);
      expect(out.result.outcome.damage.newCurrentHp, 5); // 10 - (2+3)
    });
  });
}
