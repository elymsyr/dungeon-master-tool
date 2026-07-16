import 'package:dungeon_master_tool/domain/entities/schema/rules/dnd5e_rule_catalog.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rules/rule_definition.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rules/rule_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = dnd5eRuleCatalog();

  group('validateEffectRow', () {
    test('empty or missing kind → "No rule selected"', () {
      expect(validateEffectRow({}, catalog).single.message, 'No rule selected');
      expect(validateEffectRow({'kind': ''}, catalog).single.message,
          'No rule selected');
    });

    test('unknown kind → "Unknown rule"', () {
      final issues = validateEffectRow({'kind': 'save_bonus'}, catalog);
      expect(issues.single.message, contains('Unknown rule'));
      expect(issues.single.message, contains('save_bonus'));
    });

    test('well-formed applied row passes clean', () {
      final issues = validateEffectRow({
        'kind': 'ability_score_bonus',
        'target_kind': 'ability',
        'value': 1,
      }, catalog);
      expect(issues, isEmpty);
    });

    test('target kind outside a declared allow-list is flagged', () {
      final issues = validateEffectRow({
        'kind': 'ability_score_bonus',
        'target_kind': 'skill',
      }, catalog);
      expect(issues.single.message, contains('Target kind "skill"'));
    });

    test('target kind is never flagged when the rule declares no list', () {
      final undeclared = catalog.rules.values
          .firstWhere((r) => r.allowedTargetKinds.isEmpty);
      final issues = validateEffectRow({
        'kind': undeclared.id,
        'target_kind': 'totally-custom-token',
      }, catalog);
      expect(issues, isEmpty);
    });

    test('unknown predicate kind flagged, known one passes', () {
      final bad = validateEffectRow({
        'kind': 'ability_score_bonus',
        'predicates': [
          {'kind': 'no_such_predicate'},
        ],
      }, catalog);
      expect(bad.single.message, contains('Unknown predicate'));

      final good = validateEffectRow({
        'kind': 'ability_score_bonus',
        'predicates': [
          {'kind': 'class_level_at_least', 'args': {'level': 3}},
        ],
      }, catalog);
      expect(good, isEmpty);

      final noKind = validateEffectRow({
        'kind': 'ability_score_bonus',
        'predicates': [
          {'args': {}},
        ],
      }, catalog);
      expect(noKind.single.message, 'A predicate has no kind');
    });

    test('missing required param is flagged (synthetic catalog)', () {
      // No dnd5e rule declares `required: true` today, so the branch is
      // exercised through a minimal synthetic catalog.
      const synthetic = RuleCatalog(rules: {
        'test_rule': RuleDefinition(
          id: 'test_rule',
          label: 'Test Rule',
          description: '',
          category: RuleCategory.meta,
          params: [
            RuleParamSpec(
              key: 'value',
              label: 'Amount',
              type: RuleParamType.int_,
              required: true,
            ),
            RuleParamSpec(
              key: 'range_ft',
              label: 'Range',
              type: RuleParamType.int_,
              location: RuleParamLocation.payload,
              required: true,
            ),
          ],
        ),
      });
      final missing = validateEffectRow({'kind': 'test_rule'}, synthetic);
      expect(missing.map((i) => i.message),
          containsAll(['Missing required "Amount"', 'Missing required "Range"']));

      final present = validateEffectRow({
        'kind': 'test_rule',
        'value': 2,
        'payload': {'range_ft': 30},
      }, synthetic);
      expect(present, isEmpty);
    });
  });
}
