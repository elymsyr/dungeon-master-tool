import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Tracks packages installed into a world. Live-link enables sync:
/// pack add/update/remove propagates to linked entities. Detached entities
/// (user-edited) survive package removal as homebrew copies.
class InstalledPackages extends Table {
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get packageId => text()();
  TextColumn get packageName => text().withDefault(const Constant(''))();
  TextColumn get packageVersion => text().withDefault(const Constant(''))();
  DateTimeColumn get installedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Faz 4 — **düzenlemenin istemcideki zamanı** (§2.8). Push taramasının
  /// ("watermark'tan sonra değişenler") tek girdisi; DAO upsert'i damgalar.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {worldId, packageId};
}
