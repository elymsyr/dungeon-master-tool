import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/entities_table.dart';

part 'entity_dao.g.dart';

@DriftAccessor(tables: [Entities])
class EntityDao extends DatabaseAccessor<AppDatabase> with _$EntityDaoMixin {
  EntityDao(super.db);

  /// Kampanyadaki tüm entity'leri getir.
  Future<List<Entity>> getAllForCampaign(String campaignId) =>
      (select(entities)..where((t) => t.campaignId.equals(campaignId))).get();

  /// Kampanyadaki entity'leri reactive stream olarak izle.
  Stream<List<Entity>> watchAllForCampaign(String campaignId) =>
      (select(entities)..where((t) => t.campaignId.equals(campaignId))).watch();

  /// ID'ye göre tek entity getir.
  Future<Entity?> getById(String id) =>
      (select(entities)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Kategoriye göre entity'leri getir.
  Future<List<Entity>> getByCategory(
          String campaignId, String categorySlug) =>
      (select(entities)
            ..where((t) =>
                t.campaignId.equals(campaignId) &
                t.categorySlug.equals(categorySlug)))
          .get();

  /// Yeni entity oluştur.
  Future<void> createEntity(EntitiesCompanion entity) =>
      into(entities).insert(entity);

  /// Entity güncelle.
  Future<bool> updateEntity(EntitiesCompanion entity) =>
      (update(entities)..where((t) => t.id.equals(entity.id.value)))
          .write(entity)
          .then((rows) => rows > 0);

  /// Entity sil.
  Future<int> deleteEntity(String id) =>
      (delete(entities)..where((t) => t.id.equals(id))).go();

  /// Birden fazla entity'yi batch olarak ekle (migration için).
  Future<void> insertAll(List<EntitiesCompanion> entityList) async {
    await batch((b) {
      b.insertAll(entities, entityList);
    });
  }

  /// Kampanyadaki entity sayısı.
  Future<int> countForCampaign(String campaignId) async {
    final count = entities.id.count();
    final query = selectOnly(entities)
      ..addColumns([count])
      ..where(entities.campaignId.equals(campaignId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
