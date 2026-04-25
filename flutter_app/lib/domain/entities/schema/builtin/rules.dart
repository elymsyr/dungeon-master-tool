import 'package:uuid/uuid.dart';

import '../entity_category_schema.dart';
import '../rule_v2.dart';

const _uuid = Uuid();

/// Built-in RuleV2 defs per design §7. Attached per-slug in
/// [attachBuiltinRules]. Some rules from §7 need static lookup tables
/// (CR → XP, CR → proficiency bonus, total-level → proficiency bonus)
/// that the schema engine doesn't carry as a first-class table. Those
/// rules are deliberately deferred until the table primitive lands —
/// see comments on each builder.
class BuiltinRuleSet {
  final List<RuleV2> monster;
  final List<RuleV2> playerCharacter;
  final List<RuleV2> armor;
  final List<RuleV2> magicItem;
  final List<RuleV2> spell;

  const BuiltinRuleSet({
    required this.monster,
    required this.playerCharacter,
    required this.armor,
    required this.magicItem,
    required this.spell,
  });

  int get total =>
      monster.length +
      playerCharacter.length +
      armor.length +
      magicItem.length +
      spell.length;
}

BuiltinRuleSet buildBuiltinRules() {
  return BuiltinRuleSet(
    monster: [_monsterInitiativeFromDex()],
    playerCharacter: [
      _pcPassivePerceptionFromWis(),
      _pcAcSumEquippedBonuses(),
    ],
    armor: [_armorStrengthGate()],
    magicItem: [_magicItemAttunementGate()],
    spell: [_spellFadeWhenWrongClassList()],
  );
}

/// Apply [rules] to the matching category in [categories], by slug.
/// Returns a new list with `rules` set on those categories.
List<EntityCategorySchema> attachBuiltinRules(
  List<EntityCategorySchema> categories,
  BuiltinRuleSet rules,
) {
  final bySlug = <String, List<RuleV2>>{
    'monster': rules.monster,
    'animal': rules.monster, // animal mirrors monster shape
    'player-character': rules.playerCharacter,
    'armor': rules.armor,
    'magic-item': rules.magicItem,
    'spell': rules.spell,
  };
  return [
    for (final c in categories)
      if (bySlug.containsKey(c.slug)) c.copyWith(rules: bySlug[c.slug]!) else c,
  ];
}

// ---------------------------------------------------------------------------
// Rule builders
// ---------------------------------------------------------------------------

/// Monster.initiative_score = 10 + DEX modifier.
/// Predicate is `always` — lets users override by typing into the field.
/// (Engine semantics: SetValueEffect overwrites; opt-in toggling lives at
/// the rule's `enabled` flag, not the predicate.)
RuleV2 _monsterInitiativeFromDex() {
  return RuleV2(
    ruleId: _uuid.v4(),
    name: 'Initiative from DEX',
    description: 'Sets initiative_score to 10 + DEX modifier on monster sheets.',
    when_: const Predicate.always(),
    then_: const RuleEffect.setValue(
      targetFieldKey: 'initiative_score',
      value: ValueExpression.arithmetic(
        left: ValueExpression.literal(10),
        op: ArithOp.add,
        right: ValueExpression.modifier(
          FieldRef(
            scope: RefScope.self,
            fieldKey: 'stat_block',
            nestedFieldKey: 'DEX',
          ),
        ),
      ),
    ),
    priority: 0,
  );
}

/// PlayerCharacter.passive_perception = 10 + WIS modifier.
/// (Perception proficiency add-in deferred — needs a `proficiencyTable`
/// reader expression that the engine doesn't yet expose.)
RuleV2 _pcPassivePerceptionFromWis() {
  return RuleV2(
    ruleId: _uuid.v4(),
    name: 'Passive Perception from WIS',
    description: 'Sets passive_perception to 10 + WIS modifier.',
    when_: const Predicate.always(),
    then_: const RuleEffect.setValue(
      targetFieldKey: 'passive_perception',
      value: ValueExpression.arithmetic(
        left: ValueExpression.literal(10),
        op: ArithOp.add,
        right: ValueExpression.modifier(
          FieldRef(
            scope: RefScope.self,
            fieldKey: 'stat_block',
            nestedFieldKey: 'WIS',
          ),
        ),
      ),
    ),
    priority: 0,
  );
}

