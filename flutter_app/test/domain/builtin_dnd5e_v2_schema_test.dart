import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/content.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/dm.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/lookups.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late final build = generateBuiltinDnd5eV2Schema();
  final schema = build.schema;

  group('Builtin D&D 5e v2 Schema', () {
    test('ships 37 Tier-0 + 21 Tier-1 + 13 Tier-2 = 71 categories', () {
      expect(schema.categories.length, 71);
      expect(tier0Slugs.length, 37);
      expect(tier1Slugs.length, 21);
      expect(tier2Slugs.length, 13);
    });

    test('Tier order in catalog: Tier-0, Tier-1, Tier-2', () {
      final slugs = schema.categories.map((c) => c.slug).toList();
      expect(slugs.sublist(0, 37), tier0Slugs);
      expect(slugs.sublist(37, 58), tier1Slugs);
      expect(slugs.sublist(58, 71), tier2Slugs);
    });

    test('schema metadata', () {
      expect(schema.schemaId, 'builtin-dnd5e-default-v2');
      expect(schema.baseSystem, 'dnd5e');
      expect(schema.version, '2.3.0');
      expect(schema.originalHash, 'builtin-dnd5e-default-v2');
    });

    test('every category is builtin', () {
      for (final cat in schema.categories) {
        expect(cat.isBuiltin, true, reason: '${cat.slug} should be builtin');
        for (final f in cat.fields) {
          expect(f.isBuiltin, true, reason: '${cat.slug}.${f.fieldKey} should be builtin');
        }
      }
    });

    test('Tier-0 slugs match tier0Slugs list', () {
      expect(
        schema.categories.take(37).map((c) => c.slug).toList(),
        tier0Slugs,
      );
    });

    test('Tier-1 slugs match tier1Slugs list', () {
      expect(
        schema.categories.skip(37).take(21).map((c) => c.slug).toList(),
        tier1Slugs,
      );
    });

    test('Tier-2 slugs match tier2Slugs list', () {
      expect(
        schema.categories.skip(58).map((c) => c.slug).toList(),
        tier2Slugs,
      );
    });

    test('category orderIndex is sequential 0..n-1', () {
      for (var i = 0; i < schema.categories.length; i++) {
        expect(schema.categories[i].orderIndex, i,
            reason: '${schema.categories[i].slug} orderIndex');
      }
    });

    test('every Tier-0 category carries common lookup fields', () {
      const commonKeys = {'summary', 'icon_name', 'color'};
      for (final cat in schema.categories.take(37)) {
        final keys = cat.fields.map((f) => f.fieldKey).toSet();
        expect(keys.containsAll(commonKeys), true,
            reason: '${cat.slug} missing common fields');
      }
    });

    test('field orderIndex sequential within each category', () {
      for (final cat in schema.categories) {
        for (var i = 0; i < cat.fields.length; i++) {
          expect(cat.fields[i].orderIndex, i,
              reason: '${cat.slug}.${cat.fields[i].fieldKey}');
        }
      }
    });

    test('ability category has exactly 6 seed rows', () {
      final rows = build.seedRows['ability']!;
      expect(rows.length, 6);
      expect(
        rows.map((r) => r['name']).toList(),
        ['Strength', 'Dexterity', 'Constitution', 'Intelligence', 'Wisdom', 'Charisma'],
      );
    });

    test('skill category has 18 seed rows, each with ability linkage hint', () {
      final rows = build.seedRows['skill']!;
      expect(rows.length, 18);
      for (final r in rows) {
        final fields = r['fields'] as Map<String, dynamic>;
        expect(fields.containsKey('_ability_name_'), true,
            reason: '${r['name']} must have _ability_name_ for bootstrap');
      }
    });

    test('damage-type has 13 rows; 3 flagged physical', () {
      final rows = build.seedRows['damage-type']!;
      expect(rows.length, 13);
      final physical = rows
          .where((r) => (r['fields'] as Map)['is_physical'] == true)
          .map((r) => r['name'])
          .toSet();
      expect(physical, {'Bludgeoning', 'Piercing', 'Slashing'});
    });

    test('condition has 15 rows, Exhaustion stacks, 4 grant Incapacitated', () {
      final rows = build.seedRows['condition']!;
      expect(rows.length, 15);
      final stacks = rows
          .where((r) => (r['fields'] as Map)['stacks'] == true)
          .map((r) => r['name'])
          .toSet();
      expect(stacks, {'Exhaustion'});
      final grants = rows
          .where((r) => (r['fields'] as Map)['grants_incapacitated'] == true)
          .map((r) => r['name'])
          .toSet();
      expect(grants, {'Paralyzed', 'Petrified', 'Stunned', 'Unconscious'});
    });

    test('creature-type has 14 rows', () {
      expect(build.seedRows['creature-type']!.length, 14);
    });

    test('language has 10 Standard + 9 Rare', () {
      final rows = build.seedRows['language']!;
      final standard = rows.where((r) => (r['fields'] as Map)['tier'] == 'Standard').length;
      final rare = rows.where((r) => (r['fields'] as Map)['tier'] == 'Rare').length;
      expect(standard, 10);
      expect(rare, 9);
    });

    test('weapon-property has 11 rows, weapon-mastery has 8', () {
      expect(build.seedRows['weapon-property']!.length, 11);
      expect(build.seedRows['weapon-mastery']!.length, 8);
    });

    test('spell-school has 8 rows', () {
      expect(build.seedRows['spell-school']!.length, 8);
    });

    test('skill fields include ability_ref relation to ability', () {
      final skill = schema.categories.firstWhere((c) => c.slug == 'skill');
      final ref = skill.fields.firstWhere((f) => f.fieldKey == 'ability_ref');
      expect(ref.fieldType, FieldType.relation);
      expect(ref.validation.allowedTypes, ['ability']);
      expect(ref.isRequired, true);
    });

    test('magic-item-category has crafting_tool_ref relation to tool', () {
      final cat = schema.categories.firstWhere((c) => c.slug == 'magic-item-category');
      final ref = cat.fields.firstWhere((f) => f.fieldKey == 'crafting_tool_ref');
      expect(ref.validation.allowedTypes, ['tool']);
    });

    test('encounter layout ships deterministic id', () {
      expect(schema.encounterLayouts.length, 1);
      expect(schema.encounterLayouts.first.layoutId,
          'builtin-dnd5e-default-v2-layout-standard');
    });

    test('encounter config conditions list is empty (runtime reads catalog)', () {
      expect(schema.encounterConfig.conditions, isEmpty);
    });

    test('seedRows map keys match category slugs', () {
      expect(build.seedRows.keys.toSet(),
          schema.categories.map((c) => c.slug).toSet());
    });

    test('Tier-1 categories ship empty seed rows (content pack)', () {
      for (final slug in tier1Slugs) {
        expect(build.seedRows[slug], isEmpty,
            reason: '$slug should ship no rows; content pack handles content');
      }
    });

    test('Tier-2 DM categories ship empty seed rows (user-authored)', () {
      for (final slug in tier2Slugs) {
        expect(build.seedRows[slug], isEmpty,
            reason: '$slug is user-authored — never seeded');
      }
    });

    // --- Tier-1 shape checks --------------------------------------------

    test('class category has hit_die enum and caster_kind', () {
      final cls = schema.categories.firstWhere((c) => c.slug == 'class');
      final hd = cls.fields.firstWhere((f) => f.fieldKey == 'hit_die');
      expect(hd.fieldType, FieldType.enum_);
      expect(hd.validation.allowedValues, ['d6', 'd8', 'd10', 'd12']);
      final ck = cls.fields.firstWhere((f) => f.fieldKey == 'caster_kind');
      expect(ck.validation.allowedValues,
          ['None', 'Full', 'Half', 'Third', 'Pact', 'Ritual']);
      expect(ck.isRequired, true);
    });

    test('subclass links to class via parent_class_ref', () {
      final sub = schema.categories.firstWhere((c) => c.slug == 'subclass');
      final pc = sub.fields.firstWhere((f) => f.fieldKey == 'parent_class_ref');
      expect(pc.fieldType, FieldType.relation);
      expect(pc.validation.allowedTypes, ['class']);
      expect(pc.isRequired, true);
    });

    test('species has size/speed/creature_type', () {
      final sp = schema.categories.firstWhere((c) => c.slug == 'species');
      final keys = sp.fields.map((f) => f.fieldKey).toSet();
      expect(keys, containsAll({'size_ref', 'speed_ft', 'creature_type_ref', 'trait_refs'}));
    });

    test('spell has level 0..9 and damage-type relation list', () {
      final sp = schema.categories.firstWhere((c) => c.slug == 'spell');
      final lvl = sp.fields.firstWhere((f) => f.fieldKey == 'level');
      expect(lvl.validation.minValue, 0.0);
      expect(lvl.validation.maxValue, 9.0);
      final dmg = sp.fields.firstWhere((f) => f.fieldKey == 'damage_type_refs');
      expect(dmg.isList, true);
      expect(dmg.validation.allowedTypes, ['damage-type']);
    });

    test('weapon has damage_dice, mastery_ref, cost+weight', () {
      final w = schema.categories.firstWhere((c) => c.slug == 'weapon');
      final keys = w.fields.map((f) => f.fieldKey).toSet();
      expect(keys, containsAll({'damage_dice', 'damage_type_ref', 'mastery_ref', 'cost_gp', 'weight_lb'}));
      final mastery = w.fields.firstWhere((f) => f.fieldKey == 'mastery_ref');
      expect(mastery.validation.allowedTypes, ['weapon-mastery']);
      expect(mastery.isRequired, true);
    });

    test('armor has base_ac, stealth_disadvantage, don/doff', () {
      final a = schema.categories.firstWhere((c) => c.slug == 'armor');
      final keys = a.fields.map((f) => f.fieldKey).toSet();
      expect(keys, containsAll({
        'base_ac', 'adds_dex', 'dex_cap', 'strength_requirement',
        'stealth_disadvantage', 'don_time_minutes', 'doff_time_minutes',
      }));
    });

    test('magic-item base_item_ref accepts multiple target types', () {
      final mi = schema.categories.firstWhere((c) => c.slug == 'magic-item');
      final base = mi.fields.firstWhere((f) => f.fieldKey == 'base_item_ref');
      expect(base.validation.allowedTypes,
          ['weapon', 'armor', 'adventuring-gear']);
    });

    test('monster has CR enum covering 0 through 30', () {
      final m = schema.categories.firstWhere((c) => c.slug == 'monster');
      final cr = m.fields.firstWhere((f) => f.fieldKey == 'cr');
      expect(cr.validation.allowedValues!.first, '0');
      expect(cr.validation.allowedValues!.last, '30');
      expect(cr.validation.allowedValues!.contains('1/8'), true);
      expect(cr.validation.allowedValues!.contains('1/2'), true);
    });

    test('animal mirrors monster field keys', () {
      final monster = schema.categories.firstWhere((c) => c.slug == 'monster');
      final animal = schema.categories.firstWhere((c) => c.slug == 'animal');
      final mKeys = monster.fields.map((f) => f.fieldKey).toList();
      final aKeys = animal.fields.map((f) => f.fieldKey).toList();
      expect(aKeys, mKeys);
    });

    test('tool variant_of_ref self-references tool', () {
      final t = schema.categories.firstWhere((c) => c.slug == 'tool');
      final vr = t.fields.firstWhere((f) => f.fieldKey == 'variant_of_ref');
      expect(vr.validation.allowedTypes, ['tool']);
    });

    test('adventuring-gear focus_kind_ref accepts three focus types', () {
      final g = schema.categories.firstWhere((c) => c.slug == 'adventuring-gear');
      final fk = g.fields.firstWhere((f) => f.fieldKey == 'focus_kind_ref');
      expect(fk.validation.allowedTypes,
          ['arcane-focus', 'druidic-focus', 'holy-symbol']);
    });

    test('trinket has roll_d100 with 1..100 range', () {
      final t = schema.categories.firstWhere((c) => c.slug == 'trinket');
      final r = t.fields.firstWhere((f) => f.fieldKey == 'roll_d100');
      expect(r.validation.minValue, 1.0);
      expect(r.validation.maxValue, 100.0);
      expect(r.isRequired, true);
    });

    // --- Tier-2 shape checks --------------------------------------------

    test('npc carries combat_stats, stat_block, and DM-only secrets', () {
      final npc = schema.categories.firstWhere((c) => c.slug == 'npc');
      final keys = npc.fields.map((f) => f.fieldKey).toSet();
      expect(keys, containsAll({'stat_block', 'combat_stats', 'attitude_ref', 'secrets'}));
      final secrets = npc.fields.firstWhere((f) => f.fieldKey == 'secrets');
      expect(secrets.visibility, FieldVisibility.dmOnly);
    });

    test('player-character has spell slots, death saves, inventory union', () {
      final pc = schema.categories.firstWhere((c) => c.slug == 'player-character');
      final keys = pc.fields.map((f) => f.fieldKey).toSet();
      expect(keys, containsAll({
        'spell_slots', 'pact_magic_slots',
        'death_saves_successes', 'death_saves_failures',
        'heroic_inspiration', 'temp_hp', 'inventory',
        'current_conditions',
      }));
      final inv = pc.fields.firstWhere((f) => f.fieldKey == 'inventory');
      expect(inv.validation.allowedTypes,
          ['weapon', 'armor', 'adventuring-gear', 'magic-item']);
      final cc = pc.fields.firstWhere((f) => f.fieldKey == 'current_conditions');
      expect(cc.validation.allowedTypes, ['applied-condition']);
    });

    test('applied-condition references condition + ability', () {
      final ac = schema.categories.firstWhere((c) => c.slug == 'applied-condition');
      final cr = ac.fields.firstWhere((f) => f.fieldKey == 'condition_ref');
      expect(cr.validation.allowedTypes, ['condition']);
      expect(cr.isRequired, true);
      final freq = ac.fields.firstWhere((f) => f.fieldKey == 'save_frequency');
      expect(freq.validation.allowedValues,
          ['none', 'start-of-turn', 'end-of-turn', 'when-damaged']);
    });

    test('location parent_location_ref self-references', () {
      final loc = schema.categories.firstWhere((c) => c.slug == 'location');
      final p = loc.fields.firstWhere((f) => f.fieldKey == 'parent_location_ref');
      expect(p.validation.allowedTypes, ['location']);
    });

    test('encounter monsters_refs accepts monster + animal', () {
      final enc = schema.categories.firstWhere((c) => c.slug == 'encounter');
      final m = enc.fields.firstWhere((f) => f.fieldKey == 'monsters_refs');
      expect(m.validation.allowedTypes, ['monster', 'animal']);
      expect(m.isList, true);
    });

    test('trap has save mechanics and detection/disable DCs', () {
      final t = schema.categories.firstWhere((c) => c.slug == 'trap');
      final keys = t.fields.map((f) => f.fieldKey).toSet();
      expect(keys, containsAll({'save_dc', 'save_ability_ref', 'damage_dice', 'detection_dc', 'disable_dc'}));
    });

    test('poison kind enum is 4 SRD values', () {
      final p = schema.categories.firstWhere((c) => c.slug == 'poison');
      final k = p.fields.firstWhere((f) => f.fieldKey == 'poison_kind');
      expect(k.validation.allowedValues, ['Contact', 'Ingested', 'Inhaled', 'Injury']);
    });

    test('hireling has skill_ref + daily_cost_cp + skilled flag', () {
      final h = schema.categories.firstWhere((c) => c.slug == 'hireling');
      final keys = h.fields.map((f) => f.fieldKey).toSet();
      expect(keys, containsAll({'skill_ref', 'daily_cost_cp', 'skilled'}));
      final sk = h.fields.firstWhere((f) => f.fieldKey == 'skill_ref');
      expect(sk.validation.allowedTypes, ['skill']);
    });

    test('service kind enum carries 4 categories', () {
      final s = schema.categories.firstWhere((c) => c.slug == 'service');
      final k = s.fields.firstWhere((f) => f.fieldKey == 'kind');
      expect(k.validation.allowedValues, ['Spellcasting', 'Transport', 'Shelter', 'Other']);
    });
  });
}
