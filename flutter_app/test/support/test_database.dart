import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:sqlite3/open.dart';

/// Opens an in-memory [AppDatabase] for tests.
///
/// `package:sqlite3` defaults to `DynamicLibrary.open('libsqlite3.so')`, which
/// only exists when the *development* package (`libsqlite3-dev`) is installed.
/// Plenty of Linux boxes ship only the runtime `libsqlite3.so.0`, where every
/// Drift-backed test dies with "Failed to load dynamic library". Register a
/// resolver that falls back to the versioned name so these tests run without
/// an extra apt install; on a machine that has the symlink this is a no-op.
AppDatabase openTestDatabase() {
  _registerSqliteFallback();
  return AppDatabase.forTesting(NativeDatabase.memory());
}

var _registered = false;

void _registerSqliteFallback() {
  if (_registered || !Platform.isLinux) return;
  _registered = true;
  open.overrideFor(OperatingSystem.linux, () {
    for (final name in const [
      'libsqlite3.so',
      'libsqlite3.so.0',
    ]) {
      try {
        return DynamicLibrary.open(name);
      } on ArgumentError {
        continue;
      }
    }
    // Nothing found — let the default path raise its own clearer error.
    return DynamicLibrary.open('libsqlite3.so');
  });
}
