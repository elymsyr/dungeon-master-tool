// Link-aware world install: the closure is installed, cross-package refs are
// remapped to world ids, and uninstall does not cascade.
//
//   cd flutter_app && flutter test test/application/services/world_package_installer_test.dart

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/package_link_service.dart';
import 'package:dungeon_master_tool/application/services/world_package_installer.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/package_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

const _worldId = 'world-1';

void main() {
  late AppDatabase db;
  late WorldPackageInstaller installer;
  late PackageLinkService links;

  setUp(() async {
    db = openTestDatabase();
    final repo = PackageRepositoryImpl(db);
    installer = WorldPackageInstaller(db, repo);
    links = PackageLinkService(db, repo);

    await db.into(db.worlds).insert(
          WorldsCompanion.insert(id: _worldId, worldName: 'Test World'),
        );
  });

  tearDown(() async => db.close());

  Future<void> makePackage(String name) async {
    await db.packagesDao.upsertPackage(
      PackagesCompanion.insert(id: 'id-$name', name: name),
    );
  }

  Future<void> addEntity(
    String packageName,
    String entityId, {
    required String slug,
    required String name,
    Map<String, dynamic> fields = const {},
  }) async {
    await db.packagesDao.upsertEntity(PackageEntitiesCompanion.insert(
      id: entityId,
      packageId: 'id-$packageName',
      categorySlug: slug,
      name: name,
      fieldsJson: Value(jsonEncode(fields)),
    ));
  }

  Future<WorldEntity?> worldRowFor(String packageEntityId) async {
    final rows = await (db.select(db.worldEntities)
          ..where((t) => t.packageEntityId.equals(packageEntityId)))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<Set<String>> installedPackageNames() async {
    final rows = await db.installedPackagesDao.getByWorld(_worldId);
    return rows.map((r) => r.packageName).toSet();
  }

  group('installIntoWorld', () {
    setUp(() async {
      // B owns a spell; A owns a class whose `spells_known` points at it —
      // exactly what the package editor's reference overlay lets you author.
      await makePackage('A');
      await makePackage('B');
      await addEntity('B', 'b-spell', slug: 'spell', name: 'Fireball');
      await addEntity('A', 'a-class',
          slug: 'class',
          name: 'Pyromancer',
          fields: {
            'spells_known': ['b-spell'],
          });
      await links.addLink('A', 'B');
    });

    test('installs the linked package alongside the requested one', () async {
      final result =
          await installer.installIntoWorld(worldId: _worldId, packageId: 'id-A');

      expect(await installedPackageNames(), {'A', 'B'});
      expect(result.dependencyCount, 1);
      // Dependency order: B is synced before A.
      expect([for (final r in result.installed) r.packageName], ['B', 'A']);
      expect(result.added, 2);
    });

    test('remaps a ref into the linked package to its world-side id',
        () async {
      await installer.installIntoWorld(worldId: _worldId, packageId: 'id-A');

      final classRow = await worldRowFor('a-class');
      final spellRow = await worldRowFor('b-spell');
      expect(classRow, isNotNull);
      expect(spellRow, isNotNull);

      final fields =
          jsonDecode(classRow!.fieldsJson) as Map<String, dynamic>;
      expect(
        fields['spells_known'],
        [spellRow!.id],
        reason: 'the pack-side id must not survive into the world',
      );
      expect(fields['spells_known'], isNot(contains('b-spell')));
    });

    test('is idempotent — a second run adds nothing', () async {
      await installer.installIntoWorld(worldId: _worldId, packageId: 'id-A');
      final again =
          await installer.installIntoWorld(worldId: _worldId, packageId: 'id-A');

      expect(again.added, 0);
      final rows = await (db.select(db.worldEntities)
            ..where((t) => t.worldId.equals(_worldId)))
          .get();
      expect(rows.length, 2);
    });

    test('a dangling link does not block the install', () async {
      await makePackage('Solo');
      await addEntity('Solo', 'solo-1', slug: 'spell', name: 'Spark');
      // Point at a package that was never installed on this device.
      await db.packagesDao.upsertPackage(PackagesCompanion(
        id: const Value('id-Solo'),
        name: const Value('Solo'),
        stateJson: Value(jsonEncode({
          'links': [
            {'package_id': 'id-Ghost', 'name': 'Ghost'},
          ],
        })),
      ));

      final result = await installer.installIntoWorld(
          worldId: _worldId, packageId: 'id-Solo');
      expect(result.installed.single.packageName, 'Solo');
      expect(await installedPackageNames(), {'Solo'});
    });

    test('an unknown package id is a no-op', () async {
      final result = await installer.installIntoWorld(
          worldId: _worldId, packageId: 'nope');
      expect(result.installed, isEmpty);
      expect(await installedPackageNames(), isEmpty);
    });
  });

  group('uninstallFromWorld', () {
    test('removes only the requested package — dependencies stay', () async {
      await makePackage('A');
      await makePackage('B');
      await addEntity('B', 'b-spell', slug: 'spell', name: 'Fireball');
      await addEntity('A', 'a-class', slug: 'class', name: 'Pyromancer');
      await links.addLink('A', 'B');
      await installer.installIntoWorld(worldId: _worldId, packageId: 'id-A');

      await installer.uninstallFromWorld(
          worldId: _worldId, packageId: 'id-A');

      expect(await installedPackageNames(), {'B'},
          reason: 'the linked package is not cascaded away');
      expect(await worldRowFor('a-class'), isNull);
      expect(await worldRowFor('b-spell'), isNotNull);
    });
  });

  group('buildForeignRefIndex', () {
    test('maps every installed package-entity id to its world id', () async {
      await makePackage('B');
      await addEntity('B', 'b-spell', slug: 'spell', name: 'Fireball');
      await installer.installIntoWorld(worldId: _worldId, packageId: 'id-B');

      final index = await installer.buildForeignRefIndex(_worldId);
      final spellRow = await worldRowFor('b-spell');
      expect(index['b-spell'], spellRow!.id);
    });

    test('is empty for a world with nothing installed', () async {
      expect(await installer.buildForeignRefIndex(_worldId), isEmpty);
    });
  });
}
