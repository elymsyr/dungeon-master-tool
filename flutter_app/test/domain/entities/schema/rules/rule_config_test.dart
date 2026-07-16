import 'package:dungeon_master_tool/domain/entities/schema/rules/rule_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleConfig', () {
    test('toJson/fromJson round-trip preserves value equality', () {
      const config = RuleConfig(
        asiLevels: [4, 6, 8],
        hitDieToHp: {'d6': 4, 'd8': 5, 'd10': 6, 'd12': 7, 'd20': 11},
        acUnarmoredBase: 13,
        acShieldBonus: 3,
        proficiencyBonusBreakpoints: [3, 7, 11],
      );
      final parsed = RuleConfig.fromJson(config.toJson());
      expect(parsed, config);
      expect(parsed.hashCode, config.hashCode);
    });

    test('dnd5eDefaults round-trips to an equal value', () {
      final parsed = RuleConfig.fromJson(RuleConfig.dnd5eDefaults.toJson());
      expect(parsed, RuleConfig.dnd5eDefaults);
    });

    test('partial override keeps every other key at the base default', () {
      final parsed = RuleConfig.fromJson({
        'asi_levels': [4],
      });
      expect(parsed.asiLevels, [4]);
      expect(parsed.hitDieToHp, RuleConfig.dnd5eDefaults.hitDieToHp);
      expect(parsed.acUnarmoredBase, RuleConfig.dnd5eDefaults.acUnarmoredBase);
      expect(parsed.acShieldBonus, RuleConfig.dnd5eDefaults.acShieldBonus);
      expect(parsed.proficiencyBonusBreakpoints,
          RuleConfig.dnd5eDefaults.proficiencyBonusBreakpoints);
    });

    test('malformed values fall back per-key, not wholesale', () {
      final parsed = RuleConfig.fromJson({
        'asi_levels': 'not-a-list',
        'hit_die_to_hp': 42,
        'ac_unarmored_base': 15,
        'ac_shield_bonus': 'nope',
      });
      expect(parsed.asiLevels, RuleConfig.dnd5eDefaults.asiLevels);
      expect(parsed.hitDieToHp, RuleConfig.dnd5eDefaults.hitDieToHp);
      expect(parsed.acUnarmoredBase, 15);
      expect(parsed.acShieldBonus, RuleConfig.dnd5eDefaults.acShieldBonus);
    });

    test('proficiencyBonusFor follows SRD breakpoints', () {
      const c = RuleConfig.dnd5eDefaults;
      expect(c.proficiencyBonusFor(1), 2);
      expect(c.proficiencyBonusFor(4), 2);
      expect(c.proficiencyBonusFor(5), 3);
      expect(c.proficiencyBonusFor(9), 4);
      expect(c.proficiencyBonusFor(13), 5);
      expect(c.proficiencyBonusFor(17), 6);
      expect(c.proficiencyBonusFor(20), 6);
    });

    test('isAsiLevel matches configured levels only', () {
      const c = RuleConfig.dnd5eDefaults;
      expect(c.isAsiLevel(4), isTrue);
      expect(c.isAsiLevel(19), isTrue);
      expect(c.isAsiLevel(5), isFalse);
    });

    test('hpPerLevelFor returns 0 for unknown or null die', () {
      const c = RuleConfig.dnd5eDefaults;
      expect(c.hpPerLevelFor('d8'), 5);
      expect(c.hpPerLevelFor('d100'), 0);
      expect(c.hpPerLevelFor(null), 0);
    });

    test('canonicalHitDie normalizes int, dN, DN, NdM and bare-number forms',
        () {
      expect(canonicalHitDie(8), 'd8');
      expect(canonicalHitDie('d8'), 'd8');
      expect(canonicalHitDie('D8'), 'd8');
      expect(canonicalHitDie('1d10'), 'd10');
      expect(canonicalHitDie('8'), 'd8');
      expect(canonicalHitDie('garbage'), isNull);
      expect(canonicalHitDie(null), isNull);
    });

    test('hitDieFaces mirrors canonicalHitDie', () {
      expect(hitDieFaces('d12'), 12);
      expect(hitDieFaces(6), 6);
      expect(hitDieFaces('junk'), 0);
    });
  });
}
