import 'package:drift/drift.dart';

import 'world_sessions_table.dart';
import 'worlds_table.dart';

/// Local-only — no Postgres counterpart. FKs follow v12 rename.
class Encounters extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(WorldSessions, #id)();
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get name => text()();
  TextColumn get mapPath => text().nullable()();
  IntColumn get tokenSize => integer().withDefault(const Constant(40))();
  IntColumn get gridSize => integer().withDefault(const Constant(50))();
  BoolColumn get gridVisible =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get gridSnap => boolean().withDefault(const Constant(true))();
  IntColumn get feetPerCell => integer().withDefault(const Constant(5))();
  TextColumn get fogData => text().nullable()();
  TextColumn get annotationData => text().nullable()();
  TextColumn get encounterLayoutId => text().nullable()();
  IntColumn get turnIndex => integer().withDefault(const Constant(-1))();
  IntColumn get round => integer().withDefault(const Constant(1))();
  TextColumn get tokenPositionsJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get tokenSizeMultipliersJson =>
      text().withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
