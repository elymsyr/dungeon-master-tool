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

  /// Kampanyayı sil.
  Future<void> delete(String campaignName);

  /// Yeni kampanya oluştur, template ile.
  Future<String> create(String worldName, {WorldSchema? template});
}
