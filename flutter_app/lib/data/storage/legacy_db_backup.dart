import 'dart:io';

import 'package:path/path.dart' as p;

/// Pre-purge / pre-destructive-migration safety net for the v4 SQLite file.
///
/// On the first launch that performs the v4→v5 reset (and, when Doc 04
/// Step 7 ships, the v8→v9 destructive `onUpgrade` that drops legacy
/// tables), the prior `dmt.sqlite` is preserved as `dmt.v4.backup.sqlite`
/// next to the original. The user can recover it manually if needed; the
/// runtime never reads it back.
///
/// Pure — no globals. Caller owns path resolution so tests run on a
/// temp dir without touching real app data. All errors are swallowed
/// and the helper returns `null` rather than throwing — startup must
/// never fail because the backup attempt could not complete (locked file
/// on Windows, ENOSPC, etc.).
class LegacyDbBackup {
  /// File-name suffix appended next to the original DB. Kept short so
  /// `ls` output stays scannable.
  static const String backupSuffix = '.v4.backup.sqlite';

  /// Copies the SQLite file at [dbPath] to `<dbPath>.v4.backup.sqlite`
  /// (sibling, same directory). Returns the backup path on success,
  /// `null` if [dbPath] does not exist, the backup already exists
  /// (idempotent), or any I/O step fails.
  static Future<String?> backup(String dbPath) async {
    try {
      final src = File(dbPath);
      if (!await src.exists()) return null;

      final dir = p.dirname(dbPath);
      final base = p.basenameWithoutExtension(dbPath);
      final dst = File(p.join(dir, '$base$backupSuffix'));
      if (await dst.exists()) return dst.path;

      await src.copy(dst.path);
      return dst.path;
    } catch (_) {
      return null;
    }
  }
}
