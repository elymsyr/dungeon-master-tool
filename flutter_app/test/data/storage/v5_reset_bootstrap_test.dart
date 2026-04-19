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
  });
}
