import 'package:drift/drift.dart';

/// Shared shape for Tier 1 catalog rows (Doc 03 §Catalog tables).
///
/// Rows are populated by the package importer (Doc 14); the built-in dnd5e
/// module seeds zero rows. `id` is always namespaced (`<packageSlug>:<localId>`).
/// `sourcePackageId` lets "uninstall package X" cascade a bulk delete.
abstract class _CatalogTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get bodyJson => text()();
  TextColumn get sourcePackageId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Conditions extends _CatalogTable {}

class DamageTypes extends _CatalogTable {}

class Skills extends _CatalogTable {}

class Sizes extends _CatalogTable {}

class CreatureTypes extends _CatalogTable {}

class Alignments extends _CatalogTable {}

class Languages extends _CatalogTable {}

class SpellSchools extends _CatalogTable {}

class WeaponProperties extends _CatalogTable {}

class WeaponMasteries extends _CatalogTable {}

class ArmorCategories extends _CatalogTable {}

class Rarities extends _CatalogTable {}