/// PlayerCharacter.ac = sum of equipped-item AC bonuses.
/// Aggregates the `base_ac` field across the equipped subset of `inventory`.
RuleV2 _pcAcSumEquippedBonuses() {
  return RuleV2(
    ruleId: _uuid.v4(),
    name: 'AC from Equipped Items',
    description: 'Sums base_ac across equipped inventory into combat_stats.ac.',
    when_: const Predicate.always(),
    then_: const RuleEffect.setValue(
      targetFieldKey: 'combat_stats',
      value: ValueExpression.aggregate(
        relationFieldKey: 'inventory',
        sourceFieldKey: 'base_ac',
        op: AggregateOp.sum,
        onlyEquipped: true,
      ),
    ),
    priority: 1,
  );
}

/// Armor.gate-equip if strength_requirement > wearer.STR.
/// Equip is allowed when the predicate is true (i.e. the gate "passes").
/// Predicate: strength_requirement <= wearer.STR.
RuleV2 _armorStrengthGate() {
  return RuleV2(
    ruleId: _uuid.v4(),
    name: 'Heavy Armor STR Gate',
    description: 'Blocks equipping armor when wearer STR is below requirement.',
    when_: const Predicate.compare(
      left: FieldRef(scope: RefScope.self, fieldKey: 'strength_requirement'),
      op: CompareOp.lte,
      right: FieldRef(
        scope: RefScope.related,
        fieldKey: 'stat_block',
        relationFieldKey: '__wearer__',
        nestedFieldKey: 'STR',
      ),
    ),
    then_: const RuleEffect.gateEquip(
      blockReason: 'Wearer STR is below the armor\'s strength requirement.',
    ),
    priority: 0,
  );
}

/// MagicItem.gate-equip if requires_attunement and the wearer hasn't
/// completed attunement. The "attuned-to" check resolves at runtime
/// against the wearer's attunement slots — this rule guards the schema
/// shape and surfaces the block reason; the runtime layer fills in the
/// wearer-side predicate.
RuleV2 _magicItemAttunementGate() {
  return RuleV2(
    ruleId: _uuid.v4(),
    name: 'Attunement Gate',
    description: 'Blocks equipping items that require attunement until attuned.',
    when_: const Predicate.compare(
      left: FieldRef(scope: RefScope.self, fieldKey: 'requires_attunement'),
      op: CompareOp.eq,
      literalValue: false,
    ),
    then_: const RuleEffect.gateEquip(
      blockReason: 'Item requires attunement before it can be equipped.',
    ),
    priority: 0,
  );
}

/// Spell list styling: fade spells whose class_refs do not intersect the
/// caster's classes. The runtime evaluates this per-item against the
/// caster's class list; here we declare the styling contract.
RuleV2 _spellFadeWhenWrongClassList() {
  return RuleV2(
    ruleId: _uuid.v4(),
    name: 'Fade Off-Class Spells',
    description: 'Fades spell list items whose class_refs do not include any of the caster\'s classes.',
    when_: const Predicate.compare(
      left: FieldRef(scope: RefScope.self, fieldKey: 'class_refs'),
      op: CompareOp.isDisjointFrom,
      right: FieldRef(
        scope: RefScope.related,
        fieldKey: 'class_refs',
        relationFieldKey: '__caster__',
      ),
    ),
    then_: const RuleEffect.styleItems(
      listFieldKey: 'class_refs',
      style: ItemStyle(faded: true, tooltip: 'Not on your class list.'),
    ),
    priority: 5,
  );
}
