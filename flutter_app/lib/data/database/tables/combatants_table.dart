import 'package:drift/drift.dart';

import 'encounters_table.dart';
import 'world_entities_table.dart';

/// Local-only.
class Combatants extends Table {
  TextColumn get id => text()();
  TextColumn get encounterId => text().references(Encounters, #id)();
  TextColumn get entityId =>
      text().nullable().references(WorldEntities, #id)();
  TextColumn get name => text()();
  IntColumn get init => integer().withDefault(const Constant(0))();
  IntColumn get ac => integer().withDefault(const Constant(10))();
  IntColumn get hp => integer().withDefault(const Constant(10))();
  IntColumn get maxHp => integer().withDefault(const Constant(10))();
  TextColumn get tokenId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
