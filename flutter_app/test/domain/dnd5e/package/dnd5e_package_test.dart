import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dnd5ePackage', () {
    test('throws on invalid slug', () {
      expect(
        () => Dnd5ePackage(
          id: 'a',
          packageIdSlug: 'BAD',
          name: 'n',
          version: 'v',
          authorId: 'a',
          authorName: 'A',
        ),
        throwsArgumentError,
      );
    });

    test('collections are unmodifiable', () {
      final pkg = Dnd5ePackage(
        id: 'a',
        packageIdSlug: 'srd',
        name: 'n',
        version: '1',
        authorId: 'a',
        authorName: 'A',
        conditions: [
          const CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
        ],
      );
      expect(
        () => pkg.conditions.add(
          const CatalogEntry(id: 'x', name: 'x', bodyJson: '{}'),
        ),
        throwsUnsupportedError,
      );
    });

    test('namespaced() rewrites local ids + refs to <slug>:<localId>', () {
      final pkg = Dnd5ePackage(
        id: 'uuid',
        packageIdSlug: 'srd',
        name: 'n',
        version: '1',
        authorId: 'a',
        authorName: 'A',
        conditions: const [
          CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
        ],
        spells: const [
          SpellEntry(
            id: 'fireball',
            name: 'Fireball',
            level: 3,
            schoolId: 'evocation',
            bodyJson: '{}',
          ),
        ],
        items: const [
          ItemEntry(
            id: 'longsword',
            name: 'Longsword',
            itemType: 'weapon',
            rarityId: 'common',
            bodyJson: '{}',
          ),
        ],
        subclasses: const [
          SubclassEntry(
            id: 'evocation_wiz',
            name: 'School of Evocation',
            parentClassId: 'wizard',
            bodyJson: '{}',
          ),
        ],
      );
      final n = pkg.namespaced();
      expect(n.conditions.single.id, 'srd:stunned');
      expect(n.spells.single.id, 'srd:fireball');
      expect(n.spells.single.schoolId, 'srd:evocation');
      expect(n.items.single.id, 'srd:longsword');
      expect(n.items.single.rarityId, 'srd:common');
      expect(n.subclasses.single.id, 'srd:evocation_wiz');
      expect(n.subclasses.single.parentClassId, 'srd:wizard');
    });

    test('namespaced() leaves already-namespaced refs alone', () {
      final pkg = Dnd5ePackage(
        id: 'uuid',
        packageIdSlug: 'homebrew',
        name: 'n',
        version: '1',
        authorId: 'a',
        authorName: 'A',
        spells: const [
          SpellEntry(
            id: 'wintry_bolt',
            name: 'Wintry Bolt',
            level: 1,
            schoolId: 'srd:evocation', // cross-package ref
            bodyJson: '{}',
          ),
        ],
      );
      final n = pkg.namespaced();
      expect(n.spells.single.id, 'homebrew:wintry_bolt');
      expect(n.spells.single.schoolId, 'srd:evocation');
    });

    test('namespaced() is idempotent', () {
      final pkg = Dnd5ePackage(
        id: 'uuid',
        packageIdSlug: 'srd',
        name: 'n',
        version: '1',
        authorId: 'a',
        authorName: 'A',
        conditions: const [
          CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
        ],
      );
      final once = pkg.namespaced();
      final twice = once.namespaced();
      expect(twice.conditions.single.id, once.conditions.single.id);
    });
  });
}
