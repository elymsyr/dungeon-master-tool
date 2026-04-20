import 'package:drift/drift.dart';

/// Doc 50 §Homebrew Entries Table — typed storage for world-content
/// categories that do not map to Tier 2 D&D 5e content tables (quests,
/// locations, lore, planes, status effects). Rows keep a category slug +
/// JSON body; per-category body shape encoded via sealed `HomebrewBody`
/// subtypes (see application layer).
///
/// `id` carries the namespaced prefix (`hb:<uuid>` or
/// `hb:<campaignId>:<uuid>`). `sourcePackageId` defaults to 'homebrew' for
/// user-created rows; imported packages stamp their slug here.
class HomebrewEntries extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().nullable()();
  TextColumn get categorySlug => text()();
  TextColumn get name => text()();
  TextColumn get bodyJson => text()();
  TextColumn get sourcePackageId =>
      text().withDefault(const Constant('homebrew'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
