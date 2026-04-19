import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/character/caster_kind.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<CharacterClass> classes;

  setUpAll(() {
    final file = File('assets/packages/srd_core/classes.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    classes = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return characterClassFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 5 SRD class samples parse', () {
    expect(classes, hasLength(5));
  });

  test('canonical sample id set', () {
    expect(classes.map((c) => c.id).toSet(), {
      'srd:barbarian',
      'srd:cleric',
      'srd:fighter',
      'srd:rogue',
      'srd:wizard',
    });
  });

  test('hit dice match canonical SRD values', () {
    final hitDie = {for (final c in classes) c.id: c.hitDie};
    expect(hitDie['srd:barbarian'], Die.d12);
    expect(hitDie['srd:cleric'], Die.d8);
    expect(hitDie['srd:fighter'], Die.d10);
    expect(hitDie['srd:rogue'], Die.d8);
    expect(hitDie['srd:wizard'], Die.d6);
  });

  test('caster kinds match canonical SRD values', () {
    final caster = {for (final c in classes) c.id: c.casterKind};
    expect(caster['srd:barbarian'], CasterKind.none);
    expect(caster['srd:cleric'], CasterKind.full);
    expect(caster['srd:fighter'], CasterKind.none);
    expect(caster['srd:rogue'], CasterKind.none);
    expect(caster['srd:wizard'], CasterKind.full);
  });

  test('every class has 2 saving throws + non-empty description', () {
    for (final c in classes) {
      expect(c.savingThrows, hasLength(2), reason: '${c.id} saves');
      expect(c.description, isNotEmpty);
    }
  });

  test('feature table rows are sorted by level', () {
    for (final c in classes) {
      final levels = c.featureTable.map((r) => r.level).toList();
      final sorted = [...levels]..sort();
      expect(levels, sorted, reason: '${c.id} feature rows out of order');
    }
  });
}
