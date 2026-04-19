import 'package:drift/drift.dart';

/// Doc 03 typed D&D 5e content tables. JSON-blob storage for the read-mostly
/// catalog half — whole entity loaded for display, no per-field SQL queries
/// beyond id/name/level/school/itemType. Shape evolves without DB migration.

class Monsters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sourcePackageId => text().nullable()();
  TextColumn get statBlockJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Spells extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get level => integer()();
  TextColumn get schoolId => text()();
  TextColumn get sourcePackageId => text().nullable()();
  TextColumn get bodyJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get itemType =>
      text()(); // 'weapon'|'armor'|'shield'|'gear'|'magic'|'tool'|'ammo'
  TextColumn get rarityId => text().nullable()();
  TextColumn get sourcePackageId => text().nullable()();
  TextColumn get bodyJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

abstract class _NamedJsonTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get bodyJson => text()();
  TextColumn get sourcePackageId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Feats extends _NamedJsonTable {}

class Backgrounds extends _NamedJsonTable {}

class SpeciesCatalog extends _NamedJsonTable {
  @override
  String? get tableName => 'species';
}

class Subclasses extends _NamedJsonTable {
  TextColumn get parentClassId => text()();
}

class ClassProgressions extends _NamedJsonTable {}
