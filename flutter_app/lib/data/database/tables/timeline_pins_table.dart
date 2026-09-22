import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Local-only.
class TimelinePins extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  RealColumn get x => real()();
  RealColumn get y => real()();
  IntColumn get day => integer().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get entityIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get sessionId => text().nullable()();
  TextColumn get parentIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get color => text().withDefault(const Constant(''))();

  /// Faz 4 — **düzenlemenin istemcideki zamanı** (§2.8). Push taramasının
  /// ("watermark'tan sonra değişenler") tek girdisi; DAO upsert'i damgalar.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
