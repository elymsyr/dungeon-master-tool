import 'package:drift/drift.dart';

/// Per-world package enablement. Row present = package's content is visible
/// in that campaign. Deleting a row hides the package's content in that
/// world without uninstalling the package from the user's DB.
///
/// `campaignId` references `campaigns.id`, `packageId` references
/// `installed_packages.id`. Composite primary key so enablement is
/// idempotent.
class CampaignPackages extends Table {
  TextColumn get campaignId => text()();
  TextColumn get packageId => text()();
  DateTimeColumn get enabledAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {campaignId, packageId};
}
