import 'package:drift/drift.dart';

import 'campaigns_table.dart';

/// Tracks packages installed into a campaign. Live link enables sync:
/// pack add/update/remove propagates to linked entities. Detached entities
/// (user-edited) survive package removal as homebrew copies.
class InstalledPackages extends Table {
  TextColumn get campaignId => text().references(Campaigns, #id)();
  TextColumn get packageId => text()();
  TextColumn get packageName => text().withDefault(const Constant(''))();
  TextColumn get packageVersion => text().withDefault(const Constant(''))();
  DateTimeColumn get installedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {campaignId, packageId};
}
