import 'dart:io';

import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw;

import '../../support/test_database.dart';

/// **Audit phase O5 — the workspace that came back from the dead.**
///
/// O4 retires a spent guest tree by *moving* `db/dmt.sqlite` into
/// `guest_archive/`, so "there is no database here" became a routine state
/// rather than a first-install one. Two things in `_openConnectionForUser` read
/// that state as "fresh install" and between them resurrected an ancient
/// database into the signed-out workspace: the pre-Apr-2026 support-directory
/// import re-fired, and the v12 cut let the imported file through because its
/// `.v12_cut_applied` marker was already in the directory.
///
/// Measured on the reporter's device: the guest workspace came back holding a
/// **schema v5** file (`map_pins.campaign_id`, no `world_id`), Drift ran
/// `onUpgrade`, `createAll()` left the ancient tables alone, and the first
/// index statement threw `no such column: world_id` — the hub rendered a
/// SqliteException where the world list belongs.
///
/// The import guard cannot be exercised here (`path_provider` has no support
/// directory under `flutter test`), so what is pinned is the stronger of the
/// two rules: **a pre-v12 file is cut, marker or no marker.**
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('o5_pre_v12');
    AppPaths.dataRoot = tmp.path;
    registerSqliteFallback();
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {
      // Windows holds sqlite handles a moment longer than the test does.
    }
  });

  File guestDb() => File(p.join(tmp.path, 'db', 'dmt.sqlite'));

  /// A database from before the v12 cut: old `user_version`, old table shape.
  void seedPreV12Database() {
    guestDb().parent.createSync(recursive: true);
    final db = raw.sqlite3.open(guestDb().path);
    db.execute('PRAGMA user_version = 5');
    db.execute('CREATE TABLE map_pins ('
        'id TEXT NOT NULL PRIMARY KEY, campaign_id TEXT NOT NULL, '
        'x REAL NOT NULL, y REAL NOT NULL)');
    db.execute("INSERT INTO map_pins VALUES ('p1', 'c1', 1.0, 2.0)");
    db.dispose();
  }

  test('a pre-v12 file that arrives after the cut marker is still cut',
      () async {
    seedPreV12Database();
    // The directory has been past the cut already — this is exactly the state
    // a retired guest workspace is in.
    await File(p.join(tmp.path, 'db', '.v12_cut_applied'))
        .writeAsString('fresh v12');

    final db = AppDatabase.forUser(null);
    // Opening is the assertion: on the shipped build this threw
    // `SqliteException(1): no such column: world_id`.
    expect(await db.select(db.worlds).get(), isEmpty);
    // The v12 shape is the one that survived.
    final pins = await db.customSelect('PRAGMA table_info("map_pins")').get();
    expect(
      [for (final r in pins) r.read<String>('name')],
      contains('world_id'),
    );
    await db.close();

    // The old file is kept as a forensic backup, exactly as the cut does.
    final backups = Directory(p.join(tmp.path, 'db'))
        .listSync()
        .map((e) => p.basename(e.path))
        .where((n) => n.startsWith('dmt.sqlite.legacy.'))
        .toList();
    expect(backups, hasLength(1));
  });

  test('a v12 file is left alone', () async {
    final seeded = openTestDatabaseAt(guestDb());
    await seeded
        .into(seeded.worlds)
        .insert(WorldsCompanion.insert(id: 'w1', worldName: 'Barrowmoor'));
    await seeded.close();
    await File(p.join(tmp.path, 'db', '.v12_cut_applied'))
        .writeAsString('fresh v12');

    final db = AppDatabase.forUser(null);
    expect((await db.select(db.worlds).get()).single.worldName, 'Barrowmoor');
    await db.close();
  });
}
