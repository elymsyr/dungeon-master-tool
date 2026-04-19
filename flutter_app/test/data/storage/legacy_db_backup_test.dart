import 'dart:io';

import 'package:dungeon_master_tool/data/storage/legacy_db_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('legacy_db_backup_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  String dbPath() => p.join(tempRoot.path, 'dmt.sqlite');
  String backupPath() => p.join(tempRoot.path, 'dmt${LegacyDbBackup.backupSuffix}');

  group('LegacyDbBackup.backup', () {
    test('returns null when source DB does not exist', () async {
      final result = await LegacyDbBackup.backup(dbPath());
      expect(result, isNull);
      expect(await File(backupPath()).exists(), false);
    });

    test('copies DB to sibling .v4.backup.sqlite when source exists',
        () async {
      await File(dbPath()).writeAsBytes(<int>[1, 2, 3, 4, 5]);

      final result = await LegacyDbBackup.backup(dbPath());

      expect(result, backupPath());
      expect(await File(backupPath()).exists(), true);
      expect(
          await File(backupPath()).readAsBytes(), <int>[1, 2, 3, 4, 5]);
    });

    test('idempotent — second call returns same path without overwriting',
        () async {
      await File(dbPath()).writeAsBytes(<int>[9, 9, 9]);
      final first = await LegacyDbBackup.backup(dbPath());
      // Mutate source to prove we don't overwrite the backup.
      await File(dbPath()).writeAsBytes(<int>[1, 1, 1]);
      final second = await LegacyDbBackup.backup(dbPath());

      expect(first, second);
      expect(await File(backupPath()).readAsBytes(), <int>[9, 9, 9]);
    });

    test('returns null and does not throw when path is invalid', () async {
      // /dev/null/foo on Linux is unwritable; on other platforms a
      // path with a NUL byte is rejected by dart:io. Both should return
      // null without throwing.
      final result = await LegacyDbBackup.backup('\u0000not-a-real-path');
      expect(result, isNull);
    });
  });
}
