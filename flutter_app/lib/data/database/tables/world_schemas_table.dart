import 'package:drift/drift.dart';

import 'campaigns_table.dart';

/// Supabase mirror: world_schemas tablosu.
/// categories, encounter_config, encounter_layouts → jsonb columns.
class WorldSchemas extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().references(Campaigns, #id)();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get version => text().withDefault(const Constant('1.0'))();
  TextColumn get baseSystem => text().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get categoriesJson => text().withDefault(const Constant('[]'))();
  TextColumn get encounterConfigJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get encounterLayoutsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  /// `schemaId` of the source template this campaign-scoped schema was
  /// derived from. Null on legacy rows; loaders fall back to
  /// `'builtin-dnd5e-default'`.
  TextColumn get templateId => text().nullable()();
  /// "Current" content hash of the source template at the time this row
  /// was last synced. Compared against the source template's freshly
  /// recomputed current hash on campaign open to detect drift and prompt
  /// the user.
  TextColumn get templateHash => text().nullable()();
  /// Frozen content hash of the source template AT FIRST CREATION — the
  /// stable lineage identifier. Survives template edits, so the lazy
  /// template-sync flow can match a campaign back to the right template
  /// even after its schemaId / current hash change. Computed purely from
  /// canonical JSON of gameplay-affecting fields, so it is "global" —
  /// two installs that generate the same template land on the same
  /// originalHash. Nullable for legacy rows; backfilled lazily on next
  /// successful drift sync.
  TextColumn get templateOriginalHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
