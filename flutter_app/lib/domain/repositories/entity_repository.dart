import '../entities/entity.dart';

/// Entity persistence interface.
/// Lokal: Drift (SQLite) implementasyonu.
/// Online: Supabase implementasyonu (future).
abstract class EntityRepository {
  /// Kampanyadaki tüm entity'leri getir.
  Future<List<Entity>> getAll(String campaignId);

  /// Kampanyadaki entity'leri reactive stream olarak izle.
  Stream<List<Entity>> watchAll(String campaignId);

  /// ID'ye göre entity getir.
  Future<Entity?> getById(String id);

  /// Yeni entity oluştur.
  Future<void> create(Entity entity);

  /// Entity güncelle.
  Future<void> update(Entity entity);

  /// Entity sil.
  Future<void> delete(String id);
}
