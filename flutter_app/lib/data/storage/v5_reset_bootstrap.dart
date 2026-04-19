import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_data_purger.dart';
import 'legacy_db_backup.dart';

/// Outcome of the v5-reset check during bootstrap.
enum V5ResetStatus {
  /// Flag was already `true` — no purge needed, no upgrade dialog shown.
  alreadyComplete,

  /// Purger ran and removed nothing — fresh install. Flag was set; no upgrade
  /// dialog needed.
  freshInstall,

  /// Purger ran and actually deleted legacy data — this device is upgrading
  /// from v4. Dialog should be shown once.
  upgradedFromV4,
}

class V5ResetOutcome {
  final V5ResetStatus status;
  final PurgeReport? report;

  /// Path to the v4 SQLite backup written by [LegacyDbBackup.backup] just
  /// before the purger ran, or `null` when no DB existed / backup was
  /// disabled / the copy failed.
  final String? backupPath;

  const V5ResetOutcome({
    required this.status,
    this.report,
    this.backupPath,
  });

  bool get shouldShowUpgradeNotice => status == V5ResetStatus.upgradedFromV4;
}

/// Glue that wires [LegacyDataPurger] into app startup.
///
/// Idempotent: a successful run sets [LegacyDataPurger.resetCompleteFlag], so
/// subsequent launches short-circuit with [V5ResetStatus.alreadyComplete].
class V5ResetBootstrap {
  final String cacheRoot;
  final Future<SharedPreferences> Function() prefsLoader;

  /// Optional v4 SQLite path. When set, the file is copied to a sibling
  /// `.v4.backup.sqlite` *before* the purger runs (or the destructive
  /// `onUpgrade` migration runs, when Doc 04 Step 7 lands). The resulting
  /// path is propagated to [V5ResetOutcome.backupPath] so the upgrade
  /// dialog can surface it.
  final String? legacyDbPath;

  /// Injectable backup function — defaults to [LegacyDbBackup.backup].
  /// Tests pass a fake to assert call ordering without touching disk.
  final Future<String?> Function(String) backupV4Db;

  const V5ResetBootstrap({
    required this.cacheRoot,
    this.prefsLoader = SharedPreferences.getInstance,
    this.legacyDbPath,
    this.backupV4Db = LegacyDbBackup.backup,
  });

  Future<V5ResetOutcome> runIfNeeded() async {
    final prefs = await prefsLoader();
    if (prefs.getBool(LegacyDataPurger.resetCompleteFlag) == true) {
      return const V5ResetOutcome(status: V5ResetStatus.alreadyComplete);
    }

    String? backupPath;
    if (legacyDbPath != null) {
      backupPath = await backupV4Db(legacyDbPath!);
    }

    final purger = LegacyDataPurger(cacheRoot: cacheRoot, prefs: prefs);
    final report = await purger.purge();
    await prefs.setBool(LegacyDataPurger.resetCompleteFlag, true);

    return V5ResetOutcome(
      status: report.hasAnyRemovals
          ? V5ResetStatus.upgradedFromV4
          : V5ResetStatus.freshInstall,
      report: report,
      backupPath: backupPath,
    );
  }
}
