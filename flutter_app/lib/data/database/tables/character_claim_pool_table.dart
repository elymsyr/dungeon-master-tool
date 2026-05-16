import 'package:drift/drift.dart';

import 'world_characters_table.dart';
import 'worlds_table.dart';

/// Mirrors Postgres `public.character_claim_pool` (migration 026). DM-marked
/// "available for claim" characters.
class CharacterClaimPool extends Table {
  TextColumn get characterId => text().references(WorldCharacters, #id)();
  TextColumn get worldId => text().references(Worlds, #id)();
  BoolColumn get available => boolean().withDefault(const Constant(true))();
  TextColumn get claimedBy => text().nullable()();
  DateTimeColumn get claimedAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {characterId};
}
