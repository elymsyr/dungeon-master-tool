import 'package:drift/drift.dart';

/// Registry of installed Doc 14 packages — one row per install. Distinct from
/// the legacy v5 `packages` table (template-coupled) so both can coexist
/// until Doc 04 Step 5 retires the legacy system.
///
/// `sourcePackageId` = the package's own UUID from its metadata (for
/// "already installed" detection in the marketplace). `packageIdSlug` is the
/// slug actually used at install time — may differ from the original when
/// [ConflictResolution.duplicate] appended a suffix (e.g. `srd_2`).
class InstalledPackages extends Table {
  TextColumn get id => text()();
  TextColumn get sourcePackageId => text()();
  TextColumn get packageIdSlug => text()();
  TextColumn get name => text()();
  TextColumn get version => text()();
  TextColumn get gameSystemId => text()();
  TextColumn get authorName => text().withDefault(const Constant(''))();
  TextColumn get sourceLicense => text().withDefault(const Constant(''))();
  TextColumn get description => text().nullable()();
  TextColumn get reportJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get installedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
