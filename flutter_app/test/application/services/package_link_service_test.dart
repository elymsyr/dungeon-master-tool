// Package→package link graph: closure order, cycle safety, dangling links,
// reverse lookup.
//
//   cd flutter_app && flutter test test/application/services/package_link_service_test.dart

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/package_link_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/package_repository_impl.dart';
import 'package:dungeon_master_tool/domain/entities/package_link.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late PackageLinkService links;

  setUp(() {
    db = openTestDatabase();
    links = PackageLinkService(db, PackageRepositoryImpl(db));
  });

  tearDown(() async => db.close());

  Future<void> makePackage(String name, {String? id}) async {
    await db.packagesDao.upsertPackage(
      PackagesCompanion.insert(id: id ?? 'id-$name', name: name),
    );
  }

  /// Writes links straight into `state_json`, bypassing the cycle/self checks
  /// in [PackageLinkService.addLink] — lets us build graphs the UI refuses to.
  Future<void> forceLinks(String name, List<String> targetNames) async {
    final pkg = await db.packagesDao.getByName(name);
    await db.packagesDao.upsertPackage(PackagesCompanion(
      id: Value(pkg!.id),
      name: Value(name),
      stateJson: Value(jsonEncode({
        'links': [
          for (final t in targetNames) {'package_id': 'id-$t', 'name': t},
        ],
      })),
    ));
  }

  Future<List<String>> closureNames(String name) async =>
      [for (final p in await links.closure(name)) p.name];

  group('parseLinks', () {
    test('reads top-level links and metadata.links alike', () {
      final top = PackageLinkService.parseLinks(jsonEncode({
        'links': [
          {'package_id': 'x', 'name': 'X'},
        ],
      }));
      final nested = PackageLinkService.parseLinks(jsonEncode({
        'metadata': {
          'links': [
            {'package_id': 'x', 'name': 'X'},
          ],
        },
      }));
      expect(top, [const PackageLink(packageId: 'x', name: 'X')]);
      expect(nested, top);
    });

    test('drops malformed entries instead of throwing', () {
      final parsed = PackageLinkService.parseLinks(jsonEncode({
        'links': [
          'nonsense',
          {'unrelated': 1},
          {'name': 'Good'},
        ],
      }));
      expect(parsed, [const PackageLink(packageId: '', name: 'Good')]);
    });

    test('tolerates empty and corrupt state_json', () {
      expect(PackageLinkService.parseLinks(''), isEmpty);
      expect(PackageLinkService.parseLinks('{}'), isEmpty);
      expect(PackageLinkService.parseLinks('not json'), isEmpty);
    });
  });

  group('closure', () {
    test('returns dependencies first, the root last', () async {
      // A → B → D, A → C
      for (final n in ['A', 'B', 'C', 'D']) {
        await makePackage(n);
      }
      await forceLinks('A', ['B', 'C']);
      await forceLinks('B', ['D']);

      final order = await closureNames('A');
      expect(order.last, 'A');
      expect(order.toSet(), {'A', 'B', 'C', 'D'});
      expect(order.indexOf('D'), lessThan(order.indexOf('B')));
      expect(order.indexOf('B'), lessThan(order.indexOf('A')));
      expect(order.indexOf('C'), lessThan(order.indexOf('A')));
    });

    test('a cycle terminates and emits each package once', () async {
      await makePackage('A');
      await makePackage('B');
      await forceLinks('A', ['B']);
      await forceLinks('B', ['A']);

      final order = await closureNames('A');
      expect(order.toSet(), {'A', 'B'});
      expect(order.length, 2);
    });

    test('a self-link is ignored', () async {
      await makePackage('A');
      await forceLinks('A', ['A']);
      expect(await closureNames('A'), ['A']);
    });

    test('a dangling link is skipped, not fatal', () async {
      await makePackage('A');
      await forceLinks('A', ['Missing']);
      expect(await closureNames('A'), ['A']);
    });

    test('an unknown root yields nothing', () async {
      expect(await closureNames('Nope'), isEmpty);
    });

    test('closureOfAll de-duplicates shared dependencies', () async {
      for (final n in ['A', 'B', 'Shared']) {
        await makePackage(n);
      }
      await forceLinks('A', ['Shared']);
      await forceLinks('B', ['Shared']);

      final order = [for (final p in await links.closureOfAll(['A', 'B'])) p.name];
      expect(order.where((n) => n == 'Shared').length, 1);
      expect(order.toSet(), {'A', 'B', 'Shared'});
      expect(order.indexOf('Shared'), lessThan(order.indexOf('A')));
    });
  });

  group('statusOf', () {
    test('splits resolved targets from dangling links', () async {
      await makePackage('A');
      await makePackage('B');
      await forceLinks('A', ['B', 'Gone']);

      final status = await links.statusOf('A');
      expect([for (final p in status.resolved) p.name], ['B']);
      expect([for (final l in status.dangling) l.name], ['Gone']);
      expect(status.total, 2);
    });

    test('resolves by name when the id is stale', () async {
      await makePackage('B', id: 'fresh-local-id');
      await makePackage('A');
      // Simulates a marketplace download: the payload's package_id is from the
      // publisher's machine, only the human name still matches.
      await forceLinks('A', ['B']);

      final status = await links.statusOf('A');
      expect([for (final p in status.resolved) p.id], ['fresh-local-id']);
      expect(status.dangling, isEmpty);
    });
  });

  group('reverseLinks', () {
    test('finds every package linking the target', () async {
      for (final n in ['A', 'B', 'C', 'Target']) {
        await makePackage(n);
      }
      await forceLinks('A', ['Target']);
      await forceLinks('B', ['Target']);
      await forceLinks('C', ['A']);

      final linkers = await links.reverseLinks('Target');
      expect([for (final p in linkers) p.name]..sort(), ['A', 'B']);
    });

    test('is empty for an unlinked package', () async {
      await makePackage('Lonely');
      expect(await links.reverseLinks('Lonely'), isEmpty);
    });
  });

  group('addLink / removeLink', () {
    test('addLink persists and is idempotent', () async {
      await makePackage('A');
      await makePackage('B');

      expect(await links.addLink('A', 'B'), isTrue);
      expect([for (final p in await links.closure('A')) p.name], ['B', 'A']);
      // Second add is a no-op — already linked.
      expect(await links.addLink('A', 'B'), isFalse);
    });

    test('addLink refuses a self-link and a cycle', () async {
      await makePackage('A');
      await makePackage('B');
      await links.addLink('A', 'B');

      expect(await links.addLink('A', 'A'), isFalse);
      expect(await links.addLink('B', 'A'), isFalse, reason: 'would cycle');
      expect(await links.wouldCycle('B', 'A'), isTrue);
      expect(await links.wouldCycle('A', 'B'), isFalse,
          reason: 'already linked, but not a cycle');
    });

    test('removeLink drops the link and leaves content alone', () async {
      await makePackage('A');
      await makePackage('B');
      await links.addLink('A', 'B');

      final linked = (await links.statusOf('A')).resolved.single;
      final removed = await links.removeLink(
        'A',
        PackageLink(packageId: linked.id, name: linked.name),
      );
      expect(removed, isTrue);
      expect((await links.statusOf('A')).isEmpty, isTrue);
      // Both packages still exist.
      expect(await db.packagesDao.getByName('B'), isNotNull);
    });

    test('removeLink of an absent link reports no change', () async {
      await makePackage('A');
      expect(
        await links.removeLink(
            'A', const PackageLink(packageId: 'x', name: 'X')),
        isFalse,
      );
    });

    test('a dangling link can be removed', () async {
      await makePackage('A');
      await forceLinks('A', ['Gone']);

      final dangling = (await links.statusOf('A')).dangling.single;
      expect(await links.removeLink('A', dangling), isTrue);
      expect((await links.statusOf('A')).isEmpty, isTrue);
    });
  });
}
