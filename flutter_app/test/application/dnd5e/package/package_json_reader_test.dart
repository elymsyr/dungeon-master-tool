import 'dart:convert';

import 'package:dungeon_master_tool/application/dnd5e/package/package_json_reader.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PackageJsonReader', () {
    const reader = PackageJsonReader();

    test('parses minimal JSON string', () {
      final json = jsonEncode({
        'id': 'p',
        'packageIdSlug': 'srd',
        'name': 'SRD',
        'version': '1',
        'authorId': 'a',
        'authorName': 'a',
        'catalogs': <String, Object?>{},
        'content': <String, Object?>{},
      });
      final pkg = reader.readJson(json);
      expect(pkg.packageIdSlug, 'srd');
      expect(pkg.name, 'SRD');
    });

    test('rejects malformed JSON', () {
      expect(
        () => reader.readJson('{this is not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-object root', () {
      expect(
        () => reader.readJson('[1, 2, 3]'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PackageJsonWriter', () {
    const writer = PackageJsonWriter();
    const reader = PackageJsonReader();

    test('compact mode emits one-line JSON', () {
      final pkg = Dnd5ePackage(
        id: 'p',
        packageIdSlug: 'srd',
        name: 'SRD',
        version: '1',
        authorId: 'a',
        authorName: 'a',
      );
      final out = writer.writeJson(pkg);
      expect(out.contains('\n'), false);
    });

    test('pretty mode indents and round-trips', () {
      final pkg = Dnd5ePackage(
        id: 'p',
        packageIdSlug: 'srd',
        name: 'SRD',
        version: '1',
        authorId: 'a',
        authorName: 'a',
        conditions: const [
          CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
        ],
      );
      final pretty = writer.writeJson(pkg, pretty: true);
      expect(pretty.contains('\n'), true);
      final back = reader.readJson(pretty);
      expect(back.conditions.single.id, 'stunned');
    });
  });
}
