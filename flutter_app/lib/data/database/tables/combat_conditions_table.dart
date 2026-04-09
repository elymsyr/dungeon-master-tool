import 'package:drift/drift.dart';

import 'combatants_table.dart';

/// Supabase mirror: combat_conditions tablosu.
class CombatConditions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get combatantId => text().references(Combatants, #id)();
  TextColumn get name => text()();
  IntColumn get duration => integer().nullable()();
  IntColumn get initialDuration => integer().nullable()();
  TextColumn get entityId => text().nullable()();
}
