import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/alignment.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Alignment> alignments;

  setUpAll(() {
    final file = File('assets/packages/srd_core/alignments.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    alignments = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return alignmentFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 10 SRD alignments parse', () {
    expect(alignments, hasLength(10));
  });

  test('ids namespaced + unique', () {
    for (final a in alignments) {
      expect(a.id, startsWith('srd:'));
    }
    final ids = alignments.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical SRD 10-alignment set', () {
    final ids = alignments.map((a) => a.id).toSet();
    expect(ids, {
      'srd:lawful_good',
      'srd:neutral_good',
      'srd:chaotic_good',
      'srd:lawful_neutral',
      'srd:true_neutral',
      'srd:chaotic_neutral',
      'srd:lawful_evil',
      'srd:neutral_evil',
      'srd:chaotic_evil',
      'srd:unaligned',
    });
  });

  test('9 classic alignments form 3×3 L/C × G/E grid', () {
    final grid = alignments.where((a) => a.id != 'srd:unaligned').toList();
    expect(grid, hasLength(9));
    final pairs = grid.map((a) => (a.lawChaos, a.goodEvil)).toSet();
    for (final lc in [LawChaosAxis.lawful, LawChaosAxis.neutral, LawChaosAxis.chaotic]) {
      for (final ge in [GoodEvilAxis.good, GoodEvilAxis.neutral, GoodEvilAxis.evil]) {
        expect(pairs.contains((lc, ge)), isTrue, reason: '$lc × $ge missing');
      }
    }
  });

  test('Lawful Good = (lawful, good)', () {
    final lg = alignments.firstWhere((a) => a.id == 'srd:lawful_good');
    expect(lg.lawChaos, LawChaosAxis.lawful);
    expect(lg.goodEvil, GoodEvilAxis.good);
  });

  test('Chaotic Evil = (chaotic, evil)', () {
    final ce = alignments.firstWhere((a) => a.id == 'srd:chaotic_evil');
    expect(ce.lawChaos, LawChaosAxis.chaotic);
    expect(ce.goodEvil, GoodEvilAxis.evil);
  });

  test('True Neutral named "Neutral" with both axes neutral', () {
    final n = alignments.firstWhere((a) => a.id == 'srd:true_neutral');
    expect(n.name, 'Neutral');
    expect(n.lawChaos, LawChaosAxis.neutral);
    expect(n.goodEvil, GoodEvilAxis.neutral);
  });

  test('Unaligned uses unaligned axis value on both axes', () {
    final u = alignments.firstWhere((a) => a.id == 'srd:unaligned');
    expect(u.lawChaos, LawChaosAxis.unaligned);
    expect(u.goodEvil, GoodEvilAxis.unaligned);
  });
}
