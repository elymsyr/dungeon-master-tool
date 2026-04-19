import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_hash.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:flutter_test/flutter_test.dart';

Dnd5ePackage _pkg({
  List<CatalogEntry> conds = const [],
  List<SpellEntry> spells = const [],
}) =>
    Dnd5ePackage(
      id: 'pkg-uuid',
      packageIdSlug: 'srd',
      name: 'T',
      version: '1.0.0',
      authorId: 'a',
      authorName: 'A',
      conditions: conds,
      spells: spells,
    );

void main() {
  group('computeContentHash', () {
    test('starts with sha256: and is 64 hex chars', () {
      final h = computeContentHash(_pkg());
      expect(h, startsWith('sha256:'));
      expect(h.substring(7).length, 64);
    });

    test('stable across input order (canonicalization)', () {
      final a = _pkg(conds: const [
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
        CatalogEntry(id: 'prone', name: 'Prone', bodyJson: '{}'),
      ]);
      final b = _pkg(conds: const [
        CatalogEntry(id: 'prone', name: 'Prone', bodyJson: '{}'),
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
      ]);
      expect(computeContentHash(a), computeContentHash(b));
    });

    test('differs when content changes', () {
      final a = _pkg(conds: const [
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
      ]);
      final b = _pkg(conds: const [
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{"x":1}'),
      ]);
      expect(computeContentHash(a), isNot(computeContentHash(b)));
    });

    test('differs when an entry is added', () {
      final empty = _pkg();
      final one = _pkg(conds: const [
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
      ]);
      expect(computeContentHash(empty), isNot(computeContentHash(one)));
    });

    test('metadata is NOT hashed', () {
      final a = _pkg();
      final b = Dnd5ePackage(
        id: 'different-uuid',
        packageIdSlug: 'srd',
        name: 'Totally Different Name',
        version: '9.9.9',
        authorId: 'x',
        authorName: 'X',
      );
      expect(computeContentHash(a), computeContentHash(b));
    });
  });
}
