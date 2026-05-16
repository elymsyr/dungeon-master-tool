import '../entities/schema/world_schema.dart';

/// Campaign persistence interface.
/// Lokal: Drift (SQLite) implementasyonu.
/// Online: Supabase implementasyonu (future).
abstract class CampaignRepository {
  /// Mevcut kampanya isimlerini getir.
  Future<List<String>> getAvailable();

  /// Kampanya verisini yükle (ID veya isim ile).
  Future<Map<String, dynamic>> load(String campaignName);

  /// Kampanya verisini kaydet.
  Future<void> save(String campaignName, Map<String, dynamic> data);

  /// Kampanyayı sil (soft delete — `.trash/`'a taşır).
  Future<void> delete(String campaignName);

  /// Kampanyayı kalıcı olarak sil — trash'a taşımaz, doğrudan siler.
  /// Online world leave/kick akışı tarafından kullanılır: oyuncu cihazından
  /// world'ün lokal kopyasını anında temizler.
  Future<void> purge(String campaignName);

  /// Yeni kampanya oluştur, template ile.
  Future<String> create(String worldName, {WorldSchema? template});

  /// PR-D4: restore a soft-deleted world from `trash_items` by its trash
  /// row id. Returns false on conflict / corrupt payload.
  Future<bool> restoreFromTrash(String trashId);

  /// PR-D4: hard-delete a trash row.
  Future<void> permanentlyDelete(String trashId);
}
