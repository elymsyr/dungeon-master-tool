// Satırdan karaktere: kolonlar mı kazanıyor, `payload_json` mu?
//
// `_rowToCharacterJson` "kolonlar kanoniktir" diyor ama anahtarları
// `Character.fromJson`'ın okuduğu adlarla yazmak zorunda. Snake_case
// yazıldıklarında hiçbiri okunmuyordu ve blob'daki bayat kopya kazanıyordu —
// hesap silinip sahiplik kolonda düşürülünce karakterler hâlâ silinmiş uid'e
// ait görünüyor, own-only karakter sekmesinde kayboluyorlardı.
//
//   cd flutter_app && flutter test test/data/repositories/character_row_columns_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/character_repository.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late CharacterRepository repo;
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('character_row_columns');
    AppPaths.dataRoot = tmp.path;
    await AppPaths.setUser(null);
    db = openTestDatabase();
    repo = CharacterRepository(db);
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {
      // Windows'ta açık handle kalabiliyor.
    }
  });

  test('kolon bayat payload_json değerini yener', () async {
    await repo.save(const Character(
      id: 'char-1',
      templateId: 't',
      templateName: 'PC',
      worldId: 'w1',
      ownerId: 'dead-uid',
      entity: Entity(
        id: 'char-1',
        categorySlug: 'player_character',
        name: 'Vex',
        fields: {},
      ),
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    ));
    // Payload'a dokunmadan sahipliği düşür — hesap silme akışının
    // (`releaseAccountCharacters`) yaptığının aynısı.
    await db.customUpdate(
      "UPDATE world_characters SET owner_id = NULL, world_id = '' "
      "WHERE id = 'char-1'",
      updates: const {},
    );
    final stale = jsonDecode(
      (await db.customSelect(
        "SELECT payload_json FROM world_characters WHERE id = 'char-1'",
      ).getSingle())
          .read<String>('payload_json'),
    ) as Map<String, dynamic>;
    expect(stale['ownerId'], 'dead-uid', reason: 'blob bilerek bayat kalıyor');

    final loaded = (await repo.loadAll()).single;
    expect(loaded.ownerId, isNull);
    expect(loaded.worldId, isNull);
  });
}
