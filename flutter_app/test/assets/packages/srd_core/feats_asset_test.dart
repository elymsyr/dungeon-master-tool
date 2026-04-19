import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/character/feat.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/feat_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Feat> feats;

  setUpAll(() {
    final file = File('assets/packages/srd_core/feats.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    feats = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return featFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 12 SRD Origin feats parse', () {
    expect(feats, hasLength(12));
  });

  test('ids namespaced + unique', () {
    for (final f in feats) {
      expect(f.id, startsWith('srd:'));
    }
    final ids = feats.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical 2024 PHB SRD Origin feat set', () {
    final ids = feats.map((f) => f.id).toSet();
    expect(ids, {
      'srd:alert',
      'srd:crafter',
      'srd:healer',
      'srd:lucky',
      'srd:magic_initiate_cleric',
      'srd:magic_initiate_druid',
      'srd:magic_initiate_wizard',
      'srd:musician',
      'srd:savage_attacker',
      'srd:skilled',
      'srd:tavern_brawler',
      'srd:tough',
    });
  });

  test('every feat is category=origin', () {
    for (final f in feats) {
      expect(f.category, FeatCategory.origin,
          reason: '${f.id} should be origin category');
    }
  });

  test('every feat has non-empty description', () {
    for (final f in feats) {
      expect(f.description, isNotEmpty, reason: '${f.id} missing description');
    }
  });

  test('Magic Initiate + Skilled feats are repeatable; others are not', () {
    const repeatableIds = {
      'srd:magic_initiate_cleric',
      'srd:magic_initiate_druid',
      'srd:magic_initiate_wizard',
      'srd:skilled',
    };
    for (final f in feats) {
      if (repeatableIds.contains(f.id)) {
        expect(f.repeatable, isTrue, reason: '${f.id} should be repeatable');
      } else {
        expect(f.repeatable, isFalse,
            reason: '${f.id} should not be repeatable');
      }
    }
  });

  test('no feat has a prerequisite (Origin feats have no prereq)', () {
    for (final f in feats) {
      expect(f.prerequisite, isNull,
          reason: '${f.id} should have no prerequisite');
    }
  });

  test('all Origin feats referenced by backgrounds are present', () {
    // Cross-reference: every Origin Feat named in backgrounds.json must exist.
    const referencedByBackgrounds = {
      'srd:magic_initiate_cleric',
      'srd:crafter',
      'srd:skilled',
      'srd:alert',
      'srd:musician',
      'srd:tough',
      'srd:magic_initiate_druid',
      'srd:healer',
      'srd:lucky',
      'srd:magic_initiate_wizard',
      'srd:tavern_brawler',
      'srd:savage_attacker',
    };
    final ids = feats.map((f) => f.id).toSet();
    for (final ref in referencedByBackgrounds) {
      expect(ids, contains(ref),
          reason: 'Background references unknown feat $ref');
    }
  });

  test('feats currently ship effects-free (DSL lacks cantrip/HP/reroll grants)',
      () {
    for (final f in feats) {
      expect(f.effects, isEmpty, reason: '${f.id} should have no effects yet');
    }
  });
}
