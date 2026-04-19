import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/size.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Size> sizes;

  setUpAll(() {
    final file = File('assets/packages/srd_core/sizes.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    sizes = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return sizeFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 6 SRD sizes parse', () {
    expect(sizes, hasLength(6));
  });

  test('ids namespaced + unique', () {
    for (final s in sizes) {
      expect(s.id, startsWith('srd:'));
    }
    final ids = sizes.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical SRD 6-size set', () {
    final ids = sizes.map((s) => s.id).toSet();
    expect(ids, {
      'srd:tiny',
      'srd:small',
      'srd:medium',
      'srd:large',
      'srd:huge',
      'srd:gargantuan',
    });
  });

  test('Tiny occupies 2.5ft / tokenScale 0.5', () {
    final t = sizes.firstWhere((s) => s.id == 'srd:tiny');
    expect(t.spaceFt, 2.5);
    expect(t.tokenScale, 0.5);
  });

  test('Small and Medium both 5ft / scale 1', () {
    for (final id in ['srd:small', 'srd:medium']) {
      final s = sizes.firstWhere((x) => x.id == id);
      expect(s.spaceFt, 5, reason: id);
      expect(s.tokenScale, 1, reason: id);
    }
  });

  test('Large=10/2, Huge=15/3, Gargantuan=20/4', () {
    final l = sizes.firstWhere((s) => s.id == 'srd:large');
    expect(l.spaceFt, 10);
    expect(l.tokenScale, 2);
    final h = sizes.firstWhere((s) => s.id == 'srd:huge');
    expect(h.spaceFt, 15);
    expect(h.tokenScale, 3);
    final g = sizes.firstWhere((s) => s.id == 'srd:gargantuan');
    expect(g.spaceFt, 20);
    expect(g.tokenScale, 4);
  });

  test('spaceFt monotonic across size order', () {
    final order = ['srd:tiny', 'srd:small', 'srd:medium', 'srd:large', 'srd:huge', 'srd:gargantuan'];
    final ordered = order.map((id) => sizes.firstWhere((s) => s.id == id)).toList();
    for (var i = 1; i < ordered.length; i++) {
      expect(ordered[i].spaceFt, greaterThanOrEqualTo(ordered[i - 1].spaceFt),
          reason: '${ordered[i].id} < ${ordered[i - 1].id}');
    }
  });
}
