import 'package:drift/drift.dart';

/// Supabase mirror: campaigns tablosu.
class Campaigns extends Table {
  TextColumn get id => text()();
  TextColumn get worldName => text()();
  /// Combat state, map data, mind maps gibi henüz normalize edilmemiş
  /// alanları bir JSON blob olarak tutar (schema v2).
  /// Gelecekte Supabase migration'ında normalize edilecek.
  TextColumn get stateJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
