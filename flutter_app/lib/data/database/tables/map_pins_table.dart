import 'package:drift/drift.dart';

import 'world_entities_table.dart';
import 'worlds_table.dart';

/// Local-only.
class MapPins extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  RealColumn get x => real()();
  RealColumn get y => real()();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get pinType => text().withDefault(const Constant('default'))();
  TextColumn get entityId =>
      text().nullable().references(WorldEntities, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant(''))();
  TextColumn get styleJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
