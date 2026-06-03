import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';

/// Set of package ids installed into [worldId] (built-in SRD + custom/official
/// add-on packages, materialized via `_materializeSharedPackageLocally` or the
/// DM share path). Reactive stream so consumers (e.g. [visibleEntityProvider])
/// live-update when a package is materialized or uninstalled.
final installedWorldPackageIdsProvider =
    StreamProvider.family<Set<String>, String>((ref, worldId) {
  final db = ref.watch(appDatabaseProvider);
  return db.installedPackagesDao
      .watchByWorld(worldId)
      .map((rows) => rows.map((r) => r.packageId).toSet());
});
