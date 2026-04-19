import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_data_purger.dart';

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
  const V5ResetOutcome({required this.status, this.report});

  bool get shouldShowUpgradeNotice => status == V5ResetStatus.upgradedFromV4;
}

/// Glue that wires [LegacyDataPurger] into app startup.
///
/// Idempotent: a successful run sets [LegacyDataPurger.resetCompleteFlag], so
/// subsequent launches short-circuit with [V5ResetStatus.alreadyComplete].
class V5ResetBootstrap {
  final String cacheRoot;
  final Future<SharedPreferences> Function() prefsLoader;

  const V5ResetBootstrap({
    required this.cacheRoot,
    this.prefsLoader = SharedPreferences.getInstance,
  });

  Future<V5ResetOutcome> runIfNeeded() async {
    final prefs = await prefsLoader();
    if (prefs.getBool(LegacyDataPurger.resetCompleteFlag) == true) {
      return const V5ResetOutcome(status: V5ResetStatus.alreadyComplete);
    }

    final purger = LegacyDataPurger(cacheRoot: cacheRoot, prefs: prefs);
    final report = await purger.purge();
    await prefs.setBool(LegacyDataPurger.resetCompleteFlag, true);

    return V5ResetOutcome(
      status: report.hasAnyRemovals
          ? V5ResetStatus.upgradedFromV4
          : V5ResetStatus.freshInstall,
      report: report,
    );
  }
}
