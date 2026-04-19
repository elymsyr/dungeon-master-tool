import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Report of what a [LegacyDataPurger] run actually removed.
class PurgeReport {
  final List<String> removedPaths;
  final List<String> removedPrefsKeys;

  const PurgeReport({
    required this.removedPaths,
    required this.removedPrefsKeys,
  });

  bool get isEmpty => removedPaths.isEmpty && removedPrefsKeys.isEmpty;
  bool get hasAnyRemovals => !isEmpty;
}

/// Purges v4 template-system caches and prefs keys on v5 first-launch.
///
/// Pure — no globals. Callers supply the cache root and a prefs instance so
/// tests can run it on a temp dir without touching real app state.
///
/// See [docs/engineering/42-fresh-start-db-reset.md](../../../../docs/engineering/42-fresh-start-db-reset.md).
class LegacyDataPurger {
  /// Sub-directories under [cacheRoot] that v4 used for template/rule caches.
  /// Missing dirs are silently skipped; no error is raised.
  static const List<String> _legacyCacheDirs = <String>[
    'templates',
    'package_cache_v4',
    'rule_eval_cache',
  ];

  /// Prefs-key prefixes used by v4's template + rule-engine layers.
  static const List<String> _legacyPrefsPrefixes = <String>[
    'template_',
    'rule_',
  ];

  final String cacheRoot;
  final SharedPreferences prefs;

  const LegacyDataPurger({required this.cacheRoot, required this.prefs});

  Future<PurgeReport> purge() async {
    final removedPaths = <String>[];
    for (final sub in _legacyCacheDirs) {
      final dir = Directory(p.join(cacheRoot, sub));
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
          removedPaths.add(dir.path);
        } catch (_) {
          // Best-effort — a locked file on Windows should not block startup.
        }
      }
    }

    final removedPrefsKeys = <String>[];
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (_legacyPrefsPrefixes.any(key.startsWith)) {
        if (await prefs.remove(key)) {
          removedPrefsKeys.add(key);
        }
      }
    }

    return PurgeReport(
      removedPaths: removedPaths,
      removedPrefsKeys: removedPrefsKeys,
    );
  }

  /// Key persisted after a successful first-launch purge. If already `true`,
  /// [AppBootstrap.runV5ResetIfNeeded] skips the purger entirely.
  static const String resetCompleteFlag = 'v5_reset_complete';
}
