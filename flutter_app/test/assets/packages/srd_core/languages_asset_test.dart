import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/language.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Language> languages;

  setUpAll(() {
    final file = File('assets/packages/srd_core/languages.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    languages = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return languageFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 19 SRD languages parse', () {
    expect(languages, hasLength(19));
  });

  test('ids namespaced + unique', () {
    for (final l in languages) {
      expect(l.id, startsWith('srd:'));
    }
    final ids = languages.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical SRD language set', () {
    final ids = languages.map((l) => l.id).toSet();
    expect(ids, {
      'srd:common',
      'srd:common_sign_language',
      'srd:dwarvish',
      'srd:elvish',
      'srd:giant',
      'srd:gnomish',
      'srd:goblin',
      'srd:halfling',
      'srd:orc',
      'srd:abyssal',
      'srd:celestial',
      'srd:deep_speech',
      'srd:draconic',
      'srd:druidic',
      'srd:infernal',
      'srd:primordial',
      'srd:sylvan',
      'srd:undercommon',
      'srd:thieves_cant',
    });
  });

  test('scripts are null or non-empty', () {
    for (final l in languages) {
      if (l.script != null) {
        expect(l.script, isNotEmpty, reason: '${l.id} has empty script');
      }
    }
  });

  test('unwritten languages have null script', () {
    final unwritten = {
      'srd:common_sign_language',
      'srd:deep_speech',
      'srd:thieves_cant',
    };
    for (final l in languages) {
      if (unwritten.contains(l.id)) {
        expect(l.script, isNull, reason: '${l.id} should have null script');
      }
    }
  });

  test('common uses Common script', () {
    final c = languages.firstWhere((l) => l.id == 'srd:common');
    expect(c.script, 'Common');
  });

  test('draconic uses Draconic script', () {
    final d = languages.firstWhere((l) => l.id == 'srd:draconic');
    expect(d.script, 'Draconic');
  });
}
