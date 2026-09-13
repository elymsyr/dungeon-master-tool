// Katılınan dünyanın şeması: kabukta snapshot yok — load() ne döner?
//
// `WorldJoinService` yalnızca `worlds` satırını açar; `_world_schema`
// snapshot'ı dünya *oluşturulurken* yazılıyor ve aynalanan tablolardan biri
// değil. Snapshot yoksa load() şema anahtarını hiç koymuyordu, okuyucu da
// legacy v1 varsayılanına düşüyordu: `weapon` / `species` / `subclass` gibi
// Tier-1 slug'ları tanımayan 18 kategori → paylaşılan kartın gövdesi atlanır.
//
//   cd flutter_app && flutter test test/data/repositories/world_joined_schema_fallback_test.dart

import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/world_repository_impl.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('snapshotsuz kabuk → built-in v2 şeması', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    // Katılma yolunun yazdığı kadarı: id + isim, şema yok.
    await db.worldsDao.upsert(WorldsCompanion.insert(
      id: 'w-joined',
      worldName: 'Joined World',
    ));

    final data = await WorldRepositoryImpl(db).load('Joined World');
    final schema = data['world_schema'] as Map<String, dynamic>?;
    expect(schema!['schemaId'], builtinDnd5eV2SchemaId);
    final slugs = {
      for (final c in schema['categories'] as List) (c as Map)['slug'],
    };
    expect(slugs, containsAll(['weapon', 'species', 'subclass']));
  });
}
