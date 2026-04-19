import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/skill.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Skill> skills;

  setUpAll(() {
    final file = File('assets/packages/srd_core/skills.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    skills = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return skillFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 18 SRD skills parse', () {
    expect(skills, hasLength(18));
  });

  test('ids namespaced + unique', () {
    for (final s in skills) {
      expect(s.id, startsWith('srd:'));
    }
    final ids = skills.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('ability distribution matches SRD (1/3/5/5/4)', () {
    final byAbility = <Ability, int>{};
    for (final s in skills) {
      byAbility[s.ability] = (byAbility[s.ability] ?? 0) + 1;
    }
    expect(byAbility[Ability.strength], 1);
    expect(byAbility[Ability.dexterity], 3);
    expect(byAbility[Ability.intelligence], 5);
    expect(byAbility[Ability.wisdom], 5);
    expect(byAbility[Ability.charisma], 4);
    expect(byAbility[Ability.constitution] ?? 0, 0);
  });

  test('STR skill is Athletics', () {
    final str = skills.where((s) => s.ability == Ability.strength).single;
    expect(str.id, 'srd:athletics');
  });

  test('DEX skills: Acrobatics, Sleight of Hand, Stealth', () {
    final dex = skills
        .where((s) => s.ability == Ability.dexterity)
        .map((s) => s.id)
        .toSet();
    expect(dex, {'srd:acrobatics', 'srd:sleight_of_hand', 'srd:stealth'});
  });

  test('WIS skills include Perception and Insight', () {
    final wis = skills
        .where((s) => s.ability == Ability.wisdom)
        .map((s) => s.id)
        .toSet();
    expect(wis,
        {'srd:animal_handling', 'srd:insight', 'srd:medicine', 'srd:perception', 'srd:survival'});
  });

  test('CHA skills cover Deception/Intimidation/Performance/Persuasion', () {
    final cha = skills
        .where((s) => s.ability == Ability.charisma)
        .map((s) => s.id)
        .toSet();
    expect(cha,
        {'srd:deception', 'srd:intimidation', 'srd:performance', 'srd:persuasion'});
  });

  test('canonical 18-skill set', () {
    final ids = skills.map((s) => s.id).toSet();
    expect(ids, {
      'srd:acrobatics',
      'srd:animal_handling',
      'srd:arcana',
      'srd:athletics',
      'srd:deception',
      'srd:history',
      'srd:insight',
      'srd:intimidation',
      'srd:investigation',
      'srd:medicine',
      'srd:nature',
      'srd:perception',
      'srd:performance',
      'srd:persuasion',
      'srd:religion',
      'srd:sleight_of_hand',
      'srd:stealth',
      'srd:survival',
    });
  });
}
