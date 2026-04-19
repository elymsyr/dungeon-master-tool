import 'dart:io';

import 'package:dungeon_master_tool/data/storage/legacy_data_purger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('purger_');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<LegacyDataPurger> build({
    Map<String, Object> prefsSeed = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsSeed);
    final prefs = await SharedPreferences.getInstance();
    return LegacyDataPurger(cacheRoot: tempRoot.path, prefs: prefs);
  }

  group('LegacyDataPurger', () {
    test('no-op on clean cache reports empty removals', () async {
      final purger = await build();
      final report = await purger.purge();
      expect(report.hasAnyRemovals, false);
      expect(report.removedPaths, isEmpty);
      expect(report.removedPrefsKeys, isEmpty);
    });

    test('removes templates / package_cache_v4 / rule_eval_cache dirs',
        () async {
      for (final sub in ['templates', 'package_cache_v4', 'rule_eval_cache']) {
        final dir = Directory(p.join(tempRoot.path, sub));
        await dir.create(recursive: true);
        await File(p.join(dir.path, 'sample.bin')).writeAsString('x');
      }
      // A non-legacy dir should NOT be touched.
      final safe = Directory(p.join(tempRoot.path, 'keep_me'));
      await safe.create();
      await File(p.join(safe.path, 'data.txt')).writeAsString('y');

      final purger = await build();
      final report = await purger.purge();

      expect(report.removedPaths.length, 3);
      for (final sub in ['templates', 'package_cache_v4', 'rule_eval_cache']) {
        expect(Directory(p.join(tempRoot.path, sub)).existsSync(), false);
      }
      expect(safe.existsSync(), true);
      expect(File(p.join(safe.path, 'data.txt')).existsSync(), true);
    });

    test('removes only template_* / rule_* prefs keys', () async {
      final purger = await build(
        prefsSeed: const {
          'template_foo': 'a',
          'template_bar': 'b',
          'rule_cache_42': 1,
          'keep_me': 'c',
          'welcome_seen': true,
        },
      );
      final report = await purger.purge();
      expect(
        report.removedPrefsKeys..sort(),
        <String>['rule_cache_42', 'template_bar', 'template_foo'],
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('keep_me'), 'c');
      expect(prefs.getBool('welcome_seen'), true);
      expect(prefs.containsKey('template_foo'), false);
    });

    test('hasAnyRemovals true when anything removed', () async {
      final purger = await build(prefsSeed: const {'template_a': 1});
      final report = await purger.purge();
      expect(report.hasAnyRemovals, true);
    });

    test('purge is idempotent — second run is a no-op', () async {
      await Directory(p.join(tempRoot.path, 'templates')).create();
      final purger = await build(prefsSeed: const {'rule_x': 1});

      final first = await purger.purge();
      expect(first.hasAnyRemovals, true);

      final second = await purger.purge();
      expect(second.hasAnyRemovals, false);
    });
  });
}
