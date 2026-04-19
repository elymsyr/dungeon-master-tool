import 'dart:io';

import 'package:dungeon_master_tool/data/storage/legacy_data_purger.dart';
import 'package:dungeon_master_tool/data/storage/v5_reset_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('v5boot_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  V5ResetBootstrap build() {
    return V5ResetBootstrap(
      cacheRoot: tempRoot.path,
      prefsLoader: SharedPreferences.getInstance,
    );
  }

  group('V5ResetBootstrap', () {
    test('alreadyComplete when flag is set', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LegacyDataPurger.resetCompleteFlag: true,
      });
      final out = await build().runIfNeeded();
      expect(out.status, V5ResetStatus.alreadyComplete);
      expect(out.shouldShowUpgradeNotice, false);
      expect(out.report, isNull);
    });

    test('freshInstall when no flag, nothing to purge', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final out = await build().runIfNeeded();
      expect(out.status, V5ResetStatus.freshInstall);
      expect(out.shouldShowUpgradeNotice, false);
      expect(out.report?.hasAnyRemovals, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(LegacyDataPurger.resetCompleteFlag), true);
    });

    test('upgradedFromV4 when legacy cache exists', () async {
      await Directory(p.join(tempRoot.path, 'templates')).create();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'template_abc': 'x',
      });

      final out = await build().runIfNeeded();
      expect(out.status, V5ResetStatus.upgradedFromV4);
      expect(out.shouldShowUpgradeNotice, true);
      expect(out.report?.hasAnyRemovals, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(LegacyDataPurger.resetCompleteFlag), true);
    });

    test('second run after upgrade short-circuits', () async {
      await Directory(p.join(tempRoot.path, 'templates')).create();
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final bootstrap = build();
      final first = await bootstrap.runIfNeeded();
      expect(first.status, V5ResetStatus.upgradedFromV4);

      final second = await bootstrap.runIfNeeded();
      expect(second.status, V5ResetStatus.alreadyComplete);
    });

    test('legacyDbPath triggers backup before purge and surfaces path',
        () async {
      await Directory(p.join(tempRoot.path, 'templates')).create();
      final dbFile = File(p.join(tempRoot.path, 'dmt.sqlite'));
      await dbFile.writeAsBytes(<int>[7, 7, 7]);
      SharedPreferences.setMockInitialValues(<String, Object>{});

      var backupCalled = false;
      String? receivedPath;
      final bootstrap = V5ResetBootstrap(
        cacheRoot: tempRoot.path,
        legacyDbPath: dbFile.path,
        backupV4Db: (path) async {
          backupCalled = true;
          receivedPath = path;
          return '$path.v4.backup.sqlite';
        },
      );

      final out = await bootstrap.runIfNeeded();
      expect(backupCalled, true);
      expect(receivedPath, dbFile.path);
      expect(out.backupPath, '${dbFile.path}.v4.backup.sqlite');
      expect(out.status, V5ResetStatus.upgradedFromV4);
    });

    test('no legacyDbPath = no backup attempt + null backupPath', () async {
      await Directory(p.join(tempRoot.path, 'templates')).create();
      SharedPreferences.setMockInitialValues(<String, Object>{});

      var backupCalled = false;
      final bootstrap = V5ResetBootstrap(
        cacheRoot: tempRoot.path,
        backupV4Db: (_) async {
          backupCalled = true;
          return 'should-not-be-called';
        },
      );

      final out = await bootstrap.runIfNeeded();
      expect(backupCalled, false);
      expect(out.backupPath, isNull);
    });

    test('alreadyComplete short-circuit skips backup', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        LegacyDataPurger.resetCompleteFlag: true,
      });

      var backupCalled = false;
      final bootstrap = V5ResetBootstrap(
        cacheRoot: tempRoot.path,
        legacyDbPath: '/some/path/dmt.sqlite',
        backupV4Db: (_) async {
          backupCalled = true;
          return null;
        },
      );

      final out = await bootstrap.runIfNeeded();
      expect(backupCalled, false);
      expect(out.status, V5ResetStatus.alreadyComplete);
      expect(out.backupPath, isNull);
    });
  });
}
