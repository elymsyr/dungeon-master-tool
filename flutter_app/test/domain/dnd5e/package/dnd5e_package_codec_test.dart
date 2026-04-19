import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package_codec.dart';
import 'package:flutter_test/flutter_test.dart';

Dnd5ePackage _fixture() => Dnd5ePackage(
      id: 'pkg-srd-1',
      packageIdSlug: 'srd',
      name: 'D&D 5e SRD Core Rules',
      version: '1.0.0',
      authorId: 'wotc',
      authorName: 'Wizards of the Coast',
      sourceLicense: 'CC BY 4.0',
      description: 'SRD 5.2.1',
      tags: const ['srd', 'core'],
      requiredRuntimeExtensions: const ['srd:wish'],
      conditions: const [
        CatalogEntry(
            id: 'stunned', name: 'Stunned', bodyJson: '{"description":"..."}'),
      ],
      damageTypes: const [
        CatalogEntry(
            id: 'fire', name: 'Fire', bodyJson: '{"physical":false}'),
      ],
      spells: const [
        SpellEntry(
          id: 'fireball',
          name: 'Fireball',
          level: 3,
          schoolId: 'evocation',
          bodyJson: '{"castingTime":"1 action"}',
        ),
      ],
      monsters: const [
        MonsterEntry(
          id: 'goblin',
          name: 'Goblin',
          statBlockJson: '{"cr":"1/4"}',
        ),
      ],
      items: const [
        ItemEntry(
          id: 'longsword',
          name: 'Longsword',
          itemType: 'weapon',
          bodyJson: '{"damage":"1d8"}',
        ),
        ItemEntry(
          id: 'bag_of_holding',
          name: 'Bag of Holding',
          itemType: 'magic_item',
          rarityId: 'uncommon',
          bodyJson: '{"attunement":false}',
        ),
      ],
      subclasses: const [
        SubclassEntry(
          id: 'champion',
          name: 'Champion',
          parentClassId: 'fighter',
          bodyJson: '{"features":[]}',
        ),
      ],
    );

void main() {
  const codec = Dnd5ePackageCodec();

  group('Dnd5ePackageCodec', () {
    test('round-trips a realistic package through encode → decode', () {
      final pkg = _fixture();
      final json = codec.encode(pkg);
      final back = codec.decode(json);

      expect(back.id, pkg.id);
      expect(back.packageIdSlug, pkg.packageIdSlug);
      expect(back.name, pkg.name);
      expect(back.version, pkg.version);
      expect(back.authorId, pkg.authorId);
      expect(back.authorName, pkg.authorName);
      expect(back.sourceLicense, pkg.sourceLicense);
      expect(back.description, pkg.description);
      expect(back.tags, pkg.tags);
      expect(back.requiredRuntimeExtensions, pkg.requiredRuntimeExtensions);

      expect(back.conditions, pkg.conditions);
      expect(back.damageTypes, pkg.damageTypes);

      expect(back.spells.length, 1);
      expect(back.spells.first.id, 'fireball');
      expect(back.spells.first.level, 3);
      expect(back.spells.first.schoolId, 'evocation');

      expect(back.monsters.single.statBlockJson, '{"cr":"1/4"}');
      expect(back.items.length, 2);
      expect(back.items[1].rarityId, 'uncommon');
      expect(back.subclasses.single.parentClassId, 'fighter');
    });

    test('encode → decode is idempotent (same structure twice)', () {
      final pkg = _fixture();
      final first = codec.decode(codec.encode(pkg));
      final second = codec.decode(codec.encode(first));
      expect(codec.encode(second), codec.encode(first));
    });

    test('defaults applied on minimal payload', () {
      final minimal = <String, Object?>{
        'id': 'x',
        'packageIdSlug': 'x',
        'name': 'x',
        'version': '1',
        'authorId': 'a',
        'authorName': 'a',
        'catalogs': <String, Object?>{},
        'content': <String, Object?>{},
      };
      final pkg = codec.decode(minimal);
      expect(pkg.gameSystemId, 'dnd5e');
      expect(pkg.formatVersion, '2');
      expect(pkg.sourceLicense, '');
      expect(pkg.tags, isEmpty);
      expect(pkg.conditions, isEmpty);
      expect(pkg.spells, isEmpty);
    });

    test('missing required field throws FormatException', () {
      expect(
        () => codec.decode(<String, Object?>{'packageIdSlug': 'srd'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('wrong-type list throws pointed FormatException', () {
      final bad = <String, Object?>{
        'id': 'x',
        'packageIdSlug': 'x',
        'name': 'x',
        'version': '1',
        'authorId': 'a',
        'authorName': 'a',
        'catalogs': <String, Object?>{
          'conditions': 'not a list',
        },
        'content': <String, Object?>{},
      };
      expect(
        () => codec.decode(bad),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"conditions"'),
          ),
        ),
      );
    });

    test('description is preserved as null when absent', () {
      final pkg = Dnd5ePackage(
        id: 'p',
        packageIdSlug: 'p',
        name: 'p',
        version: '1',
        authorId: 'a',
        authorName: 'a',
      );
      final back = codec.decode(codec.encode(pkg));
      expect(back.description, isNull);
    });
  });
}
