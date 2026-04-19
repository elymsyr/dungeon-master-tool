import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';

/// Doc 15 attribution surface — denormalized view of every typed package
/// installed for the active user. Read by the About / Attributions screen
/// (CC BY 4.0 compliance) and by any UI that wants to surface "what's
/// installed" without depending on the importer's internal report shape.
///
/// `name` + `version` are the human-facing identity. `authorName` +
/// `sourceLicense` are the legally required attribution. `description`
/// optionally narrates the package.
class InstalledPackageAttribution {
  final String id;
  final String packageIdSlug;
  final String sourcePackageId;
  final String name;
  final String version;
  final String gameSystemId;
  final String authorName;
  final String sourceLicense;
  final String? description;
  final DateTime installedAt;

  const InstalledPackageAttribution({
    required this.id,
    required this.packageIdSlug,
    required this.sourcePackageId,
    required this.name,
    required this.version,
    required this.gameSystemId,
    required this.authorName,
    required this.sourceLicense,
    required this.description,
    required this.installedAt,
  });

  factory InstalledPackageAttribution.fromRow(InstalledPackage row) {
    return InstalledPackageAttribution(
      id: row.id,
      packageIdSlug: row.packageIdSlug,
      sourcePackageId: row.sourcePackageId,
      name: row.name,
      version: row.version,
      gameSystemId: row.gameSystemId,
      authorName: row.authorName,
      sourceLicense: row.sourceLicense,
      description: row.description,
      installedAt: row.installedAt,
    );
  }
}

/// Reads `installed_packages` rows for the active user, sorted by name.
final installedAttributionsProvider =
    FutureProvider<List<InstalledPackageAttribution>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.installedPackages)
    ..orderBy([(t) => OrderingTerm(expression: t.name)]);
  final rows = await query.get();
  return rows.map(InstalledPackageAttribution.fromRow).toList(growable: false);
});
